#!/bin/bash
# bigkick-seedtake-2026-10-24.sh: feasibility take BEFORE the 09z10 item enters the queue: the SEED policy (09l kickbl model_13000, trained on the
# 70 mm / 15 g ball) kicks the 140 mm / 60 g ball in the big-ball task with the goal and face_goal reset on. 1 env, standing spawn, no shoves,
# 6 s, 0.1 s samples. tells whether the retrain has anything to fix (ball distance / direction / goal) and proves the recorder, goal and camera.
# usage: bash bigkick-seedtake-2026-10-24.sh <name> [az] [dist] [elev] [lookat x,y,z]   (clips land in ~/Pollen/clips/bigkick-feas-2026-10-24/)
exec > >(tee -a /home/witcheer/Pollen/clips/bigkick-feas-2026-10-24.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
export MICRODUCK_BIGKICK_GOAL=1
cd /home/witcheer/Pollen/microduck_rl
name=${1:?take name}; az=${2:-60}; dist=${3:-1.9}; elev=${4:--8}; look=${5:-0.65,0,0.10}
OUT=/home/witcheer/Pollen/clips/bigkick-feas-2026-10-24; mkdir -p $OUT
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckkickbl/2026-09-28_14-10-20_duckkickbl/model_13000.pt
tmp=$OUT/tmp-$name; rm -rf $tmp; mkdir -p $tmp; cp $SEED $tmp/; cp -r $(dirname $SEED)/params $tmp/ 2>/dev/null
t0=$(date +%s)
timeout 900 uv run python headless_play.py Mjlab-BallKick-Flat-Backlash-Big-MicroDuck --checkpoint-file $tmp/model_13000.pt --num-envs 1 --video True \
  --video-length 300 --video-width 1280 --video-height 720 --episode-s 6 --log-every 5 --spawn standing --no-push \
  --cam-world $look --cam-distance $dist --cam-elevation $elev --cam-azimuth $az > $OUT/$name.full.log 2>&1
echo "rc=$? in $(( $(date +%s)-t0 )) s"
grep -a "headless_play\|RESET\|rror" $OUT/$name.full.log > $OUT/$name.log
[ -f $tmp/videos/play/rl-video-step-0.mp4 ] && mv $tmp/videos/play/rl-video-step-0.mp4 $OUT/$name.mp4 || { echo NO_CLIP; tail -n 20 $OUT/$name.full.log; }
rm -rf $tmp
echo "=== SEEDTAKE_END $name ==="
