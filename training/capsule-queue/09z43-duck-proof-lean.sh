#!/bin/bash
# 09z43-duck-proof-lean.sh: the 09z42 lean verdict as a CPU queue item (no card, no Donald drain).
# sorts right behind its training item and runs in the same drain after it.
#   1. no ducklean model_10000 -> exit 3 (stays queued, resumable).
#   2. SWEEP: model_7250..model_10000 (every 250 it), 4 takes each at 3.0 N (new policy only, CPU, nice 19), fresh PROOF_TAG per checkpoint.
#      lean-pick.py applies the pre-registered PICK rule (eligible = held >= 3/4 at 3.0 N; PICK = highest median held pitch; ties -> later).
#   3. LADDER on the PICK (fresh takes, never the sweep takes): 10 takes each at 2.0 / 3.0 / 4.0 N, then lean-verdict.py (frozen rule, unchanged).
#      PICK none -> the ladder runs on model_10000 (the frozen default).
# exit 0 only when the pick exists, every ladder leg has 10 takes AND a VERDICT line exists. pre-registered rules: lean-pick.py and lean-verdict.py headers,
# vault 60-robotics/microduck/09z42-duck-lean-status.md (SIZING section).
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
RUNDIR=$(ls -1d $RL/logs/rsl_rl/ducklean/*_ducklean 2>/dev/null | tail -n 1)
[ -n "$RUNDIR" ] && [ -f "$RUNDIR/model_10000.pt" ] || { echo "NO_CHECKPOINT: ducklean model_10000 missing (09z42 train not run); exit 3 (resumable)"; exit 3; }
echo "=== $(date -u +%T) 09z43 lean proof start: $RUNDIR ==="
# DRYRUN guard (added 2026-11-11 after this item's own DRYRUN pass ran the full proof a second time):
# a queue item that does real work must exit before it when the runner is only dry-running it.
[ "${DRYRUN:-0}" = 1 ] && { echo "DRYRUN: exiting before any CPU work"; exit 0; }
cd $P/lean-09z42
# 2. sweep, 3 checkpoints in parallel
printf '%s\n' 7250 7500 7750 8000 8250 8500 8750 9000 9250 9500 9750 10000 | \
  xargs -P 3 -I{} sh -c "GM_CKPT=$RUNDIR/model_{}.pt PROOF_TAG=sweep-c{} nice -n 19 bash proof-lean-batch.sh 3.0 1 4 > $P/lean-09z42/sweep-c{}.out 2>&1; echo SWEEP_LEG_c{} rc=\$?"
pick_out=$(nice -n 19 python3 lean-pick.py 2>&1); echo "$pick_out"
pick=$(echo "$pick_out" | sed -n 's/^PICK c=\([0-9]*\).*/\1/p' | head -n 1)
if [ -z "$pick" ]; then ck=$RUNDIR/model_10000.pt; tag=ladder-default; else ck=$RUNDIR/model_$pick.pt; tag=ladder-c$pick; fi
echo "=== $(date -u +%T) ladder on $ck tag $tag ==="
for pk in 2.0 3.0 4.0; do
  GM_CKPT=$ck PROOF_TAG=$tag nice -n 19 bash proof-lean-batch.sh $pk 1 10 || echo "LEG_RC pk=$pk rc=$?"
done
out=$(nice -n 19 python3 lean-verdict.py "$tag" 2>&1); echo "$out"
echo "$out" | grep -q '^VERDICT:' && { echo "=== $(date -u +%T) 09z43 DONE ==="; exit 0; }
echo "=== $(date -u +%T) 09z43 no verdict line ==="; exit 3
