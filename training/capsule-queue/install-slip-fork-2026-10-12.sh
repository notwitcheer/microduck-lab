#!/bin/bash
# install-slip-fork-2026-10-12.sh: register Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck in our patched clone.
# one module file + one appended import line (backup first), then a resolved-cfg check. idempotent (guarded).
# shape copied from install-payload-fork-2026-10-11.sh.
set -euo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
cp /home/witcheer/Pollen/witcheer_velocity_slip_env_cfg.py $T/
# import test BEFORE the line goes into __init__.py: a broken module there would break every task load
(cd /home/witcheer/Pollen/microduck_rl && uv run python -c "import mjlab_microduck.tasks.witcheer_velocity_slip_env_cfg" >/dev/null 2>&1) || { echo "IMPORT FAILED, not registering"; exit 2; }
echo "module import ok"
if ! grep -q witcheer_velocity_slip_env_cfg $T/__init__.py; then
  cp $T/__init__.py /home/witcheer/tasks-init.py.bak-slip-2026-10-12
  printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck, walk with gear play + foot friction 0.2-1.3 (slippery floor), see the module docstring.\nfrom . import witcheer_velocity_slip_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
  echo "import line appended (backup ~/tasks-init.py.bak-slip-2026-10-12)"
else echo "already registered"; fi
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'EOF' 2>&1 | grep -v Warning
import re, difflib
import mjlab_microduck.tasks  # noqa: F401
from mjlab.tasks.registry import list_tasks, load_env_cfg
ids = list_tasks(); print("registered:", "Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck" in ids, "total ids:", len(ids))
for t in ("Mjlab-Velocity-Flat-Backlash-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck"):
    c = load_env_cfg(t); f = c.events["foot_friction"].params
    print(t, "foot friction", f["ranges"], f["operation"], "geoms", f["asset_cfg"].geom_names, "robot", type(c.scene.entities["robot"]).__name__)
b = re.sub(r" at 0x[0-9a-f]+", "", repr(load_env_cfg("Mjlab-Velocity-Flat-Backlash-MicroDuck")))
p = re.sub(r" at 0x[0-9a-f]+", "", repr(load_env_cfg("Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck")))
d = [l for l in difflib.unified_diff(b.split(", "), p.split(", "), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
print("repr diff base vs fork (items):", len(d)); print("\n".join(d[:12]))
EOF
