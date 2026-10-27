#!/bin/bash
# dribble-wrap-2026-10-27.sh <drain 0|1> <tag> <script> [args...]: run a GPU script on the SHARED capsule card (09z14 probes, 2026-10-27), per capsule-rig-ops etiquette.
# waits while ~/*-BUSY exists (any sibling), a vx-*/voxel-*/hmrun*/idleq tmux lives, or a GPU pid sits outside Donald's own tree; settles 90 s and re-checks; writes ~/<tag>-BUSY;
# drain=1 stops Donald through night-lib (nl_donald_stop, EXIT-trap nl_donald_restore) for the big (4096-env) probes; drain=0 for 1-env takes (~2-3 GB, fits beside a loaded Donald);
# refuses to start after 12:30 UTC (13:30 CET). log ~/Pollen/<tag>-wrap.log
D=${1:?drain 0|1}; TAG=${2:?tag}; shift 2
exec >> /home/witcheer/Pollen/$TAG-wrap.log 2>&1
NL_TAG=$TAG; MANIFEST=/tmp/$TAG.json; export MANIFEST
. /home/witcheer/night-lib.sh
donald_pids() { local m; m=$(systemctl show -p MainPID --value llama-server.service 2>/dev/null); [ -n "$m" ] && [ "$m" != 0 ] || return 0
  echo "$m"; pgrep -P "$m"; for c in $(pgrep -P "$m"); do pgrep -P "$c"; done; }
foreign() { local dp; dp=" $(donald_pids | tr '\n' ' ') "
  for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader | tr -d ' '); do case "$dp" in *" $p "*) ;; *) echo "$p";; esac; done; }
blocked() {
  local b; b=$(ls /home/witcheer/*-BUSY 2>/dev/null | grep -v -e "/$TAG-BUSY$" -e "/$TAG-wait-BUSY$" | tr '\n' ' '); [ -n "$b" ] && { echo "BUSY flag: $b"; return 0; }
  local t; t=$(tmux ls -F '#{session_name}' 2>/dev/null | grep -E '^(vx-|voxel-|hmrun|idleq$)' | tr '\n' ' '); [ -n "$t" ] && { echo "tmux alive: $t"; return 0; }
  local f; f=$(foreign | tr '\n' ' '); [ -n "$f" ] && { echo "foreign GPU pids: $f"; return 0; }
  systemctl is-active --quiet llama-server.service || { echo "llama-server.service inactive (someone else's drain)"; return 0; }
  return 1; }
trap 'rm -f /home/witcheer/$TAG-wait-BUSY' EXIT
# reservation ticket (2026-10-27): a sibling chain of back-to-back wrappers starved the free-card check for 25 min. while waiting we hold ~/$TAG-wait-BUSY: a sibling wrapper that checks ~/*-BUSY
# before ITS next start waits for us, so the card changes hands in turn. the running tenant is never touched.
date '+%F %T dribble waits for the card (reservation ticket)' > /home/witcheer/$TAG-wait-BUSY
past() { [ "$(date -u +%H%M)" -ge 1230 ]; }
last=""
while :; do
  while :; do
    past && { echo "$(date -u +%T) 12:30 UTC reached without a free card, not running"; exit 3; }
    why=$(blocked) || break
    [ "$why" != "$last" ] && echo "$(date -u +%T) waiting: $why"; last=$why
    sleep 10
  done
  # claim first (2026-10-27, after a sibling chain starved this wrapper for 20 min): write our flag so a sibling wrapper that checks ~/*-BUSY waits for us during the settle window
  date '+%F %T dribble claims the card (settling)' > /home/witcheer/$TAG-BUSY
  echo "$(date -u +%T) card looks free, flag written, settling 90 s and re-checking"
  sleep 90
  why=$(blocked) || break
  rm -f /home/witcheer/$TAG-BUSY
  echo "$(date -u +%T) re-check failed: $why; flag removed, back to waiting"; last=$why; date '+%F %T dribble waits for the card (reservation ticket)' > /home/witcheer/$TAG-wait-BUSY
done
date '+%F %T dribble holds the card' > /home/witcheer/$TAG-BUSY; rm -f /home/witcheer/$TAG-wait-BUSY
if [ "$D" = 1 ]; then
  trap 'rm -f /home/witcheer/$TAG-BUSY; nl_donald_restore; sleep 5; curl -s -m5 127.0.0.1:8090/health | grep -qi ok && echo "$(date -u +%T) donald health ok" || echo "$(date -u +%T) WARN donald health not ok"' EXIT
  nl_donald_stop
  for i in $(seq 1 60); do v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '); [ "${v:-99999}" -lt 4000 ] && { echo "drain clear (${v} MiB)"; break; }; sleep 2; done
else
  trap 'rm -f /home/witcheer/$TAG-BUSY' EXIT
fi
echo "$(date -u +%T) running: $*"
bash "$@"
echo "$(date -u +%T) rc=$? WRAP_END $TAG"
