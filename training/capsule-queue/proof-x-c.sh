#!/bin/bash
# proof-x-c (2026-10-11): "part A" owed since 10-08: 09w and 09x in the branch's flat VelStand-Flat-Backlash env, forced spawns,
# verdict-carpet.sh harness (12 s one episode, fixed world camera auto, 0.1 s samples): face_up x3, face_down x2, standing x2 each.
TASK=Mjlab-VelStand-Flat-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-x-c-2026-10-11
WT=/home/witcheer/Pollen/microduck_rl-carpet
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
. /home/witcheer/Pollen/proof-common-wt.sh
X=/home/witcheer/Pollen/microduck_rl-carpet/logs/rsl_rl/duckvsroughbl/2026-10-08_14-10-19_duckvsroughbl/model_12000.pt
W=/home/witcheer/Pollen/microduck_rl-carpet/logs/rsl_rl/duckcarpetbl/2026-10-07_14-10-19_duckcarpetbl/model_9000.pt
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for p in x:$X w:$W; do
  for i in 1 2 3; do play ${p%%:*}-face_up-t$i $TASK ${p#*:} 600 $C --spawn face_up; done
  for i in 1 2; do play ${p%%:*}-face_down-t$i $TASK ${p#*:} 600 $C --spawn face_down; play ${p%%:*}-standing-t$i $TASK ${p#*:} 600 $C --spawn standing; done
done
echo "=== $(date -u +%T) PROOF_X_C_END ==="
