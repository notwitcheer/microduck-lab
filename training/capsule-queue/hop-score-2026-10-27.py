#!/usr/bin/env python3
# hop-score-2026-10-27.py: 09z16 (Microduck HOP) take scoring. take logs from hop_play.py --hop-log: one `[hop] k= t= air= z= fz= tilt= tq= fl= fr=` line per 20 ms policy step.
# definitions (settle window: the first 12 steps = 0.24 s are ignored, the spawn drops ~8 mm onto the floor; rows after t = 5.94 s are dropped: the take runs 305 steps and the 6 s time-out resets the env into a new spawn drop):
#   flight   = a run of consecutive steps with air=1 (BOTH feet have no ground contact) and tilt < 35 deg on every step of the run.
#   HOP      = a flight of >= HOP_MIN_STEPS steps (default 4 = 80 ms) whose lower sole rises >= HOP_MIN_CLEAR_MM (default 12) above its standing height at some step of the run.
#   upright  = the last 0.5 s of the take: tilt < 30 deg and trunk z > 70 mm (a landing compresses the trunk to ~85 mm; 70 mm is a collapse), and no RESET line before t = 5.9 s.
#   SUCCESS  = n_hops >= HOP_MIN_HOPS (default 3) AND upright (it left the ground at least three times, no fall, and is on its feet at the end).
#   also printed: longest flight (ms), peak lower-foot lift (mm), peak trunk lift above the 115 mm stand (mm), peak servo torque over the take (N m), torque share <= 0.60 (Robotis XL330-M288 datasheet stall at 6.0 V).
# PRE-REGISTERED (written into vault log.md BEFORE any take of the 3,000-iteration policy; see the 2026-10-27 entry for the exact thresholds and why):
#   A  GAIN CONDITION  takes: 15 per policy, 1 env, zero command, no shoves, 6 s, hop play env. new = duckhop model_<TARGET>, ref = its seed (walk-flat v2 duckvelbl model_7000) taken in the SAME env.
#      success per take as above (>= 3 hops). new vs ref one-sided exact Fisher, p < 0.05. with the reference at 0/15 that needs new >= 4/15 (p 0.0498).
#   Q  QUALITY         printed, not in the verdict: median longest flight and peak foot lift of the SUCCESS takes; share of success takes with peak torque <= 0.60 N m.
#   VERDICT = GAIN iff A p < 0.05, else NO GAIN.
# usage: python3 hop-score-2026-10-27.py                      (verdict from ~/Pollen/clips/proof-hop-a-$PROOF_TAG (hnew) and proof-hop-b-$PROOF_TAG (href))
#        python3 hop-score-2026-10-27.py --dir <dir> <prefix>  (per-take table for one policy's takes: sweeps, seed reads)
import glob, math, os, re, statistics, sys
from math import comb
TAG = os.environ.get('PROOF_TAG', '2026-10-27'); NT = int(os.environ.get('PROOF_N', '15'))
MIN_STEPS = int(os.environ.get('HOP_MIN_STEPS', '4')); MIN_CLEAR = float(os.environ.get('HOP_MIN_CLEAR_MM', '12')); MIN_HOPS = int(os.environ.get('HOP_MIN_HOPS', '3'))
H = re.compile(r'\[hop\] k=\s*(\d+) t=\s*([\d.]+) air=(\d) z=\s*([-\d.]+) fz=\s*([-\d.]+) tilt=\s*([\d.]+)(?: zl=\s*([-\d.]+) zr=\s*([-\d.]+))? tq=([\d.]+) fl=\s*([\d.]+) fr=\s*([\d.]+)')
R = re.compile(r'RESET at t=\s*([\d.]+)')
SETTLE = 12; TQ_REAL = 0.60
def take(f):
    t = open(f, errors='replace').read()
    rows = [(int(m[1]), float(m[2]), int(m[3]), float(m[4]), float(m[5]), float(m[6]), float(m[9])) for m in H.finditer(t)]  # k, t, air, z, fz, tilt, tq
    rows = [r for r in rows if r[1] <= 5.94]   # the 6 s episode ends at k=299: later rows are the NEXT episode's spawn drop (a 60 ms 'flight' at 126 mm), never a hop
    if len(rows) < 100: return None
    resets = [float(x) for x in R.findall(t) if float(x) < 5.9]
    runs, cur = [], []
    for r in rows:
        if r[0] < SETTLE: continue
        if r[2] == 1 and r[5] < 35.0: cur.append(r)
        else:
            if cur: runs.append(cur)
            cur = []
    if cur: runs.append(cur)
    hops = [x for x in runs if len(x) >= MIN_STEPS and max(y[4] for y in x) >= MIN_CLEAR]
    tail = [r for r in rows if r[1] >= rows[-1][1] - 0.5]
    upright = (not resets) and bool(tail) and all(r[5] < 30.0 and r[3] > 70.0 for r in tail)
    body = [r for r in rows if r[0] >= SETTLE]
    return dict(n_hops=len(hops), n_flights=len(runs), upright=upright, resets=len(resets), success=len(hops) >= MIN_HOPS and upright,
                air_ms=max([len(x) for x in runs] or [0]) * 20, hop_ms=max([len(x) for x in hops] or [0]) * 20,
                foot_mm=max(r[4] for r in body), lift_mm=max(r[3] for r in body) - 115.0, tq=max(r[6] for r in body),
                tq_hop=max([max(y[6] for y in x) for x in hops] or [0.0]), t_first=(hops[0][0][1] if hops else float('nan')))
