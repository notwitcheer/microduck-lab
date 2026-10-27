#!/bin/bash
# hop-takes-2026-10-27.sh <out dir name under ~/Pollen/clips> <take prefix> <checkpoint .pt> [N takes, default 4] [task id]: N 1-env hop takes of one checkpoint in the hop PLAY env
# (zero command, no shoves, 6 s, per-step [hop] log, no video unless HOP_VIDEO=1). read with: python3 ~/Pollen/hop-score-2026-10-27.py --dir ~/Pollen/clips/<out> <prefix>
# the checkpoint may belong to any task with the 61/14 layout (the seed is a walk-flat v2 policy): the play env is always the hop task, so a seed take is "the seed through the condition".
OUT=/home/witcheer/Pollen/clips/${1:?out dir name}; PFX=${2:?prefix}; CK=${3:?checkpoint}; N=${4:-4}; TASK=${5:-Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck}
export HOP_VIDEO=${HOP_VIDEO:-0}
. /home/witcheer/Pollen/proof-hop-common.sh
[ -f "$CK" ] || { echo "NO_CHECKPOINT $CK"; exit 2; }
C="--episode-s 6 --no-push"
[ "$HOP_VIDEO" = 1 ] && C="$C --cam-world auto --cam-world-z 0.08 --cam-distance 0.7 --cam-elevation -5 --cam-azimuth 110"
for i in $(seq 1 $N); do play $PFX-t$i $TASK $CK 300 $C; done
echo "=== $(date -u +%T) TAKES_END $PFX ==="
