#!/bin/bash
# 09z49-duck-proof-lean3.sh (2026-11-12): CPU proof for the 09z48 lean v3 (upright target = wind lean, experiment ducklean3, 7000 -> 10000).
# rule: the frozen 09z42 verdict, unchanged. signed median lean into the wind over the last 4 s, bar 12.6 deg, ladder 10 fresh takes at
# 2.0 / 3.0 / 4.0 N, P* = highest peak with >= 6/10 held, verdict words LEAN GAIN / LEAN ONLY / NO LEAN / BROKEN.
# sweep: 10 takes per checkpoint at 3.0 N over 7250..10000 every 250 it (12 checkpoints), bootstrap CIs, pick = highest held-take median
# among checkpoints holding >= 8/10 (lean-pick-redo.py); UNDETERMINED pick -> both top two get a ladder, the pick's is the counted one.
# takes play on the 09z42 lean task (same wind, obs, physics and terminations; rewards do not act in play), so every lean row is comparable.
# DRYRUN guard before any take. no card, no Donald drain. exit 3 (resumable) until model_10000.pt exists or before NOT_BEFORE; exit 0 only with a VERDICT line.
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
NOT_BEFORE=${NOT_BEFORE:-1794611400}
RUNDIR=""
for d in $RL/logs/rsl_rl/ducklean3/*_ducklean3; do [ -f "$d/model_10000.pt" ] && RUNDIR=$d; done
if [ "${DRYRUN:-0}" = 1 ]; then  # guard: checks the harness, starts no take
  for f in proof-lean-batch.sh lean-pick-redo.py lean-verdict.py; do [ -f "$P/lean-09z42/$f" ] || { echo "DRYRUN FAIL: $f missing"; exit 1; }; done
  echo "DRYRUN ok: harness present; ducklean3 model_10000 ${RUNDIR:-not yet trained}"; echo "PROOF DONE"; exit 0
fi
[ -n "$RUNDIR" ] || { echo "NO_CHECKPOINT: ducklean3 model_10000.pt missing (09z48 train not finished); exit 3 (resumable)"; exit 3; }
echo "=== $(date -u +%T) 09z49 lean3 proof start: $RUNDIR ==="
[ "$(date +%s)" -ge "$NOT_BEFORE" ] || { echo "NOT_BEFORE not reached, exit 3"; exit 3; }
cd $P/lean-09z42
printf '%s\n' 7250 7500 7750 8000 8250 8500 8750 9000 9250 9500 9750 10000 | \
  xargs -P 4 -I{} sh -c "GM_CKPT=$RUNDIR/model_{}.pt PROOF_TAG=sweep4l3-c{} nice -n 19 bash proof-lean-batch.sh 3.0 1 10 > $P/lean-09z42/sweep4l3-c{}.out 2>&1; echo SWEEP4L3_LEG_c{} rc=\$?"
pick_out=$(SWEEP_TAG=sweep4l3 SWEEP_LO=7250 SWEEP_HI=10000 nice -n 19 python3 lean-pick-redo.py 2>&1); echo "$pick_out"
pick=$(echo "$pick_out" | sed -n 's/^PICK c=\([0-9]*\).*/\1/p' | head -n 1)
runner=$(echo "$pick_out" | sed -n 's/^RUNNERUP c=\([0-9]*\).*/\1/p' | head -n 1)
if [ -z "$pick" ]; then pick=10000; echo "=== $(date -u +%T) no pick: frozen default model_10000 ==="; fi
tag=ladder4l3-c$pick
echo "=== $(date -u +%T) ladder (counted) on model_$pick tag $tag ==="
for pk in 2.0 3.0 4.0; do
  GM_CKPT=$RUNDIR/model_$pick.pt PROOF_TAG=$tag nice -n 19 bash proof-lean-batch.sh $pk 1 10 || echo "LEG_RC pk=$pk rc=$?"
done
out=$(nice -n 19 python3 lean-verdict.py "$tag" 2>&1); echo "$out"
if [ -n "$runner" ] && [ "$runner" != "$pick" ]; then
  rtag=ladder4l3r-c$runner
  echo "=== $(date -u +%T) ladder (robustness) on model_$runner tag $rtag ==="
  for pk in 2.0 3.0 4.0; do
    GM_CKPT=$RUNDIR/model_$runner.pt PROOF_TAG=$rtag nice -n 19 bash proof-lean-batch.sh $pk 1 10 || echo "RR_LEG_RC pk=$pk rc=$?"
  done
  rout=$(nice -n 19 python3 lean-verdict.py "$rtag" 2>&1); echo "ROBUSTNESS:"; echo "$rout"
fi
if echo "$out" | grep -q '^VERDICT:'; then echo "=== $(date -u +%T) 09z49 PROOF DONE ==="; echo "PROOF DONE"; exit 0; fi
echo "=== $(date -u +%T) 09z49 no verdict line ==="; echo "PROOF DONE"; exit 3
