"""witcheer fork: Microduck walk with gear play over a SINGLE STEP.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Step-MicroDuck`` by one import line appended
to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``
(walk-flat v2 on the Hub): ONE thing, the floor. The maker trains this task on
an infinite plane (``terrain_type="plane"``). This fork swaps the plane for a
generated floor that is flat except for one raised square per 4 m tile: a
1.5 m platform whose top sits 10 to 25 mm above the surrounding floor, with
2.5 m of flat floor between neighbouring platforms. Every edge crossing is a
single step, down when the duck walks off its spawn platform, up when it walks
onto the next one. A Microduck stands ~117 mm tall at the trunk and lifts its
feet ~1-2 cm (maker's rough-terrain comment, which caps their stairs at
1.5 cm), so 25 mm is a real step for it.

How the floor is built: mjlab's ``BoxPyramidStairsTerrainCfg`` with a border
wide enough that zero stairs fit (``num_steps = int((4 - 2*1.25 - 1.5) /
(2*1.0)) = 0``), which leaves the border frame at z = 0 and one centre box with
its top at the step height. Random mode (``curriculum=False``, the mjlab
default the maker's flat task never touches), so each of the 10 x 10 tiles gets
its own height drawn uniformly from (10, 25) mm; no terrain-level curriculum
(the maker's flat cfg deletes it and so does this fork).

Height reads: the env origin sits on the platform top, so any read of
``root_z - env_origin_z`` is off by the step height once the duck steps down.
Our clone's ``ground_height_patch.py`` makes ``_ground_z`` read the
``foot_height_scan`` ray hits on generator terrain, and in this task the only
active term that reads height (``head_pose_bias``) goes through it.
``body_pose_tracking_6d`` reads the origin directly but has weight 0 in the
velocity task. ``out_of_terrain_bounds`` becomes live with a generator floor
(it is a no-op on a plane); the 40 m grid plus the 20 m outer border means a
20 s episode cannot reach it.

Everything else (rewards, terminations, pushes, backlash robot, curricula,
mass and friction DR, solver settings, observations: the policy still has no
terrain scan, it meets the step blind like the real robot would) is the maker's.
The maker's rough branch also softens terrain box contacts and raises solver
iterations; this fork does not, to keep one variable. Watch ``nan_state``.

Verdict override: ``MICRODUCK_STEP_HEIGHT=lo,hi`` in metres (read at import,
i.e. at process start) replaces the height range, so play takes can force the
tallest step (``0.025,0.025``) or a flat floor on the same layout
(``0.0,0.0``) for both the seed and the fork.
"""

import os
from copy import deepcopy

import mjlab.terrains as terrain_gen
from mjlab.terrains.terrain_generator import TerrainGeneratorCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Step-MicroDuck"

STEP_HEIGHT = (0.010, 0.025)  # metres; maker's rough stairs top out at 0.015
TILE = 4.0  # m, one platform per tile
PLATFORM = 1.5  # m, side of the raised square
BORDER = (TILE - PLATFORM) / 2.0  # 1.25 m of floor around it -> 2.5 m between platforms


def _step_range():
    v = os.environ.get("MICRODUCK_STEP_HEIGHT")
    if v:
        lo, hi = (float(x) for x in v.split(","))
        return lo, hi
    return STEP_HEIGHT


SINGLE_STEP_TERRAIN_CFG = TerrainGeneratorCfg(
    size=(TILE, TILE),
    border_width=20.0,  # same outer border as the maker's rough grid
    num_rows=10,
    num_cols=10,
    curriculum=False,
    sub_terrains={
        "single_step": terrain_gen.BoxPyramidStairsTerrainCfg(
            proportion=1.0,
            step_height_range=_step_range(),
            step_width=1.0,  # unused: zero stairs fit, see the docstring
            platform_width=PLATFORM,
            border_width=BORDER,
        ),
    },
    add_lights=False,
)


def make_witcheer_velocity_step_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.scene.terrain.terrain_type = "generator"
    cfg.scene.terrain.terrain_generator = deepcopy(SINGLE_STEP_TERRAIN_CFG)
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_step_env_cfg(),
    play_env_cfg=make_witcheer_velocity_step_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
