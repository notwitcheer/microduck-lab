#!/bin/bash
# 09z13-duck-proof-bigaim.sh: the 09z12 verdict as a QUEUE ITEM right behind its training item (prefix 09z13 sorts after 09z12 and before every bench item).
# why an item and not only a watcher: the next queue item after the training export is a bench leg (69-hermes-kv-v3, vLLM-style legs that book most of the card), and
# batches launched after the export would OOM or starve it (09z7 lost its first batches that way). here the three batches run inside the drain's own slot, on a card
# nobody else holds, in the ~15-20 min between the 09z12 export and the next bench item.
# behaviour: no 09z12 export (bigaim-*-it19000.onnx) -> exit 3 (stays queued, resumable; DRYRUN stays green). export present -> three parallel batches
# proof-ba-{a,b,c}.sh (a: giant ball + goal, no shoves, 15 takes per policy, GAIN condition one-sided; b: giant ball + play shoves, 10 per policy, reported;
# c: stock small-ball task, 10 per policy, no-loss two-sided; new = duckbigaim model_19000, ref = duckbigkick model_16000 = its seed, re-taken), then ba-score-2026-10-26.py ->
# ~/Pollen/proof-ba-score.txt. exit 0 only when all three END markers and a VERDICT line exist (item moves to done/).
# a batch dir left by an earlier cut run is moved aside (.partial-<epoch>), never deleted. after scoring the item also runs clip-bigaim-2026-10-26.sh (best effort, CPU only,
# nice 19): ~/Pollen/clips/x-bigaim-<tag>/bigaim-x.mp4 + bigaim-x-beforeafter.mp4 from the batch-a takes (rerun by hand with the same script).
# test hooks (e2e only): PROOF_TAG, PROOF_N, BA_CKPT, BA_REF (see proof-ba-a.sh), PROOF_ONNX_GLOB.
set -uo pipefail
NL_TAG=duckbaproof
MANIFEST=/home/witcheer/duckbaproof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
TAG=${PROOF_TAG:-2026-10-26}
ONNX=$(ls $P/policies-ours/${PROOF_ONNX_GLOB:-bigaim-*-it19000.onnx} 2>/dev/null | head -1)
SCORE=$P/proof-ba-score${PROOF_TAG:+-$PROOF_TAG}.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z12 proof takes, tag $TAG"
nl_check_path $P/proof-ba-a.sh $P/proof-ba-b.sh $P/proof-ba-c.sh $P/proof-common.sh $P/ba-score-2026-10-26.py /usr/bin/python3
[ -n "$ONNX" ] && nl_ok "09z12 export present: $ONNX" || nl_say "  09z12 export not present yet (training item still to run): the real run will exit 3"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init takes score; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ -n "$ONNX" ] || { nl_say "no 09z12 export yet, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 2400 ] || { nl_say "under 40 min left in the block, not starting (resumable)"; exit 3; }
[ "$left" -gt 5400 ] && left=5400
export PROOF_TAG=$TAG
for b in a b c; do
  d=$P/clips/proof-ba-$b-$TAG
  if [ -d "$d" ] && ! grep -q "PROOF_BA_${b^^}_END" $P/proof-ba-$b.out 2>/dev/null; then mv "$d" "$d.partial-$(date +%s)"; [ -f "$d.log" ] && mv "$d.log" "$d.log.partial-$(date +%s)"; nl_say "  moved aside an unfinished batch dir $d"; fi
done
nl_say "=== launching proof-ba-a/b/c in parallel (cap $((left/60)) min) ==="
t0=$(date +%s)
for b in a b c; do
  if grep -q "PROOF_BA_${b^^}_END" $P/proof-ba-$b.out 2>/dev/null && [ -d $P/clips/proof-ba-$b-$TAG ]; then nl_say "  batch $b already ended, kept"; continue; fi
  ( timeout --kill-after=60 "$left" bash $P/proof-ba-$b.sh > $P/proof-ba-$b.out 2>&1 ) &
done
wait
nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min: $(for b in a b c; do printf '%s:%s ' $b $(ls $P/clips/proof-ba-$b-$TAG/*.mp4 2>/dev/null | wc -l); done) mp4, NO_CLIP $(cat $P/proof-ba-?.out | grep -c NO_CLIP)"
/usr/bin/python3 $P/ba-score-2026-10-26.py > "$SCORE" 2>&1; cat "$SCORE"
# best-effort clip cut (CPU only, nice 19): hero + before/after from batch a; a failure never changes the item's result (rerun by hand: bash ~/Pollen/clip-bigaim-2026-10-26.sh)
if [ -d $P/clips/proof-ba-a-$TAG ]; then
  if nice -n 19 bash $P/clip-bigaim-2026-10-26.sh $TAG > $P/clip-bigaim-cut-$TAG.log 2>&1; then nl_say "clips cut: $(grep -E '^(NEW|REF|CUT_DONE)' $P/clip-bigaim-cut-$TAG.log | tr '\n' ' ')"; else nl_say "clip cut FAILED (see $P/clip-bigaim-cut-$TAG.log), rerun by hand"; fi
fi
if grep -q PROOF_BA_A_END $P/proof-ba-a.out && grep -q PROOF_BA_B_END $P/proof-ba-b.out && grep -q PROOF_BA_C_END $P/proof-ba-c.out && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then
  nl_mark takes done "3 batches ended"; nl_mark score done "$(grep '^VERDICT' $SCORE)"; nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
fi
nl_mark takes failed "batches incomplete or cut (resumable, unfinished dirs are moved aside next run)"; nl_say "DONE incomplete, exit 3"; exit 3
