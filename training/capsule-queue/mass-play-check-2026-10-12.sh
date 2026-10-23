#!/bin/bash
# mass-play-check-2026-10-12.sh: does MICRODUCK_PAYLOAD_SCALE actually reach the PLAY env? builds the play env (1 env) for the payload
# task at 1.0 and 1.30 and prints the trunk_base mass after the startup events.
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
for s in 1.0,1.0 1.30,1.30; do
MICRODUCK_PAYLOAD_SCALE=$s uv run python - <<'EOF' 2>&1 | grep -E "^(MASS|ERR|sig)" 
import os, inspect, traceback
try:
    import mjlab_microduck.tasks  # noqa
    from mjlab.tasks import registry
    from mjlab.envs import ManagerBasedRlEnv
    T = "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck"
    try:
        cfg = registry.load_env_cfg(T, play=True)
    except TypeError:
        print("sig", inspect.signature(registry.load_env_cfg)); cfg = registry.load_env_cfg(T)
    cfg.scene.num_envs = 1
    env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
    m = env.sim.mj_model
    import mujoco
    bid = mujoco.mj_name2id(m, mujoco.mjtObj.mjOBJ_BODY, "trunk_base")
    if bid < 0:
        names = [mujoco.mj_id2name(m, mujoco.mjtObj.mjOBJ_BODY, i) for i in range(m.nbody)]
        bid = [i for i, n in enumerate(names) if n and n.endswith("trunk_base")][0]
    bm = env.sim.model.body_mass.detach().cpu().numpy()
    print(f"MASS scale_env={os.environ['MICRODUCK_PAYLOAD_SCALE']} default_trunk={m.body_mass[bid]*1000:.1f} g  env_trunk={bm.reshape(-1, m.nbody)[0, bid]*1000:.1f} g")
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1500:])
EOF
done
