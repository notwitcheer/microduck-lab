#!/bin/bash
# lane-sim-hill-2026-11-08.sh: lane simulation for 09z32 (and 09z33). NOTHING real is touched: state file = a COPY, queue = a fake dir, clock = HILL_NOW/NL_NOW, the item stops (HILL_SIM=1) right after the lane check, before any Donald drain.
# runs the REAL staged 09z32 header+body with the real duck-lane.sh sourced. prints the item's own lane lines, its rc and the state file after.
STG=${STG:-/home/witcheer/Pollen/queue-staging}; D=/tmp/lanesim-hill; rm -rf $D; mkdir -p $D/q
cd $STG
for c in "Sun 12:10 CET weekend, hill pair + a bench item queued|2026-11-08 12:10|2026-11-08 23:59:59|1|ld=1793981400; ly=1793941800" \
         "Sun 03:10 weekend fire (same state)|2026-11-08 03:10|2026-11-08 23:59:59|1|ld=1793981400; ly=1793941800" \
         "Mon 01:10 weekday after a Sun cut (ld>ly, bench queued): the alternation applies to a resume|2026-11-09 01:10|2026-11-09 06:10|0|ld=1793981400; ly=1793941800" \
         "Mon 01:10 weekday, previous decision = yield (ly>ld)|2026-11-09 01:10|2026-11-09 06:10|0|ld=1793941800; ly=1793981400"; do
  IFS="|" read -r lab now end wk st <<<"$c"; echo "$st" > $D/state; rm -rf $D/q; mkdir -p $D/q; touch $D/q/09z32-duck-hill.sh $D/q/09z33-duck-proof-hill.sh $D/q/98b-arete-toolcall-recheck.sh
  ( export DUCK_LANE_FILE=$D/state DUCK_LANE_QUEUE=$D/q HILL_SIM=1 HILL_NOW=$(date -d "$now" +%s) NL_NOW=$(date -d "$now" +%s) NL_HARD_STOP_EPOCH=$(date -d "$end" +%s) NL_HC_WEEKEND=$wk DUCK_LANE_OFF=0 HILL_NOFREEZE=1
    bash 09z32-duck-hill.sh > $D/out.txt 2>&1; echo "rc=$?" >> $D/out.txt )
  echo "--- $lab"; grep -aE "lane:|SIM:|rc=" $D/out.txt | sed "s/^\[hill09z32\] [0-9:]* *//" | cut -c1-150
  echo "    state: before [$st]  after [$(cat $D/state)]"
done
rm -rf $D ~/hill09z32-status.json
echo "drain order (ls | sort): $(printf '%s\n' 09z32-duck-hill.sh 09z33-duck-proof-hill.sh 98b-arete-toolcall-recheck.sh | sort | tr '\n' ' ')"
