#!/bin/bash
# bg2-resume-probe.sh: exact-argv resume probe for back-getup v2 (duck-train-body.sh's train + export commands),
# 4096 envs, 300 iterations from the std-bumped seed, in a THROWAWAY experiment (probe-backgetup2) so the real item starts at 28000.
exec > >(tee -a /home/witcheer/Pollen/clips/backgetup2-2026-09-24/resume-probe300.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
RL=/home/witcheer/Pollen/microduck_rl; cd $RL
TASK=Mjlab-StandUpBack2-Flat-MicroDuck; EXP=probe-backgetup2; SEED=2026-09-24_00-00-00_seed-backgetup-it28000-std2x
rm -rf logs/rsl_rl/$EXP; mkdir -p logs/rsl_rl/$EXP/$SEED
cp logs/rsl_rl/duckbackgetup2/$SEED/model_28000.pt logs/rsl_rl/$EXP/$SEED/
nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -lms 2000 > /home/witcheer/Pollen/clips/backgetup2-2026-09-24/resume-probe300-vram.csv & SMI=$!
echo "=== $(date -u +%T) resume probe $TASK ==="
t0=$(date +%s)
timeout --signal=INT --kill-after=60 1200 uv run train "$TASK" --env.scene.num-envs 4096 \
  --agent.max-iterations 301 --agent.save-interval 100 --agent.logger tensorboard \
  --agent.experiment-name "$EXP" --agent.run-name "$EXP" --video True --video-interval 100 --video-length 300 \
  --agent.resume True --agent.load-run $SEED --agent.load-checkpoint model_28000.pt; rc=$?
echo "train rc=$rc in $(( $(date +%s)-t0 )) s"
kill $SMI 2>/dev/null
run=$(ls -d logs/rsl_rl/$EXP/*_$EXP/ 2>/dev/null | tail -1); echo "run dir: $run"; ls "$run"; ls "$run/videos/train" 2>/dev/null | head
ck=$(ls "$run"/model_*.pt 2>/dev/null | sort -V | tail -1); echo "last ckpt: $ck"
timeout 600 uv run scripts/export.py "$TASK" --checkpoint-file "$ck" --onnx-file /tmp/probe-backgetup2.onnx; echo "export rc=$? size=$(stat -c %s /tmp/probe-backgetup2.onnx 2>/dev/null)"
echo "VRAM peak MiB: $(sort -n /home/witcheer/Pollen/clips/backgetup2-2026-09-24/resume-probe300-vram.csv | tail -1)"
echo "=== $(date -u +%T) RESUME_PROBE_END ==="
nvidia-smi --query-gpu=memory.used --format=csv,noheader
