#!/bin/bash
# proof-y-a (2026-10-11): 09y velroughbl model_11000 vs walk-rough v1 (velrough model_8000) in Velocity-Rough-Backlash,
# forced hardest row L9 x 3 rough types x 3 takes, --no-push --spawn-offset 1.6, 20 s, 0.1 s samples. falls = tilt events + mid RESETs.
TASK=Mjlab-Velocity-Rough-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-y-a-2026-10-11
. /home/witcheer/Pollen/proof-common-wt.sh
Y=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelroughbl/2026-10-09_14-10-19_duckvelroughbl/model_11000.pt
V1=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelrough/2026-09-19_02-53-18_duckvelrough/model_8000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.6 --cam-elevation -25 --no-push --spawn-offset 1.6"
for ty in pyramid_stairs random_grid pyramid_slope; do for i in 1 2 3; do for p in y:$Y v1:$V1; do
  play ${p%%:*}-L9-$ty-t$i $TASK ${p#*:} 1000 $C --terrain-level 9 --terrain-type $ty; done; done; done
echo "=== $(date -u +%T) PROOF_Y_A_END ==="
