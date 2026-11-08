#!/usr/bin/python3
"""hill-proof-2026-11-08.py: the judging for 09z33 (Arena 1.5 m Hill Climb), stdlib only, CPU only. Rules frozen in PREREG.md before any counted output.

usage:
  hill-proof-2026-11-08.py eval    <runs-file> <tag>   export (publish --dry-run, serial per worktree) + Arena score + hack metrics of every saved checkpoint >= it250 -> eval/<name>-it<N>.json, cands/<name>-it<N>.onnx; also the Pollen reference
  hill-proof-2026-11-08.py pick    <runs-file> <tag>   per run: PICK = lowest score among checkpoints that finish 5/5 AND are clean (ties: earlier it); RAW = lowest among 5/5 whatever the tilt -> pick-<tag>.json
  hill-proof-2026-11-08.py check   <tag>               25-seed CHECK of every PICK and every RAW pick (+ the reference) -> check/<name>-<kind>.json
  hill-proof-2026-11-08.py audit   <tag>               PART A: the live board re-scored on 25 starts: every row's public policy file downloaded, scored (5 official seeds) and checked on seeds 1-25 at its own scored command -> audit/rows-<tag>.json
  hill-proof-2026-11-08.py verdict <runs-file> <tag>   the VERDICT block (stdout) incl. the AUDIT line and the live-board rank; writes facts-<tag>.json for the clip
the local scorer is the Arena's own evaluate() from the 0.7.0 wheel on x86_64 Linux (the Space's platform): on 2026-11-08 it reproduced 128 of 128 downloadable board rows (score and command, within 1.5 ms) and the reference.
"""
import concurrent.futures as cf
import json
import os
import re
import statistics
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

H = Path("/home/witcheer")
A = Path(os.environ.get("HILL_PROOF_DIR", str(H / "Pollen/arena/hill")))   # HILL_PROOF_DIR: test hook only (a scratch dir for the PASS-path unit test)
VENV = H / "Pollen/arena/heist/microduck-challenges/.venv"      # the heist clone's venv (same pinned commit and wheel as the hill clone)
JUDGE = H / "Pollen/hill-judge.py"
REF = A / "reference/policy.onnx"
BOARD = "https://pollen-robotics-microduck-arena.hf.space/api/events/hill-climb-1m5/leaderboard"
EXP = "hill_climb_1m5"
ENV = dict(os.environ, PATH=f"{H}/.local/bin:" + os.environ["PATH"], CUDA_VISIBLE_DEVICES="")

# --- frozen constants (PREREG.md) ---
REF_PIN_S = 5.870          # the reference as the Space and our x86 scorer score it (board row 'Pollen Hill Climb Reference' 5.87 s at 0.55 m/s; AGENTS.md quotes 5.866 s on the maker's machine)
GAIN_SCORE_S = 5.869       # the headline pick's local Arena score must be below the reference's 5.870 s at the Arena's millisecond precision
GAIN_CHECK_MIN = 24        # CHECK over seeds 1-25 at the scored command: finishes >= 24 ...
GAIN_CLEAN_MIN = 24        # ... and >= 24 of the 25 seeds clean (no tilt past 60 deg, trunk height held on the slope)
GAIN_HELD_MEAN_S = 5.872   # ... and the mean over the 20 UNSCORED seeds 6-25 (never used for the pick) <= the reference's own held-out mean, measured 5.872 s (25-seed run, 2026-11-08)
MIN_IT = int(os.environ.get("HILL_MIN_IT", "250"))   # test hook only; the frozen value is 250
AUDIT_TOP = 30             # the audit looks at the board's first 30 rows
FRAGILE_FRESH_MAX = 9      # FRAGILE row = fewer than 10 of the 20 unscored starts (seeds 6-25) finished at the row's own scored command
AUDIT_HOLDS_MIN = 10       # the audit headline holds when >= 10 of the top 30 rows are FRAGILE
MATCH_TOL_S = 0.0015       # local score equals the board row within 1.5 ms (same command)


def runs_of(runs_file):
    out = subprocess.run(["bash", "-c", f'. {runs_file}; printf "%s\\n" "${{RUNS[@]}}"; echo "H:$HEADLINE_RUNS"; echo "V:$VARIANT_RUNS"'], capture_output=True, text=True, check=True).stdout.splitlines()
    specs = [l.split("|") for l in out if "|" in l]
    head = next(l[2:].split() for l in out if l.startswith("H:"))
    var = next(l[2:].split() for l in out if l.startswith("V:"))
    return specs, head, var


