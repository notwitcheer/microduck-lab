#!/bin/bash
# proof-hop-common.sh (2026-10-27): play() for hop takes. like proof-common.sh, but runs hop_play.py (headless_play + `--hop-log`: one [hop] line per 20 ms step with
# air / trunk z / lower-foot lift / tilt / peak servo torque / foot forces) and keeps the [hop] lines in the take log. source after setting OUT. env: HOP_VIDEO=1 (default) writes the mp4.
# parallel batches: the tmp dir is keyed by batch (basename of OUT) + take name, so take names must also carry a per-batch prefix.
exec > >(tee -a $OUT.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
mkdir -p $OUT
play() { local name=$1 task=$2 ck=$3 steps=$4; shift 4
  local tmp=/home/witcheer/Pollen/clips/tmp-play-$(basename $OUT)-$name; rm -rf $tmp
  echo "=== $(date -u +%T) take $name ($task) ==="; local t0=$(date +%s)
  mkdir -p $tmp; cp "$ck" $tmp/; cp -r "$(dirname "$ck")/params" $tmp/ 2>/dev/null
  local vid="--video False"; [ "${HOP_VIDEO:-1}" = 1 ] && vid="--video True --video-length $steps --video-width 1280 --video-height 720"
  timeout 900 uv run python hop_play.py "$task" --checkpoint-file "$tmp/$(basename "$ck")" --num-envs 1 $vid --steps $((steps+5)) --hop-log "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "\[hop\]\|headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ "${HOP_VIDEO:-1}" = 1 ]; then
    if [ -f "$tmp/videos/play/rl-video-step-0.mp4" ]; then mv "$tmp/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
  elif ! grep -aq "\[hop\] k=" $OUT/$name.log; then echo "NO_LOG $name"; tail -15 $OUT/$name.full.log; fi
  rm -rf $tmp
}
