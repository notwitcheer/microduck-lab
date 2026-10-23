#!/bin/bash
# probe-velstairs-wrap-2026-10-23.sh: 09z8 exact-argv warm-start probe on a free card, outside heures creuses (minutes of
# card time, allowed). waits for a free card (no BUSY flag, no vx/voxel/hmrun/idleq tmux, no foreign GPU pid), then the sanctioned
# drain (night-lib nl_donald_stop, EXIT trap nl_donald_restore), probe-duck-warmstart.sh at 4096 envs, restore + health check.
# refuses to start after 23:30 CEST (keeps the Sat 00:10 weekend drain clear; there is no weekday runner between 14:10 and 01:10).
# tmux "z8probe". log ~/Pollen/probe-velstairs-wrap.log
exec >> /home/witcheer/Pollen/probe-velstairs-wrap.log 2>&1
NL_TAG=z8probe; MANIFEST=/tmp/z8probe.json; export MANIFEST
. /home/witcheer/night-lib.sh
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelstairs/2026-10-23_00-00-00_seed-velmixslope-it16000/model_16000.pt
echo "$(date '+%F %T') wrap start, waiting for a free card"
# card-sharing rules (operator update 2026-10-22 morning): never probe while ~/sparkagent-BUSY exists (Spark-X agent test books
# the card SOLO), while any vx-*/voxel-* tmux is alive (Flint release-day voxel run), while a hermes-kv hmrun* session runs
# (vLLM legs back to back, a probe in a gap could OOM its next leg), or while the idle-queue drain runs.
# foreign GPU check filters ONLY Donald's own pids (descendants of llama-server.service's MainPID = the llama-swap child),
# never every process named llama-server (that hid the Flint server from a check this morning).
donald_pids() { local m; m=$(systemctl show -p MainPID --value llama-server.service 2>/dev/null); [ -n "$m" ] && [ "$m" != 0 ] || return 0
  echo "$m"; pgrep -P "$m"; for c in $(pgrep -P "$m"); do pgrep -P "$c"; done; }
foreign() { local dp; dp=" $(donald_pids | tr '\n' ' ') "
  for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader | tr -d ' '); do case "$dp" in *" $p "*) ;; *) echo "$p";; esac; done; }
blocked() { # prints the reason when the card is not free for the probe
  [ -e /home/witcheer/sparkagent-BUSY ] && { echo "sparkagent-BUSY present"; return 0; }
  local t; t=$(tmux ls -F '#{session_name}' 2>/dev/null | grep -E '^(vx-|voxel-|hmrun|idleq$)' | tr '\n' ' '); [ -n "$t" ] && { echo "tmux alive: $t"; return 0; }
  local f; f=$(foreign | tr '\n' ' '); [ -n "$f" ] && { echo "foreign GPU pids: $f"; return 0; }
  systemctl is-active --quiet llama-server.service || { echo "llama-server.service inactive (someone else's drain, waiting for its restore)"; return 0; }
  return 1; }
last=""
while :; do
  while :; do
    [ "$(date +%H%M)" -lt 2330 ] || { echo "$(date '+%T') 23:30 reached without a free card, not probing"; exit 3; }
    why=$(blocked) || break
    [ "$why" != "$last" ] && echo "$(date '+%T') waiting: $why"; last=$why
    sleep 30
  done
  echo "$(date '+%T') card looks free (no BUSY flag, no vx/voxel/idleq tmux, no foreign GPU pid), settling 90 s and re-checking"
  sleep 90
  why=$(blocked) || break
  echo "$(date '+%T') re-check failed: $why; back to waiting"; last=$why
done
echo "$(date '+%T') draining Donald (marker ~/z8probe-BUSY while the probe holds the card)"
date '+%F %T z8 probe holds the card' > /home/witcheer/z8probe-BUSY
trap 'rm -f /home/witcheer/z8probe-BUSY; nl_donald_restore; sleep 5; curl -s -m5 127.0.0.1:8090/health | grep -qi ok && echo "$(date +%T) donald health ok" || echo "$(date +%T) WARN donald health not ok"' EXIT
nl_donald_stop
for i in $(seq 1 60); do v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '); [ "${v:-99999}" -lt 4000 ] && { echo "drain clear (${v} MiB)"; break; }; sleep 2; done
bash /home/witcheer/Pollen/probe-duck-warmstart.sh velstairs Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck "$SEED" 4096 > /dev/null 2>&1
echo "$(date '+%T') probe rc=$? (full log ~/Pollen/probe-velstairs.log)"
# one control take in the verdict env (condition a overrides) with the walk-mixslope seed (the rival): recorder + override reach on the new task id
export MICRODUCK_STEP_HEIGHT=0.025,0.025 MICRODUCK_FOOT_FRICTION=0.2,0.2 MICRODUCK_PUSH_SCALE=2.0 MICRODUCK_PUSH_INTERVAL=3,6
TASK=Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck; OUT=/home/witcheer/Pollen/clips/z8-controltake-2026-10-23
( . /home/witcheer/Pollen/proof-common.sh
  play z7ctl-a-t1 $TASK /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmixslope/2026-10-22_14-18-58_duckvelmixslope/model_16000.pt 1000 \
    --episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds ) > /dev/null 2>&1
echo "$(date '+%T') control take done: $(ls $OUT 2>/dev/null | tr '\n' ' ')"
echo "$(date '+%T') WRAP_END"
