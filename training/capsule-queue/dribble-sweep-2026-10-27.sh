#!/bin/bash
# dribble-sweep-2026-10-27.sh: pre-queue design probe of 09z14 (the duck walks the giant ball). picks the reward weights from evidence instead of a guess.
# seed = SEED (default: the seed the seed takes picked, see the vault log 2026-10-27), N = its iteration. for each setting "<name>:<W_CARRY>,<W_LAT>": ITS (200) warm-start iterations at
# 4096 envs on Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck (setting = "<name>:<W_CARRY>,<W_LAT>[,<FAR>[,<ROLL>]]" -> MICRODUCK_DRIBBLE_W_CARRY / _W_LAT / _FAR / _ROLL set per run, save every 20), then 1-env goal-mode takes (TAKES, default 6) of the
# +100 and +ITS checkpoints at command vx VX (0.25), plus TAKES takes of the seed as the same-day reference. every number is printed by dr-score-2026-10-27.py --dir.
# a probe (card time ~25 min, allowed outside heures creuses on a free card: run it through dribble-wrap-2026-10-27.sh 1 <tag> this-script, which drains Donald through night-lib).
# log ~/Pollen/dribble-sweep-2026-10-27.log. probe run dirs stay under logs/rsl_rl/probe-dribble-<name> (moved aside by hand).
exec >> /home/witcheer/Pollen/dribble-sweep-2026-10-27.log 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
P=/home/witcheer/Pollen; RL=$P/microduck_rl; T=Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck
SEED=${SEED:?seed checkpoint}; N=${N:?seed iteration}; SETS=${SETS:-"c10:10,0 c10l10:10,10 c20l10:20,10"}; KS=${KS:-"100 200"}; SKIPSEED=${SKIPSEED:-0}; ITS=${ITS:-200}; VX=${VX:-0.25}; TAKES=${TAKES:-6}; TAG=${TAG:-2026-10-27}
cd $RL
md5sum $SEED
for S in $SETS; do
  name=${S%%:*}; IFS=, read -r WC WL FAR ROLL <<<"${S#*:}"; FAR=${FAR:-0}; ROLL=${ROLL:-0}
  exp=probe-dribble-$name; seed=seed-it$N
  rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed; cp $SEED logs/rsl_rl/$exp/$seed/model_$N.pt
  echo "=== $(date -u +%T) $name: W_CARRY=$WC W_LAT=$WL FAR=$FAR ROLL=$ROLL, $ITS warm-start iterations, 4096 envs ==="
  ( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > $P/dribble-sweep-$name-vram.log & SP=$!
  t0=$(date +%s)
  MICRODUCK_DRIBBLE_W_CARRY=$WC MICRODUCK_DRIBBLE_W_LAT=$WL MICRODUCK_DRIBBLE_FAR=$FAR MICRODUCK_DRIBBLE_ROLL=$ROLL timeout 1500 uv run train $T --env.scene.num-envs 4096 --agent.max-iterations $((ITS+1)) --agent.save-interval 20 --agent.logger tensorboard \
    --agent.experiment-name $exp --agent.run-name $exp --agent.resume True --agent.load-run $seed --agent.load-checkpoint model_$N.pt > $P/dribble-sweep-$name.train.log 2>&1; rc=$?
  kill $SP 2>/dev/null
  echo "$name train rc=$rc in $(( $(date +%s)-t0 )) s, card peak MiB $(sort -n $P/dribble-sweep-$name-vram.log | tail -n 1)"
  grep -a "Loading model checkpoint\|size mismatch" $P/dribble-sweep-$name.train.log | head -n 2
  grep -a "Iteration time" $P/dribble-sweep-$name.train.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
  python3 - $P/dribble-sweep-$name.train.log <<'PY'
import re, sys
t = open(sys.argv[1], errors='replace').read(); blocks = re.split(r'Learning iteration (\d+)/\d+', t)
rows = {}
for i in range(1, len(blocks) - 1, 2):
    it = int(blocks[i]); b = blocks[i + 1]
    g = lambda k: (re.search(k + r':\s*(-?[\d.]+)', b) or [None, 'nan'])[1]
    rows[it] = (g('Mean reward'), g('Episode_Reward/ball_carry'), g('Episode_Reward/ball_lateral'), g('Episode_Reward/track_linear_velocity'), g('Episode_Termination/fell_over'), g('Episode_Termination/ball_escaped'))
for it in sorted(rows):
    if it % 40 == 0 or it == max(rows) or it == min(rows): print('  it', it, 'mean', rows[it][0], 'carry', rows[it][1], 'lateral', rows[it][2], 'track_lin', rows[it][3], 'fell_over', rows[it][4], 'ball_escaped', rows[it][5])
PY
done
echo "=== $(date -u +%T) takes: $TAKES per checkpoint, batches in parallel ==="
OUTP=dribble-sweep-$TAG
RO=""; for S in $SETS; do IFS=, read -r _a _b _c ROLL <<<"${S#*:}"; ROLL=${ROLL:-0}; case " $RO " in *" $ROLL "*) ;; *) RO="$RO $ROLL";; esac; done
[ "$SKIPSEED" = 1 ] || for RR in $RO; do ( MICRODUCK_DRIBBLE_ROLL=$RR bash $P/dribble-takes-2026-10-27.sh $OUTP-seed-r$RR ref$RR $T $SEED $VX $TAKES > /dev/null 2>&1 ) & done
for S in $SETS; do name=${S%%:*}; IFS=, read -r _a _b _c ROLL <<<"${S#*:}"; ROLL=${ROLL:-0}; for K in $KS; do
  run=$(ls -d $RL/logs/rsl_rl/probe-dribble-$name/*_probe-dribble-$name/ 2>/dev/null | tail -n 1); ck=$run/model_$((N+K)).pt
  ( MICRODUCK_DRIBBLE_ROLL=$ROLL bash $P/dribble-takes-2026-10-27.sh $OUTP-$name-$K ${name}i$K $T $ck $VX $TAKES > /dev/null 2>&1 ) &
done; done
wait
echo "=== $(date -u +%T) READ ==="
[ "$SKIPSEED" = 1 ] || for RR in $RO; do echo "seed (roll $RR):"; python3 $P/dr-score-2026-10-27.py --dir $P/clips/$OUTP-seed-r$RR ref$RR | tail -n 1; done
for S in $SETS; do name=${S%%:*}; for K in $KS; do echo "$name +$K it:"; python3 $P/dr-score-2026-10-27.py --dir $P/clips/$OUTP-$name-$K ${name}i$K | tail -n 1; done; done
echo "=== $(date -u +%T) SWEEP_END ==="
