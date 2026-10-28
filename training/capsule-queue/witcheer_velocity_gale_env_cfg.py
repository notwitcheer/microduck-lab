"""witcheer fork: Microduck WALKS INTO A RISING WIND (the gale), gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck`` by one import line appended to the end of
``tasks/__init__.py``; nothing else in the Pollen tree is edited.

What this is: the maker's backlash walk env (``Mjlab-Velocity-Flat-Backlash-MicroDuck``, walk backlash robot, 61-dim actor obs, 14
actions: the published walk policies' dims, so a warm start is a true resume) with

- the twist command fixed to a FORWARD walk (vx in ``GALE_VX``, default 0.15-0.30 m/s, vy 0, wz 0, no standing / turn envs, one command per
  20 s episode); the ``standing_envs`` curriculum is dropped (it would re-impose standing envs on a resumed checkpoint);
- a WIND: one constant-direction external force on the trunk body (``Entity.write_external_wrench_to_sim`` = ``xfrc_applied``, world frame,
  applied at the trunk's centre of mass so it adds no torque by itself: the duck has to lean and step against it), pointing against the
  direction the duck FACES (the heading of the trunk at the current step, so the wind is always a headwind for a straight walk) and
  growing linearly from 0 to the episode's peak over ``GALE_RAMP_S`` seconds (default 12 s), then held at the peak until the episode
  ends (20 s). It is a ``step`` event (every 20 ms policy step, all envs) plus a ``reset`` event that draws the episode's peak force.
  Training draws the peak per episode uniformly from ``GALE_PEAK_RANGE`` (default 1.0-4.0 N); the duck weighs ~7.8 N, so 1 N is ~13% of its weight. The play env
  uses one fixed peak, 3.0 N (``GALE_PLAY_PEAK``, 38% of its weight): the proof condition (the seeds collapse at ~2.5 N, see below).
- everything else (rewards, terminations, DR, curricula, the maker's shoves, observations, robot) untouched. The actor does not observe the
  wind (a new obs term would break the warm start): the policy has to feel it through the body's own tilt and speed, like the push policies do.

The wind is a constant force, not aerodynamics (no gusts, no drag on moving limbs). A very rough conversion, UNVERIFIED and not used
in any caption: drag on a 25 cm by 10 cm frontal area at Cd 1 is ~0.015 v^2 N, so 2 N is a ~11.5 m/s (~40 km/h) wind.

Seed probes: (1) 2026-10-27, scripts/cond_probe.py, walk-flat v2, constant force from t = 0: holds ~0.5 N, is pushed backwards at 1 N, falls at 2 N, with a 3-4
degree lean on the survivors. (2) 2026-10-28, THIS env (ramp 12 s, forced vx 0.25, no shoves, 14 s takes, CPU, 1 env per take, ``gm_play.py``): walk-flat v2, walk-mixslope 16000 and
walk-stairs 19000 all hold a 2.0 N peak in 3-5 of 6 takes and collapse at a median 2.4-2.8 N when the peak is 3.0 N or more (0 of 6 / 0 of 12 held at 3.0, 3.5, 4.0 N), with a median
lean of 0 +- 3 degrees: no visible lean into the wind. The lean the clip wants has to be trained (log: vault 60-robotics/microduck/log.md 2026-10-28).

Overrides (read at import, i.e. at process start; unset = the values above, so the training env never sees them):
- ``MICRODUCK_GALE_PEAK=N``       one fixed peak force for every episode (play default 2.0 N; setting it in the training env pins the peak).
- ``MICRODUCK_GALE_PEAK_RANGE=lo,hi``  training draw (default 1.0,4.0).
- ``MICRODUCK_GALE_RAMP=s``       seconds from 0 to the peak (default 12).
- ``MICRODUCK_GALE_VX=lo,hi``     forward command range.
- ``MICRODUCK_GALE_OFF=1``        no wind at all (the control take in the same env).
"""

import math
import os

import torch
from mjlab.managers import EventTermCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck"

GALE_PLAY_PEAK = 3.0


