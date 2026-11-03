#!/bin/bash
# 09z24-duck-boulder.sh: THE BOULDER CHASE (STAGED in ~/Pollen/queue-staging, NOT enqueued; 2026-11-03, mercury subagent, GPU thread ask "new duck lines items, new way to showcase our duck").
# WHAT: a 50 cm boulder (twice the duck's height) rolls up behind a walking Microduck and speeds up from 0.3 to 0.7 m/s. NO reflex: the duck is flattened (tuning seed 1: 16 of 16 takes touched, 0 of 16 upright at the end). WITH the reflex Hermes Agent wrote
#   from one sentence (a python function, no training, no new task id): it strafes out of the lane and keeps walking. play-only: policy = walk-flat v2 (duckvelbl model_7000, Mjlab-Velocity-Flat-Backlash-MicroDuck, blind to the boulder),
#   boulder = a free body with scripted roll speed (play-only entity in our boulder_play.py, nothing in Pollen's tree or our fork modules is edited).
# MOJO: a 50 cm boulder rolls up behind a walking 25 cm Microduck, flattens it, then misses it by centimetres once Hermes Agent has written the dodge (brackets [a] [b] come from this item's own verdict) | intense + funny + never-seen (Hermes Agent in the loop) | the boulder from Indiana Jones chased a 25 cm robot duck: with no reflex the duck got away in [a] of 48 tries, with the dodge Hermes Agent wrote in [b] of 48. simulation only.
# EV: line 1 above ([a] [b] from this item's own verdict batch, never before it exists). rules: gpu-ev-gate-2026-10-25 section 2 rule 6 (a duck clip doing something crazy, new, original, posted as a milestone) + rule 3 (finding first, never "I ran"/"my") + the mojo rule
#   (intense/funny/never-seen, Hermes Agent in the loop). comparables (fxtwitter, gpu-ev-gate section 1 and the road-to-cup readbacks): duck single-level median 1,986 (n16); Hermes drives the duck 3,791; open-source sim 4,343; walk-mixslope 4,329; road-to-cup day 1/2/3/4/5 =
#   2,363 / 2,497 / 2,016 / 2,786 / 1,432 (fxtwitter 2026-11-03, days 4-5 under 48 h old). projected bracket 3-6k, UNVERIFIED: it is the first duck clip that is a stunt with a visible loser and a visible fix, and the first where Hermes Agent writes the robot's behaviour as code and iterates on a take report.
#   X only if the verdict is GAIN AND the beforeafter plan clip reads (2 stills vision-read + one phone-size look); NO GAIN = hero take only, TG + repo line.
# serves: content (a Hermes-driven showcase + a stunt) + the pre-registered verdict. card minutes: 0 GPU (CPU physics and CPU EGL renders; the 5090 idles). block minutes: ~20-25 of one HC block (batches 3-4 min, renders 5-8 min, cut 1 min).
# LANE: a duck item (sources duck-lane.sh like the training body): previous weekday decision train (ld > ly) -> it yields the first weekday block it sees (records ly, exit 3, seconds) and RUNS FIRST in the next one. state at staging: ld=1793376600 (Fri 10-30 17:10 CET), ly=1793337000 (Fri 10-30 06:10 CET).
#   enqueued BEFORE Tue 11-03 14:10: it yields Tue 14:10 (item 79 bench runs untouched), runs Wed 11-04 01:10 CET. enqueued after Tue 14:10 and before Wed 01:10: Wed 01:10 yields, it runs Wed 14:10 CET. weekend blocks never yield.
#
# PRE-REGISTERED (2026-11-03, written before any item take; seeds 11-13 and 101+ never used while tuning). success of ONE take = the boulder never touched ANY duck collision geom (ball-vs-robot contact in the last substep OR clearance < 0 to the trunk) AND tilt stayed <= 60 deg AND
#   median trunk z (after the 0.5 s settle) >= 0.9 x Z_STAND AND <= 10% of steps under 0.8 x Z_STAND (Z_STAND = 116.1 mm = the seed's CPU stand height from the 2026-10-29 hop diagnostics; this item's control batch re-checks it and must give 16/16 tall) AND the boulder rolled past (x > duck x + 0.3 m).
#   VERDICT GAIN iff B (Hermes reflex) >= 40 of 48 AND A (no reflex) <= 8 of 48 AND one-sided Fisher p < 0.001 AND control 16/16 tall; otherwise NO GAIN. A, B = seeds 11, 12, 13 x 16 CPU takes each. a take counts once; every batch log is kept.
#   REFLEX UNDER TEST = ~/Pollen/boulder-item/reflex_hermes.py (md5 dcea57f6 = hermes2/attempt-2.py, written by Hermes Agent v0.22.6 on mercury, session local-319af8bba433..., 2 attempts: attempt 1 12/16, attempt 2 16/16 on tuning seed 1; it limits itself to vy <= 0.3 m/s, the policy's trained lateral range).
#   not claimed: that a real duck can strafe like this (the lateral command is inside the trained range, the achieved sideways speed ~0.1-0.15 m/s, the boulder is a scripted unstoppable roller); that the policy "sees" the boulder (it is blind, the reflex reads the boulder's position from the sim state, as a Hermes-written state-feed controller would).
#   KNOWN CAVEAT (seen in the stills): the duck's collision hulls are group-3 meshes (contype 2), the boulder is built with conaffinity 3 to hit them; a FLATTENED duck's shell sinks through the floor (visual-only meshes), so the 'before' take reads as the duck vanishing under the boulder with only the orange feet left (feet seen in the stills).
#
# CLIP PLAN (in the item, not rescued after): boulder-clip-2026-11-03.sh renders 6 Hermes takes + 3 no-reflex takes as 1-env runs, each from TWO cameras of the same run (low front-left + a plan view with the lane stripes), picks the hero by the rule in boulder-pick-2026-11-03.py (clean take with the SMALLEST clearance >= 4 cm = a visible near miss)
#   and the 'before' (the no-reflex take with the largest tilt = flattened). outputs ~/Pollen/boulder-item/run-<tag>/clips/: boulder-x-plan.mp4 + boulder-x-low.mp4 (hero, always), boulder-x-beforeafter.mp4 (plan view: flattened take then hero, ONLY on GAIN). burnt HUD: timer, live 'BOULDER x.xx M BEHIND' / PASSED / HIT, SIMULATION ONLY pill, caption
#   'the dodge was written by Hermes Agent' / 'no reflex: the same duck, the same boulder'. HUD leak read (paths, hostnames) is a vision step at readout. fixed shared camera for the pair (same --cam2 on both). edit treatment (kicker, title band, speed tag) on mercury afterwards.
#   what the stills say so far (2026-11-03, tuning takes, vision-read, sceptical): the plan view reads as an overtaking near miss with no contact; the low camera is ambiguous about depth (the boulder overlaps the duck on screen); the dodge itself is subtle in stills (a steady 0.2-0.4 m drift away from the lane), so the before/after contrast carries the story. UNVERIFIED: motion, phone size.
set -uo pipefail
NL_TAG=duckboulder
MANIFEST=/home/witcheer/duckboulder-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
I=$P/boulder-item
TAG=${BOULDER_TAG:-2026-11-03}
OUT=$I/run-$TAG
SCORE=$I/boulder-score-$TAG.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z24 boulder chase, tag $TAG, out $OUT"
nl_check_path $P/microduck_rl/boulder_play.py $I/reflex_hermes.py $I/boulder-batch-2026-11-03.sh $I/boulder-clip-2026-11-03.sh $I/boulder-verdict-2026-11-03.py $I/boulder-pick-2026-11-03.py $P/duck-lane.sh /usr/bin/python3
nl_check_path $P/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
# the reflex under test is frozen by md5 (pre-registration): a different file refuses to run
M=$(md5sum $I/reflex_hermes.py 2>/dev/null | cut -c1-8)
[ "$M" = "dcea57f6" ] && nl_ok "reflex_hermes.py md5 $M (pre-registered)" || nl_fail "reflex_hermes.py md5 is '$M', pre-registered dcea57f6"
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init takes verdict clips; fi
nl_gate
. $P/duck-lane.sh; duck_lane_check   # weekday duck/bench alternation: exits 3 on a bench block (no card is used, but the lane rule is the operator's)
if [ "$ALREADY" = 1 ] && ls $OUT/clips/boulder-x-plan.mp4 >/dev/null 2>&1; then nl_say "nothing to run, item complete"; exit 0; fi
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1800 ] || { nl_say "under 30 min left in the block, not starting (resumable)"; exit 3; }
mkdir -p $OUT
t0=$(date +%s)
if [ "$ALREADY" = 0 ]; then
  nl_say "=== takes: control + A x3 + B x3 (16 CPU takes each, parallel) ==="
  for s in 11 12 13; do
    for k in A B; do
      if grep -q "BATCH_END $k $s rc=0" $OUT/$k-s$s.log 2>/dev/null; then nl_say "  $k seed $s already ended, kept"; continue; fi
      [ -f $OUT/$k-s$s.log ] && mv $OUT/$k-s$s.log $OUT/$k-s$s.log.partial-$(date +%s)
      ( timeout --kill-after=30 900 bash $I/boulder-batch-2026-11-03.sh $k $s $OUT ) &
    done
  done
  if ! grep -q "BATCH_END C 0 rc=0" $OUT/C.log 2>/dev/null; then ( timeout --kill-after=30 900 bash $I/boulder-batch-2026-11-03.sh C 0 $OUT ) & fi
  wait
  nl_say "batches finished in $(( ($(date +%s)-t0)/60 )) min: $(grep -l 'BATCH_END' $OUT/*.log | wc -l) logs"
  /usr/bin/python3 $I/boulder-verdict-2026-11-03.py $OUT > "$SCORE" 2>&1; cat "$SCORE"
  nl_mark takes done "A, B, C batches ended"; nl_mark verdict done "$(grep '^VERDICT' $SCORE)"
fi
# best-effort clip cut (CPU only, nice 19): hero always, before/after only on GAIN; a failure never changes the item's result (rerun by hand: bash $I/boulder-clip-2026-11-03.sh $OUT $SCORE $TAG)
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
if [ "$left" -gt 900 ]; then
  if timeout --kill-after=30 $(( left > 1500 ? 1500 : left )) nice -n 19 bash $I/boulder-clip-2026-11-03.sh $OUT $SCORE $TAG > $OUT/clip-cut.log 2>&1; then nl_say "clips cut: $(grep -E '^(HERO|BEFORE|BEFOREAFTER|CUT_DONE)' $OUT/clip-cut.log | tr '\n' ' ')"; nl_mark clips done "cut"; else nl_say "clip cut FAILED or cut short (see $OUT/clip-cut.log), rerun by hand"; fi
else
  nl_say "under 15 min left, clip cut skipped (rerun by hand: bash $I/boulder-clip-2026-11-03.sh $OUT $SCORE $TAG)"
fi
if [ -s "$SCORE" ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' "$SCORE" && ls $OUT/clips/boulder-x-plan.mp4 >/dev/null 2>&1; then nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0; fi
nl_say "DONE incomplete, exit 3 (resumable: finished batches are kept)"; exit 3
