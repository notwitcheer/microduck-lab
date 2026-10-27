#!/bin/bash
# dribble-takes-2026-10-27.sh <out dir name under ~/Pollen/clips> <take prefix> <task id> <checkpoint .pt> <cmd vx> [N takes, default 3] [extra headless_play flags...]:
# N 1-env 24 s takes of one checkpoint on the dribble task, goal mode (goal mouth at x = 1.8 m, duck turned to +x), forced forward command, NO shoves, 0.2 s samples,
# duck-tracking side camera (CAM env overrides). used for the seed feasibility reads and the sweep reads of 09z14; scored with dr-score-2026-10-27.py --dir ~/Pollen/clips/<out> <prefix>.
export MICRODUCK_DRIBBLE_GOAL=${MICRODUCK_DRIBBLE_GOAL:-1}
OUT=/home/witcheer/Pollen/clips/${1:?out dir name}; PFX=${2:?prefix}; TASK=${3:?task id}; CK=${4:?checkpoint}; VX=${5:?cmd vx}; N=${6:-3}; shift $(( $# < 6 ? $# : 6 ))
. /home/witcheer/Pollen/proof-common-dr-2026-10-27.sh
[ -f "$CK" ] || { echo "NO_CHECKPOINT $CK"; exit 2; }
CAM=${CAM:-"--cam-distance 1.9 --cam-elevation -12 --cam-azimuth 70"}  # env CAM overrides the camera flags (a fixed world camera: --cam-world x,y,z --cam-distance ...); VW/VH set the video size
C="--episode-s 24 --log-every 10 --no-push --cmd-vx $VX $CAM"
for i in $(seq 1 $N); do play $PFX-t$i $TASK $CK 1200 $C "$@"; done
echo "=== $(date -u +%T) TAKES_END $PFX ==="
