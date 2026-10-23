#!/bin/bash
# 09b-duck-sitstand.sh: duck skill tree level 3, SitStand. commanded sit <-> stand in one policy, gently, head commandable.
# Pollen task Mjlab-SitStand-Flat-MicroDuck, maker default budget 15_000 iterations (tasks/microduck_sitstand_env_cfg.py).
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=sitstand
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/ducksitstand-status.json
TASK=Mjlab-SitStand-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-15000}
. /home/witcheer/Pollen/duck-train-body.sh
