#!/bin/bash
# probe-velmixslope-wrap-2026-10-22.sh: 09z7 exact-argv warm-start probe on a free card, outside heures creuses (minutes of
# card time, allowed). waits for the day0 voxel flint run (own hard stop 10:16 CEST) to release the card, then the sanctioned
# drain (night-lib nl_donald_stop, EXIT trap nl_donald_restore), probe-duck-warmstart.sh at 4096 envs, restore + health check.
# refuses to start after 13:30 CEST (keeps the 14:10 runner clear). tmux "z7probe". log ~/Pollen/probe-velmixslope-wrap.log
exec >> /home/witcheer/Pollen/probe-velmixslope-wrap.log 2>&1
NL_TAG=z7probe; MANIFEST=/tmp/z7probe.json; export MANIFEST
. /home/witcheer/night-lib.sh
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmixslope/2026-10-22_00-00-00_seed-velmix-it13000/model_13000.pt
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
    [ "$(date +%H%M)" -lt 1330 ] || { echo "$(date '+%T') 13:30 reached without a free card, not probing"; exit 3; }
    why=$(blocked) || break
    [ "$why" != "$last" ] && echo "$(date '+%T') waiting: $why"; last=$why
    sleep 30
  done
  echo "$(date '+%T') card looks free (no BUSY flag, no vx/voxel/idleq tmux, no foreign GPU pid), settling 90 s and re-checking"
  sleep 90
  why=$(blocked) || break
  echo "$(date '+%T') re-check failed: $why; back to waiting"; last=$why
done
echo "$(date '+%T') draining Donald (marker ~/z7probe-BUSY while the probe holds the card)"
date '+%F %T z7 probe holds the card' > /home/witcheer/z7probe-BUSY
trap 'rm -f /home/witcheer/z7probe-BUSY; nl_donald_restore; sleep 5; curl -s -m5 127.0.0.1:8090/health | grep -qi ok && echo "$(date +%T) donald health ok" || echo "$(date +%T) WARN donald health not ok"' EXIT
nl_donald_stop
for i in $(seq 1 60); do v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '); [ "${v:-99999}" -lt 4000 ] && { echo "drain clear (${v} MiB)"; break; }; sleep 2; done
bash /home/witcheer/Pollen/probe-duck-warmstart.sh velmixslope Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck "$SEED" 4096 > /dev/null 2>&1
echo "$(date '+%T') probe rc=$? (full log ~/Pollen/probe-velmixslope.log)"
# one control take in the verdict env (condition a overrides) with the walk-mix rival: recorder + override reach on the new task id
export MICRODUCK_SLOPE=0.15,0.15 MICRODUCK_STEP_HEIGHT=0.025,0.025 MICRODUCK_FOOT_FRICTION=0.2,0.2 MICRODUCK_PUSH_SCALE=2.0 MICRODUCK_PUSH_INTERVAL=3,6
TASK=Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck; OUT=/home/witcheer/Pollen/clips/z7-controltake-2026-10-22
( . /home/witcheer/Pollen/proof-common.sh
  play z6ctl-a-t1 $TASK /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelmix/2026-10-18_16-27-19_duckvelmix/model_13000.pt 1000 \
    --episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 --cmd-vx 0.3 --no-bounds ) > /dev/null 2>&1
echo "$(date '+%T') control take done: $(ls $OUT 2>/dev/null | tr '\n' ' ')"
echo "$(date '+%T') WRAP_END"
