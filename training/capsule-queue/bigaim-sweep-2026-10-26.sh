#!/bin/bash
# bigaim-sweep-2026-10-26.sh: pre-queue design probe of 09z12 (giant-ball kick that AIMS). picks the weight of the aim term from evidence instead of a guess.
# seed = duckbigkick model_16000 (md5 71eab7c2...). for each aim weight W in "3 8 20": 200 warm-start iterations at 4096 envs (task Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck,
# MICRODUCK_BIGAIM_W=W, save every 20 so the +40 checkpoint exists), then 1-env goal-mode takes (6 each) of the +40 and +200 checkpoints, plus 6 takes of the seed as the same-day reference.
# every number is printed by ba-score-2026-10-26.py --dir. card time ~15 min of training + ~6 min of takes, a probe (allowed outside heures creuses on a free card, owner check first).
# tmux "bapr", log ~/Pollen/bigaim-sweep-2026-10-26.log. probe run dirs stay under logs/rsl_rl/probe-bigaim-w<W> (moved aside afterwards by hand).
exec >> /home/witcheer/Pollen/bigaim-sweep-2026-10-26.log 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
P=/home/witcheer/Pollen; RL=$P/microduck_rl; T=Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck
SEED=${SEED:-$RL/logs/rsl_rl/duckbigkick/2026-10-25_08-12-58_duckbigkick/model_16000.pt}
WS=${WS:-"3 8 20"}; ITS=${ITS:-200}; TAG=${TAG:-2026-10-26}
cd $RL
md5sum $SEED
for W in $WS; do
  exp=probe-bigaim-w$W; seed=seed-it16000
  rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed; cp $SEED logs/rsl_rl/$exp/$seed/model_16000.pt
  echo "=== $(date -u +%T) W=$W: $ITS warm-start iterations, 4096 envs ==="
  ( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > $P/bigaim-sweep-w$W-vram.log & SP=$!
  t0=$(date +%s)
  MICRODUCK_BIGAIM_W=$W timeout 1500 uv run train $T --env.scene.num-envs 4096 --agent.max-iterations $((ITS+1)) --agent.save-interval 20 --agent.logger tensorboard \
    --agent.experiment-name $exp --agent.run-name $exp --agent.resume True --agent.load-run $seed --agent.load-checkpoint model_16000.pt > $P/bigaim-sweep-w$W.train.log 2>&1; rc=$?
  kill $SP 2>/dev/null
  echo "W=$W train rc=$rc in $(( $(date +%s)-t0 )) s, card peak MiB $(sort -n $P/bigaim-sweep-w$W-vram.log | tail -n 1)"
  grep -a "Loading model checkpoint\|size mismatch" $P/bigaim-sweep-w$W.train.log | head -n 2
  grep -a "Iteration time" $P/bigaim-sweep-w$W.train.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
  python3 - $P/bigaim-sweep-w$W.train.log <<'PY'
import re, sys
t = open(sys.argv[1], errors='replace').read(); blocks = re.split(r'Learning iteration (\d+)/\d+', t)
rows = {}
for i in range(1, len(blocks) - 1, 2):
    it = int(blocks[i]); b = blocks[i + 1]
    g = lambda k: (re.search(k + r':\s*(-?[\d.]+)', b) or [None, 'nan'])[1]
    rows[it] = (g('Mean reward'), g('Episode_Reward/ball_forward_velocity'), g('Episode_Reward/ball_lateral'), g('Episode_Reward/ball_speed_overshoot'), g('Episode_Termination/fell_over'))
for it in sorted(rows):
    if it % 40 == 0 or it == max(rows) or it == min(rows): print('  it', it, 'mean', rows[it][0], 'fwd', rows[it][1], 'lateral', rows[it][2], 'overshoot', rows[it][3], 'fell_over', rows[it][4])
PY
done
echo "=== $(date -u +%T) takes: 6 per checkpoint, seven batches in parallel ==="
OUTP=bigaim-sweep-$TAG
( bash $P/bigaim-takes-2026-10-26.sh $OUTP-seed ref Mjlab-BallKick-Flat-Backlash-Big-MicroDuck $SEED 6 > /dev/null 2>&1 ) &
for W in $WS; do for N in 40 200; do
  run=$(ls -d $RL/logs/rsl_rl/probe-bigaim-w$W/*_probe-bigaim-w$W/ 2>/dev/null | tail -n 1); ck=$run/model_$((16000+N)).pt
  ( bash $P/bigaim-takes-2026-10-26.sh $OUTP-w$W-$N w${W}i$N $T $ck 6 > /dev/null 2>&1 ) &
done; done
wait
echo "=== $(date -u +%T) READ ==="
echo "seed (bigkick 16000):"; python3 $P/ba-score-2026-10-26.py --dir $P/clips/$OUTP-seed ref | tail -n 1
for W in $WS; do for N in 40 200; do echo "W=$W +$N it:"; python3 $P/ba-score-2026-10-26.py --dir $P/clips/$OUTP-w$W-$N w${W}i$N | tail -n 1; done; done
echo "=== $(date -u +%T) SWEEP_END ==="
