"""witcheer fork: Microduck walk with gear play over short FLIGHTS OF 2-3 STEPS, in the mix conditions.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck`` by one import line
appended to the end of ``tasks/__init__.py``; nothing else in the Pollen tree
is edited.

Why: the single-step fork (09z3) was a GAIN, and the mix/mixslope forks
carry steps, slippery feet, 2x shoves and hills in one policy (walk-mixslope
is the newest published walk). The next honest question is the one a real
staircase asks: can the same policy climb up and down a short flight, where
the second riser arrives one stride after the first. Warm start is the
walk-mixslope final checkpoint (09z7 model_16000), 16000 -> 19000 (3k rule).

What changes against walk-mixslope's task (``Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck``,
every other line of its cfg is reused, nothing copied): ONLY the tile mix of the
generated floor. Same 4 m tiles, 10 x 10 grid, 20 m outer border, random mode
(``curriculum=False``), foot friction DR (0.2, 1.3), shoves x2 at the maker
interval, backlash robot. Tile types, drawn per tile with these shares:

- ``stairs2`` 0.25: a pyramid of TWO risers (floor -> h -> 2h), one tread of
  0.25 m between them, then a 2.5 m square platform at 2h (the env origin).
- ``stairs3`` 0.25: THREE risers (floor -> h -> 2h -> 3h), two treads of 0.25 m,
  then a 2.0 m square platform at 3h.
- ``single_step`` 0.15: the 09z3 tile (1.5 m platform, one riser), so the
  single-step skill is rehearsed.
- ``hill`` 0.15: the 09z5 heightfield tile (gradient 0.05-0.15), so the slope
  skill walk-mixslope carries is rehearsed.
- ``flat`` 0.20: a plain 4 m floor at z = 0, so walking on the flat is not lost.

Riser height ``h`` is drawn per tile uniformly from (10, 25) mm, the band the
single-step fork gained on (maker's rough stairs top out at 15 mm). The top of a
3-step flight is therefore 30 to 75 mm above the floor, about 0.26 to 0.64 of
the Microduck's 117 mm trunk height. The tread (0.25 m) is the maker's rough
stairs tread (0.15 m) stretched to about one stride; the policy has no terrain
scan, it meets every riser blind.

How the flights are built: mjlab's ``BoxPyramidStairsTerrainCfg``. It builds
``num_steps = int((size - 2*border - platform_width) / (2*step_width))``
concentric steps and a centre box, so the flight has ``num_steps + 1`` risers
(``num_steps = 0`` is the 09z3 single step) and the centre box top is
``(num_steps + 1) * h`` above the border frame at z = 0. ``platform_width`` is
only used in that count, so each tile passes the value that lands the quotient at
``num_steps + 0.5`` (never an exact integer, no float edge) and the real
platform is ``size - 2*border - 2*num_steps*step_width``. Between two
neighbouring tiles there is 1.0 m of flat floor (border 0.5 m on each side).

Height reads: the env origin sits on the platform top (``(num_steps + 1) * h``),
so any read of ``root_z - env_origin_z`` is off once the duck steps down. Our
clone's ``ground_height_patch.py`` makes ``_ground_z`` read the
``foot_height_scan`` ray hits on generator terrain, which covers box stairs and
hills alike (09z3, 09z5 and 09z7 already ran on both).

Verdict overrides (read at import, i.e. at process start): ``MICRODUCK_STEP_HEIGHT=lo,hi``
(riser height of stairs AND single steps, metres), ``MICRODUCK_SLOPE``,
``MICRODUCK_FOOT_FRICTION``, ``MICRODUCK_PUSH_SCALE``, ``MICRODUCK_PUSH_INTERVAL``
(these five are imported from the single-condition modules and work here unchanged),
and ``MICRODUCK_STAIRS_MIX=stairs2:0.5,stairs3:0.5`` (this module): replaces the tile
shares, tile types not named get share 0. A 1-env play take lands on one random tile,
so a stairs verdict forces the mix to flights only (a take on a flat or hill tile would
dilute it); ``flat:1`` gives a flat-floor control on the same generator.
"""

import os

from copy import deepcopy

import mjlab.terrains as terrain_gen
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg
from mjlab_microduck.tasks.witcheer_velocity_step_env_cfg import SINGLE_STEP_TERRAIN_CFG, _step_range
from mjlab_microduck.tasks.witcheer_velocity_slope_env_cfg import SLOPE_TERRAIN_CFG
from mjlab_microduck.tasks.witcheer_velocity_slip_env_cfg import _friction_range
from mjlab_microduck.tasks.witcheer_velocity_push_env_cfg import _push_scale, _push_interval

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck"

TILE = 4.0  # m, same tile as the step/slope/mixslope forks
STAIR_BORDER = 0.5  # m of flat floor around a flight -> 1.0 m between neighbouring tiles
TREAD = 0.25  # m, depth of each step (maker's rough stairs 0.15)
SHARES = {"stairs2": 0.25, "stairs3": 0.25, "single_step": 0.15, "hill": 0.15, "flat": 0.20}


def _shares():
    v = os.environ.get("MICRODUCK_STAIRS_MIX")
    if not v:
        return SHARES
    given = {k: float(x) for k, x in (kv.split(":") for kv in v.split(","))}
    unknown = set(given) - set(SHARES)
    if unknown:
        raise ValueError(f"MICRODUCK_STAIRS_MIX names unknown tile types {sorted(unknown)}; known {sorted(SHARES)}")
    return {k: given.get(k, 0.0) for k in SHARES}


def _stairs_tile(num_steps: int, proportion: float):
    """A flight of ``num_steps + 1`` risers. platform_width lands the generator's step count at num_steps + 0.5 -> int() = num_steps."""
    inner = TILE - 2 * STAIR_BORDER
    platform_param = inner - 2 * TREAD * (num_steps + 0.5)
    return terrain_gen.BoxPyramidStairsTerrainCfg(
        proportion=proportion,
        step_height_range=_step_range(),
        step_width=TREAD,
        platform_width=platform_param,
        border_width=STAIR_BORDER,
    )


def _stairs_terrain_cfg():
    sh = _shares()
    t = deepcopy(SINGLE_STEP_TERRAIN_CFG)
    single = deepcopy(SINGLE_STEP_TERRAIN_CFG.sub_terrains["single_step"])
    hill = deepcopy(SLOPE_TERRAIN_CFG.sub_terrains["hill"])
    single.proportion = sh["single_step"]
    hill.proportion = sh["hill"]
    t.sub_terrains = {
        "stairs2": _stairs_tile(1, sh["stairs2"]),
        "stairs3": _stairs_tile(2, sh["stairs3"]),
        "single_step": single,
        "hill": hill,
        "flat": terrain_gen.BoxFlatTerrainCfg(proportion=sh["flat"]),
    }
    return t


def make_witcheer_velocity_stairs_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.scene.terrain.terrain_type = "generator"
    cfg.scene.terrain.terrain_generator = _stairs_terrain_cfg()
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
    env_cfg=make_witcheer_velocity_stairs_env_cfg(),
    play_env_cfg=make_witcheer_velocity_stairs_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
