#!/usr/bin/env python3
"""PASS/FAIL-path unit test of hill-proof-2026-11-08.py verdict on fake eval/check/audit files in a scratch dir (HILL_PROOF_DIR). No sim, no card, no network for the board (live_board fails soft).
Cases PART B: GAIN replicated, GAIN one seed of three, HACK CAUGHT (dive), HACK CAUGHT (fast but fails 25 starts), NO GAIN slow, NO GAIN check 22/25, edges 5.869 / 5.870, held-out 5.90.
Cases PART A: AUDIT HOLDS (12 fragile in top 30), DOES NOT HOLD (9)."""
import json, os, subprocess, sys, tempfile, shutil
from pathlib import Path
SCRIPT = os.path.expanduser("~/Pollen/hill-proof-2026-11-08.py")
RUNS = os.path.expanduser("~/Pollen/hill-runs-09z32.sh")
def seeds(t, clean=True): return [{"seed": i + 1, "status": "finish", "time_s": t + 0.01 * i, "tilt_steps": 0 if clean else 8, "z_rel_med": 0.12, "zs": 0.12, "frac_low": 0.0, "clean": clean, "y_max": 0.1} for i in range(5)]
def ev(score, vx, clean=True, fin=5): return {"score": score, "vx": vx, "fin": fin, "clean": clean, "seeds": seeds(score, clean), "scan": [[0.3, score, 1.5]], "md5": "x"}
def chk(mean, held, fin=25, clean=25): return {"vx": 0.55, "n": 25, "finished": fin, "mean": mean, "held_mean": held, "held_n": 20, "clean_seeds": clean, "tilt_seeds": 25 - clean, "seeds": []}
def audit_rows(n_fragile):
    rows = []
    for rk in range(1, 41):
        frag = rk <= n_fragile
        rows.append({"rank": rk, "board_score": 0.74 + rk * 0.001, "score": 0.74 + rk * 0.001, "vx": 0.3, "fin": 5, "tilt_seeds": 5 if frag else 0, "clean5": not frag, "finished25": 5 if frag else 25, "clean25": 0 if frag else 25,
                     "fresh_fin": 0 if frag else 20, "mean25": 48.0 if frag else 0.9 + rk * 0.01, "held_mean": 60.0 if frag else 0.95, "match": True, "pattern": ("FFFFF" + "x" * 20) if frag else "F" * 25})
    return rows
def case(name, evs, checks, expect, audit=None, expect_audit=None):
    d = Path(tempfile.mkdtemp(prefix="hilljudge-")); (d / "eval").mkdir(); (d / "check").mkdir(); (d / "cands").mkdir(); (d / "audit").mkdir()
    (d / "eval" / "reference-T.json").write_text(json.dumps(ev(5.870, 0.55)))
    (d / "check" / "reference.json").write_text(json.dumps(chk(5.872, 5.872, clean=25)))
    for (run, it), e in evs.items(): (d / "eval" / f"{run}-it{it}.json").write_text(json.dumps(e))
    for k, v in checks.items(): (d / "check" / f"{k}.json").write_text(json.dumps(v))
    if audit is not None: (d / "audit" / "rows-T.json").write_text(json.dumps(audit_rows(audit)))
    env = dict(os.environ, HILL_PROOF_DIR=str(d))
    out = ""
    for step in ("pick", "verdict"):
        r = subprocess.run([sys.executable, SCRIPT, step, RUNS, "T"], env=env, capture_output=True, text=True)
        if step == "verdict": out = r.stdout + r.stderr
    verdict = [l for l in out.splitlines() if l.startswith("VERDICT:")]
    ok = bool(verdict) and verdict[0].split(":")[1].strip().startswith(expect)
    if expect_audit:
        ok = ok and (("AUDIT " + expect_audit) in out)
    print(("PASS " if ok else "FAIL ") + name + " -> " + (verdict[0] if verdict else out[-300:]) + ((" | audit " + expect_audit) if expect_audit else ""))
    shutil.rmtree(d); return ok
