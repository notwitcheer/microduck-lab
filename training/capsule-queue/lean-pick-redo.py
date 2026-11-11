#!/usr/bin/env python3
"""lean-pick-redo.py: the 09z42 checkpoint PICK rule at the REDO sample size (written 2026-11-11, before any redo take).

why this exists: the first proof pass swept 12 checkpoints with 4 takes each, twice (the missing DRYRUN guard), and the two
sweeps of the same checkpoints picked different winners (c10000 then c8250) while the same checkpoint moved ~2 deg. per-take
lean sd is 1.6-3.5 deg, so a 4-take median cannot rank checkpoints. sample size only changes here; the metric, the 12.6 deg
bar, the ladder and the verdict words are untouched.

sweep: model_<LO>..model_<HI> every 250 it (default 7250..10000), 10 takes each at 3.0 N, gm_play, new policy only.
  dirs: proof-p<PEAK>-<SWEEP_TAG>-c<N> (SWEEP_TAG default sweep2; the 09z45 re-check uses sweep3, HI 13000).
  eligible = held >= 8 of 10 at 3.0 N (the same 75% proportion as the original 3 of 4).
  PICK     = eligible checkpoint with the highest median pitch of its held takes (ties -> the LATER checkpoint).
  no eligible checkpoint -> PICK none: the frozen verdict runs on the highest checkpoint in the range.
  each row prints a bootstrap 95% CI of the held-take median; if the top two CIs overlap the script prints
  'PICK UNDETERMINED' and a RUNNERUP line: a readout flag, never a change to a verdict word.
env: SWEEP_TAG, SWEEP_LO (7250), SWEEP_HI (10000), SWEEP_N (10), SWEEP_ELIG (8), SWEEP_PEAK (3.0).
usage: python3 lean-pick-redo.py
"""
import importlib.util, os, random, statistics as s

P = os.path.expanduser('~/Pollen')
spec = importlib.util.spec_from_file_location('gms', f'{P}/gm-score-2026-10-28.py')
gms = importlib.util.module_from_spec(spec); spec.loader.exec_module(gms)

EP = 14.0
N = int(os.environ.get('SWEEP_N', '10'))
ELIG = int(os.environ.get('SWEEP_ELIG', '8'))
THR = 12.6
TAG = os.environ.get('SWEEP_TAG', 'sweep2')
PEAK = os.environ.get('SWEEP_PEAK', '3.0')
LO = int(os.environ.get('SWEEP_LO', '7250'))
HI = int(os.environ.get('SWEEP_HI', '10000'))
CKPTS = list(range(LO, HI + 1, 250))


def boot(vals, n=2000, seed=20261111):
    r = random.Random(seed)
    ms = sorted(s.median(r.choices(vals, k=len(vals))) for _ in range(n))
    return ms[int(0.025 * n)], ms[int(0.975 * n) - 1]


rows = []
for c in CKPTS:
    d = f'{P}/lean-09z42/proof-p{PEAK}-{TAG}-c{c}'
    xs = [x for x in gms.load(d, 'lnew', EP) if x] if os.path.isdir(d) else []
    held = [x['lean_med'] for x in xs if x['held']]
    med = s.median(held) if held else float('nan')
    lo, hi = boot(held) if len(held) >= 3 else (float('nan'), float('nan'))
    rows.append(dict(c=c, n=len(xs), h=len(held), med=med, lo=lo, hi=hi,
                     elig=(len(xs) == N and len(held) >= ELIG)))

print('ckpt   takes held  median_pitch_held(deg)  95% CI (bootstrap)  eligible')
for r in rows:
    print(f"{r['c']:>5}  {r['n']:>5} {r['h']:>4}  {r['med']:>+10.2f}   [{r['lo']:>+6.2f}, {r['hi']:>+6.2f}]   "
          f"{'yes' if r['elig'] else 'no'}")

elig = [r for r in rows if r['elig']]
for r in elig:
    if r['med'] >= THR:
        print(f"DRIFT FLAG c={r['c']}: median pitch {r['med']:+.2f} deg >= {THR} deg with {r['h']}/{r['n']} held at 3.0 N")

if not elig:
    print(f'PICK none (no checkpoint holds >= {ELIG} of {N} at 3.0 N): frozen verdict runs on model_10000')
else:
    ranked = sorted(elig, key=lambda r: (r['med'], r['c']), reverse=True)
    best = ranked[0]
    print(f"PICK c={best['c']} (median pitch {best['med']:+.2f} deg, {best['h']}/{best['n']} held at 3.0 N, "
          f"95% CI [{best['lo']:+.2f}, {best['hi']:+.2f}])")
    if len(ranked) > 1:
        second = ranked[1]
        overlap = not (best['lo'] > second['hi'] or second['lo'] > best['hi'])
        if overlap:
            print(f"PICK UNDETERMINED: c={second['c']} (median {second['med']:+.2f} deg, "
                  f"95% CI [{second['lo']:+.2f}, {second['hi']:+.2f}]) overlaps the pick's CI")
            print(f"RUNNERUP c={second['c']}")
    spread = [r['med'] for r in elig]
    print(f'eligible spread: {min(spread):+.2f} to {max(spread):+.2f} deg over {len(elig)} checkpoints '
          f'(bar {THR} deg)')
