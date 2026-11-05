#!/usr/bin/env python3
# hop2-pickclip-2026-10-29.py <tag>: picks the takes for the 09z23 clip cut from clips/proof-hop2-a-<tag> (new = the picked checkpoint) / proof-hop2-b-<tag> (ref = the seed), same strict scorer.
#   NEW <take> flights=<n> longest=<ms> apex=<mm> lift=<mm> t=<s the longest strict flight starts> success=<0/1> (success <k>/<n>)
#   REF <take> apex=<mm> (median apex of the reference takes)
# NEW = the SUCCESS take with the highest trunk apex (needs an mp4); no success take -> the take with the longest strict flight, flagged success=0 so the cutter refuses a hop caption.
import importlib.util, os, statistics, sys
P = os.path.expanduser('~/Pollen')
spec = importlib.util.spec_from_file_location('h2s', f'{P}/hop2-score-2026-10-29.py'); h2s = importlib.util.module_from_spec(spec); spec.loader.exec_module(h2s)
tag = sys.argv[1]
def takes(d, pre):
    out = {}
    for x in h2s.load(d, pre):
        if not os.path.exists(f'{os.path.expanduser(d)}/{x["name"]}.mp4'): continue
        t = open(f'{os.path.expanduser(d)}/{x["name"]}.log', errors='replace').read()
        rows = [dict(k=int(m[1]), t=float(m[2]), n=int(m[3]), z=float(m[4]), tilt=float(m[5])) for m in h2s.S.finditer(t)]
        rows = [r for r in rows if r['t'] <= 5.94]
        runs = [r for r in h2s.runs_of(rows, lambda r: r['n'] == 0 and r['z'] >= h2s.Z_STAND + h2s.LIFT) if len(r) >= h2s.MIN_STEPS]
        best = max(runs, key=len) if runs else None
        x['t0'] = best[0]['t'] if best else 0.0
        out[x['name']] = x
    return out
new = takes(f'{P}/clips/proof-hop2-a-{tag}', 'hnew'); ref = takes(f'{P}/clips/proof-hop2-b-{tag}', 'href')
if not new: sys.exit('NO_NEW_TAKE')
succ = {k: v for k, v in new.items() if v['success']}
k = max(succ, key=lambda n: succ[n]['apex']) if succ else max(new, key=lambda n: (new[n]['flight_ms'], new[n]['apex']))
v = new[k]
print(f"NEW {k} flights={v['n_strict']} longest={v['flight_ms']} apex={v['apex']:.1f} lift={v['apex_lift']:.1f} t={v['t0']:.2f} success={int(v['success'])} (success {len(succ)}/{len(new)})")
if not ref: sys.exit('NO_REF_TAKE')
med = statistics.median(x['apex'] for x in ref.values()); s = min(ref, key=lambda n: abs(ref[n]['apex'] - med)); r = ref[s]
print(f"REF {s} apex={r['apex']:.1f} flights={r['n_strict']} (median apex of {len(ref)} reference takes {med:.1f} mm)")
