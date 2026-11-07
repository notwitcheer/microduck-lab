#!/bin/bash
# 09z29-duck-proof-sockheist.sh: the Arena 6 m SOCK HEIST verdict as a QUEUE ITEM right behind its training item 09z28 (sorts right after it, before every bench item). CPU ONLY: no Donald drain, no GPU work except the publish --dry-run export (a few hundred MiB for seconds).
# EV: same as 09z28 (this is its verdict + the clip): GAIN = a duck that freezes on cue and beats the reference walker by the pre-registered margin -> clip + line 1 "a Hermes Agent trained the duck to freeze on cue: N s for 6 m, inside the giant's 3 cm ring". NO GAIN is said plainly (the duck stays unentered). No rank promise: rank on the live board is REPORTED at scoring time, never a headline.
# MOJO: the freeze clip of OUR pick from the Arena's own recorder: the duck walks, the giant swings its head round, the duck stops dead inside the 3 cm ring, creeps on | funny/absurd + intense | a Hermes Agent trained the duck to freeze on cue (only on GAIN)
# serves: content (Arena entry decision, own yes per entry, + the clip) + the pre-registered local-score verdict.
# behaviour: any run of ~/Pollen/heist-runs-09z28.sh below its target iteration -> exit 3 (stays queued, DRYRUN green; also the case while 09z28 is held by its NOT_BEFORE gate). all runs at target -> (1) heist-proof eval: every saved checkpoint it100..it999 of every run is exported as the real publish does (--dry-run) and scored with `arena score` (x86_64 Linux = the Space's platform, reproduced four board rows to the ms), plus the reference walker re-scored;
# (2) pick per run (5/5 finishes, lowest local score, ties earlier iteration); (3) 25-seed CHECK of each pick (seeds 6-25 are held out from the pick); (4) VERDICT (frozen thresholds in PREREG.md) incl. the rank the HEADLINE pick would take on the live board at that moment; (5) clip of the headline pick (clip-heist-2026-11-05.sh: arena score into a LOCAL store, arena clip headless, 10 s 1920x1080 cut, burnt "simulation only" strip) -> ~/Pollen/clips/x-heist-<tag>/.
# exit 0 only when a VERDICT line exists and the clip was tried. PREREG: vault 60-robotics/microduck/scripts/sockheist-2026-11-05/PREREG.md (sha256s inside).
# test hooks (e2e only): PROOF_TAG, HEIST_RUNS (runs file), HEIST_MIN_IT (skip checkpoints below N, default 100), PROOF_NOCLIP=1.
# nothing here publishes, enters or pushes: the Arena entry stays its own operator yes (publish --enter --code-url on the FIRST entry; push branches to the notwitcheer fork before it).
set -uo pipefail
NL_TAG=heistproof
MANIFEST=/home/witcheer/heistproof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen; A=$P/arena/heist
TAG=${PROOF_TAG:-2026-11-07}
RUNSFILE=${HEIST_RUNS:-$P/heist-runs-09z28.sh}
SCORE=$A/proof-heist-score-$TAG.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z28 proof, tag $TAG, runs $RUNSFILE"
nl_check_path $RUNSFILE $P/heist-proof-2026-11-05.py $P/clip-heist-2026-11-05.sh $A/microduck-challenges/.venv/bin/arena $A/microduck-challenges/.venv/bin/publish $A/microduck-challenges/src/microduck_challenges/sock_heist_6m/walker.onnx $P/arena/bin/ffmpeg $P/arena/libs/root/usr/lib/x86_64-linux-gnu/libasound.so.2 /usr/bin/python3
nl_check_disk 120
. $RUNSFILE
PENDING=0; NR=0
for spec in "${RUNS[@]}"; do
  IFS='|' read -r NAME WT SEED TGT RENVS <<<"$spec"; NR=$((NR+1))
  IT=$(ls $A/$WT/logs/rsl_rl/sock_heist_6m/*_$NAME/model_*.pt 2>/dev/null | sed -n 's/.*model_\([0-9]*\)\.pt/\1/p' | sort -n | tail -n 1); IT=${IT:-0}
  if [ "$IT" -ge $((TGT-1)) ]; then nl_ok "run $NAME at $IT (target $TGT)"; else nl_say "  run $NAME at $IT of $TGT: the training item has not finished"; PENDING=1; fi
done
if [ -s "$SCORE" ] && grep -q '^VERDICT:' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init eval pick check verdict clip; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ "$PENDING" = 0 ] || { nl_say "09z28 not finished, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1800 ] || { nl_say "under 30 min left in the block, not starting (resumable)"; exit 3; }
S=/usr/bin/python3; H=$P/heist-proof-2026-11-05.py
export HEIST_MIN_IT=${HEIST_MIN_IT:-100}
nl_say "=== eval: export + local Arena score of every saved checkpoint >= it$HEIST_MIN_IT of $NR runs (CPU, cap $((left/60)) min) ==="
t0=$(date +%s)
timeout --kill-after=60 $(( left > 600 ? left - 600 : 600 )) $S $H eval $RUNSFILE $TAG > $A/proof-heist-eval-$TAG.log 2>&1; erc=$?
nl_say "eval finished in $(( ($(date +%s)-t0)/60 )) min (rc $erc): $(grep -c '^scored' $A/proof-heist-eval-$TAG.log) scored, $(grep -c 'export failed' $A/proof-heist-eval-$TAG.log) export failures"
nl_mark eval done "$(ls $A/eval | wc -l) files"
$S $H pick $RUNSFILE $TAG > $A/proof-heist-pick-$TAG.log 2>&1; cat $A/proof-heist-pick-$TAG.log; nl_mark pick done "$(grep '^PICK' $A/proof-heist-pick-$TAG.log | tr '\n' ' ')"
nl_say "=== 25-seed CHECK of each pick ==="
timeout --kill-after=60 1500 $S $H check $TAG > $A/proof-heist-check-$TAG.log 2>&1; cat $A/proof-heist-check-$TAG.log; nl_mark check done "picks checked"
$S $H verdict $RUNSFILE $TAG > "$SCORE" 2>&1; cat "$SCORE"
grep -q '^VERDICT:' "$SCORE" && nl_mark verdict done "$(grep '^VERDICT' $SCORE)" || { nl_mark verdict failed "no VERDICT line"; nl_say "no verdict, exit 3"; exit 3; }
# clip of the headline pick (best effort, CPU only, nice 19, ~15 min): never changes the item's result
read -r PN PI <<<"$(sed -n 's/^HEADLINE PICK: \([^ ]*\) it\([0-9]*\) .*/\1 \2/p' "$SCORE" | head -1)"
C=$A/cands/$PN-it$PI.onnx
if [ "${PROOF_NOCLIP:-0}" = "1" ]; then nl_say "clip skipped (PROOF_NOCLIP=1)"
elif [ -n "${PN:-}" ] && [ -f "$C" ]; then
  O=$P/clips/x-heist-$TAG; mkdir -p $O
  if nice -n 19 bash $P/clip-heist-2026-11-05.sh $C "heist-$PN-it$PI" $O > $A/proof-heist-clip-$TAG.log 2>&1; then nl_mark clip done "$O"; nl_say "clips cut: $(grep -E '^(RUN_ID|CLIPFACTS|CUT_DONE)' $A/proof-heist-clip-$TAG.log | tr '\n' ' ')"
  else nl_mark clip failed "see proof-heist-clip-$TAG.log"; nl_say "clip cut FAILED (see $A/proof-heist-clip-$TAG.log), verdict stands"; fi
else nl_say "no headline pick onnx ($C), clip skipped"; fi
nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
