"""witcheer fork: Microduck walk with gear play over SLOPES.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck`` by one import line appended
to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

What changes against the maker's ``Mjlab-Velocity-Flat-Backlash-MicroDuck``
(walk-flat v2 on the Hub): ONE thing, the floor. The maker trains this task on
an infinite plane (``terrain_type="plane"``). This fork swaps the plane for a
generated floor of gentle hills: every 4 m tile is one heightfield pyramid
(mjlab ``HfPyramidSlopedTerrainCfg``, the same generator and the same 1 mm
vertical resolution the maker's rough grid uses for its ``pyramid_slope``
patches), flat top in the middle, sloping down to floor level at the tile
edge, so a duck walking straight from its spawn goes down one hill and up the
next. Gradient (rise / run) is drawn per tile uniformly from 0.05 to 0.15
(about 2.9 to 8.5 deg). The maker's rough patches stop at 0.10 ("small robot,
small slopes"), so the top of this range is 1.5x past their cap, the same
choice the step fork made for step height (25 mm vs their 15 mm).

Shape of one tile (mjlab's generator, not ours): the height is
``h_max * x * y`` with x, y the normalised distances from the tile edge, then
clipped at the platform height, so the flat top is a four-pointed star about
1.0 m (diagonal) to 1.15 m (axis) from the tile centre, and the slope runs from
there to the tile edge (2.0 m on the axis). At gradient 0.15 the top sits
127 mm above the floor, about the duck's own trunk height. Random mode
(``curriculum=False``, the mjlab default the maker's flat task never touches),
10 x 10 tiles, no terrain-level curriculum (the maker's flat cfg deletes it and
so does this fork). NOT inverted: the maker removed inverted pyramids from
their rough grid because the env origin lands in the pit.

Height reads: the env origin sits on the hill top, so any read of
``root_z - env_origin_z`` is off by the hill height once the duck walks down.
Our clone's ``ground_height_patch.py`` makes ``_ground_z`` read the
``foot_height_scan`` ray hits on generator terrain, and in this task the only
active term that reads height (``head_pose_bias``) goes through it.
``body_pose_tracking_6d`` reads the origin directly but has weight 0 in the
velocity task. ``out_of_terrain_bounds`` becomes live with a generator floor
(a no-op on a plane); the 40 m grid plus the 20 m outer border means a 20 s
episode cannot reach it.

Everything else (rewards, terminations, pushes, backlash robot, curricula,
mass and friction DR, solver settings, observations: the policy still has no
terrain scan, it meets the slope blind like the real robot would) is the
maker's. The maker's rough branch also softens terrain contacts and raises
solver iterations; this fork does not, to keep one variable (the step fork made
the same call). ``nan_state`` covers contact-force NaNs since the maker's
2026-08-21 hfield-slope crash; watch it in the probe.

Verdict override: ``MICRODUCK_SLOPE=lo,hi`` (rise / run, read at import, i.e.
at process start) replaces the gradient range, so play takes can force the
steepest hill (``0.15,0.15``) or a near-flat floor on the same layout
(``0.001,0.001`` = a 1 mm top) for both the seed and the fork.
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

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck"

SLOPE_RANGE = (0.05, 0.15)  # rise / run; maker's rough pyramid_slope is (0.03, 0.10)
TILE = 4.0  # m, one hill per tile (same tile as the step fork)
PLATFORM = 1.5  # m, platform_width passed to the generator (same as the step fork)


def _slope_range():
    v = os.environ.get("MICRODUCK_SLOPE")
    if v:
        lo, hi = (float(x) for x in v.split(","))
        return lo, hi
    return SLOPE_RANGE


SLOPE_TERRAIN_CFG = TerrainGeneratorCfg(
    size=(TILE, TILE),
    border_width=20.0,  # same outer border as the maker's rough grid
    num_rows=10,
    num_cols=10,
    curriculum=False,
    sub_terrains={
        "hill": terrain_gen.HfPyramidSlopedTerrainCfg(
            proportion=1.0,
            slope_range=_slope_range(),
            platform_width=PLATFORM,
            vertical_scale=0.001,  # maker's value: 1 mm steps, smooth gentle slopes
        ),
    },
    add_lights=False,
)


def make_witcheer_velocity_slope_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.scene.terrain.terrain_type = "generator"
    cfg.scene.terrain.terrain_generator = deepcopy(SLOPE_TERRAIN_CFG)
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_slope_env_cfg(),
    play_env_cfg=make_witcheer_velocity_slope_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
