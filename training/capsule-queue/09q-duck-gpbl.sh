#!/bin/bash
# 09q-duck-gpbl.sh: duck skill tree, queued 2026-09-28 (operator, GPU thread: "let's add as much duck as possible").
# task Mjlab-GroundPick-Flat-Backlash-MicroDuck = backlash twin of level 8 (groundpick; dataset-only, phase-driven).
# WARM START: logs/rsl_rl/duckgpbl/2026-09-28_00-00-00_seed-groundpick-it20000/model_20000.pt = duckgroundpick model_20000,
# so the body resumes at 20000 and TARGET_IT = 20000 + 3000 (3k budget rule, operator 2026-09-23).
# probe 2026-09-28 07:29-07:40 CEST (~/Pollen/duck-probes-0928.sh, FREE card, 4096 envs): checkpoint loads with no size
# mismatch, 20000 -> 20041, train rc 0, export rc 0. measured 1.2 s/it at 4096 envs -> ~60 min for 3000 it + export.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=gpbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckgpbl-status.json
TASK=Mjlab-GroundPick-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-23000}
. /home/witcheer/Pollen/duck-train-body.sh
