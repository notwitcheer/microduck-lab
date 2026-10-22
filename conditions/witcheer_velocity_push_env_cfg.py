"""witcheer fork: Microduck walk with gear play under STRONGER PUSHES.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Push-MicroDuck`` by one import line appended
to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``
(walk-flat v2 on the Hub): ONE thing, the size of the training shove. The
maker's ``push_robot`` event (``mdp.push_by_setting_velocity``, mode
``interval``) ADDS a random root velocity change drawn per axis from
``VELOCITY_PUSH_RANGE`` = (-0.3, 0.3) m/s in x and y, every 3 to 6 s
(``VELOCITY_PUSH_INTERVAL_S``) in training. This fork multiplies the x and y
ranges by ``PUSH_SCALE`` = 2.0, i.e. (-0.6, 0.6) m/s. The interval stays the
maker's 3-6 s, so the duck is shoved as often as before, only harder.

Read before trusting a gain: the maker's cfg comment says their earlier
+-0.5 m/s ("an ADDITIVE kick larger than max walk speed (0.4) every 3-6 s")
trained "a permanently nervous fall-recovery gait" (2026-07 audit), and they
cut it to +-0.3 so a calmer gait could be optimal. +-0.6 is past that line on
purpose: this fork asks whether harder shoves buy push robustness and what it
costs the calm gait. The verdict therefore includes the maker-strength control
and the training windows (error_vel_xy, fell_over) against walk-flat v2.

Play: the maker's play branch shortens the push interval to 0.5-1.0 s "for
better visibility", same range. This fork keeps that and scales the range the
same way, so a play take at the default scale is a strong shove every 0.5-1 s.

Everything else (rewards, terminations, backlash robot, curricula, mass and
friction DR, solver settings, observations) is the maker's.

Verdict overrides (read at import, i.e. at process start; unset = the values
above, so the training env never sees them):
- ``MICRODUCK_PUSH_SCALE=s`` replaces 2.0 (``1.0`` = the maker's +-0.3 m/s),
  so play takes can run the seed and the fork under the same shove.
- ``MICRODUCK_PUSH_INTERVAL=lo,hi`` in seconds replaces the interval of
  whichever cfg is built (train 3-6 s, play 0.5-1.0 s), so a play take can use
  the training cadence.
"""

import os

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Push-MicroDuck"

PUSH_SCALE = 2.0  # x the maker's VELOCITY_PUSH_RANGE (-0.3, 0.3) m/s -> (-0.6, 0.6)


def _push_scale():
    v = os.environ.get("MICRODUCK_PUSH_SCALE")
    return float(v) if v else PUSH_SCALE


def _push_interval():
    v = os.environ.get("MICRODUCK_PUSH_INTERVAL")
    if v:
        lo, hi = (float(x) for x in v.split(","))
        return lo, hi
    return None


def make_witcheer_velocity_push_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    push = cfg.events["push_robot"]  # KeyError if the maker ever turns ENABLE_VELOCITY_PUSHES off: loud on purpose
    s = _push_scale()
    vr = push.params["velocity_range"]
    push.params["velocity_range"] = {k: (lo * s, hi * s) for k, (lo, hi) in vr.items()}
    iv = _push_interval()
    if iv is not None:
        push.interval_range_s = iv
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_push_env_cfg(),
    play_env_cfg=make_witcheer_velocity_push_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
