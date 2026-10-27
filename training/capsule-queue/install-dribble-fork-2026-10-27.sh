#!/bin/bash
# install-dribble-fork-2026-10-27.sh: registers Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck (09z14) in our patched clone.
# backup ~/tasks-init.py.bak-dribble-2026-10-27; identity check = repr-md5-dribble-2026-10-27.sh before and after (must be byte-identical);
# then prints the resolved cfg (train and goal-mode play) against the stock walk-flat backlash task.
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/dribble-install-2026-10-27; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
bash /home/witcheer/Pollen/repr-md5-dribble-2026-10-27.sh > $D/before.txt
[ -f /home/witcheer/tasks-init.py.bak-dribble-2026-10-27 ] || cp $T/__init__.py /home/witcheer/tasks-init.py.bak-dribble-2026-10-27
cp /home/witcheer/Pollen/witcheer_velocity_dribble_env_cfg.py $T/
grep -q witcheer_velocity_dribble_env_cfg $T/__init__.py || printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck, the backlash walk with a 300 mm ball ahead of the feet and ball-carry rewards, see the module docstring.\nfrom . import witcheer_velocity_dribble_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
bash /home/witcheer/Pollen/repr-md5-dribble-2026-10-27.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
show() { uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import os, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t = "Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck"; assert t in list_tasks(), "not registered"
b = "Mjlab-Velocity-Flat-Backlash-MicroDuck"
for play in (False, True):
    c = load_env_cfg(t, play=play); cb = load_env_cfg(b, play=play)
    tag = ("play" if play else "train") + " env=" + ",".join(f"{k}={v}" for k, v in sorted(os.environ.items()) if k.startswith("MICRODUCK_"))
    tw = c.commands["twist"]
    print(tag, "entities", list(c.scene.entities.keys()), "events", list(c.events.keys()))
    print(tag, "twist ranges", tw.ranges, "rel_standing", tw.rel_standing_envs, "rel_turn", tw.rel_turn_in_place_envs, "resample", getattr(tw, "resampling_time_range", None))
    print(tag, "ball rewards", {k: (v.weight, v.params) for k, v in c.rewards.items() if k.startswith("ball")})
    print(tag, "reset_ball", c.events["reset_ball"].params)
    print(tag, "reward names extra vs walk-flat backlash:", sorted(set(c.rewards) - set(cb.rewards)), "missing:", sorted(set(cb.rewards) - set(c.rewards)),
          "other weights equal:", all(c.rewards[k].weight == cb.rewards[k].weight for k in cb.rewards))
    print(tag, "episode_s", c.episode_length_s, "base", cb.episode_length_s, "curricula:", list(c.curriculum), "dropped vs base:", sorted(set(cb.curriculum) - set(c.curriculum)))
    print(tag, "nconmax", c.sim.nconmax, "base", cb.sim.nconmax)
PY
}
show
MICRODUCK_DRIBBLE_GOAL=1 show
echo INSTALL_END
