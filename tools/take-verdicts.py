#!/usr/bin/env python3
"""take-verdicts.py: per-take and per-group verdicts from headless_play take logs.

usage: python3 take-verdicts.py [--end 19.9] <glob> [<glob> ...]
  e.g. python3 take-verdicts.py '~/Pollen/clips/velbl-*/twin-t*.log' '~/Pollen/clips/velbl-*/seed-t*.log'

per take: fall-free (no mid-episode RESET before --end, the episode time-out), the mid RESET
times, trunk_z min-max and worst grav_b z inside the logged window. per glob: N of M fall-free.

rules baked in:
- `*.full.log` (stderr mirror) is skipped: globbing both double-counts every take.
- a mid-episode `RESET at t=` IS a fall on the Velocity family (fell_over resets on tilt before
  the trunk reaches the floor, so trunk-height tests score falls as held) and on VelStand it is
  the fallen_too_long teleport (8 s down), never a get-up.
- a trunk dip below ~80 mm with grav_b z still ~-0.98 is a crouch, not a fall: read the line.
"""
import glob, os, re, sys

SAMPLE = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
RESET = re.compile(r'RESET at t=\s*([\d.]+)')

args = sys.argv[1:]
end = 19.9
if args[:1] == ['--end']:
    end = float(args[1]); args = args[2:]

for pat in args:
    files = sorted(f for f in glob.glob(os.path.expanduser(pat)) if not f.endswith('.full.log'))
    clean = 0
    for f in files:
        t = open(f, errors='replace').read()
        v = [(float(m[1]), float(m[2]), float(m[5])) for m in SAMPLE.finditer(t)]
        mid = [float(x) for x in RESET.findall(t) if float(x) < end]
        win = [x for x in v if x[0] <= end]
        ok = not mid
        clean += ok
        if win:
            zs = [x[1] for x in win]
            print(f"  {os.path.basename(f):28s} {'fall-free' if ok else 'FALLS at ' + ', '.join(f'{x:.1f}s' for x in mid):24s} "
                  f"trunk {min(zs):.1f}-{max(zs):.1f} mm, worst grav z {max(x[2] for x in win):+.2f}, window to {win[-1][0]:.1f}s")
        else:
            print(f"  {os.path.basename(f):28s} no samples parsed")
    print(f"{pat}: {clean} of {len(files)} fall-free")
