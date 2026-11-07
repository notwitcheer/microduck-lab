#!/bin/bash
# heist-train-body.sh (2026-11-05): shared body for the Arena 6 m SOCK HEIST idle-queue item 09z28 (witcheer's robot lane, vault 60-robotics/microduck).
# derived from tug2-train-body.sh (resume logic, Donald drain + EXIT-trap restore, manifest) with two additions: (1) a NOT_BEFORE epoch gate, (2) test hooks for a CPU e2e.
# the challenge: github.com/pollen-robotics/microduck-challenges @ 5cee942 (Arena 0.7.0 wheel), task Mjlab-SockHeist6m-MicroDuck, own venv ~/Pollen/arena/heist/microduck-challenges/.venv.
# spec = name|worktree|seed|target_it|envs   (worktree relative to ~/Pollen/arena/heist; a run to max-iterations M ends at model_(M-1); a resume counts its loaded iteration as the first: MI = TGT - IT)
# the learner always starts as the Arena's reference walker (walker.onnx, WARM_START_STD 0.3) on a fresh run: that is the recipe as shipped (AGENTS.md), nothing to copy in.
# gates: NOT_BEFORE=<epoch> (item header) -> exit 3 BEFORE the lane check and the Donald drain, so a queued item cannot take an earlier block; NOT_BEFORE=0 on the command line lifts it for a hand run.
# test hooks (e2e/sim only): HEIST_NOW=<epoch> (clock for the NOT_BEFORE gate), HEIST_SIM=1 (stop after the lane check), HEIST_NODRAIN=1 skips the Donald drain/restore, HEIST_TRAIN_ARGS appends to the train argv (e.g. "--gpu-ids None"), HEIST_ENVS overrides the envs of every run.
set -uo pipefail
: "${RUNS:?set RUNS in the runs file}"; : "${ITEM:?set ITEM}"
NL_TAG=heist$ITEM
MANIFEST=/home/witcheer/heist$ITEM-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
A=/home/witcheer/Pollen/arena/heist
VENV=$A/microduck-challenges/.venv
TASK=Mjlab-SockHeist6m-MicroDuck
SAVE_EVERY=${SAVE_EVERY:-100}
RUNLOG=/home/witcheer/heist$ITEM-run.log
export PATH=/home/witcheer/.local/bin:$PATH
EXP=sock_heist_6m

latest_ckpt() { # <worktree> <name> -> "<run_dir> <model_N.pt> <N>" for the highest N of the run named <name>, nothing when none
  /usr/bin/python3 - "$1/logs/rsl_rl/$EXP" "$2" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1]); name = sys.argv[2]; best = None
if root.is_dir():
    for d in root.glob("*_" + name):
        if d.name.split("_", 2)[2:] != [name]: continue   # exact run name, not a suffix of another
        for f in d.glob("model_*.pt"):
            m = re.fullmatch(r"model_(\d+)\.pt", f.name)
            if m and (best is None or int(m.group(1)) > best[2]):
                best = (f.parent.name, f.name, int(m.group(1)))
if best: print(*best)
PY
}

nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) item=$ITEM runs=${#RUNS[@]}"
nl_check_path "$VENV/bin/train" "$VENV/bin/python" "$A/microduck-challenges/src/microduck_challenges/sock_heist_6m/walker.onnx" "$A/microduck-challenges/src/microduck_challenges/sock_heist_6m/challenge.toml"
nl_check_disk 120
PYTHONPATH=$A/microduck-challenges/src "$VENV/bin/python" -c "import sys, warp, mujoco_warp, rsl_rl, microduck_challenges.sock_heist_6m; from mjlab.tasks.registry import list_tasks; sys.exit(0 if '$TASK' in list_tasks() else 1)" 2>/dev/null && nl_ok "venv imports warp/mujoco_warp/rsl_rl, $TASK registered" || nl_fail "venv cannot import the heist stack or $TASK is not registered"
DL=$(nl_deadline_epoch); nl_say "  planned: hard stop $(date -u -d "@$DL" "+%a %H:%M") UTC, $(( (DL-$(date +%s))/60 )) min away"
NB=${NOT_BEFORE:-0}
hnow() { echo "${HEIST_NOW:-$(date +%s)}"; }   # HEIST_NOW is a lane-simulation hook only
if [ "$(hnow)" -lt "$NB" ]; then nl_say "  NOT_BEFORE gate: $(date -d "@$NB" '+%a %Y-%m-%d %H:%M %Z') ($NB), HOLDS now: a real run exits 3 in seconds, no drain, no lane record"; else nl_say "  NOT_BEFORE gate: open ($NB)"; fi
ALL_DONE=1
for spec in "${RUNS[@]}"; do
  IFS='|' read -r NAME WT SEED TGT RENVS <<<"$spec"
  nl_check_path "$A/$WT/src/microduck_challenges/sock_heist_6m/challenge.toml"
  if [ "$WT" != microduck-challenges ]; then   # a branch worktree: the knob must sit in ITS challenge.toml and be committed (publish refuses a dirty tree)
    [ -z "$(git -C "$A/$WT" status --porcelain 2>/dev/null)" ] && nl_ok "run $NAME: worktree $WT clean at $(git -C "$A/$WT" rev-parse --short HEAD)" || nl_fail "run $NAME: worktree $WT is dirty"
  fi
  read -r RUN CKPT IT <<<"$(latest_ckpt "$A/$WT" "$NAME")"; IT=${IT:-0}
  [ "$IT" -ge $((TGT-1)) ] && nl_say "  run $NAME ($WT seed $SEED): present (last checkpoint $IT, target $TGT: a run to N ends at model_N-1)" || { ALL_DONE=0; nl_say "  run $NAME ($WT seed $SEED): RUN ($((TGT-IT)) iterations left, ${HEIST_ENVS:-${RENVS:-4096}} envs; ${RUN:-fresh}/${CKPT:-none} at $IT)"; }
done
[ "$ALL_DONE" = 1 ] && { nl_say "nothing to run, item complete"; exit 0; }
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init train; fi
nl_gate
if [ "$(hnow)" -lt "$NB" ]; then nl_say "NOT_BEFORE $(date -d "@$NB" '+%a %H:%M') not reached, exit 3 (stays queued, nothing started)"; exit 3; fi
. /home/witcheer/Pollen/duck-lane.sh; duck_lane_check   # weekday duck/bench alternation (weekend blocks never yield), exits 3 on a bench block

[ "${HEIST_SIM:-0}" = 1 ] && { nl_say "SIM: the lane check passed, the item would start training now (stopping here)"; exit 0; }
restore() { [ "${HEIST_NODRAIN:-0}" = 1 ] && return 0; nl_say "EXIT trap: restoring Donald"; systemctl is-active --quiet llama-server.service || sudo -n systemctl start llama-server.service || true; }
trap restore EXIT
if [ "${HEIST_NODRAIN:-0}" = 1 ]; then nl_say "HEIST_NODRAIN=1 (e2e): Donald left alone"; else
  nl_say "draining Donald (night-lib nl_donald_stop; stop kills the child too)"; nl_donald_stop
  for i in $(seq 1 120); do v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '); [ "${v:-99999}" -lt 4000 ] && { nl_say "drain clear (${v}MiB)"; break; }; sleep 2; [ "$i" -eq 120 ] && { nl_say "FATAL drain timeout"; exit 1; }; done
fi

REMAIN=0
for spec in "${RUNS[@]}"; do
  IFS='|' read -r NAME WT SEED TGT RENVS <<<"$spec"
  read -r RUN CKPT IT <<<"$(latest_ckpt "$A/$WT" "$NAME")"; IT=${IT:-0}
  [ "$IT" -ge $((TGT-1)) ] && continue
  left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
  [ "$left" -gt 600 ] || { nl_say "under 10 min left, not starting $NAME"; REMAIN=1; continue; }
  RESUME=""; [ -n "${RUN:-}" ] && RESUME="--agent.resume True --agent.load-run $RUN --agent.load-checkpoint $CKPT"
  nl_say "=== train $NAME ($WT) seed $SEED envs=${HEIST_ENVS:-${RENVS:-4096}} iterations $IT -> $TGT (budget $((left/60)) min) ==="
  t0=$(date +%s)
  MI=$TGT; [ -n "${RUN:-}" ] && MI=$(( TGT - IT ))
  ( cd "$A/$WT" && export PYTHONPATH="$A/$WT/src" && \
    timeout --signal=INT --kill-after=60 "$left" "$VENV/bin/train" "$TASK" --env.scene.num-envs "${HEIST_ENVS:-${RENVS:-4096}}" \
      --agent.max-iterations "$MI" --agent.save-interval "$SAVE_EVERY" --agent.seed "$SEED" --agent.logger tensorboard \
      --agent.run-name "$NAME" $RESUME ${HEIST_TRAIN_ARGS:-} >> "$RUNLOG" 2>&1 ); rc=$?
  read -r RUN2 CKPT2 IT2 <<<"$(latest_ckpt "$A/$WT" "$NAME")"; IT2=${IT2:-0}
  dt=$(( $(date +%s) - t0 )); did=$(( IT2 - IT ))
  [ "$did" -gt 0 ] && spi=$(awk -v a="$dt" -v b="$did" 'BEGIN{printf "%.2f", a/b}') || spi="n/a"
  nl_say "  train $NAME rc=$rc: iterations $IT -> $IT2 in $((dt/60)) min ($spi s/it), run ${RUN2:-none}"
  [ "$IT2" -ge $((TGT-1)) ] || REMAIN=1
done
if [ "$REMAIN" = 0 ]; then nl_mark train done "all runs at target"; else nl_mark train failed "iterations remain (resumable)"; fi

restore; trap - EXIT
if [ "${HEIST_NODRAIN:-0}" != 1 ]; then
  ok=0; for _ in $(seq 1 60); do curl -s -m 3 localhost:8090/health | grep -qi ok && { ok=1; break; }; sleep 5; done
  [ "$ok" = "1" ] && nl_say "Donald healthy at end" || nl_donald_restore
fi
[ "$REMAIN" = 0 ] && { nl_say "DONE rc=0 manifest $MANIFEST"; exit 0; }
nl_say "DONE, iterations still resumable"; exit 3
