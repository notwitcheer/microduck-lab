#!/bin/bash
# repr-md5.sh: md5 of the address-stripped repr of every witcheer velocity fork's train + play cfg (identity check before/after
# any fork install; never python hash(), str hashes are randomised per process). 2026-10-22: Mix added to the list.
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import re, hashlib, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Step-MicroDuck","Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck","Mjlab-Velocity-Flat-Backlash-Push-MicroDuck","Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck","Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck"]:
    for play in (False, True):
        print(t, play, hashlib.md5(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t, play=play) if 'play' in load_env_cfg.__code__.co_varnames else load_env_cfg(t))).encode()).hexdigest()[:12])
PY
