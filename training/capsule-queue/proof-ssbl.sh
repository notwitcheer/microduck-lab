#!/bin/bash
# sitstand backlash twin (ssbl model_18000) vs seed (sitstand model_15000), both in SitStand-Flat-Backlash, 25 s episodes
# (POSTURE_DWELL_S 3.5-6.5 s -> several sit/stand switches), spawn standing x3 + sitting x2; reference seed in plain SitStand x2.
TASK=Mjlab-SitStand-Flat-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-ssbl-2026-10-02
. /home/witcheer/Pollen/proof-common.sh
TW=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckssbl/2026-10-02_15-21-18_duckssbl/model_18000.pt
SD=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckssbl/2026-09-28_00-00-00_seed-sitstand-it15000/model_15000.pt
C="--episode-s 25 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for i in 1 2 3; do play twin-standing-t$i $TASK $TW 1250 $C --spawn standing; play seed-standing-t$i $TASK $SD 1250 $C --spawn standing; done
for i in 1 2; do play twin-sitting-t$i $TASK $TW 1250 $C --spawn sitting; play seed-sitting-t$i $TASK $SD 1250 $C --spawn sitting; done
for i in 1 2; do play ref-standing-t$i Mjlab-SitStand-Flat-MicroDuck $SD 1250 $C --spawn standing; done
echo "=== $(date -u +%T) PROOF_SSBL_END ==="
