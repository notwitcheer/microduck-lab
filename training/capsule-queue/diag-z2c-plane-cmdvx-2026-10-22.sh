#!/bin/bash
# diag-z2c-plane-cmdvx (2026-10-22): anomaly check for z6-c (walk-slip 3/15 on its own condition).
# walk-slip (09z2 model_10000) in its OWN env Velocity-Flat-Backlash-Slip (plane floor), friction 0.2, maker shoves
# (play interval 0.5-1 s, +-0.3), WITH --cmd-vx 0.3: isolates the command change (z2-a/ax had random play twist commands).
# 15 takes, 20 s, 0.1 s samples, same camera. unique take names (dg1-*) so no tmp-dir clash with dg2.
export MICRODUCK_FOOT_FRICTION=0.2,0.2
TASK=Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck; OUT=/home/witcheer/Pollen/clips/diag-z2c-plane-cmdvx-2026-10-22
. /home/witcheer/Pollen/proof-common.sh
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslip/2026-10-13_14-10-19_duckvelslip/model_10000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3"
for i in $(seq 1 15); do play dg1-c-t$i $TASK $R 1000 $C; done
echo "=== $(date -u +%T) DIAG_Z2C_PLANE_CMDVX_END ==="
