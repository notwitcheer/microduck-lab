#!/bin/bash
# 09z4-duck-velpush.sh: duck skill tree, "our own conditions" track (skill-tree.md side branch: "stronger pushes"), fourth fork
# of a walking task, sibling of 09z (payload), 09z2 (slippery floor, GAIN -> walk-slip candidate) and 09z3 (single step).
# task Mjlab-Velocity-Flat-Backlash-Push-MicroDuck = the maker's Velocity-Flat-Backlash (walk-flat v2 on the Hub) with ONE change:
# the training push_robot event (push_by_setting_velocity, interval 3-6 s) adds a root velocity change of +-0.6 m/s in x and y
# instead of the maker's +-0.3 (2x, interval unchanged). the maker's cfg comment: +-0.5 once trained "a permanently nervous
# fall-recovery gait", so the verdict reads the calm-gait cost too (control c + training windows vs v2). module
# witcheer_velocity_push_env_cfg.py (vault 99-personal/benchmark-rig/scripts/), registered by one appended import line (backup
# ~/tasks-init.py.bak-push-2026-10-14); resolved-cfg repr vs the base task = only push_robot velocity_range (train and play);
# base, slip, payload, step reprs identical before/after (install-push-fork-2026-10-14.log). no terrain patch dependency
# (plane floor), the clone's standard patches only.
# WARM START: logs/rsl_rl/duckvelpush/2026-10-14_00-00-00_seed-velbl-it7000/model_7000.pt = walk-flat v2 (duckvelbl model_7000,
# md5 d16ed76e, the seed of 09z/09z2/09z3), true resume, 7000 -> 10000 (3k rule).
# probe (free card, 4096 envs): 1.17 s/it median (n=46), card peak 7,143 MiB, train rc 0 (58 s), export rc 0 (793,775 B), 0 size mismatch;
# ~59 min + export at 4096 = one duck block. log ~/Pollen/probe-velpush.log, numbers in log.md 2026-10-14.
# verdict: proof-z4-{a,b,c}.sh (z4 vs v2 in the push env, 15 takes each, --cmd-vx 0.3): a = 2x shove every 0.5-1 s (play
# default), b = 2x shove every 3-6 s (training cadence), c = maker 1x shove every 0.5-1 s (control). play reach: push-play-check.
# held out of the queue by ~/Pollen/w09z4-enqueue.sh until after the wed 2026-10-14 14:10 block (09z3 trains there).
SKILL=velpush
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelpush-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Push-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
