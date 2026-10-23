#!/bin/bash
exec > >(tee -a /home/witcheer/Pollen/clips/backgetup2-2026-09-24/turnover-probe.log) 2>&1
export PATH=/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
for CK in logs/rsl_rl/duckbackgetup/2026-09-24_16-01-44_duckbackgetup/model_28000.pt logs/rsl_rl/duckbackgetup/2026-09-24_00-00-00_seed-standup-it25000/model_25000.pt; do
  echo "=== $(date -u +%T) checkpoint $CK ==="
  timeout 600 uv run python turnover-probe.py Mjlab-StandUpBack2-Flat-MicroDuck --checkpoint-file $CK --num-envs 256 --probe-steps 290 2>&1 | grep -E "^\[probe\]|Error|Traceback|error" 
done
echo "=== $(date -u +%T) TURNOVER_PROBE_END ==="
nvidia-smi --query-gpu=memory.used --format=csv,noheader
