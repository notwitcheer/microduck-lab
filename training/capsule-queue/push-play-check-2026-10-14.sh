#!/bin/bash
# push-play-check-2026-10-14.sh: do MICRODUCK_PUSH_SCALE / MICRODUCK_PUSH_INTERVAL reach the PLAY env of the push task?
# per verdict condition (a/b/c of proof-z4-*.sh) it builds the play env (1 env) and prints (1) the push_robot term the built
# EventManager holds, (2) the measured root velocity change of 400 direct calls of that term on env 0 (max |dvx|, |dvy|),
# (3) the number of pushes the env actually fires in 1000 steps (20 s) with zero actions (counting wrapper on the term func).
# then one walk-flat v2 control take in condition a and one in b (recorder + harness proof, saturation read).
exec > >(tee -a /home/witcheer/Pollen/push-play-check-2026-10-14.log) 2>&1
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
for s in "2.0|" "2.0|3,6" "1.0|"; do
sc=${s%%|*}; iv=${s#*|}
( export MICRODUCK_PUSH_SCALE=$sc; if [ -n "$iv" ]; then export MICRODUCK_PUSH_INTERVAL=$iv; else unset MICRODUCK_PUSH_INTERVAL; fi
uv run python - <<'EOF' 2>&1 | grep -E "^(PUSH|ERR)"
import os, traceback, torch
try:
    import mjlab_microduck.tasks  # noqa
    from mjlab.tasks import registry
    from mjlab.envs import ManagerBasedRlEnv
    tag = "scale=%s interval=%s" % (os.environ.get("MICRODUCK_PUSH_SCALE"), os.environ.get("MICRODUCK_PUSH_INTERVAL", "play-default"))
    cfg = registry.load_env_cfg("Mjlab-Velocity-Flat-Backlash-Push-MicroDuck", play=True)
    cfg.scene.num_envs = 1
    env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
    t = env.event_manager.get_term_cfg("push_robot")
    print("PUSH %s built term: velocity_range %s interval_range_s %s" % (tag, t.params["velocity_range"], t.interval_range_s))
    robot = env.scene["robot"]; ids = torch.tensor([0], device=env.device)
    dmax = torch.zeros(2)
    for _ in range(400):
        env.sim.forward(); v0 = robot.data.root_link_vel_w[0, :2].clone()
        t.func(env, ids, **t.params)
        env.sim.forward()  # root_link_vel_w is derived from cvel, stale until forward() (v1 of this check read 0.000)
        dv = (robot.data.root_link_vel_w[0, :2] - v0).abs().cpu()
        dmax = torch.maximum(dmax, dv)
    print("PUSH %s measured max |dvx| %.3f |dvy| %.3f m/s over 400 calls" % (tag, dmax[0], dmax[1]))
    n = [0]; f = t.func
    def counted(*a, **k):
        n[0] += 1; return f(*a, **k)
    t.func = counted
    env.reset()
    act = torch.zeros(1, env.action_manager.total_action_dim, device=env.device)
    for _ in range(1000):
        env.step(act)
    print("PUSH %s pushes fired in 1000 steps (20 s): %d" % (tag, n[0]))
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1500:])
EOF
)
done
[ -n "${SKIP_TAKES:-}" ] && { echo "=== $(date -u +%T) PUSH_CHECK_END (takes skipped) ==="; exit 0; }
TASK=Mjlab-Velocity-Flat-Backlash-Push-MicroDuck; OUT=/home/witcheer/Pollen/clips/push-control-2026-10-14
. /home/witcheer/Pollen/proof-common.sh
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3"
( export MICRODUCK_PUSH_SCALE=2.0; unset MICRODUCK_PUSH_INTERVAL; play v2-ctrl-a-t1 $TASK $V2 1000 $C )
( export MICRODUCK_PUSH_SCALE=2.0 MICRODUCK_PUSH_INTERVAL=3,6; play v2-ctrl-b-t1 $TASK $V2 1000 $C )
echo "=== $(date -u +%T) PUSH_CHECK_END ==="
