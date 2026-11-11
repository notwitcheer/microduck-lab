#!/bin/bash
# 09z46-duck-proof-lean15.sh (2026-11-11): CPU proof for the 09z45 lean RE-CHECK (LEAN_W 1.5, experiment ducklean15, 7000 -> 13000).
# rule: the frozen 09z42 verdict, unchanged. signed median lean into the wind over the last 4 s, bar 12.6 deg, ladder 10 fresh takes at
# 2.0 / 3.0 / 4.0 N, P* = highest peak with >= 6/10 held, verdict words LEAN GAIN / LEAN ONLY / NO LEAN / BROKEN.
# sweep: 10 takes per checkpoint at 3.0 N over 7250..13000 every 250 it (24 checkpoints), bootstrap CIs, pick = highest held-take median
# among checkpoints holding >= 8/10 (lean-pick-redo.py, sample-size rule fixed in the 09z44 redo).
# DRYRUN guard: exits before any take (defect 1 of 09z43: the runner's DRYRUN pass ran the whole proof a second time).
# no card, no Donald drain. exit 3 (resumable) until model_13000.pt exists; exit 0 only when a VERDICT line exists.
# PROOF HARD STOP 05:30 CET is the runner block's own end (06:10) minus the restore; the item's own stop is not needed for a CPU proof.
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
RUNDIR=""
for d in $RL/logs/rsl_rl/ducklean15/*_ducklean15; do [ -f "$d/model_13000.pt" ] && RUNDIR=$d; done
[ -n "$RUNDIR" ] || { echo "NO_CHECKPOINT: ducklean15 model_13000.pt missing (09z45 train not finished); exit 3 (resumable)"; exit 3; }
echo "=== $(date -u +%T) 09z46 lean15 proof start: $RUNDIR ==="
[ "${DRYRUN:-0}" = 1 ] && { echo "DRYRUN: exiting before any CPU work (guard)"; echo "PROOF DONE"; exit 0; }
cd $P/lean-09z42
# 1. sweep3: 24 checkpoints x 10 takes at 3.0 N, 4 legs in parallel (12 cores, nice 19)
printf '%s\n' 7250 7500 7750 8000 8250 8500 8750 9000 9250 9500 9750 10000 10250 10500 10750 11000 11250 11500 11750 12000 12250 12500 12750 13000 | \
  xargs -P 4 -I{} sh -c "GM_CKPT=$RUNDIR/model_{}.pt PROOF_TAG=sweep3-c{} nice -n 19 bash proof-lean-batch.sh 3.0 1 10 > $P/lean-09z42/sweep3-c{}.out 2>&1; echo SWEEP3_LEG_c{} rc=\$?"
pick_out=$(SWEEP_TAG=sweep3 SWEEP_HI=13000 nice -n 19 python3 lean-pick-redo.py 2>&1); echo "$pick_out"
pick=$(echo "$pick_out" | sed -n 's/^PICK c=\([0-9]*\).*/\1/p' | head -n 1)
runner=$(echo "$pick_out" | sed -n 's/^RUNNERUP c=\([0-9]*\).*/\1/p' | head -n 1)
if [ -z "$pick" ]; then pick=13000; tag=ladder3-c13000; echo "=== $(date -u +%T) no pick: frozen default model_13000 ==="; else tag=ladder3-c$pick; fi
echo "=== $(date -u +%T) ladder (counted) on model_$pick tag $tag ==="
for pk in 2.0 3.0 4.0; do
  GM_CKPT=$RUNDIR/model_$pick.pt PROOF_TAG=$tag nice -n 19 bash proof-lean-batch.sh $pk 1 10 || echo "LEG_RC pk=$pk rc=$?"
done
out=$(nice -n 19 python3 lean-verdict.py "$tag" 2>&1); echo "$out"
if [ -n "$runner" ] && [ "$runner" != "$pick" ]; then
  rtag=ladder3r-c$runner
  echo "=== $(date -u +%T) ladder (robustness) on model_$runner tag $rtag ==="
  for pk in 2.0 3.0 4.0; do
    GM_CKPT=$RUNDIR/model_$runner.pt PROOF_TAG=$rtag nice -n 19 bash proof-lean-batch.sh $pk 1 10 || echo "RR_LEG_RC pk=$pk rc=$?"
  done
  rout=$(nice -n 19 python3 lean-verdict.py "$rtag" 2>&1); echo "ROBUSTNESS:"; echo "$rout"
fi
if echo "$out" | grep -q '^VERDICT:'; then echo "=== $(date -u +%T) 09z46 PROOF DONE ==="; echo "PROOF DONE"; exit 0; fi
echo "=== $(date -u +%T) 09z46 no verdict line ==="; echo "PROOF DONE"; exit 3
