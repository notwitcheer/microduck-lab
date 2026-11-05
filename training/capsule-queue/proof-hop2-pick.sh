#!/bin/bash
# proof-hop2-pick.sh (2026-10-29, staged with 09z22): the CHECKPOINT PICK takes of the hop2 item: 4 takes (CPU, strict logger, hop2 play env, no video) of EVERY saved checkpoint of the run (seed+250 ... final, every 250 it),
# prefix pk<iteration>, then hop2-pick-2026-10-29.py applies the PRE-REGISTERED pick rule (most strict successes, ties by the median trunk apex, then the earliest) and writes ~/Pollen/pick-hop2.json.
# test hooks (e2e only): PROOF_TAG (OUT suffix), HOP2_RUNDIR (run dir override), HOP2_SEEDIT (seed iteration, default 7000), PICK_N (takes per checkpoint, default 4).
P=/home/witcheer/Pollen; RL=$P/microduck_rl/logs/rsl_rl; TAG=${PROOF_TAG:-2026-10-29}; TASK=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
RUN=${HOP2_RUNDIR:-$(ls -d $RL/duckhop2/*_duckhop2 2>/dev/null | tail -n 1)}; SEEDIT=${HOP2_SEEDIT:-7000}
[ -d "$RUN" ] || { echo "NO_HOP2_RUN (09z22 not run)"; exit 2; }
ITS=$(ls $RUN/model_*.pt | sed 's/.*model_\([0-9]*\)\.pt/\1/' | sort -n | awk -v s=$SEEDIT '$1>s')
[ -n "$ITS" ] || { echo "NO_CHECKPOINTS above $SEEDIT in $RUN"; exit 2; }
echo "pick takes: run $RUN, checkpoints: $(echo $ITS | tr '\n' ' ')"
for N in $ITS; do OUTBASE=$P/clips bash $P/strict-takes-2026-10-29.sh proof-hop2-pick-$TAG pk$N $RUN/model_$N.pt ${PICK_N:-4} 6 $TASK; done
python3 $P/hop2-pick-2026-10-29.py $P/clips/proof-hop2-pick-$TAG $P/pick-hop2${PROOF_TAG:+-$PROOF_TAG}.json $ITS
echo "=== $(date -u +%T) PROOF_HOP2_PICK_END ==="
