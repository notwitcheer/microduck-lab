#!/usr/bin/env python3
# hop-pick-2026-10-27.py <tag>: picks the takes for the 09z16 clip cut from proof-hop-a (new) / proof-hop-b (ref). prints
#   "NEW <take> hops=<n> longest=<ms> foot=<mm> t=<s of the longest flight start> train=<0/1 success>"  and  "REF <take> hops=.. longest=.. foot=.. t=.."
# NEW = the SUCCESS take (>= 2 hops, upright at the end) with the largest peak foot lift; if there is no success take: the take with the longest flight, flagged success=0 so the cutter refuses a hop caption.
# REF = the reference take whose peak foot lift is the MEDIAN of the reference takes (the typical "before", never the best).
import glob, importlib.util, os, re, statistics, sys
tag = sys.argv[1]; P = os.path.expanduser('~/Pollen')
spec = importlib.util.spec_from_file_location('hs', f'{P}/hop-score-2026-10-27.py'); src = open(f'{P}/hop-score-2026-10-27.py').read().split("if len(sys.argv) > 1 and sys.argv[1] == '--dir':")[0]
ns = {'__name__': 'hs', 'sys': sys}; exec(compile(src, 'hs', 'exec'), ns)
H = ns['H']
def longest(f):
    rows = [(int(m[1]), float(m[2]), int(m[3]), float(m[6]), float(m[9])) for m in H.finditer(open(f, errors='replace').read())]
    best, cur = (0, 0.0), []
    for r in rows + [(-1, 0, 0, 0, 0)]:
        if r[0] >= ns['SETTLE'] and r[2] == 1 and r[3] < 35: cur.append(r)
        else:
            if len(cur) > best[0]: best = (len(cur), cur[0][1])
            cur = []
    return best[0] * 20, best[1]
def takes(d, pre):
    out = {}
    for f in sorted(glob.glob(f'{d}/{pre}-t*.log')):
        if f.endswith('.full.log'): continue
        n = os.path.basename(f)[:-4]; x = ns['take'](f)
        if x and os.path.exists(f'{d}/{n}.mp4'): x['air'], x['t0'] = longest(f); out[n] = x
    return out
new = takes(f'{P}/clips/proof-hop-a-{tag}', 'hnew'); ref = takes(f'{P}/clips/proof-hop-b-{tag}', 'href')
if not new: sys.exit('NO_NEW_TAKE')
succ = {k: v for k, v in new.items() if v['success']}
k = max(succ, key=lambda n: succ[n]['foot_mm']) if succ else max(new, key=lambda n: new[n]['air'])
v = new[k]; print(f"NEW {k} hops={v['n_hops']} longest={v['air']} foot={v['foot_mm']:.1f} t={v['t0']:.2f} success={int(v['success'])} (success {len(succ)}/{len(new)})")
if not ref: sys.exit('NO_REF_TAKE')
med = statistics.median(x['foot_mm'] for x in ref.values()); s = min(ref, key=lambda n: abs(ref[n]['foot_mm'] - med)); r = ref[s]
print(f"REF {s} hops={r['n_hops']} longest={r['air']} foot={r['foot_mm']:.1f} t={r['t0']:.2f} (median peak foot lift of {len(ref)} reference takes {med:.1f} mm)")
