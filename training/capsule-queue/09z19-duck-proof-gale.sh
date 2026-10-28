#!/bin/bash
# 09z19-duck-proof-gale.sh: the 09z18 (gale) verdict as a QUEUE ITEM right behind its training item (prefix 09z19 sorts after 09z18 and before every bench item).
# EV: same as 09z18 (this is its verdict + clip cut): "a 25 cm robot duck learned to walk into a gale that knocks the untrained one flat", before/after clip with a live wind meter (only on GAIN). serves: content (the clip) + the pre-registered verdict.
# why an item and not only a watcher: the item after the training export may be a bench leg that books most of the card; batches launched after the export would OOM or starve it (09z7 lost its first batches that way). here the batch scripts run inside the drain's own slot on a card nobody else holds.
# behaviour: no 09z18 export (gale-*-it10000.onnx) -> exit 3 (stays queued, resumable; DRYRUN stays green). export present -> four parallel batches: proof-gm-batch-2026-10-28.sh gale a 1 8 and gale a 9 15 (A: the GAIN condition, 15 takes per policy, video),
# gale b (B: reported only, 10 per policy), gale c (C: stock walk + shoves, Earth, 10 per policy, no-loss, two-sided); new = duck gale model_10000, ref = its seed duckvelbl model_7000 (walk-flat v2) re-taken in the same env. then gm-verdict-2026-10-28.py gale -> ~/Pollen/proof-gale-score.txt.
# exit 0 only when all END markers and a VERDICT line (GAIN or NO GAIN) exist (item moves to done/). a batch dir left by an earlier cut run is moved aside (.partial-<epoch>), never deleted. after scoring the item runs clip-gm-2026-10-28.sh (best effort, CPU only, nice 19):
# ~/Pollen/clips/x-gale-<tag>/gale-x.mp4 always, gale-x-beforeafter.mp4 ONLY on a GAIN verdict (picker rule: never a before/after on a NO GAIN). needs >= 25 min left in the block, else exit 3 (resumable).
# pre-registered rule: vault log 2026-10-28 and the 09z18 header (written before any take of the 3,000-iteration policy). test hooks (e2e only): PROOF_TAG, PROOF_N, GM_CKPT, GM_REF, PROOF_ONNX_GLOB, GM_DEVICE.
set -uo pipefail
NL_TAG=duckgaleproof
MANIFEST=/home/witcheer/duckgaleproof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
TAG=${PROOF_TAG:-2026-10-28}
ONNX=$(ls $P/policies-ours/${PROOF_ONNX_GLOB:-gale-*-it10000.onnx} 2>/dev/null | head -1)
SCORE=$P/proof-gale-score${PROOF_TAG:+-$PROOF_TAG}.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z18 proof takes, tag $TAG"
nl_check_path $P/proof-gm-batch-2026-10-28.sh $P/proof-gm-common-2026-10-28.sh $P/gm-score-2026-10-28.py $P/gm-verdict-2026-10-28.py $P/gm-pick-2026-10-28.py $P/clip-gm-2026-10-28.sh $P/clip-gm-frames-2026-10-28.py $P/microduck_rl/gm_play.py /usr/bin/python3
[ -n "$ONNX" ] && nl_ok "09z18 export present: $ONNX" || nl_say "  09z18 export not present yet (training item still to run): the real run will exit 3"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init takes score; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ -n "$ONNX" ] || { nl_say "no 09z18 export yet, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1500 ] || { nl_say "under 25 min left in the block, not starting (resumable)"; exit 3; }
[ "$left" -gt 2400 ] && left=2400
export PROOF_TAG=$TAG
declare -A SCR=( [a1]="proof-gm-batch-2026-10-28.sh gale a 1 8" [a2]="proof-gm-batch-2026-10-28.sh gale a 9 15" [b]="proof-gm-batch-2026-10-28.sh gale b" [c]="proof-gm-batch-2026-10-28.sh gale c" )
declare -A DIR=( [a1]=a [a2]=a [b]=b [c]=c )
declare -A MK=( [a1]=PROOF_GALE_A_END [a2]=PROOF_GALE_A_END [b]=PROOF_GALE_B_END [c]=PROOF_GALE_C_END )
for k in a1 a2 b c; do   # a unfinished batch dir is moved aside once per letter (a1 and a2 share a dir)
  d=$P/clips/proof-gale-${DIR[$k]}-$TAG
  if [ "$k" != a2 ] && [ -d "$d" ] && ! grep -q "${MK[$k]}" $P/proof-gale-$k.out 2>/dev/null; then mv "$d" "$d.partial-$(date +%s)"; [ -f "$d.log" ] && mv "$d.log" "$d.log.partial-$(date +%s)"; nl_say "  moved aside an unfinished batch dir $d"; fi
done
nl_say "=== launching proof-gale a1/a2/b/c in parallel (cap $((left/60)) min) ==="
t0=$(date +%s)
for k in a1 a2 b c; do
  if grep -q "${MK[$k]}" $P/proof-gale-$k.out 2>/dev/null && [ -d $P/clips/proof-gale-${DIR[$k]}-$TAG ]; then nl_say "  batch $k already ended, kept"; continue; fi
  ( timeout --kill-after=60 "$left" bash $P/${SCR[$k]} > $P/proof-gale-$k.out 2>&1 ) &
done
wait
nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min: $(for l in a b c; do printf '%s:%s ' $l $(ls $P/clips/proof-gale-$l-$TAG/*.mp4 2>/dev/null | wc -l); done) mp4, NO_CLIP $(cat $P/proof-gale-?*.out | grep -c NO_CLIP)"
/usr/bin/python3 $P/gm-verdict-2026-10-28.py gale $TAG > "$SCORE" 2>&1; cat "$SCORE"
# best-effort clip cut (CPU only, nice 19): hero always, before/after only on GAIN; a failure never changes the item's result (rerun by hand: bash ~/Pollen/clip-gm-2026-10-28.sh gale)
if [ -d $P/clips/proof-gale-a-$TAG ]; then
  if GM_SCORE_SUFFIX=${PROOF_TAG:+-$PROOF_TAG} nice -n 19 bash $P/clip-gm-2026-10-28.sh gale $TAG > $P/clip-gm-gale-cut-$TAG.log 2>&1; then nl_say "clips cut: $(grep -E '^(NEW|REF|CUT_DONE|BEFOREAFTER)' $P/clip-gm-gale-cut-$TAG.log | tr '\n' ' ')"; else nl_say "clip cut FAILED (see $P/clip-gm-gale-cut-$TAG.log), rerun by hand"; fi
fi
if grep -q PROOF_GALE_A_END $P/proof-gale-a1.out && grep -q PROOF_GALE_A_END $P/proof-gale-a2.out && grep -q PROOF_GALE_B_END $P/proof-gale-b.out && grep -q PROOF_GALE_C_END $P/proof-gale-c.out && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then
  nl_mark takes done "4 batches ended"; nl_mark score done "$(grep '^VERDICT' $SCORE)"; nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
fi
nl_mark takes failed "batches incomplete or cut (resumable, unfinished dirs are moved aside next run)"; nl_say "DONE incomplete, exit 3"; exit 3
