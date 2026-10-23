#!/bin/bash
# RESTARTED 2026-09-28 ~17:40 CEST: the 14:10 block trained 20000 -> 21900 under the stock terrain rule, which parked every env on level 0 (flat in practice). that run is archived at logs/rsl_rl/duckvsrough-archive-stockcurriculum/ (manifest ~/duckvsrough-status.json.stockcurriculum-2026-09-28); this item now retrains 20000 -> 23000 from the seed under the Microduck-scaled rule (mdp.terrain_levels_tracking, wired for every rough velocity/velstand task). watch Curriculum/terrain_levels/mean in the second half: rising above ~1 = the fix works.
# 09m-duck-vsrough.sh: duck skill tree, queued 2026-09-28 (operator, GPU thread: "let's add as much duck as possible").
# task Mjlab-VelStand-Rough-MicroDuck = level 5 (walk + recover, HF witcheer/microduck-walk-recover v1) moved to uneven ground: the rough set's first warm-started level.
# WARM START: logs/rsl_rl/duckvsrough/2026-09-28_00-00-00_seed-velstand-it20000/model_20000.pt = duckvelstand model_20000,
# so the body resumes at 20000 and TARGET_IT = 20000 + 3000 (3k budget rule, operator 2026-09-23).
# probe 2026-09-28 07:29-07:40 CEST (~/Pollen/duck-probes-0928.sh, FREE card, 4096 envs): checkpoint loads with no size
# mismatch, 20000 -> 20041, train rc 0, export rc 0. measured 3.31 s/it at 4096 envs -> ~166 min for 3000 it + export.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=vsrough
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvsrough-status.json
TASK=Mjlab-VelStand-Rough-MicroDuck
TARGET_IT=${TARGET_IT:-23000}
. /home/witcheer/Pollen/duck-train-body.sh
