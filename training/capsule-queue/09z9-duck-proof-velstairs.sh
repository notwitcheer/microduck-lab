#!/bin/bash
# 09z9-duck-proof-velstairs.sh: the 09z8 verdict as a QUEUE ITEM right behind its training item (prefix 09z9 sorts after 09z8 and before every bench item).
# why an item and not only a watcher: the weekend drain re-globs the queue the moment 09z8 exits and starts 67c (a 29 GB llama-server leg that holds the
# card for hours), so batches launched after the export would either OOM or starve the bench leg (09z7 lost its first batches that way, proof-z7-*.out.oom).
# here the batches run inside the drain's own slot, on a card nobody else holds, in the ~25 min between the 09z8 export and the next bench item.
# behaviour: no 09z8 export (velstairs-*-it19000.onnx) -> exit 3 (stays queued, resumable; DRYRUN stays green). export present -> three parallel batches
# proof-z8-{a,b,c}.sh (15 takes per policy per condition, z8 vs walk-mixslope; a = stairs GAIN condition one-sided, b flat + c MixSlope no-loss two-sided),
# then z8-score-2026-10-23.py -> ~/Pollen/proof-z8-score.txt. exit 0 only when all three END markers and a VERDICT line exist (item moves to done/).
# a batch dir left by an earlier cut run is moved aside (.partial-<epoch>), never deleted. the watcher wduckz8 (liveness line, ~/Pollen/wduck-z8.alive) is the
# backstop when the drain is not running (it launches the same batches itself, only with VRAM room, after a 20 min grace).
# test hooks (e2e only): PROOF_TAG, PROOF_N, Z8_CKPT (see proof-z8-a.sh), PROOF_ONNX_GLOB.
set -uo pipefail
NL_TAG=duckz8proof
MANIFEST=/home/witcheer/duckz8proof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
TAG=${PROOF_TAG:-2026-10-23}
ONNX=$(ls $P/policies-ours/${PROOF_ONNX_GLOB:-velstairs-*-it19000.onnx} 2>/dev/null | head -1)
SCORE=$P/proof-z8-score${PROOF_TAG:+-$PROOF_TAG}.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z8 proof takes, tag $TAG"
nl_check_path $P/proof-z8-a.sh $P/proof-z8-b.sh $P/proof-z8-c.sh $P/proof-common.sh $P/z8-score-2026-10-23.py /usr/bin/python3
[ -n "$ONNX" ] && nl_ok "09z8 export present: $ONNX" || nl_say "  09z8 export not present yet (training item still to run): the real run will exit 3"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init takes score; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ -n "$ONNX" ] || { nl_say "no 09z8 export yet, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 2400 ] || { nl_say "under 40 min left in the block, not starting (resumable)"; exit 3; }
[ "$left" -gt 5400 ] && left=5400
export PROOF_TAG=$TAG
for b in a b c; do
  d=$P/clips/proof-z8-$b-$TAG
  if [ -d "$d" ] && ! grep -q "PROOF_Z8_${b^^}_END" $P/proof-z8-$b.out 2>/dev/null; then mv "$d" "$d.partial-$(date +%s)"; [ -f "$d.log" ] && mv "$d.log" "$d.log.partial-$(date +%s)"; nl_say "  moved aside an unfinished batch dir $d"; fi
done
nl_say "=== launching proof-z8-a/b/c in parallel (cap $((left/60)) min) ==="
t0=$(date +%s)
for b in a b c; do
  if grep -q "PROOF_Z8_${b^^}_END" $P/proof-z8-$b.out 2>/dev/null && [ -d $P/clips/proof-z8-$b-$TAG ]; then nl_say "  batch $b already ended, kept"; continue; fi
  ( timeout --kill-after=60 "$left" bash $P/proof-z8-$b.sh > $P/proof-z8-$b.out 2>&1 ) &
done
wait
nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min: $(for b in a b c; do printf '%s:%s ' $b $(ls $P/clips/proof-z8-$b-$TAG/*.mp4 2>/dev/null | wc -l); done) mp4, NO_CLIP $(cat $P/proof-z8-?.out | grep -c NO_CLIP)"
/usr/bin/python3 $P/z8-score-2026-10-23.py > "$SCORE" 2>&1; cat "$SCORE"
if grep -q PROOF_Z8_A_END $P/proof-z8-a.out && grep -q PROOF_Z8_B_END $P/proof-z8-b.out && grep -q PROOF_Z8_C_END $P/proof-z8-c.out && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then
  nl_mark takes done "3 batches ended"; nl_mark score done "$(grep '^VERDICT' $SCORE)"; nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
fi
nl_mark takes failed "batches incomplete or cut (resumable, unfinished dirs are moved aside next run)"; nl_say "DONE incomplete, exit 3"; exit 3
