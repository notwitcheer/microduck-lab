#!/bin/bash
# e2e-dribble-2026-10-27.sh: e2e clone of the shared duck body for the NEW task id of 09z14. NOT a queue item. leg 1 = forced deadline cut (rc 124, exit 3, Donald restored), leg 2 = resume from leg 1's
# checkpoint to completion + export (exit 0). SKILL=dribblee2e (own manifest, exp, run log, onnx), ENVS=512, SAVE_EVERY=10. seed copied under logs/rsl_rl/duckdribblee2e/. DUCK_LANE_OFF=1 so the forced epoch never
# touches ~/duck-lane-state (backup ~/duck-lane-state.bak-09z14-2026-10-27 made by the caller, cmp after). waits for a free card like dribble-wrap-2026-10-27.sh (BUSY flags, vx/voxel/hmrun/idleq tmux, foreign GPU pid).
exec >> /home/witcheer/Pollen/e2e-dribble-2026-10-27.log 2>&1
RL=/home/witcheer/Pollen/microduck_rl
donald_pids() { local m; m=$(systemctl show -p MainPID --value llama-server.service 2>/dev/null); [ -n "$m" ] && [ "$m" != 0 ] || return 0
  echo "$m"; pgrep -P "$m"; for c in $(pgrep -P "$m"); do pgrep -P "$c"; done; }
foreign() { local dp; dp=" $(donald_pids | tr '\n' ' ') "
  for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader | tr -d ' '); do case "$dp" in *" $p "*) ;; *) echo "$p";; esac; done; }
blocked() {
  local b; b=$(ls /home/witcheer/*-BUSY 2>/dev/null | grep -v "/dribble-BUSY$" | tr '\n' ' '); [ -n "$b" ] && { echo "BUSY flag: $b"; return 0; }
  local t; t=$(tmux ls -F '#{session_name}' 2>/dev/null | grep -E '^(vx-|voxel-|hmrun|idleq$)' | tr '\n' ' '); [ -n "$t" ] && { echo "tmux alive: $t"; return 0; }
  local f; f=$(foreign | tr '\n' ' '); [ -n "$f" ] && { echo "foreign GPU pids: $f"; return 0; }
  systemctl is-active --quiet llama-server.service || { echo "llama-server.service inactive"; return 0; }
  return 1; }
if [ "${E2E_NOWAIT:-0}" != 1 ]; then   # E2E_NOWAIT=1: run inside a dribble-wrap slot that already holds the card (flag + Donald drained)
last=""
while :; do
  while :; do
    [ "$(date -u +%H%M)" -lt 1230 ] || { echo "$(date -u +%T) 12:30 UTC reached, not running"; exit 3; }
    why=$(blocked) || break
    [ "$why" != "$last" ] && echo "$(date -u +%T) waiting: $why"; last=$why; sleep 30
  done
  echo "$(date -u +%T) card looks free, settling 90 s"; sleep 90; why=$(blocked) || break; last=$why
done
  date '+%F %T dribble e2e holds the card' > /home/witcheer/dribble-BUSY; trap 'rm -f /home/witcheer/dribble-BUSY' EXIT
fi
SEED=$(ls $RL/logs/rsl_rl/duckdribble/*seed-velstairs-it19000/model_19000.pt | tail -n 1)
D=$RL/logs/rsl_rl/duckdribblee2e/2026-10-27_00-00-00_seed-velstairs-it19000
mkdir -p $D && cp $SEED $D/model_19000.pt && md5sum $SEED $D/model_19000.pt
export DUCK_LANE_OFF=1 SKILL=dribblee2e TASK=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck ENVS=512 SAVE_EVERY=10 VIDEO_EVERY=500
export TARGET_IT=20500
export NL_HARD_STOP_EPOCH=$(( $(date +%s) + 600 + 200 ))
echo "=== $(date -u +%T) LEG1 TARGET_IT=$TARGET_IT (forced deadline $(date -u -d @$NL_HARD_STOP_EPOCH +%T) UTC) ==="
bash /home/witcheer/Pollen/duck-train-body.sh; echo "LEG1 exit=$?"
unset NL_HARD_STOP_EPOCH
N=$(ls $RL/logs/rsl_rl/duckdribblee2e/*/model_*.pt | sed 's/.*model_//; s/.pt//' | sort -n | tail -n 1)
export TARGET_IT=$(( N + 20 ))
echo "=== $(date -u +%T) LEG2 resume from model_$N, TARGET_IT=$TARGET_IT ==="
bash /home/witcheer/Pollen/duck-train-body.sh; echo "LEG2 exit=$?"
echo "=== $(date -u +%T) E2E_END ==="; nvidia-smi --query-gpu=memory.used --format=csv,noheader; curl -s -m 5 localhost:8090/health; echo
ls -la /home/witcheer/Pollen/policies-ours/dribblee2e-* 2>/dev/null; cat /home/witcheer/duckdribblee2e-status.json
