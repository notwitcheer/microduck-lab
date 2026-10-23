#!/bin/bash
# proof-x-a (2026-10-11): 09x vsroughbl model_12000 vs its seed 09w carpetbl model_9000 in VelStand-Rough-Backlash (soft_carpet worktree,
# ported terrain patches), standing spawn, forced L9 x 3 rough types x 3 takes, --no-push --spawn-offset 1.6, 20 s, 0.1 s.
TASK=Mjlab-VelStand-Rough-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-x-a-2026-10-11
WT=/home/witcheer/Pollen/microduck_rl-carpet
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
. /home/witcheer/Pollen/proof-common-wt.sh
X=/home/witcheer/Pollen/microduck_rl-carpet/logs/rsl_rl/duckvsroughbl/2026-10-08_14-10-19_duckvsroughbl/model_12000.pt
W=/home/witcheer/Pollen/microduck_rl-carpet/logs/rsl_rl/duckcarpetbl/2026-10-07_14-10-19_duckcarpetbl/model_9000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.6 --cam-elevation -25 --no-push --spawn-offset 1.6"
for ty in pyramid_stairs random_grid pyramid_slope; do for i in 1 2 3; do for p in x:$X w:$W; do
  play ${p%%:*}-standing-L9-$ty-t$i $TASK ${p#*:} 1000 $C --spawn standing --terrain-level 9 --terrain-type $ty; done; done; done
echo "=== $(date -u +%T) PROOF_X_A_END ==="
