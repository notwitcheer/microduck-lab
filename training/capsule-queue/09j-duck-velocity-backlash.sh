#!/bin/bash
# 09j-duck-velocity-backlash.sh: duck skill tree, sim2real track, first -Backlash- twin (skill-tree.md GPU order step 2).
# task Mjlab-Velocity-Flat-Backlash-MicroDuck = the maker's own backlash twin of level 1 (walk): +-1 deg serial gear play per servo,
# firmware PD closing on the encoder reading THROUGH the play, obs/action dims unchanged (tasks/backlash.py, tasks/__init__.py).
# WARM START: logs/rsl_rl/duckvelbl/2026-09-25_00-00-00_seed-velocity-it4000/model_4000.pt = level 1 duckvel model_4000
# (velocity-2026-09-15-it4000.onnx, HF witcheer/microduck-walk-flat v1), so the body resumes at 4000 and
# TARGET_IT = 4000 + 3000 (3k budget rule, operator 2026-09-23). operator yes 2026-09-25 (GPU thread) to queue the next level.
# probe 2026-09-25 07:19 CEST (~/Pollen/velbl-probe.sh): checkpoint loads with no size mismatch, 4000 -> 4040 at 4096 envs,
# 1.17 s/it, VRAM peak 7,143 MiB, export rc 0 (793,771 bytes), fell_over 0.54 in the first 40 it under backlash.
# 3000 it at 1.17 s/it = ~59 min + export.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=velbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelbl-status.json
TASK=Mjlab-Velocity-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-7000}
. /home/witcheer/Pollen/duck-train-body.sh
