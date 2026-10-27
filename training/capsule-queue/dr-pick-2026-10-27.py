#!/usr/bin/env python3
# dr-pick-2026-10-27.py <batch dir> [new-prefix ref-prefix]: picks the takes for the 09z14 clip cut from proof-dr-a (dribble condition, goal at 1.8 m, no shoves). reads takes with dr-score-2026-10-27.py.
# prints "NEW <take> carried=<0/1> goal=<t or -> streak=<s> near=<f> first_far=<s or ->" and "REF <take> ...".
# NEW = the held CARRIED take with the EARLIEST goal time (the quickest clean walk-in); if no take is CARRIED: the held take with the longest near streak, flagged carried=0 so the cut script never burns a goal caption.
# REF = the held reference take whose longest near streak is the MEDIAN of the reference's held takes: the typical "before" (the ball leaves its reach at first_far), never the worst.
import glob, importlib.util, os, statistics, sys
d = sys.argv[1]; pn, pr = (sys.argv[2], sys.argv[3]) if len(sys.argv) > 3 else ('dra', 'drsa')
spec = importlib.util.spec_from_file_location('drs', '/home/witcheer/Pollen/dr-score-2026-10-27.py'); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def takes(prefix):
    return {r['name']: r for r in m.load(d, prefix, False) if os.path.exists(f"{d}/{r['name']}.mp4")}
new, ref = takes(pn), takes(pr)
held = {k: v for k, v in new.items() if v['held']}
if not held: sys.exit('NO_HELD_NEW_TAKE')
car = {k: v for k, v in held.items() if v['ok']}
k = min(car, key=lambda n: car[n]['t_goal']) if car else max(held, key=lambda n: held[n]['streak_s'])
f = lambda v: '-' if v is None else f'{v:.1f}'
def row(tag, n, v): return f"{tag} {n} carried={int(v['ok'])} goal={f(v['t_goal'])} streak={v['streak_s']:.1f} near={v['near_frac']:.2f} first_far={f(v['first_far'])}"
print(row('NEW', k, new[k]) + f' (held {len(held)}/{len(new)}, carried {len(car)}/{len(new)})')
rh = {k2: v for k2, v in ref.items() if v['held']}
if not rh: sys.exit('NO_HELD_REF_TAKE')
med = statistics.median(v['streak_s'] for v in rh.values())
s = min(rh, key=lambda n: abs(rh[n]['streak_s'] - med))
print(row('REF', s, ref[s]) + f' (median longest near streak of {len(rh)} held reference takes {med:.1f} s)')
