#!/bin/bash
# walk-recover-rough candidate (vsrough3 model_23000) vs its seed (velstand model_20000 = walk-recover v1) in VelStand-Rough.
# standing L9 x3 types x3, face_down L6 x3 types x2, face_up L6 x3 types x1. --no-push --spawn-offset 1.6, 20 s, 0.1 s.
TASK=Mjlab-VelStand-Rough-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-vsr3-2026-10-02
. /home/witcheer/Pollen/proof-common.sh
V3=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsrough3/2026-10-02_14-10-19_duckvsrough3/model_23000.pt
SD=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsrough3/2026-09-28_00-00-00_seed-velstand-it20000/model_20000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.6 --cam-elevation -25 --no-push --spawn-offset 1.6"
for ty in pyramid_stairs random_grid pyramid_slope; do
  for i in 1 2 3; do for p in v3:$V3 seed:$SD; do play ${p%%:*}-standing-L9-$ty-t$i $TASK ${p#*:} 1000 $C --spawn standing --terrain-level 9 --terrain-type $ty; done; done
  for i in 1 2; do for p in v3:$V3 seed:$SD; do play ${p%%:*}-face_down-L6-$ty-t$i $TASK ${p#*:} 1000 $C --spawn face_down --terrain-level 6 --terrain-type $ty; done; done
  for p in v3:$V3 seed:$SD; do play ${p%%:*}-face_up-L6-$ty-t1 $TASK ${p#*:} 1000 $C --spawn face_up --terrain-level 6 --terrain-type $ty; done
done
echo "=== $(date -u +%T) PROOF_VSR3_END ==="
