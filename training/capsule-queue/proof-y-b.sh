#!/bin/bash
# proof-y-b (2026-10-11): same pair, L6 x 3 types x 1 in Velocity-Rough-Backlash, plus the reference: both in plain Velocity-Rough L9 x 3 types x 1.
OUT=/home/witcheer/Pollen/clips/proof-y-b-2026-10-11; TASK=x
. /home/witcheer/Pollen/proof-common-wt.sh
Y=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelroughbl/2026-10-09_14-10-19_duckvelroughbl/model_11000.pt
V1=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelrough/2026-09-19_02-53-18_duckvelrough/model_8000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.6 --cam-elevation -25 --no-push --spawn-offset 1.6"
for ty in pyramid_stairs random_grid pyramid_slope; do for p in y:$Y v1:$V1; do
  play ${p%%:*}-L6-$ty-t1 Mjlab-Velocity-Rough-Backlash-MicroDuck ${p#*:} 1000 $C --terrain-level 6 --terrain-type $ty
  play ref-${p%%:*}-L9-$ty-t1 Mjlab-Velocity-Rough-MicroDuck ${p#*:} 1000 $C --terrain-level 9 --terrain-type $ty; done; done
echo "=== $(date -u +%T) PROOF_Y_B_END ==="
