#!/usr/bin/env python3
# bk-score-2026-10-24.py: 09z10 (giant-ball kick) verdict scoring, z8 scorer shape. take logs from proof-bk-{a,b,c}.sh (headless_play, 0.1 s samples, 6 s episodes).
# held   = no tilt fall (grav_b z > -0.5 at any sample before the end) and no RESET before t = 5.9 s (the 6 s time-out RESET at ~5.98 s is the end).
# a, b   = GIANT ball (r 0.15 m, 0.275 kg) with the goal (mouth line x 1.4 m, y +-0.50, depth 0.40, height 0.50, face_goal yaw 0): success = held AND the ball
#          travelled >= 1.25 m (planar, from its start) by t = 2.0 s. 1.25 m is the seed's own median at 2 s on the maker's 70 mm ball (32 takes), so "success" reads
#          "kicks the giant ball as far in 2 s as the seed kicked the small one"; the seed on the giant ball had a median of 0.74 m (max 0.86 of 6 takes), chosen from
#          the seed's feasibility takes BEFORE the item was queued. Also reported, not in the verdict: goal (ball centre ever inside 1.40 <= x <= 1.80, |y| < 0.50,
#          z < 0.50), median travel at 1 s and 2 s, median aim angle of the displacement at 1.5 s (deg off +x).
# c      = stock small-ball task, random heading: success = held AND ball >= 1.0 m (planar) from its start by t = 3.0 s (the no-loss check).
# pre-registered: a = new vs seed one-sided (gain); c = no-loss, two-sided (a loss = significant with new lower); b (play shoves) reported, not in the verdict.
# verdict line: GAIN if a one-sided p < 0.05 and no loss on c; NO GAIN otherwise (loss named when present). exact Fisher via math.comb.
import glob, math, os, re, statistics
TAG = os.environ.get('PROOF_TAG', '2026-10-24'); NTAKES = {'a': 15, 'b': 10, 'c': 10}
if os.environ.get('PROOF_N'): NTAKES = {k: int(os.environ['PROOF_N']) for k in 'abc'}   # test hook, default = the real run
from math import comb
S = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([-\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\) ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
A0 = re.compile(r'after reset:.*?ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
R = re.compile(r'RESET at t=\s*([\d.]+)')
END = 5.95
def goal_in(x, y, z): return 1.40 <= x <= 1.80 and abs(y) < 0.50 and z < 0.50
def take(f, cond):
    t = open(f, errors='replace').read()
    a0 = A0.search(t)
    rows = [(float(m[1]), float(m[3]), float(m[4]), float(m[5]), float(m[6]), float(m[7]), float(m[8])) for m in S.finditer(t)]   # t, gx, gy, gz, bx, by, bz
    rows = [r for r in rows if r[0] <= END]
    if not a0 or not rows: return None
    sx, sy = float(a0[1]), float(a0[2])
    rs = [float(x) for x in R.findall(t) if float(x) < 5.9]
    falls, st = 0, 'up'
    for r in rows:
        if st == 'up' and r[3] > -0.5: falls += 1; st = 'down'
        elif st == 'down' and r[3] < -0.9: st = 'up'
    held = falls == 0 and not rs
    def at(tt): return min(rows, key=lambda r: abs(r[0] - tt))
    d3 = max(math.hypot(r[4] - sx, r[5] - sy) for r in rows if r[0] <= 3.0)
    r15, r10, r20 = at(1.5), at(1.0), at(2.0)
    d1 = math.hypot(r10[4] - sx, r10[5] - sy); d2 = math.hypot(r20[4] - sx, r20[5] - sy)
    aim = math.degrees(math.atan2(r15[5] - sy, r15[4] - sx))
    spd = math.hypot(r10[4] - sx, r10[5] - sy) / max(r10[0], 0.1)
    last = rows[-1]
    goal = any(goal_in(r[4], r[5], r[6]) for r in rows)
    kicked = d3 >= 1.0
    return dict(held=held, goal=goal, kicked=kicked, aim=aim, spd=spd, d1=d1, d2=d2, power=d2 >= 1.25, ok=(held and (d2 >= 1.25 if cond in 'ab' else kicked)))
def f1(a, n1, b, n2):
    K = a + b; N = n1 + n2
    return sum(comb(n1, x) * comb(n2, K - x) for x in range(a, min(n1, K) + 1)) / comb(N, K)
def f2(a, n1, b, n2):
    K = a + b; N = n1 + n2; p0 = comb(n1, a) * comb(n2, b)
    return min(1.0, sum(comb(n1, x) * comb(n2, K - x) for x in range(max(0, K - n2), min(n1, K) + 1) if comb(n1, x) * comb(n2, K - x) <= p0 * (1 + 1e-9)) / comb(N, K))
def med(v): return statistics.median(v) if v else float('nan')
res = {}
for c in 'abc':
    d = os.path.expanduser(f'~/Pollen/clips/proof-bk-{c}-{TAG}'); out = {}
    for f in sorted(glob.glob(d + '/*-t*.log')):
        if f.endswith('.full.log'): continue
        pol = os.path.basename(f).split('-')[0]
        out.setdefault(pol, []).append(take(f, c))
    me, ri = out.get(f'bkn{c}', []), out.get(f'bks{c}', [])
    nn, ns = [x for x in me if x], [x for x in ri if x]
    a, n1, b, n2 = sum(x['ok'] for x in nn), len(nn), sum(x['ok'] for x in ns), len(ns)
    if not n1 or not n2: print(f'{c}: no takes yet'); res[c] = None; continue
    p1, p2 = f1(a, n1, b, n2), f2(a, n1, b, n2); res[c] = (a, n1, b, n2, p1, p2)
    def line(nm, xs): return (f'{nm} held {sum(x["held"] for x in xs)}/{len(xs)} kicked {sum(x["kicked"] for x in xs)}/{len(xs)}'
                              + (f' goal {sum(x["goal"] for x in xs)}/{len(xs)} power {sum(x["power"] for x in xs)}/{len(xs)}' if c in 'ab' else '') + f' median aim {med([x["aim"] for x in xs]):+.1f} deg, travel@1s {med([x["d1"] for x in xs]):.2f} m @2s {med([x["d2"] for x in xs]):.2f} m')
    print(f'{c}: new {a}/{n1} vs seed {b}/{n2}  one-sided p={p1:.4f}  two-sided p={p2:.4f}  no-sample takes new {len(me)-n1} seed {len(ri)-n2}')
    print(f'   new  : {line("new ", nn)}'); print(f'   seed : {line("seed", ns)}')
if all(res.get(c) and res[c][1] == NTAKES[c] and res[c][3] == NTAKES[c] for c in 'abc'):
    gain = res['a'][4] < 0.05
    loss = [c for c in 'c' if res[c][5] < 0.05 and res[c][0] / res[c][1] < res[c][2] / res[c][3]]
    print('VERDICT:', ('GAIN' if gain and not loss else 'NO GAIN') + (f' (loss on {",".join(loss)})' if loss else ''))
else:
    print('VERDICT: incomplete (not every condition has its full new + seed takes yet)')
