#!/usr/bin/env python3
# bk-pick-2026-10-24.py <batch dir> [new-prefix seed-prefix]: picks the takes for the 09z10 clip cut from proof-bk-a (giant ball, goal, no shoves).
# prints "NEW <take name> d2=<m> goal=<0/1> aim=<deg>" and "SEED <take name> d2=<m> ..." (names without extension; the mp4 sits next to the log).
# NEW  = the held take with the ball inside the goal and the largest 2 s ball travel (the hero); if no take has the ball in the goal: the held take with the largest travel,
#        flagged GOAL=0 so the cut script refuses to burn a goal caption (it only ever says what the take shows).
# SEED = the held seed take whose 2 s travel is the MEDIAN of the seed's takes (the typical "before", never the worst).
import glob, math, os, re, statistics, sys
d = sys.argv[1]; pn, ps = (sys.argv[2], sys.argv[3]) if len(sys.argv) > 3 else ('bkna', 'bksa')
S = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([-\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\) ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
A0 = re.compile(r'after reset:.*?ball=\(([-+\d.]+),([-+\d.]+)')
R = re.compile(r'RESET at t=\s*([\d.]+)')
def read(f):
    t = open(f, errors='replace').read(); a = A0.search(t)
    rows = [(float(m[1]), float(m[5]), float(m[6]), float(m[7]), float(m[8])) for m in S.finditer(t) if float(m[1]) <= 5.95]   # t, grav z, ball x, y, z
    if not a or not rows: return None
    sx, sy = float(a[1]), float(a[2])
    falls, st = 0, 'up'
    for r in rows:
        if st == 'up' and r[1] > -0.5: falls += 1; st = 'down'
        elif st == 'down' and r[1] < -0.9: st = 'up'
    held = falls == 0 and not [x for x in R.findall(t) if float(x) < 5.9]
    r2 = min(rows, key=lambda r: abs(r[0] - 2.0)); r15 = min(rows, key=lambda r: abs(r[0] - 1.5))
    goal = any(1.40 <= r[2] <= 1.80 and abs(r[3]) < 0.50 for r in rows)  # ball centre ever inside the goal mouth footprint (x 1.4..1.8, |y| < 0.5)
    return dict(held=held, d2=math.hypot(r2[2] - sx, r2[3] - sy), goal=goal, aim=math.degrees(math.atan2(r15[3] - sy, r15[2] - sx)))
def takes(prefix):
    out = {}
    for f in sorted(glob.glob(f'{d}/{prefix}-t*.log')):
        if f.endswith('.full.log'): continue
        n = os.path.basename(f)[:-4]; r = read(f)
        if r and os.path.exists(f'{d}/{n}.mp4'): out[n] = r
    return out
new, seed = takes(pn), takes(ps)
cand = {k: v for k, v in new.items() if v['held']}
if not cand: sys.exit('NO_HELD_NEW_TAKE')
goalc = {k: v for k, v in cand.items() if v['goal']}
pool = goalc or cand
k = max(pool, key=lambda n: pool[n]['d2'])
print(f"NEW {k} d2={new[k]['d2']:.2f} goal={int(new[k]['goal'])} aim={new[k]['aim']:+.1f} (held {len(cand)}/{len(new)}, goal {len(goalc)}/{len(new)})")
sh = {k2: v for k2, v in seed.items() if v['held']}
if not sh: sys.exit('NO_HELD_SEED_TAKE')
med = statistics.median(v['d2'] for v in sh.values())
s = min(sh, key=lambda n: abs(sh[n]['d2'] - med))
print(f"SEED {s} d2={seed[s]['d2']:.2f} goal={int(seed[s]['goal'])} aim={seed[s]['aim']:+.1f} (median d2 of {len(sh)} held seed takes {med:.2f})")
