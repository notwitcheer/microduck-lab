#!/bin/bash
# proof-dr-a.sh [from to] (2026-10-27, staged with 09z14): THE PRE-REGISTERED CONDITION (A) of the dribble verdict. 300 mm ball 0.27 m ahead of the duck, goal mouth at x = 1.8 m, duck turned to face it (face_goal),
# forced forward command vx 0.25 m/s, NO shoves, 24 s episodes, 0.2 s samples. success = CARRIED (dr-score-2026-10-27.py): held AND the ball enters the goal mouth AND the ball is NEAR the duck
# (0 < gap < 0.60 m, |lat| < 0.30 m) at every sample from t = 1.0 s until it enters the goal. new vs ref one-sided exact Fisher p < 0.05 = GAIN.
# policies: dra-tN = the 09z14 dribble policy (duckdribble model_22000), drsa-tN = its seed (walk-stairs duckvelstairs model_19000) in the SAME task, re-taken (nothing reused from the sweep).
# takes from..to (default 1..15, 15 per policy); the item runs two copies (1 8 and 9 15) into the same OUT dir (take names are unique per take number, tmp dirs keyed by take name).
# test hooks (e2e of the proof item only): PROOF_TAG, PROOF_N (takes, overrides to), DR_CKPT, DR_REF. camera + size: DR_CAM / VW / VH (defaults = the pre-registered clip camera).
export MICRODUCK_DRIBBLE_GOAL=1
PROOF_TAG=${PROOF_TAG:-$(date +%F)}
OUT=/home/witcheer/Pollen/clips/proof-dr-a-$PROOF_TAG
. /home/witcheer/Pollen/proof-common-dr-2026-10-27.sh
FROM=${1:-1}; TO=${PROOF_N:-${2:-15}}
Z=${DR_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckdribble/*_duckdribble/model_22000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_DR_CHECKPOINT (09z14 model_22000 missing: item cut or not run)"; exit 2; }
R=${DR_REF:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstairs/*_duckvelstairs/model_19000.pt | tail -n 1)}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
T=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck
echo "dr ckpt: $Z  ref (drsa, walk-stairs 19000): $R  takes $FROM..$TO  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 24 --log-every 10 --no-push --cmd-vx 0.25 ${DR_CAM:---cam-distance 1.9 --cam-elevation -12 --cam-azimuth 70}"
for i in $(seq $FROM $TO); do
  play dra-t$i $T $Z 1200 $C
  play drsa-t$i $T $R 1200 $C
done
echo "=== $(date -u +%T) PROOF_DR_A_END $FROM..$TO ==="
