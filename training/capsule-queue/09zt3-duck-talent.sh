#!/bin/bash
# 09zt3-duck-talent.sh: idle-queue item, MicroDuck Arena "Got a Talent" policy, trained on capsule from Pollen's recipe as is.
# staged 2026-10-27 ("visual and original content ... funny, absurd ... with our 5090";
# ruling 40-content/content-lane-decisions.md 2026-10-27 #3). NAME: 09zt3 (not 09t3) on purpose: in the runner's locale sort it falls AFTER 09z14/09z15 (dribble)
# and 09z16/09z17 (hop), so it can never push either out of its block, and BEFORE the 7x bench items. no watcher needed.
# EV: the clip is the post: "I gave Hermes Agent one sentence and it choreographed my robot duck's talent show act" (Hermes-drives-the-duck format, 3,791 views
# vs ~1.5-2k for single levels, gpu-ev-gate-2026-10-25 section 2; funny/absurd bar of ruling #3). serves: content (Hermes-driven showcase).
# WHAT: repo pollen-robotics/microduck-challenges @ 4b675eb (pinned 2026-10-27), task Mjlab-GotATalent-MicroDuck, recipe as is (challenge.toml [recipe]: 4096 envs,
# 3000 iterations, seed 1, knobs head 0.75 / stillness 2.0 / upright 2.5 untouched), venv ~/Pollen/arena-talent/microduck-challenges/.venv (Arena wheel 0.6.0, own dir:
# the tug-of-war sibling lives in ~/Pollen/arena/). Pollen's own reference policy is checkpoint 2000 of this same recipe (seed 1), so this reproduces it "comparable, not
# bit-identical" (their README); the item exists because the entry must be OUR policy (publish needs a repo of ours), and a seed-1 retrain is the honest version of that.
# PACE (probe 2026-10-27 15:42 UTC, free card, Donald unloaded, 4096 envs, exact argv, 30 it): 1.10 s/it (iteration time 1.09-1.10 s, 35 s for 30 it incl. warm-up),
# peak VRAM 17,384 MiB, dry-run export rc 0 (61 -> 14, smoke finite). 3000 it = ~55 min + ~1 min start + ~5 min judge (CPU). Donald (~25 GB) must be drained first.
# JUDGE (CPU, after training): every saved checkpoint 500..3000 is exported with publish --dry-run (the exact export a real publish does) and played on the Arena's
# stage on the reference timeline + every Hermes act in ~/Pollen/arena-talent/acts/; talent_pick.py picks the entry checkpoint with the rule fixed BEFORE any of our
# checkpoints was judged (docstring of talent_pick.py: >= 1500, fewest problems over all timelines, then neighbours, then later). result: ~/Pollen/arena-talent/pick-ducktalent.json.
# lane: weekday alternation applies (duck-lane.sh sourced after nl_gate), Wed 2026-10-28 01:10 CET is a duck block (ly > ld), items 09z14 + 09z15 train first
# (~01:11-02:50 CET estimate), this item starts behind them and needs ~62 min, the block ends 06:10 CET. resumable: exit 3 while iterations remain.
# NEVER hand-start: no GPU outside the runner. nothing here publishes or enters; the entry is a separate operator-gated step.
set -uo pipefail
NL_TAG=ducktalent
MANIFEST=/home/witcheer/ducktalent-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
RL=${TALENT_RL:-/home/witcheer/Pollen/arena-talent/microduck-challenges}
AT=/home/witcheer/Pollen/arena-talent
UV=/home/witcheer/.local/bin/uv
TASK=Mjlab-GotATalent-MicroDuck
EXP=got_a_talent
RUN_NAME=${TALENT_RUN_NAME:-talent}
TARGET_IT=${TARGET_IT:-3000}
ENVS=${ENVS:-4096}
SAVE_EVERY=${SAVE_EVERY:-250}
SEED=${TALENT_SEED:-1}
TAGJ=${TALENT_JUDGE_TAG:-ducktalent}
JUDGE_MIN=${TALENT_JUDGE_MIN:-500}   # first checkpoint judged (e2e clone lowers it)
export TALENT_PICK_MIN=${TALENT_PICK_MIN:-1500}   # talent_pick.py candidate floor
LOGROOT=$RL/logs/rsl_rl/$EXP
RUNLOG=/home/witcheer/${NL_TAG}-run.log
OUT=/home/witcheer/Pollen/policies-ours
export PATH=/home/witcheer/.local/bin:$PATH

