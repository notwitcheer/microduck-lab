#!/bin/bash
# velbl-probe.sh: exact-argv WARM-START probe for 09y-duck-velroughbl before it enters the idle queue.
# seed = duckvelrough model_8000 (level 4 walk-rough, 2026-09-19) copied under the probe experiment, resumed on
# Mjlab-Velocity-Flat-Backlash-MicroDuck at 4096 envs for 40 iterations (s/it + VRAM), then the maker's export.py.
# short probe (~2 min of card time), allowed outside heures creuses. afterwards: rm -rf logs/rsl_rl/probe-vrbl /tmp/probe-vrbl.onnx
exec > >(tee -a /home/witcheer/Pollen/probe-vrbl.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
T=Mjlab-Velocity-Rough-Backlash-MicroDuck; exp=probe-vrbl; seed=2026-10-08_00-00-00_seed-velrough-it8000
mkdir -p logs/rsl_rl/$exp/$seed
cp logs/rsl_rl/duckvelrough/2026-09-19_02-53-18_duckvelrough/model_8000.pt logs/rsl_rl/$exp/$seed/model_8000.pt
echo "=== $(date -u +%T) warm-start probe $T ==="
( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > /home/witcheer/Pollen/probe-vrbl-vram.log & SP=$!
t0=$(date +%s)
timeout 900 uv run train "$T" --env.scene.num-envs 4096 --agent.max-iterations 41 --agent.save-interval 20 --agent.logger tensorboard \
  --agent.experiment-name "$exp" --agent.run-name "$exp" --video True --video-interval 20 --video-length 30 \
  --agent.resume True --agent.load-run "$seed" --agent.load-checkpoint model_8000.pt; rc=$?
kill $SP 2>/dev/null
echo "train rc=$rc in $(( $(date +%s)-t0 )) s; VRAM peak MiB: $(sort -n /home/witcheer/Pollen/probe-vrbl-vram.log | tail -1)"
ls -d logs/rsl_rl/$exp/*/
run=$(ls -d logs/rsl_rl/$exp/*_$exp/ 2>/dev/null | tail -1)
echo "run dir: $run"; ls "$run" 2>/dev/null | head; ls "$run/videos/train" 2>/dev/null | head
ck=$(ls "$run"/model_*.pt 2>/dev/null | sort -V | tail -1)
echo "last ckpt: $ck"
if [ -n "$ck" ]; then
  timeout 600 uv run scripts/export.py "$T" --checkpoint-file "$ck" --onnx-file /tmp/probe-vrbl.onnx; rc=$?
  echo "export rc=$rc size=$(stat -c %s /tmp/probe-vrbl.onnx 2>/dev/null)"
else echo "NO CHECKPOINT"; fi
echo "=== $(date -u +%T) PROBE_END ==="
nvidia-smi --query-gpu=memory.used --format=csv,noheader
