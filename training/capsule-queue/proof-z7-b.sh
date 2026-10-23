#!/bin/bash
# proof-z7-b (2026-10-22, staged with 09z7): hill 0.15, NO shoves, in the Slope env = the proof-z5-b harness, z7 vs walk-slope (09z5 model_10000).
# NO-LOSS condition (two-sided Fisher; a loss = significant two-sided result against z7).
# 15 takes per policy, 20 s, 0.1 s samples, tracking camera, --cmd-vx 0.3, --no-bounds (generator floor, edge-column truncation fix).
# take names carry a per-batch prefix (z7b-tN / z5b-tN), unique across proof-z7 a/b/c and every earlier batch; proof-common.sh
# keys its tmp dir by batch since 2026-10-22. scored with z7-score-2026-10-22.py. OUT dated 2026-10-22 (staging date label).
export MICRODUCK_SLOPE=0.15,0.15
TASK=Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z7-b-2026-10-22
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmixslope/*_duckvelmixslope/model_16000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z7_CHECKPOINT (09z7 model_16000 missing: item cut or not run)"; exit 2; }
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslope/2026-10-18_15-10-19_duckvelslope/model_10000.pt
[ -f "$R" ] || { echo "NO_RIVAL_CHECKPOINT $R"; exit 2; }
echo "z7 ckpt: $Z  rival z5b: $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
P="--no-push"
for i in $(seq 1 15); do for q in z7b:$Z z5b:$R; do
  play ${q%%:*}-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z7_B_END ==="
