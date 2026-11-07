#!/bin/bash
# lane-sim-heist-2026-11-05.sh: lane simulation for 09z28 (and 09z29) beside the hop3 items. NOTHING real is touched: state file = a COPY, queue = a fake dir, clock = NL_NOW/HEIST_NOW, the item stops (HEIST_SIM=1) right after the lane check, before any Donald drain.
# runs the REAL staged 09z28 header+body with the real duck-lane.sh sourced. state before each case is written explicitly. prints the item's own lines, its rc, the state file after, and whether the state changed.
# real state at staging time (2026-11-05 19:4x CET): ld=1793895000 (Thu 17:10 hop2 trained) ly=1793808600 (Wed 17:10) = last decision "train", so Fri 01:10 is a bench block and Fri 14:10 a duck block.
set -u
STG=${STG:-/home/witcheer/Pollen/queue-staging}
D=/tmp/lanesim-heist; rm -rf $D; mkdir -p $D/q
E() { date -d "$1" +%s; }
B1=$(E "2026-11-06 06:10"); B2=$(E "2026-11-06 17:10"); SAT0010=$(E "2026-11-07 00:10"); SUNEND=$(E "2026-11-08 23:59:59")
echo "ITEM gate NOT_BEFORE=$(grep -m1 '^NOT_BEFORE=' $STG/09z28-duck-sockheist.sh | cut -d- -f2- | head -c 60)"
echo "B1 (Fri 01:10-06:10) end=$B1  B2 (Fri 14:10-17:10) end=$B2  Sat 00:10 weekend block end=$SUNEND"
run() { # <label> <state> <now epoch> <block end epoch> <weekend 0/1> <NOT_BEFORE or ''> <queue files...>
  local label=$1 state=$2 now=$3 end=$4 wk=$5 nb=$6; shift 6
  echo "$state" > $D/state; rm -rf $D/q; mkdir -p $D/q; for f in "$@"; do touch $D/q/$f; done
  local nbx=""; [ -n "$nb" ] && nbx="NOT_BEFORE=$nb"
  ( export DUCK_LANE_FILE=$D/state DUCK_LANE_QUEUE=$D/q HEIST_SIM=1 HEIST_NOW=$now NL_NOW=$now NL_HARD_STOP_EPOCH=$end NL_HC_WEEKEND=$wk DUCK_LANE_OFF=0; [ -n "$nb" ] && export NOT_BEFORE=$nb
    cd $STG && bash 09z28-duck-sockheist.sh > $D/out.txt 2>&1; echo "rc=$?" >> $D/out.txt )
  echo "--- $label"
  grep -a -E "NOT_BEFORE|lane:|SIM:|not reached|rc=|weekend|run hs1" $D/out.txt | sed 's/^\[heist09z28\] [0-9:]* */    /' | cut -c1-200
  echo "    state: before [$state]  after [$(cat $D/state)]  -> $([ "$(cat $D/state)" = "$state" ] && echo UNCHANGED || echo CHANGED)"
}
HOP="09z26-duck-hop3.sh 09z26s2-duck-hop3-seed2.sh 09z27-duck-proof-hop3.sh"
S_NOW="ld=1793895000; ly=1793808600"
echo; echo "=== A. Fri 14:10 block, hop3 done earlier in the block (09z28 still queued, tried once the drain walks past 09z27), WITH the gate"
run "A1 Fri 16:25, hop3 trained in B2 (ld=B2), 88/89 queued" "ld=$B2; ly=$B1" $(E "2026-11-06 16:25") $B2 0 "" $HOP 09z28-duck-sockheist.sh 09z29-duck-proof-sockheist.sh 88-units-orbit.sh 89-ripple-65b-hermes-repo.sh
run "A2 Fri 14:10:05, 09z28 reached BEFORE hop3 trained (cannot happen by sort; worst case anyway), state = real now-state" "$S_NOW" $(E "2026-11-06 14:10") $B2 0 "" 09z28-duck-sockheist.sh 88-units-orbit.sh
run "A3 Fri 01:10 B1 bench-by-alternation, 88/89 queued" "$S_NOW" $(E "2026-11-06 01:10") $B1 0 "" $HOP 09z28-duck-sockheist.sh 09z29-duck-proof-sockheist.sh 88-units-orbit.sh 89-ripple-65b-hermes-repo.sh
echo; echo "=== B. CONTROL: the same Fri 16:25 tail WITHOUT the gate (NOT_BEFORE=0): what a plain 09z28 would do"
run "B1 no gate, hop3 trained in B2 (ld=B2)" "ld=$B2; ly=$B1" $(E "2026-11-06 16:25") $B2 0 0 $HOP 09z28-duck-sockheist.sh 88-units-orbit.sh
run "B2 no gate, Fri 14:10 with the real now-state and a bench item queued" "$S_NOW" $(E "2026-11-06 14:10") $B2 0 0 09z28-duck-sockheist.sh 88-units-orbit.sh
echo; echo "=== C. first weekend block: Sat 00:10 runner fire, WITH the gate (open at Sat 00:00)"
run "C1 Sat 00:10, hop3 done, 88-91 still queued" "ld=$B2; ly=$B1" $SAT0010 $SUNEND 1 "" 09z28-duck-sockheist.sh 09z29-duck-proof-sockheist.sh 88-units-orbit.sh 89-ripple-65b-hermes-repo.sh 90-astra-stop-q4.sh 91-glb-3d-coder.sh
run "C2 Sat 00:10, hop3 NOT done (09z27 not finished) and bench queued" "ld=$B2; ly=$B1" $SAT0010 $SUNEND 1 "" $HOP 09z28-duck-sockheist.sh 88-units-orbit.sh
run "C3 gate probe: Fri 23:55 (a runner fire cannot happen then, but the gate must hold)" "ld=$B2; ly=$B1" $(E "2026-11-06 23:55") $SUNEND 1 "" 09z28-duck-sockheist.sh
echo; echo "drain order at Sat 00:10 (ls | sort, C1): $(printf '%s\n' 09z28-duck-sockheist.sh 09z29-duck-proof-sockheist.sh 88-units-orbit.sh 89-ripple-65b-hermes-repo.sh 90-astra-stop-q4.sh 91-glb-3d-coder.sh | sort | tr '\n' ' ')"
rm -rf $D; rm -f ~/heist09z28-status.json
