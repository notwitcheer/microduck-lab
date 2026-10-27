#!/bin/bash
# proof-dr-c.sh (2026-10-27, staged with 09z14): condition C, the NO-LOSS check on plain walking: the stock task Mjlab-Velocity-Flat-Backlash-MicroDuck (no ball, no goal), forced forward command vx 0.25 m/s, the maker's play
# shoves ON, 20 s episodes, 10 takes per policy. held = no mid RESET and no tilt fall. drc-tN = 09z14 policy, drsc-tN = the walk-stairs seed. two-sided Fisher; a LOSS = p < 0.05 with the new policy lower
# (dr-score-2026-10-27.py --noball). test hooks as proof-dr-a.sh. (cheap: small video, scored from the logs.)
export MICRODUCK_DRIBBLE_GOAL=0
PROOF_TAG=${PROOF_TAG:-$(date +%F)}
OUT=/home/witcheer/Pollen/clips/proof-dr-c-$PROOF_TAG
. /home/witcheer/Pollen/proof-common-dr-2026-10-27.sh
Z=${DR_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckdribble/*_duckdribble/model_22000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_DR_CHECKPOINT"; exit 2; }
R=${DR_REF:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstairs/*_duckvelstairs/model_19000.pt | tail -n 1)}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
T=Mjlab-Velocity-Flat-Backlash-MicroDuck
echo "dr ckpt: $Z  ref: $R  task $T (stock walk, no ball)"
C="--episode-s 20 --log-every 10 --cmd-vx 0.25 --cam-distance 0.55 --cam-elevation -10"
for i in $(seq 1 ${PROOF_N:-10}); do
  play drc-t$i $T $Z 1000 $C
  play drsc-t$i $T $R 1000 $C
done
echo "=== $(date -u +%T) PROOF_DR_C_END ==="
