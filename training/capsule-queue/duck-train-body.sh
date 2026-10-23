#!/bin/bash
# duck-train-body.sh: shared body for the duck skill-tree idle-queue items (heures creuses runner).
# an item is a 6-line header that sets SKILL, TASK, TARGET_IT (and optionally ENVS, SAVE_EVERY) then sources this file.
# lane: 60-robotics/microduck (witcheer's personal robot lane). one item = one skill = one Pollen mjlab task id.
# derived from 09-duck-velocity-train.sh (done 2026-09-15: 4000 it in 58 min at 0.88 s/it, 4096 envs, exported clean).
# per-skill names: NL_TAG=duck$SKILL, manifest ~/duck$SKILL-status.json, run log ~/duck$SKILL-run.log,
# checkpoints logs/rsl_rl/duck$SKILL/, export ~/Pollen/policies-ours/$SKILL-<date>-it<N>.onnx.
# resumable across blocks (highest model_N.pt, --agent.resume). exit 3 while iterations remain, 0 once trained AND exported.
# the resumed run counts its loaded iteration as the first one, so max-iterations is TARGET-IT+1 (e2e finding 2026-09-15).
# EXTRA_TRAIN_ARGS (optional, header-set, 2026-10-04): appended to the train argv, e.g. "--agent.seed 3 --env.seed 3" for the
# get-up seed sweep (every earlier run used the rsl_rl default seed 42).
# --video True writes training clips every VIDEO_EVERY iterations to logs/rsl_rl/duck$SKILL/<run>/videos/train/ (needs MUJOCO_GL=egl).
set -uo pipefail
: "${SKILL:?set SKILL in the item header}"; : "${TASK:?set TASK in the item header}"; : "${TARGET_IT:?set TARGET_IT in the item header}"
NL_TAG=duck$SKILL
MANIFEST=/home/witcheer/duck$SKILL-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
RL=${RL:-/home/witcheer/Pollen/microduck_rl}
UV=/home/witcheer/.local/bin/uv
EXP=duck$SKILL
ENVS=${ENVS:-4096}
SAVE_EVERY=${SAVE_EVERY:-100}
VIDEO_EVERY=${VIDEO_EVERY:-500}
LOGROOT=$RL/logs/rsl_rl/$EXP
RUNLOG=/home/witcheer/duck$SKILL-run.log
OUT=/home/witcheer/Pollen/policies-ours
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl

latest_ckpt() { # prints "<run_dir> <model_N.pt> <N>" for the highest N under LOGROOT, nothing when none
  /usr/bin/python3 - "$LOGROOT" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1]); best = None
if root.is_dir():
    for f in root.glob("*/model_*.pt"):
        m = re.fullmatch(r"model_(\d+)\.pt", f.name)
        if m and (best is None or int(m.group(1)) > best[2]):
            best = (f.parent.name, f.name, int(m.group(1)))
if best: print(*best)
PY
}

nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) skill=$SKILL task=$TASK"
nl_check_path "$UV" "$RL/pyproject.toml" "$RL/.venv/bin/python" "$RL/scripts/export.py"
nl_check_disk 50
"$RL/.venv/bin/python" -c "import warp, mujoco_warp, rsl_rl" 2>/dev/null && nl_ok "rl venv imports warp, mujoco_warp, rsl_rl" || nl_fail "rl venv cannot import warp/mujoco_warp/rsl_rl"
"$RL/.venv/bin/python" -c "import sys, mjlab_microduck.tasks; from mjlab.tasks.registry import list_tasks; sys.exit(0 if '$TASK' in list_tasks() else 1)" 2>/dev/null && nl_ok "task $TASK is registered" || nl_fail "task $TASK not registered in mjlab_microduck"
read -r RUN CKPT IT <<<"$(latest_ckpt)"; IT=${IT:-0}; RUN=${RUN:-}; CKPT=${CKPT:-}
nl_say "  checkpoint: ${RUN:-none}/${CKPT:-none} at iteration $IT of $TARGET_IT"
ONNX_DONE=$(ls "$OUT/$SKILL"-*-it$TARGET_IT.onnx 2>/dev/null | head -1)  # exact-artifact skip: a policy exported at a lower TARGET_IT does not satisfy an extended budget (2026-09-17)
[ "$IT" -ge "$TARGET_IT" ] && nl_say "  train: present ($IT >= $TARGET_IT)" || nl_say "  train: RUN ($((TARGET_IT-IT)) iterations left, $ENVS envs)"
[ -n "$ONNX_DONE" ] && nl_say "  export: present ($ONNX_DONE)" || nl_say "  export: RUN"
DL=$(nl_deadline_epoch); nl_say "  planned: hard stop $(date -u -d "@$DL" "+%H:%M") UTC, $(( (DL-$(date +%s))/60 )) min away"
if [ "$IT" -ge "$TARGET_IT" ] && [ -n "$ONNX_DONE" ]; then nl_say "nothing to run, item complete"; exit 0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init train export; fi
nl_gate
. /home/witcheer/Pollen/duck-lane.sh; duck_lane_check   # weekday duck/bench alternation, exits 3 on a bench block

