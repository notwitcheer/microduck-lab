#!/bin/bash
# clip-z7-fresh.sh <batch 1|2|3> (2026-10-22, content clip for 09z7 mixslope, NOT a verdict batch)
# MixSlope env with fixed geometry (hill 0.15, step 25 mm), normal grip 1.0, no shoves, 40 s episode so the duck can
# cross from one tile onto the next. 2 takes per batch, take names zcB-tN unique per batch.
B=$1
export MICRODUCK_SLOPE=0.15,0.15
export MICRODUCK_STEP_HEIGHT=0.025,0.025
export MICRODUCK_FOOT_FRICTION=1.0,1.0
TASK=Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck; OUT=/home/witcheer/Pollen/clips/clip-z7-fresh$B-2026-10-22
. /home/witcheer/Pollen/proof-common.sh
Z=$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmixslope/*_duckvelmixslope/model_16000.pt 2>/dev/null | tail -n 1)
[ -n "$Z" ] || { echo NO_Z7_CHECKPOINT; exit 2; }
echo "z7 ckpt: $Z env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 40 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds --no-push"
for i in 1 2; do play zc$B-t$i $TASK $Z 2000 $C; done
echo "=== $(date -u +%T) CLIP_Z7_FRESH${B}_END ==="
