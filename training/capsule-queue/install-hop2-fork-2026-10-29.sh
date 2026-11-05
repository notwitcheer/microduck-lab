#!/bin/bash
# install-hop2-fork-2026-10-29.sh: registers Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck in our patched clone (not a Pollen file edit: a new module + one import line appended to tasks/__init__.py, atomic mv).
# backup ~/tasks-init.py.bak-hop2-2026-10-29; identity check = repr-md5-hop2-2026-10-29.sh before and after (must be byte-identical); the module was import-tested in the scratch tree ~/Pollen/hop2-dev/src first (CPU smoke, play takes).
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/hop2-install-2026-10-29; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
bash /home/witcheer/Pollen/repr-md5-hop2-2026-10-29.sh > $D/before.txt
[ -f /home/witcheer/tasks-init.py.bak-hop2-2026-10-29 ] || cp $T/__init__.py /home/witcheer/tasks-init.py.bak-hop2-2026-10-29
cp /home/witcheer/Pollen/witcheer_velocity_hop2_env_cfg.py $T/witcheer_velocity_hop2_env_cfg.py.new && mv $T/witcheer_velocity_hop2_env_cfg.py.new $T/witcheer_velocity_hop2_env_cfg.py
if ! grep -q witcheer_velocity_hop2_env_cfg $T/__init__.py; then
  cp $T/__init__.py $T/__init__.py.new
  printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck, the hop env that pays only whole-body airtime (no robot body on the floor, trunk above stand), see the module docstring.\nfrom . import witcheer_velocity_hop2_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py.new
  python3 -m py_compile $T/__init__.py.new && mv $T/__init__.py.new $T/__init__.py
fi
bash /home/witcheer/Pollen/repr-md5-hop2-2026-10-29.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
uv run python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
t = "Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck"; assert t in list_tasks(), "not registered"
b = "Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck"
for play in (False, True):
    c = load_env_cfg(t, play=play); cb = load_env_cfg(b, play=play)
    tag = "play" if play else "train"
    print(tag, "reward names extra vs hop v1:", sorted(set(c.rewards) - set(cb.rewards)), "missing:", sorted(set(cb.rewards) - set(c.rewards)))
    print(tag, "hop2 weights:", {k: v.weight for k, v in c.rewards.items() if k.startswith("hop2")})
    print(tag, "sensors", [s.name for s in c.scene.sensors], "terminations", list(c.terminations), "episode_s", c.episode_length_s)
    print(tag, "obs actor terms equal to hop v1:", list(c.observations["actor"].terms) == list(cb.observations["actor"].terms), "action terms equal:", list(c.actions) == list(cb.actions))
PY
echo INSTALL_END
