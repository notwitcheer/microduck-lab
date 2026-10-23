#!/bin/bash
# level 8 groundpick recorder test: model_1000 vs model_12300, 12 s, mouth_tip height every 0.1 s
exec > >(tee -a /home/witcheer/Pollen/clips/groundpick-2026-09-23/record.log) 2>&1
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
RUN=logs/rsl_rl/duckgroundpick/2026-09-23_14-10-19_duckgroundpick
OUT=/home/witcheer/Pollen/clips/groundpick-2026-09-23
for it in 12300 1000; do
  echo "=== it$it $(date +%T)"
  rm -rf $RUN/videos/play
  timeout 400 uv run python headless_play.py Mjlab-GroundPick-Flat-MicroDuck --checkpoint-file $RUN/model_$it.pt \
    --num-envs 1 --video True --video-length 600 --video-width 1280 --video-height 720 \
    --cam-distance 0.45 --cam-elevation -10 --cam-azimuth 135 --log-every 5 --log-site mouth_tip > $OUT/it$it.log 2>&1
  echo "rc=$? $(date +%T)"
  cp $RUN/videos/play/rl-video-step-0.mp4 $OUT/it$it.mp4 2>/dev/null && ls -la $OUT/it$it.mp4
done
echo "=== END $(date +%T)"; nvidia-smi --query-gpu=memory.used --format=csv,noheader