latest_ckpt() { # prints "<run_dir> <model_N.pt> <N>" for the highest N under this item's runs, nothing when none
  /usr/bin/python3 - "$LOGROOT" "$RUN_NAME" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1]); name = sys.argv[2]; best = None
if root.is_dir():
    for f in root.glob(f"*_{name}/model_*.pt"):
        m = re.fullmatch(r"model_(\d+)\.pt", f.name)
        if m and (best is None or int(m.group(1)) > best[2]):
            best = (f.parent.name, f.name, int(m.group(1)))
if best: print(*best)
PY
}

nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) task=$TASK run=$RUN_NAME"
nl_check_path "$UV" "$RL/pyproject.toml" "$RL/.venv/bin/python" "$AT/talent_stage_report.py" "$AT/talent_pick.py"
nl_check_disk 50
"$RL/.venv/bin/python" -c "import warp, mujoco_warp, rsl_rl, arena" 2>/dev/null && nl_ok "venv imports warp, mujoco_warp, rsl_rl, arena" || nl_fail "venv cannot import warp/mujoco_warp/rsl_rl/arena"
(cd "$RL" && "$RL/.venv/bin/python" -c "import sys, microduck_challenges; from mjlab.tasks.registry import list_tasks; sys.exit(0 if '$TASK' in list_tasks() else 1)" 2>/dev/null) && nl_ok "task $TASK is registered" || nl_fail "task $TASK not registered"
(cd "$RL" && git status --short -- src | grep -q .) && nl_fail "the challenge folder has uncommitted changes (publish refuses a dirty run)" || nl_ok "challenge folder clean ($(cd "$RL" && git rev-parse --short HEAD))"
read -r RUN CKPT IT <<<"$(latest_ckpt)"; IT=${IT:-0}; RUN=${RUN:-}; CKPT=${CKPT:-}
nl_say "  checkpoint: ${RUN:-none}/${CKPT:-none} at iteration $IT of $TARGET_IT"
PICK=$AT/pick-$TAGJ.json
[ "$IT" -ge "$TARGET_IT" ] && nl_say "  train: present ($IT >= $TARGET_IT)" || nl_say "  train: RUN ($((TARGET_IT-IT)) iterations left, $ENVS envs)"
[ -s "$PICK" ] && nl_say "  judge: present ($PICK)" || nl_say "  judge: RUN"
DL=$(nl_deadline_epoch); nl_say "  planned: hard stop $(date -u -d "@$DL" "+%H:%M") UTC, $(( (DL-$(date +%s))/60 )) min away"
if [ "$IT" -ge "$TARGET_IT" ] && [ -s "$PICK" ]; then nl_say "nothing to run, item complete"; exit 0; fi
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init train judge; fi
nl_gate
. /home/witcheer/Pollen/duck-lane.sh; duck_lane_check   # weekday duck/bench alternation, exits 3 on a bench block

