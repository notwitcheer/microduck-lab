#!/bin/bash
# 09e-duck-roulade.sh: duck skill tree level 6, forward roll over the head top, land on the feet (the trick level).
# Pollen task Mjlab-Roulade-Flat-MicroDuck (tasks/__init__.py), maker budget 10_000 (microduck_roulade_env_cfg.py max_iterations); ours the same.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=roulade
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckroulade-status.json
TASK=Mjlab-Roulade-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
