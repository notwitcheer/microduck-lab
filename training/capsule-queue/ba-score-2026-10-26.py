#!/usr/bin/env python3
# ba-score-2026-10-26.py: 09z12 (giant-ball kick that AIMS) verdict scoring, bk-score shape. take logs from proof-ba-{a,b,c}.sh (headless_play, 0.1 s samples, 6 s episodes).
# new = duckbigaim model_19000 (take prefix ban{a,b,c}), ref = the 09z10 giant-ball kick duckbigkick model_16000 (its seed, take prefix bkr{a,b,c}); the reference is RE-TAKEN, not reused from proof-bk.
# held   = no tilt fall (grav_b z > -0.5 at any sample before the end) and no RESET before t = 5.9 s (the 6 s time-out RESET at ~5.98 s is the end).
# goal   = the ball centre was ever inside the goal mouth footprint (1.40 <= x <= 1.80, |y| < 0.50, z < 0.50) at any 0.1 s sample of the episode; the goal exists only in batches a and b.
# power  = ball planar travel from its start >= 1.25 m at t = 2.0 s (the pre-registered power threshold of 09z10/09z11).
# PRE-REGISTERED (written 2026-10-26 before any take of the 3,000-iteration policy; the 200-iteration sweep checkpoints were taken earlier, only to choose the aim weight, and are not the verdict policy):
#   A  GAIN CONDITION  batch a (giant ball + goal, no shoves, 15 takes per policy): success = held AND goal. new vs ref, one-sided exact Fisher, p < 0.05.
#   P  POWER NO-LOSS   the same batch-a takes: success = held AND power. two-sided exact Fisher; a loss = p < 0.05 with new lower.
#   C  SMALL BALL      batch c (stock 70 mm task, random heading, no shoves, 10 takes per policy): success = held AND ball >= 1.0 m from its start by 3 s. two-sided; a loss = p < 0.05 with new lower.
#   B  reported only   batch b (giant ball + goal + the maker's play shoves, 10 takes per policy): held AND goal, and held AND power, no verdict weight.
#   VERDICT = GAIN iff A p < 0.05 and no loss on P and C; otherwise NO GAIN (the loss is named when present). with n = 15 per policy, A needs new >= 6/15 goals against a reference at 1/15 (p 0.040; 5/15 gives p 0.084);
#   the power check only flags a loss at <= 2/15 against 9/15 (p 0.021), so a NOTE line is printed whenever the new power count is under half the reference's.
#   also printed, not in the verdict: median aim of the ball displacement at 1.5 s (deg off +x, the heading), share inside +-20 deg, travel at 1 s / 2 s.
# usage: python3 ba-score-2026-10-26.py                      (verdict from ~/Pollen/clips/proof-ba-{a,b,c}-$PROOF_TAG)
#        python3 ba-score-2026-10-26.py --dir <dir> <prefix>  (per-take table + medians for one policy's takes, used for the pre-training probes)
import glob, math, os, re, statistics, sys
from math import comb
TAG = os.environ.get('PROOF_TAG', '2026-10-26'); NTAKES = {'a': 15, 'b': 10, 'c': 10}
if os.environ.get('PROOF_N'): NTAKES = {k: int(os.environ['PROOF_N']) for k in 'abc'}   # test hook, default = the real run
S = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([-\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\) ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
A0 = re.compile(r'after reset:.*?ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
R = re.compile(r'RESET at t=\s*([\d.]+)')
END = 5.95
def goal_in(x, y, z): return 1.40 <= x <= 1.80 and abs(y) < 0.50 and z < 0.50
def take(f):
    t = open(f, errors='replace').read(); a0 = A0.search(t)
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
    goal = any(goal_in(r[4], r[5], r[6]) for r in rows)
    return dict(held=held, goal=goal, kicked=d3 >= 1.0, aim=aim, d1=d1, d2=d2, power=d2 >= 1.25)
def f1(a, n1, b, n2):
    K = a + b; N = n1 + n2
    return sum(comb(n1, x) * comb(n2, K - x) for x in range(a, min(n1, K) + 1)) / comb(N, K)
def f2(a, n1, b, n2):
    K = a + b; N = n1 + n2; p0 = comb(n1, a) * comb(n2, b)
    return min(1.0, sum(comb(n1, x) * comb(n2, K - x) for x in range(max(0, K - n2), min(n1, K) + 1) if comb(n1, x) * comb(n2, K - x) <= p0 * (1 + 1e-9)) / comb(N, K))
def med(v): return statistics.median(v) if v else float('nan')
def summary(nm, xs, goal_cond):
    s = f'{nm} held {sum(x["held"] for x in xs)}/{len(xs)}'
    if goal_cond: s += f' goal {sum(x["goal"] for x in xs)}/{len(xs)} held&goal {sum(x["held"] and x["goal"] for x in xs)}/{len(xs)} power {sum(x["power"] for x in xs)}/{len(xs)} held&power {sum(x["held"] and x["power"] for x in xs)}/{len(xs)} in+-20deg {sum(abs(x["aim"]) <= 20 for x in xs)}/{len(xs)}'
    else: s += f' kicked {sum(x["kicked"] for x in xs)}/{len(xs)}'
    return s + f' median aim {med([x["aim"] for x in xs]):+.1f} deg, travel@1s {med([x["d1"] for x in xs]):.2f} m @2s {med([x["d2"] for x in xs]):.2f} m'
if len(sys.argv) > 1 and sys.argv[1] == '--dir':
    d, pre = os.path.expanduser(sys.argv[2]), sys.argv[3]; xs = []
    for f in sorted([g for g in glob.glob(f'{d}/{pre}-t*.log') if not g.endswith('.full.log')], key=lambda p: int(re.search(r'-t(\d+)\.log$', p)[1])):
        x = take(f)
        if x: xs.append(x); print(f'  {os.path.basename(f)[:-4]:>10} held={int(x["held"])} goal={int(x["goal"])} aim@1.5s={x["aim"]:+6.1f} d1={x["d1"]:.2f} d2={x["d2"]:.2f}')
    if xs: print(summary(pre, xs, True))
    sys.exit(0)
res = {}
for c in 'abc':
    d = os.path.expanduser(f'~/Pollen/clips/proof-ba-{c}-{TAG}'); out = {}
    for f in sorted(glob.glob(d + '/*-t*.log')):
        if f.endswith('.full.log'): continue
        out.setdefault(os.path.basename(f).split('-')[0], []).append(take(f))
    me, ri = out.get(f'ban{c}', []), out.get(f'bkr{c}', [])
    nn, ns = [x for x in me if x], [x for x in ri if x]
    if not nn or not ns: print(f'{c}: no takes yet'); res[c] = None; continue
    def cnt(xs, key): return sum(bool(key(x)) for x in xs)
    keys = {'a': {'A goal': lambda x: x['held'] and x['goal'], 'P power': lambda x: x['held'] and x['power']},
            'b': {'B goal': lambda x: x['held'] and x['goal'], 'B power': lambda x: x['held'] and x['power']},
            'c': {'C small ball': lambda x: x['held'] and x['kicked']}}[c]
    res[c] = {}
    print(f'{c}: n new {len(nn)} ref {len(ns)}  no-sample takes new {len(me)-len(nn)} ref {len(ri)-len(ns)}')
    for nm, k in keys.items():
        a, n1, b, n2 = cnt(nn, k), len(nn), cnt(ns, k), len(ns)
        p1, p2 = f1(a, n1, b, n2), f2(a, n1, b, n2); res[c][nm[0]] = (a, n1, b, n2, p1, p2)
        print(f'   {nm}: new {a}/{n1} vs ref {b}/{n2}  one-sided p={p1:.4f}  two-sided p={p2:.4f}')
    print('   new :', summary('new', nn, c in 'ab')); print('   ref :', summary('ref', ns, c in 'ab'))
full = all(res.get(c) and res[c][{'a': 'A', 'b': 'B', 'c': 'C'}[c]][1] == NTAKES[c] and res[c][{'a': 'A', 'b': 'B', 'c': 'C'}[c]][3] == NTAKES[c] for c in 'abc')
if full:
    gain = res['a']['A'][4] < 0.05
    loss = [nm for nm, r in (('power', res['a']['P']), ('small ball', res['c']['C'])) if r[5] < 0.05 and r[0] / r[1] < r[2] / r[3]]
    pw = res['a']['P']
    if pw[0] * 2 < pw[2]: print(f'NOTE: power count {pw[0]}/{pw[1]} is under half of the reference {pw[2]}/{pw[3]} (p two-sided {pw[5]:.3f}); with n=15 only <= 2 of 15 against 9 of 15 flags a loss, so read the power medians before any claim that the power was kept')
    print('VERDICT:', ('GAIN' if gain and not loss else 'NO GAIN') + (f' (loss on {", ".join(loss)})' if loss else ''))
else:
    print('VERDICT: incomplete (not every condition has its full new + ref takes yet)')
