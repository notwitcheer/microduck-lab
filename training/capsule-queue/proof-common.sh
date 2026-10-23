# proof-common.sh (2026-10-02): shared play() for the fri 14:10 proof-take batches. source after setting TASK, OUT.
# 2026-10-22: tmp dir keyed by batch (basename of OUT) + take name. before, two parallel batches with the same take names
# (proof-z5-a and proof-z6-a both used v2-a-tN) deleted each other's tmp-play dir and every z5-a v2 take lost its clip.
exec > >(tee -a $OUT.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
mkdir -p $OUT
play() { local name=$1 task=$2 ck=$3 vlen=$4; shift 4
  local tmp=/home/witcheer/Pollen/clips/tmp-play-$(basename $OUT)-$name; rm -rf $tmp
  echo "=== $(date -u +%T) clip $name ($task) ==="; local t0=$(date +%s)
  # each take writes into its own copy of the run dir's video path: copy the checkpoint so parallel batches never share videos/play
  mkdir -p $tmp; cp "$ck" $tmp/; cp -r "$(dirname "$ck")/params" $tmp/ 2>/dev/null
  timeout 900 uv run python headless_play.py "$task" --checkpoint-file "$tmp/$(basename "$ck")" --num-envs 1 --video True --video-length $vlen \
      --video-width 1280 --video-height 720 "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ -f "$tmp/videos/play/rl-video-step-0.mp4" ]; then mv "$tmp/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
  rm -rf $tmp
}
