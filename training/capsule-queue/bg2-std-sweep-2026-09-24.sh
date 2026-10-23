#!/bin/bash
# bg2-std-sweep.sh: does the 2x std bump survive? 100 iterations from the std-bumped seed per entropy_coef, throwaway experiments.
exec > >(tee -a /home/witcheer/Pollen/clips/backgetup2-2026-09-24/std-sweep.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
TASK=Mjlab-StandUpBack2-Flat-MicroDuck; SEED=2026-09-24_00-00-00_seed-backgetup-it28000-std2x
for ENT in 0.01 0.02 0.03; do
  EXP=probe-bg2-ent$ENT; rm -rf logs/rsl_rl/$EXP; mkdir -p logs/rsl_rl/$EXP/$SEED
  cp logs/rsl_rl/duckbackgetup2/$SEED/model_28000.pt logs/rsl_rl/$EXP/$SEED/
  echo "=== $(date -u +%T) entropy_coef $ENT ==="
  timeout --signal=INT 600 uv run train "$TASK" --env.scene.num-envs 4096 --agent.max-iterations 101 --agent.save-interval 50 \
    --agent.logger tensorboard --agent.experiment-name "$EXP" --agent.run-name "$EXP" --agent.algorithm.entropy-coef $ENT \
    --agent.resume True --agent.load-run $SEED --agent.load-checkpoint model_28000.pt > /home/witcheer/Pollen/clips/backgetup2-2026-09-24/std-sweep-ent$ENT.log 2>&1
  echo "rc=$?"; grep -m1 -E "entropy_coef" /home/witcheer/Pollen/clips/backgetup2-2026-09-24/std-sweep-ent$ENT.log
done
echo "=== $(date -u +%T) STD_SWEEP_END ==="; nvidia-smi --query-gpu=memory.used --format=csv,noheader
