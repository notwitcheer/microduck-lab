#!/bin/bash
# e2e-hop-2026-10-27.sh: e2e clone of the shared duck body for the NEW task id of 09z16 (hop; the item's EXTRA_TRAIN_ARGS entropy 0.02 and the std-bumped seed are exercised too). NOT a queue item. leg 1 = forced deadline cut
# (rc 124, exit 3, Donald restored), leg 2 = resume from leg 1's checkpoint to completion + export (exit 0). SKILL=e2ehop (own manifest,
# exp, run log, onnx), ENVS=512, SAVE_EVERY=10. seed copied under logs/rsl_rl/duckhope2e/. DUCK_LANE_OFF=1 so the forced epoch never touches
# ~/duck-lane-state (backup ~/duck-lane-state.bak-09z16-2026-10-27, cmp after). refuses to start if a GPU process other than Donald's is on the card.
# cleanup (separate step afterwards): logs/rsl_rl/duckhope2e, ~/duckhope2e-run.log... see the log.
exec >> /home/witcheer/Pollen/e2e-hop-2026-10-27.log 2>&1
RL=/home/witcheer/Pollen/microduck_rl
donald=$(systemctl show -p MainPID --value llama-server.service); dp=" $donald $(pgrep -P "$donald" | tr '\n' ' ') "
for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader | tr -d ' '); do case "$dp" in *" $p "*) ;; *) echo "foreign GPU pid $p, not starting"; exit 3;; esac; done
[ -e /home/witcheer/sparkagent-BUSY ] && { echo "sparkagent-BUSY present, not starting"; exit 3; }
tmux ls -F '#{session_name}' | grep -E '^(vx-|voxel-|hmrun|idleq$)' && { echo "bench tmux alive, not starting"; exit 3; }
SEED=$RL/logs/rsl_rl/duckhop/2026-10-27_00-00-00_seed-velbl-it7000-std06/model_7000.pt
D=$RL/logs/rsl_rl/duckhope2e/2026-10-27_00-00-00_seed-velbl-it7000-std06
mkdir -p $D && cp $SEED $D/model_7000.pt && md5sum $SEED $D/model_7000.pt
export DUCK_LANE_OFF=1 SKILL=hope2e TASK=Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck ENVS=512 SAVE_EVERY=10 VIDEO_EVERY=500
export TARGET_IT=9000
export EXTRA_TRAIN_ARGS="--agent.algorithm.entropy-coef 0.02"
export NL_HARD_STOP_EPOCH=$(( $(date +%s) + 600 + 200 ))
echo "=== $(date -u +%T) LEG1 TARGET_IT=$TARGET_IT (forced deadline $(date -u -d @$NL_HARD_STOP_EPOCH +%T) UTC) ==="
bash /home/witcheer/Pollen/duck-train-body.sh; echo "LEG1 exit=$?"
unset NL_HARD_STOP_EPOCH
N=$(ls $RL/logs/rsl_rl/duckhope2e/*/model_*.pt | sed 's/.*model_//; s/.pt//' | sort -n | tail -n 1)
export TARGET_IT=$(( N + 20 ))
echo "=== $(date -u +%T) LEG2 resume from model_$N, TARGET_IT=$TARGET_IT ==="
bash /home/witcheer/Pollen/duck-train-body.sh; echo "LEG2 exit=$?"
echo "=== $(date -u +%T) E2E_END ==="; nvidia-smi --query-gpu=memory.used --format=csv,noheader; curl -s -m 5 localhost:8090/health; echo
ls -la /home/witcheer/Pollen/policies-ours/hope2e-* 2>/dev/null; cat /home/witcheer/duckhope2e-status.json
