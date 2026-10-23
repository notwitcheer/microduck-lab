#!/usr/bin/env python3
"""proof-verdicts.py (2026-10-02): per-take + per-group verdicts for headless_play take logs.

usage: python3 proof-verdicts.py <dir> [--end 19.9] [--posture]
- upright = grav_b z < -0.9. a get-up (non-standing spawn) counts only if upright is HELD >= 1.0 s
  before any mid-episode RESET (a RESET is a fallen_too_long teleport or a fell_over reset, never a get-up).
- falls = tilt events (grav_b z > -0.5 after being upright), as vsrough-falls.py.
- --rise: a get-up = trunk >= 105 mm held 1 s and still >= 105 mm at the end, any tilt (StandUp stands hunched); tilt reported.
- --posture: count sit/stand switches while upright (sit < 80 mm, stand > 100 mm, hysteresis between).
"""
import glob, os, re, sys
S = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([-\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)(?:.*?r=([\d.]+)m)?')
R = re.compile(r'RESET at t=\s*([\d.]+)')
a = sys.argv[1:]; d = os.path.expanduser(a[0]); end = 19.9; posture = '--posture' in a; RISE = '--rise' in a
if '--end' in a: end = float(a[a.index('--end') + 1])
groups = {}
for f in sorted(glob.glob(d + '/*-t*.log')):
    if f.endswith('.full.log'): continue
    txt = open(f, errors='replace').read()
    v = [(float(m[1]), float(m[2]), float(m[3]), float(m[5]), float(m[6]) if m[6] else 0.0) for m in S.finditer(txt) if float(m[1]) <= end]
    if not v: print(os.path.basename(f), 'NO SAMPLES'); continue
    rs = [float(x) for x in R.findall(txt) if float(x) < end]
    first_reset = rs[0] if rs else 99
    name = os.path.basename(f)[:-4]; g = name.rsplit('-t', 1)[0]
    standing = '-standing' in name
    # first time upright is held 1.0 s, before the first reset
    t_up = None; run_start = None
    for (t, z, gx, gz, r) in v:
        if t >= first_reset: break
        if gz < -0.9:
            run_start = t if run_start is None else run_start
            if t - run_start >= 1.0: t_up = run_start; break
        else: run_start = None
    t_rise = None; rs0 = None
    for (t, z, gx, gz, r) in v:
        if t >= first_reset: break
        if z >= 105:
            rs0 = t if rs0 is None else rs0
            if t - rs0 >= 1.0: t_rise = rs0; break
        else: rs0 = None
    import math
    tilt_end = math.degrees(math.acos(max(-1, min(1, -v[-1][3]))))
    falls = []; st = 'up' if v[0][3] < -0.9 else 'down'
    for (t, z, gx, gz, r) in v:
        if st == 'up' and gz > -0.5: falls.append(t); st = 'down'
        elif st == 'down' and gz < -0.9: st = 'up'
    if standing: ok = not falls and not rs
    elif RISE: ok = t_rise is not None and v[-1][1] >= 105 and not [x for x in rs if x > t_rise]
    else: ok = t_up is not None and not [x for x in falls if x > t_up] and not [x for x in rs if x > (t_up or 0)]
    zs = [x[1] for x in v]; last = v[-1]
    extra = ''
    if posture:
        cls = None; sw = []; hs = {'sit': [], 'stand': []}
        for (t, z, gx, gz, r) in v:
            if gz > -0.8: continue
            c = 'sit' if z < 80 else ('stand' if z > 100 else None)
            if c: hs[c].append(z)
            if c and c != cls:
                if cls is not None: sw.append(f'{c}@{t:.1f}')
                cls = c
        med = lambda l: sorted(l)[len(l) // 2] if l else 0
        extra = f" switches={len(sw)} {sw} sit~{med(hs['sit']):.0f}mm stand~{med(hs['stand']):.0f}mm"
    groups.setdefault(g, []).append(ok)
    print(f"{name:34s} {'OK ' if ok else 'BAD'} up@{'%.1f' % t_up if t_up is not None else '-':>5} rise@{'%.1f' % t_rise if t_rise is not None else '-':>5} tilt_end={tilt_end:.0f}deg falls={[round(x, 1) for x in falls]} "
          f"resets={rs} trunk {min(zs):.0f}-{max(zs):.0f}mm end=({last[2]:+.2f},{last[3]:+.2f}) {last[1]:.0f}mm r={min(x[4] for x in v):.2f}-{max(x[4] for x in v):.2f}{extra}")
print()
for g, l in groups.items(): print(f"{g:30s} {sum(l)}/{len(l)}")
