#!/bin/bash
# proof-x-b (2026-10-11): same pair in VelStand-Rough-Backlash, forced prone spawns on L6: face_down x 3 types x 1, face_up x 3 types x 1.
TASK=Mjlab-VelStand-Rough-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-x-b-2026-10-11
WT=/home/witcheer/Pollen/microduck_rl-carpet
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
. /home/witcheer/Pollen/proof-common-wt.sh
X=/home/witcheer/Pollen/microduck_rl-carpet/logs/rsl_rl/duckvsroughbl/2026-10-08_14-10-19_duckvsroughbl/model_12000.pt
W=/home/witcheer/Pollen/microduck_rl-carpet/logs/rsl_rl/duckcarpetbl/2026-10-07_14-10-19_duckcarpetbl/model_9000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.6 --cam-elevation -25 --no-push --spawn-offset 1.6"
for ty in pyramid_stairs random_grid pyramid_slope; do for sp in face_down face_up; do for p in x:$X w:$W; do
  play ${p%%:*}-$sp-L6-$ty-t1 $TASK ${p#*:} 1000 $C --spawn $sp --terrain-level 6 --terrain-type $ty; done; done; done
echo "=== $(date -u +%T) PROOF_X_B_END ==="
