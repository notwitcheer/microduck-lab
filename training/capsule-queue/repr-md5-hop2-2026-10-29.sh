#!/bin/bash
# repr-md5-hop2-2026-10-29.sh: train + play cfg md5 (address-stripped repr) of the tasks next to the hop2 fork (the 7 of the hop install + hop v1, gale, moon, dribble: the items queued or running next). the hop2 install must leave every line byte-identical.
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import re, hashlib, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-Velocity-Flat-MicroDuck","Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck","Mjlab-VelStand-Flat-Backlash-MicroDuck","Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck","Mjlab-Roulade-Flat-MicroDuck","Mjlab-StandUp-Flat-MicroDuck","Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck","Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck","Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck","Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck"]:
    for play in (False, True):
        print(t, play, hashlib.md5(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t, play=play))).encode()).hexdigest()[:12])
PY
