#!/bin/bash
# 09z12-duck-bigaim.sh: duck skill tree, level 7c, the giant-ball kick learns to AIM (operator-facing commitment: the 2026-10-26 16:30 CET X post says "aiming is the next thing I train").
# task Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck (module witcheer_ballkick_bigaim_env_cfg.py, installed 2026-10-26 by install-bigaim-fork-2026-10-26.sh, backup ~/tasks-init.py.bak-bigaim-2026-10-26;
# train + play cfg reprs of BallKick flat/backlash/Big, Velocity backlash, Stairs, Roulade md5-identical before/after, 12 of 12). ONE change against the 09z10 Big task: the aim reward term
# ball_lateral (ball speed PERPENDICULAR to the kick direction = the heading at reset, absolute value, weight -AIM_W) switched ON; it already existed in the Big module, off. forward-velocity term (12, capped 1.0 m/s),
# overshoot penalty, curricula, DR, ball, 5 s episodes are the Big task's. no clone patches involved. the goal exists only in the PLAY cfg behind MICRODUCK_BIGKICK_GOAL=1, never in training.
# WHY: 09z10/09z11 (model_16000) won on power (9/15 vs 0/15 at >= 1.25 m by 2 s) but put the ball in the goal 1/15 (seed 15/15): the ball leaves at -26..-34 deg in 14 of 15 takes, median -30.5 (seed +0.7). a systematic
# deflection, which the policy (blind to ball and goal) can only fix by kicking along its own heading, which is what ball_lateral pays for.
# AIM WEIGHT 20 (module default, no env var in the item): pre-queue sweep bigaim-sweep-2026-10-26.sh, 200 warm-start iterations per weight, 6 goal takes per checkpoint: the reference (bigkick 16000, re-taken)
# goal 0/6 median aim -29.7 deg; W=3 no change (goal 0/6, -26.7 at +200); W=8 slow (goal 2/6, -23.8 at +200); W=20 goal 6/6, median aim -3.4 deg, ball >= 1.25 m by 2 s 6/6 at +200
# (+80: -7.9 deg, +120: -5.0, +160: -2.7), forward term 10.99 -> 9.7 of 12 (a slower first second: 0.76 m vs 0.97 m at 1 s). full numbers: vault log 2026-10-26 + 09z12-staging-results-2026-10-26.txt.
# WARM START: logs/rsl_rl/duckbigaim/2026-10-26_00-00-00_seed-bigkick-it16000/model_16000.pt = duckbigkick 2026-10-25_08-12-58 model_16000 (md5 71eab7c2, both copies), true resume, 16000 -> 19000 (3k rule). dims 61/14.
# probes 2026-10-26 08:38-08:41 CET on a FREE card (final cfg, exact argv, no env var): new task 64 envs rc 0 in 10 s, export rc 0 793,750 B; warm start 512 envs 0.71 s/it rc 0; warm start 4096 envs 1.26 s/it (mean of 46), peak 8,163 MiB,
# train rc 0, export rc 0 793,754 B, checkpoint loads with no size mismatch. the 200-iteration sweep runs measured 1.20-1.22 s/it. ESTIMATE 3000 it x 1.2-1.26 = 60-63 min + export, one block (the block's own pace is UNVERIFIED until it runs).
# verdict: item 09z13-duck-proof-bigaim (right behind this one), batches proof-ba-{a,b,c}, scorer ba-score-2026-10-26.py, new = duckbigaim
# model_19000 vs ref = duckbigkick model_16000, 15 takes per policy. pre-registered (written before any take of the 3,000-iteration policy; the 200-iteration sweep takes only chose the weight): A success = held AND ball enters the goal, one-sided exact Fisher p < 0.05 = GAIN; no-loss (two-sided,
# loss = p < 0.05 with new lower) on power (held AND >= 1.25 m by 2 s, same takes) and on the stock small ball (held AND >= 1.0 m by 3 s, 10 takes). b (play shoves) reported only. then clip-bigaim-2026-10-26.sh cuts the X clips.
# EV: rule 6 duck milestone: "Microduck scores with a ball bigger than itself" before/after clip (the 09z10 clip shows power only, 1 goal in 15); if the takes do not show goals, no post.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item, e2e-proven on 09z8's clone; not re-e2e'd for this task id, the exact-argv probes cover train + resume + export).
SKILL=bigaim
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckbigaim-status.json
TASK=Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck
TARGET_IT=${TARGET_IT:-19000}
. /home/witcheer/Pollen/duck-train-body.sh
