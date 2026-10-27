#!/bin/bash
# bigaim-takes-2026-10-26.sh <out dir name under ~/Pollen/clips> <take prefix> <task id> <checkpoint .pt> [N takes, default 6]: N 1-env goal-mode takes of one checkpoint on the giant ball
# (same flags as proof-bk-a / proof-ba-a: goal at 1.4 m, face_goal, standing spawn, no shoves, 6 s, 0.1 s samples, camera D). used for the pre-training reads of the 09z12 sweep
# (seed model_16000 as the reference, the 40- and 200-iteration probe checkpoints per aim weight); read with: python3 ~/Pollen/ba-score-2026-10-26.py --dir ~/Pollen/clips/<out> <prefix>
export MICRODUCK_BIGKICK_GOAL=1
OUT=/home/witcheer/Pollen/clips/${1:?out dir name}; PFX=${2:?prefix}; TASK=${3:?task id}; CK=${4:?checkpoint}; N=${5:-6}
. /home/witcheer/Pollen/proof-common.sh
[ -f "$CK" ] || { echo "NO_CHECKPOINT $CK"; exit 2; }
C="--episode-s 6 --log-every 5 --spawn standing --no-push --cam-world 0.8,0,0.12 --cam-distance 1.75 --cam-elevation -18 --cam-azimuth 65"
for i in $(seq 1 $N); do play $PFX-t$i $TASK $CK 300 $C; done
echo "=== $(date -u +%T) TAKES_END $PFX ==="
