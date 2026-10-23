#!/bin/bash
# proof-z4-b (2026-10-14, staged with the item): 09z4 velpush model_10000 vs walk-flat v2 (duckvelbl model_7000)
# in Velocity-Flat-Backlash-Push, MICRODUCK_PUSH_SCALE=2.0 (+-0.6 m/s) at the TRAINING interval 3-6 s (MICRODUCK_PUSH_INTERVAL=3,6): the shove the fork trained on.
# 15 takes per policy (sample-size rule 2026-10-13), 20 s, 0.1 s samples, tracking camera, twist fixed straight ahead at 0.3 m/s
# (--cmd-vx). falls = tilt events + mid RESETs (take-score-2026-10-11.py). override reach proven by push-play-check-2026-10-14.sh.
# sibling of proof-z3-b.sh.
export MICRODUCK_PUSH_SCALE=2.0
export MICRODUCK_PUSH_INTERVAL=3,6
TASK=Mjlab-Velocity-Flat-Backlash-Push-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z4-b-2026-10-15
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelpush/*_duckvelpush/model_10000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z4_CHECKPOINT (09z4 model_10000 missing: item cut or not run)"; exit 2; }
echo "z4 ckpt: $Z  PUSH_SCALE=${MICRODUCK_PUSH_SCALE:-} PUSH_INTERVAL=${MICRODUCK_PUSH_INTERVAL:-play default}"
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3"
for i in $(seq 1 15); do for q in z4:$Z v2:$V2; do
  play ${q%%:*}-b-t$i $TASK ${q#*:} 1000 $C; done; done
echo "=== $(date -u +%T) PROOF_Z4_B_END ==="
