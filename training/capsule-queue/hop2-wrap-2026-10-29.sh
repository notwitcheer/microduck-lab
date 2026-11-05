#!/bin/bash
# hop2-wrap-2026-10-29.sh <script> [args...]: run a GPU probe/sweep under the shared-card protocol (hop2 sweeps, Thu 2026-10-29).
# NEVER starts before HOP2_START_EPOCH (default 2026-10-29 05:15 UTC = 06:15 CET: the card belongs to idle-queue item 73-agenttest-v2-c1 until 06:10 CET) and never after HOP2_STOP_EPOCH (default 12:30 UTC = 13:30 CET; the 14:10 CET duck block is tug + gale).
# waits while any ~/*-BUSY flag (other than ours) exists, a non-Donald GPU pid lives, or tmux idleq is up; settles 90 s and re-checks; writes ~/hop2-BUSY; removes it on exit (trap). never drains Donald (the 4096-env sweeps peak ~6.5 GB beside his 7.8 GB), never touches :8090.
set -uo pipefail
START_EPOCH=${HOP2_START_EPOCH:-$(date -u -d "2026-10-29 05:15:00" +%s)}
STOP_EPOCH=${HOP2_STOP_EPOCH:-$(date -u -d "2026-10-29 12:30:00" +%s)}
LOG=${HOP2_WRAP_LOG:-$HOME/Pollen/hop2-wrap-2026-10-29.log}
say() { echo "$(date -u +%FT%TZ) hop2-wrap: $*" | tee -a "$LOG"; }
donald_pids() { local m; m=$(systemctl show -p MainPID --value llama-server.service 2>/dev/null); [ -n "$m" ] && [ "$m" != 0 ] && { echo "$m"; pgrep -P "$m"; } ; }
foreign_gpu() {
  local don; don=$(donald_pids | tr '\n' ' ')
  for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null); do
    case " $don " in *" $p "*) ;; *) echo "$p";; esac
  done
}
busy_flags() { ls $HOME/*-BUSY 2>/dev/null | grep -v "/hop2-BUSY$"; }
quiet() { [ -z "$(busy_flags)" ] && [ -z "$(foreign_gpu)" ] && ! tmux has-session -t =idleq 2>/dev/null; }
say "armed: start gate $(date -u -d @$START_EPOCH +%T)Z, stop gate $(date -u -d @$STOP_EPOCH +%T)Z, cmd: $*"
while [ "$(date +%s)" -lt "$START_EPOCH" ]; do sleep 30; done
while true; do
  [ "$(date +%s)" -ge "$STOP_EPOCH" ] && { say "past stop time, not starting"; exit 9; }
  if quiet; then sleep 90; quiet && break; else say "waiting: flags=$(busy_flags | tr '\n' ' ') foreign=$(foreign_gpu | tr '\n' ' ') idleq=$(tmux has-session -t =idleq 2>/dev/null && echo up || echo gone)"; sleep 60; fi
done
echo "hop2 $$ $(date -u +%FT%TZ) $*" > $HOME/hop2-BUSY
trap 'rm -f $HOME/hop2-BUSY; say "hop2-BUSY removed"' EXIT
say "start: $*"
timeout --signal=INT $(( STOP_EPOCH - $(date +%s) )) "$@"
rc=$?
say "rc=$rc: $*"
exit $rc