def run_dirs(wt, name):
    """every stamped run dir of <name> (a resume cut by a block end writes a NEW dir and keeps counting iterations), oldest first"""
    root = A / wt / "logs/rsl_rl" / EXP
    return sorted(d for d in root.glob("*_" + name) if d.name.split("_", 2)[2:] == [name]) if root.is_dir() else []


def ckpts(d):
    ns = sorted(int(m.group(1)) for f in d.glob("model_*.pt") if (m := re.fullmatch(r"model_(\d+)\.pt", f.name)))
    return [n for n in ns if n >= MIN_IT]


def md5(p):
    import hashlib
    return hashlib.md5(Path(p).read_bytes()).hexdigest()[:8]


def judge(mode, onnx, *extra):
    r = subprocess.run(["nice", "-n", "10", str(VENV / "bin/python"), str(JUDGE), mode, str(onnx), *extra], capture_output=True, text=True, env=ENV)
    for line in reversed(r.stdout.splitlines()):
        if line.startswith("{"):
            return json.loads(line)
    return {"error": (r.stdout + r.stderr)[-300:]}


def cmd_eval(runs_file, tag):
    specs, _, _ = runs_of(runs_file)
    (A / "eval").mkdir(exist_ok=True)
    (A / "cands").mkdir(exist_ok=True)
    jobs = []

    def export_worktree(wt, names):
        for name in names:
            if not run_dirs(wt, name):
                print(f"no run dir for {name}")
                continue
            seen = set()
            for d, n in sorted(((d, n) for d in reversed(run_dirs(wt, name)) for n in ckpts(d)), key=lambda t: t[1]):
                if n in seen:   # the same iteration in two dirs: the newest dir wins
                    continue
                seen.add(n)
                out = A / "cands" / f"{name}-it{n}.onnx"
                if not out.exists():
                    wd = A / wt
                    env = dict(ENV, PYTHONPATH=str(wd / "src"))
                    r = subprocess.run([str(VENV / "bin/publish"), "--run", str(d.relative_to(wd)), "--checkpoint", str(n), "--repo", "local/microduck-eval", "--dry-run", "--allow-dirty"],
                                       cwd=wd, env=env, capture_output=True, text=True)
                    src = wd / "publish-eval/policy.onnx"
                    if r.returncode != 0 or not src.exists():
                        print(f"export failed {name} it{n}: {r.stdout[-200:]}{r.stderr[-200:]}")
                        continue
                    out.write_bytes(src.read_bytes())
                jobs.append((name, n, out))
                print(f"exported {name} it{n} {md5(out)}", flush=True)

    byw = {}
    for name, wt, *_ in specs:
        byw.setdefault(wt, []).append(name)
    with cf.ThreadPoolExecutor(max_workers=len(byw)) as ex:
        list(ex.map(lambda kv: export_worktree(*kv), byw.items()))

    def score_one(job):
        name, n, onnx = job
        j = judge("score", onnx)
        j["md5"] = md5(onnx)
        (A / "eval" / f"{name}-it{n}.json").write_text(json.dumps(j))
        print(f"scored {name} it{n}: " + (f"{j['score']:.3f} s at {j['vx']} m/s, {j['fin']}/5, clean={j['clean']}" if "score" in j else f"ERROR {j.get('error')}"), flush=True)

    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        list(ex.map(score_one, jobs))
    j = judge("score", REF)
    j["md5"] = md5(REF)
    (A / "eval" / f"reference-{tag}.json").write_text(json.dumps(j))
    print("reference:", j.get("score"), j.get("vx"), "clean", j.get("clean"))


def read_eval(name):
    rows = []
    for f in sorted((A / "eval").glob(f"{name}-it*.json")):
        n = int(re.search(r"-it(\d+)\.json", f.name).group(1))
        j = json.loads(f.read_text())
        if "score" in j:
            rows.append({"it": n, "score": j["score"], "vx": j["vx"], "fin": j["fin"], "clean": j["clean"], "tilt_seeds": sum(s["tilt_steps"] > 0 for s in j["seeds"])})
    return sorted(rows, key=lambda r: r["it"])


