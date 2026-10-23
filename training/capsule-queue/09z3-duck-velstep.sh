#!/bin/bash
# 09z3-duck-velstep.sh: duck skill tree, "our own conditions" track (skill-tree.md side branch: "a single step"), third fork
# of a walking task, sibling of 09z (payload) and 09z2 (slippery floor). task Mjlab-Velocity-Flat-Backlash-Step-MicroDuck = the
# maker's Velocity-Flat-Backlash (walk-flat v2 on the Hub) with ONE change: the infinite plane becomes a generated floor that is
# flat except for one raised 1.5 m platform per 4 m tile, top 10-25 mm above the floor (random per tile), 2.5 m of floor between
# platforms. every edge crossing is a single step (down off the spawn platform, up onto the next). module
# witcheer_velocity_step_env_cfg.py (vault 99-personal/benchmark-rig/scripts/), registered by one appended import line (backup
# ~/tasks-init.py.bak-step-2026-10-13); resolved-cfg repr vs the base task = only terrain_type plane -> generator + the
# generator block (install log in log.md 2026-10-13). height reads: depends on our ground_height_patch (_ground_z from
# foot_height_scan on generator terrain); the only origin-z read left (body_pose_tracking_6d) has weight 0 in this task.
# WARM START: logs/rsl_rl/duckvelstep/2026-10-13_00-00-00_seed-velbl-it7000/model_7000.pt = walk-flat v2 (duckvelbl model_7000,
# md5 d16ed76e, the same seed as 09z and 09z2), true resume, 7000 -> 10000 (3k rule).
# verdict plan: walk-flat v2 vs this policy in this env with MICRODUCK_STEP_HEIGHT=0.025,0.025 (tallest) and 0.0,0.0 (same
# layout, no step), 20 s takes, falls = mid RESET lines (fell_over) + tilt events, same takes per policy; check r (distance from
# origin) so every quoted take actually crossed an edge (0.75 m from spawn).
# held out of the queue by ~/Pollen/w09z3-enqueue.sh until after the tue 2026-10-13 14:10 block (09z2 trains there), so the duck
# lane keeps an item queued once 09z2 exports. probe numbers: log.md 2026-10-13.
SKILL=velstep
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelstep-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Step-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
