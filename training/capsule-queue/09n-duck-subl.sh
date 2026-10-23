#!/bin/bash
# 09n-duck-subl.sh: duck skill tree, queued 2026-09-28 (operator, GPU thread: "let's add as much duck as possible").
# task Mjlab-StandUp-Flat-Backlash-MicroDuck = backlash twin of level 2 (standup, HF witcheer/microduck-standup v1): candidate standup v2.
# WARM START: logs/rsl_rl/ducksubl/2026-09-28_00-00-00_seed-standup-it25000/model_25000.pt = duckstandup model_25000,
# so the body resumes at 25000 and TARGET_IT = 25000 + 3000 (3k budget rule, operator 2026-09-23).
# probe 2026-09-28 07:29-07:40 CEST (~/Pollen/duck-probes-0928.sh, FREE card, 4096 envs): checkpoint loads with no size
# mismatch, 25000 -> 25041, train rc 0, export rc 0. measured 1.27 s/it at 4096 envs -> ~64 min for 3000 it + export.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=subl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/ducksubl-status.json
TASK=Mjlab-StandUp-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-28000}
. /home/witcheer/Pollen/duck-train-body.sh
