#!/bin/bash
# MOJO: a duck that leans into a gale while it holds the wind | v3 moves the upright target with the wind instead of fighting it | [a duck leaning into a 3 N wind]
# serves: content + experiment
# 09z48-duck-lean3.sh: the lean line, v3. task Mjlab-Velocity-Flat-Backlash-Lean3-MicroDuck = the lean env (LEAN_W 1.5) with ONE change: the maker's upright
# Gaussian (weight 2.0, std^2 0.05) now targets the wind lean atan(F/7.8 N), capped at 15 deg, instead of 0 deg (no wind = the stock term, checked: max diff 0.0).
# why: the 0.5 and 1.5 runs each settled at the static optimum of upright + lean_into_wind (1.7 / 6.2 deg on paper, +2..4 / +7..11 deg measured) within ~250 it.
# a weight-only push moves that optimum slowly; moving the upright target puts it at 15 deg at 3.0 N (on paper).
# experiment ducklean3 (own run dir + manifest), seed = walk-flat v2 model_7000 (md5 d16ed76e1dde), copied to logs/rsl_rl/ducklean3/2026-10-28_00-00-00_seed-velbl-it7000/.
# PRE-REGISTRATION: vault 60-robotics/microduck/09z42-duck-lean-status.md, V3 section. 12.6 deg bar and verdict words unchanged; a re-check beside the frozen results.
# 3000 it (7000 -> 10000), checkpoints every 250; proof = 09z49-duck-proof-lean3.sh (CPU, same block).
# WINDOW: NOT_BEFORE Sat 2026-11-14 00:10 CET (1794611400), the weekend drain (no alternation), so it never takes the Fri 14:10 block planned for 9a1.
# a real run before then exits 3 BEFORE the lane check and the Donald drain (nothing recorded, stays queued); DRYRUN is never gated.
SKILL=lean3
TASK=Mjlab-Velocity-Flat-Backlash-Lean3-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
SAVE_EVERY=250
export MICRODUCK_LEAN_W=1.5
NOT_BEFORE=${NOT_BEFORE:-1794611400}
if [ "${DRYRUN:-0}" != 1 ] && [ "$(date +%s)" -lt "$NOT_BEFORE" ]; then echo "[ducklean3] NOT_BEFORE $(date -d "@$NOT_BEFORE" '+%a %F %H:%M %Z') not reached, exit 3 (stays queued, nothing started)"; exit 3; fi
. /home/witcheer/Pollen/duck-train-body.sh
