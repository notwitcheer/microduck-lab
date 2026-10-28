#!/bin/bash
# proof-gm-common-2026-10-28.sh: play() for the gale / moon proof takes (09z19 / 09z21). like proof-hop-common.sh, but runs gm_play.py (headless_play + `--gm-log`: one [gm] line per 20 ms
# policy step: fwd / lat displacement, trunk z, tilt, forward lean, both-feet-in-the-air flag, peak servo torque, wind force) and keeps the [gm] lines in the take log. source after setting OUT.
# env: GM_VIDEO=1 (default) writes the mp4; 0 = logs only (the reported / no-loss batches). parallel batches: the tmp dir is keyed by batch (basename of OUT) + take name.
# GM_DEVICE=cpu runs the sim on the CPU (the e2e / DRYRUN-adjacent checks only; the real item runs on the card).
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
  local vid="--video False"; [ "${GM_VIDEO:-1}" = 1 ] && vid="--video True --video-length $steps --video-width 1280 --video-height 720"
  local dev=""; [ -n "${GM_DEVICE:-}" ] && dev="--device $GM_DEVICE"
  timeout 900 uv run python gm_play.py "$task" --checkpoint-file "$tmp/$(basename "$ck")" --num-envs 1 $vid --steps $((steps+5)) --gm-log $dev "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "\[gm\]\|headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ "${GM_VIDEO:-1}" = 1 ]; then
    if [ -f "$tmp/videos/play/rl-video-step-0.mp4" ]; then mv "$tmp/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
  elif ! grep -aq "\[gm\] k=" $OUT/$name.log; then echo "NO_LOG $name"; tail -15 $OUT/$name.full.log; fi
  rm -rf $tmp
}
