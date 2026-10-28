#!/usr/bin/env python3
"""gm-envcheck-2026-10-28.py: CPU check that the gale / moon TRAIN envs (not play) do what the module docstrings say. no card, 8 envs.
gale: the per-env peak draw (training range), the force written to xfrc_applied on the trunk (opposite the heading, ramp x peak), zero at an episode's first step;
moon: gravity in the MuJoCo model AND the warp model (the cfg.sim.gravity trap: only the printed model value counts).
usage: PYTHONPATH=<src> python gm-envcheck-2026-10-28.py <gale|moon> [steps]
"""
import math
import os
import sys

os.environ.setdefault("MUJOCO_GL", "egl")
import torch  # noqa: E402

import mjlab_microduck.tasks  # noqa: E402,F401
from mjlab.envs import ManagerBasedRlEnv  # noqa: E402
from mjlab.tasks.registry import load_env_cfg  # noqa: E402

which = sys.argv[1]
steps = int(sys.argv[2]) if len(sys.argv) > 2 else 400
task = {"gale": "Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck", "moon": "Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck"}[which]
cfg = load_env_cfg(task)
cfg.scene.num_envs = 8
env = ManagerBasedRlEnv(cfg=cfg, device="cpu")
env.reset()
base = env
print(f"[check] task {task} envs {env.num_envs} train cfg, episode_length_s {cfg.episode_length_s}, step_dt {env.step_dt}")
print(f"[check] gravity mj_model={list(env.sim.mj_model.opt.gravity)} warp_model={env.sim.wp_model.opt.gravity.numpy().tolist()}")
robot = env.scene["robot"]
if which == "gale":
    from mjlab_microduck.tasks import witcheer_velocity_gale_env_cfg as g
    ids, _ = robot.find_bodies(["trunk_base"])
    print(f"[check] peak draw (N, per env): {[round(float(x), 2) for x in env._gale_peak]}  range {g.GALE_PEAK_RANGE}, ramp {g.GALE_RAMP_S} s")
    act = torch.zeros((env.num_envs, env.action_manager.total_action_dim), device="cpu")
    worst = 0.0
    wind_max = 1.0
    for k in range(steps):
        env.step(act)
        if k in (0, 49, 149, 299, steps - 1) or (k % 20 == 0 and float(env.episode_length_buf.max()) * env.step_dt > 2.0 and float(wind_max) < 0.01):
            f = robot.data.body_external_wrench[:, ids[0], :3]
            q = robot.data.root_link_quat_w
            yaw = torch.atan2(2 * (q[:, 0] * q[:, 3] + q[:, 1] * q[:, 2]), 1 - 2 * (q[:, 2] ** 2 + q[:, 3] ** 2))
            exp = g.wind_force_now(env)
            fx = f[:, 0]; fy = f[:, 1]
            along = -(fx * torch.cos(yaw) + fy * torch.sin(yaw))   # force component against the heading (should equal the wind magnitude)
            across = -fx * torch.sin(yaw) + fy * torch.cos(yaw)
            print(f"[check] step {k:3d} t_ep={[round(float(t) * env.step_dt, 2) for t in env.episode_length_buf[:3]]}.. wind_now(first 3)={[round(float(x), 3) for x in exp[:3]]} "
                  f"headwind component(first 3)={[round(float(x), 3) for x in along[:3]]} cross component max={float(across.abs().max()):.4f} fz max={float(f[:, 2].abs().max()):.4f}")
            worst = max(worst, float((along - exp).abs().max())); wind_max = 1.0
    print(f"[check] RESULT gale: max |applied headwind - expected| over the printed steps = {worst:.4f} N (one policy step of lag allowed)")
else:
    print(f"[check] RESULT moon: model gravity z = {float(env.sim.mj_model.opt.gravity[2]):+.3f} m/s^2, warp gravity z = {float(env.sim.wp_model.opt.gravity.numpy()[0][2]):+.3f}")
print("[check] done")
