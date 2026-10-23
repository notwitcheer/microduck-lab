#!/bin/bash
# proof-z6-b (2026-10-16, staged with 09z6): 25 mm step, normal grip, no shoves: mix vs walk-step (no-loss check).
# 15 takes per policy, 20 s, 0.1 s samples, tracking camera, --cmd-vx 0.3, --no-bounds (generator floor, edge-column truncation fix).
# scored with take-score-2026-10-11.py + z6-score (= z5-score copy, Fisher via math.comb). OUT dated 2026-10-17 (expected weekend run date).
export MICRODUCK_STEP_HEIGHT=0.025,0.025
export MICRODUCK_FOOT_FRICTION=1.0,1.0
export MICRODUCK_PUSH_SCALE=1.0

TASK=Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z6-b-2026-10-17
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmix/*_duckvelmix/model_13000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z6_CHECKPOINT"; exit 2; }
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstep/2026-10-14_14-30-21_duckvelstep/model_10000.pt
echo "z6 ckpt: $Z  rival z3: $R"
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
P="--no-push"
for i in $(seq 1 15); do for q in z6:$Z z3:$R; do
  play ${q%%:*}-b-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z6_B_END ==="
