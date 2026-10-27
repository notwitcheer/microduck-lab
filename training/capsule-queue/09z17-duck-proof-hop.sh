#!/bin/bash
# 09z17-duck-proof-hop.sh: the 09z16 (Microduck HOP) verdict as a QUEUE ITEM right behind its training item (prefix 09z17 sorts after 09z16 and before every bench item).
# EV: rule 6 duck milestone: "a 25 cm robot duck learned to jump" before/after clip (the seed never leaves the ground); no post if the takes do not show both feet off the floor.
# behaviour: no 09z16 export (hop-*-it10000.onnx) -> exit 3 (stays queued, resumable; DRYRUN stays green). export present -> two parallel batches proof-hop-{a,b}.sh
# (a: new = duckhop model_10000, 15 takes; b: ref = its seed duckvelbl model_7000 in the same hop play env, 15 takes; zero command, no shoves, 6 s, per-step [hop] log, video),
# then hop-score-2026-10-27.py -> ~/Pollen/proof-hop-score.txt (the pre-registered verdict), then clip-hop-2026-10-27.sh (CPU only, nice 19, best effort).
# exit 0 only when both END markers and a VERDICT line exist (item moves to done/). a batch dir left by an earlier cut run is moved aside (.partial-<epoch>), never deleted.
# test hooks (e2e only): PROOF_TAG, PROOF_N, HOP_CKPT, HOP_REF, PROOF_ONNX_GLOB.
set -uo pipefail
NL_TAG=duckhopproof
MANIFEST=/home/witcheer/duckhopproof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
TAG=${PROOF_TAG:-2026-10-27}
ONNX=$(ls $P/policies-ours/${PROOF_ONNX_GLOB:-hop-*-it10000.onnx} 2>/dev/null | head -1)
SCORE=$P/proof-hop-score${PROOF_TAG:+-$PROOF_TAG}.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z16 proof takes, tag $TAG"
nl_check_path $P/proof-hop-a.sh $P/proof-hop-b.sh $P/proof-hop-common.sh $P/hop-score-2026-10-27.py $P/microduck_rl/hop_play.py /usr/bin/python3
[ -n "$ONNX" ] && nl_ok "09z16 export present: $ONNX" || nl_say "  09z16 export not present yet (training item still to run): the real run will exit 3"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init takes score; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ -n "$ONNX" ] || { nl_say "no 09z16 export yet, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1800 ] || { nl_say "under 30 min left in the block, not starting (resumable)"; exit 3; }
[ "$left" -gt 3600 ] && left=3600
export PROOF_TAG=$TAG
for b in a b; do
  d=$P/clips/proof-hop-$b-$TAG
  if [ -d "$d" ] && ! grep -q "PROOF_HOP_${b^^}_END" $P/proof-hop-$b.out 2>/dev/null; then mv "$d" "$d.partial-$(date +%s)"; [ -f "$d.log" ] && mv "$d.log" "$d.log.partial-$(date +%s)"; nl_say "  moved aside an unfinished batch dir $d"; fi
done
nl_say "=== launching proof-hop-a/b in parallel (cap $((left/60)) min) ==="
t0=$(date +%s)
for b in a b; do
  if grep -q "PROOF_HOP_${b^^}_END" $P/proof-hop-$b.out 2>/dev/null && [ -d $P/clips/proof-hop-$b-$TAG ]; then nl_say "  batch $b already ended, kept"; continue; fi
  ( timeout --kill-after=60 "$left" bash $P/proof-hop-$b.sh > $P/proof-hop-$b.out 2>&1 ) &
done
wait
nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min: $(for b in a b; do printf '%s:%s ' $b $(ls $P/clips/proof-hop-$b-$TAG/*.mp4 2>/dev/null | wc -l); done) mp4, NO_CLIP $(cat $P/proof-hop-?.out | grep -c NO_CLIP)"
/usr/bin/python3 $P/hop-score-2026-10-27.py > "$SCORE" 2>&1; cat "$SCORE"
# best-effort clip cut (CPU only, nice 19): a failure never changes the item's result (rerun by hand: bash ~/Pollen/clip-hop-2026-10-27.sh)
if [ -d $P/clips/proof-hop-a-$TAG ]; then
  if nice -n 19 bash $P/clip-hop-2026-10-27.sh $TAG > $P/clip-hop-cut-$TAG.log 2>&1; then nl_say "clips cut: $(grep -E '^(NEW|REF|CUT_DONE)' $P/clip-hop-cut-$TAG.log | tr '\n' ' ')"; else nl_say "clip cut FAILED (see $P/clip-hop-cut-$TAG.log), rerun by hand"; fi
fi
if grep -q PROOF_HOP_A_END $P/proof-hop-a.out && grep -q PROOF_HOP_B_END $P/proof-hop-b.out && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then
  nl_mark takes done "2 batches ended"; nl_mark score done "$(grep '^VERDICT' $SCORE)"; nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
fi
nl_mark takes failed "batches incomplete or cut (resumable, unfinished dirs are moved aside next run)"; nl_say "DONE incomplete, exit 3"; exit 3
