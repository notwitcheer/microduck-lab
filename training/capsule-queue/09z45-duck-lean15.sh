#!/bin/bash
# MOJO: a duck that leans into a gale while it holds the wind | a 3x stronger lean term, does it finally bow into the wind | [a duck leaning into a 3 N wind]
# serves: content + experiment
# 09z45-duck-lean15.sh: the 09z42 lean RE-CHECK. same env, same seed, same task, LEAN_W 1.5 instead of 0.5 (3x), 6000 iterations (7000 -> 13000).
# why the weight is the lever: the 0.5 run (09z42) reached its plateau by +250 it (10-take sweep: +2.35 deg at c7250, no climb to c10000), so the limit was
# the term's equilibrium, not an iteration shortage. the budget is doubled anyway so the sweep sees whether 1.5 keeps climbing past 250 it.
# experiment ducklean15 (own run dir + own manifest), seed = walk-flat v2 model_7000 (md5 d16ed76e1dde), copied to
# logs/rsl_rl/ducklean15/2026-10-28_00-00-00_seed-velbl-it7000/ before the run.
# PRE-REGISTRATION: vault 60-robotics/microduck/09z42-duck-lean-status.md RE-CHECK section. 12.6 deg bar unchanged, n=10 sweep, a re-check, not a new verdict.
# checkpoints every 250 it; proof = 09z46-duck-proof-lean15.sh (CPU, same block).
# CARD HARD STOP 04:10 CET (ITEM_HARD_STOP_EPOCH=1794453000) so the CPU proof has the rest of the 01:10-06:10 block; the block id NL_HARD_STOP_EPOCH is untouched.
SKILL=lean15
MANIFEST=/home/witcheer/ducklean15-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Lean-MicroDuck
TARGET_IT=${TARGET_IT:-13000}
SAVE_EVERY=250
export MICRODUCK_LEAN_W=1.5
ITEM_HARD_STOP_EPOCH=1794453000
. /home/witcheer/Pollen/duck-train-body.sh
