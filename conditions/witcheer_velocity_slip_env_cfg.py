"""witcheer fork: Microduck walk with gear play on a SLIPPERY floor.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck`` by one import line appended
to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``
(walk-flat v2 on the Hub): ONE parameter. The maker randomises the foot
friction at startup (mjlab ``dr.geom_friction``, ``operation="abs"``,
``shared_random=True``) on ``left_foot_collision`` / ``right_foot_collision``
over (0.7, 1.3), narrowed from mjlab's (0.3, 1.2) default ("Grippier footpad",
``microduck_velocity_env_cfg.py``). This fork lowers the bottom of that range
to 0.2: each env walks with a fixed foot friction between 0.2 and 1.3 for the
whole run.

Why the foot friction is the floor friction here: the robot cfg gives the foot
collision geoms ``priority=1`` (``microduck_constants.py``), and MuJoCo uses the
higher-priority geom's friction for a contact, so the floor's own value never
enters a foot contact. A low foot friction therefore models a slippery floor
(polished tile, laminate, a sheet of paper) as much as a worn pad.

Everything else (rewards, terminations, pushes, backlash robot, curricula,
mass DR) is the maker's.

Verdict override: ``MICRODUCK_FOOT_FRICTION=lo,hi`` (read at import, i.e. at
process start) replaces the range, so play takes can force the slipperiest case
(``0.2,0.2``) or a normal floor (``1.0,1.0``) for both the seed and the fork.
"""

import os

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck"

FOOT_FRICTION = (0.2, 1.3)  # maker (0.7, 1.3), mjlab default (0.3, 1.2)


def _friction_range():
    v = os.environ.get("MICRODUCK_FOOT_FRICTION")
    if v:
        lo, hi = (float(x) for x in v.split(","))
        return lo, hi
    return FOOT_FRICTION


def make_witcheer_velocity_slip_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.events["foot_friction"].params["ranges"] = _friction_range()
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_slip_env_cfg(),
    play_env_cfg=make_witcheer_velocity_slip_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
