#!/bin/bash
# install-hop-fork-2026-10-27.sh: registers Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck (09z16) in our patched clone.
# backup ~/tasks-init.py.bak-hop-2026-10-27; identity check = repr-md5-hop-2026-10-27.sh before and after (must be byte-identical);
# then prints the resolved cfg of the hop task against its base (extra / changed reward names, commands, curricula, episode length).
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/hop-install-2026-10-27; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
bash /home/witcheer/Pollen/repr-md5-hop-2026-10-27.sh > $D/before.txt
[ -f /home/witcheer/tasks-init.py.bak-hop-2026-10-27 ] || cp $T/__init__.py /home/witcheer/tasks-init.py.bak-hop-2026-10-27
cp /home/witcheer/Pollen/witcheer_velocity_hop_env_cfg.py $T/
grep -q witcheer_velocity_hop_env_cfg $T/__init__.py || printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck, the backlash walk env with a zero command and a hop reward layer (both feet off the ground, upright landing), see the module docstring.\nfrom . import witcheer_velocity_hop_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
bash /home/witcheer/Pollen/repr-md5-hop-2026-10-27.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t = "Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck"; assert t in list_tasks(), "not registered"
b = "Mjlab-Velocity-Flat-Backlash-MicroDuck"
for play in (False, True):
    c = load_env_cfg(t, play=play); cb = load_env_cfg(b, play=play)
    tag = "play" if play else "train"
    print(tag, "reward names extra vs base:", sorted(set(c.rewards) - set(cb.rewards)), "missing:", sorted(set(cb.rewards) - set(c.rewards)))
    print(tag, "changed weights:", {k: (cb.rewards[k].weight, c.rewards[k].weight) for k in cb.rewards if k in c.rewards and cb.rewards[k].weight != c.rewards[k].weight})
    print(tag, "hop weights:", {k: v.weight for k, v in c.rewards.items() if k.startswith("hop")})
    print(tag, "twist ranges", c.commands["twist"].ranges, "rel_standing", c.commands["twist"].rel_standing_envs)
    print(tag, "events", list(c.events.keys()), "| base had", sorted(set(cb.events) - set(c.events)), "extra", sorted(set(c.events) - set(cb.events)))
    print(tag, "episode_s", c.episode_length_s, "base", cb.episode_length_s, "terminations equal:", list(c.terminations) == list(cb.terminations))
    print(tag, "obs actor terms equal:", list(c.observations["actor"].terms) == list(cb.observations["actor"].terms), "robot cfg same obj type:", type(c.scene.entities["robot"]).__name__)
PY
echo INSTALL_END
