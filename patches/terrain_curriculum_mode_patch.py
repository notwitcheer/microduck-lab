"""terrain_curriculum_mode_patch.py (2026-09-30): real difficulty ladder for the Microduck velocity family (rough).

finding 2026-09-30 (lab log): MICRODUCK_ROUGH_TERRAINS_CFG never sets curriculum=True, and mjlab's
TerrainGeneratorCfg defaults to False (random mode: every patch gets a random type AND a uniform random difficulty, so
rows are not ordered and terrain_levels moves envs between random patches). on top of that, every rough make_*_cfg
assigns the SHARED module-level generator and its play branch mutates it in place (curriculum False, rows 5, cols 5) at
task registration, so every training run used a 5x5 random grid (params/env.yaml of all three rough runs).

this patch touches ONLY the velocity family (make_microduck_velocity_env_cfg, so Velocity-Rough, VelStand-Rough and
their -Backlash- twins):
- the rough branch deep-copies the generator (no aliasing with other tasks' play cfgs), resets rows/cols to the source
  values (10 x 20; other tasks' play branches may already have mutated the shared object when this runs) and sets
  curriculum=True for training (one column per sub-terrain type, difficulty rising along the 10 rows, as mjlab's own
  G1/Go1 rough tasks do). play keeps its 5x5 random grid on its own copy.
- SitStand/StandUp/GroundPick rough are untouched (still the shared object, still 5x5 random at train time): changing
  their grid would change queued items (09o ssrough) without a probe.

idempotent; backup *.bak-curmode-2026-09-30.
"""
import os
import pathlib
import shutil

T = pathlib.Path(os.environ.get("MICRODUCK_RL", ".")) / "src/mjlab_microduck/tasks"
cfg = T / "microduck_velocity_env_cfg.py"
c = cfg.read_text()
if "curmode-2026-09-30" in c:
    print("already patched")
    raise SystemExit(0)
b = cfg.with_name(cfg.name + ".bak-curmode-2026-09-30")
if not b.exists():
    shutil.copy2(cfg, b)


def sub(text, old, new, count=1):
    assert text.count(old) == count, (old[:60], text.count(old))
    return text.replace(old, new)


c = sub(
    c,
    '        cfg.scene.terrain.terrain_type = "generator"\n'
    "        cfg.scene.terrain.terrain_generator = MICRODUCK_ROUGH_TERRAINS_CFG\n",
    '        cfg.scene.terrain.terrain_type = "generator"\n'
    "        # curmode-2026-09-30: own copy (the shared module object is mutated in place by every rough task's play\n"
    "        # branch at registration), source grid size restored, and curriculum mode ON for training so rows are a\n"
    "        # difficulty ladder (random mode samples difficulty per patch, which made terrain_levels meaningless).\n"
    "        cfg.scene.terrain.terrain_generator = deepcopy(MICRODUCK_ROUGH_TERRAINS_CFG)\n"
    "        cfg.scene.terrain.terrain_generator.num_rows = 10\n"
    "        cfg.scene.terrain.terrain_generator.num_cols = 20\n"
    "        cfg.scene.terrain.terrain_generator.curriculum = not play\n",
)
cfg.write_text(c)
print("patched", cfg)
