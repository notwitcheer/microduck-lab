#!/bin/bash
# 09z25-duck-rlgl.sh: RED LIGHT, GREEN LIGHT WITH 456 DUCKS (STAGED in ~/Pollen/queue-staging, then enqueued on the operator's yes; 2026-11-04, mercury subagent, GPU thread ask "new duck lines items, new way to showcase our duck").
# WHAT: 456 Microducks (one per env, a 22-wide grid at 0.45 m) walk toward a chequered finish gate on GREEN and freeze on RED. A duck still moving after the 0.9 s grace is OUT (recoloured red), a live counter
#   "N of 456 still in" drops, the floor and frame flip red. play-only: policy = walk-flat v2 (duckvelbl model_7000, Mjlab-Velocity-Flat-Backlash-MicroDuck, blind to the game), NO training, NO new task id, the card is never used (CPU physics, 8 shards, CPU EGL render).
# MOJO: 456 robot ducks play red light, green light | absurd + meme (the Squid Game number) | 456 Microducks played red light, green light: [n] were still standing at the finish
# EV: line 1 above ([n] = this item's own measured survivor count, never before it exists). rules: gpu-ev-gate-2026-10-25 section 2 rule 6 (a duck clip doing something new, posted as a milestone) + rule 3 (finding first, never "I ran"/"my") + the mojo rule (absurd + meme).
#   comparables (fxtwitter, gpu-ev-gate section 1 and the road-to-cup readbacks): duck single-level median 1,986 (n16); road-to-cup day 1/2/3/4/5 = 2,363 / 2,497 / 2,016 / 2,786 / 1,432 (fxtwitter 2026-11-03, days 4-5 under 48 h old); Hermes drives the duck 3,791; open-source sim 4,343.
#   projected bracket 2-4k, UNVERIFIED: it is a fourth crowd render in two weeks (swarm fatigue is real), so the meme + the finish gate + the live counter carry it, not the count. X only if the stills read at phone size (vision-read + one phone-size look at readout); otherwise TG + repo line.
# serves: content (a crowd game with a number on screen) + the pre-registered verdict. card minutes: 0 GPU (CPU physics and CPU EGL render; the 5090 idles). block minutes: ~25-30 of one HC block (physics ~20 min on 8 shards, render ~1 min, stills 1 min).
# LANE: a duck item (sources duck-lane.sh like the training body): previous weekday decision train (ld > ly) -> it yields the first weekday block it sees (records ly, exit 3, seconds) and RUNS FIRST in the next one. state at staging: ld=1793769000 (Wed 11-04 06:10 CET, the boulder block), ly=1793722200 (Tue 11-03 17:10 CET).
#   enqueued BEFORE Wed 11-04 14:10: it yields Wed 14:10 (the bench item 84-chess-duel runs untouched) and runs Thu 11-05 01:10 CET. enqueued after Wed 14:10 and before Thu 01:10: nothing records ly, Thu 01:10 yields to the bench items still queued (or trains when none is queued), it then runs Thu 14:10 CET. weekend blocks never yield.
#
# PRE-REGISTERED (2026-11-04, written before this item's first run; seed 11 was never used while building the picture, which used the dev seed 1 only). frozen params: grace 0.9 s, thr 0.06 m/s planar trunk speed over 0.1 s, reaction delay lognormal median 0.2 s sigma 0.6 (clip 0.05-1.5 s), walking speed uniform 0.30-0.40 m/s,
#   4 lights of 2 s red / 3 s green after 1 s of green lead-in, 456 envs, spacing 0.55 m in the physics (one duck per env, ducks never touch), heading hold on every duck. a duck is OUT in a red phase when it moves above thr later than the grace after that light turned red, and OUT at once when its tilt passes 60 deg (a fall) in any phase;
#   a SURVIVOR is a duck that was never above thr after the grace in any red phase and never tilted past 60 deg.
#   THE RESULT IS THE MEASURED SURVIVOR COUNT (logged from the physics, the burnt-in final counter must equal it). it is NOT a pass/fail on the duck: the policy needs ~0.5 s to stop (median 0.48-0.57 s at n=64/456 in the 2026-11-03 probes) and the reaction delay is a modelled assumption, so the count is a property of the modelled game, never of a real duck.
#   dev reference (NOT the item's result): seed 1 gave 152 of 456 still in after 4 lights, 2 falls, counter monotone (2026-11-04 dev run); 2 lights gave 241 of 456 on 2026-11-03 with the old grace 0.5/spacing 0.8 set.
#   VERDICT RULE (frozen, rlgl-verdict-2026-11-04.py): RENDER OK iff ALL: merged field n == 456; the merged counter is monotone non-increasing over every frame; the render's own counter is monotone; the burnt-in final counter equals the logged survivors;
#   falls <= 10 of 456; the hero mp4 exists at 1920x1080, 25 fps, 15-30 s. otherwise RENDER FAILED with the reasons (a failed render is rerun by hand from the saved trajectory: bash $I/rlgl-clip-2026-11-04.sh <out> <tag>, never re-simulated to chase a number).
#   a survivor share outside 20-60% is flagged in the score file as a NOTE (not a failure): it would mean the modelled game is too easy or too harsh to be a picture.
#   why this rule (refined before the run, 2026-11-04): the rule suggested was "render succeeds + counter monotone + survivors logged + 0 or few falls"; "few" is fixed at <= 10 of 456 (2%) because 2 falls occurred in the 4-light dev run and the 64-duck probe had 0, and the burnt-in-equals-logged check is added because the lane rule (robotics-lane-ops, batched-sim numbers) says the delivered clip's counter must be the logged value.
#   not claimed: that a real duck stops this fast or reacts like this (reaction delays are drawn from a model, the policy is blind to the light), that a real swarm of 456 ducks could be run at once (one duck per sim env, no duck-to-duck contact), or that the survivors "won" anything (no duck reaches the gate in the dev run beyond a handful: the gate is a goal marker, the count is the result).
#   FROZEN FILES (md5, first 8 hex; the item refuses to run on a different file, RLGL_SKIP_MD5=1 skips the check for a hand rerun only):
#   md5 swarm_rlgl2.py f69c6bd0
#   md5 rlgl_render.py 38b71e94
#   md5 rlgl_merge.py 0da7e34d
#   md5 rlgl-verdict-2026-11-04.py 019ae62d
#   CPU physics is deterministic per seed on this box in the dev reruns of the same trajectory render, but batched-sim numbers are not deterministic across renders on a GPU (lane rule): the clip quotes THIS run's logged survivors and a rerun is never used to chase an earlier number.
#
# CLIP PLAN (in the item, not rescued after): rlgl-clip-2026-11-04.sh renders the hero from the saved trajectory: 1920x1080 16:9, 25 fps, ~24 s (0.3 s lead, 21 s of play, 3 s end card), a title card in the first 1.6 s ("456 ROBOT DUCKS / RED LIGHT, GREEN LIGHT"), a camera behind the field that pulls back from a low shot,
#   a chequered finish gate, a traffic light + GREEN/RED LIGHT word, a red floor + red frame on RED, "N of 456 still in" live, a "= OUT" legend (eliminated ducks are red), a "SIMULATION ONLY" pill, an end card "N SURVIVED / M OUT | 456 STARTED". no paths, usernames or hostnames on screen. outputs ~/Pollen/rlgl-item/run-<tag>/clips/:
#   rlgl-hero.mp4 (+ rlgl-hero-preview.mp4 1280x720 crf 28, + still-1..8.png). X/TG edit treatment (kicker, title band) on mercury afterwards. HUD leak read + phone-size look are a vision step at readout.
#   what the stills said (2026-11-04 dev, 8 vision-read passes, sceptical): the traffic light, state word, counter and end card read at phone width; the red frame and floor make the red light unmistakable; the gate is the clearest object; the first-second title card says what it is.
#   WEAK (said plainly): the ducks are 40-150 px near and ~15-30 px at the back, so they read as small white-and-orange robots, not as ducks (no beak from behind); the far two-thirds of the field is a texture; eliminated red ducks on the dark-red floor are the weakest contrast. UNVERIFIED: motion and phone size, nobody has watched the mp4 on a phone.
set -uo pipefail
NL_TAG=duckrlgl
MANIFEST=/home/witcheer/duckrlgl-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
P=/home/witcheer/Pollen
I=$P/rlgl-item
TAG=${RLGL_TAG:-2026-11-04}
OUT=$I/run-$TAG
SCORE=$I/rlgl-score-$TAG.txt
nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z25 red light green light, tag $TAG, out $OUT"
nl_check_path $P/microduck_rl/swarm_rlgl2.py $I/rlgl_render.py $I/rlgl_merge.py $I/rlgl-physics-2026-11-04.sh $I/rlgl-clip-2026-11-04.sh $I/rlgl-verdict-2026-11-04.py $P/duck-lane.sh /usr/bin/python3
nl_check_path $P/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
# the physics and render scripts are frozen by md5 (pre-registration): a different file refuses to run
for kv in swarm_rlgl2.py:$P/microduck_rl/swarm_rlgl2.py rlgl_render.py:$I/rlgl_render.py rlgl_merge.py:$I/rlgl_merge.py rlgl-verdict-2026-11-04.py:$I/rlgl-verdict-2026-11-04.py; do
  f=${kv%%:*}; path=${kv#*:}; want=$(grep -m1 "^#   md5 $f " "$0" | awk '{print $4}')
  [ -z "${RLGL_SKIP_MD5:-}" ] || continue
  have=$(md5sum "$path" 2>/dev/null | cut -c1-8)
  [ -n "$want" ] && [ "$have" = "$want" ] && nl_ok "$f md5 $have (pre-registered)" || nl_fail "$f md5 is '$have', pre-registered '$want'"
done
if [ -s "$SCORE" ] && grep -q '^VERDICT: RENDER \(OK\|FAILED\)' "$SCORE"; then nl_say "  scored already: $(grep '^VERDICT' $SCORE)"; ALREADY=1; else ALREADY=0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init physics render verdict; fi
nl_gate
. $P/duck-lane.sh; duck_lane_check   # weekday duck/bench alternation: exits 3 on a bench block (no card is used, but the lane rule is the operator's)
if [ "$ALREADY" = 1 ] && grep -q '^VERDICT: RENDER OK' "$SCORE" && ls $OUT/clips/rlgl-hero.mp4 >/dev/null 2>&1; then nl_say "nothing to run, item complete"; exit 0; fi
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1800 ] || { nl_say "under 30 min left in the block, not starting (resumable)"; exit 3; }
mkdir -p $OUT
t0=$(date +%s)
# 1. physics (resumable per shard)
if ! grep -q "PHYSICS_END shards=${RLGL_SHARDS:-8} done=${RLGL_SHARDS:-8}" $OUT/physics.log 2>/dev/null; then
  nl_say "=== physics: ${RLGL_N:-456} ducks, ${RLGL_SHARDS:-8} shards, seed ${RLGL_SEED:-11}, ${RLGL_CYCLES:-4} lights ==="
  RLGL_SHARD_TIMEOUT=$(( left > 2400 ? 2400 : left - 60 )) bash $I/rlgl-physics-2026-11-04.sh $OUT > $OUT/physics.log.new 2>&1
  cat $OUT/physics.log.new >> $OUT/physics.log; rm -f $OUT/physics.log.new
  nl_say "physics finished in $(( ($(date +%s)-t0)/60 )) min: $(tail -n 1 $OUT/physics.log)"
