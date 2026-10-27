#!/bin/bash
# 09z15-duck-proof-dribble.sh: the 09z14 verdict as a QUEUE ITEM right behind its training item (prefix 09z15 sorts after 09z14 and before every bench item).
# EV: same as 09z14 (this is its verdict + clip cut): rule 6 duck milestone clip, "Microduck walks a ball bigger than itself into the goal". serves: content (the clip) + the pre-registered verdict.
# why an item and not only a watcher: the item after the training export may be a bench leg that books most of the card; batches launched after the export would OOM or starve it (09z7 lost its first
# batches that way). here the four batch scripts run inside the drain's own slot on a card nobody else holds.
# behaviour: no 09z14 export (dribble-*-it22000.onnx) -> exit 3 (stays queued, resumable; DRYRUN stays green). export present -> four parallel batches: proof-dr-a.sh 1 8 and proof-dr-a.sh 9 15
# (A: dribble condition, goal at 1.8 m, no shoves, 15 takes per policy, the GAIN condition, one-sided), proof-dr-b.sh (B: dribble with the maker's play shoves, 10 per policy, reported only),
# proof-dr-c.sh (C: stock walk, shoves, 10 per policy, no-loss, two-sided); new = duckdribble model_22000, ref = its seed duckvelstairs model_19000 re-taken. then dr-verdict-2026-10-27.py ->
# ~/Pollen/proof-dr-score.txt. exit 0 only when all END markers and a VERDICT line (GAIN or NO GAIN) exist (item moves to done/). a batch dir left by an earlier cut run is moved aside
# (.partial-<epoch>), never deleted. after scoring the item runs clip-dribble-2026-10-27.sh (best effort, CPU only, nice 19): ~/Pollen/clips/x-dribble-<tag>/dribble-x.mp4 + dribble-x-beforeafter.mp4.
# pre-registered rule: vault log 2026-10-27 (written before any take of the 3,000-iteration policy). test hooks (e2e only): PROOF_TAG, PROOF_N, DR_CKPT, DR_REF, PROOF_ONNX_GLOB.
set -uo pipefail
NL_TAG=duckdrproof
MANIFEST=/home/witcheer/duckdrproof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
TAG=${PROOF_TAG:-$(date +%F)}
ONNX=$(ls $P/policies-ours/${PROOF_ONNX_GLOB:-dribble-*-it22000.onnx} 2>/dev/null | head -1)
SCORE=$P/proof-dr-score${PROOF_TAG:+-$PROOF_TAG}.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z14 proof takes, tag $TAG"
nl_check_path $P/proof-dr-a.sh $P/proof-dr-b.sh $P/proof-dr-c.sh $P/proof-common-dr-2026-10-27.sh $P/dr-score-2026-10-27.py $P/dr-verdict-2026-10-27.py $P/clip-dribble-2026-10-27.sh /usr/bin/python3
[ -n "$ONNX" ] && nl_ok "09z14 export present: $ONNX" || nl_say "  09z14 export not present yet (training item still to run): the real run will exit 3"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init takes score; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ -n "$ONNX" ] || { nl_say "no 09z14 export yet, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 2700 ] || { nl_say "under 45 min left in the block, not starting (resumable)"; exit 3; }
[ "$left" -gt 5400 ] && left=5400
export PROOF_TAG=$TAG
declare -A SCR=( [a1]="proof-dr-a.sh 1 8" [a2]="proof-dr-a.sh 9 15" [b]="proof-dr-b.sh" [c]="proof-dr-c.sh" )
declare -A DIR=( [a1]=a [a2]=a [b]=b [c]=c )
declare -A MK=( [a1]=PROOF_DR_A_END [a2]=PROOF_DR_A_END [b]=PROOF_DR_B_END [c]=PROOF_DR_C_END )
for k in a1 a2 b c; do   # a unfinished batch dir is moved aside once per letter (a1 and a2 share a dir)
  d=$P/clips/proof-dr-${DIR[$k]}-$TAG
  if [ "$k" != a2 ] && [ -d "$d" ] && ! grep -q "${MK[$k]}" $P/proof-dr-$k.out 2>/dev/null; then mv "$d" "$d.partial-$(date +%s)"; [ -f "$d.log" ] && mv "$d.log" "$d.log.partial-$(date +%s)"; nl_say "  moved aside an unfinished batch dir $d"; fi
done
nl_say "=== launching proof-dr a1/a2/b/c in parallel (cap $((left/60)) min) ==="
t0=$(date +%s)
for k in a1 a2 b c; do
  if grep -q "${MK[$k]}" $P/proof-dr-$k.out 2>/dev/null && [ -d $P/clips/proof-dr-${DIR[$k]}-$TAG ]; then nl_say "  batch $k already ended, kept"; continue; fi
  ( timeout --kill-after=60 "$left" bash $P/${SCR[$k]} > $P/proof-dr-$k.out 2>&1 ) &
done
wait
nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min: $(for l in a b c; do printf '%s:%s ' $l $(ls $P/clips/proof-dr-$l-$TAG/*.mp4 2>/dev/null | wc -l); done) mp4, NO_CLIP $(cat $P/proof-dr-?*.out | grep -c NO_CLIP)"
/usr/bin/python3 $P/dr-verdict-2026-10-27.py $TAG > "$SCORE" 2>&1; cat "$SCORE"
# best-effort clip cut (CPU only, nice 19): hero + before/after from batch a; a failure never changes the item's result (rerun by hand: bash ~/Pollen/clip-dribble-2026-10-27.sh)
if [ -d $P/clips/proof-dr-a-$TAG ]; then
  if nice -n 19 bash $P/clip-dribble-2026-10-27.sh $TAG > $P/clip-dribble-cut-$TAG.log 2>&1; then nl_say "clips cut: $(grep -E '^(NEW|REF|CUT_DONE)' $P/clip-dribble-cut-$TAG.log | tr '\n' ' ')"; else nl_say "clip cut FAILED (see $P/clip-dribble-cut-$TAG.log), rerun by hand"; fi
fi
if grep -q PROOF_DR_A_END $P/proof-dr-a1.out && grep -q PROOF_DR_A_END $P/proof-dr-a2.out && grep -q PROOF_DR_B_END $P/proof-dr-b.out && grep -q PROOF_DR_C_END $P/proof-dr-c.out && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then
  nl_mark takes done "4 batches ended"; nl_mark score done "$(grep '^VERDICT' $SCORE)"; nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
fi
nl_mark takes failed "batches incomplete or cut (resumable, unfinished dirs are moved aside next run)"; nl_say "DONE incomplete, exit 3"; exit 3
