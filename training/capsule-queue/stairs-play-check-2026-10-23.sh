#!/bin/bash
# stairs-play-check-2026-10-23.sh: do the verdict overrides reach the PLAY env of the stairs task? builds the play env (1 env, GPU, ~1 GB,
# a minute) under three override sets and prints (a) the tile mix actually generated (distinct box-geom top heights + env origin z),
# (b) the two foot-collision geoms' friction, (c) the push event range + interval of the play cfg:
#   A  MICRODUCK_STAIRS_MIX=stairs2:0.5,stairs3:0.5 MICRODUCK_STEP_HEIGHT=0.025,0.025 FOOT_FRICTION=0.2,0.2 PUSH_SCALE=2.0 PUSH_INTERVAL=3,6
#      (proof-z8-a): origin z 50 or 75 mm, friction 0.200, push +-0.6 at 3-6 s. (as run 2026-10-23: origin z 75.0, friction 0.2/0.2, push +-0.6 at 3-6 s.)
#      NOTE: the box-top histogram prints {} in this mjlab build (terrain geoms are not on body 0 of the compiled env, the 09z3 step check used the same
#      filter on an older read); origin z is the evidence, and stairs-profile-check-2026-10-23.sh reads the real heights by ray-cast.
#   B  MICRODUCK_STAIRS_MIX=flat:1 (stairs flat control): no raised box, origin z 0.
#   C  no override: the training mix (origin z drawn over stairs/single/hill/flat).
exec > >(tee -a /home/witcheer/Pollen/stairs-play-check-2026-10-23.log) 2>&1
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
run() { env "$@" uv run python - <<'EOF' 2>&1 | grep -E "^(CHK|ERR)"
import os, traceback, collections
try:
    import mjlab_microduck.tasks  # noqa
    from mjlab.tasks import registry
    from mjlab.envs import ManagerBasedRlEnv
    import mujoco
    cfg = registry.load_env_cfg("Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck", play=True)
    pe = cfg.events["push_robot"]; fr = cfg.events["foot_friction"].params["ranges"]
    cfg.scene.num_envs = 1
    env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
    m = env.sim.mj_model
    tops = collections.Counter()
    for i in range(m.ngeom):
        if m.geom_type[i] == mujoco.mjtGeom.mjGEOM_BOX and m.geom_bodyid[i] == 0:
            tops[round(float(m.geom_pos[i, 2] + m.geom_size[i, 2]) * 1000, 1)] += 1
    tag = ",".join(f"{k[10:]}={v}" for k, v in sorted(os.environ.items()) if k.startswith("MICRODUCK_"))
    print("CHK [%s] box tops mm (count): %s" % (tag, dict(sorted(tops.items()))))
    print("CHK [%s] origin z (env 0): %.1f mm; friction range cfg %s; push %s interval %s" % (tag, 1000 * float(env.scene.env_origins[0, 2]), fr, pe.params["velocity_range"], pe.interval_range_s))
    gf = env.sim.model.geom_friction.detach().cpu()
    foot = [i for i in range(m.ngeom) if m.geom_priority[i] > 0]
    print("CHK [%s] foot geoms (priority>0) friction[:, 0] over envs: %s" % (tag, [round(float(gf[0, i, 0]), 3) for i in foot]))
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1500:])
EOF
}
run MICRODUCK_STAIRS_MIX=stairs2:0.5,stairs3:0.5 MICRODUCK_STEP_HEIGHT=0.025,0.025 MICRODUCK_FOOT_FRICTION=0.2,0.2 MICRODUCK_PUSH_SCALE=2.0 MICRODUCK_PUSH_INTERVAL=3,6
run MICRODUCK_STAIRS_MIX=flat:1
run MICRODUCK_X=none
echo "=== $(date -u +%T) STAIRS_PLAY_CHECK_END ==="
