#!/bin/bash
# 09l-duck-kickbl.sh: duck skill tree, queued 2026-09-28 (operator, GPU thread: "let's add as much duck as possible").
# task Mjlab-BallKick-Flat-Backlash-MicroDuck = backlash twin of level 7 (kick-right, HF witcheer/microduck-kick-right v1): candidate kick-right v2.
# WARM START: logs/rsl_rl/duckkickbl/2026-09-28_00-00-00_seed-ballkick-it10000/model_10000.pt = duckballkick model_10000,
# so the body resumes at 10000 and TARGET_IT = 10000 + 3000 (3k budget rule, operator 2026-09-23).
# probe 2026-09-28 07:29-07:40 CEST (~/Pollen/duck-probes-0928.sh, FREE card, 4096 envs): checkpoint loads with no size
# mismatch, 10000 -> 10041, train rc 0, export rc 0. measured 1.21 s/it at 4096 envs -> ~60 min for 3000 it + export.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=kickbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckkickbl-status.json
TASK=Mjlab-BallKick-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-13000}
. /home/witcheer/Pollen/duck-train-body.sh
