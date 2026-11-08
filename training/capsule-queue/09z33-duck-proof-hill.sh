#!/bin/bash
# 09z33-duck-proof-hill.sh: the Arena 1.5 m HILL CLIMB board audit + verdict as a QUEUE ITEM right behind its training item 09z32 (sorts right after it, before every bench item). CPU ONLY: no Donald drain, no GPU work except the publish --dry-run export (a few hundred MiB for seconds).
# idle-queue item (2026-11-08): Arena 1.5 m Hill Climb board audit + shipped-recipe comparator (simulation only)
# serves: content (the board audit post; Arena entry of our pick = its own approval) + the pre-registered verdicts. verdict words: PART B GAIN / HACK CAUGHT / NO GAIN, PART A AUDIT HOLDS / DOES NOT HOLD (PREREG.md).
# behaviour: any run of ~/Pollen/hill-runs-09z32.sh below its target iteration -> exit 3 (stays queued, DRYRUN green). all runs at target -> (1) eval: every saved checkpoint it250..it1499 of every run is exported as the real publish does (--dry-run) and scored with the Arena's own evaluate() + the hack metrics (hill-judge.py), plus the Pollen reference re-scored; (2) pick per run: PICK = lowest score among 5/5 finishers that are CLEAN, ties earlier iteration; RAW = lowest 5/5 whatever the tilt (reported); (3) 25-start CHECK of each PICK, each distinct RAW and the reference; (4) PART A: the live board re-scored (every row's public policy file, 5 official starts + 25-start check at the row's own scored command); (5) VERDICT (frozen thresholds in PREREG.md) incl. the rank on the live board at that moment; (6) clip (clip-hill-2026-11-08.sh: the Arena's own recorder into a LOCAL store, hill_render.py) -> ~/Pollen/clips/x-hill-<tag>/. exit 0 only when a VERDICT line exists and the clip was tried.
# test hooks (e2e only): PROOF_TAG, HILL_RUNS (runs file), HILL_MIN_IT (skip checkpoints below N, default 250), PROOF_NOCLIP=1, HILL_NOFREEZE=1 (skip the frozen-hash guard on an e2e clone), PROOF_NOAUDIT=1 (skip part A).
# nothing here publishes, enters or pushes: the Arena entry stays its own approval (publish --enter --code-url on the FIRST entry; push the branch to the notwitcheer fork before it). board policies are only DOWNLOADED from their public Hub files, scored in-process and never re-published or named on screen.
set -uo pipefail
NL_TAG=hillproof
MANIFEST=/home/witcheer/hillproof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen; A=${HILL_PROOF_DIR:-$P/arena/hill}
TAG=${PROOF_TAG:-2026-11-08}
RUNSFILE=${HILL_RUNS:-$P/hill-runs-09z32.sh}
SCORE=$A/proof-hill-score-$TAG.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z32 proof, tag $TAG, runs $RUNSFILE"
nl_check_path $RUNSFILE $P/hill-proof-2026-11-08.py $P/hill-judge.py $P/hill_render.py $P/clip-hill-2026-11-08.sh $P/hill-store-run.py /home/witcheer/Pollen/arena/heist/microduck-challenges/.venv/bin/arena /home/witcheer/Pollen/arena/heist/microduck-challenges/.venv/bin/publish $A/reference/policy.onnx $P/arena/bin/ffmpeg $P/arena/libs/root/usr/lib/x86_64-linux-gnu/libasound.so.2 /usr/bin/python3
# PRE-REGISTRATION GUARD (same file as the training item): a differing hash aborts the PLAN phase
if [ "${HILL_NOFREEZE:-0}" = 1 ]; then nl_say "  HILL_NOFREEZE=1 (e2e clone only): frozen-hash guard skipped"; elif sha256sum --quiet -c ${HILL_FROZEN:-$P/hill-frozen/FROZEN.sha256} >/dev/null 2>&1; then nl_ok "frozen files match FROZEN.sha256 (PREREG.md)"; else nl_fail "a frozen file differs from FROZEN.sha256 (pre-registration broken)"; fi
nl_check_disk 120
. $RUNSFILE
PENDING=0; NR=0
for spec in "${RUNS[@]}"; do
  IFS='|' read -r NAME WT SEED TGT RENVS <<<"$spec"; NR=$((NR+1))
  IT=$(ls $A/$WT/logs/rsl_rl/hill_climb_1m5/*_$NAME/model_*.pt 2>/dev/null | sed -n 's/.*model_\([0-9]*\)\.pt/\1/p' | sort -n | tail -n 1); IT=${IT:-0}
  if [ "$IT" -ge $((TGT-1)) ]; then nl_ok "run $NAME at $IT (target $TGT)"; else nl_say "  run $NAME at $IT of $TGT: the training item has not finished"; PENDING=1; fi
done
if [ -s "$SCORE" ] && grep -q '^VERDICT:' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init eval pick check audit verdict clip; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ "$PENDING" = 0 ] || { nl_say "09z32 not finished, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 2400 ] || { nl_say "under 40 min left in the block, not starting (resumable)"; exit 3; }
S=/usr/bin/python3; H=$P/hill-proof-2026-11-08.py
export HILL_MIN_IT=${HILL_MIN_IT:-250}
nl_say "=== eval: export + Arena score + hack metrics of every saved checkpoint >= it$HILL_MIN_IT of $NR runs (CPU, cap $((left/60)) min) ==="
t0=$(date +%s)
timeout --kill-after=60 $(( left > 900 ? left - 900 : 900 )) $S $H eval $RUNSFILE $TAG > $A/proof-hill-eval-$TAG.log 2>&1; erc=$?
nl_say "eval finished in $(( ($(date +%s)-t0)/60 )) min (rc $erc): $(grep -c '^scored' $A/proof-hill-eval-$TAG.log) scored, $(grep -c 'export failed' $A/proof-hill-eval-$TAG.log) export failures"
nl_mark eval done "$(ls $A/eval | wc -l) files"
$S $H pick $RUNSFILE $TAG > $A/proof-hill-pick-$TAG.log 2>&1; cat $A/proof-hill-pick-$TAG.log; nl_mark pick done "$(grep -E '^(PICK|RAW)' $A/proof-hill-pick-$TAG.log | tr '\n' ' ')"
nl_say "=== 25-seed CHECK of each pick, each raw best and the reference ==="
timeout --kill-after=60 1800 $S $H check $TAG > $A/proof-hill-check-$TAG.log 2>&1; cat $A/proof-hill-check-$TAG.log; nl_mark check done "picks checked"
if [ "${PROOF_NOAUDIT:-0}" = "1" ]; then nl_say "part A skipped (PROOF_NOAUDIT=1)"; nl_mark audit done "skipped (e2e)"; else
nl_say "=== PART A: the live board re-scored (download every public policy file, 5 official starts + 25-start check at the row's own command; CPU) ==="
timeout --kill-after=60 2400 $S $H audit $TAG > $A/proof-hill-audit-$TAG.log 2>&1; arc=$?; cat $A/proof-hill-audit-$TAG.log | tail -n 3
[ -s $A/audit/rows-$TAG.json ] && nl_mark audit done "$(tail -n 1 $A/proof-hill-audit-$TAG.log)" || { nl_mark audit failed "no rows file (rc $arc)"; nl_say "audit FAILED (rc $arc), verdict continues without it"; }
fi
$S $H verdict $RUNSFILE $TAG > "$SCORE" 2>&1; cat "$SCORE"
grep -q '^VERDICT:' "$SCORE" && nl_mark verdict done "$(grep '^VERDICT' $SCORE)" || { nl_mark verdict failed "no VERDICT line"; nl_say "no verdict, exit 3"; exit 3; }
# clip of the verdict's shown policy (best effort, CPU only, nice 19, ~15 min): never changes the item's result
FACTS=$A/facts-$TAG.json; O=$P/clips/x-hill-$TAG; mkdir -p $O
if [ "${PROOF_NOCLIP:-0}" = "1" ]; then nl_say "clip skipped (PROOF_NOCLIP=1)"
elif [ -f "$FACTS" ]; then
  if nice -n 19 bash $P/clip-hill-2026-11-08.sh $FACTS $O > $A/proof-hill-clip-$TAG.log 2>&1; then nl_mark clip done "$O"; nl_say "clip cut: $(grep -E '^(RUN_ID|CUT_DONE)' $A/proof-hill-clip-$TAG.log | tr '\n' ' ')"
  else nl_mark clip failed "see proof-hill-clip-$TAG.log"; nl_say "clip cut FAILED (see $A/proof-hill-clip-$TAG.log), verdict stands"; fi
else nl_say "no facts file ($FACTS), clip skipped"; fi
nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
