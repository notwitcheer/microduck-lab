#!/bin/bash
# standup v2 candidate (subl model_28000) vs seed (standup model_25000 = HF standup v1), both in StandUp-Flat-Backlash,
# spawns face_down/face_up/sitting/standing x3; reference: seed in plain StandUp-Flat x2 per spawn. 12 s, 0.1 s, fixed cam.
TASK=Mjlab-StandUp-Flat-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-subl-2026-10-02
. /home/witcheer/Pollen/proof-common.sh
TW=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/ducksubl/2026-10-02_14-17-04_ducksubl/model_28000.pt
SD=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/ducksubl/2026-09-28_00-00-00_seed-standup-it25000/model_25000.pt
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for sp in face_up face_down sitting standing; do
  for i in 1 2 3; do play twin-$sp-t$i $TASK $TW 600 $C --spawn $sp; play seed-$sp-t$i $TASK $SD 600 $C --spawn $sp; done
  for i in 1 2; do play ref-$sp-t$i Mjlab-StandUp-Flat-MicroDuck $SD 600 $C --spawn $sp; done
done
echo "=== $(date -u +%T) PROOF_SUBL_END ==="
