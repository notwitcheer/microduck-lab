#!/usr/bin/env python3
# ba-pick-2026-10-26.py <batch dir> [new-prefix ref-prefix]: picks the takes for the 09z12 clip cut from proof-ba-a (giant ball, goal, no shoves).
# prints "NEW <take name> d2=<m> goal=<0/1> aim=<deg>" and "REF <take name> d2=<m> goal=<0/1> aim=<deg>" (names without extension; the mp4 sits next to the log).
# NEW = the held take with the ball inside the goal and the largest 2 s ball travel (the hero); if no new take has the ball in the goal: the held take with the best (smallest) |aim|,
#       flagged GOAL=0 so the cut script refuses to burn a goal caption (it only ever says what the take shows).
# REF = the held reference take (the 09z10 giant-ball kick, 16000) whose aim at 1.5 s is the MEDIAN aim of the reference's held takes: the typical "before", never the worst.
import glob, math, os, re, statistics, sys
d = sys.argv[1]; pn, pr = (sys.argv[2], sys.argv[3]) if len(sys.argv) > 3 else ('bana', 'bkra')
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
    goal = any(1.40 <= r[2] <= 1.80 and abs(r[3]) < 0.50 and r[4] < 0.50 for r in rows)
    return dict(held=held, d2=math.hypot(r2[2] - sx, r2[3] - sy), goal=goal, aim=math.degrees(math.atan2(r15[3] - sy, r15[2] - sx)))
def takes(prefix):
    out = {}
    for f in sorted(glob.glob(f'{d}/{prefix}-t*.log')):
        if f.endswith('.full.log'): continue
        n = os.path.basename(f)[:-4]; r = read(f)
        if r and os.path.exists(f'{d}/{n}.mp4'): out[n] = r
    return out
new, ref = takes(pn), takes(pr)
cand = {k: v for k, v in new.items() if v['held']}
if not cand: sys.exit('NO_HELD_NEW_TAKE')
goalc = {k: v for k, v in cand.items() if v['goal']}
k = max(goalc, key=lambda n: goalc[n]['d2']) if goalc else min(cand, key=lambda n: abs(cand[n]['aim']))
print(f"NEW {k} d2={new[k]['d2']:.2f} goal={int(new[k]['goal'])} aim={new[k]['aim']:+.1f} (held {len(cand)}/{len(new)}, goal {len(goalc)}/{len(new)})")
rh = {k2: v for k2, v in ref.items() if v['held']}
if not rh: sys.exit('NO_HELD_REF_TAKE')
med = statistics.median(v['aim'] for v in rh.values())
s = min(rh, key=lambda n: abs(rh[n]['aim'] - med))
print(f"REF {s} d2={ref[s]['d2']:.2f} goal={int(ref[s]['goal'])} aim={ref[s]['aim']:+.1f} (median aim of {len(rh)} held reference takes {med:+.1f})")
