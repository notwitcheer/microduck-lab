#!/bin/bash
# install-slope-fork-2026-10-14.sh: register Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck in our patched clone.
# one module file + one appended import line (backup first), then resolved-cfg checks:
#   (1) reprs of base/slip/payload/step/push (train + play) dumped BEFORE and AFTER the import line: must be identical;
#   (2) repr diff base vs slope (train and play): only scene.terrain (plane -> generator + the generator block) may differ.
# idempotent (guarded). shape copied from install-push-fork-2026-10-14.sh.
set -euo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
D=/home/witcheer/Pollen/slope-install-2026-10-14; mkdir -p $D
cd /home/witcheer/Pollen/microduck_rl
dump() { uv run python - "$1" <<'EOF' 2>&1 | grep -v Warning
import re, sys, json
import mjlab_microduck.tasks  # noqa: F401
from mjlab.tasks.registry import list_tasks, load_env_cfg
strip = lambda s: re.sub(r" at 0x[0-9a-f]+", "", s)
out = {"n_ids": len(list_tasks())}
for t in ("Mjlab-Velocity-Flat-Backlash-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck",
          "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Step-MicroDuck",
          "Mjlab-Velocity-Flat-Backlash-Push-MicroDuck"):
    for play in (False, True):
        out[f"{t}|play={play}"] = strip(repr(load_env_cfg(t, play=play)))
json.dump(out, open(sys.argv[1], "w"))
print("dumped", len(out) - 1, "cfgs, ids", out["n_ids"])
EOF
}
if ! grep -q witcheer_velocity_slope_env_cfg $T/__init__.py; then dump $D/before.json; fi
cp /home/witcheer/Pollen/witcheer_velocity_slope_env_cfg.py $T/
# import test BEFORE the line goes into __init__.py: a broken module there would break every task load
uv run python -c "import mjlab_microduck.tasks.witcheer_velocity_slope_env_cfg" >/dev/null 2>&1 || { echo "IMPORT FAILED, not registering"; exit 2; }
echo "module import ok"
if ! grep -q witcheer_velocity_slope_env_cfg $T/__init__.py; then
  cp $T/__init__.py /home/witcheer/tasks-init.py.bak-slope-2026-10-14
  printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck, walk with gear play over gentle hills (one heightfield pyramid per 4 m tile, gradient 0.05-0.15), see the module docstring.\nfrom . import witcheer_velocity_slope_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
  echo "import line appended (backup ~/tasks-init.py.bak-slope-2026-10-14)"
else echo "already registered"; fi
dump $D/after.json
uv run python - $D <<'EOF' 2>&1 | grep -v Warning
import re, sys, json, difflib
import mjlab_microduck.tasks  # noqa: F401
from mjlab.tasks.registry import list_tasks, load_env_cfg
D = sys.argv[1]
b, a = json.load(open(f"{D}/before.json")), json.load(open(f"{D}/after.json"))
print("ids before/after:", b["n_ids"], a["n_ids"], "slope registered:", "Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck" in list_tasks())
for k in b:
    if k != "n_ids": print("UNCHANGED" if b[k] == a[k] else "CHANGED!!", k)
strip = lambda s: re.sub(r" at 0x[0-9a-f]+", "", s)
B, F = "Mjlab-Velocity-Flat-Backlash-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck"
for play in (False, True):
    x = strip(repr(load_env_cfg(B, play=play))); y = strip(repr(load_env_cfg(F, play=play)))
    d = [l for l in difflib.unified_diff(x.split(", "), y.split(", "), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
    print(f"repr diff base vs slope play={play} (items): {len(d)}"); print("\n".join(s[:200] for s in d))
    for t in (B, F):
        tr = load_env_cfg(t, play=play).scene.terrain
        g = tr.terrain_generator
        print(f"  {t} play={play}: terrain_type {tr.terrain_type} generator {None if g is None else (g.size, g.num_rows, g.num_cols, g.curriculum, {k: (type(v).__name__, getattr(v, 'slope_range', None), v.platform_width, v.vertical_scale) for k, v in g.sub_terrains.items()})}")
EOF
