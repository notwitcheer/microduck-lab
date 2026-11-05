#!/bin/bash
# 09z22-duck-hop2.sh: duck skill tree, a NEW picture: the HOP v2 (the WHOLE duck leaves the floor: no robot body touches it, trunk above standing height, then lands upright, repeat). task Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck (module witcheer_velocity_hop2_env_cfg.py, installed 2026-10-29 by
# install-hop2-fork-2026-10-29.sh, backup ~/tasks-init.py.bak-hop2-2026-10-29; train + play cfg reprs of 11 neighbour tasks md5-identical before/after, "other reprs identical: yes").
# EV: rule 6 duck milestone (gpu-ev-gate 2026-10-25 section 2 rule 6, section 6 mojo): "a 25 cm robot duck learned to jump: all of it leaves the floor, up to 5 cm up" (strict log: no robot body on the floor for ~0.1 s, trunk 40-52 mm over the standing height, 13-22 flights per 6 s take; HONEST about the small apex: a bounce, not a leap; sim only, not yet on a real robot).
# MOJO: a 25 cm Microduck takes off with its whole body (no part on the floor, trunk 4-5 cm above standing height) and lands upright, again and again | never-seen (the v1 hop was a knee-kneel hack, never posted) | a 25 cm robot duck learned to jump: all of it leaves the floor
#     projected reach bracket 1.5-4k (duck lane median 1,986 views, n16; the v1 hop was a sole-contact hack and was never posted; UNVERIFIED). no GAIN verdict = no before/after clip and no post.
# serves: content (rule 6 milestone clip, road-to-the-cup fallback) + a sim finding on the v1 reward hack (head on the floor, soles kicked up: 96% of steps) and on what a contact-strict reward lets a 25 cm duck do.
# what is trained: the v1 hop env made strict. backlash walk env on the GROUNDCONTACT backlash robot, zero twist command, no shoves, 8 s episodes, 61-dim obs / 14 actions (the published walk policies' dims, true resume), pose 0.1, action_rate -0.02, plus five terms (module defaults, no env var in this item):
#     hop2_flight +12 (no robot body on the floor AND trunk >= stand + 10 mm AND upright), hop2_clearance +6 (TRUNK height above stand, paid while a sole is off the floor and no other body touches), hop2_vz +6, hop2_impact -0.1/N above 20 N, hop2_nonsole -5 per non-sole body on the floor per step. no termination variant.
# WARM START: logs/rsl_rl/duckhop2/2026-10-29_00-00-00_seed-velbl-it7000-std06/model_7000.pt = the hop v1 seed copy (duckvelbl 2026-09-25_14-59-27 model_7000, walk-flat v2, md5 d16ed76e, with distribution.std_param 0.19 -> 0.6, md5 9aecaf71), true resume 7000 -> 10000 (3k rule),
# EXTRA_TRAIN_ARGS entropy-coef 0.02 (the exploration lever of the 2026-10-27 design: PPO undoes a bare std bump at 0.01 within ~100 it). checkpoints SAVED EVERY 250 IT (SAVE_EVERY=250) for the pick rule of the proof item.
# EVIDENCE (vault log.md 2026-10-29, all CPU takes of the strict logger unless marked): (1) the v1 3,000-it policy has 0/15 strict flights (trunk 88.8 mm median, head/jaw shell on the floor 96.1% of steps) although the old rule scored it 15/15; its own earlier checkpoints had real flights (+300 it: 5/6 successes, 43 flights, 140 ms, apex 160 mm) that vanished by +1,000 it;
# (2) three 300-it warm-start sweeps of THIS env (A penalty only / B + termination / C std 0.4), 4096 envs, 1.31-1.34 s/it, 6,538 MiB: +300 it 2/8, 1/8, 0/8 strict successes: NO-GO by the frozen 300-it gate; (3) an informational continuation of A (resumed from its own +300 checkpoint): +400 it 4/8, +500 it 7/8 strict successes (127 strict flights, longest 120 ms, trunk apex 160.5 mm median, 167.8 max, non-sole contact share 0%, 1 fall).
#     UNVERIFIED: that a fresh 3,000-it run repeats the sweep run (one seed per cell: --agent.seed is the default 42), that a late exploit does not replace the bounce (the pick rule guards it), any real-robot transfer (every take pins the sim torque ceiling 0.641 N m against the 0.60 N m XL330 stall at 6 V).
# PACE: 1.31-1.34 s/it at 4096 envs (sweeps A-C, 300 it incl. start; A2 continuation 1.50 s/it incl. start), card peak 6,538 MiB. 3000 it = ~66 min + ~2 min start/export, one block. the block's own pace is UNVERIFIED until it runs.
# verdict: item 09z23-duck-proof-hop2 (right behind this one): 4 CPU takes of every saved checkpoint -> PRE-REGISTERED pick (most strict successes, ties by median trunk apex, then earliest) -> 15 NEW takes of the pick vs 15 takes of the seed in the hop2 play env, strict scorer hop2-score-2026-10-29.py,
# SUCCESS per take = >= 3 strict flights AND no fall AND upright at the end AND tall trunk at the end; one-sided exact Fisher p < 0.05 = GAIN (0/15 seed needs >= 4/15). written into vault log.md 2026-10-29 before any hop2 training.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; resumable; exports the final checkpoint; Donald drained and restored by the body).
SKILL=hop2
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckhop2-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
SAVE_EVERY=250
EXTRA_TRAIN_ARGS="--agent.algorithm.entropy-coef 0.02"
. /home/witcheer/Pollen/duck-train-body.sh
