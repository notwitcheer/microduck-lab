#!/bin/bash
# proof-hop2-a (2026-10-29, staged with 09z22): the NEW policy = the PICKED checkpoint (~/Pollen/pick-hop2.json), 15 NEW takes (CPU, strict logger, hop2 play env, zero command, no shoves, 6 s, video on; fixed world camera).
# PRE-REGISTERED VERDICT (written into the vault log.md 2026-10-29 BEFORE any hop2 training): SUCCESS per take = >= 3 strict flights (no robot body touches the floor for >= 4 consecutive steps = 80 ms AND the trunk is >= Z_STAND + 10 mm on every step of the run)
# AND no fall AND upright at the end AND tall trunk at the end (median trunk z over the last 0.5 s >= 0.9 x Z_STAND); Z_STAND = 116.1 mm. 15 takes new (the pick) vs 15 takes seed (batch b), one-sided exact Fisher p < 0.05 = GAIN.
# test hooks: PROOF_TAG, PROOF_N, HOP2_RUNDIR, HOP2_PICKJSON.
P=/home/witcheer/Pollen; RL=$P/microduck_rl/logs/rsl_rl; TAG=${PROOF_TAG:-2026-10-29}; TASK=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
RUN=${HOP2_RUNDIR:-$(ls -d $RL/duckhop2/*_duckhop2 2>/dev/null | tail -n 1)}; PJ=${HOP2_PICKJSON:-$P/pick-hop2${PROOF_TAG:+-$PROOF_TAG}.json}
PICK=$(python3 -c "import json;print(json.load(open('$PJ'))['pick'])" 2>/dev/null); [ -n "$PICK" ] || { echo "NO_PICK ($PJ)"; exit 2; }
CK=$RUN/model_$PICK.pt; [ -f "$CK" ] || { echo "NO_PICKED_CHECKPOINT $CK"; exit 2; }
echo "hop2 pick: iteration $PICK = $CK"
STRICT_VIDEO=1 OUTBASE=$P/clips bash $P/strict-takes-2026-10-29.sh proof-hop2-a-$TAG hnew $CK ${PROOF_N:-15} 3 $TASK
echo "=== $(date -u +%T) PROOF_HOP2_A_END ==="
