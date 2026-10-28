#!/usr/bin/env python3
"""gm-pick-2026-10-28.py <gale|moon> <tag>: picks the takes for the clip cut from batch a (new = prefix gnew/mnew, ref = gref/mref). prints
  NEW <take> success=<0/1> fwd_end=<m> lean_med=<deg> lean_max=<deg> wind_held=<N> bound_ms=<ms> flights=<n> fall_t=<s|nan> fell=<0/1>
  REF <take> ... (same fields)
NEW = the SUCCESS take (held and forward progress >= the verdict's bar) with the largest median lean (gale) / the most flights then the largest forward progress (moon); if there is no success take: the take with the
largest wind held (gale) / forward progress (moon), flagged success=0 so the cutter refuses a claim caption. REF = the reference take whose wind held (gale) / forward progress (moon) is the MEDIAN of the reference takes
(the typical \"before\", never the worst). only takes with an mp4 count.
"""
import importlib.util, os, statistics, sys

P = os.path.expanduser('~/Pollen')
spec = importlib.util.spec_from_file_location('gms', f'{P}/gm-score-2026-10-28.py'); gms = importlib.util.module_from_spec(spec); spec.loader.exec_module(gms)
mode, tag = sys.argv[1], sys.argv[2]
pf = 'g' if mode == 'gale' else 'm'; EP = 14.0 if mode == 'gale' else 10.0
FWD_MIN = float(os.environ.get('GM_FWD_MIN', '0.25' if mode == 'gale' else '1.00'))
d = f'{P}/clips/proof-{mode}-a-{tag}'


def takes(pre):
    return {x['name']: x for x in (y for y in gms.load(d, pre, EP) if y) if os.path.exists(f'{d}/{x["name"]}.mp4')}


def show(tag_, x, succ):
    print(f"{tag_} {x['name']} success={int(succ)} fwd_end={x['fwd_end']:.2f} lean_med={x['lean_med']:.1f} lean_max={x['lean_max']:.1f} wind_held={x['wind_held']:.2f} bound_ms={x['bound_ms']} flights={x['n_flights']} fall_t={x['fall_t']:.1f} fell={int(x['fell'])}")


new = takes(f'{pf}new'); ref = takes(f'{pf}ref')
if not new: sys.exit('NO_NEW_TAKE')
ok = {k: v for k, v in new.items() if v['held'] and v['fwd_end'] >= FWD_MIN}
if ok:
    key = (lambda k: (ok[k]['lean_med'], ok[k]['fwd_end'])) if mode == 'gale' else (lambda k: (ok[k]['n_flights'], ok[k]['fwd_end']))
    k = max(ok, key=key); show('NEW', new[k], True)
else:
    key = (lambda k: new[k]['wind_held']) if mode == 'gale' else (lambda k: new[k]['fwd_end'])
    k = max(new, key=key); show('NEW', new[k], False)
if not ref: sys.exit('NO_REF_TAKE')
m = (lambda x: x['wind_held']) if mode == 'gale' else (lambda x: x['fwd_end'])
med = statistics.median(m(x) for x in ref.values()); s = min(ref, key=lambda n: abs(m(ref[n]) - med))
show('REF', ref[s], ref[s]['held'] and ref[s]['fwd_end'] >= FWD_MIN)
print(f"(median {'wind held' if mode == 'gale' else 'forward progress'} of {len(ref)} reference takes {med:.2f})")
