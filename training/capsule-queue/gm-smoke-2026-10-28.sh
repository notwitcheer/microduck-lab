#!/bin/bash
# gm-smoke-2026-10-28.sh <gale|moon> [envs, default 16]: CPU-ONLY exact-argv smoke of a gale / moon TRAIN item (no card, no Donald drain, nothing queued): resume from the item's seed copy, 4 iterations at 16 envs
# (`--gpu-ids None`, the way the 2026-10-27 tug e2e ran on the CPU), the item's flags (--agent.save-interval, --agent.logger tensorboard, --video True small), then the maker's export.py on the CPU.
# pass = "Loading model checkpoint" with no size mismatch, train rc 0, a model_N.pt written, export rc 0 with a ~794 KB onnx. afterwards (separate steps): rm -rf logs/rsl_rl/smoke-<skill> /tmp/smoke-<skill>.onnx.
# this is NOT the 4096-env pace probe (that needs the card): the pace in the item header is the 09z14 in-block pace, UNVERIFIED for this task.
exec > >(tee -a /home/witcheer/Pollen/gm-smoke-$1.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl CUDA_VISIBLE_DEVICES=""
M=${1:?gale|moon}; ENVS=${2:-16}
case $M in gale) T=Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck;; moon) T=Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck;; *) exit 2;; esac
cd /home/witcheer/Pollen/microduck_rl
SEEDPT=$(ls -1 logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt); exp=smoke-$M; seed=2026-10-28_00-00-00_seed-velbl-it7000
# the maker's resume path torch.loads a CUDA-saved checkpoint without map_location (found 2026-10-28: "Attempting to deserialize object on a CUDA device but torch.cuda.is_available() is False"), so the CPU smoke
# resumes from a CPU-mapped copy of the same weights (same tensors, device only; the real item on the card loads the original).
mkdir -p logs/rsl_rl/$exp/$seed && .venv/bin/python -c "import torch,sys; d=torch.load(sys.argv[1], map_location='cpu', weights_only=False); torch.save(d, sys.argv[2])" "$SEEDPT" logs/rsl_rl/$exp/$seed/model_7000.pt && md5sum "$SEEDPT" logs/rsl_rl/$exp/$seed/model_7000.pt
echo "=== $(date -u +%T) CPU smoke $T at $ENVS envs from $SEEDPT ==="
t0=$(date +%s)
timeout 900 nice -n 15 uv run train "$T" --env.scene.num-envs "$ENVS" --agent.max-iterations 4 --agent.save-interval 2 --agent.logger tensorboard \
  --agent.experiment-name "$exp" --agent.run-name "$exp" --video True --video-interval 2 --video-length 20 \
  --agent.resume True --agent.load-run "$seed" --agent.load-checkpoint model_7000.pt --gpu-ids None; rc=$?
echo "train rc=$rc in $(( $(date +%s)-t0 )) s"
run=$(ls -d logs/rsl_rl/$exp/*_$exp/ 2>/dev/null | tail -1); ck=$(ls "$run"/model_*.pt 2>/dev/null | sort -V | tail -1)
echo "run dir: $run  last ckpt: $ck  all: $(ls $run | tr '\n' ' ')"
if [ -n "$ck" ]; then timeout 600 nice -n 15 uv run scripts/export.py "$T" --checkpoint-file "$ck" --onnx-file /tmp/smoke-$M.onnx --device cpu; echo "export rc=$? size=$(stat -c %s /tmp/smoke-$M.onnx 2>/dev/null)"; else echo "NO CHECKPOINT"; fi
echo "=== $(date -u +%T) SMOKE_END ==="
