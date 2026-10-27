#!/bin/bash
# hop-wrap-2026-10-27.sh <script> [args...]: run a GPU probe under the shared-card protocol (2026-10-27 hop item).
# waits while any ~/*-BUSY flag (other than ours) exists, a non-Donald GPU pid lives, or tmux idleq is up; settles 90 s and
# re-checks; writes ~/hop-BUSY; removes it on exit (trap); refuses to start after 12:30 UTC (13:30 CET). never drains Donald, never touches :8090.
# probes here coexist with a cold card (Donald unloaded); the daily brief's 25 GB load is waited out by the caller.
set -uo pipefail
STOP_EPOCH=${HOP_STOP_EPOCH:-$(date -u -d "2026-10-27 12:30:00" +%s)}
LOG=${HOP_WRAP_LOG:-$HOME/Pollen/hop-wrap-2026-10-27.log}
say() { echo "$(date -u +%FT%TZ) hop-wrap: $*" | tee -a "$LOG"; }
donald_pids() { local m; m=$(systemctl show -p MainPID --value llama-server.service 2>/dev/null); [ -n "$m" ] && [ "$m" != 0 ] && { echo "$m"; pgrep -P "$m"; } ; }
foreign_gpu() {
  local don; don=$(donald_pids | tr '\n' ' ')
  for p in $(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null); do
    case " $don " in *" $p "*) ;; *) echo "$p";; esac
  done
}
busy_flags() { ls $HOME/*-BUSY 2>/dev/null | grep -v "/hop-BUSY$"; }
quiet() { [ -z "$(busy_flags)" ] && [ -z "$(foreign_gpu)" ] && ! tmux has-session -t idleq 2>/dev/null; }
while true; do
  [ "$(date +%s)" -ge "$STOP_EPOCH" ] && { say "past stop time, not starting"; exit 9; }
  if quiet; then sleep 90; quiet && break; else say "waiting: flags=$(busy_flags | tr '\n' ' ') foreign=$(foreign_gpu | tr '\n' ' ')"; sleep 60; fi
done
echo "hop $$ $(date -u +%FT%TZ) $*" > $HOME/hop-BUSY
trap 'rm -f $HOME/hop-BUSY; say "hop-BUSY removed"' EXIT
say "start: $*"
timeout --signal=INT $(( STOP_EPOCH - $(date +%s) )) "$@"
rc=$?
say "rc=$rc: $*"
exit $rc
