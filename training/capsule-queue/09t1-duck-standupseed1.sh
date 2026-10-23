#!/bin/bash
# 09t1-duck-standupseed1.sh: get-up-from-the-back, seed sweep (2026-10-04, mercury, operator "following your leads").
# why: v1/v2/v3 forks (warm-started 25k->34k from the seed-42 level 2 run) all froze half-rolled on their back, 0 of N.
# the maker's own cfg (microduck_standup_env_cfg.py, set_ground_state comment, pinned 53b8971, unchanged upstream since 08-25)
# says back-recovery was seed-lucky (1 success / 3 failures with equivalent rewards) because the supine->prone reward landscape
# is flat until the roll completes, and that discovery happens while ground_state_mix ramps (iters 0-2500); a warm start resumes
# on the last curriculum stage, so our forks never had a discovery phase. every earlier run used rsl_rl's default seed 42.
# this item: maker env unchanged (Mjlab-StandUp-Flat-MicroDuck), FROM SCRATCH, seed 1, 3000 it (past the 2500 ramp end).
# verdict per seed = forced face_up takes at model_3000; the lucky seed (if any) gets extended.
SKILL=standupseed1
MANIFEST=/home/witcheer/duckstandupseed1-status.json
TASK=Mjlab-StandUp-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-3000}
EXTRA_TRAIN_ARGS="--agent.seed 1 --env.seed 1"
. /home/witcheer/Pollen/duck-train-body.sh
