#!/bin/bash
# proof-z6-c (2026-10-16, staged with 09z6): flat (1 mm) + foot friction 0.2 + maker shoves every 0.5-1 s: mix vs walk-slip (no-loss check).
# 15 takes per policy, 20 s, 0.1 s samples, tracking camera, --cmd-vx 0.3, --no-bounds (generator floor, edge-column truncation fix).
# scored with take-score-2026-10-11.py + z6-score (= z5-score copy, Fisher via math.comb). OUT dated 2026-10-17 (expected weekend run date).
export MICRODUCK_STEP_HEIGHT=0.001,0.001
export MICRODUCK_FOOT_FRICTION=0.2,0.2
export MICRODUCK_PUSH_SCALE=1.0

TASK=Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z6-c-2026-10-17
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmix/*_duckvelmix/model_13000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z6_CHECKPOINT"; exit 2; }
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslip/2026-10-13_14-10-19_duckvelslip/model_10000.pt
echo "z6 ckpt: $Z  rival z2: $R"
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
P=""
for i in $(seq 1 15); do for q in z6:$Z z2:$R; do
  play ${q%%:*}-c-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z6_C_END ==="
