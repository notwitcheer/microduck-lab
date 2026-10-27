#!/usr/bin/env python3
"""dr-verdict-2026-10-27.py [tag]: the pre-registered verdict of 09z14 (the duck walks the giant ball), from the proof-dr-{a,b,c} take logs. no GPU.
VERDICT: GAIN iff A (CARRIED, dribble condition, no shoves, 15 takes per policy, new = dra vs ref = drsa) one-sided exact Fisher p < 0.05 AND no loss on C (stock walk, shoves, 10 per policy, held,
two-sided, a loss = p < 0.05 with new lower); else NO GAIN (the failing part named). B (dribble with shoves, 10 per policy) is printed, never in the verdict."""
import glob, importlib.util, os, sys
P = '/home/witcheer/Pollen'
spec = importlib.util.spec_from_file_location('drs', f'{P}/dr-score-2026-10-27.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tag = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('PROOF_TAG') or sorted(os.path.basename(p)[len('proof-dr-a-'):] for p in glob.glob(f'{P}/clips/proof-dr-a-*') if os.path.isdir(p))[-1]
print(f'dribble verdict, proof tag {tag}')
def grp(letter, new, ref, noball=False):
    d = f'{P}/clips/proof-dr-{letter}-{tag}'
    return m.load(d, new, noball), m.load(d, ref, noball)
def line(label, rs, noball=False):
    n = len(rs)
    if not n: return f'{label}: no takes'
    if noball: return f'{label}: n={n} held {sum(r["held"] for r in rs)}/{n}'
    med = lambda v: sorted(v)[len(v) // 2]
    return (f'{label}: n={n} held {sum(r["held"] for r in rs)}/{n} CARRIED {sum(r["ok"] for r in rs)}/{n} goal {sum(r["goal"] for r in rs)}/{n} '
            f'median near 1-15 s {med([r["near_frac"] for r in rs]):.2f}, median longest near streak {med([r["streak_s"] for r in rs]):.1f} s, median ball travel at 15 s {med([r["travel15"] for r in rs]):.2f} m')
an, ar = grp('a', 'dra', 'drsa'); bn, br = grp('b', 'drb', 'drsb'); cn, cr = grp('c', 'drc', 'drsc', True)
print('A  dribble, no shoves (GAIN condition)'); print('   new ' + line('dra', an)); print('   ref ' + line('drsa', ar))
sa, sb = sum(r['ok'] for r in an), sum(r['ok'] for r in ar)
pa = m.fisher_one_sided(sa, len(an), sb, len(ar)) if an and ar else float('nan')
print(f'   CARRIED {sa}/{len(an)} vs {sb}/{len(ar)}: one-sided Fisher p={pa:.4f}')
print('B  dribble with shoves (reported only)'); print('   new ' + line('drb', bn)); print('   ref ' + line('drsb', br))
if bn and br:
    x, y = sum(r['ok'] for r in bn), sum(r['ok'] for r in br)
    print(f'   CARRIED {x}/{len(bn)} vs {y}/{len(br)}: one-sided p={m.fisher_one_sided(x, len(bn), y, len(br)):.4f}')
print('C  stock walk with shoves (no-loss check)'); print('   new ' + line('drc', cn, True)); print('   ref ' + line('drsc', cr, True))
loss = False
if cn and cr:
    hn, hr = sum(r['held'] for r in cn), sum(r['held'] for r in cr)
    pc = m.fisher_two_sided(hn, len(cn), hr, len(cr)); loss = pc < 0.05 and hn / len(cn) < hr / len(cr)
    print(f'   held {hn}/{len(cn)} vs {hr}/{len(cr)}: two-sided Fisher p={pc:.4f}  LOSS={loss}')
complete = len(an) >= 15 and len(ar) >= 15 and len(cn) >= 10 and len(cr) >= 10
if not complete: print('VERDICT: INCOMPLETE (take counts short, see above)')
elif pa < 0.05 and not loss: print(f'VERDICT: GAIN (A {sa}/{len(an)} vs {sb}/{len(ar)}, p={pa:.4f}; no loss on C)')
else:
    why = []
    if not pa < 0.05: why.append(f'A not significant: {sa}/{len(an)} vs {sb}/{len(ar)}, p={pa:.4f}')
    if loss: why.append('C loss on plain walking')
    print('VERDICT: NO GAIN (' + '; '.join(why) + ')')
