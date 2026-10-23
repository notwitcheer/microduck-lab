#!/bin/bash
# proof-z3-a (2026-10-14, staged with the item): 09z3 velstep model_10000 vs walk-flat v2 (duckvelbl model_7000)
# in Velocity-Flat-Backlash-Step, MICRODUCK_STEP_HEIGHT=0.025,0.025 (25 mm step, play shoves on), 15 takes per policy (sample-size rule 2026-10-13),
# 20 s, 0.1 s samples, tracking camera, twist fixed straight ahead at 0.3 m/s (--cmd-vx, added 10-14). falls = tilt events + mid RESETs (take-score-2026-10-11.py); read r= per take
# so every quoted take crossed a platform edge (spawn = platform centre, edge 0.75 m). mirrors proof-z2-a.
export MICRODUCK_STEP_HEIGHT=0.025,0.025
TASK=Mjlab-Velocity-Flat-Backlash-Step-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z3-a-2026-10-14
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstep/*_duckvelstep/model_10000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z3_CHECKPOINT (09z3 model_10000 missing: item cut or not run)"; exit 2; }
echo "z3 ckpt: $Z"
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3"
P=""; [ "push" = nopush ] && P="--no-push"
for i in $(seq 1 15); do for q in z3:$Z v2:$V2; do
  play ${q%%:*}-a-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z3_A_END ==="
