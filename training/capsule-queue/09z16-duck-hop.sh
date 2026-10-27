#!/bin/bash
# 09z16-duck-hop.sh: duck skill tree, a NEW move: the HOP (both feet leave the floor, land upright, repeat). task Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck (module witcheer_velocity_hop_env_cfg.py, installed 2026-10-27 by
# install-hop-fork-2026-10-27.sh, backup ~/tasks-init.py.bak-hop-2026-10-27; train + play cfg reprs of Velocity flat/backlash/Stairs, VelStand backlash, BallKick Big-Aim, Roulade, StandUp md5-identical before/after, 14 of 14).
# EV: rule 6 duck milestone (gpu-ev-gate 2026-10-25 section 2): "a 25 cm robot duck learned to hop: both feet off the floor, 140 ms in the air" before/after clip (the seed never leaves the ground, 0 of 8 takes).
#     projected line 1 like the Hermes-drives-the-duck / walk-mixslope duck posts: reach bracket 3-5k (duck lane median 1,986; reworked clip + wording 4,329; a first-of-its-kind move can pop, sequels decay). no clip with both feet visibly off the floor = no post.
# serves: content (rule 6 milestone clip) + a sim finding about what the actuator model allows (peak servo torque 0.641 N m, the sim motor ceiling, against the 0.60 N m datasheet stall at 6 V of the XL330-M288).
# the maker's registry (33 ids at 53b8971) has no jump / hop task. what is trained: the backlash walk env on the GROUNDCONTACT backlash robot, zero command, no shoves, 8 s episodes, plus four reward terms (hop_flight, hop_clearance, hop_vz, hop_impact),
# weights 12,6,6,0.02, pose weight 0.1 and action_rate -0.02 (module defaults, no env var in this item; the walk-model collision set let the trunk sink below the floor in an open-loop search, so the groundcontact robot is used).
# WARM START: logs/rsl_rl/duckhop/2026-10-27_00-00-00_seed-velbl-it7000-std06/model_7000.pt = duckvelbl 2026-09-25_14-59-27 model_7000 (walk-flat v2, md5 d16ed76e) with distribution.std_param set 0.19 -> 0.6 (md5 9aecaf71), true resume,
# 7000 -> 10000 (3k rule); EXTRA_TRAIN_ARGS entropy-coef 0.02 (PPO undoes a bare std bump at the default 0.01 within ~100 it). dims 61/14.
# WHY THE LEVER: the pre-queue sweep (2026-10-27, log.md) found NOTHING from the plain warm start: the seed in the hop env 0 of 8 airborne takes (peak lower-sole lift -1 mm, trunk +1 mm); three reward settings (8,4,1.5,0.05 / 12,6,3,0.02 / 0,8,2,0.05)
# x 200 iterations: hop_flight term flat at the spawn-drop baseline, 0 of 24 takes with a flight at +100 / +200 it; an open-loop squat-extend search over ~98k rollouts on the honest collision model: 0 landed hops, trunk lift <= 5 mm.
# the exploration lever (std 0.6, entropy 0.02, pose 0.1, action_rate -0.02, weights 12,6,6,0.02) turned it: at +100 it 4 of 4 takes succeed (19-27 hops each, longest flight 120-160 ms, lower-sole lift up to 64 mm, trunk +18..40 mm); at +200 it 2 of 4 (falls on landing).
# probes: exact item argv (4096 envs, entropy flag, std-bumped seed, ~/Pollen/probe-hop.log) 1.30-1.33 s/it, card peak 6,520 MiB in the 200-it runs (7,207 MiB with another tenant on the card), export rc 0 (793,767 bytes). ESTIMATE 3000 it = ~66 min + ~2 min start/export, one block (the block's own pace is UNVERIFIED until it runs).
# verdict: item 09z17-duck-proof-hop (right behind this one), batches proof-hop-{a,b}, scorer hop-score-2026-10-27.py, new = duckhop model_10000 vs ref = its seed duckvelbl model_7000 in the same hop play env, 15 takes each,
# PRE-REGISTERED in vault log.md 2026-10-27 before any take of the 3,000-iteration policy: SUCCESS per take = >= 3 hops (both feet out of contact >= 80 ms, lower sole >= 12 mm up) AND no RESET AND tilt < 30 deg / trunk > 70 mm in the last 0.5 s;
# one-sided exact Fisher p < 0.05 = GAIN (0/15 reference needs >= 4/15).
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; e2e of this task id on a clone 2026-10-27, see log.md).
SKILL=hop
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckhop-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
EXTRA_TRAIN_ARGS="--agent.algorithm.entropy-coef 0.02"
. /home/witcheer/Pollen/duck-train-body.sh
