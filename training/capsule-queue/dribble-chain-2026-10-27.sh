#!/bin/bash
# dribble-chain-2026-10-27.sh: ONE card slot for the 09z14 design probe + the body e2e: the reward sweep (dribble-sweep-2026-10-27.sh, env passes through: SEED N SETS ITS KS TAG)
# then the e2e clone of the shared duck body (e2e-dribble-2026-10-27.sh, E2E_NOWAIT=1 because this slot already holds the card and the drained Donald). run through dribble-wrap-2026-10-27.sh 1 dribble <this>.
# the e2e exercises the condim-6 rolling-friction path and both ball reward terms through env vars (the module defaults are set after the sweep).
P=/home/witcheer/Pollen
bash $P/dribble-sweep-2026-10-27.sh; echo "sweep rc=$? $(date -u +%T)"
MICRODUCK_DRIBBLE_ROLL=${E2E_ROLL:-0.004} MICRODUCK_DRIBBLE_W_CARRY=20 MICRODUCK_DRIBBLE_W_LAT=10 E2E_NOWAIT=1 bash $P/e2e-dribble-2026-10-27.sh; echo "e2e rc=$? $(date -u +%T)"
