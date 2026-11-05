#!/bin/bash
# strict-takes-2026-10-29.sh: N 1-env CPU takes (no video unless STRICT_VIDEO=1) of one checkpoint with the per-body floor-contact log (strict_play.py --hop-log --strict-log).
# usage: [OUTBASE=<dir, default ~/Pollen/hop2-dev>] bash strict-takes-2026-10-29.sh <out dir under OUTBASE> <prefix> <checkpoint .pt> [N takes, default 8] [parallel, default 6] [task id, default the hop v1 task]
# CPU only (CUDA_VISIBLE_DEVICES empty, --device cpu), nice 19. HOP2_DEV=1 puts ~/Pollen/hop2-dev/src first on PYTHONPATH (the scratch copy that holds the hop2 module).
# play env: zero command, no shoves, 6 s episode. read with: python3 ~/Pollen/hop2-score-2026-10-29.py --dir ~/Pollen/hop2-dev/<out> <prefix>
OUT=${OUTBASE:-$HOME/Pollen/hop2-dev}/${1:?out}; PFX=${2:?prefix}; CK=${3:?ckpt}; N=${4:-8}; PAR=${5:-6}; TASK=${6:-Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck}
mkdir -p "$OUT"; cd $HOME/Pollen/microduck_rl || exit 2
export PATH=$HOME/.local/bin:$PATH MUJOCO_GL=egl CUDA_VISIBLE_DEVICES=""
[ "${HOP2_DEV:-0}" = 1 ] && export PYTHONPATH=$HOME/Pollen/hop2-dev/src
[ -f "$CK" ] || { echo "NO_CHECKPOINT $CK"; exit 2; }
VID="--video False"; EXTRA=""
if [ "${STRICT_VIDEO:-0}" = 1 ]; then VID="--video True --video-length 300 --video-width 1280 --video-height 720"; EXTRA="--cam-world auto --cam-world-z 0.08 --cam-distance 0.7 --cam-elevation -5 --cam-azimuth 110"; fi
one() { local i=$1; local tmp=$OUT/tmp-$PFX-$i; rm -rf $tmp; mkdir -p $tmp; cp "$CK" $tmp/; cp -r "$(dirname "$CK")/params" $tmp/ 2>/dev/null
  nice -n 19 timeout 900 .venv/bin/python $HOME/Pollen/hop2-dev/strict_play.py $TASK --checkpoint-file $tmp/$(basename "$CK") --num-envs 1 $VID --steps 305 --hop-log --strict-log --episode-s 6 --no-push $EXTRA --device cpu > $OUT/$PFX-t$i.full.log 2>&1
  grep -a "\[strict\] \(k=\|bodies\)\|\[hop\] k=\|RESET\|Error\|Traceback\|Loading" $OUT/$PFX-t$i.full.log > $OUT/$PFX-t$i.log
  [ -f $tmp/videos/play/rl-video-step-0.mp4 ] && mv $tmp/videos/play/rl-video-step-0.mp4 $OUT/$PFX-t$i.mp4
  rm -rf $tmp; }
i=1; while [ $i -le $N ]; do
  for j in $(seq 1 $PAR); do [ $i -le $N ] && { one $i & i=$((i+1)); }; done; wait
done
echo "=== $(date -u +%T) TAKES_END $PFX n=$N ==="