def best(rows, need_clean):
    ok = [r for r in rows if r["fin"] == 5 and (r["clean"] or not need_clean)]
    return min(ok, key=lambda r: (r["score"], r["it"])) if ok else None


def cmd_pick(runs_file, tag):
    specs, _, _ = runs_of(runs_file)
    res = {}
    for name, *_ in specs:
        rows = read_eval(name)
        p, raw = best(rows, True), best(rows, False)
        res[name] = {"rows": rows, "pick": p, "raw": raw}
        print(f"{name}: " + " ".join(f"it{r['it']}={r['score']:.2f}s({r['fin']}/5{'' if r['clean'] else ',tilt'})" for r in rows))
        print(f"PICK {name} " + (f"it{p['it']} {p['score']:.3f} s at {p['vx']} m/s" if p else "none (no checkpoint finished 5/5 and clean)"))
        print(f"RAW  {name} " + (f"it{raw['it']} {raw['score']:.3f} s at {raw['vx']} m/s, clean={raw['clean']}" if raw else "none"))
    (A / f"pick-{tag}.json").write_text(json.dumps(res))


def cmd_check(tag):
    res = json.loads((A / f"pick-{tag}.json").read_text())
    (A / "check").mkdir(exist_ok=True)
    todo = []
    for name, v in res.items():
        for kind in ("pick", "raw"):
            if v[kind] and (kind == "pick" or not v["pick"] or v["raw"]["it"] != v["pick"]["it"]):
                todo.append((name, kind, v[kind]))

    def one(t):
        name, kind, r = t
        j = judge("check", A / "cands" / f"{name}-it{r['it']}.onnx", "--vx", str(r["vx"]), "--seeds", "25")
        (A / "check" / f"{name}-{kind}.json").write_text(json.dumps(j))
        print(f"check {name} {kind} it{r['it']}: " + (f"finished {j['finished']}/25, clean {j['clean_seeds']}/25, mean {j['mean']:.3f} s, held-out {j['held_mean']:.3f} s" if "finished" in j else f"ERROR {j.get('error')}"), flush=True)

    def ref_check():
        ref = json.loads((A / "eval" / f"reference-{tag}.json").read_text())
        j = judge("check", REF, "--vx", str(ref["vx"]), "--seeds", "25")
        (A / "check" / "reference.json").write_text(json.dumps(j))
        print("check reference: " + (f"finished {j['finished']}/25, clean {j['clean_seeds']}/25, mean {j['mean']:.3f} s, held-out {j['held_mean']:.3f} s" if "finished" in j else f"ERROR {j.get('error')}"), flush=True)

    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        futs = [ex.submit(one, t) for t in todo] + [ex.submit(ref_check)]
        for f in futs:
            f.result()


def read_check(name, kind):
    f = A / "check" / f"{name}-{kind}.json"
    if not f.exists():
        return None
    j = json.loads(f.read_text())
    return j if "finished" in j else None


# ---------------------------------------------------------------- PART A: the board audit
def fetch_board():
    req = urllib.request.Request(BOARD, headers={"User-Agent": "hill-proof/1"})
    return json.load(urllib.request.urlopen(req, timeout=60))["rows"]


