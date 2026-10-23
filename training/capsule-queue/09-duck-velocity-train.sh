#!/bin/bash
# 25-duck-velocity-train.sh: idle-queue item (heures creuses runner). trains OUR Microduck walking policy on the 5090.
# lane: 60-robotics/microduck (witcheer's personal robot lane, opened 2026-09-11). why in the bench queue: RL training is GPU
# work and follows the same EDF heures creuses rule as everything else; the queue is the one place the card gets booked.
# task Mjlab-Velocity-Flat-MicroDuck, 4096 envs (Pollen README: ~1-2 h for a usable gait), target TARGET_IT iterations,
# tensorboard logger (no wandb account needed), checkpoint every SAVE_EVERY iterations so a block cut costs minutes.
# resumable across blocks: picks the highest model_N.pt under logs/rsl_rl/duckvel/ and continues with --agent.resume.
# exits 3 while iterations remain, 0 once trained AND exported (their exporter only, it bakes the obs normaliser in).
# smoke-tested 2026-09-14 07:33: 1024 envs, 30 it, 20 s, 1.9 GB VRAM, checkpoints + auto .onnx written (~/Pollen/train-smoke.log).
# e2e-tested 2026-09-15 08:32-08:46 (512 envs, real hard stop + resume + export, ~/duck-e2e.log): the resumed run counts its
# loaded iteration as the first one, so max-iterations is TARGET-IT+1 or the item stalls one short of TARGET forever.
set -uo pipefail
NL_TAG=duckvel
MANIFEST=/home/witcheer/duckvel-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
RL=/home/witcheer/Pollen/microduck_rl
UV=/home/witcheer/.local/bin/uv
TASK=Mjlab-Velocity-Flat-MicroDuck
EXP=duckvel
TARGET_IT=${TARGET_IT:-4000}
ENVS=${ENVS:-4096}
SAVE_EVERY=${SAVE_EVERY:-100}
LOGROOT=$RL/logs/rsl_rl/$EXP
RUNLOG=/home/witcheer/duckvel-run.log
OUT=/home/witcheer/Pollen/policies-ours
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl   # 2026-09-15: --video True needs an offscreen GL context; without it mjr_makeContext dies (tue 01:10 block, rc=1 in 11 s)

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

nl_say "PLAN phase (DRYRUN=${DRYRUN:-0})"
nl_check_path "$UV" "$RL/pyproject.toml" "$RL/.venv/bin/python" "$RL/scripts/export.py"
nl_check_disk 50
"$RL/.venv/bin/python" -c "import warp, mujoco_warp, rsl_rl" 2>/dev/null && nl_ok "rl venv imports warp, mujoco_warp, rsl_rl" || nl_fail "rl venv cannot import warp/mujoco_warp/rsl_rl"
read -r RUN CKPT IT <<<"$(latest_ckpt)"; IT=${IT:-0}; RUN=${RUN:-}; CKPT=${CKPT:-}
nl_say "  checkpoint: ${RUN:-none}/${CKPT:-none} at iteration $IT of $TARGET_IT"
ONNX_DONE=$(ls "$OUT"/velocity-*.onnx 2>/dev/null | head -1)
[ "$IT" -ge "$TARGET_IT" ] && nl_say "  train: present ($IT >= $TARGET_IT)" || nl_say "  train: RUN ($((TARGET_IT-IT)) iterations left, $ENVS envs)"
[ -n "$ONNX_DONE" ] && nl_say "  export: present ($ONNX_DONE)" || nl_say "  export: RUN"
DL=$(nl_deadline_epoch); nl_say "  planned: hard stop $(date -u -d "@$DL" "+%H:%M") UTC, $(( (DL-$(date +%s))/60 )) min away"
if [ "$IT" -ge "$TARGET_IT" ] && [ -n "$ONNX_DONE" ]; then nl_say "nothing to run, item complete"; exit 0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init train export; fi
nl_gate

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
    --agent.experiment-name "$EXP" --agent.run-name "$EXP" --video True --video-interval 500 --video-length 300 $RESUME >> "$RUNLOG" 2>&1; rc=$?
  read -r RUN2 CKPT2 IT2 <<<"$(latest_ckpt)"; IT2=${IT2:-0}
  dt=$(( $(date +%s) - t0 )); did=$(( IT2 - IT ))
  [ "$did" -gt 0 ] && spi=$(awk -v a="$dt" -v b="$did" 'BEGIN{printf "%.2f", a/b}') || spi="n/a"
  vram=$(grep -a -o "[0-9]* MiB" "$RUNLOG" | tail -1)
  nl_say "  train rc=$rc: iterations $IT -> $IT2 in $((dt/60)) min ($spi s/it), run ${RUN2:-none}"
  if [ "$IT2" -ge "$TARGET_IT" ]; then nl_mark train done "$IT2 iterations, ${spi} s/it at $ENVS envs, run $RUN2"; else nl_mark train failed "rc=$rc at iteration $IT2 (resumable)"; fi
  IT=$IT2; RUN=${RUN2:-}; CKPT=${CKPT2:-}
fi

if [ "$IT" -ge "$TARGET_IT" ] && [ -z "$ONNX_DONE" ]; then
  mkdir -p "$OUT"; onnx="$OUT/velocity-$(date +%F)-it$IT.onnx"
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
