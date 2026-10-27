#!/bin/bash
# install-bigaim-fork-2026-10-26.sh: registers Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck (09z12) in our patched clone.
# backup ~/tasks-init.py.bak-bigaim-2026-10-26; identity check = repr-md5-bigaim-2026-10-26.sh before and after (must be byte-identical, the Big task included);
# then prints the resolved cfg for train and for a goal-mode play cfg (the train cfg must carry ball_lateral at -AIM_W, the play cfg's other terms equal the Big task's).
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/bigaim-install-2026-10-26; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
bash /home/witcheer/Pollen/repr-md5-bigaim-2026-10-26.sh > $D/before.txt
[ -f /home/witcheer/tasks-init.py.bak-bigaim-2026-10-26 ] || cp $T/__init__.py /home/witcheer/tasks-init.py.bak-bigaim-2026-10-26
cp /home/witcheer/Pollen/witcheer_ballkick_bigaim_env_cfg.py $T/
grep -q witcheer_ballkick_bigaim_env_cfg $T/__init__.py || printf '\n# witcheer fork (not a Pollen file): Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck, the giant-ball backlash kick with the ball_lateral aim term switched on, see the module docstring.\nfrom . import witcheer_ballkick_bigaim_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
bash /home/witcheer/Pollen/repr-md5-bigaim-2026-10-26.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
show() { uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import os, mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t = "Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck"; assert t in list_tasks(), "not registered"
b = "Mjlab-BallKick-Flat-Backlash-Big-MicroDuck"
for play in (False, True):
    c = load_env_cfg(t, play=play); cb = load_env_cfg(b, play=play)
    tag = ("play" if play else "train") + " env=" + ",".join(f"{k}={v}" for k, v in sorted(os.environ.items()) if k.startswith("MICRODUCK_"))
    print(tag, "entities", list(c.scene.entities.keys()), "events", list(c.events.keys())[:14])
    print(tag, "ball rewards", {k: (v.weight, v.params) for k, v in c.rewards.items() if k.startswith("ball")})
    print(tag, "reset_ball", c.events["reset_ball"].params, "== Big:", c.events["reset_ball"].params == cb.events["reset_ball"].params)
    print(tag, "reward names extra vs Big:", sorted(set(c.rewards) - set(cb.rewards)), "missing:", sorted(set(cb.rewards) - set(c.rewards)),
          "other weights equal:", all(c.rewards[k].weight == cb.rewards[k].weight for k in cb.rewards))
    print(tag, "episode_s", c.episode_length_s, "Big", cb.episode_length_s, "curricula equal:", list(c.curriculum) == list(cb.curriculum))
PY
}
show
MICRODUCK_BIGKICK_GOAL=1 show
echo INSTALL_END