def cmd_audit(tag):
    rows = fetch_board()
    ad = A / "audit"
    (ad / "pol").mkdir(parents=True, exist_ok=True)
    (ad / f"board-{tag}.json").write_text(json.dumps(rows))

    def one(r):
        rk = r["rank"]
        out = {"rank": rk, "board_score": r["score"], "board_vx": r["command_vx"], "board_fin": r["seeds_finished"]}
        f = ad / "pol" / f"r{rk}.onnx"
        url = r.get("policy_url")
        try:
            if not (f.exists() and f.stat().st_size > 1000):
                if not url:
                    raise RuntimeError("no policy_url")
                for attempt in range(4):        # a transient DNS/HTTP error is retried; a 401/403/404 (private or removed repo) is final
                    try:
                        req = urllib.request.Request(url, headers={"User-Agent": "hill-proof/1"})
                        f.write_bytes(urllib.request.urlopen(req, timeout=90).read())
                        break
                    except urllib.error.HTTPError as he:
                        if he.code in (401, 403, 404) or attempt == 3:
                            raise
                        time.sleep(5)
                    except Exception:  # noqa: BLE001
                        if attempt == 3:
                            raise
                        time.sleep(5)
        except Exception as e:  # noqa: BLE001
            return {**out, "error": f"fetch: {e}"[:120]}
        s = judge("score", f)
        if "score" not in s:
            return {**out, "error": "score: " + str(s.get("error"))[-120:]}
        c = judge("check", f, "--vx", str(s["vx"]), "--seeds", "25")
        if "finished" not in c:
            return {**out, "error": "check: " + str(c.get("error"))[-120:]}
        fresh = sum(1 for x in c["seeds"] if x["seed"] >= 6 and x["status"] == "finish")
        pat = "".join("F" if x["status"] == "finish" else "x" for x in c["seeds"])      # one char per start, seeds 1..25: F = finished, x = fell / timed out
        return {**out, "pattern": pat, "score": s["score"], "vx": s["vx"], "fin": s["fin"], "tilt_seeds": sum(x["tilt_steps"] > 0 for x in s["seeds"]), "clean5": s["clean"],
                "finished25": c["finished"], "clean25": c["clean_seeds"], "fresh_fin": fresh, "mean25": c["mean"], "held_mean": c["held_mean"],
                "match": abs(s["score"] - r["score"]) <= MATCH_TOL_S and abs(s["vx"] - r["command_vx"]) < 1e-6}

    with cf.ThreadPoolExecutor(max_workers=8) as ex:
        res = list(ex.map(one, rows))
    (ad / f"rows-{tag}.json").write_text(json.dumps(res))
    ok = [r for r in res if "score" in r]
    print(f"audit: {len(rows)} board rows, {len(ok)} re-scored, {sum(r['match'] for r in ok)} match the board row (score + command within {MATCH_TOL_S * 1000:.1f} ms), {len(res) - len(ok)} not fetchable/scorable", flush=True)


def audit_summary(tag):
    f = A / "audit" / f"rows-{tag}.json"
    if not f.exists():
        return None
    res = json.loads(f.read_text())
    ok = [r for r in res if "score" in r]
    top = [r for r in ok if r["rank"] <= AUDIT_TOP]
    frag = [r for r in top if r["fresh_fin"] <= FRAGILE_FRESH_MAX]
    honest = [r for r in ok if r["finished25"] >= GAIN_CHECK_MIN and r["clean25"] >= GAIN_CLEAN_MIN]
    hb = min(honest, key=lambda r: (r["mean25"], r["rank"])) if honest else None
    hero = min(frag, key=lambda r: r["rank"]) if frag else (min(top, key=lambda r: r["rank"]) if top else None)
    return {"rows": len(res), "scored": len(ok), "matched": sum(r["match"] for r in ok), "top_n": len(top), "fragile_top": len(frag),
            "fragile_median_fresh": statistics.median([r["fresh_fin"] for r in frag]) if frag else None, "tilt_top": sum(r["tilt_seeds"] > 0 for r in top),
            "holds": len(frag) >= AUDIT_HOLDS_MIN, "honest_best": ({k: hb[k] for k in ("rank", "score", "mean25", "vx", "finished25", "clean25")} if hb else None),
            "hero": ({k: hero[k] for k in ("rank", "score", "vx", "fresh_fin", "finished25")} if hero else None), "patterns": [[r["rank"], r["pattern"]] for r in sorted(top, key=lambda r: r["rank"])], "mean25_all": sorted(r["mean25"] for r in ok),
            "top_bars": [[r["rank"], r["finished25"], r["fresh_fin"], r["clean25"]] for r in sorted(top, key=lambda r: r["rank"])], "top10_median_score": (statistics.median([r["score"] for r in top if r["rank"] <= 10]) if any(r["rank"] <= 10 for r in top) else None)}


def live_board(score, honest_mean=None):
    try:
        d = fetch_board()
    except Exception as e:  # noqa: BLE001
        return None, f"live board unreachable ({e}); rank not computed"
    s = sorted(r["score"] for r in d)
    rank = 1 + sum(x < score - 1e-9 for x in s)
    info = {"at": f"{datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC", "rows": len(d), "users": len({r["user"] for r in d}), "top": round(s[0], 3), "median": round(statistics.median(s), 3), "slowest": round(s[-1], 3),
            "rank": rank, "of": len(d) + 1, "ref_rank": 1 + sum(x < REF_PIN_S - 1e-9 for x in s)}
    return info, (f"LIVE BOARD at {info['at']}: {score:.3f} s would take rank {rank} of {len(d) + 1} rows (board has {len(d)} rows, {info['users']} users, top {s[0]:.3f} s, median {info['median']:.3f} s, slowest {s[-1]:.3f} s). "
                  f"no promise: the board moves and many top rows only work on the five scored starts, and this is a local score, not an entry")


