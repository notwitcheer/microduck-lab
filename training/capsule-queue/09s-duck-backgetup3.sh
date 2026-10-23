#!/bin/bash
# 09s-duck-backgetup3.sh: duck skill tree, our own env fork v3: get up from the BACK, third attempt (operator "1", 2026-10-03).
# v1 (09h, 25000 -> 28000) and v2 (09i, 28000 -> 31000) both 0 of 3 face-up takes: same half-rolled freeze at ~60 mm.
# task Mjlab-StandUpBack3-Flat-MicroDuck = witcheer fork v3 (src/mjlab_microduck/tasks/witcheer_standup_backgetup3_env_cfg.py,
# registered by one import line appended to tasks/__init__.py after v2's; backup ~/tasks-init.py.bak-backgetup3-2026-10-03).
# v3 vs v2: (1) action_rate_l2 end -1.0 -> -0.6 (maker's documented second lever, single step-0 stage);
# (2) spawn mix face_up 0.80 / face_down 0.10 / sitting 0.05 / standing 0.05 (v2: 0.50 / 0.20 / 0.15 / 0.15). rest = v2.
# WARM START: logs/rsl_rl/duckbackgetup3/2026-10-03_00-00-00_seed-backgetup2-it31000/model_31000.pt = v2 model_31000 byte copy,
# so the body resumes at 31000 and TARGET_IT = 31000 + 3000 (3k budget rule).
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=backgetup3
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckbackgetup3-status.json
TASK=Mjlab-StandUpBack3-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-34000}
. /home/witcheer/Pollen/duck-train-body.sh
