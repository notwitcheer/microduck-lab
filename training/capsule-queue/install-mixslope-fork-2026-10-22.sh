#!/bin/bash
# install-mixslope-fork-2026-10-22.sh: registers Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck (09z7) in our patched clone.
# backup ~/tasks-init.py.bak-mixslope-2026-10-22; identity check = repr-md5.sh (train + play cfg of base/step/slip/push/slope/mix)
# before and after, must be byte-identical; then prints the resolved new cfg (terrain types + ranges, friction, pushes) for
# train and for a play cfg with the verdict overrides set.
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/mixslope-install-2026-10-22; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
bash /home/witcheer/repr-md5.sh > $D/before.txt
cp $T/__init__.py /home/witcheer/tasks-init.py.bak-mixslope-2026-10-22
cp /home/witcheer/Pollen/witcheer_velocity_mixslope_env_cfg.py $T/
grep -q witcheer_velocity_mixslope_env_cfg $T/__init__.py || printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck, walk-mix (step + slippery feet + 2x shoves) plus hill tiles (0.5/0.5 step/hill), seeded from walk-mix, see the module docstring.\nfrom . import witcheer_velocity_mixslope_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
bash /home/witcheer/repr-md5.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
show() { uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import os, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t = "Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck"; assert t in list_tasks(), "not registered"
for play in (False, True):
    c = load_env_cfg(t, play=play); g = c.scene.terrain.terrain_generator
    tag = ("play" if play else "train") + " env=" + ",".join(f"{k}={v}" for k, v in sorted(os.environ.items()) if k.startswith("MICRODUCK_"))
    print(tag, "terrain", c.scene.terrain.terrain_type, "size", g.size, g.num_rows, "x", g.num_cols, "curriculum", g.curriculum)
    for k, s in g.sub_terrains.items():
        print(tag, "  sub", k, type(s).__name__, "prop", s.proportion, "step", getattr(s, "step_height_range", None), "slope", getattr(s, "slope_range", None))
    print(tag, "friction", c.events["foot_friction"].params["ranges"])
    print(tag, "push", c.events["push_robot"].params["velocity_range"], c.events["push_robot"].interval_range_s)
PY
}
show
MICRODUCK_SLOPE=0.15,0.15 MICRODUCK_STEP_HEIGHT=0.025,0.025 MICRODUCK_FOOT_FRICTION=0.2,0.2 MICRODUCK_PUSH_SCALE=2.0 MICRODUCK_PUSH_INTERVAL=3,6 show
echo INSTALL_END
