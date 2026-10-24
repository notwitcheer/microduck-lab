#!/bin/bash
# probe-duck-task.sh: exact-argv probe for a NEW skill-tree task id before its header enters the idle queue.
# 64 envs, 2 iterations, video on, then the maker's export.py. ~30 s of card time on a 5090, so allowed outside
# heures creuses. DRYRUN never runs the train command; this is what catches a bad flag or a missing env var.
# usage (on capsule): bash probe-duck-task.sh <skill> <TaskId>     e.g. bash probe-duck-task.sh velrough Mjlab-Velocity-Rough-MicroDuck
# afterwards: rm -rf logs/rsl_rl/probe-<skill> /tmp/probe-<skill>.onnx so the real item starts clean.
exec > >(tee -a /home/witcheer/Pollen/probe-tasks.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
s=${1:?skill}; t=${2:?task id}; exp=probe-$s
echo "=== $(date -u +%T) probe $t ==="
t0=$(date +%s)
timeout 900 uv run train "$t" --env.scene.num-envs 64 --agent.max-iterations 2 --agent.save-interval 1 --agent.logger tensorboard \
  --agent.experiment-name "$exp" --agent.run-name "$exp" --video True --video-interval 1 --video-length 30; rc=$?
echo "train rc=$rc in $(( $(date +%s)-t0 )) s"
run=$(ls -d logs/rsl_rl/$exp/*/ 2>/dev/null | tail -1)
echo "run dir: $run"; ls "$run" 2>/dev/null; ls "$run/videos/train" 2>/dev/null
ck=$(ls "$run"/model_*.pt 2>/dev/null | tail -1)
if [ -n "$ck" ]; then
  timeout 600 uv run scripts/export.py "$t" --checkpoint-file "$ck" --onnx-file /tmp/probe-$s.onnx; rc=$?
  echo "export rc=$rc size=$(stat -c %s /tmp/probe-$s.onnx 2>/dev/null)"
else echo "NO CHECKPOINT"; fi
echo "=== $(date -u +%T) PROBE_END ==="
nvidia-smi --query-gpu=memory.used --format=csv,noheader
