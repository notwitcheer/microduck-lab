#!/bin/bash
# repr-md5-hop-2026-10-27.sh: train + play cfg md5 (address-stripped repr) of the tasks next to the hop fork. the 09z16 install must leave
# every one of these byte-identical (the fork only registers a new id; its own base task Velocity-Flat-Backlash is in the list on purpose).
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import re, hashlib, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-Velocity-Flat-MicroDuck","Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck","Mjlab-VelStand-Flat-Backlash-MicroDuck","Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck","Mjlab-Roulade-Flat-MicroDuck","Mjlab-StandUp-Flat-MicroDuck"]:
    for play in (False, True):
        print(t, play, hashlib.md5(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t, play=play))).encode()).hexdigest()[:12])
PY
