#!/bin/bash
# proof-z7-a (2026-10-22, staged with 09z7): hill 0.15 + 25 mm step + foot friction 0.2 + 2x shoves every 3-6 s in the MixSlope env (tiles 0.5 step / 0.5 hill),
# z7 vs walk-mix (09z6 model_13000). PRE-REGISTERED GAIN CONDITION (one-sided Fisher).
# 15 takes per policy, 20 s, 0.1 s samples, tracking camera, --cmd-vx 0.3, --no-bounds (generator floor, edge-column truncation fix).
# take names carry a per-batch prefix (z7a-tN / z6a-tN), unique across proof-z7 a/b/c and every earlier batch; proof-common.sh
# keys its tmp dir by batch since 2026-10-22. scored with z7-score-2026-10-22.py. OUT dated 2026-10-22 (staging date label).
export MICRODUCK_SLOPE=0.15,0.15
export MICRODUCK_STEP_HEIGHT=0.025,0.025
export MICRODUCK_FOOT_FRICTION=0.2,0.2
export MICRODUCK_PUSH_SCALE=2.0
export MICRODUCK_PUSH_INTERVAL=3,6
TASK=Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z7-a-2026-10-22
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmixslope/*_duckvelmixslope/model_16000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo "NO_Z7_CHECKPOINT (09z7 model_16000 missing: item cut or not run)"; exit 2; }
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmix/2026-10-18_16-27-19_duckvelmix/model_13000.pt
[ -f "$R" ] || { echo "NO_RIVAL_CHECKPOINT $R"; exit 2; }
echo "z7 ckpt: $Z  rival z6a: $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
P=""
for i in $(seq 1 15); do for q in z7a:$Z z6a:$R; do
  play ${q%%:*}-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z7_A_END ==="
