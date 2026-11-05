#!/bin/bash
# 09z23-duck-proof-hop2.sh: the 09z22 (Microduck HOP v2) verdict as a QUEUE ITEM right behind its training item (prefix 09z23 sorts after 09z22, after 09z21 moon and before every bench item).
# EV: rule 6 duck milestone, only if a strict whole-body flight exists: "a 25 cm robot duck learned to jump: all of it leaves the floor, N mm up" (honest about the small apex; sim only). no GAIN = no before/after clip; the hero alone, and no post unless the strict log of the picked take supports every number.
# MOJO: before/after of the 09z22 pick against the walk it started from, same play env and camera | never-seen | a 25 cm robot duck learned to jump: all of it leaves the floor (only on GAIN)
# serves: content (rule 6 milestone clip, road-to-the-cup fallback) + a sim finding on the v1 reward hack (head-on-the-floor "flights").
# behaviour: no 09z22 export (hop2-*-it10000.onnx) -> exit 3 (stays queued, resumable; DRYRUN stays green). export present -> (1) CPU pick takes: 4 takes of EVERY saved checkpoint (proof-hop2-pick.sh), the PRE-REGISTERED pick rule picks one (hop2-pick-2026-10-29.py);
# (2) 15 takes of the pick (batch a) and 15 takes of its seed (batch b) in the hop2 play env, in parallel, CPU only (strict per-body floor-contact logger, video); (3) hop2-score-2026-10-29.py --ab -> ~/Pollen/proof-hop2-score.txt (the verdict);
# (4) clip-hop2-2026-10-29.sh (CPU only, nice 19, best effort); (5) ONNX of the pick (CPU export, best effort). no GPU is used: the takes are CPU takes. exit 0 only when both END markers and a VERDICT line exist (moves to done/).
# test hooks (e2e only): PROOF_TAG, PROOF_N, PICK_N, HOP2_RUNDIR, HOP2_SEEDIT, HOP2_REF, PROOF_ONNX_GLOB.
set -uo pipefail
NL_TAG=duckhop2proof
MANIFEST=/home/witcheer/duckhop2proof-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen; RL=$P/microduck_rl
TAG=${PROOF_TAG:-2026-10-29}
ONNX=$(ls $P/policies-ours/${PROOF_ONNX_GLOB:-hop2-2*-it10000.onnx} 2>/dev/null | head -1)
SCORE=$P/proof-hop2-score${PROOF_TAG:+-$PROOF_TAG}.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z22 proof takes, tag $TAG"
nl_check_path $P/proof-hop2-pick.sh $P/proof-hop2-a.sh $P/proof-hop2-b.sh $P/strict-takes-2026-10-29.sh $P/hop2-score-2026-10-29.py $P/hop2-pick-2026-10-29.py $P/hop2-pickclip-2026-10-29.py $P/clip-hop2-2026-10-29.sh $P/hop2-dev/strict_play.py /usr/bin/python3
[ -n "$ONNX" ] && nl_ok "09z22 export present: $ONNX" || nl_say "  09z22 export not present yet (training item still to run): the real run will exit 3"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init pick takes score; fi
nl_gate
[ "$ALREADY" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
[ -n "$ONNX" ] || { nl_say "no 09z22 export yet, exit 3 (resumable)"; exit 3; }
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1800 ] || { nl_say "under 30 min left in the block, not starting (resumable)"; exit 3; }
[ "$left" -gt 3600 ] && left=3600
export PROOF_TAG=$TAG
for d in pick a b; do   # a batch dir left by an earlier cut run is moved aside (.partial-<epoch>), never deleted
  x=$P/clips/proof-hop2-$d-$TAG; U=$(echo $d | tr a-z A-Z)
  if [ -d "$x" ] && ! grep -q "PROOF_HOP2_${U}_END" $P/proof-hop2-$d.out 2>/dev/null; then mv "$x" "$x.partial-$(date +%s)"; [ -f "$x.log" ] && mv "$x.log" "$x.log.partial-$(date +%s)"; nl_say "  moved aside an unfinished batch dir $x"; fi
