#!/bin/bash
# 09p-duck-ssbl.sh: duck skill tree, queued 2026-09-28 (operator, GPU thread: "let's add as much duck as possible").
# task Mjlab-SitStand-Flat-Backlash-MicroDuck = backlash twin of level 3 (sit/stand; dataset-only, Pollen publish refuses posture-flag policies).
# WARM START: logs/rsl_rl/duckssbl/2026-09-28_00-00-00_seed-sitstand-it15000/model_15000.pt = ducksitstand model_15000,
# so the body resumes at 15000 and TARGET_IT = 15000 + 3000 (3k budget rule, operator 2026-09-23).
# probe 2026-09-28 07:29-07:40 CEST (~/Pollen/duck-probes-0928.sh, FREE card, 4096 envs): checkpoint loads with no size
# mismatch, 15000 -> 15041, train rc 0, export rc 0. measured 1.42 s/it at 4096 envs -> ~71 min for 3000 it + export.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=ssbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckssbl-status.json
TASK=Mjlab-SitStand-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-18000}
. /home/witcheer/Pollen/duck-train-body.sh
