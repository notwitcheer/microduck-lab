"""witcheer fork: Microduck walk with gear play under the MIX conditions plus SLOPES, at once.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck`` by one import line
appended to the end of ``tasks/__init__.py``; nothing else in the Pollen tree
is edited.

Why: two own-condition forks gained on 2026-10-22 (verdicts four days after
training): 09z5 walk-slope (hill 0.15, pooled 23/30 vs walk-flat v2 12/30) and
09z6 walk-mix (step + slippery feet + 2x shoves, 9/15 vs 0/15). A real owner
installs ONE walk policy, so this fork asks whether walk-mix can also carry
the hills without losing its own condition or walk-slope's.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``
(all imported from the single-condition modules, nothing copied):
- floor: one generator, two tile types drawn per 4 m tile with proportion
  0.5 / 0.5 (mjlab random mode, ``curriculum=False``): the single-step tile of
  ``witcheer_velocity_step_env_cfg`` (1.5 m platform, 10-25 mm step) and the
  heightfield hill tile of ``witcheer_velocity_slope_env_cfg`` (gradient
  0.05-0.15). Same tile size (4 m), grid (10 x 10) and 20 m border in both
  source cfgs, so the grid is unchanged; only the tile type varies.
- foot friction DR (0.7, 1.3) -> (0.2, 1.3), as ``witcheer_velocity_slip_env_cfg``;
- training shoves x2 (+-0.6 m/s, maker interval), as ``witcheer_velocity_push_env_cfg``.
Everything else is the maker's. Because the source modules are imported, their
verdict overrides work here unchanged (all read at import, i.e. process start):
``MICRODUCK_STEP_HEIGHT``, ``MICRODUCK_SLOPE``, ``MICRODUCK_FOOT_FRICTION``,
``MICRODUCK_PUSH_SCALE``, ``MICRODUCK_PUSH_INTERVAL``.

Height reads: half the tiles are heightfield hills, so the env origin can sit
on a hill top; our clone's ``ground_height_patch.py`` (``_ground_z`` from the
``foot_height_scan`` hits on generator terrain) covers both tile types.
Heightfield floors cost ~2x per iteration (09z5 probe 2.55 s/it vs 1.29 on
the step-only mix): probe before promising a block.

Warm start: walk-mix (09z6 model_13000), 13000 -> 16000 (3k rule).
"""

from copy import deepcopy

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg
from mjlab_microduck.tasks.witcheer_velocity_step_env_cfg import SINGLE_STEP_TERRAIN_CFG
from mjlab_microduck.tasks.witcheer_velocity_slope_env_cfg import SLOPE_TERRAIN_CFG
from mjlab_microduck.tasks.witcheer_velocity_slip_env_cfg import _friction_range
from mjlab_microduck.tasks.witcheer_velocity_push_env_cfg import _push_scale, _push_interval

TASK_ID = "Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck"
STEP_SHARE = 0.5  # share of tiles that are single-step tiles; the rest are hill tiles


def _mixslope_terrain_cfg():
    t = deepcopy(SINGLE_STEP_TERRAIN_CFG)
    step = deepcopy(SINGLE_STEP_TERRAIN_CFG.sub_terrains["single_step"])
    hill = deepcopy(SLOPE_TERRAIN_CFG.sub_terrains["hill"])
    step.proportion = STEP_SHARE
    hill.proportion = 1.0 - STEP_SHARE
    t.sub_terrains = {"single_step": step, "hill": hill}
    return t


def make_witcheer_velocity_mixslope_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.scene.terrain.terrain_type = "generator"
    cfg.scene.terrain.terrain_generator = _mixslope_terrain_cfg()
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
    env_cfg=make_witcheer_velocity_mixslope_env_cfg(),
    play_env_cfg=make_witcheer_velocity_mixslope_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
