#!/usr/bin/env python3
# hop2-pick-2026-10-29.py <pick dir> <out json> <iteration> [<iteration> ...]: the PRE-REGISTERED checkpoint pick of the hop2 item (09z23), run on the pick takes (4 per saved checkpoint, prefix pk<iteration>).
# RULE (fixed 2026-10-29 BEFORE any hop2 training; same spirit as the talent item's pick-ducktalent.json):
#   candidates = every saved checkpoint of the run, i.e. every 250 iterations from seed+250 to the final one (no floor: late drift is exactly what this guards against);
#   score = the number of the 4 pick takes that are STRICT SUCCESSES (hop2-score-2026-10-29.py: >= 3 strict whole-body flights, trunk >= Z_STAND + 10 mm, no fall, upright and tall at the end);
#   the pick is the checkpoint with the MOST strict successes; ties go to the higher median trunk apex over its 4 takes; still tied, the EARLIEST iteration.
#   the pick is then judged on 15 NEW takes against 15 takes of the seed (verdict, same scorer); the pick takes are never reused for the verdict.
import importlib.util, json, os, statistics, sys
P = os.path.expanduser('~/Pollen')
spec = importlib.util.spec_from_file_location('h2s', f'{P}/hop2-score-2026-10-29.py'); h2s = importlib.util.module_from_spec(spec); spec.loader.exec_module(h2s)
d, out, its = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3:]]
res = {}
for n in its:
    xs = h2s.load(d, f'pk{n}')
    if not xs:
        res[n] = dict(n_takes=0, success=0, apex_med=float('nan'), strict_total=0); continue
    res[n] = dict(n_takes=len(xs), success=sum(x['success'] for x in xs), apex_med=statistics.median(x['apex'] for x in xs), strict_total=sum(x['n_strict'] for x in xs),
                  longest_ms=max(x['flight_ms'] for x in xs), nonsole_med=statistics.median(x['nonsole_share'] for x in xs))
cand = [n for n in its if res[n]['n_takes'] > 0]
if not cand:
    sys.exit('NO_PICK_TAKES')
best = sorted(cand, key=lambda n: (-res[n]['success'], -res[n]['apex_med'], n))[0]
rule = open(__file__).read().split('# RULE', 1)[1].split('import ', 1)[0]
json.dump(dict(pick=best, per_checkpoint={str(n): res[n] for n in its}, rule='fixed 2026-10-29 before any hop2 training:' + rule), open(os.path.expanduser(out), 'w'), indent=1)
for n in its:
    r = res[n]; print(f'  it {n}: strict successes {r["success"]}/{r["n_takes"]}, strict flights {r["strict_total"]}, apex median {r["apex_med"]:.1f} mm' + (f', longest {r["longest_ms"]} ms' if r['n_takes'] else ''))
print(f'PICK {best} (successes {res[best]["success"]}/{res[best]["n_takes"]}, apex median {res[best]["apex_med"]:.1f} mm)')
