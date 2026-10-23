#!/bin/bash
# duck-0921-groundpick.sh: exact-argv probe for skill-tree level 8 (GroundPick), then header DRYRUN from queue-staging.
exec > >(tee -a /home/witcheer/Pollen/duck-0921-groundpick.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
s=groundpick; t=Mjlab-GroundPick-Flat-MicroDuck; exp=probe-$s
echo "=== $(date -u +%T) probe $t ==="
t0=$(date +%s)
timeout 900 uv run train "$t" --env.scene.num-envs 64 --agent.max-iterations 2 --agent.save-interval 1 --agent.logger tensorboard \
  --agent.experiment-name "$exp" --agent.run-name "$exp" --video True --video-interval 1 --video-length 30 > /tmp/probe-$s.out 2>&1; rc=$?
echo "train rc=$rc in $(( $(date +%s)-t0 )) s"; [ $rc -ne 0 ] && tail -15 /tmp/probe-$s.out
run=$(ls -d logs/rsl_rl/$exp/*/ 2>/dev/null | tail -1)
echo "run dir: $run"; ls "$run" 2>/dev/null | tr '\n' ' '; echo; ls "$run/videos/train" 2>/dev/null | tr '\n' ' '; echo
ck=$(ls "$run"/model_*.pt 2>/dev/null | tail -1)
if [ -n "$ck" ]; then
  timeout 600 uv run scripts/export.py "$t" --checkpoint-file "$ck" --onnx-file /tmp/probe-$s.onnx > /tmp/probe-$s-export.out 2>&1; rc=$?
  echo "export rc=$rc size=$(stat -c %s /tmp/probe-$s.onnx 2>/dev/null)"; [ $rc -ne 0 ] && tail -10 /tmp/probe-$s-export.out
else echo "NO CHECKPOINT"; fi
echo "=== $(date -u +%T) HEADER ==="
H=/home/witcheer/Pollen/queue-staging/09g-duck-groundpick.sh
cat > $H <<'EOF'
#!/bin/bash
# 09g-duck-groundpick.sh: duck skill tree level 8, crouch and bring the beak tip to the ground without touching it, back to a clean stand (the precision level).
# Pollen task Mjlab-GroundPick-Flat-MicroDuck (tasks/__init__.py), maker budget 20_000 (microduck_ground_pick_env_cfg.py max_iterations); ours the same.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=groundpick
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckgroundpick-status.json
TASK=Mjlab-GroundPick-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-20000}
. /home/witcheer/Pollen/duck-train-body.sh
EOF
bash -n $H && echo "bash -n ok"
DRYRUN=1 bash $H 2>&1 | tail -12
echo "=== $(date -u +%T) CLEANUP ==="
rm -rf logs/rsl_rl/$exp /tmp/probe-$s.onnx /home/witcheer/duckgroundpick-status.json
ls logs/rsl_rl/ | tr '\n' ' '; echo
echo "=== $(date -u +%T) GROUNDPICK_END ==="
nvidia-smi --query-gpu=memory.used --format=csv,noheader
