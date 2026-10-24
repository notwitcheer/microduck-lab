#!/bin/bash
# install-bigkick-fork-2026-10-24.sh: registers Mjlab-BallKick-Flat-Backlash-Big-MicroDuck (09z10) in our patched clone.
# backup ~/tasks-init.py.bak-bigkick-2026-10-24; identity check = repr-md5-bigkick-2026-10-24.sh before and after (must be byte-identical);
# then prints the resolved cfg (ball radius/mass/colour, reset_ball offset, entities, event order) for train and for a goal-mode play cfg.
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/bigkick-install-2026-10-24; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
bash /home/witcheer/Pollen/repr-md5-bigkick-2026-10-24.sh > $D/before.txt
cp $T/__init__.py /home/witcheer/tasks-init.py.bak-bigkick-2026-10-24
cp /home/witcheer/Pollen/witcheer_ballkick_big_env_cfg.py $T/
grep -q witcheer_ballkick_big_env_cfg $T/__init__.py || printf '\n# witcheer fork (not a Pollen file): Mjlab-BallKick-Flat-Backlash-Big-MicroDuck, the backlash kick with a 140 mm / 60 g ball (2x the maker ball), seeded from kickbl, see the module docstring.\nfrom . import witcheer_ballkick_big_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
bash /home/witcheer/Pollen/repr-md5-bigkick-2026-10-24.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
show() { uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import os, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t = "Mjlab-BallKick-Flat-Backlash-Big-MicroDuck"; assert t in list_tasks(), "not registered"
for play in (False, True):
    c = load_env_cfg(t, play=play)
    tag = ("play" if play else "train") + " env=" + ",".join(f"{k}={v}" for k, v in sorted(os.environ.items()) if k.startswith("MICRODUCK_"))
    print(tag, "entities", list(c.scene.entities.keys()), "events", list(c.events.keys())[:14])
    print(tag, "reset_ball", c.events["reset_ball"].params)
    s = c.scene.entities["ball"].spec_fn()
    m = s.compile()
    print(tag, "ball geom size", float(m.geom_size[0][0]), "mass", float(m.body_mass[1]), "inertia", [float(v) for v in m.body_inertia[1]], "rgba", [round(float(v),2) for v in m.geom_rgba[0]])
    print(tag, "episode_s", c.episode_length_s, "reward ball_forward_velocity", c.rewards["ball_forward_velocity"].params, c.rewards["ball_forward_velocity"].weight)
    if "goal" in c.scene.entities:
        g = c.scene.entities["goal"].spec_fn().compile()
        print(tag, "goal geoms", g.ngeom, "x range", float(g.geom_pos[:,0].min()), float(g.geom_pos[:,0].max()))
PY
}
show
MICRODUCK_BIGKICK_GOAL=1 show
echo INSTALL_END
