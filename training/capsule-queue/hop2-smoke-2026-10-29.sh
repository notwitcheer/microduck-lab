#!/bin/bash
# hop2-smoke-2026-10-29.sh [envs, default 64] [iterations, default 6]: CPU-ONLY exact-argv smoke of the hop2 TRAIN task (no card, nothing queued) from the scratch tree ~/Pollen/hop2-dev/src (HOP2_DEV=1) or the real tree (HOP2_DEV=0):
# resume from a CPU-mapped copy of the std-0.6 hop seed (same tensors, device only), the item's flags (entropy 0.02, save interval, tensorboard), then the maker's export.py on the CPU.
# pass = "Loading model checkpoint" with no size mismatch, train rc 0, hop2_* reward terms printed, a model_N.pt, export rc 0 with a ~794 KB onnx. afterwards: rm -rf logs/rsl_rl/smoke-hop2 /tmp/smoke-hop2.onnx.
exec > >(tee -a /home/witcheer/Pollen/hop2-smoke.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl CUDA_VISIBLE_DEVICES=""
ENVS=${1:-64}; ITS=${2:-6}; T=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
[ "${HOP2_DEV:-1}" = 1 ] && export PYTHONPATH=/home/witcheer/Pollen/hop2-dev/src
cd /home/witcheer/Pollen/microduck_rl
SEEDPT=$(ls -1 logs/rsl_rl/duckhop/2026-10-27_00-00-00_seed-velbl-it7000-std06/model_7000.pt); exp=smoke-hop2; seed=2026-10-29_00-00-00_seed-hop-it7000
rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed && .venv/bin/python -c "import torch,sys; d=torch.load(sys.argv[1], map_location='cpu', weights_only=False); torch.save(d, sys.argv[2])" "$SEEDPT" logs/rsl_rl/$exp/$seed/model_7000.pt && md5sum "$SEEDPT" logs/rsl_rl/$exp/$seed/model_7000.pt
echo "=== $(date -u +%T) CPU smoke $T at $ENVS envs, $ITS it, dev tree=${HOP2_DEV:-1} term=${MICRODUCK_HOP2_TERM:-0} ==="
t0=$(date +%s)
timeout 1200 nice -n 15 uv run train "$T" --env.scene.num-envs "$ENVS" --agent.max-iterations $ITS --agent.save-interval 2 --agent.logger tensorboard \
  --agent.algorithm.entropy-coef 0.02 --agent.experiment-name "$exp" --agent.run-name "$exp" --video False \
  --agent.resume True --agent.load-run "$seed" --agent.load-checkpoint model_7000.pt --gpu-ids None > ~/Pollen/hop2-dev/smoke-train.log 2>&1; rc=$?
echo "train rc=$rc in $(( $(date +%s)-t0 )) s"
grep -a "Loading model checkpoint\|size mismatch\|Traceback\|Error" ~/Pollen/hop2-dev/smoke-train.log | head -5
grep -a "Episode_Reward/hop2\|Episode_Termination\|Mean reward" ~/Pollen/hop2-dev/smoke-train.log | tail -12
run=$(ls -d logs/rsl_rl/$exp/*_$exp/ 2>/dev/null | tail -1); ck=$(ls "$run"/model_*.pt 2>/dev/null | sort -V | tail -1)
echo "run dir: $run  last ckpt: $ck"
if [ -n "$ck" ]; then timeout 600 nice -n 15 uv run scripts/export.py "$T" --checkpoint-file "$ck" --onnx-file /tmp/smoke-hop2.onnx --device cpu > ~/Pollen/hop2-dev/smoke-export.log 2>&1; echo "export rc=$? size=$(stat -c %s /tmp/smoke-hop2.onnx 2>/dev/null)"; else echo "NO CHECKPOINT"; fi
echo "=== $(date -u +%T) SMOKE_END ==="
