#!/bin/bash
# hop2-sweep-2026-10-29.sh: ONE short warm-start sweep of the hop2 task (run under hop2-wrap, card only for the training; the takes are CPU-only).
#   S = setting name, STD = seed std_param, H2TERM = MICRODUCK_HOP2_TERM, W = MICRODUCK_HOP2_W (empty = module default), ITS = iterations (default 300), ENT = entropy coef (default 0.02).
# the exploration lever of the 2026-10-27 hop design (seed std 0.19 -> 0.6, entropy-coef 0.02, FREE penalties = module default) on the v2 rewards. 4096 envs, --agent.save-interval 50.
# then 8 CPU takes (strict logger, hop2 play env) of the +100, +200 and +300 checkpoints, scored with hop2-score-2026-10-29.py. EXACT argv of the item apart from the iteration count and the save interval.
S=${S:-A}; STD=${STD:-0.6}; H2TERM=${H2TERM:-0}; W=${W:-}; ITS=${ITS:-300}; ENT=${ENT:-0.02}; NT=${NT:-8}
ENVS=${ENVS:-4096}; SAVE=${SAVE:-50}; XARGS=${XARGS:-}; CKNS=${CKNS:-100 200 300}   # ENVS/SAVE/XARGS/CKNS: CPU smoke hooks only (the real sweep uses the defaults)
LOG=${SWEEP_LOG:-/home/witcheer/Pollen/hop2-sweep-2026-10-29.log}
exec >> $LOG 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
P=/home/witcheer/Pollen; RL=$P/microduck_rl; T=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
SEEDPT=$(ls $RL/logs/rsl_rl/duckvelbl/*_duckvelbl/model_7000.pt | tail -n 1)
exp=probe-hop2-$S; seed=seed-it7000; cd $RL
rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed
uv run python - "$SEEDPT" logs/rsl_rl/$exp/$seed/model_7000.pt "$STD" <<'PY' 2>&1 | grep -v Warning
import sys, torch
ck = torch.load(sys.argv[1], map_location="cpu", weights_only=False)
sp = ck["actor_state_dict"]["distribution.std_param"]; print("std_param before", float(sp.mean()))
ck["actor_state_dict"]["distribution.std_param"] = torch.full_like(sp, float(sys.argv[3]))
torch.save(ck, sys.argv[2]); print("std_param after", float(sys.argv[3]))
PY
echo "=== $(date -u +%T) hop2 sweep $S: $ITS warm-start iterations, std $STD, entropy $ENT, TERM=$H2TERM, W=${W:-default}, 4096 envs ==="
( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > $P/hop2-sweep-$S-vram.log & SP=$!
t0=$(date +%s)
env MICRODUCK_HOP2_TERM=$H2TERM ${W:+MICRODUCK_HOP2_W=$W} timeout 1500 uv run train $T --env.scene.num-envs $ENVS --agent.max-iterations $((ITS+1)) --agent.save-interval $SAVE --agent.logger tensorboard $XARGS \
  --agent.algorithm.entropy-coef $ENT --agent.experiment-name $exp --agent.run-name $exp --agent.resume True --agent.load-run $seed --agent.load-checkpoint model_7000.pt > $P/hop2-sweep-$S.train.log 2>&1; rc=$?
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
    rows[it] = (g('Mean reward'), g('Episode_Reward/hop2_flight'), g('Episode_Reward/hop2_clearance'), g('Episode_Reward/hop2_vz'), g('Episode_Reward/hop2_impact'), g('Episode_Reward/hop2_nonsole'), g('Episode_Termination/fell_over'), g('Episode_Termination/hop2_nonsole_contact'), g('Mean episode length'), g('Mean action std'))
for it in sorted(rows):
    if it % 40 == 0 or it == max(rows) or it == min(rows): print('  it', it, 'mean', rows[it][0], 'flight', rows[it][1], 'clear', rows[it][2], 'vz', rows[it][3], 'impact', rows[it][4], 'nonsole', rows[it][5], 'fell_over', rows[it][6], 'term_nonsole', rows[it][7], 'ep_len', rows[it][8], 'std', rows[it][9])
PY
run=$(ls -d $RL/logs/rsl_rl/$exp/*_$exp/ | tail -n 1)
for N in $CKNS; do
  ck=$run/model_$((7000+N)).pt
  [ -f "$ck" ] && ( bash $P/hop2-dev/strict-takes-2026-10-29.sh sweep-$S-$N s$S$N $ck $NT 6 $T > /dev/null 2>&1 )
done
for N in $CKNS; do echo "$S +$N it:"; python3 $P/hop2-score-2026-10-29.py --dir $P/hop2-dev/sweep-$S-$N s$S$N | tail -n 1; done
echo "=== $(date -u +%T) HOP2_SWEEP_END $S ==="
