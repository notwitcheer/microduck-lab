#!/bin/bash
# dribble-seed-matrix-2026-10-27.sh: the seed feasibility read of 09z14, no training. three walk checkpoints through the dribble condition (300 mm ball 0.27 m ahead, goal mode,
# forced forward command, no shoves), 20 s takes, N takes per command speed, one batch per seed in parallel (separate OUT dirs).
#   bl = walk-flat v2 (duckvelbl model_7000), ms = walk-mixslope (duckvelmixslope model_16000), st = walk-stairs (duckvelstairs model_19000)
# prefixes <seed><vx*100>, e.g. bl20-t1. read: python3 ~/Pollen/dr-score-2026-10-27.py --dir ~/Pollen/clips/dribble-seed-bl-2026-10-27 bl10 bl20 bl30 --rows
P=/home/witcheer/Pollen; RL=$P/microduck_rl/logs/rsl_rl; T=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck; N=${N:-2}; VXS=${VXS:-"0.10 0.20 0.30"}
declare -A CK=( [bl]=$(ls $RL/duckvelbl/*_duckvelbl/model_7000.pt | tail -n 1) [ms]=$(ls $RL/duckvelmixslope/*_duckvelmixslope/model_16000.pt | tail -n 1) [st]=$(ls $RL/duckvelstairs/*_duckvelstairs/model_19000.pt | tail -n 1) )
for s in ${SEEDS:-bl ms st}; do
  ( for vx in $VXS; do pf=$s$(printf %02d $(python3 -c "print(round($vx*100))")); bash $P/dribble-takes-2026-10-27.sh dribble-seed-$s-${RND:-2026-10-27} $pf $T ${CK[$s]} $vx $N; done ) > $P/dribble-seed-$s.out 2>&1 &
done
wait
echo "=== $(date -u +%T) SEED_MATRIX_END ==="
