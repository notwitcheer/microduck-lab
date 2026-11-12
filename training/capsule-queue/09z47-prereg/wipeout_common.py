"""wipeout_common.py: 09z47 duck wipeout. One kinematic spinning bar per env (a box, mocap-driven), added to the
EXISTING Microduck velocity task. No training, no new task id, sim only.

The bar is a fixed-base box entity written each policy step through mjlab's mocap buffers (mocap_pos/mocap_quat).
Pivot = env origin + PIVOT_X, centre height BAR_Z, yaw = W * t + pi/2 (long axis along y, across the duck's +x path).
Bar-duck contacts are ordinary MuJoCo contacts, counted per env in wipeout_count.py.
"""
import math
import os

import mujoco
import torch

from mjlab.entity import EntityCfg
from mjlab.managers import EventTermCfg

BAR_HALF_L = 0.30          # m, half-length: the bar is 0.60 m long, tip radius 0.30 m from the pivot
BAR_HALF_W = 0.020         # m, bar is 40 mm across (thickened: tip displacement per policy step at 4.5 rad/s is 27 mm, must stay under it)
BAR_HALF_H = 0.020         # m, 40 mm tall: sweeps the legs and the lower body
BAR_Z = 0.050              # m, centre height: bar spans z 0.030 to 0.070 m (shin height, UNVERIFIED on the real duck)
TRUNK_STAND_M = 0.1197     # m, Z_STAND of the walk policies (duck-queue-items / robotics-lane-ops)
SURVIVE_FRAC = 0.90        # survival = trunk height >= 0.90 x Z_STAND (prereg, FROZEN.sha256)
THR_M = SURVIVE_FRAC * TRUNK_STAND_M

PIVOT_X = 0.50             # m, pivot 0.50 m ahead of the env origin along +x. the sweep circle has radius BAR_HALF_L = 0.30 m, so the
                           # duck spawned at the origin is 0.20 m outside it (no spawn overlap). the bar's long axis is along x at
                           # yaw 0, so the +pi/2 offset in spin_bar puts it across the path (along y) at t = 0.
W = float(os.environ.get("WIPE_W", "3.0"))        # rad/s
TURNS = float(os.environ.get("WIPE_TURNS", "3"))  # full revolutions counted per env


def bar_spec() -> mujoco.MjSpec:
    spec = mujoco.MjSpec()
    body = spec.worldbody.add_body(name="bar")
    body.add_geom(
        name="bar_geom",
        type=mujoco.mjtGeom.mjGEOM_BOX,
        size=[BAR_HALF_L, BAR_HALF_W, BAR_HALF_H],
        rgba=[1.0, 0.35, 0.10, 1.0],
    )
    return spec


def spin_bar(env, env_ids) -> None:
    """step event: write every env's bar pose (pivot = env origin + PIVOT_X, yaw = W * t + pi/2)."""
    bar = env.scene["bar"]
    t = env.episode_length_buf.to(torch.float32) * env.step_dt
    yaw = W * t + math.pi / 2.0  # +pi/2 at t=0: the bar's long axis is across the duck's path (along y), a wall at x = PIVOT_X
    origins = env.scene.env_origins
    pose = torch.zeros((env.num_envs, 7), device=env.device)
    pose[:, 0] = origins[:, 0] + PIVOT_X
    pose[:, 1] = origins[:, 1]
    pose[:, 2] = BAR_Z
    pose[:, 3] = torch.cos(yaw / 2.0)  # quaternion (w, x, y, z), rotation about z only
    pose[:, 6] = torch.sin(yaw / 2.0)
    # mjlab's Entity.write_mocap_pose_to_sim broadcasts (N,1,3) into an (N,3) slice for a one-body mocap entity and
    # raises (smoke 2026-11-12), so the same two buffers are written here with the shape mocap_pos/mocap_quat carry.
    mid = bar.indexing.mocap_id
    d = bar.data.data
    d.mocap_pos[:, mid, :] = pose[:, 0:3]
    d.mocap_quat[:, mid, :] = pose[:, 3:7]


def add_bar(cfg) -> None:
    """add the bar entity and its per-step event to an mjlab env cfg (call before the env is built)."""
    cfg.scene.entities = {
        **cfg.scene.entities,
        "bar": EntityCfg(spec_fn=bar_spec, init_state=EntityCfg.InitialStateCfg(pos=(PIVOT_X, 0.0, BAR_Z))),
    }
    events = dict(cfg.events)
    events["spin_bar"] = EventTermCfg(func=spin_bar, mode="step")
    cfg.events = events


FWD_VX = 0.25              # m/s forced forward command (pre-registered): the walking duck is what meets the bar
ENV_SPACING = 1.2          # m, env grid spacing for the count (a 0.60 m bar needs room; the CPU smoke used the default spacing)
POLICY_DT = 0.02           # s, decimation 4 x 0.005 s


def revolution_steps(dt: float = POLICY_DT) -> int:
    """policy steps that cover TURNS full revolutions at W rad/s."""
    return int(round(TURNS * 2.0 * math.pi / W / dt))
