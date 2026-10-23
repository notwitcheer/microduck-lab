#!/bin/bash
# 09z5-duck-velslope.sh: duck skill tree, "our own conditions" track (skill-tree.md side branch: "slopes"), fifth fork of a
# walking task, sibling of 09z (payload, no gain), 09z2 (slippery floor, GAIN -> walk-slip), 09z3 (single step, GAIN) and
# 09z4 (stronger pushes). task Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck = the maker's Velocity-Flat-Backlash (walk-flat v2
# on the Hub) with ONE change: the infinite plane becomes a generated floor of gentle hills, one mjlab HfPyramidSlopedTerrainCfg
# per 4 m tile (the maker's own pyramid_slope generator, vertical_scale 0.001), gradient 0.05-0.15 rise/run random per tile
# (maker's rough cap 0.10), flat top ~1.0-1.15 m from the tile centre, 127 mm high at 0.15. module
# witcheer_velocity_slope_env_cfg.py (vault 99-personal/benchmark-rig/scripts/), registered by one appended import line (backup
# ~/tasks-init.py.bak-slope-2026-10-14); resolved-cfg repr vs the base task = only scene.terrain (27 items, train and play);
# base, slip, payload, step, push reprs identical before/after (install-slope-fork-2026-10-14.log). height reads: depends on our
# ground_height_patch (_ground_z from foot_height_scan on generator terrain, checked on the slope by slope-play-check).
# WARM START: logs/rsl_rl/duckvelslope/2026-10-14_00-00-00_seed-velbl-it7000/model_7000.pt = walk-flat v2 (duckvelbl model_7000,
# md5 d16ed76e, the seed of 09z..09z4), true resume, 7000 -> 10000 (3k rule).
# probe (free card, 4096 envs, 2026-10-14 18:24 CEST): 2.55 s/it median (n=46, 2x the step fork: heightfield collision +
# ray cost, collection 2.50 s of it), card peak 7,490 MiB, train rc 0 (116 s), export rc 0 (793,777 B), 0 size mismatch,
# nan_state 0.0000; ~128 min + export at 4096 = one duck block if it starts the block (log ~/Pollen/probe-velslope.log).
# verdict: proof-z5-{a,b,c}.sh (z5 vs v2 in the slope env, 15 takes each, --cmd-vx 0.3): a = 0.15 hill + play shoves,
# b = 0.15 hill no shoves, c = 0.001 (1 mm top, same layout) + shoves (control). scorer z5-score-2026-10-16.py.
# held out of the queue by ~/Pollen/w09z5-enqueue.sh until after the thu 2026-10-15 14:10 block (09z4 trains there); by the lane
# alternation fri 01:10 is bench, so 09z5 trains fri 2026-10-16 14:10.
SKILL=velslope
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelslope-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
