#!/bin/bash
# probe-duck-warmstart.sh: exact-argv WARM-START probe for a duck item that resumes from another level's checkpoint
# (backlash twins, env forks). copies the seed under the probe experiment (mjlab resolves --agent.load-run RELATIVE to
# logs/rsl_rl/<experiment-name>/), resumes 40 iterations, samples VRAM, then runs the maker's export.py.
# usage (on capsule, in a detached tmux):
#   bash probe-duck-warmstart.sh <skill> <TaskId> <abs path of seed model_N.pt> [envs]
#   e.g. bash probe-duck-warmstart.sh vsbl Mjlab-VelStand-Flat-Backlash-MicroDuck \
#        /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstand/<run>/model_20000.pt 4096
# envs default 4096 = the item's real pace; only valid on a FREE card. with a bench leg on the card use 512 and treat the
# printed s/it as mechanics only (pace UNVERIFIED). ~2 min of card time, allowed outside heures creuses.
# pass: "Loading model checkpoint from" with no size mismatch, train rc 0, export rc 0 with a ~794 KB onnx.
# afterwards: rm -rf logs/rsl_rl/probe-<skill> /tmp/probe-<skill>.onnx
exec > >(tee -a /home/witcheer/Pollen/probe-$1.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
s=${1:?skill}; T=${2:?task id}; SEEDPT=${3:?seed checkpoint}; ENVS=${4:-4096}
exp=probe-$s; N=$(basename "$SEEDPT" .pt | sed 's/model_//'); seed=seed-it$N
mkdir -p logs/rsl_rl/$exp/$seed && cp "$SEEDPT" logs/rsl_rl/$exp/$seed/model_$N.pt
echo "=== $(date -u +%T) warm-start probe $T from $SEEDPT at $ENVS envs ==="
( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > /home/witcheer/Pollen/probe-$s-vram.log & SP=$!
t0=$(date +%s)
timeout 900 uv run train "$T" --env.scene.num-envs "$ENVS" --agent.max-iterations 41 --agent.save-interval 20 --agent.logger tensorboard \
  --agent.experiment-name "$exp" --agent.run-name "$exp" --video True --video-interval 20 --video-length 30 \
  --agent.resume True --agent.load-run "$seed" --agent.load-checkpoint model_$N.pt; rc=$?
kill $SP 2>/dev/null
echo "train rc=$rc in $(( $(date +%s)-t0 )) s; card peak MiB (includes any other tenant): $(sort -n /home/witcheer/Pollen/probe-$s-vram.log | tail -1)"
run=$(ls -d logs/rsl_rl/$exp/*_$exp/ 2>/dev/null | tail -1)
ck=$(ls "$run"/model_*.pt 2>/dev/null | sort -V | tail -1)
echo "run dir: $run  last ckpt: $ck"
if [ -n "$ck" ]; then
  timeout 600 uv run scripts/export.py "$T" --checkpoint-file "$ck" --onnx-file /tmp/probe-$s.onnx; rc=$?
  echo "export rc=$rc size=$(stat -c %s /tmp/probe-$s.onnx 2>/dev/null)"
else echo "NO CHECKPOINT"; fi
grep -a "Iteration time" /home/witcheer/Pollen/probe-$s.log | tail -5
echo "=== $(date -u +%T) PROBE_END ==="
