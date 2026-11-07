#!/usr/bin/python3
"""heist-proof-2026-11-05.py: the judging for 09z29 (Arena 6 m Sock Heist), stdlib only, CPU only. Rule frozen in PREREG.md before any counted output.

usage:
  heist-proof-2026-11-05.py eval   <runs-file> <tag>   export (publish --dry-run, serial per worktree) + `arena score` every saved checkpoint >= it100 -> eval/<name>-it<N>.txt, cands/<name>-it<N>.onnx; also the reference walker
  heist-proof-2026-11-05.py pick   <runs-file> <tag>   per run: the checkpoint with 5/5 finishes and the lowest local score (ties: earlier iteration) -> pick-<tag>.json
  heist-proof-2026-11-05.py check  <tag>               25-seed CHECK of every pick (parallel) -> check/<name>.txt
  heist-proof-2026-11-05.py verdict <runs-file> <tag>  the VERDICT block (stdout) incl. the live-board rank

the local scorer runs on x86_64 Linux = the Space's platform; on 2026-11-05 it reproduced four board rows to the millisecond (see PREREG evidence).
"""
import concurrent.futures as cf
import json
import os
import re
import statistics
import subprocess
import sys
import urllib.request
from pathlib import Path

H = Path("/home/witcheer")
A = H / "Pollen/arena/heist"
VENV = A / "microduck-challenges/.venv"
EVENT = "sock-heist-6m"
WALKER = A / "microduck-challenges/src/microduck_challenges/sock_heist_6m/walker.onnx"
BOARD = "https://pollen-robotics-microduck-arena.hf.space/api/events/sock-heist-6m/leaderboard"
ENV = dict(os.environ, PATH=f"{H}/.local/bin:" + os.environ["PATH"], CUDA_VISIBLE_DEVICES="")

# --- frozen constants (PREREG.md) ---
GAIN_SCORE_S = 21.0       # local Arena score of the headline pick must be <= this
GAIN_CHECK_MIN = 24       # and the pick must finish >= 24 of the 25-seed CHECK (the reference walker finishes 24/25)
WALKER_PIN_S = 24.159     # the repo's own x86 measurement of the reference walker (AGENTS.md / event toml); we re-score it every proof
MIN_IT = int(os.environ.get("HEIST_MIN_IT", "100"))   # test hook only; the frozen value is 100
GAIN_HELD_MEAN_S = 22.5   # and the mean over the 20 held-out CHECK seeds (6-25, never used for the pick) must be <= this (the reference walker's is about 24)


def runs_of(runs_file):
    out = subprocess.run(["bash", "-c", f'. {runs_file}; printf "%s\\n" "${{RUNS[@]}}"; echo "H:$HEADLINE_RUNS"; echo "V:$VARIANT_RUNS"'],
                         capture_output=True, text=True, check=True).stdout.splitlines()
    specs = [l.split("|") for l in out if "|" in l]
    head = next(l[2:].split() for l in out if l.startswith("H:"))
    var = next(l[2:].split() for l in out if l.startswith("V:"))
    return specs, head, var


def run_dirs(wt, name):
    """every stamped run dir of <name> (a resume cut by a block end writes a NEW dir and keeps counting iterations), oldest first"""
    root = A / wt / "logs/rsl_rl/sock_heist_6m"
    return sorted(d for d in root.glob("*_" + name) if d.name.split("_", 2)[2:] == [name]) if root.is_dir() else []


def ckpts(d):
    ns = sorted(int(m.group(1)) for f in d.glob("model_*.pt") if (m := re.fullmatch(r"model_(\d+)\.pt", f.name)))
    return [n for n in ns if n >= MIN_IT]


SCORE_RE = re.compile(r"^score ([0-9.]+)s · (\d+)/(\d+) finished")


def parse_score(txt):
    for l in txt.splitlines():
        m = SCORE_RE.match(l.strip())
        if m:
            return float(m[1]), int(m[2]), int(m[3])
    return None


def arena_score(onnx):
    r = subprocess.run(["nice", "-n", "10", str(VENV / "bin/arena"), "score", str(onnx), "--event", EVENT], capture_output=True, text=True, env=ENV)
    return r.stdout + r.stderr


