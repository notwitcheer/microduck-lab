#!/bin/bash
# vsbl-track.sh (2026-09-26): trunk-tracking camera takes (standing spawn) for the backlash post clip; walking needs a tracking cam, the fixed cam loses the duck by ~12 s.
# seed = level 5 model_20000 (no backlash training), twin = model_23000 (+3k it with +-1 deg play).
# spawns standing / face_down / face_up (headless_play --spawn, random_prone_init branch added 2026-09-26), 3 takes each.
# 20 s episodes; fallen_too_long resets after 8 s down (RESET lines = resets, not recoveries). 0.1 s sampling.
exec > >(tee -a /home/witcheer/Pollen/vsbl-track.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
OUT=/home/witcheer/Pollen/clips/vsbl-track-2026-09-26; mkdir -p $OUT
TASK=Mjlab-VelStand-Flat-Backlash-MicroDuck
play() { local name=$1 ck=$2; shift 2; local d=$(dirname "$ck")
  echo "=== $(date -u +%T) clip $name ==="; local t0=$(date +%s)
  rm -f "$d/videos/play/rl-video-step-0.mp4"
  timeout 900 uv run python headless_play.py "$TASK" --checkpoint-file "$ck" --num-envs 1 --video True --video-length 1000 \
      --video-width 1280 --video-height 720 --episode-s 20 --log-every 5 "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ -f "$d/videos/play/rl-video-step-0.mp4" ]; then mv "$d/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
}
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsbl/2026-09-25_00-00-00_seed-velstand-it20000/model_20000.pt
TWIN=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsbl/2026-09-26_00-10-19_duckvsbl/model_23000.pt
for sp in standing; do
  for i in 1 2; do
    play twin-$sp-t$i $TWIN --spawn $sp --cam-distance 0.55 --cam-elevation -10
    play seed-$sp-t$i $SEED --spawn $sp --cam-distance 0.55 --cam-elevation -10
  done
done
echo "=== $(date -u +%T) VSBL_TRACK_END ==="
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader
