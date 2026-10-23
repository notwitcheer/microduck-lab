#!/bin/bash
# 09c-duck-velocity-rough.sh: duck skill tree level 4, walk on rough ground. first "specific conditions" level.
# Pollen task Mjlab-Velocity-Rough-MicroDuck (tasks/__init__.py), maker budget 50_000 (velocity cfg); ours 8000 = 2x the flat cut that gave 0.15 m/s.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=velrough
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelrough-status.json
TASK=Mjlab-Velocity-Rough-MicroDuck
TARGET_IT=${TARGET_IT:-8000}
. /home/witcheer/Pollen/duck-train-body.sh
