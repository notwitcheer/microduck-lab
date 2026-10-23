"""witcheer fork: Microduck walk with gear play AND a payload on the back.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck`` by one import line
appended to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is
edited.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``
(walk-flat v2 on the Hub): ONE parameter. The maker already randomises the
trunk mass at startup with mjlab's ``pseudo_inertia`` (mass and inertia scaled
together by e^(2*alpha), CoM unchanged), on ``trunk_base`` only, over +-5%
(``MASS_INERTIA_RANDOMIZATION_RANGE = (0.95, 1.05)``). This fork widens the top
of that range to 1.30: each env carries a fixed trunk mass between 0.95x and
1.30x for the whole run. The trunk is 199.2 g of a 737.2 g robot (compiled
model, 2026-10-11), so 1.30x is about +60 g, roughly 8% of the robot: the
order of a small camera or battery pack strapped to the back. Everything else
(rewards, terminations, pushes, backlash robot, curricula) is the maker's.

Known limit: pseudo_inertia keeps the CoM where it was, so this is extra mass
and inertia at the trunk, not a raised CoM. ``randomize_com`` (maker, +-15 mm)
still runs on top.

Verdict override: ``MICRODUCK_PAYLOAD_SCALE=lo,hi`` (read at import, i.e. at
process start) replaces the range, so play takes can force the heaviest case
(``1.30,1.30``) or no payload (``1.0,1.0``) for both the seed and the fork.
"""

import math
import os

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck"

PAYLOAD_SCALE = (0.95, 1.30)  # trunk mass scale; maker default (0.95, 1.05)


def _scale_range():
    v = os.environ.get("MICRODUCK_PAYLOAD_SCALE")
    if v:
        lo, hi = (float(x) for x in v.split(","))
        return lo, hi
    return PAYLOAD_SCALE


def make_witcheer_velocity_payload_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    lo, hi = _scale_range()
    ev = cfg.events["randomize_mass_inertia"]
    ev.params["alpha_range"] = (math.log(lo) / 2.0, math.log(hi) / 2.0)
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_payload_env_cfg(),
    play_env_cfg=make_witcheer_velocity_payload_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
