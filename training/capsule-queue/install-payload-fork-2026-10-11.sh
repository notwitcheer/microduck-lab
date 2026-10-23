#!/bin/bash
# install-payload-fork-2026-10-11.sh: register Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck in our patched clone.
# one module file + one appended import line (backup first), then a resolved-cfg check. idempotent (guarded).
set -euo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
cp /home/witcheer/Pollen/witcheer_velocity_payload_env_cfg.py $T/
# import test BEFORE the line goes into __init__.py: a broken module there would break every task load (live proof takes too)
(cd /home/witcheer/Pollen/microduck_rl && uv run python -c "import mjlab_microduck.tasks, mjlab_microduck.tasks.witcheer_velocity_payload_env_cfg as m; print('module import ok', m.TASK_ID)" 2>&1 | grep -v Warning | tail -n 3)
(cd /home/witcheer/Pollen/microduck_rl && uv run python -c "import mjlab_microduck.tasks.witcheer_velocity_payload_env_cfg" >/dev/null 2>&1) || { echo "IMPORT FAILED, not registering"; exit 2; }
if ! grep -q witcheer_velocity_payload_env_cfg $T/__init__.py; then
  cp $T/__init__.py /home/witcheer/tasks-init.py.bak-payload-2026-10-11
  printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck, walk with gear play + 0.95-1.30x trunk mass (payload on the back), see the module docstring.\nfrom . import witcheer_velocity_payload_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
  echo "import line appended (backup ~/tasks-init.py.bak-payload-2026-10-11)"
else echo "already registered"; fi
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'EOF' 2>&1 | grep -v Warning
import math, re
import mjlab_microduck.tasks  # noqa: F401
from mjlab.tasks.registry import list_tasks, load_env_cfg
ids = list_tasks(); print("registered:", "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck" in ids, "total ids:", len(ids))
for t in ("Mjlab-Velocity-Flat-Backlash-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck"):
    c = load_env_cfg(t); a = c.events["randomize_mass_inertia"].params["alpha_range"]
    print(t, "mass scale", tuple(round(math.exp(2 * x), 3) for x in a), "robot", type(c.scene.entities["robot"]).__name__,
          "push", c.events["push_robot"].params["velocity_range"])
b = re.sub(r" at 0x[0-9a-f]+", "", repr(load_env_cfg("Mjlab-Velocity-Flat-Backlash-MicroDuck")))
p = re.sub(r" at 0x[0-9a-f]+", "", repr(load_env_cfg("Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck")))
import difflib
d = [l for l in difflib.unified_diff(b.split(", "), p.split(", "), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
print("repr diff base vs fork (items):", len(d)); print("\n".join(d[:12]))
EOF
