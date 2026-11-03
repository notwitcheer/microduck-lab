#!/usr/bin/env python3
"""boulder-pick-2026-11-03.py <clip dir>: pick the hero and the 'before' from the 1-env render takes (rule fixed before any take).

takes: H<n>.log (Hermes reflex, 1 env, rendered) and N<n>.log (no reflex, 1 env, rendered). each log has one per-env line
  env00 touched=<bool>@<t> clear_min=<m> tilt_max=<deg> z_med=<mm> low=<share> ...
HERO = the Hermes take with touched=False, tilt_max <= 60, z_med >= 0.9 x 116.1 mm, low <= 0.10 whose clear_min is the SMALLEST value >= 0.04 m (a visible near miss);
if none, the largest clear_min among clean takes. BEFORE = the no-reflex take that touched with the largest tilt_max (the duck flattened), else any touched one.
prints HERO=<n> and BEFORE=<n> (or NONE). exit 0 always (the clip script decides).
"""
import glob
import os
import re
import sys

d = sys.argv[1]
Z_STAND = 116.1


def parse(f):
    txt = open(f, errors="replace").read()
    m = re.search(r"env00 touched=(True|False)@(\S+) clear_min=([+-][\d.]+) tilt_max=\s*([\d.]+) z_med=\s*([+-]?[\d.]+) low=([\d.]+)", txt)
    if not m or "[boulder] done" not in txt:
        return None
    return dict(touched=m.group(1) == "True", clear=float(m.group(3)), tilt=float(m.group(4)), z=float(m.group(5)), low=float(m.group(6)))


hero = []
for f in sorted(glob.glob(os.path.join(d, "H*.log"))):
    r = parse(f)
    n = re.search(r"H(\d+)\.log", f).group(1)
    if r and not r["touched"] and r["tilt"] <= 60 and r["z"] >= 0.9 * Z_STAND and r["low"] <= 0.10:
        hero.append((n, r["clear"]))
vis = [h for h in hero if h[1] >= 0.04]
if vis:
    n = min(vis, key=lambda h: h[1])[0]
elif hero:
    n = max(hero, key=lambda h: h[1])[0]
else:
    n = None
before = []
for f in sorted(glob.glob(os.path.join(d, "N*.log"))):
    r = parse(f)
    m = re.search(r"N(\d+)\.log", f)
    if r and r["touched"] and m:
        before.append((m.group(1), r["tilt"]))
b = max(before, key=lambda x: x[1])[0] if before else None
print(f"HERO={n if n else 'NONE'}")
print(f"BEFORE={b if b else 'NONE'}")
print(f"[pick] hero candidates (clean takes): {hero}; before candidates (touched): {before}")
