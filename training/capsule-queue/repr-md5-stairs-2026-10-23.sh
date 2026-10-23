#!/bin/bash
# repr-md5-stairs-2026-10-23.sh: repr-md5.sh with the MixSlope task added (09z7 was installed after the last list update), used by the
# 09z8 stairs install: every earlier witcheer velocity fork's train + play cfg md5 must be byte-identical before and after.
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import re, hashlib, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Step-MicroDuck","Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck","Mjlab-Velocity-Flat-Backlash-Push-MicroDuck","Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck","Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck","Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck"]:
    for play in (False, True):
        print(t, play, hashlib.md5(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t, play=play))).encode()).hexdigest()[:12])
PY