def md5(p):
    import hashlib
    return hashlib.md5(Path(p).read_bytes()).hexdigest()[:8]


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
        txt = arena_score(onnx)
        (A / "eval" / f"{name}-it{n}.txt").write_text(f"== {name} it{n} {md5(onnx)}\n{txt}")
        s = parse_score(txt)
        print(f"scored {name} it{n}: {s}", flush=True)

    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        list(ex.map(score_one, jobs))
    wtxt = arena_score(WALKER)
    (A / "eval" / f"walker-{tag}.txt").write_text(f"== reference walker {md5(WALKER)}\n{wtxt}")
    print("walker:", parse_score(wtxt))


def read_eval(name):
    rows = []
    for f in sorted((A / "eval").glob(f"{name}-it*.txt")):
        n = int(re.search(r"-it(\d+)\.txt", f.name).group(1))
        s = parse_score(f.read_text())
        if s:
            rows.append((n, s[0], s[1], s[2]))
    return sorted(rows)


def pick_of(rows):
    ok = [r for r in rows if r[2] == r[3]]
    if not ok:
        return None
    return min(ok, key=lambda r: (r[1], r[0]))


def cmd_pick(runs_file, tag):
    specs, _, _ = runs_of(runs_file)
    res = {}
    for name, *_ in specs:
        rows = read_eval(name)
        p = pick_of(rows)
        res[name] = {"rows": rows, "pick": p[0] if p else None, "pick_score": p[1] if p else None}
        print(f"{name}: " + " ".join(f"it{n}={s:.2f}s({f}/{t})" for n, s, f, t in rows))
        print(f"PICK {name} " + (f"it{p[0]} {p[1]:.3f} s" if p else "none (no checkpoint finished 5/5)"))
    (A / f"pick-{tag}.json").write_text(json.dumps(res))


def cmd_check(tag):
    res = json.loads((A / f"pick-{tag}.json").read_text())
    (A / "check").mkdir(exist_ok=True)

    def one(kv):
        name, v = kv
        if v["pick"] is None:
            return
        onnx = A / "cands" / f"{name}-it{v['pick']}.onnx"
        r = subprocess.run(["nice", "-n", "10", str(VENV / "bin/python"), "-m", "microduck_challenges.sock_heist_6m.check", str(onnx), "--seeds", "25"],
                           cwd=A / "microduck-challenges", env=ENV, capture_output=True, text=True)
        (A / "check" / f"{name}.txt").write_text(r.stdout + r.stderr)
        print(f"check {name} it{v['pick']}: " + (r.stdout.strip().splitlines() or ["?"])[-1])

    with cf.ThreadPoolExecutor(max_workers=3) as ex:
        list(ex.map(one, res.items()))


def parse_check(name):
    f = A / "check" / f"{name}.txt"
    if not f.exists():
        return None
    txt = f.read_text()
    m = re.search(r"finished (\d+)/(\d+) · caught (\d+).*?mean ([0-9.]+) s", txt)
    if not m:
        return None
    held = []
    for l in txt.splitlines():
        s = re.match(r"seed (\d+) · finish ([0-9.]+) s", l)
        if s and int(s[1]) >= 6:
            held.append(float(s[2]))
        elif (s2 := re.match(r"seed (\d+) · ", l)) and int(s2[1]) >= 6:
            held.append(40.0)
    return {"fin": int(m[1]), "of": int(m[2]), "caught": int(m[3]), "mean25": float(m[4]), "held_mean": statistics.mean(held) if held else None, "held_n": len(held)}


def live_board(score):
    try:
        d = json.load(urllib.request.urlopen(BOARD, timeout=30))["rows"]
    except Exception as e:  # noqa: BLE001
        return f"live board unreachable ({e}); rank not computed"
    s = sorted(r["score"] for r in d)
    rank = 1 + sum(x < score - 1e-9 for x in s)
    users = len({r["user"] for r in d})
    from datetime import datetime, timezone
    return (f"LIVE BOARD at {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC: {score:.3f} s would take rank {rank} of {len(d) + 1} rows "
            f"(board has {len(d)} rows, {users} users, top {s[0]:.3f} s, median {statistics.median(s):.3f} s, slowest {s[-1]:.3f} s). "
            f"no promise: the board moves, and this is a local score, not an entry")