def f1(a, n1, b, n2):
    K = a + b; N = n1 + n2
    return sum(comb(n1, x) * comb(n2, K - x) for x in range(a, min(n1, K) + 1)) / comb(N, K)
def med(v): return statistics.median(v) if v else float('nan')
def summary(nm, xs):
    s = [x for x in xs if x['success']]
    return (f'{nm}: success {len(s)}/{len(xs)} (n_hops>={MIN_HOPS} & upright) | takes with >=1 hop {sum(x["n_hops"] >= 1 for x in xs)}/{len(xs)} upright {sum(x["upright"] for x in xs)}/{len(xs)} resets {sum(x["resets"] > 0 for x in xs)} | '
            f'median longest flight {med([x["air_ms"] for x in xs]):.0f} ms, max {max(x["air_ms"] for x in xs)} ms | median peak foot lift {med([x["foot_mm"] for x in xs]):.1f} mm | '
            f'peak torque median {med([x["tq"] for x in xs]):.3f} N m, success takes <= {TQ_REAL} N m: {sum(x["tq"] <= TQ_REAL for x in s)}/{len(s)}')
def load(d, pre):
    out = []
    for f in sorted([g for g in glob.glob(f'{d}/{pre}-t*.log') if not g.endswith('.full.log')], key=lambda p: int(re.search(r'-t(\d+)\.log$', p)[1])):
        x = take(f)
        if x: x['name'] = os.path.basename(f)[:-4]
        out.append(x)
    return out
def row(x): return f'  {x["name"]:>10} hops={x["n_hops"]} flights={x["n_flights"]} longest={x["air_ms"]:3d}ms foot={x["foot_mm"]:5.1f}mm lift={x["lift_mm"]:+6.1f}mm tq={x["tq"]:.3f} upright={int(x["upright"])} resets={x["resets"]} success={int(x["success"])}'
if len(sys.argv) > 1 and sys.argv[1] == '--dir':
    d, pre = os.path.expanduser(sys.argv[2]), sys.argv[3]
    xs = [x for x in load(d, pre) if x]
    for x in xs: print(row(x))
    if xs: print(summary(pre, xs))
    else: print(pre, 'no takes')
    sys.exit(0)
new_all = load(os.path.expanduser(f'~/Pollen/clips/proof-hop-a-{TAG}'), 'hnew'); ref_all = load(os.path.expanduser(f'~/Pollen/clips/proof-hop-b-{TAG}'), 'href')   # batch a = the new policy, batch b = the reference (its seed), taken in the same play env
new, ref = [x for x in new_all if x], [x for x in ref_all if x]
print(f'a: n new {len(new)} ref {len(ref)}  no-log takes new {len(new_all)-len(new)} ref {len(ref_all)-len(ref)}')
if not new or not ref: print('VERDICT: incomplete (no takes yet)'); sys.exit(0)
a, n1, b, n2 = sum(x['success'] for x in new), len(new), sum(x['success'] for x in ref), len(ref)
p1 = f1(a, n1, b, n2)
print(f'   A success: new {a}/{n1} vs ref {b}/{n2}  one-sided p={p1:.4f}')
print('  ', summary('new', new)); print('  ', summary('ref', ref))
for x in new: print(row(x))
if n1 == NT and n2 == NT: print('VERDICT:', 'GAIN' if p1 < 0.05 else 'NO GAIN')
else: print('VERDICT: incomplete (not every take of the pre-registered n is in yet)')
