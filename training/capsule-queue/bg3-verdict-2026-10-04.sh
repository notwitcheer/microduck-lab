#!/bin/bash
# bg3-verdict-2026-10-04.sh: verdict takes for back-getup v3 (09s, model_34000), in the plain StandUp-Flat env (the published
# standup env). face_up x5 (the claim; baselines v1/v2/seed all 0 of 3), face_down/sitting/standing x2 (no-regression check).
# 12 s one-episode takes, 0.1 s sampling, fixed world camera. needs ~/Pollen/proof-common.sh + proof-verdicts.py.
CK=$(ls -d /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbackgetup3/*_duckbackgetup3/model_34000.pt 2>/dev/null | tail -1)
[ -n "$CK" ] || { echo "NO_MODEL_34000: 09s not finished ($(ls /home/witcheer/idle-queue/ | tr '\n' ' '))"; exit 2; }
TASK=Mjlab-StandUp-Flat-MicroDuck; OUT=/home/witcheer/Pollen/clips/bg3-verdict-2026-10-04
. /home/witcheer/Pollen/proof-common.sh
echo "checkpoint: $CK"
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for i in 1 2 3 4 5; do play v3-face_up-t$i $TASK $CK 600 $C --spawn face_up; done
for sp in face_down sitting standing; do for i in 1 2; do play v3-$sp-t$i $TASK $CK 600 $C --spawn $sp; done; done
echo "=== $(date -u +%T) BG3_VERDICT_END ==="
python3 /home/witcheer/Pollen/proof-verdicts.py $OUT --end 11.9 --rise
