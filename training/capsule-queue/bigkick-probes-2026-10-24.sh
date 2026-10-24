#!/bin/bash
# bigkick-probes-2026-10-24.sh: the three exact-argv probes of 09z10 on the FINAL giant-ball cfg (r 0.15 m, 0.275 kg), run beside the sub10 bench leg (llama-server 10.3 GB, 97% util):
#   1. probe-duck-task.sh (64 envs, 2 it, video, export)   2. probe-duck-warmstart.sh at 512 envs (mechanics)   3. probe-duck-warmstart.sh at 4096 envs (peak VRAM; the pace is
#   CONTENDED by the bench leg and only an upper bound). each probe's run dir is MOVED aside (never deleted) into ~/Pollen/probe-aside-2026-10-24/ so the real item starts clean.
# tmux "bkprobes". log ~/Pollen/bigkick-probes-2026-10-24.log
exec >> /home/witcheer/Pollen/bigkick-probes-2026-10-24.log 2>&1
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl; A=$P/probe-aside-2026-10-24; mkdir -p $A
T=Mjlab-BallKick-Flat-Backlash-Big-MicroDuck
SEED=$RL/logs/rsl_rl/duckbigkick/2026-10-24_00-00-00_seed-kickbl-it13000/model_13000.pt
md5sum $SEED
echo "=== $(date +%T) card: $(nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader)"
echo "=== $(date +%T) probe 1: exact-argv new task, 64 envs"; bash $P/probe-duck-task.sh bigkick $T > /dev/null 2>&1; echo "probe1 rc=$?"
grep -a "train rc\|export rc" $P/probe-tasks.log | tail -n 2; mv $RL/logs/rsl_rl/probe-bigkick $A/g-probe-bigkick-64
echo "=== $(date +%T) probe 2: warm start 512 envs"; bash $P/probe-duck-warmstart.sh bigkick $T $SEED 512 > /dev/null 2>&1; echo "probe2 rc=$?"
grep -a "Loading model checkpoint\|mismatch\|train rc\|export rc" $P/probe-bigkick.log | tail -n 4; grep -a "Iteration time" $P/probe-bigkick.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
grep -a "Episode_Reward/ball\|Mean reward" $P/probe-bigkick.log | tail -n 3
mv $RL/logs/rsl_rl/probe-bigkick $A/g-probe-bigkick-512; mv $P/probe-bigkick.log $P/probe-bigkick-g512.log; mv $P/probe-bigkick-vram.log $P/probe-bigkick-g512-vram.log
echo "=== $(date +%T) probe 3: warm start 4096 envs"; bash $P/probe-duck-warmstart.sh bigkick $T $SEED 4096 > /dev/null 2>&1; echo "probe3 rc=$?"
grep -a "Loading model checkpoint\|mismatch\|train rc\|card peak\|export rc" $P/probe-bigkick.log | tail -n 5; grep -a "Iteration time" $P/probe-bigkick.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
grep -a "Episode_Reward/ball\|Mean reward" $P/probe-bigkick.log | tail -n 3
mv $RL/logs/rsl_rl/probe-bigkick $A/g-probe-bigkick-4096; mv $P/probe-bigkick.log $P/probe-bigkick-g4096.log; mv $P/probe-bigkick-vram.log $P/probe-bigkick-g4096-vram.log
echo "=== $(date +%T) PROBES_END card: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
