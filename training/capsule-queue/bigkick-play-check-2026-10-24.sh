#!/bin/bash
# bigkick-play-check-2026-10-24.sh: proves the pieces of the big-ball kick fork on a built 1-env PLAY env (goal mode), CPU-light, ~1 min:
#  1. ball radius 0.15 / mass 0.275 / colour reach the compiled model (geom_size, body_mass of the scene), reset_ball offset puts the ball resting on the floor
#  2. face_goal: after env.reset() the robot yaw is 0 (world +x), xy at the env origin, ball ahead on the +x axis at the right-foot line (y ~ -0.04)
#  3. the goal geoms sit at the world x range [1.4, 1.8], width 1.00 (y +-0.50), the ball is a dynamic body, the goal is not
#  4. ball_lateral reward term: ball velocity (0.60, 0.47) m/s with heading +x gives lateral 0.47 and ball_forward_velocity 0.60 (cap 1.0), the
#     weight is -6.0 in the TRAIN cfg and the term is absent when MICRODUCK_BIGKICK_AIM_W=0
# usage: bash bigkick-play-check-2026-10-24.sh   (log ~/Pollen/bigkick-play-check-2026-10-24.log)
exec > >(tee -a /home/witcheer/Pollen/bigkick-play-check-2026-10-24.log) 2>&1
export PATH=/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl MICRODUCK_BIGKICK_GOAL=1
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>&1 | grep -v '^\[mdp\]' | grep -v Warning
import math, torch, mujoco, mjlab_microduck.tasks
from mjlab.envs import ManagerBasedRlEnv
from mjlab.tasks.registry import load_env_cfg
T = "Mjlab-BallKick-Flat-Backlash-Big-MicroDuck"
tr = load_env_cfg(T, play=False)
print("TRAIN rewards:", {k: v.weight for k, v in tr.rewards.items() if k.startswith("ball")}, "entities", list(tr.scene.entities))
cfg = load_env_cfg(T, play=True)
cfg.scene.num_envs = 1
env = ManagerBasedRlEnv(cfg=cfg, device="cuda:0")
env.reset()
sc = env.scene; m = env.sim.mj_model
names = [mujoco.mj_id2name(m, mujoco.mjtObj.mjOBJ_GEOM, i) or "" for i in range(m.ngeom)]
bi = [i for i, n in enumerate(names) if "ball_geom" in n][0]
print("ball geom", names[bi], "radius", float(m.geom_size[bi][0]), "rgba", [round(float(v), 2) for v in m.geom_rgba[bi]])
bb = int(m.geom_bodyid[bi]); print("ball body mass", float(m.body_mass[bb]), "dof of ball body", int(m.body_dofnum[bb]), "(6 = free)")
gi = [i for i, n in enumerate(names) if n.startswith("goal") or "post" in n or "net_" in n or "bar_" in n or "rail_" in n]
gb = sorted({int(m.geom_bodyid[i]) for i in gi}); print("goal geoms", len(gi), "goal bodies dofs", [int(m.body_dofnum[b]) for b in gb], "mocap", [int(m.body_mocapid[b]) for b in gb])
d = env.sim.mj_data
mujoco.mj_forward(m, d)
xs = [float(d.geom_xpos[i][0]) for i in gi]; ys = [float(d.geom_xpos[i][1]) for i in gi]
print("goal world x range %.3f..%.3f  y range %.3f..%.3f" % (min(xs), max(xs), min(ys), max(ys)))
robot = sc["robot"]; ball = sc["ball"]
rp = robot.data.root_link_pos_w[0]; q = robot.data.root_link_quat_w[0]
yaw = math.atan2(2*(q[0]*q[3]+q[1]*q[2]), 1-2*(q[2]**2+q[3]**2))
print("after reset: robot xy (%.3f, %.3f) yaw %.2f deg; ball (%.3f, %.3f, %.3f)" % (rp[0], rp[1], math.degrees(float(yaw)), *[float(v) for v in ball.data.root_link_pos_w[0]]))
import mjlab_microduck.tasks.witcheer_ballkick_big_env_cfg as F
ball.write_root_link_velocity_to_sim(torch.tensor([[0.60, 0.47, 0, 0, 0, 0]], device="cuda:0"), torch.tensor([0], device="cuda:0"))
env.sim.forward()  # root velocity reads lag the write until a forward()
print("lateral term", float(F.ball_lateral_speed(env)[0]), "(expect 0.47)  forward term", float(F.microduck_mdp.ball_forward_velocity(env, max_speed=1.0)[0]), "(expect 0.60)")
print("CHECK_END")
PY
for w in 0 10; do MICRODUCK_BIGKICK_AIM_W=$w uv run python -c "
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
c = load_env_cfg('Mjlab-BallKick-Flat-Backlash-Big-MicroDuck', play=False)
print('AIM_W=$w: ball_lateral present =', 'ball_lateral' in c.rewards, c.rewards['ball_lateral'].weight if 'ball_lateral' in c.rewards else '')
" 2>&1 | grep 'AIM_W'; done
env -u MICRODUCK_BIGKICK_GOAL uv run python -c "
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
for play in (False, True):
    c = load_env_cfg('Mjlab-BallKick-Flat-Backlash-Big-MicroDuck', play=play)
    print('default env, play', play, 'entities', list(c.scene.entities), 'rewards', {k: v.weight for k, v in c.rewards.items() if k.startswith('ball')}, 'reset_ball', c.events['reset_ball'].params)
" 2>&1 | grep 'default env'
