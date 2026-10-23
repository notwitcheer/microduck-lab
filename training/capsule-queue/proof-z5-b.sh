#!/bin/bash
# proof-z5-b (2026-10-14, staged with the item): 09z5 velslope model_10000 vs walk-flat v2 (duckvelbl model_7000)
# in Velocity-Flat-Backlash-Slope, MICRODUCK_SLOPE=0.15,0.15: 0.15 rise/run hill (127 mm top), NO shoves.
# 15 takes per policy (sample-size rule 2026-10-13), 20 s, 0.1 s samples, tracking camera, twist fixed straight ahead at 0.3 m/s
# (--cmd-vx: random play commands never reach the feature), --no-bounds (a 1-env take spawns in an edge column of the tile
# grid and mjlab's out_of_terrain_bounds ends it upright after ~1.7 m: slope-calib-2026-10-14.sh). falls = tilt events + mid RESETs (take-score-2026-10-11.py), located
# by r= (z5-score-2026-10-16.py: < 0.95 m = hill top, >= 0.95 m = slope/valley). override reach: slope-play-check-2026-10-14.sh.
# sibling of proof-z3-b.sh / proof-z4-b.sh.
export MICRODUCK_SLOPE=0.15,0.15
TASK=Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z5-b-2026-10-16
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslope/*_duckvelslope/model_10000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z5_CHECKPOINT (09z5 model_10000 missing: item cut or not run)"; exit 2; }
echo "z5 ckpt: $Z  SLOPE=${MICRODUCK_SLOPE:-}"
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
P="--no-push"
for i in $(seq 1 15); do for q in z5:$Z v2:$V2; do
  play ${q%%:*}-b-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z5_B_END ==="
