#!/bin/bash
# back-getup verdict recorder: N face_up takes of one checkpoint, 12 s episode (one episode = whole clip, no mid-clip reset), 0.1 s sampling.
# usage: bg-record.sh <checkpoint.pt> <label> [takes]
CKPT=$1; LABEL=$2; TAKES=${3:-3}
OUT=/home/witcheer/Pollen/clips/backgetup-2026-09-24
mkdir -p $OUT
exec > >(tee -a $OUT/record-$LABEL.log) 2>&1
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
RUN=$(dirname $CKPT)
for t in $(seq 1 $TAKES); do
  echo "=== $LABEL take$t $(date +%T)"
  rm -rf $RUN/videos/play
  timeout 400 uv run python headless_play.py Mjlab-StandUpBack-Flat-MicroDuck --checkpoint-file $CKPT \
    --num-envs 1 --video True --video-length 600 --video-width 1280 --video-height 720 --episode-s 12 \
    --spawn face_up --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --log-every 5 > $OUT/$LABEL-take$t.log 2>&1
  echo "rc=$? $(date +%T)"
  cp $RUN/videos/play/rl-video-step-0.mp4 $OUT/$LABEL-take$t.mp4 2>/dev/null && ls -la $OUT/$LABEL-take$t.mp4
done
rm -rf $RUN/videos/play
echo "=== END $(date +%T)"; nvidia-smi --query-gpu=memory.used --format=csv,noheader