def cmd_verdict(runs_file, tag):
    specs, head, var = runs_of(runs_file)
    res = json.loads((A / f"pick-{tag}.json").read_text())
    wtxt = (A / "eval" / f"walker-{tag}.txt").read_text() if (A / "eval" / f"walker-{tag}.txt").exists() else ""
    w = parse_score(wtxt)
    print(f"HEIST PROOF {tag}: rule frozen in the vault PREREG.md. reference walker re-scored here: {w[0] if w else '?'} s ({w[1] if w else '?'}/5), repo pin {WALKER_PIN_S} s")
    summ = {}
    for name, *_ in specs:
        v = res.get(name, {})
        c = parse_check(name)
        ok = (v.get("pick") is not None and c is not None and c["fin"] >= GAIN_CHECK_MIN and v["pick_score"] <= GAIN_SCORE_S
              and c["held_mean"] is not None and c["held_mean"] <= GAIN_HELD_MEAN_S)
        summ[name] = {"pick": v.get("pick"), "score": v.get("pick_score"), "check": c, "meets_bar": ok}
        role = "HEADLINE" if name in head else "VARIANT"
        if v.get("pick") is None:
            print(f"{role} {name}: no checkpoint finished 5/5 (best of {len(v.get('rows', []))} judged: " + (f"{min(r[1] for r in v['rows']):.2f} s" if v.get("rows") else "none") + ")")
            continue
        cs = (f"CHECK25 finished {c['fin']}/{c['of']}, caught {c['caught']}, mean {c['mean25']:.2f} s; held-out seeds 6-25 mean {c['held_mean']:.2f} s (n={c['held_n']})" if c else "CHECK25 missing")
        print(f"{role} {name}: PICK it{v['pick']} local score {v['pick_score']:.3f} s (5/5); {cs}; meets bar (score <= {GAIN_SCORE_S} s, CHECK >= {GAIN_CHECK_MIN}/25, held-out mean <= {GAIN_HELD_MEAN_S} s): {'yes' if ok else 'no'}")
    hs = [(summ[n]["score"], n) for n in head if summ.get(n, {}).get("score") is not None]
    if not hs:
        print("VERDICT: NO GAIN (no headline checkpoint finished 5/5)")
        return
    best_s, best_n = min(hs)
    beats_walker = w is not None and best_s < w[0]
    if summ[best_n]["meets_bar"]:
        verdict = "GAIN"
    elif beats_walker and summ[best_n]["check"] and summ[best_n]["check"]["fin"] >= GAIN_CHECK_MIN and summ[best_n]["check"]["held_mean"] is not None and summ[best_n]["check"]["held_mean"] < 24.0:
        verdict = "BEATS WALKER, BAR NOT MET"
    else:
        verdict = "NO GAIN"
    reps = [n for n in head if summ.get(n, {}).get("meets_bar")]
    print(f"HEADLINE PICK: {best_n} it{summ[best_n]['pick']} at {best_s:.3f} s (reference walker {w[0] if w else '?'} s)")
    print(f"REPLICATION: {len(reps)} of {len(head)} headline seeds meet the bar ({', '.join(reps) or 'none'})")
    print(f"VARIANT (reported only, one seed each, never a comparison): " + "; ".join(f"{n} {summ[n]['score']:.3f} s" if summ.get(n, {}).get("score") else f"{n} none" for n in var))
    print(live_board(best_s))
    print(f"VERDICT: {verdict}")


if __name__ == "__main__":
    c = sys.argv[1]
    {"eval": lambda: cmd_eval(*sys.argv[2:4]), "pick": lambda: cmd_pick(*sys.argv[2:4]), "check": lambda: cmd_check(sys.argv[2]), "verdict": lambda: cmd_verdict(*sys.argv[2:4])}[c]()
