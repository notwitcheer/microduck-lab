#!/bin/bash
# duck-lane.sh: weekday alternation between the duck lane and the bench lane (operator, 2026-09-16: "once duck run, once bench run").
# sourced by duck-train-body.sh AFTER nl_gate (real runs only; the drain's own DRYRUN must stay green).
# state file: ld=<hard stop epoch of the last block a duck item trained in>; ly=<hard stop epoch of the last block the duck yielded>.
# rules per weekday block B (= NL_HARD_STOP_EPOCH, one value per block):
#   ld == B  -> a duck item already trained in this block: continue (second duck item, same block)
#   ly == B  -> this block is already yielded: exit 3 (all duck items yield together)
#   ld > ly  -> the previous duck decision was "train", so this block goes to the bench: record ly=B, exit 3
#   else     -> the previous block was a bench block: record ld=B, train
# weekend blocks (nl_hc_in_weekend) and hand runs (no NL_HARD_STOP_EPOCH) never yield. DUCK_LANE_OFF=1 bypasses.
DUCK_LANE_FILE=${DUCK_LANE_FILE:-/home/witcheer/duck-lane-state}
duck_lane_check() {
  [ "${DUCK_LANE_OFF:-0}" = "1" ] && { nl_say "lane: alternation off (DUCK_LANE_OFF=1)"; return 0; }
  [ -n "${NL_HARD_STOP_EPOCH:-}" ] || { nl_say "lane: hand run, no alternation"; return 0; }
  if nl_hc_in_weekend; then nl_say "lane: weekend block, no alternation"; return 0; fi
  local B=$NL_HARD_STOP_EPOCH ld=0 ly=0
  [ -f "$DUCK_LANE_FILE" ] && . "$DUCK_LANE_FILE"
  if [ "$ld" = "$B" ]; then nl_say "lane: duck block (continuing after another duck item)"; return 0; fi
  if [ "$ly" = "$B" ]; then nl_say "lane: block already yielded to the bench, exit 3"; exit 3; fi
  # 2026-10-04: yield only when a bench item is actually queued (any ~/idle-queue/*.sh not prefixed 00 or 09); otherwise the
  # block would idle. the training block is then recorded as a duck block, so the next block goes to the bench as usual.
  if [ "$ld" -gt "$ly" ] && [ -z "$(ls ${DUCK_LANE_QUEUE:-/home/witcheer/idle-queue}/*.sh 2>/dev/null | grep -v -E '/0[09][^/]*$')" ]; then
    echo "ld=$B; ly=$ly" > "$DUCK_LANE_FILE"; nl_say "lane: bench block by alternation but no bench item queued, training instead of idling"; return 0; fi
  if [ "$ld" -gt "$ly" ]; then echo "ld=$ld; ly=$B" > "$DUCK_LANE_FILE"; nl_say "lane: previous block was duck, yielding this block to the bench (exit 3, resumable)"; exit 3; fi
  echo "ld=$B; ly=$ly" > "$DUCK_LANE_FILE"; nl_say "lane: duck block"
}
