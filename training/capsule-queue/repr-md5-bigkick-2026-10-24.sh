#!/bin/bash
# repr-md5-bigkick-2026-10-24.sh: train + play cfg md5 (address-stripped repr) of the tasks next to the big-ball kick fork. used by the
# 09z10 install: every one of these must be byte-identical before and after the fork module is imported (the fork only registers a new id).
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import re, hashlib, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-BallKick-Flat-MicroDuck","Mjlab-BallKick-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck","Mjlab-Roulade-Flat-MicroDuck"]:
    for play in (False, True):
        print(t, play, hashlib.md5(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t, play=play))).encode()).hexdigest()[:12])
PY
