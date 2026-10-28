#!/bin/bash
# 09z20-duck-moon.sh: duck skill tree, a NEW picture: the MOON (the same 25 cm duck in 1.62 m/s^2 gravity). task Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck (module witcheer_velocity_moon_env_cfg.py, installed 2026-10-28 by
# install-gm-fork-2026-10-28.sh, backup ~/tasks-init.py.bak-gm-2026-10-28; train + play cfg reprs of 10 neighbour tasks md5-identical before/after, both modes). Mars (3.71 m/s^2) is the same task at process start (MICRODUCK_MOON_G=3.71), used for the reported condition B.
# EV: rule 6 duck milestone + mojo (gpu-ev-gate 2026-10-25 section 2 rule 6, section 6): "the same Microduck on the Moon: it learned to walk in 1.62 m/s^2" with a gravity + distance meter, the untrained one losing traction (0.45 m in 10 s median, 0 of 12 takes reach 1.00 m) against the Earth pace
#     (1.18 m median). projected reach bracket 1.5-4k (scout ideas note item 7: "high only if it floats instead of falling"; duck-lane median 1,986 n16; UNVERIFIED). HONEST CAVEAT written before the run: the SEED already bounds on the Moon (walk-flat v2: a flight of both feet >= 80 ms in 11 of 12 takes,
#     median air fraction 0.149, longest flight 400 ms), so "it learned to bound" is NOT the claim and is never burnt into a caption; the claim is the distance the trained duck covers. no GAIN verdict = no post and no before/after clip.
# serves: content (road-to-the-cup series: day 6 Tue 11-03 banked fallback "moon gravity side by side" + the clip) + a sim finding about walking in low gravity.
# what is trained: the backlash walk env on the walk backlash robot, forward command only (vx 0.15-0.35), the maker's shoves kept, gravity 1.62 m/s^2 through cfg.sim.mujoco.gravity (the field that reaches the model; cfg.sim.gravity is silently ignored: the 2026-10-27 trap; the model value is printed by the
# env check: mj_model -1.620, warp -1.620). NO reward asks for a bound: the reward is the maker's velocity tracking + walk shaping. gravity is a build-time constant in mjlab (no DR hook), so one run = one gravity.
# SEED: logs/rsl_rl/duckmoon/2026-10-28_00-00-00_seed-velbl-it7000/model_7000.pt = duckvelbl 2026-09-25_14-59-27 model_7000 (walk-flat v2, md5 d16ed76e1ddef1d6fb836ba6a4c4e06f; no std bump, no extra train flag), true resume 7000 -> 10000 (3k rule), dims 61/14. WHY walk-flat v2: the published default walk, and in the seed-through-the-condition sweep (2026-10-28, ~/Pollen/gm-probe/sweep2, 12 takes per cell, 1 env, forced vx 0.25, 10 s) it is the best of the three candidates on the Moon:
#     held 10/12, median forward progress 0.45 m (walk-stairs 19000: 9/12, 0.19 m; walk-mixslope 16000: 12/12, 0.24 m); Earth (same protocol) 12/12, 1.18 m, 9 of 12 takes at or above 1.00 m; Mars 12/12, 0.66 m, 2 of 12 at or above 1.00 m.
# probes (all CPU, nothing on the card, 2026-10-28): (1) env check (train env, 8 envs): model gravity -1.620 and warp gravity -1.620 (the base task prints -9.81); (2) CPU exact-argv smoke gm-smoke-2026-10-28.sh moon: resume from the seed copy, 4 iterations at 16 envs, no size mismatch, train rc 0, model_7003.pt written, export.py rc 0 (793,769 B).
#     NOT probed: the 4096-env pace and VRAM (no card use on the staging day). ESTIMATE 3000 it x ~1.2 s/it (the 09z14 in-block pace on the sibling backlash-walk fork; the sweep runs measured 1.16) = ~60 min + ~2 min start/export, one block. UNVERIFIED until it runs.
# the body (duck-train-body.sh) is shared and was e2e-proven on a clone 2026-10-27 (hop); not re-e2e'd for this task id (needs the card and a Donald drain): the CPU smoke stands in for it.
# what is NOT verified: that 3,000 iterations beat the 1.00 m bar (no GPU warm-start sweep was allowed on the staging day); that Earth-tuned actuators, gear play and foot friction suit 0.165 g (nothing is re-tuned); any real-robot meaning (the Moon is a sim constant here).
# verdict: item 09z21-duck-proof-moon (right behind this one). PRE-REGISTERED in vault log.md 2026-10-28 BEFORE any take of the 3,000-iteration policy (the design probes are evidence, not the verdict):
#   A (GAIN) 15 takes per policy, 1 env, forced vx 0.25 m/s, NO shoves, gravity 1.62, 10 s: success = held (no RESET, trunk tilt <= 60 deg throughout) AND forward progress >= 1.00 m at the end (the seed's own Earth pace); one-sided exact Fisher p < 0.05 new vs ref (reference 0/15 needs new >= 4/15);
#   B reported only: Mars gravity 3.71, same rule, 10 takes per policy, plus flights >= 80 ms and the air fraction; C no-loss: stock walk task, play shoves, Earth, 20 s, 10 takes per policy, two-sided, a LOSS = p < 0.05 with new lower;
#   VERDICT = GAIN iff A p < 0.05 and no loss on C, else NO GAIN (the failing part named). clip rule: before/after cut ONLY on GAIN; the word "bound" / flights in a caption only if the hero take shows >= 3 flights >= 80 ms (the seed does too, so it is never framed as learned).
# body: ~/Pollen/duck-train-body.sh (shared with every duck item).
SKILL=moon
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckmoon-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
