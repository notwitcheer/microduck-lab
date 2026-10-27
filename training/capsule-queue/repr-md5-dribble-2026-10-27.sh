#!/bin/bash
# repr-md5-dribble-2026-10-27.sh: train + play cfg md5 (address-stripped repr) of the tasks next to the dribble fork. the 09z14 install must leave every one of these
# byte-identical (the fork only registers a new id; the giant-ball kick tasks and the walk tasks it imports from are in the list on purpose).
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import re, hashlib, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-BallKick-Flat-MicroDuck","Mjlab-BallKick-Flat-Backlash-MicroDuck","Mjlab-BallKick-Flat-Backlash-Big-MicroDuck","Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck","Mjlab-Velocity-Flat-MicroDuck","Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck","Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck","Mjlab-Roulade-Flat-MicroDuck"]:
    for play in (False, True):
        print(t, play, hashlib.md5(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t, play=play))).encode()).hexdigest()[:12])
PY
