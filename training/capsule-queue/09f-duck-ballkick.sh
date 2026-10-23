#!/bin/bash
# 09f-duck-ballkick.sh: duck skill tree level 7, kick a 70 mm ball forward with the right foot from standing (first object interaction).
# Pollen task Mjlab-BallKick-Flat-MicroDuck (tasks/__init__.py), maker budget 10_000 (microduck_ball_kick_env_cfg.py max_iterations); ours the same.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=ballkick
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckballkick-status.json
TASK=Mjlab-BallKick-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
