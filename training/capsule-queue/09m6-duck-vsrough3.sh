#!/bin/bash
# 09m6-duck-vsrough3.sh (was 09r, moved to the front of the duck items 2026-09-30, operator "ok then lets do it"): VelStand-Rough on a REAL difficulty ladder, queued 2026-09-30 (operator "yes on all, go ahead", GPU thread).
# seed: velstand model_20000 (md5-identical copy in logs/rsl_rl/duckvsrough3/2026-09-28_00-00-00_seed-velstand-it20000/), 20000 -> 23000.
# depends on local patches (60-robotics/microduck/patches/): ground_height, terrain_tracking(2), terrain_demote_arms,
# terrain_prone_neutral, terrain_curriculum_mode (2026-09-30: deep-copied generator + curriculum=True for the velocity family).
# probe 2026-09-30 18:41 (probe-curmode.sh, 200 it, 4096 envs, 3.46 s/it): env.yaml curriculum true, rows 10; terrain mean
# 3.07 -> 4.43, max 9 by +100..150, promote 0.21-0.24 vs demote 0.02-0.03; reward median 36.3 -> -7.0 over the 200 it
# (vsrough2 same window 28.9 -> -56.9 on the random grid). success read: reward back in the 40s AND terrain mean climbing
# toward the top rows at 23000 (levels now = difficulty).
SKILL=vsrough3
MANIFEST=/home/witcheer/duckvsrough3-status.json
TASK=Mjlab-VelStand-Rough-MicroDuck
TARGET_IT=${TARGET_IT:-23000}
. /home/witcheer/Pollen/duck-train-body.sh
