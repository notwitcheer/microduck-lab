#!/bin/bash
# vsrough3-terrain-matrix.sh (2026-10-01, operator "go" in the GPU thread): does the curriculum-mode ladder help on hard ground?
# vsr3 = VelStand-Rough model_22900 (09m6, curriculum-mode ladder, rows ordered by difficulty, all five patches)
# vsr2 = VelStand-Rough model_23000 (09m5, same patches minus curriculum mode: trained on the shared 5x5 RANDOM grid)
# both in Mjlab-VelStand-Rough-MicroDuck, spawn standing, --no-push --spawn-offset 1.6 (onto the rough part, not the
# centre platform), headless_play --terrain-level/--terrain-type forces an ordered-difficulty row: difficulty (L+U)/10.
# level 9 (hardest row) x 4 takes, level 6 x 2 takes, three rough types. 20 s episodes, 0.1 s sampling.
# falls = tilt events (grav_b z > -0.5), never RESET lines (origin-z artefact on pyramids, see log 2026-09-29).
exec > >(tee -a /home/witcheer/Pollen/vsrough3-terrain-matrix.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
OUT=/home/witcheer/Pollen/clips/vsrough3-terrain-2026-10-01; mkdir -p $OUT
TASK=Mjlab-VelStand-Rough-MicroDuck
play() { local name=$1 ck=$2; shift 2; local d=$(dirname "$ck")
  echo "=== $(date -u +%T) clip $name ==="; local t0=$(date +%s)
  rm -f "$d/videos/play/rl-video-step-0.mp4"
  timeout 900 uv run python headless_play.py "$TASK" --checkpoint-file "$ck" --num-envs 1 --video True --video-length 1000 \
      --video-width 1280 --video-height 720 --episode-s 20 --log-every 5 --spawn standing \
      --cam-distance 0.6 --cam-elevation -25 --no-push --spawn-offset 1.6 "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ -f "$d/videos/play/rl-video-step-0.mp4" ]; then mv "$d/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
}
VSR3=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsrough3/2026-10-01_14-10-19_duckvsrough3/model_22900.pt
VSR2=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsrough2/2026-09-30_14-10-19_duckvsrough2/model_23000.pt
for lv in 9 6; do
  n=4; [ $lv = 6 ] && n=2
  for ty in pyramid_stairs random_grid pyramid_slope; do
    for i in $(seq 1 $n); do
      play vsr3-L$lv-$ty-t$i $VSR3 --terrain-level $lv --terrain-type $ty
      play vsr2-L$lv-$ty-t$i $VSR2 --terrain-level $lv --terrain-type $ty
    done
  done
done
echo "=== $(date -u +%T) VSROUGH3_TERRAIN_MATRIX_END ==="
