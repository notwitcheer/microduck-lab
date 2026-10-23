#!/bin/bash
# clip-walkgetup-2026-10-12.sh: tracking-camera content takes of level 11c (09w, model_9000) for the walk-getup Hub beat.
# same harness as clip-carpet.sh (2026-10-05) with the task switched to the gear-play env and the 09w checkpoint. 1 env, 12 s.
WT=/home/witcheer/Pollen/microduck_rl-carpet
OUT=/home/witcheer/Pollen/clips/clip-walkgetup-2026-10-12
mkdir -p $OUT
exec > >(tee -a $OUT.log) 2>&1
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
cd $WT
CK=$WT/logs/rsl_rl/duckcarpetbl/2026-10-07_14-10-19_duckcarpetbl/model_9000.pt
play() { local name=$1 ck=$2; shift 2
  local tmp=/home/witcheer/Pollen/clips/tmp-clip-wg-$name; rm -rf $tmp; mkdir -p $tmp; cp "$ck" $tmp/; cp -r "$(dirname "$ck")/params" $tmp/ 2>/dev/null
  echo "=== $(date +%T) $name"
  timeout 900 uv run python headless_play.py Mjlab-VelStand-Flat-Backlash-MicroDuck --checkpoint-file "$tmp/$(basename "$ck")" --num-envs 1 --video True --video-length 600 \
    --video-width 1280 --video-height 720 --episode-s 12 --log-every 5 --cam-distance 0.45 --cam-elevation -10 --cam-azimuth 135 "$@" > $OUT/$name.full.log 2>&1 < /dev/null
  echo "rc=$?"; grep -a "headless_play\|RESET" $OUT/$name.full.log > $OUT/$name.log
  [ -f $tmp/videos/play/rl-video-step-0.mp4 ] && mv $tmp/videos/play/rl-video-step-0.mp4 $OUT/$name.mp4 || { echo NO_CLIP; tail -n 5 $OUT/$name.full.log; }
  grep -m1 "after reset" $OUT/$name.log; rm -rf $tmp
}
for i in 1 2 3 4; do play w-t$i $CK --spawn face_up; done
echo CLIP_END
