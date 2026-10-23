#!/bin/bash
# slope-play-check-2026-10-14.sh: does MICRODUCK_SLOPE reach the PLAY env of the slope task, and does the ground read follow
# the hill? per verdict setting (0.15,0.15 = a/b, 0.001,0.001 = control c, unset = training range) it builds the play env
# (1 env) and prints (1) the hfield tops of the generated floor (count, min/median/max mm) and env 0's origin z, (2) with the
# spawn forced 1.6 m out along +x (onto the slope), after 25 zero-action steps: the hfield surface height under the trunk
# (bilinear sample of the model's hfield data) against our patched _ground_z (foot_height_scan hits). they must agree to a
# few mm, otherwise every height-gated term reads an upright duck on the slope as fallen. then three walk-flat v2 control
# takes at --cmd-vx 0.3 (0.15 with shoves, 0.15 no shoves, 0.001 with shoves): recorder + harness proof, and whether the
# base policy falls on the hill at all. sibling of step-play-check-2026-10-14.sh.
# NOTE (same evening): these four takes ran WITHOUT --no-bounds and every mid RESET was out_of_terrain_bounds (edge-column
# spawn, duck upright); the control set that counts is slope-calib-2026-10-14.sh.
exec > >(tee -a /home/witcheer/Pollen/slope-play-check-2026-10-14.log) 2>&1
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
for s in 0.15,0.15 0.001,0.001 train; do
( if [ "$s" = train ]; then unset MICRODUCK_SLOPE; else export MICRODUCK_SLOPE=$s; fi
uv run python - <<'EOF' 2>&1 | grep -E "^(SLOPE|ERR)"
import os, traceback, statistics
try:
    import numpy as np, torch, mujoco
    import mjlab_microduck.tasks  # noqa
    from mjlab.tasks import registry
    from mjlab.envs import ManagerBasedRlEnv
    from mjlab_microduck.tasks.mdp import _ground_z
    tag = os.environ.get("MICRODUCK_SLOPE", "train-range")
    cfg = registry.load_env_cfg("Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck", play=True)
    cfg.scene.num_envs = 1
    print("SLOPE %s cfg slope_range %s" % (tag, cfg.scene.terrain.terrain_generator.sub_terrains["hill"].slope_range))
    pr = cfg.events["reset_base"].params["pose_range"]
    pr["x"] = (1.6, 1.6); pr["y"] = (-0.05, 0.05)
    env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
    m = env.sim.mj_model
    d = mujoco.MjData(m); mujoco.mj_forward(m, d)
    hf = [g for g in range(m.ngeom) if m.geom_type[g] == mujoco.mjtGeom.mjGEOM_HFIELD]
    tops = [1000 * (d.geom_xpos[g, 2] + m.hfield_size[m.geom_dataid[g], 2]) for g in hf]
    print("SLOPE %s hfield geoms %d, tops mm min %.1f median %.1f max %.1f" % (tag, len(hf), min(tops), statistics.median(tops), max(tops)))
    print("SLOPE %s origin z (env 0): %.4f" % (tag, float(env.scene.env_origins[0, 2])))
    def surf(x, y):
        for g in hf:
            h = m.geom_dataid[g]; rx, ry, sz, _ = m.hfield_size[h]; gx, gy, gz = d.geom_xpos[g]
            if abs(x - gx) <= rx and abs(y - gy) <= ry:
                nr, nc = m.hfield_nrow[h], m.hfield_ncol[h]; a = m.hfield_adr[h]
                D = np.asarray(m.hfield_data[a:a + nr * nc]).reshape(nr, nc)
                c = (x - gx + rx) / (2 * rx) * (nc - 1); r = (y - gy + ry) / (2 * ry) * (nr - 1)
                c0, r0 = int(np.floor(c)), int(np.floor(r)); c1, r1 = min(c0 + 1, nc - 1), min(r0 + 1, nr - 1); fc, fr = c - c0, r - r0
                v = (D[r0, c0] * (1 - fc) * (1 - fr) + D[r0, c1] * fc * (1 - fr) + D[r1, c0] * (1 - fc) * fr + D[r1, c1] * fc * fr)
                return gz + v * sz
        return float("nan")
    o = env.scene.env_origins[0].cpu().numpy()
    print("SLOPE %s surface at origin xy %.4f (origin z %.4f)" % (tag, surf(o[0], o[1]), o[2]))
    env.reset()
    act = torch.zeros(1, env.action_manager.total_action_dim, device=env.device)
    for _ in range(25):
        env.step(act)
    p = env.scene["robot"].data.root_link_pos_w[0].cpu().numpy()
    gzv = float(_ground_z(env)[0])
    rr = float(np.hypot(p[0] - o[0], p[1] - o[1]))
    print("SLOPE %s spawn +1.6 m after 0.5 s: r %.2f m, root z %.4f, hfield surface under trunk %.4f, _ground_z %.4f, diff %.1f mm" % (
        tag, rr, p[2], surf(p[0], p[1]), gzv, 1000 * (gzv - surf(p[0], p[1]))))
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1500:])
EOF
)
done
[ -n "${SKIP_TAKES:-}" ] && { echo "=== $(date -u +%T) SLOPE_CHECK_END (takes skipped) ==="; exit 0; }
TASK=Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck; OUT=/home/witcheer/Pollen/clips/slope-control-2026-10-14
. /home/witcheer/Pollen/proof-common.sh
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3"
( export MICRODUCK_SLOPE=0.15,0.15; play v2-ctrl-a-t1 $TASK $V2 1000 $C )
( export MICRODUCK_SLOPE=0.15,0.15; play v2-ctrl-b-t1 $TASK $V2 1000 $C --no-push )
( export MICRODUCK_SLOPE=0.15,0.15; play v2-ctrl-b-t2 $TASK $V2 1000 $C --no-push )
( export MICRODUCK_SLOPE=0.001,0.001; play v2-ctrl-c-t1 $TASK $V2 1000 $C )
echo "=== $(date -u +%T) SLOPE_CHECK_END ==="
