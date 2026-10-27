#!/bin/bash
# dribble-probes-2026-10-27.sh: the exact-argv probes of 09z14 on the FINAL cfg (module defaults: rolling 0.008, carry 20, lateral 10; NO MICRODUCK_ env var set), then the e2e of the PROOF item 09z15 with test hooks.
#   1. probe-duck-task.sh (64 envs, 2 it, video, export)  2. probe-duck-warmstart.sh at 512 envs (mechanics)  3. probe-duck-warmstart.sh at 4096 envs (the item's pace, free card, Donald drained by the wrapper)
#   4. 09z15 from ~/Pollen/queue-staging with PROOF_TAG=e2e PROOF_N=1 DR_CKPT=<the e2e clone's checkpoint> DR_REF=<seed> PROOF_ONNX_GLOB=dribblee2e-*.onnx (one take per policy per batch, scorer + picker + clip cut run; its VERDICT line is meaningless at n=1)
# seed = duckdribble seed copy (duckvelstairs model_19000, md5 8a3de9ca). probe run dirs are MOVED aside (never deleted) into ~/Pollen/probe-aside-2026-10-27/.
# run through dribble-wrap-2026-10-27.sh 1 dribble <this>. log ~/Pollen/dribble-probes-2026-10-27.log
exec >> /home/witcheer/Pollen/dribble-probes-2026-10-27.log 2>&1
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl; A=$P/probe-aside-2026-10-27; mkdir -p $A
T=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck
SEED=$RL/logs/rsl_rl/duckdribble/2026-10-27_00-00-00_seed-velstairs-it19000/model_19000.pt
md5sum $SEED; env | grep ^MICRODUCK_ || echo "no MICRODUCK_ env set"
echo "=== $(date -u +%T) card: $(nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader)"
echo "=== $(date -u +%T) probe 1: exact-argv new task, 64 envs"; bash $P/probe-duck-task.sh dribble $T > /dev/null 2>&1; echo "probe1 rc=$?"
grep -a "train rc\|export rc" $P/probe-tasks.log | tail -n 2; mv $RL/logs/rsl_rl/probe-dribble $A/f-probe-dribble-64-$(date +%s)
echo "=== $(date -u +%T) probe 2: warm start 512 envs"; bash $P/probe-duck-warmstart.sh dribble $T $SEED 512 > /dev/null 2>&1; echo "probe2 rc=$?"
grep -a "Loading model checkpoint\|mismatch\|train rc\|export rc" $P/probe-dribble.log | tail -n 4; grep -a "Iteration time" $P/probe-dribble.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
mv $RL/logs/rsl_rl/probe-dribble $A/f-probe-dribble-512; mv $P/probe-dribble.log $P/probe-dribble-f512.log; mv $P/probe-dribble-vram.log $P/probe-dribble-f512-vram.log
echo "=== $(date -u +%T) probe 3: warm start 4096 envs"; bash $P/probe-duck-warmstart.sh dribble $T $SEED 4096 > /dev/null 2>&1; echo "probe3 rc=$?"
grep -a "Loading model checkpoint\|mismatch\|train rc\|card peak\|export rc" $P/probe-dribble.log | tail -n 5; grep -a "Iteration time" $P/probe-dribble.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
grep -a "Episode_Reward/ball\|Mean reward" $P/probe-dribble.log | tail -n 4
mv $RL/logs/rsl_rl/probe-dribble $A/f-probe-dribble-4096; mv $P/probe-dribble.log $P/probe-dribble-f4096.log; mv $P/probe-dribble-vram.log $P/probe-dribble-f4096-vram.log
echo "=== $(date -u +%T) e2e of the proof item 09z15 (hooks, n=1)"
E2EDIR=$(ls -d $RL/logs/rsl_rl/duckdribblee2e/*_duckdribblee2e | tail -n 1); N=$(ls $E2EDIR/model_*.pt | sed 's/.*model_//; s/.pt//' | sort -n | tail -n 1)
rm -f $P/proof-dr-?*.out
export PROOF_TAG=e2e PROOF_N=1 DR_CKPT=$E2EDIR/model_$N.pt DR_REF=$SEED PROOF_ONNX_GLOB='dribblee2e-*.onnx'
mkdir -p $P/e2e-2026-10-27-dribble-item
bash $P/queue-staging/09z15-duck-proof-dribble.sh; echo "09z15 e2e rc=$?"
echo "=== $(date -u +%T) PROBES_END card: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
