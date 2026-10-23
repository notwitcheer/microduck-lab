#!/bin/bash
# bg3-probe-2026-10-03.sh: cfg check + exact-argv resume probe for back-getup v3 (body's train + export argv),
# 64 envs (card shared with the gpqa leg), 3 iterations from the v2 seed, THROWAWAY experiment probe-backgetup3.
L=/home/witcheer/Pollen/clips/backgetup3-2026-10-03; mkdir -p $L
exec > >(tee -a $L/probe.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
RL=/home/witcheer/Pollen/microduck_rl; cd $RL
echo "=== $(date -u +%T) cfg check ==="
uv run python - <<'PY'
import mjlab_microduck.tasks  # registers
from mjlab.tasks.registry import load_env_cfg, load_rl_cfg
for tid in ("Mjlab-StandUp-Flat-MicroDuck","Mjlab-StandUpBack2-Flat-MicroDuck","Mjlab-StandUpBack3-Flat-MicroDuck"):
    c=load_env_cfg(tid); r=load_rl_cfg(tid)
    ar=c.rewards["action_rate_l2"].weight; st=c.curriculum["action_rate_weight"].params["weight_stages"]
    ev={k:v for k,v in c.events["set_ground_state"].params.items() if k.endswith("_prob")}
    gs=c.curriculum["ground_state_mix"].params["param_stages"]
    print(tid, "| action_rate", ar, "stages", st[-1], len(st), "| body_ang_vel", c.rewards["body_ang_vel"].weight,
          "| turnover", getattr(c.rewards.get("supine_turnover_progress"), "func", None).__name__ if c.rewards.get("supine_turnover_progress") else None,
          "| ent", r.algorithm.entropy_coef, "| spawn ev", ev, "| spawn cur", gs[-1]["params"], len(gs))
PY
echo "cfgcheck rc=$?"
TASK=Mjlab-StandUpBack3-Flat-MicroDuck; EXP=probe-backgetup3; SEED=2026-10-03_00-00-00_seed-backgetup2-it31000
rm -rf logs/rsl_rl/$EXP; mkdir -p logs/rsl_rl/$EXP/$SEED
cp logs/rsl_rl/duckbackgetup3/$SEED/model_31000.pt logs/rsl_rl/$EXP/$SEED/
echo "=== $(date -u +%T) resume probe $TASK ==="
t0=$(date +%s)
timeout --signal=INT --kill-after=60 900 uv run train "$TASK" --env.scene.num-envs 64 \
  --agent.max-iterations 3 --agent.save-interval 1 --agent.logger tensorboard \
  --agent.experiment-name "$EXP" --agent.run-name "$EXP" --video True --video-interval 1 --video-length 50 \
  --agent.resume True --agent.load-run $SEED --agent.load-checkpoint model_31000.pt; rc=$?
echo "train rc=$rc in $(( $(date +%s)-t0 )) s"
run=$(ls -d logs/rsl_rl/$EXP/*_$EXP/ 2>/dev/null | tail -1); echo "run dir: $run"; ls "$run"
ck=$(ls "$run"/model_*.pt 2>/dev/null | sort -V | tail -1); echo "last ckpt: $ck"
timeout 600 uv run scripts/export.py "$TASK" --checkpoint-file "$ck" --onnx-file /tmp/probe-backgetup3.onnx; echo "export rc=$? size=$(stat -c %s /tmp/probe-backgetup3.onnx 2>/dev/null)"
echo "=== $(date -u +%T) PROBE_END ==="
