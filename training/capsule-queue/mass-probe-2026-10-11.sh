#!/bin/bash
# mass-probe-2026-10-11.sh: read Microduck body masses from the Velocity-Flat-Backlash task model (CPU, no GPU env).
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'EOF'
import mujoco
import mjlab_microduck.tasks  # noqa: F401
from mjlab.tasks.registry import load_env_cfg
cfg = load_env_cfg("Mjlab-Velocity-Flat-Backlash-MicroDuck")
rc = cfg.scene.entities["robot"]
spec = rc.spec_fn() if callable(getattr(rc, "spec_fn", None)) else None
if spec is None:
    print("no spec_fn; attrs:", [a for a in dir(rc) if not a.startswith("_")][:40]); raise SystemExit
m = spec.compile()
tot = 0.0
for i in range(m.nbody):
    n = mujoco.mj_id2name(m, mujoco.mjtObj.mjOBJ_BODY, i); tot += m.body_mass[i]
    if m.body_mass[i] > 0.01: print(f"{n:30s} {m.body_mass[i]*1000:8.1f} g")
print(f"total {tot*1000:.1f} g")
ev = cfg.events["randomize_mass_inertia"]; print("mass DR:", ev.params)
EOF
