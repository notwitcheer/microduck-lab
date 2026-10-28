#!/bin/bash
# install-gm-fork-2026-10-28.sh: registers Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck (09z18) and Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck (09z20) in our patched microduck_rl clone, and generates microduck_rl/gm_play.py.
# safety (a duck item may be training while this runs, and every later python start imports tasks/__init__.py): the new __init__.py is built as __init__.py.new, import-tested in a scratch copy of src/ first, and only then
# moved into place atomically (mv). backup ~/tasks-init.py.bak-gm-2026-10-28. identity check = repr-md5-gm-2026-10-28.sh before and after (must be byte-identical; it includes the live hop + dribble tasks).
# then prints the resolved cfg of both new tasks against their base (backlash walk).
set -uo pipefail
export PATH=/home/witcheer/.local/bin:$PATH CUDA_VISIBLE_DEVICES=""
RL=/home/witcheer/Pollen/microduck_rl; T=$RL/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/gm-install-2026-10-28; mkdir -p $D
cd $RL
bash /home/witcheer/Pollen/repr-md5-gm-2026-10-28.sh > $D/before.txt
[ -f /home/witcheer/tasks-init.py.bak-gm-2026-10-28 ] || cp $T/__init__.py /home/witcheer/tasks-init.py.bak-gm-2026-10-28
cp /home/witcheer/Pollen/witcheer_velocity_gale_env_cfg.py /home/witcheer/Pollen/witcheer_velocity_moon_env_cfg.py $T/
cp $T/__init__.py $T/__init__.py.new
grep -q witcheer_velocity_gale_env_cfg $T/__init__.py.new || printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck, the backlash walk into a rising headwind on the trunk (xfrc_applied), see the module docstring.\nfrom . import witcheer_velocity_gale_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py.new
grep -q witcheer_velocity_moon_env_cfg $T/__init__.py.new || printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck, the backlash walk in 1.62 m/s^2 gravity (cfg.sim.mujoco.gravity), see the module docstring.\nfrom . import witcheer_velocity_moon_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py.new
# scratch import test of the NEW __init__ before it goes live
S=/home/witcheer/Pollen/gm-install-scratch; rm -rf $S; mkdir -p $S; cp -r $RL/src $S/src; find $S -name __pycache__ -prune -exec rm -rf {} \; ; cp $T/__init__.py.new $S/src/mjlab_microduck/tasks/__init__.py
PYTHONPATH=$S/src $RL/.venv/bin/python - <<'PY' 2>&1 | grep -v '^\[mdp\]'
import sys, mjlab_microduck.tasks
from mjlab.tasks.registry import list_tasks
ok = all(t in list_tasks() for t in ("Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck"))
print("scratch import test:", "OK" if ok else "FAILED", "| package from", mjlab_microduck.__file__)
sys.exit(0 if ok else 1)
PY
rc=${PIPESTATUS[0]}
if [ "$rc" != 0 ]; then echo "SCRATCH IMPORT FAILED rc=$rc: __init__.py NOT touched, modules left in tasks/ but unregistered"; rm -f $T/__init__.py.new; exit 1; fi
mv $T/__init__.py.new $T/__init__.py && echo "__init__.py replaced atomically"
python3 /home/witcheer/Pollen/make-gm-play-2026-10-28.py $RL/headless_play.py $RL/gm_play.py && python3 -m py_compile $RL/gm_play.py && echo "gm_play.py written"
bash /home/witcheer/Pollen/repr-md5-gm-2026-10-28.sh > $D/after.txt
echo "lines before $(wc -l < $D/before.txt) after $(wc -l < $D/after.txt)"
echo "other reprs identical: $(cmp -s $D/before.txt $D/after.txt && [ -s $D/before.txt ] && echo yes || echo NO)"; cat $D/after.txt
.venv/bin/python - <<'PY' 2>/dev/null | grep -v '^\[mdp\]'
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg, list_tasks
b = "Mjlab-Velocity-Flat-Backlash-MicroDuck"
for t in ("Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck"):
    assert t in list_tasks(), "not registered " + t
    for play in (False, True):
        c = load_env_cfg(t, play=play); cb = load_env_cfg(b, play=play); tag = "play" if play else "train"
        print(t.split("-")[4], tag, "gravity", tuple(c.sim.mujoco.gravity), "base", tuple(cb.sim.mujoco.gravity), "| twist vx", c.commands["twist"].ranges.lin_vel_x, "vy", c.commands["twist"].ranges.lin_vel_y, "wz", c.commands["twist"].ranges.ang_vel_z, "| episode_s", c.episode_length_s)
        print(t.split("-")[4], tag, "events extra vs base:", sorted(set(c.events) - set(cb.events)), "missing:", sorted(set(cb.events) - set(c.events)), "| curriculum missing vs base:", sorted(set(cb.curriculum or {}) - set(c.curriculum or {})), "| rewards equal:", list(c.rewards) == list(cb.rewards), {k: v.weight for k, v in c.rewards.items()} == {k: v.weight for k, v in cb.rewards.items()})
        print(t.split("-")[4], tag, "obs actor terms equal:", list(c.observations["actor"].terms) == list(cb.observations["actor"].terms), "terminations equal:", list(c.terminations) == list(cb.terminations))
PY
echo INSTALL_END
