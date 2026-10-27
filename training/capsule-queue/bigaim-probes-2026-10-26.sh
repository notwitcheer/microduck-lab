#!/bin/bash
# bigaim-probes-2026-10-26.sh: the three exact-argv probes of 09z12 on the FINAL cfg (Big-Aim task, aim weight default 20 baked in the module, NO env var set):
#   1. probe-duck-task.sh (64 envs, 2 it, video, export)   2. probe-duck-warmstart.sh at 512 envs (mechanics)   3. probe-duck-warmstart.sh at 4096 envs (the item's pace, free card).
# seed = duckbigkick model_16000 (md5 71eab7c2). each probe's run dir is MOVED aside (never deleted) into ~/Pollen/probe-aside-2026-10-26/ so the real item starts clean.
# tmux "baprobes". log ~/Pollen/bigaim-probes-2026-10-26.log
exec >> /home/witcheer/Pollen/bigaim-probes-2026-10-26.log 2>&1
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl; A=$P/probe-aside-2026-10-26; mkdir -p $A
T=Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck
SEED=$RL/logs/rsl_rl/duckbigaim/2026-10-26_00-00-00_seed-bigkick-it16000/model_16000.pt
md5sum $SEED; env | grep ^MICRODUCK_ || echo "no MICRODUCK_ env set"
echo "=== $(date +%T) card: $(nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader)"
echo "=== $(date +%T) probe 1: exact-argv new task, 64 envs"; bash $P/probe-duck-task.sh bigaim $T > /dev/null 2>&1; echo "probe1 rc=$?"
grep -a "train rc\|export rc" $P/probe-tasks.log | tail -n 2; mv $RL/logs/rsl_rl/probe-bigaim $A/f-probe-bigaim-64-$(date +%s)
echo "=== $(date +%T) probe 2: warm start 512 envs"; bash $P/probe-duck-warmstart.sh bigaim $T $SEED 512 > /dev/null 2>&1; echo "probe2 rc=$?"
grep -a "Loading model checkpoint\|mismatch\|train rc\|export rc" $P/probe-bigaim.log | tail -n 4; grep -a "Iteration time" $P/probe-bigaim.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
grep -a "Episode_Reward/ball\|Mean reward" $P/probe-bigaim.log | tail -n 4
mv $RL/logs/rsl_rl/probe-bigaim $A/f-probe-bigaim-512; mv $P/probe-bigaim.log $P/probe-bigaim-f512.log; mv $P/probe-bigaim-vram.log $P/probe-bigaim-f512-vram.log
echo "=== $(date +%T) probe 3: warm start 4096 envs"; bash $P/probe-duck-warmstart.sh bigaim $T $SEED 4096 > /dev/null 2>&1; echo "probe3 rc=$?"
grep -a "Loading model checkpoint\|mismatch\|train rc\|card peak\|export rc" $P/probe-bigaim.log | tail -n 5; grep -a "Iteration time" $P/probe-bigaim.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
grep -a "Episode_Reward/ball\|Mean reward" $P/probe-bigaim.log | tail -n 4
mv $RL/logs/rsl_rl/probe-bigaim $A/f-probe-bigaim-4096; mv $P/probe-bigaim.log $P/probe-bigaim-f4096.log; mv $P/probe-bigaim-vram.log $P/probe-bigaim-f4096-vram.log
echo "=== $(date +%T) PROBES_END card: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
