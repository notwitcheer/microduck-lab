#!/bin/bash
# proof-z2-a (2026-10-13): 09z2 velslip model_10000 vs walk-flat v2 (duckvelbl model_7000) in Velocity-Flat-Backlash-Slip,
# foot friction forced MICRODUCK_FOOT_FRICTION=0.2,0.2 (slipperiest), push, 5 takes per policy,
# 20 s, 0.1 s samples, tracking camera. falls = tilt events + mid RESETs (take-score-2026-10-11.py). mirrors proof-z-a.
export MICRODUCK_FOOT_FRICTION=0.2,0.2
TASK=Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z2-a-2026-10-13
. /home/witcheer/Pollen/proof-common.sh
Z=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslip/2026-10-13_14-10-19_duckvelslip/model_10000.pt
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10"
P=""; [ "push" = nopush ] && P="--no-push"
for i in $(seq 1 5); do for q in z2:$Z v2:$V2; do
  play ${q%%:*}-a-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z2_A_END ==="
