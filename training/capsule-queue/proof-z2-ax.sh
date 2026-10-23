#!/bin/bash
# proof-z2-ax (2026-10-13 evening): EXTENSION of proof-z2 (first set inconclusive: slip 6/8 vs 3/8, normal 3/5 vs 4/5).
# 09z2 velslip model_10000 vs walk-flat v2 model_7000 in Velocity-Flat-Backlash-Slip, MICRODUCK_FOOT_FRICTION=0.2,0.2 (slipperiest),
# push, takes t6..t15 per policy (numbering continues the first set), same 20 s / tracking camera / scorer.
export MICRODUCK_FOOT_FRICTION=0.2,0.2
TASK=Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z2-ax-2026-10-13
. /home/witcheer/Pollen/proof-common.sh
Z=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslip/2026-10-13_14-10-19_duckvelslip/model_10000.pt
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10"
P=""; [ "push" = nopush ] && P="--no-push"
for i in $(seq 6 15); do for q in z2:$Z v2:$V2; do
  play ${q%%:*}-a-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z2_AX_END ==="
