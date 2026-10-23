#!/bin/bash
# proof-z8-a (2026-10-23, staged with 09z8): STAIRS condition: flights of 2-3 steps only (MICRODUCK_STAIRS_MIX=stairs2:0.5,stairs3:0.5), riser 25 mm (the top of the trained band, flights top out at 50-75 mm), foot friction 0.2 + 2x shoves every 3-6 s, in the Stairs env, z8 vs walk-mixslope. PRE-REGISTERED GAIN CONDITION (one-sided Fisher).
# 15 takes per policy, 20 s, 0.1 s samples, tracking camera, --cmd-vx 0.3, --no-bounds (generator floors; harmless on a plane).
# test hooks (e2e of the proof item only): PROOF_TAG (OUT suffix), PROOF_N (takes per policy), Z8_CKPT (checkpoint override); defaults are the real run.
# take names carry a per-batch prefix (z8a-tN / mxa-tN), unique across proof-z8 a/b/c and every earlier batch; proof-common.sh keys its
# tmp dir by batch (basename of OUT). scored with z8-score-2026-10-23.py. rival = walk-mixslope (09z7 model_16000, md5 82e6979d, = the seed).
export MICRODUCK_STAIRS_MIX=stairs2:0.5,stairs3:0.5
export MICRODUCK_STEP_HEIGHT=0.025,0.025
export MICRODUCK_FOOT_FRICTION=0.2,0.2
export MICRODUCK_PUSH_SCALE=2.0
export MICRODUCK_PUSH_INTERVAL=3,6
TASK=Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-z8-a-${PROOF_TAG:-2026-10-23}
. /home/witcheer/Pollen/proof-common.sh
Z=${Z8_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstairs/*_duckvelstairs/model_19000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_Z8_CHECKPOINT (09z8 model_19000 missing: item cut or not run)"; exit 2; }
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmixslope/2026-10-22_14-18-58_duckvelmixslope/model_16000.pt
[ -f "$R" ] || { echo "NO_RIVAL_CHECKPOINT $R"; exit 2; }
echo "z8 ckpt: $Z  rival mxa (walk-mixslope): $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
P=""
for i in $(seq 1 ${PROOF_N:-15}); do for q in z8a:$Z mxa:$R; do
  play ${q%%:*}-t$i $TASK ${q#*:} 1000 $C $P; done; done
echo "=== $(date -u +%T) PROOF_Z8_A_END ==="
