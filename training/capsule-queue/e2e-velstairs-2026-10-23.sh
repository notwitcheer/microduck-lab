#!/bin/bash
# e2e-velstairs-2026-10-23.sh: e2e clone of the shared duck body for the NEW task id of 09z8. NOT a queue item. leg 1 = forced deadline cut
# (rc 124, exit 3, Donald restored), leg 2 = resume from leg 1's checkpoint to completion + export (exit 0). SKILL=e2evelstairs (own manifest,
# exp, run log, onnx), ENVS=512, SAVE_EVERY=10. seed copied under logs/rsl_rl/ducke2evelstairs/. DUCK_LANE_OFF=1 so the forced epoch never touches
# ~/duck-lane-state (backup ~/duck-lane-state.bak-09z8-2026-10-23, cmp after). refuses to start if a GPU process other than Donald's is on the card.
# cleanup (separate step afterwards): logs/rsl_rl/ducke2evelstairs, ~/duckvelstairse2e-run.log... see the log.
exec >> /home/witcheer/Pollen/e2e-velstairs-2026-10-23.log 2>&1
RL=/home/witcheer/Pollen/microduck_rl
donald=$(systemctl show -p MainPID --value llama-server.service); dp=" $donald $(pgrep -P "$donald" | tr '\n' ' ') "
for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader | tr -d ' '); do case "$dp" in *" $p "*) ;; *) echo "foreign GPU pid $p, not starting"; exit 3;; esac; done
[ -e /home/witcheer/sparkagent-BUSY ] && { echo "sparkagent-BUSY present, not starting"; exit 3; }
tmux ls -F '#{session_name}' | grep -E '^(vx-|voxel-|hmrun|idleq$)' && { echo "bench tmux alive, not starting"; exit 3; }
SEED=$RL/logs/rsl_rl/duckvelstairs/2026-10-23_00-00-00_seed-velmixslope-it16000/model_16000.pt
D=$RL/logs/rsl_rl/duckvelstairse2e/2026-10-23_00-00-00_seed-velmixslope-it16000
mkdir -p $D && cp $SEED $D/model_16000.pt && md5sum $SEED $D/model_16000.pt
export DUCK_LANE_OFF=1 SKILL=velstairse2e TASK=Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck ENVS=512 SAVE_EVERY=10 VIDEO_EVERY=500
export TARGET_IT=17500
export NL_HARD_STOP_EPOCH=$(( $(date +%s) + 600 + 200 ))
echo "=== $(date -u +%T) LEG1 TARGET_IT=$TARGET_IT (forced deadline $(date -u -d @$NL_HARD_STOP_EPOCH +%T) UTC) ==="
bash /home/witcheer/Pollen/duck-train-body.sh; echo "LEG1 exit=$?"
unset NL_HARD_STOP_EPOCH
N=$(ls $RL/logs/rsl_rl/duckvelstairse2e/*/model_*.pt | sed 's/.*model_//; s/.pt//' | sort -n | tail -n 1)
export TARGET_IT=$(( N + 20 ))
echo "=== $(date -u +%T) LEG2 resume from model_$N, TARGET_IT=$TARGET_IT ==="
bash /home/witcheer/Pollen/duck-train-body.sh; echo "LEG2 exit=$?"
echo "=== $(date -u +%T) E2E_END ==="; nvidia-smi --query-gpu=memory.used --format=csv,noheader; curl -s -m 5 localhost:8090/health; echo
ls -la /home/witcheer/Pollen/policies-ours/velstairse2e-* 2>/dev/null; cat /home/witcheer/duckvelstairse2e-status.json
