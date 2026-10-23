#!/bin/bash
# install-step-fork-2026-10-13.sh: register Mjlab-Velocity-Flat-Backlash-Step-MicroDuck in our patched clone.
# one module file + one appended import line (backup first), then resolved-cfg checks + a geometry check of one tile.
# idempotent (guarded). shape copied from install-slip-fork-2026-10-12.sh.
set -euo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
T=/home/witcheer/Pollen/microduck_rl/src/mjlab_microduck/tasks
cp /home/witcheer/Pollen/witcheer_velocity_step_env_cfg.py $T/
# import test BEFORE the line goes into __init__.py: a broken module there would break every task load
(cd /home/witcheer/Pollen/microduck_rl && uv run python -c "import mjlab_microduck.tasks.witcheer_velocity_step_env_cfg" >/dev/null 2>&1) || { echo "IMPORT FAILED, not registering"; exit 2; }
echo "module import ok"
if ! grep -q witcheer_velocity_step_env_cfg $T/__init__.py; then
  cp $T/__init__.py /home/witcheer/tasks-init.py.bak-step-2026-10-13
  printf '\n# witcheer fork (not a Pollen file): Mjlab-Velocity-Flat-Backlash-Step-MicroDuck, walk with gear play over a single 10-25 mm step (one raised 1.5 m platform per 4 m tile), see the module docstring.\nfrom . import witcheer_velocity_step_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py
  echo "import line appended (backup ~/tasks-init.py.bak-step-2026-10-13)"
else echo "already registered"; fi
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'EOF' 2>&1 | grep -v Warning
import re, difflib, inspect
import numpy as np, mujoco
import mjlab_microduck.tasks  # noqa: F401
from mjlab.tasks.registry import list_tasks, load_env_cfg
B, F = "Mjlab-Velocity-Flat-Backlash-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Step-MicroDuck"
ids = list_tasks(); print("registered:", F in ids, "total ids:", len(ids))
for t in (B, F, "Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck", "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck"):
    c = load_env_cfg(t); g = c.scene.terrain.terrain_generator
    print(t, "terrain", c.scene.terrain.terrain_type, "gen", None if g is None else (g.size, g.num_rows, g.num_cols, g.curriculum, list(g.sub_terrains)),
          "friction", c.events["foot_friction"].params["ranges"], "terrain_levels" in c.curriculum, "nconmax", c.sim.nconmax)
strip = lambda s: re.sub(r" at 0x[0-9a-f]+", "", s)
b = strip(repr(load_env_cfg(B))); p = strip(repr(load_env_cfg(F)))
d = [l for l in difflib.unified_diff(b.split(", "), p.split(", "), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
print("repr diff base vs fork (items):", len(d)); print("\n".join(x[:200] for x in d[:40]))
# height reads in active terms and observations
c = load_env_cfg(F)
for grp, terms in (("rew", c.rewards), ("term", c.terminations)):
    for k, t in terms.items():
        try: src = inspect.getsource(t.func)
        except Exception: src = ""
        if "env_origins" in src and "_ground_z" not in src: print("ORIGIN READ", grp, k, "weight", getattr(t, "weight", "-"))
for gname, grp in c.observations.items():
    for k, t in grp.terms.items():
        try: src = inspect.getsource(t.func)
        except Exception: src = ""
        if "env_origins" in src or "pos_w[:, 2]" in src: print("OBS HEIGHT READ", gname, k)
# geometry of one tile at three difficulties: top z of every geom
st = c.scene.terrain.terrain_generator.sub_terrains["single_step"]
st.size = c.scene.terrain.terrain_generator.size
for diff in (0.0, 0.5, 1.0):
    spec = mujoco.MjSpec(); spec.worldbody.add_body(name="terrain")
    out = st.function(diff, spec, np.random.default_rng(0))
    tops = sorted({round(float(g.geom.pos[2] + g.geom.size[2]), 4) for g in out.geometries})
    big = [ (round(2*g.geom.size[0],3), round(2*g.geom.size[1],3)) for g in out.geometries if round(float(g.geom.pos[2]+g.geom.size[2]),4) == max(tops)]
    print(f"difficulty {diff}: geoms {len(out.geometries)} tops {tops} origin_z {round(float(out.origin[2]),4)} raised footprint {big}")
EOF