done
t0=$(date +%s)
if [ -s $P/pick-hop2${PROOF_TAG:+-$PROOF_TAG}.json ] && grep -q PROOF_HOP2_PICK_END $P/proof-hop2-pick.out 2>/dev/null; then nl_say "  pick already made: $(grep -h '^PICK' $P/proof-hop2-pick.out | tail -n 1)"
else
  nl_say "=== pick takes: every saved checkpoint, 4 CPU takes each (cap $((left/60)) min) ==="
  timeout --kill-after=60 "$left" bash $P/proof-hop2-pick.sh > $P/proof-hop2-pick.out 2>&1; cat $P/proof-hop2-pick.out | grep -a "^  it\|^PICK\|NO_"; nl_say "pick: $(grep -a '^PICK' $P/proof-hop2-pick.out | tail -n 1)"
fi
grep -q '^PICK' $P/proof-hop2-pick.out || { nl_mark pick failed "no pick"; nl_say "DONE incomplete (no pick), exit 3"; exit 3; }
nl_mark pick done "$(grep -a '^PICK' $P/proof-hop2-pick.out | tail -n 1)"
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 )); [ "$left" -gt 3600 ] && left=3600
nl_say "=== launching proof-hop2-a/b in parallel (cap $((left/60)) min) ==="
for b in a b; do
  ( timeout --kill-after=60 "$left" bash $P/proof-hop2-$b.sh > $P/proof-hop2-$b.out 2>&1 ) &
done
wait
nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min total: $(for b in a b; do printf '%s:%s ' $b $(ls $P/clips/proof-hop2-$b-$TAG/*.mp4 2>/dev/null | wc -l); done) mp4"
{ grep -a '^PICK' $P/proof-hop2-pick.out | tail -n 1; grep -a '^  it' $P/proof-hop2-pick.out; /usr/bin/python3 $P/hop2-score-2026-10-29.py --ab $P/clips/proof-hop2-a-$TAG hnew $P/clips/proof-hop2-b-$TAG href; } > "$SCORE" 2>&1; cat "$SCORE"
# best-effort clip cut + export of the pick (CPU only): a failure never changes the item's result
if [ -d $P/clips/proof-hop2-a-$TAG ]; then
  if nice -n 19 bash $P/clip-hop2-2026-10-29.sh $TAG > $P/clip-hop2-cut-$TAG.log 2>&1; then nl_say "clips cut: $(grep -E '^(NEW|REF|CUT_DONE|BEFOREAFTER)' $P/clip-hop2-cut-$TAG.log | tr '\n' ' ')"; else nl_say "clip cut FAILED (see $P/clip-hop2-cut-$TAG.log), rerun by hand"; fi
fi
PN=$(python3 -c "import json;print(json.load(open('$P/pick-hop2${PROOF_TAG:+-$PROOF_TAG}.json'))['pick'])" 2>/dev/null)
RUN=${HOP2_RUNDIR:-$(ls -d $RL/logs/rsl_rl/duckhop2/*_duckhop2 2>/dev/null | tail -n 1)}
if [ -n "$PN" ] && [ -f "$RUN/model_$PN.pt" ] && [ ! -s "$P/policies-ours/hop2-pick-$(date +%F)-it$PN.onnx" ]; then
  ( cd $RL && PATH=/home/witcheer/.local/bin:$PATH timeout 600 nice -n 15 uv run scripts/export.py Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck --checkpoint-file $RUN/model_$PN.pt --onnx-file "$P/policies-ours/hop2-pick-$(date +%F)-it$PN.onnx" --device cpu > $P/hop2-pick-export.log 2>&1 ) && nl_say "pick exported: hop2-pick-$(date +%F)-it$PN.onnx" || nl_say "pick export failed (see $P/hop2-pick-export.log), best effort"
fi
if grep -q PROOF_HOP2_A_END $P/proof-hop2-a.out && grep -q PROOF_HOP2_B_END $P/proof-hop2-b.out && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then
  nl_mark takes done "2 batches ended"; nl_mark score done "$(grep '^VERDICT' $SCORE)"; nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0
fi
nl_mark takes failed "batches incomplete or cut (resumable, unfinished dirs are moved aside next run)"; nl_say "DONE incomplete, exit 3"; exit 3
