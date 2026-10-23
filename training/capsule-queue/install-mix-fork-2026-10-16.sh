#!/bin/bash
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
cd /home/witcheer/Pollen/microduck_rl
dump() { uv run python - <<'PY' 2>/dev/null
import re, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for t in ["Mjlab-Velocity-Flat-Backlash-MicroDuck","Mjlab-Velocity-Flat-Backlash-Step-MicroDuck","Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck","Mjlab-Velocity-Flat-Backlash-Push-MicroDuck","Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck"]:
    print(t, hash(re.sub(r" at 0x[0-9a-f]+","",repr(load_env_cfg(t)))))
PY
}
dump > /tmp/mix-before.txt
cp $T/__init__.py /home/witcheer/tasks-init.py.bak-mix-2026-10-16
cp /home/witcheer/witcheer_velocity_mix_env_cfg.py $T/
grep -q witcheer_velocity_mix_env_cfg $T/__init__.py || printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck, walk with gear play over the single step + slippery feet + 2x shoves at once, seeded from walk-step, see the module docstring.\nfrom . import witcheer_velocity_mix_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
dump > /tmp/mix-after.txt
echo "other reprs identical: $(cmp -s /tmp/mix-before.txt /tmp/mix-after.txt && echo yes || echo NO)"; cat /tmp/mix-after.txt
uv run python - <<'PY'
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t="Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck"; assert t in list_tasks(), "not registered"
c=load_env_cfg(t)
print("terrain", c.scene.terrain.terrain_type, list(c.scene.terrain.terrain_generator.sub_terrains))
print("friction", c.events["foot_friction"].params["ranges"])
print("push", c.events["push_robot"].params["velocity_range"], c.events["push_robot"].interval_range_s)
PY
