#!/bin/bash
# 09d-duck-velstand.sh: duck skill tree level 5, walk + fall recovery + body pose in one policy.
# Pollen task Mjlab-VelStand-Flat-MicroDuck (tasks/__init__.py), maker budget 20_000 (microduck_velstand_env_cfg.py max_iterations); ours the same.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=velstand
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelstand-status.json
TASK=Mjlab-VelStand-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-20000}
. /home/witcheer/Pollen/duck-train-body.sh
