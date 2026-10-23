#!/bin/bash
# slope-calib-2026-10-14.sh: walk-flat v2 control takes in the 09z5 slope env WITH --no-bounds (the first control set in
# slope-play-check-2026-10-14.sh lost every take to out_of_terrain_bounds: edge-column spawn). calibrates whether the base
# policy falls on a 0.15 hill at all, and on a steeper 0.25 hill (play-time override only).
TASK=Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck; OUT=/home/witcheer/Pollen/clips/slope-calib-2026-10-14
. /home/witcheer/Pollen/proof-common.sh
V2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
C="--episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds"
for i in 1 2; do ( export MICRODUCK_SLOPE=0.15,0.15; play v2-a15-t$i $TASK $V2 1000 $C ); done
for i in 1 2; do ( export MICRODUCK_SLOPE=0.15,0.15; play v2-b15-t$i $TASK $V2 1000 $C --no-push ); done
for i in 1 2; do ( export MICRODUCK_SLOPE=0.25,0.25; play v2-b25-t$i $TASK $V2 1000 $C --no-push ); done
( export MICRODUCK_SLOPE=0.001,0.001; play v2-c-t1 $TASK $V2 1000 $C )
echo "=== $(date -u +%T) SLOPE_CALIB_END ==="
