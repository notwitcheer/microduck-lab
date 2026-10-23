#!/bin/bash
# roul-back-probe-2026-10-04.sh: zero-shot diagnostic. does the forward-roll policy (level 6, roulade model_10000)
# get the duck up from a face_up spawn in the plain StandUp env? decides whether roulade is a better warm start for
# get-up-from-the-back v4 than the frozen standup line (v1/v2/v3 all 0 of N face-up). card shared with the bench leg.
CK=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckroulade/2026-09-21_14-10-19_duckroulade/model_10000.pt
OUT=/home/witcheer/Pollen/clips/roul-back-probe-2026-10-04
TASK=Mjlab-StandUp-Flat-MicroDuck
. /home/witcheer/Pollen/proof-common.sh
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for i in 1 2 3; do play roul-face_up-t$i $TASK $CK 600 $C --spawn face_up; done
for i in 1 2; do play roul-midroll-t$i Mjlab-Roulade-Flat-MicroDuck $CK 300 --episode-s 6 --log-every 5 --spawn midroll; done
echo "=== $(date -u +%T) ROULBACK_END ==="
python3 /home/witcheer/Pollen/proof-verdicts.py $OUT --end 11.9 --rise
