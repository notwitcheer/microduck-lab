#!/bin/bash
# hop2-ext-2026-10-29.sh: a CONTINUATION of one sweep run (run under hop2-wrap): resume from the sweep run's own checkpoint (model + optimizer, no std patch) for ITS more iterations, then 8 CPU takes of the +N checkpoints, strict scorer.
#   S = new setting name (e.g. A2), FROM = the sweep exp dir name (probe-hop2-A), FROMIT = checkpoint iteration to resume (7300), H2TERM, W as in the sweep, ITS (default 200), NT, CKNS = offsets from the resume point to score (default "100 200").
# same task, same argv as the item apart from the iteration count and the save interval (50), 4096 envs.
S=${S:?}; FROM=${FROM:?}; FROMIT=${FROMIT:?}; H2TERM=${H2TERM:-0}; W=${W:-}; ITS=${ITS:-200}; ENT=${ENT:-0.02}; NT=${NT:-8}; CKNS=${CKNS:-100 200}
LOG=/home/witcheer/Pollen/hop2-sweep-2026-10-29.log
exec >> $LOG 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
P=/home/witcheer/Pollen; RL=$P/microduck_rl; T=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
SRC=$(ls -d $RL/logs/rsl_rl/$FROM/*_$FROM | tail -n 1)/model_$FROMIT.pt
exp=probe-hop2-$S; seed=seed-it$FROMIT; cd $RL
[ -f "$SRC" ] || { echo "NO_SOURCE_CHECKPOINT $SRC"; exit 2; }
rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed; cp "$SRC" logs/rsl_rl/$exp/$seed/model_$FROMIT.pt; md5sum "$SRC" logs/rsl_rl/$exp/$seed/model_$FROMIT.pt
echo "=== $(date -u +%T) hop2 continuation $S: $ITS more iterations from $FROM model_$FROMIT, entropy $ENT, TERM=$H2TERM, W=${W:-default}, 4096 envs ==="
( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > $P/hop2-sweep-$S-vram.log & SP=$!
t0=$(date +%s)
env MICRODUCK_HOP2_TERM=$H2TERM ${W:+MICRODUCK_HOP2_W=$W} timeout 1500 uv run train $T --env.scene.num-envs 4096 --agent.max-iterations $((ITS+1)) --agent.save-interval 50 --agent.logger tensorboard \
  --agent.algorithm.entropy-coef $ENT --agent.experiment-name $exp --agent.run-name $exp --agent.resume True --agent.load-run $seed --agent.load-checkpoint model_$FROMIT.pt > $P/hop2-sweep-$S.train.log 2>&1; rc=$?
kill $SP 2>/dev/null
dt=$(( $(date +%s)-t0 ))
echo "$S train rc=$rc in $dt s ($(awk -v a=$dt -v b=$ITS 'BEGIN{printf "%.2f", a/b}') s/it incl. start), card peak MiB $(sort -n $P/hop2-sweep-$S-vram.log | tail -n 1)"
grep -a "Loading model checkpoint\|size mismatch" $P/hop2-sweep-$S.train.log | head -n 2
python3 - $P/hop2-sweep-$S.train.log <<'PY'
import re, sys
t = open(sys.argv[1], errors='replace').read(); blocks = re.split(r'Learning iteration (\d+)/\d+', t)
rows = {}
for i in range(1, len(blocks) - 1, 2):
    it = int(blocks[i]); b = blocks[i + 1]
    g = lambda k: (re.search(k + r':\s*(-?[\d.]+)', b) or [None, 'nan'])[1]
    rows[it] = (g('Mean reward'), g('Episode_Reward/hop2_flight'), g('Episode_Reward/hop2_clearance'), g('Episode_Reward/hop2_nonsole'), g('Episode_Termination/fell_over'), g('Mean episode length'), g('Mean action std'))
for it in sorted(rows):
    if it % 40 == 0 or it == max(rows) or it == min(rows): print('  it', it, 'mean', rows[it][0], 'flight', rows[it][1], 'clear', rows[it][2], 'nonsole', rows[it][3], 'fell_over', rows[it][4], 'ep_len', rows[it][5], 'std', rows[it][6])
PY
run=$(ls -d $RL/logs/rsl_rl/$exp/*_$exp/ | tail -n 1)
for N in $CKNS; do
  ck=$run/model_$((FROMIT+N)).pt
  [ -f "$ck" ] && ( bash $P/hop2-dev/strict-takes-2026-10-29.sh sweep-$S-$N s$S$N $ck $NT 6 $T > /dev/null 2>&1 )
done
for N in $CKNS; do echo "$S +$N it (after $FROMIT; +$((FROMIT+N-7000)) from the seed):"; python3 $P/hop2-score-2026-10-29.py --dir $P/hop2-dev/sweep-$S-$N s$S$N | tail -n 1; done
echo "=== $(date -u +%T) HOP2_EXT_END $S ==="