restore() { nl_say "EXIT trap: restoring Donald"; systemctl is-active --quiet llama-server.service || sudo -n systemctl start llama-server.service || true; }
trap restore EXIT
nl_say "draining Donald (proxy: stop kills the child too)"; sudo -n systemctl stop llama-server.service; sleep 3
for i in $(seq 1 120); do v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '); [ "${v:-99999}" -lt 4000 ] && { nl_say "drain clear (${v}MiB)"; break; }; sleep 2; [ "$i" -eq 120 ] && { nl_say "FATAL drain timeout"; exit 1; }; done
cd "$RL"

if [ "$IT" -lt "$TARGET_IT" ]; then
  left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
  [ "$left" -gt 600 ] || { nl_say "under 10 min left, not starting"; nl_mark train failed "window exhausted (resumable)"; exit 3; }
  RESUME=""; [ -n "$RUN" ] && RESUME="--agent.resume True --agent.load-run $RUN --agent.load-checkpoint $CKPT"
  nl_say "=== train $TASK envs=$ENVS iterations $IT -> $TARGET_IT (budget $((left/60)) min) ==="
  t0=$(date +%s)
  # shellcheck disable=SC2086
  timeout --signal=INT --kill-after=60 "$left" "$UV" run train "$TASK" --env.scene.num-envs "$ENVS" \
    --agent.max-iterations $((TARGET_IT-IT+1)) --agent.save-interval "$SAVE_EVERY" --agent.logger tensorboard \
    --agent.experiment-name "$EXP" --agent.run-name "$EXP" --video True --video-interval "$VIDEO_EVERY" --video-length 300 $RESUME ${EXTRA_TRAIN_ARGS:-} >> "$RUNLOG" 2>&1; rc=$?
  read -r RUN2 CKPT2 IT2 <<<"$(latest_ckpt)"; IT2=${IT2:-0}
  dt=$(( $(date +%s) - t0 )); did=$(( IT2 - IT ))
  [ "$did" -gt 0 ] && spi=$(awk -v a="$dt" -v b="$did" 'BEGIN{printf "%.2f", a/b}') || spi="n/a"
  nl_say "  train rc=$rc: iterations $IT -> $IT2 in $((dt/60)) min ($spi s/it), run ${RUN2:-none}"
  if [ "$IT2" -ge "$TARGET_IT" ]; then nl_mark train done "$IT2 iterations, ${spi} s/it at $ENVS envs, run $RUN2"; else nl_mark train failed "rc=$rc at iteration $IT2 (resumable)"; fi
  IT=$IT2; RUN=${RUN2:-}; CKPT=${CKPT2:-}
fi

if [ "$IT" -ge "$TARGET_IT" ] && [ -z "$ONNX_DONE" ]; then
  mkdir -p "$OUT"; onnx="$OUT/$SKILL-$(date +%F)-it$IT.onnx"
  nl_say "=== export $RUN/$CKPT -> $onnx ==="
  timeout 900 "$UV" run scripts/export.py "$TASK" --checkpoint-file "$LOGROOT/$RUN/$CKPT" --onnx-file "$onnx" >> "$RUNLOG" 2>&1; rc=$?
  if [ "$rc" = 0 ] && [ -s "$onnx" ]; then nl_mark export done "$onnx"; nl_say "  export ok: $onnx"
  else nl_mark export failed "rc=$rc"; nl_say "  export FAILED rc=$rc (see $RUNLOG); the run dir's auto-export is $(ls "$LOGROOT/$RUN"/*.onnx 2>/dev/null | head -1)"; fi
fi

restore; trap - EXIT
ok=0; for _ in $(seq 1 60); do curl -s -m 3 localhost:8090/health | grep -qi ok && { ok=1; break; }; sleep 5; done
[ "$ok" = "1" ] && nl_say "Donald healthy at end" || nl_donald_restore
if [ "$IT" -ge "$TARGET_IT" ]; then nl_say "DONE rc=0 manifest $MANIFEST"; exit 0; fi
nl_say "DONE, $((TARGET_IT-IT)) iterations still resumable"; exit 3
