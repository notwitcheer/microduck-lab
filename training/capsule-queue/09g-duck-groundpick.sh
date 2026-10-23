#!/bin/bash
# 09g-duck-groundpick.sh: duck skill tree level 8, crouch and bring the beak tip to the ground without touching it, back to a clean stand (the precision level).
# Pollen task Mjlab-GroundPick-Flat-MicroDuck (tasks/__init__.py), maker budget 20_000 (microduck_ground_pick_env_cfg.py max_iterations); ours the same.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=groundpick
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckgroundpick-status.json
TASK=Mjlab-GroundPick-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-20000}
. /home/witcheer/Pollen/duck-train-body.sh