restore() { nl_say "EXIT trap: restoring Donald"; systemctl is-active --quiet llama-server.service || sudo -n systemctl start llama-server.service || true; }
trap restore EXIT
if [ "$IT" -lt "$TARGET_IT" ]; then
  nl_say "draining Donald (proxy: stop kills the child too)"; sudo -n systemctl stop llama-server.service; sleep 3
  for i in $(seq 1 120); do v=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '); [ "${v:-99999}" -lt 4000 ] && { nl_say "drain clear (${v}MiB)"; break; }; sleep 2; [ "$i" -eq 120 ] && { nl_say "FATAL drain timeout"; exit 1; }; done
  cd "$RL"
  left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
  [ "$left" -gt 600 ] || { nl_say "under 10 min left, not starting"; nl_mark train failed "window exhausted (resumable)"; exit 3; }
  RESUME=""; [ -n "$RUN" ] && RESUME="--agent.resume True --agent.load-run $RUN --agent.load-checkpoint $CKPT"
  nl_say "=== train $TASK envs=$ENVS iterations $IT -> $TARGET_IT seed $SEED (budget $((left/60)) min) ==="
  t0=$(date +%s)
  # shellcheck disable=SC2086
  timeout --signal=INT --kill-after=60 "$left" "$UV" run train "$TASK" --env.scene.num-envs "$ENVS" \
    --agent.max-iterations $((TARGET_IT-IT+1)) --agent.save-interval "$SAVE_EVERY" --agent.seed "$SEED" --agent.logger tensorboard \
    --agent.run-name "$RUN_NAME" $RESUME >> "$RUNLOG" 2>&1; rc=$?
  read -r RUN2 CKPT2 IT2 <<<"$(latest_ckpt)"; IT2=${IT2:-0}
  dt=$(( $(date +%s) - t0 )); did=$(( IT2 - IT ))
  [ "$did" -gt 0 ] && spi=$(awk -v a="$dt" -v b="$did" 'BEGIN{printf "%.2f", a/b}') || spi="n/a"
  nl_say "  train rc=$rc: iterations $IT -> $IT2 in $((dt/60)) min ($spi s/it), run ${RUN2:-none}"
  if [ "$IT2" -ge "$TARGET_IT" ]; then nl_mark train done "$IT2 iterations, ${spi} s/it at $ENVS envs, run $RUN2"; else nl_mark train failed "rc=$rc at iteration $IT2 (resumable)"; fi
  IT=$IT2; RUN=${RUN2:-}; CKPT=${CKPT2:-}
fi
restore; trap - EXIT   # the judge below is CPU only: give Donald back before it
ok=0; for _ in $(seq 1 60); do curl -s -m 3 localhost:8090/health | grep -qi ok && { ok=1; break; }; sleep 5; done
[ "$ok" = "1" ] && nl_say "Donald healthy" || nl_donald_restore

if [ "$IT" -ge "$TARGET_IT" ] && [ ! -s "$PICK" ]; then
  nl_say "=== judge every checkpoint on the Arena stage (CPU) ==="
  cd "$RL"; JD=$AT/judge-$TAGJ; rm -rf "$JD"; mkdir -p "$JD" "$OUT"
  ACTS=$(ls "$AT"/acts/*.json 2>/dev/null | tr '\n' ' ')
  for f in $(ls "$LOGROOT/$RUN"/model_*.pt | sed -n 's/.*model_\([0-9]*\)\.pt$/\1/p' | sort -n); do
    [ "$f" -lt "$JUDGE_MIN" ] && continue
    rm -rf publish-eval
    "$UV" run publish --run "$LOGROOT/$RUN" --checkpoint "$f" --repo local/microduck-eval --dry-run --allow-dirty --device cpu >> "$RUNLOG" 2>&1 || { nl_say "  export of checkpoint $f failed"; continue; }
    cp publish-eval/policy.onnx "$OUT/talent-$TAGJ-ck$f.onnx"
    # shellcheck disable=SC2086
    "$UV" run --group workshop python "$AT/talent_stage_report.py" "$OUT/talent-$TAGJ-ck$f.onnx" $ACTS --json "$JD/ck$f.json" > "$JD/ck$f.txt" 2>&1
    nl_say "  checkpoint $f judged: $(grep -c 'ALL MOVES LANDED' "$JD/ck$f.txt") landed, $(grep -c 'PROBLEMS' "$JD/ck$f.txt") with problems"
  done
  rm -rf publish-eval
  /usr/bin/python3 "$AT/talent_pick.py" "$PICK" "$JD" | tee -a "$RUNLOG" && nl_mark judge done "$(head -c 200 "$PICK" | tr '\n' ' ')" || nl_mark judge failed "no pick"
fi
if [ "$IT" -ge "$TARGET_IT" ] && [ -s "$PICK" ]; then nl_say "DONE rc=0 manifest $MANIFEST pick $PICK"; exit 0; fi
nl_say "DONE, $((TARGET_IT-IT)) iterations still resumable"; exit 3
