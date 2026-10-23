#!/bin/bash
# seed-verdict-2026-10-05.sh <seed>...: verdict takes for the get-up seed sweep (09t1..09t6, maker StandUp env from scratch,
# 3000 it each). per seed at model_3000, plain Mjlab-StandUp-Flat-MicroDuck: face_up x5 (the claim; every earlier policy 0 of N,
# half-rolled freeze ~60 mm), face_down x1 + sitting x1 (sanity). 12 s takes, 0.1 s sampling, fixed world camera (same as bg3).
# usage: bash seed-verdict.sh 1 2 3  (run two copies in parallel with disjoint seed lists; each writes its own OUT dir)
TAG=$(echo "$@" | tr ' ' '-')
OUT=/home/witcheer/Pollen/clips/seed-verdict-2026-10-05-s$TAG
TASK=Mjlab-StandUp-Flat-MicroDuck
. /home/witcheer/Pollen/proof-common.sh
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for s in "$@"; do
  CK=$(ls -d /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckstandupseed$s/*/model_3000.pt 2>/dev/null | tail -1)
  [ -n "$CK" ] || { echo "NO_MODEL_3000 seed $s"; continue; }
  echo "seed $s checkpoint: $CK"
  for i in 1 2 3 4 5; do play s$s-face_up-t$i $TASK $CK 600 $C --spawn face_up; done
  for sp in face_down sitting; do play s$s-$sp-t1 $TASK $CK 600 $C --spawn $sp; done
done
echo "=== $(date -u +%T) SEED_VERDICT_END $TAG ==="
python3 /home/witcheer/Pollen/proof-verdicts.py $OUT --end 11.9 --rise
