#!/bin/bash
# vsrough-terrain-matrix.sh (2026-09-29): forced-terrain takes for level 5 on rough ground.
# rough = VelStand-Rough model_23000 (09m, tracking terrain curriculum), seed = flat VelStand model_20000 (its warm start).
# both in Mjlab-VelStand-Rough-MicroDuck, spawn standing, env forced onto a training-layout patch with headless_play
# --terrain-level/--terrain-type (added 2026-09-29). level 4 = highest tier the run reached (3 takes), level 9 = hardest row (2 takes).
# 20 s episodes, 0.1 s sampling; RESET lines = terminations, never recoveries.
exec > >(tee -a /home/witcheer/Pollen/vsrough-terrain-matrix.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
EXTRA=${EXTRA:-}  # EXTRA=--no-push for the push-free pass
OUT=/home/witcheer/Pollen/clips/vsrough-terrain-2026-09-29${TAG:+-$TAG}; mkdir -p $OUT  # TAG names the pass dir
TASK=Mjlab-VelStand-Rough-MicroDuck
play() { local name=$1 ck=$2; shift 2; local d=$(dirname "$ck")
  echo "=== $(date -u +%T) clip $name ==="; local t0=$(date +%s)
  rm -f "$d/videos/play/rl-video-step-0.mp4"
  timeout 900 uv run python headless_play.py "$TASK" --checkpoint-file "$ck" --num-envs 1 --video True --video-length 1000 \
      --video-width 1280 --video-height 720 --episode-s 20 --log-every 5 --spawn standing \
      --cam-distance 0.6 --cam-elevation -25 $EXTRA "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ -f "$d/videos/play/rl-video-step-0.mp4" ]; then mv "$d/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
}
ROUGH=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsrough/2026-09-29_14-10-21_duckvsrough/model_23000.pt
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsrough/2026-09-28_00-00-00_seed-velstand-it20000/model_20000.pt
for lv in 4 9; do
  n=3; [ $lv = 9 ] && n=2
  for ty in pyramid_stairs random_grid; do
    for i in $(seq 1 $n); do
      play rough-L$lv-$ty-t$i $ROUGH --terrain-level $lv --terrain-type $ty
      play seed-L$lv-$ty-t$i $SEED --terrain-level $lv --terrain-type $ty
    done
  done
done
echo "=== $(date -u +%T) VSROUGH_TERRAIN_MATRIX_END ==="
