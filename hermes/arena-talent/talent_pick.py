#!/usr/bin/env python3
"""talent_pick.py: pick the checkpoint to enter, from per-checkpoint stage reports.

usage: talent_pick.py OUT.json JUDGE_DIR   (JUDGE_DIR holds ck<N>.json written by talent_stage_report.py --json)
Rule, fixed before any checkpoint of our run is judged (2026-10-27):
  1. candidates are checkpoints >= 1500 (the head range finishes widening at iteration 2000; env TALENT_PICK_MIN lowers it for the e2e clone only);
  2. cost = sum over every judged timeline and duck of problems.total (posture segment not reached / slow / not held,
     head hold off by more than 0.25 rad, a fall);
  3. lowest cost wins; ties go to the checkpoint whose two neighbours (+-250) have the lower summed cost, then to the later one.
"""
import json, os, re, sys
from pathlib import Path
out, jd = Path(sys.argv[1]), Path(sys.argv[2])
cost = {}
for f in jd.glob("ck*.json"):
    n = int(re.fullmatch(r"ck(\d+)\.json", f.name).group(1))
    data = json.loads(f.read_text())
    cost[n] = sum(d["problems"]["total"] for ducks in data.values() for d in ducks)
FLOOR = int(os.environ.get("TALENT_PICK_MIN", "1500"))
cands = sorted(n for n in cost if n >= FLOOR)
if not cands:
    out.write_text(json.dumps({"error": f"no checkpoint >= {FLOOR} judged", "cost": cost})); sys.exit(1)
def nb(n):
    return sum(cost.get(n + k, 0) for k in (-250, 250))
best = sorted(cands, key=lambda n: (cost[n], nb(n), -n))[0]
out.write_text(json.dumps({"pick": best, "cost": dict(sorted(cost.items())), "rule": __doc__.split("Rule,")[1].strip()}, indent=1))
print(f"pick checkpoint {best} (cost {cost[best]}); costs: " + " ".join(f"{n}:{c}" for n, c in sorted(cost.items())))
