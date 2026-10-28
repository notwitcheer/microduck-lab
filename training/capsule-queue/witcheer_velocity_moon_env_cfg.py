"""witcheer fork: Microduck WALKS ON THE MOON (reduced gravity), gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck`` by one import line appended to the end of
``tasks/__init__.py``; nothing else in the Pollen tree is edited.

What this is: the maker's backlash walk env (``Mjlab-Velocity-Flat-Backlash-MicroDuck``, walk backlash robot, 61-dim actor obs, 14
actions: the published walk policies' dims, so a warm start is a true resume) with

- gravity 1.62 m/s^2 (the Moon, 0.165 g) instead of 9.81, set through ``cfg.sim.mujoco.gravity`` (the field that reaches the model;
  ``cfg.sim.gravity`` is silently ignored, the 2026-10-27 probe trap: the first "moon" numbers were earth in disguise and only the printed
  ``opt.gravity`` line exposed it). Mars is the same task with ``MICRODUCK_MOON_G=3.71`` at process start (a play-time override).
  Gravity is a build-time model constant in mjlab (no domain-randomisation hook), so one training run = one gravity.
- the twist command fixed to a FORWARD walk (vx in ``MOON_VX``, default 0.15-0.35 m/s, vy 0, wz 0, no standing / turn envs, one command per 20 s
  episode); the ``standing_envs`` curriculum is dropped (it would re-impose standing envs on a resumed checkpoint);
- everything else (rewards, terminations, DR, curricula, the maker's shoves, observations, robot) untouched. NO reward asks for a bound or a
  flight phase: the reward is the maker's velocity tracking + walk shaping, so whatever gait appears is what tracking in 0.165 g produces. The
  proof counts flight phases and only a take that shows them is captioned as a bound.

Seed probe (2026-10-27, scripts/cond_probe.py, walk-flat v2, forced 0.2 m/s, 8 s, 64 envs): moon 0.165 g held 61/64, forward travel +0.25 m
(a third of Earth's +0.71 m); Mars 0.38 g held 64/64, +0.36 m. It does not fall, it loses traction and shuffles. Physics caveat: the actuator
model, the gear play and the feet's friction are the Earth-tuned maker values, nothing is re-tuned for the Moon.

Overrides (read at import, i.e. at process start; unset = the values above, so the training env never sees them):
- ``MICRODUCK_MOON_G=g``      gravity magnitude in m/s^2 (default 1.62; 3.71 = Mars, 9.81 = Earth control in the same env).
- ``MICRODUCK_MOON_VX=lo,hi`` forward command range.
"""

import os

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck"

MOON_G = float(os.environ.get("MICRODUCK_MOON_G", "1.62"))


def _pair(name, default):
    v = os.environ.get(name)
    if not v:
        return default
    lo, hi = (float(x) for x in v.split(","))
    return lo, hi


MOON_VX = _pair("MICRODUCK_MOON_VX", (0.15, 0.35))


def make_witcheer_velocity_moon_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.sim.mujoco.gravity = (0.0, 0.0, -MOON_G)

    tw = cfg.commands["twist"]
    tw.ranges.lin_vel_x = MOON_VX
    tw.ranges.lin_vel_y = (0.0, 0.0)
    tw.ranges.ang_vel_z = (0.0, 0.0)
    for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs"):
        if hasattr(tw, k):
            setattr(tw, k, 0.0)
    if hasattr(tw, "resampling_time_range"):
        tw.resampling_time_range = (cfg.episode_length_s, cfg.episode_length_s)
    cfg.curriculum.pop("standing_envs", None)
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_moon_env_cfg(),
    play_env_cfg=make_witcheer_velocity_moon_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
