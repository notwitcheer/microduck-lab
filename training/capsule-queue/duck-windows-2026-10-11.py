#!/usr/bin/env python3
# duck-windows-2026-10-11.py <run.log> <win_end> [win_end ...]: 100-it window means from an rsl_rl run log
# (first occurrence of each iteration wins, so a resumed leg's re-printed iterations do not overwrite the pre-cut leg).
import re, sys
KEYS = ["Mean reward", "Mean episode length", "Episode_Termination/fell_over", "Episode_Termination/fallen_too_long",
        "Metrics/twist/error_vel_xy", "Curriculum/terrain_levels/mean", "Episode_Reward/recovery_success",
        "Episode_Termination/nan_state"]
txt = open(sys.argv[1], errors="replace").read()
blocks = re.split(r"Learning iteration (\d+)/\d+", txt)
it = {}
for i in range(1, len(blocks), 2):
    n = int(blocks[i]); body = blocks[i + 1]
    if n in it:
        continue
    d = {}
    for k in KEYS:
        m = re.search(re.escape(k) + r":\s*([-\d.eE+]+)", body)
        if m:
            d[k] = float(m.group(1))
    if "Mean reward" in d:
        it[n] = d
print(f"iterations parsed: {len(it)} ({min(it)}..{max(it)})")
for e in map(int, sys.argv[2:]):
    w = [it[n] for n in range(e - 99, e + 1) if n in it]
    if not w:
        print(f"..{e}: none"); continue
    row = [f"..{e} (n={len(w)})"]
    for k in KEYS:
        v = [x[k] for x in w if k in x]
        if v:
            row.append(f"{k.split('/')[-1]}={sum(v)/len(v):.3f}")
    print("  ".join(row))
