#!/bin/bash
# 09h-duck-backgetup.sh: duck skill tree, our own env fork: get up from the BACK (StandUp froze half-rolled from its back, 0 of 2 takes).
# task Mjlab-StandUpBack-Flat-MicroDuck = witcheer fork of Pollen StandUp (src/mjlab_microduck/tasks/witcheer_standup_backgetup_env_cfg.py,
# registered by one import line appended to tasks/__init__.py; backup ~/tasks-init.py.bak-backgetup-2026-09-24). Two changes vs StandUp:
# spawn mix flat at face_up 0.50 / face_down 0.20 / sitting 0.15 / standing 0.15, and one potential-based reward that pays the turn off the back.
# 3k budget rule (operator 2026-09-23): new duck items cap at 3,000 iterations, extend only while mean reward still climbs.
# WARM START: logs/rsl_rl/duckbackgetup/2026-09-24_00-00-00_seed-standup-it25000/model_25000.pt is a copy of duckstandup model_25000
# (the policy that already stands from sitting and face-down), so the body resumes at 25000 and TARGET_IT = 25000 + 3000.
# from scratch, 3k iterations would barely reach face-up spawns. mjlab restores common_step_counter (600072) from the checkpoint,
# so StandUp's curricula (and its late attempt-taxes) stay on their final stages, the regime the policy already trained in.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=backgetup
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckbackgetup-status.json
TASK=Mjlab-StandUpBack-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-28000}
. /home/witcheer/Pollen/duck-train-body.sh
