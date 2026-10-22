"""witcheer fork: Microduck walk with gear play under the THREE conditions that paid, at once.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck`` by one import line appended
to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why: the own-conditions track trained one condition per policy against
walk-flat v2. Two were clear gains (09z2 slippery floor -> walk-slip, 09z3
single step -> walk-step) and one gained at its training cadence (09z4
stronger pushes). A real owner installs ONE walk policy, so this fork asks
whether one policy can carry all three without losing any of them.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``:
- floor: the single-step generator of ``witcheer_velocity_step_env_cfg``
  (one 1.5 m platform per 4 m tile, 10-25 mm step at every edge);
- foot friction DR (0.7, 1.3) -> (0.2, 1.3), as ``witcheer_velocity_slip_env_cfg``;
- training shoves x2 (+-0.6 m/s, maker interval), as ``witcheer_velocity_push_env_cfg``.
Everything else is the maker's. The three source modules are imported, not
copied, so their verdict overrides work here unchanged:
``MICRODUCK_STEP_HEIGHT``, ``MICRODUCK_FOOT_FRICTION``, ``MICRODUCK_PUSH_SCALE``,
``MICRODUCK_PUSH_INTERVAL`` (all read at import, i.e. at process start).

Warm start: walk-step v1 (09z3 model_10000), the policy that already meets the
step; 10000 -> 13000 (3k rule).
"""

from copy import deepcopy

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg
from mjlab_microduck.tasks.witcheer_velocity_step_env_cfg import SINGLE_STEP_TERRAIN_CFG
from mjlab_microduck.tasks.witcheer_velocity_slip_env_cfg import _friction_range
from mjlab_microduck.tasks.witcheer_velocity_push_env_cfg import _push_scale, _push_interval

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck"


def make_witcheer_velocity_mix_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.scene.terrain.terrain_type = "generator"
    cfg.scene.terrain.terrain_generator = deepcopy(SINGLE_STEP_TERRAIN_CFG)
    cfg.events["foot_friction"].params["ranges"] = _friction_range()
    push = cfg.events["push_robot"]
    s = _push_scale()
    push.params["velocity_range"] = {k: (lo * s, hi * s) for k, (lo, hi) in push.params["velocity_range"].items()}
    iv = _push_interval()
    if iv is not None:
        push.interval_range_s = iv
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_mix_env_cfg(),
    play_env_cfg=make_witcheer_velocity_mix_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
