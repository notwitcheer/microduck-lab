#!/bin/bash
# fric-play-check-2026-10-13.sh: does MICRODUCK_FOOT_FRICTION reach the PLAY env of the slip task? builds the play env (1 env)
# at 0.2,0.2 and 1.0,1.0 and prints the friction of the priority>0 (foot) geoms after the startup events.
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
for s in 0.2,0.2 1.0,1.0; do
MICRODUCK_FOOT_FRICTION=$s uv run python - <<'EOF' 2>&1 | grep -E "^(FRIC|ERR)"
import os, traceback
try:
    import mjlab_microduck.tasks  # noqa
    from mjlab.tasks import registry
    from mjlab.envs import ManagerBasedRlEnv
    import mujoco
    cfg = registry.load_env_cfg("Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck", play=True)
    cfg.scene.num_envs = 1
    env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
    m = env.sim.mj_model
    gf = env.sim.model.geom_friction.detach().cpu().numpy().reshape(-1, m.ngeom, 3)[0]
    feet = [i for i in range(m.ngeom) if m.geom_priority[i] > 0]
    print("FRIC env=%s " % os.environ["MICRODUCK_FOOT_FRICTION"] + " ".join("%s:%.3f(default %.3f)" % (mujoco.mj_id2name(m, mujoco.mjtObj.mjOBJ_GEOM, i), gf[i,0], m.geom_friction[i,0]) for i in feet))
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1500:])
EOF
done