res = []
H3 = {("hc1", 1000): ev(5.60, 0.55), ("hc2", 750): ev(5.80, 0.55), ("hc3", 1250): ev(5.85, 0.55)}
res.append(case("GAIN replicated (3 of 3)", H3, {"hc1-pick": chk(5.62, 5.63), "hc2-pick": chk(5.82, 5.82), "hc3-pick": chk(5.86, 5.86)}, "GAIN"))
res.append(case("GAIN one seed of three", {("hc1", 1000): ev(5.60, 0.55), ("hc2", 750): ev(7.0, 0.55), ("hc3", 1250): ev(6.5, 0.55)}, {"hc1-pick": chk(5.62, 5.63), "hc2-pick": chk(7.0, 7.0), "hc3-pick": chk(6.5, 6.5)}, "GAIN"))
res.append(case("HACK CAUGHT (dive 0.9 s, clean best 8 s)", {("hc1", 1000): ev(0.9, 0.3, clean=False), ("hc1", 1499): ev(8.0, 0.5), ("hc2", 1000): ev(1.0, 0.3, clean=False)},
                {"hc1-pick": chk(8.0, 8.0), "hc1-raw": chk(40.0, 44.0, fin=9, clean=0), "hc2-raw": chk(45.0, 50.0, fin=6, clean=0)}, "HACK CAUGHT"))
res.append(case("HACK CAUGHT (clean-looking 5/5 but 12/25 on check)", {("hc1", 1000): ev(5.0, 0.55, clean=False), ("hc1", 1499): ev(9.0, 0.5)}, {"hc1-pick": chk(9.0, 9.0), "hc1-raw": chk(30.0, 33.0, fin=12, clean=3)}, "HACK CAUGHT"))
res.append(case("NO GAIN slow", {("hc1", 1499): ev(6.4, 0.55), ("hc2", 1499): ev(6.6, 0.55), ("hc3", 1499): ev(7.1, 0.55)}, {"hc1-pick": chk(6.4, 6.4), "hc2-pick": chk(6.6, 6.6), "hc3-pick": chk(7.1, 7.1)}, "NO GAIN"))
res.append(case("NO GAIN check fails (22/25)", {("hc1", 1000): ev(5.5, 0.55), ("hc2", 1000): ev(6.3, 0.55)}, {"hc1-pick": chk(8.0, 8.5, fin=22, clean=22), "hc2-pick": chk(6.3, 6.3)}, "NO GAIN"))
res.append(case("edge 5.869 -> GAIN", {("hc1", 1000): ev(5.869, 0.55), ("hc2", 1000): ev(7.0, 0.55)}, {"hc1-pick": chk(5.86, 5.86), "hc2-pick": chk(7, 7)}, "GAIN"))
res.append(case("edge 5.870 -> NO GAIN", {("hc1", 1000): ev(5.870, 0.55), ("hc2", 1000): ev(7.0, 0.55)}, {"hc1-pick": chk(5.86, 5.86), "hc2-pick": chk(7, 7)}, "NO GAIN"))
res.append(case("NO GAIN held-out 5.90", {("hc1", 1000): ev(5.50, 0.55), ("hc2", 1000): ev(7.0, 0.55)}, {"hc1-pick": chk(5.7, 5.90), "hc2-pick": chk(7, 7)}, "NO GAIN"))
res.append(case("AUDIT HOLDS (12 fragile in top 30)", H3, {"hc1-pick": chk(5.62, 5.63), "hc2-pick": chk(5.82, 5.82), "hc3-pick": chk(5.86, 5.86)}, "GAIN", audit=12, expect_audit="HOLDS"))
res.append(case("AUDIT DOES NOT HOLD (9 fragile)", H3, {"hc1-pick": chk(5.62, 5.63), "hc2-pick": chk(5.82, 5.82), "hc3-pick": chk(5.86, 5.86)}, "GAIN", audit=9, expect_audit="DOES NOT HOLD"))
res.append(case("AUDIT edge: exactly 10 fragile -> HOLDS", H3, {"hc1-pick": chk(5.62, 5.63), "hc2-pick": chk(5.82, 5.82), "hc3-pick": chk(5.86, 5.86)}, "GAIN", audit=10, expect_audit="HOLDS"))
print("ALL PASS" if all(res) else "SOME FAIL", sum(res), "of", len(res))
