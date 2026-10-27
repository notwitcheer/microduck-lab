#!/bin/bash
# proof-dr-b.sh (2026-10-27, staged with 09z14): condition B, REPORTED ONLY (not in the verdict): the same dribble condition as A but WITH the maker's play shoves (push every 0.5-1 s), 10 takes per policy.
# drb-tN = 09z14 policy (model_22000), drsb-tN = the walk-stairs seed (model_19000), same task. scored with dr-score-2026-10-27.py (CARRIED, near, travel). test hooks as proof-dr-a.sh.
export MICRODUCK_DRIBBLE_GOAL=1
PROOF_TAG=${PROOF_TAG:-$(date +%F)}
OUT=/home/witcheer/Pollen/clips/proof-dr-b-$PROOF_TAG
. /home/witcheer/Pollen/proof-common-dr-2026-10-27.sh
Z=${DR_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckdribble/*_duckdribble/model_22000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_DR_CHECKPOINT"; exit 2; }
R=${DR_REF:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstairs/*_duckvelstairs/model_19000.pt | tail -n 1)}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
T=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck
echo "dr ckpt: $Z  ref: $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 24 --log-every 10 --cmd-vx 0.25 ${DR_CAM:---cam-distance 1.9 --cam-elevation -12 --cam-azimuth 70}"
for i in $(seq 1 ${PROOF_N:-10}); do
  play drb-t$i $T $Z 1200 $C
  play drsb-t$i $T $R 1200 $C
done
echo "=== $(date -u +%T) PROOF_DR_B_END ==="
