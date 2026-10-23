#!/bin/bash
# diag-z2c-mix-randcmd (2026-10-22): anomaly check for z6-c (walk-slip 3/15 on its own condition).
# walk-slip (09z2 model_10000) in the z6-c env (Mix, 1 mm platform generator floor, friction 0.2, push scale 1.0 = maker shoves)
# WITHOUT --cmd-vx (random play twist commands, as z2-a/ax): isolates the floor change. --no-bounds kept (generator floor).
# 15 takes, 20 s, 0.1 s samples, same camera. unique take names (dg2-*).
export MICRODUCK_STEP_HEIGHT=0.001,0.001
export MICRODUCK_FOOT_FRICTION=0.2,0.2
export MICRODUCK_PUSH_SCALE=1.0
TASK=Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck; OUT=/home/witcheer/Pollen/clips/diag-z2c-mix-randcmd-2026-10-22
. /home/witcheer/Pollen/proof-common.sh
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelslip/2026-10-13_14-10-19_duckvelslip/model_10000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --no-bounds"
for i in $(seq 1 15); do play dg2-c-t$i $TASK $R 1000 $C; done
echo "=== $(date -u +%T) DIAG_Z2C_MIX_RANDCMD_END ==="
