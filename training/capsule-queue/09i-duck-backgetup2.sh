#!/bin/bash
# 09i-duck-backgetup2.sh: duck skill tree, our own env fork v2: get up from the BACK, second attempt.
# v1 (09h, Mjlab-StandUpBack-Flat-MicroDuck, 25000 -> 28000 on 2026-09-24) changed nothing: 0 of 3 face-up takes got up,
# same half-rolled freeze as the seed, reward flat from it25500, turnover term negative the whole run.
# task Mjlab-StandUpBack2-Flat-MicroDuck = witcheer fork v2 (src/mjlab_microduck/tasks/witcheer_standup_backgetup2_env_cfg.py,
# registered by one import line appended to tasks/__init__.py after v1's; backup ~/tasks-init.py.bak-backgetup2-2026-09-24).
# v2 vs v1: (1) the maker's late attempt-taxes OFF (arrival_damping, head_pose_bias, joint_torque_rate_l2 at weight 0, single
# step-0 stage, i.e. the maker's own discovery regime); (2) body_ang_vel halved -0.05 -> -0.025 (maker's documented first lever);
# (3) supine_turnover_progress measured from the episode's running minimum, so the spawn flop onto the back is no longer charged;
# (4) exploration std x2 in the seed checkpoint (0.166 -> 0.332 mean) plus entropy_coef 0.01 -> 0.02 so the bump does not
# decay back to 0.18 within 100 it.
# WARM START: logs/rsl_rl/duckbackgetup2/2026-09-24_00-00-00_seed-backgetup-it28000-std2x/model_28000.pt = v1 model_28000
# with std_param x2 (prep-backgetup2-seed.py), so the body resumes at 28000 and TARGET_IT = 28000 + 3000 (3k budget rule).
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=backgetup2
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckbackgetup2-status.json
TASK=Mjlab-StandUpBack2-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-31000}
. /home/witcheer/Pollen/duck-train-body.sh
