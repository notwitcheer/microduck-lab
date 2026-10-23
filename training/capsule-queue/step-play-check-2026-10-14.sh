#!/bin/bash
# step-play-check-2026-10-14.sh: does MICRODUCK_STEP_HEIGHT reach the PLAY env of the step task? builds the play env (1 env)
# at 0.025,0.025 and 0.0,0.0 and prints the distinct box-geom top heights of the generated floor. then one control take of
# walk-flat v2 at 25 mm with shoves (proves recorder + r= column before the verdict cron relies on them).
exec > >(tee -a /home/witcheer/Pollen/step-play-check-2026-10-14.log) 2>&1
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
for s in 0.025,0.025 0.0,0.0; do
MICRODUCK_STEP_HEIGHT=$s uv run python - <<'EOF' 2>&1 | grep -E "^(STEP|ERR)"
import os, traceback, collections
try:
    import mjlab_microduck.tasks  # noqa
    from mjlab.tasks import registry
    from mjlab.envs import ManagerBasedRlEnv
    import mujoco
    cfg = registry.load_env_cfg("Mjlab-Velocity-Flat-Backlash-Step-MicroDuck", play=True)
    cfg.scene.num_envs = 1
    env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
    m = env.sim.mj_model
    tops = collections.Counter()
    for i in range(m.ngeom):
        if m.geom_type[i] == mujoco.mjtGeom.mjGEOM_BOX and m.geom_bodyid[i] == 0:
            tops[round(float(m.geom_pos[i, 2] + m.geom_size[i, 2]) * 1000, 1)] += 1
    print("STEP env=%s box tops mm (count): %s" % (os.environ["MICRODUCK_STEP_HEIGHT"], dict(sorted(tops.items()))))
    print("STEP origin z (env 0): %.4f" % float(env.scene.env_origins[0, 2]))
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1500:])
EOF
done
export MICRODUCK_STEP_HEIGHT=0.025,0.025
TASK=Mjlab-Velocity-Flat-Backlash-Step-MicroDuck; OUT=/home/witcheer/Pollen/clips/step-control-2026-10-14
. /home/witcheer/Pollen/proof-common.sh
play v2-ctrl-t1 $TASK /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt 1000 --episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10
echo "=== $(date -u +%T) STEP_CHECK_END ==="
