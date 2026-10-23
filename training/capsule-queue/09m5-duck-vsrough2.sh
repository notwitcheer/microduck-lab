#!/bin/bash
# 09m5-duck-vsrough2.sh (was 09r, moved to the front of the duck items 2026-09-30, operator "agreed"): duck skill tree, queued 2026-09-29 (operator, GPU thread: "yes let's fix").
# RERUN of 09m vsrough on the ground-height fix: mdp.py `_ground_z` (60-robotics/microduck/patches/ground_height_patch.py)
# measures the trunk against the foot rays' terrain hits on rough terrain instead of the env origin's z. the 09m run
# (2026-09-29_14-10-21_duckvsrough) trained with origin-relative heights, so an upright duck a few steps down a pyramid
# stairs/slope counted as fallen (fallen tax, recovery-gated rewards, fallen_too_long reset at 8 s). fix proven in play:
# 8 false resets on the offset matrix before, 0 after (every reset now lands 8 s after a real tilt fall).
# also logs the curriculum's demote arms (terrain_demote_arms_patch.py): Curriculum/terrain_levels/demote_short_rate
# (episode ended before half its length) and demote_track_rate (ran >= half, tracked poorly).
# 2026-09-29 18:30 CEST (operator: "following your lead"): also carries terrain_prone_neutral_patch.py, prone/crouch-start
# episodes (56-67% of resets) no longer move the terrain level. 200-it probe from the same seed vs ground-z alone:
# terrain mean 1.99 vs 0.65, demote 0.17 vs 0.62 at +200, but reward -67 vs -38 and episode length 490 vs 611 (harder
# terrain during the warm-start dip). success read at the end: reward back in the 40s AND terrain mean > 1.
# task Mjlab-VelStand-Rough-MicroDuck, WARM START logs/rsl_rl/duckvsrough2/2026-09-28_00-00-00_seed-velstand-it20000/
# model_20000.pt = duckvelstand model_20000 (same seed as 09m), TARGET_IT 23000 (3k budget rule). 09m measured 3.48 s/it
# -> ~174 min + export = one duck block.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=vsrough2
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvsrough2-status.json
TASK=Mjlab-VelStand-Rough-MicroDuck
TARGET_IT=${TARGET_IT:-23000}
. /home/witcheer/Pollen/duck-train-body.sh
