#!/bin/bash
# proof-gm-batch-2026-10-28.sh <gale|moon> <a|b|c> [from to]: one batch of the pre-registered proof takes of 09z19 (gale) / 09z21 (moon). The batch name decides everything; see the item headers + vault log.md 2026-10-28.
#   gale A (GAIN)    task Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck, peak 3.0 N, ramp 12 s, forced vx 0.25, NO shoves, 14 s, 15 takes per policy, video. prefixes gnew / gref.
#   gale B (reported) the same gale WITH the maker's play shoves (push every 0.5-1 s), 10 takes per policy, logs only. prefixes gbnew / gbref.
#   gale C (no loss)  stock task Mjlab-Velocity-Flat-Backlash-MicroDuck (no wind), vx 0.25, play shoves ON, 20 s, 10 takes per policy, logs only. prefixes gcnew / gcref.
#   moon A (GAIN)     task Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck, g 1.62, forced vx 0.25, NO shoves, 10 s, 15 takes per policy, video. prefixes mnew / mref.
#   moon B (reported) the same task at Mars gravity (MICRODUCK_MOON_G=3.71), no shoves, 10 s, 10 takes per policy, logs only. prefixes mbnew / mbref.
#   moon C (no loss)  stock task, Earth, vx 0.25, play shoves ON, 20 s, 10 takes per policy, logs only. prefixes mcnew / mcref.
# new = the item's final checkpoint (model_10000), ref = its seed (walk-flat v2, duckvelbl model_7000), taken in the SAME env, re-taken (nothing reused from the design probes).
# camera for the video batches: the duck faces +x (--face-x), fixed side azimuth 270 (the duck walks to the right), tracking the trunk, 0.7 m, -8 deg.
# test hooks (e2e only): PROOF_TAG (OUT suffix), PROOF_N (takes, overrides the per-batch n and `to`), GM_CKPT (new checkpoint override), GM_REF (reference override), GM_DEVICE=cpu.
set -uo pipefail
MODE=${1:?gale|moon}; COND=${2:?a|b|c}
PROOF_TAG=${PROOF_TAG:-2026-10-28}
OUT=/home/witcheer/Pollen/clips/proof-$MODE-$COND-$PROOF_TAG
P=/home/witcheer/Pollen; L=$P/microduck_rl/logs/rsl_rl
case $MODE in
  gale) EXP=duckgale; TASK=Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck; PFX=g; export MICRODUCK_GALE_PEAK=3.0 MICRODUCK_GALE_RAMP=12; EPA=14 ;;
  moon) EXP=duckmoon; TASK=Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck; PFX=m; EPA=10 ;;
  *) echo "bad mode $MODE"; exit 2 ;;
esac
STOCK=Mjlab-Velocity-Flat-Backlash-MicroDuck
export GM_VIDEO=0; CAM="--face-x --cam-distance 0.7 --cam-elevation -8 --cam-azimuth 270"
case $COND in
  a) export GM_VIDEO=1; EP=$EPA; N=15; T=$TASK; ARGS="--no-push $CAM"; NP=${PFX}new; RP=${PFX}ref ;;
  b) EP=$EPA; N=10; T=$TASK; NP=${PFX}bnew; RP=${PFX}bref
     if [ $MODE = gale ]; then ARGS="--face-x"; else ARGS="--no-push --face-x"; export MICRODUCK_MOON_G=3.71; fi ;;
  c) EP=20; N=10; T=$STOCK; ARGS="--cam-distance 0.55 --cam-elevation -10"; NP=${PFX}cnew; RP=${PFX}cref; unset MICRODUCK_GALE_PEAK MICRODUCK_GALE_RAMP ;;
  *) echo "bad cond $COND"; exit 2 ;;
esac
. $P/proof-gm-common-2026-10-28.sh
FROM=${3:-1}; TO=${PROOF_N:-${4:-$N}}
Z=${GM_CKPT:-$(ls -1 $L/$EXP/*_$EXP/model_10000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] && [ -f "$Z" ] || { echo "NO_NEW_CHECKPOINT ($EXP model_10000 missing: item cut or not run)"; exit 2; }
R=${GM_REF:-$(ls -1 $L/duckvelbl/*_duckvelbl/model_7000.pt 2>/dev/null | tail -n 1)}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
echo "$MODE batch $COND: new $Z  ref (walk-flat v2) $R  task $T  takes $FROM..$TO  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s $EP --log-every 25 --cmd-vx 0.25 $ARGS"; STEPS=$(python3 -c "print(int(round($EP/0.02)))")
for i in $(seq $FROM $TO); do
  play $NP-t$i $T $Z $STEPS $C
  play $RP-t$i $T $R $STEPS $C
done
echo "=== $(date -u +%T) PROOF_${MODE^^}_${COND^^}_END $FROM..$TO ==="