def _pair(name, default):
    v = os.environ.get(name)
    if not v:
        return default
    lo, hi = (float(x) for x in v.split(","))
    return lo, hi


GALE_PEAK_FIXED = float(os.environ["MICRODUCK_GALE_PEAK"]) if os.environ.get("MICRODUCK_GALE_PEAK") else None
GALE_PEAK_RANGE = _pair("MICRODUCK_GALE_PEAK_RANGE", (1.0, 4.0))
GALE_RAMP_S = float(os.environ.get("MICRODUCK_GALE_RAMP", "12.0"))
GALE_VX = _pair("MICRODUCK_GALE_VX", (0.15, 0.30))
GALE_OFF = os.environ.get("MICRODUCK_GALE_OFF", "") not in ("", "0")

_TRUNK = {}


def _trunk_ids(env):
    key = id(env)
    if key not in _TRUNK:
        ids, _ = env.scene["robot"].find_bodies(["trunk_base"])
        _TRUNK[key] = list(ids)
    return _TRUNK[key]


def _peak(env):
    p = getattr(env, "_gale_peak", None)
    if p is None:
        p = torch.zeros(env.num_envs, device=env.device)
        env._gale_peak = p
    return p


def gale_reset(env, env_ids, play_fixed: bool = False):
    """reset event: draw this episode's peak force (N) for the resetting envs."""
    p = _peak(env)
    if isinstance(env_ids, slice) or env_ids is None:
        env_ids = torch.arange(env.num_envs, device=env.device)
    n = len(env_ids)
    if GALE_PEAK_FIXED is not None:
        p[env_ids] = GALE_PEAK_FIXED
    elif play_fixed:
        p[env_ids] = GALE_PLAY_PEAK
    else:
        lo, hi = GALE_PEAK_RANGE
        p[env_ids] = torch.rand(n, device=env.device) * (hi - lo) + lo


def wind_force_now(env):
    """(N,) wind force magnitude in newtons at the current step (the episode's ramp x its peak)."""
    t = env.episode_length_buf.to(torch.float32) * env.step_dt
    ramp = torch.clamp(t / max(GALE_RAMP_S, 1e-6), 0.0, 1.0)
    return _peak(env) * ramp * (0.0 if GALE_OFF else 1.0)


def gale_wind(env, env_ids):
    """step event: write the headwind (against the trunk's current heading) to xfrc_applied on the trunk, every policy step, every env."""
    robot = env.scene["robot"]
    ids = _trunk_ids(env)
    q = robot.data.root_link_quat_w
    w, x, y, z = q[:, 0], q[:, 1], q[:, 2], q[:, 3]
    yaw = torch.atan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z))
    f = wind_force_now(env)
    forces = torch.zeros((env.num_envs, len(ids), 3), device=env.device)
    forces[:, :, 0] = (-f * torch.cos(yaw)).unsqueeze(1)
    forces[:, :, 1] = (-f * torch.sin(yaw)).unsqueeze(1)
    robot.write_external_wrench_to_sim(forces, torch.zeros_like(forces), body_ids=ids)


def make_witcheer_velocity_gale_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)

    # forward walk only, one command per episode (the wind is a HEADwind only if the duck walks into it)
    tw = cfg.commands["twist"]
    tw.ranges.lin_vel_x = GALE_VX
    tw.ranges.lin_vel_y = (0.0, 0.0)
    tw.ranges.ang_vel_z = (0.0, 0.0)
    for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs"):
        if hasattr(tw, k):
            setattr(tw, k, 0.0)
    if hasattr(tw, "resampling_time_range"):
        tw.resampling_time_range = (cfg.episode_length_s, cfg.episode_length_s)
    cfg.curriculum.pop("standing_envs", None)

    # the wind: peak drawn at every reset (after reset_base, dict order), force written every step
    events = dict(cfg.events)
    events["gale_reset"] = EventTermCfg(func=gale_reset, mode="reset", params={"play_fixed": bool(play)})
    events["gale_wind"] = EventTermCfg(func=gale_wind, mode="step")
    cfg.events = events
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_gale_env_cfg(),
    play_env_cfg=make_witcheer_velocity_gale_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
