#!/bin/bash
# verdict-carpet.sh [A|B|AB] [CKPT_DIR_GLOB]: proof takes for 09u-duck-carpet (2026-10-05).
# A = falls + get-up in the branch's own VelStand-Flat env (worktree ~/Pollen/microduck_rl-carpet, all-collisions model,
#     play carpet stage = last severity stage at carpet_prob 0.5): trained carpet model vs our level 5 (velstand it20000),
#     forced spawns via headless_play.py (random_prone_init), 12 s one-episode takes, proof-verdicts.py --rise.
# B = walking on a 10 mm soft carpet (Pollen's infer_policy.py --carpet, the failure their commit reproduced at 98% falls):
#     the trained carpet ONNX vs our level 5 ONNX vs Pollen's shipped velstand.onnx, vx 0.30, 3 takes each, 12 s.
# usage before training finishes: MODE=baseline bash verdict-carpet.sh B  (level 5 + Pollen only).
set -uo pipefail
WHAT=${1:-AB}
WT=/home/witcheer/Pollen/microduck_rl-carpet
D=$(date +%F)
OUT=/home/witcheer/Pollen/clips/verdict-carpet-$D${MODE:+-$MODE}
TASK=Mjlab-VelStand-Flat-MicroDuck
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl PYTHONUNBUFFERED=1
# stdin from /dev/null for infer_policy: under tmux stdin is a TTY, keyboard control turns on and the take hangs (rc=124, 2026-10-05)
mkdir -p $OUT; exec > >(tee -a $OUT.log) 2>&1
cd $WT; for f in headless_play.py headless_record.py; do [ -f $f ] || cp /home/witcheer/Pollen/microduck_rl/$f .; done
# play builds the branch's PPO-with-BC runner, which loads the experts at construction (no wandb here)
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
L5PT=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstand/2026-09-20_10-27-52_duckvelstand/model_20000.pt
L5ONNX=/home/witcheer/Pollen/policies-ours/velstand-2026-09-20-it20000.onnx
POLLEN=/home/witcheer/Pollen/pollen-policies/velstand.onnx
[ -f $POLLEN ] || curl -sL -o $POLLEN https://huggingface.co/pollen-robotics/microduck-policies/resolve/main/velstand.onnx
CK=$(ls -d $WT/logs/rsl_rl/duckcarpet/*/model_*.pt 2>/dev/null | grep -v seed-walk | sort -t_ -k3 -V | tail -1)
CONNX=$(ls /home/witcheer/Pollen/policies-ours/carpet-*-it*.onnx 2>/dev/null | tail -1)
echo "carpet ckpt: ${CK:-none}  onnx: ${CONNX:-none}  mode: ${MODE:-full}"
play() { local name=$1 ck=$2; shift 2
  local tmp=/home/witcheer/Pollen/clips/tmp-play-$name; rm -rf $tmp; mkdir -p $tmp; cp "$ck" $tmp/
  echo "=== $(date -u +%T) clip $name ==="; local t0=$(date +%s)
  timeout 900 uv run python headless_play.py $TASK --checkpoint-file "$tmp/$(basename "$ck")" --num-envs 1 --video True --video-length 600 \
    --video-width 1280 --video-height 720 --episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8 "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  [ -f $tmp/videos/play/rl-video-step-0.mp4 ] && mv $tmp/videos/play/rl-video-step-0.mp4 $OUT/$name.mp4 || { echo "NO_CLIP $name"; tail -n 8 $OUT/$name.full.log; }
  rm -rf $tmp; }
rec() { local name=$1 onnx=$2
  echo "=== $(date -u +%T) carpet walk $name ==="
  timeout 300 uv run python headless_record.py --out $OUT/$name.mp4 --seconds 12 -- \
    --walking "$onnx" --new-cmd-obs --lin-vel-x 0.30 --carpet --carpet-thickness 10 < /dev/null > $OUT/$name.full.log 2>&1; echo "rc=$?"
  grep -a "vel 1s avg\|RESET\|fall\|wrote" $OUT/$name.full.log | tail -n 13; }
if [[ $WHAT == *A* ]]; then
  if [ -z "${MODE:-}" ] && [ -n "$CK" ]; then
    for i in 1 2 3 4 5; do play carpet-face_up-t$i $CK --spawn face_up; done
    for i in 1 2; do play carpet-face_down-t$i $CK --spawn face_down; play carpet-standing-t$i $CK --spawn standing; done
  fi
  for i in 1 2 3; do play l5-face_up-t$i $L5PT --spawn face_up; done
  echo "=== A_END ==="; python3 /home/witcheer/Pollen/proof-verdicts.py $OUT --end 11.9 --rise
fi
if [[ $WHAT == *B* ]]; then
  for i in 1 2 3; do rec l5-carpet-t$i $L5ONNX; rec pollen-carpet-t$i $POLLEN; done
  if [ -z "${MODE:-}" ] && [ -n "$CONNX" ]; then for i in 1 2 3; do rec ours-carpet-t$i $CONNX; done; fi
  echo "=== B_END ==="
fi