def meets(pick, chk):
    return (pick is not None and chk is not None and pick["score"] <= GAIN_SCORE_S and chk["finished"] >= GAIN_CHECK_MIN and chk["clean_seeds"] >= GAIN_CLEAN_MIN
            and chk["held_mean"] is not None and chk["held_mean"] <= GAIN_HELD_MEAN_S)


def cmd_verdict(runs_file, tag):
    specs, head, var = runs_of(runs_file)
    res = json.loads((A / f"pick-{tag}.json").read_text())
    rf = A / "eval" / f"reference-{tag}.json"
    ref = json.loads(rf.read_text()) if rf.exists() else {}
    print(f"HILL PROOF {tag}: rules frozen in the vault PREREG.md. Pollen reference re-scored here: {ref.get('score', '?')} s at {ref.get('vx', '?')} m/s ({ref.get('fin', '?')}/5, clean {ref.get('clean', '?')}), pin {REF_PIN_S} s")
    summ = {}
    for name, *_ in specs:
        v = res.get(name, {})
        p, raw = v.get("pick"), v.get("raw")
        cp = read_check(name, "pick")
        craw = read_check(name, "raw") if raw and (not p or raw["it"] != p["it"]) else (cp if raw else None)
        ok = meets(p, cp)
        summ[name] = {"pick": p, "check": cp, "raw": raw, "raw_check": craw, "meets_bar": ok}
        role = "HEADLINE" if name in head else "VARIANT"
        if p is None:
            print(f"{role} {name}: no checkpoint finished 5/5 and clean" + (f"; raw best {raw['score']:.3f} s (it{raw['it']}, clean={raw['clean']})" if raw else ""))
            continue
        cs = (f"CHECK25 finished {cp['finished']}/25, clean {cp['clean_seeds']}/25, mean {cp['mean']:.3f} s; unscored seeds 6-25 mean {cp['held_mean']:.3f} s (n={cp['held_n']})" if cp else "CHECK25 missing")
        rs = f"; raw best (any tilt) it{raw['it']} {raw['score']:.3f} s clean={raw['clean']}" if raw else ""
        print(f"{role} {name}: PICK it{p['it']} local score {p['score']:.3f} s at {p['vx']} m/s (5/5, clean); {cs}{rs}; meets bar (score <= {GAIN_SCORE_S} s, CHECK finishes >= {GAIN_CHECK_MIN}, clean >= {GAIN_CLEAN_MIN}, unscored mean <= {GAIN_HELD_MEAN_S} s): {'yes' if ok else 'no'}")
    hp = [(summ[n]["pick"]["score"], n) for n in head if summ.get(n, {}).get("pick")]
    hr = [(summ[n]["raw"]["score"], n) for n in head if summ.get(n, {}).get("raw")]
    au = audit_summary(tag)
    if au:
        print(f"AUDIT (part A, live board re-scored on 25 starts): {au['scored']} of {au['rows']} rows re-scored, {au['matched']} match the board row; top {au['top_n']}: {au['fragile_top']} are FRAGILE (fewer than 10 of the 20 unscored starts finish; median {au['fragile_median_fresh']} of 20), "
              f"{au['tilt_top']} tip past 60 degrees in a scored seed; best row that holds up on 25 starts (>= 24/25 finish and >= 24 clean): " +
              (f"board rank {au['honest_best']['rank']}, {au['honest_best']['mean25']:.3f} s mean of 25 (board {au['honest_best']['score']:.3f} s); " if au['honest_best'] else "none; ") + f"AUDIT {'HOLDS' if au['holds'] else 'DOES NOT HOLD'} (>= {AUDIT_HOLDS_MIN} fragile rows in the top {AUDIT_TOP})")
    else:
        print("AUDIT: missing (no audit/rows file)")
    if not hp and not hr:
        print("VERDICT: NO GAIN (no headline checkpoint finished 5/5)")
        return
    best_s, best_n = min(hp) if hp else (None, None)
    raw_s, raw_n = min(hr) if hr else (None, None)
    raw_fragile = False
    if raw_n and summ[raw_n]["raw"] and (not best_n or summ[raw_n]["raw"]["it"] != summ[best_n]["pick"]["it"] or raw_n != best_n):
        rc = summ[raw_n]["raw_check"]
        raw_fragile = (not summ[raw_n]["raw"]["clean"]) or (rc is not None and (rc["finished"] < GAIN_CHECK_MIN))
    if best_n and summ[best_n]["meets_bar"]:
        verdict, ref_s, ref_n = "GAIN", best_s, best_n
    elif raw_n and raw_s <= GAIN_SCORE_S and raw_fragile:      # the fastest 5/5 beats the bar only by tipping or by failing the unscored starts: tuned to the five scored seeds, not a hill climber
        verdict, ref_s, ref_n = "HACK CAUGHT", raw_s, raw_n
    else:
        verdict, ref_s, ref_n = "NO GAIN", best_s if best_n else raw_s, best_n or raw_n
    reps = [n for n in head if summ.get(n, {}).get("meets_bar")]
    print(f"HEADLINE PICK: {best_n or '-'} it{summ[best_n]['pick']['it'] if best_n else '-'} at {f'{best_s:.3f}' if best_n else '-'} s (Pollen reference {ref.get('score', '?')} s)")
    if raw_n:
        print(f"RAW BEST (any tilt, reported): {raw_n} it{summ[raw_n]['raw']['it']} {raw_s:.3f} s, clean={summ[raw_n]['raw']['clean']}")
    print(f"REPLICATION: {len(reps)} of {len(head)} headline seeds meet the bar ({', '.join(reps) or 'none'})")
    print("VARIANT (reported only): " + ("none defined" if not var else "; ".join(f"{n} {summ[n]['pick']['score']:.3f} s" if summ.get(n, {}).get("pick") else f"{n} none" for n in var)))
    show = best_s if best_n else raw_s
    # honest ladder place of the shown pick: rank by mean of 25 starts among the audited rows
    shown = summ[ref_n]["pick"] if verdict != "HACK CAUGHT" and summ[ref_n]["pick"] else summ[ref_n]["raw"]
    shown_chk = summ[ref_n]["check"] if verdict != "HACK CAUGHT" and summ[ref_n]["pick"] else summ[ref_n]["raw_check"]
    info, line = live_board(show)
    print(line)
    honest_place = None
    if au and shown_chk:
        honest_place = {"place": 1 + sum(m < shown_chk["mean"] - 1e-9 for m in au["mean25_all"]), "of": len(au["mean25_all"]) + 1}
        print(f"HONEST LADDER (audited rows ranked by mean of 25 starts): {shown_chk['mean']:.3f} s would take place {honest_place['place']} of {honest_place['of']}")
    ej = json.loads((A / "eval" / f"{ref_n}-it{shown['it']}.json").read_text())
    facts = {"verdict": verdict, "run": ref_n, "it": shown["it"], "score": shown["score"], "vx": shown["vx"], "fin": shown["fin"], "clean": shown["clean"], "check": shown_chk,
             "ref": {k: ref.get(k) for k in ("score", "vx", "fin", "clean")}, "ref_check": None, "board": info, "audit": au, "honest_place": honest_place, "gain_bar": GAIN_SCORE_S,
             "replication": f"{len(reps)} of {len(head)}", "tag": tag, "onnx": str(A / "cands" / f"{ref_n}-it{shown['it']}.onnx"), "scan": ej["scan"],
             "hero_onnx": (str(A / "audit/pol" / f"r{au['hero']['rank']}.onnx") if au and au["hero"] else None)}
    rc = A / "check" / "reference.json"
    if rc.exists():
        facts["ref_check"] = json.loads(rc.read_text())
    (A / f"facts-{tag}.json").write_text(json.dumps(facts, indent=1))
    print(f"VERDICT: {verdict}")


if __name__ == "__main__":
    c = sys.argv[1]
    {"eval": lambda: cmd_eval(*sys.argv[2:4]), "pick": lambda: cmd_pick(*sys.argv[2:4]), "check": lambda: cmd_check(sys.argv[2]), "audit": lambda: cmd_audit(sys.argv[2]),
     "verdict": lambda: cmd_verdict(*sys.argv[2:4])}[c]()
