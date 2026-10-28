#!/usr/bin/env python3
"""gm-verdict-2026-10-28.py <gale|moon> [tag]: the PRE-REGISTERED verdict of 09z19 (gale) / 09z21 (moon), from the proof batches' take logs (gm-score-2026-10-28.py definitions).
frozen BEFORE any take of the 3,000-iteration policy existed (vault 60-robotics/microduck/log.md 2026-10-28; the design probes in gm-probe/ are evidence, not the verdict).
  A  GAIN condition, 15 takes per policy, 1 env, forced vx 0.25 m/s, NO shoves:
       gale: wind ramp 0 -> 3.0 N over 12 s then held, 14 s takes. success = held (no RESET before the end, trunk tilt <= 60 deg at every step) AND forward progress at the end >= 0.25 m (mean of the last 0.5 s).
       moon: gravity 1.62 m/s^2, 10 s takes.  success = held AND forward progress at the end >= 1.00 m (the untrained seed's own pace on Earth in the same protocol: median 1.18 m, 9 of 12 takes reach 1.00 m; on the Moon the seed's median is 0.45 m and 0 of 12 reach it, CPU takes 2026-10-28).
     one-sided exact Fisher p < 0.05 on the success counts, new vs ref. (reference 0/15 needs new >= 4/15, p 0.0498.)
  B  reported, not in the verdict: gale = the same wind with the maker's play shoves, 10 takes per policy; moon = Mars gravity 3.71, no shoves, 10 takes per policy (same success rule). plus bounds (flights >= 80 ms), lean, wind held.
  C  no loss, stock walk task on Earth with the maker's play shoves, forced vx 0.25, 20 s, 10 takes per policy: held counts, two-sided exact Fisher; a LOSS = p < 0.05 with new lower.
  VERDICT = GAIN iff A p < 0.05 and no loss on C, else NO GAIN (the failing part named). INCOMPLETE until every batch has its take count (A 15 each, C 10 each).
env hooks (e2e only): PROOF_TAG, PROOF_N (A take count, C/B n = min(10, PROOF_N)), GM_FWD_MIN.
"""
import importlib.util, os, sys

P = os.path.expanduser('~/Pollen')
spec = importlib.util.spec_from_file_location('gms', f'{P}/gm-score-2026-10-28.py'); gms = importlib.util.module_from_spec(spec); spec.loader.exec_module(gms)
mode = sys.argv[1]; tag = sys.argv[2] if len(sys.argv) > 2 else os.environ.get('PROOF_TAG', '2026-10-28')
pf = 'g' if mode == 'gale' else 'm'
EPA = 14.0 if mode == 'gale' else 10.0
FWD_MIN = float(os.environ.get('GM_FWD_MIN', '0.25' if mode == 'gale' else '1.00'))
NA = int(os.environ.get('PROOF_N', '15')); NBC = min(10, NA)


def batch(cond, pre, ep):
    d = f'{P}/clips/proof-{mode}-{cond}-{tag}'
    return gms.load(d, pre, ep)


def succ(x): return bool(x['held'] and x['fwd_end'] >= FWD_MIN)


def part(name, new_all, ref_all, n, rule, two_sided=False):
    new = [x for x in new_all if x]; ref = [x for x in ref_all if x]
    miss = (len(new_all) - len(new)) + (len(ref_all) - len(ref))
    ok = len(new) == n and len(ref) == n
    a = sum(rule(x) for x in new); b = sum(rule(x) for x in ref)
    return new, ref, a, b, ok, miss


# A
newA, refA, a, b, okA, missA = part('A', batch('a', f'{pf}new', EPA), batch('a', f'{pf}ref', EPA), NA, succ)
if not newA or not refA:
    print('VERDICT: incomplete (no A takes yet)'); sys.exit(0)
pA = gms.f1(a, len(newA), b, len(refA))
print(f'A (GAIN condition, {mode}, no shoves, n {len(newA)}/{len(refA)}, no-log takes {missA}): success = held and forward progress >= {FWD_MIN:.2f} m at the end')
print(f'   A success: new {a}/{len(newA)} vs ref {b}/{len(refA)}  one-sided p={pA:.4f}')
print('   new  ', gms.summary('new', newA)); print('   ref  ', gms.summary('ref', refA))
for x in newA: print(gms.row(x))
# B
bn, br = batch('b', f'{pf}bnew', EPA), batch('b', f'{pf}bref', EPA)
newB = [x for x in bn if x]; refB = [x for x in br if x]
if newB and refB:
    aB = sum(succ(x) for x in newB); bB = sum(succ(x) for x in refB)
    print(f'B (reported only, {"wind + shoves" if mode == "gale" else "Mars gravity 3.71"}, n {len(newB)}/{len(refB)}): success new {aB}/{len(newB)} vs ref {bB}/{len(refB)}  one-sided p={gms.f1(aB, len(newB), bB, len(refB)):.4f}')
    print('   new  ', gms.summary('new', newB)); print('   ref  ', gms.summary('ref', refB))
else:
    print('B (reported only): no takes')
# C
cn, cr = batch('c', f'{pf}cnew', 20.0), batch('c', f'{pf}cref', 20.0)
newC = [x for x in cn if x]; refC = [x for x in cr if x]
okC = len(newC) == NBC and len(refC) == NBC
loss = None
if newC and refC:
    hn = sum(x['held'] for x in newC); hr = sum(x['held'] for x in refC)
    p2 = gms.f2(hn, len(newC), hr, len(refC)); loss = (p2 < 0.05 and hn < hr)
    print(f'C (no loss, stock walk + shoves, Earth, n {len(newC)}/{len(refC)}): held new {hn}/{len(newC)} vs ref {hr}/{len(refC)}  two-sided p={p2:.4f}  LOSS={loss}  (direction {"down" if hn < hr else "up or equal"})')
else:
    print('C: no takes')
if not (okA and okC and loss is not None):
    print(f'VERDICT: incomplete (A takes {len(newA)}/{len(refA)} of {NA}, C takes {len(newC)}/{len(refC)} of {NBC})'); sys.exit(0)
if pA < 0.05 and not loss: print('VERDICT: GAIN')
elif pA >= 0.05: print(f'VERDICT: NO GAIN (A not significant: {a}/{len(newA)} vs {b}/{len(refA)}, p={pA:.4f})')
else: print(f'VERDICT: NO GAIN (A significant, p={pA:.4f}, but a LOSS on C: stock walk held {hn}/{len(newC)} vs {hr}/{len(refC)})')
