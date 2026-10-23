#!/bin/bash
# proof-z-c (2026-10-12): 09z velpay model_10000 vs walk-flat v2 (duckvelbl model_7000) in Velocity-Flat-Backlash-Payload,
# trunk mass forced MICRODUCK_PAYLOAD_SCALE=1.0,1.0 (play env check: 1.30 -> trunk 259.0 g vs 199.2 g), push, 5 takes per policy,
# 20 s, 0.1 s samples, tracking camera. falls = tilt events + mid RESETs (take-score-2026-10-11.py).
export MICRODUCK_PAYLOAD_SCALE=1.0,1.0
TASK=Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z-c-2026-10-12
. /home/witcheer/Pollen/proof-common.sh
Z=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelpay/2026-10-12_14-10-19_duckvelpay/model_10000.pt
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10"
P=""; [ "push" = nopush ] && P="--no-push"
for i in $(seq 1 5); do for q in z:$Z v2:$V2; do
  play ${q%%:*}-c-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z_C_END ==="
