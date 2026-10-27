#!/bin/bash
# 09z14-duck-dribble.sh: duck skill tree, level 7d, the duck WALKS the giant ball (dribbling): the 300 mm ball ahead of its feet, the duck walks forward and the ball stays within reach all the way into a goal.
# task Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck (module witcheer_velocity_dribble_env_cfg.py, installed 2026-10-27 by install-dribble-fork-2026-10-27.sh, backup ~/tasks-init.py.bak-dribble-2026-10-27;
# train + play cfg reprs of BallKick flat/backlash/Big/Big-Aim, Velocity flat/backlash/Stairs/MixSlope, Roulade md5-identical before/after, 18 of 18, again after the defaults were set). no clone patches involved.
# EV: rule 6 duck milestone: "Microduck walks a ball bigger than itself into the goal" (the franchise after the 09z10 power kick 1,680 views and the 09z12 aim kick 15/15), before/after clip; if the takes do not show the ball carried into the goal, no post.
# serves: content (duck clip, gate rule 6) + the pre-registered verdict.
# WHAT CHANGES against the stock walk-flat backlash task: (1) the 300 mm / 0.275 kg ball of the 09z10 kick spawned 0.27 m ahead of the root on the centre line; (2) the ball geom has ROLLING RESISTANCE (condim 6, 0.008 m = Crr 0.053, a ball
# on a soft floor, UNVERIFIED against a real ball): the kick tasks' ball rolls forever (MuJoCo ignores the rolling term at condim 3: 0.300 m/s held for 5 s in a CPU check), which is why a blind walker loses a pushed ball after 3-9 s (24 of 24 seed takes);
# (3) forward walk command only (vx 0.15-0.30, no standing/turn envs, standing_envs curriculum dropped); (4) reward ball_carry = exp(-d^2/0.2^2) (ball vs (0.27, 0) in the base frame) x clamp(ball speed along the reset heading, 0, 0.30), weight 20,
# plus the kick module's ball_lateral at -10. walk rewards, DR, curricula, 20 s episodes untouched; the critic does not see the ball; the actor is blind to ball and goal (obs 61 / 14 unchanged, so every walk checkpoint warm-starts).
# EVIDENCE (vault log 2026-10-27, files in the public clone): seed takes (3 walk checkpoints, 24 takes at 0.2/0.3 m/s, zero rolling resistance): ball out of reach after 2-13 s in 24 of 24, carried-into-goal 0 of 24; 200-iteration sweep WITHOUT rolling resistance (3 weight settings):
# no trend; WITH rolling resistance 0.008, 300 warm-start iterations: carried into the goal 4 of 6 vs the seed's 1 of 6 (near fraction 1.00 vs 0.68, longest near streak 23.2 s vs 10.6 s, held 6/6): the behaviour appears. n=6, design evidence, NOT the verdict.
# WARM START: logs/rsl_rl/duckdribble/2026-10-27_00-00-00_seed-velstairs-it19000/model_19000.pt = duckvelstairs 2026-10-24_00-10-26 model_19000 (walk-stairs, md5 8a3de9ca, both copies), true resume, 19000 -> 22000 (3k rule).
# PACE (4096 envs, free card, Donald drained): sweep runs 1.161 / 1.164 s/it (mean of 301 it), peak 7,544 MiB; final-cfg exact-argv probes 2026-10-27 12:05-12:07 CET (no MICRODUCK_ env var): new task 64 envs rc 0 in 10 s, export rc 0 793,772 B; warm start 512 envs rc 0 0.62 s/it, no size mismatch; warm start 4096 envs rc 0 in 61 s, 1.223 s/it (mean of 46, incl. warm-up), peak 8,231 MiB, export rc 0 793,776 B. ESTIMATE 3000 it x 1.16-1.22 = 58-61 min + export, one block (the block's own pace is UNVERIFIED until it runs).
# verdict: item 09z15-duck-proof-dribble (right behind this one), batches proof-dr-{a,b,c}, scorer dr-score-2026-10-27.py + dr-verdict-2026-10-27.py, new = duckdribble model_22000 vs ref = its seed (duckvelstairs model_19000) re-taken in the same task, 15 takes per policy.
# PRE-REGISTERED (vault log 2026-10-27, before any take of the 3,000-iteration policy): A (GAIN) dribble condition, goal mouth at x = 1.8 m, forced vx 0.25, no shoves, 24 s, success = CARRIED = held AND the ball enters the goal AND is NEAR (0 < gap < 0.60 m ahead of the trunk,
# |lateral| < 0.30 m) at every 0.2 s sample from t = 1 s until it enters; one-sided exact Fisher p < 0.05 = GAIN. C no-loss: stock walk task, shoves, 10 per policy, held, two-sided, a loss = p < 0.05 with new lower. B (dribble with shoves, 10 per policy) reported only.
# VERDICT = GAIN iff A p < 0.05 and no loss on C. then clip-dribble-2026-10-27.sh cuts the X clips.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item). e2e clone run 2026-10-27 (e2e-dribble-2026-10-27.sh, 512 envs, forced deadline): leg 1 rc 124 / exit 3 after 1120 iterations (19000 -> 20120), Donald restored; leg 2 resumed model_20120, export ok, exit 0, lane state unchanged.
# weekday lane: ld (Tue 06:10 CET block) > ly, a bench item is queued, so Tue 14:10 CET yields to 70-hermes-settings (this item exits 3 within seconds, records ly) and the first duck block is Wed 01:10 CET.
SKILL=dribble
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckdribble-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck
TARGET_IT=${TARGET_IT:-22000}
. /home/witcheer/Pollen/duck-train-body.sh
