#!/bin/bash
# 09a-duck-standup.sh: duck skill tree level 2, StandUp. the duck starts on the ground (face down, on its back, or sitting) and must get to its feet.
# Pollen task Mjlab-StandUp-Flat-MicroDuck, maker default budget 15_000 iterations (tasks/microduck_standup_env_cfg.py).
# 2026-09-17: extended to 25_000 (operator yes). at model_15000 the policy stood from sitting and from face-down (hunched, trunk pitched ~33 deg)
# but froze half-rolled from its back (60-robotics/microduck/log.md 2026-09-17). resumes from model_15000 in logs/rsl_rl/duckstandup/.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=standup
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckstandup-status.json
TASK=Mjlab-StandUp-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-25000}
. /home/witcheer/Pollen/duck-train-body.sh
