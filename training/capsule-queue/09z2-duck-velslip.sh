#!/bin/bash
# 09z2-duck-velslip.sh: duck skill tree, "our own conditions" track (skill-tree.md side branch: "low-friction floor"), second fork
# of a walking task, sibling of 09z (payload). task Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck = the maker's Velocity-Flat-Backlash
# (walk-flat v2 on the Hub) with ONE parameter changed: the startup foot friction DR (dr.geom_friction abs, both foot collision
# geoms, shared) widened from the maker's 0.7-1.3 to 0.2-1.3. the foot geoms carry priority 1, so the foot value IS the contact
# friction: low values model a slippery floor. module witcheer_velocity_slip_env_cfg.py (vault 99-personal/benchmark-rig/scripts/),
# registered by one appended import line (backup ~/tasks-init.py.bak-slip-2026-10-12); resolved-cfg repr vs the base task: see
# install log in log.md 2026-10-12.
# WARM START: logs/rsl_rl/duckvelslip/2026-10-12_00-00-00_seed-velbl-it7000/model_7000.pt = walk-flat v2 (duckvelbl model_7000,
# md5 d16ed76e, the same seed as 09z), true resume, 7000 -> 10000 (3k rule). same seed + one variable = 09z and 09z2 compare cleanly.
# verdict plan: walk-flat v2 vs this policy in this env with MICRODUCK_FOOT_FRICTION=0.2,0.2 (slipperiest) and 1.0,1.0 (normal),
# 20 s takes, falls = mid RESET lines (fell_over) + tilt events, same takes per policy.
# enqueued by the watcher ~/Pollen/w09z2-enqueue.sh after the mon 2026-10-12 14:10 block (so it trains in the tue 14:10 duck
# block and the duck lane keeps an item queued after 09z exports). probe numbers: log.md 2026-10-12.
SKILL=velslip
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelslip-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