fi
if /usr/bin/python3 $I/rlgl-verdict-2026-11-04.py $OUT physics > $OUT/physics-check.txt 2>&1 && grep -q '^PHYSICS:' $OUT/physics-check.txt; then
  cat $OUT/physics-check.txt | grep -E 'RESULT|PHYSICS' ; nl_mark physics done "$(grep '^PHYSICS' $OUT/physics-check.txt)"
else
  cat $OUT/physics-check.txt; nl_say "DONE incomplete, exit 3 (resumable: finished shards are kept)"; exit 3
fi
# 2. render (CPU, nice 19; ffmpeg always -nostdin </dev/null inside the clip script)
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
if [ "$left" -gt 600 ]; then
  if timeout --kill-after=30 $(( left > 1200 ? 1200 : left )) nice -n 19 bash $I/rlgl-clip-2026-11-04.sh $OUT $TAG > $OUT/clip-cut.log 2>&1 < /dev/null; then nl_say "clips cut: $(grep -E '^(CUT_DONE|\[render\] RESULT)' $OUT/clip-cut.log | tr '\n' ' ')"; nl_mark render done "cut"; else nl_say "clip cut FAILED or cut short (see $OUT/clip-cut.log), rerun by hand: bash $I/rlgl-clip-2026-11-04.sh $OUT $TAG"; fi
else
  nl_say "under 10 min left, render skipped (rerun by hand: bash $I/rlgl-clip-2026-11-04.sh $OUT $TAG)"
fi
# 3. verdict (the pre-registered rule, from the logs and the clip)
/usr/bin/python3 $I/rlgl-verdict-2026-11-04.py $OUT final $TAG > "$SCORE" 2>&1; cat "$SCORE"
nl_mark verdict done "$(grep '^VERDICT' $SCORE)"
if grep -q '^VERDICT: RENDER OK' "$SCORE"; then nl_say "DONE rc=0 $(grep '^VERDICT' $SCORE)"; exit 0; fi
nl_say "DONE incomplete, exit 3 ($(grep '^VERDICT' $SCORE | head -n 1))"; exit 3
