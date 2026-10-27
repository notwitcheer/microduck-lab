#!/bin/bash
# hop-lever2-2026-10-27.sh: the ONE more lever tried after the reward sweep found nothing (pre-queue design probe of 09z16; run under hop-wrap). setting L2 = the exploration lever:
#   seed checkpoint with distribution.std_param bumped 0.19 -> STD (default 0.6, the maker's mean is 0.19) AND --agent.algorithm.entropy-coef $ENT (PPO undoes a bare std bump at 0.01 within ~100 it),
#   push-off pay raised and the penalties it fights lowered: MICRODUCK_HOP_W=12,6,6,0.02  MICRODUCK_HOP_FREE=1 (pose 0.1, action_rate -0.02).
# 200 warm-start iterations at 4096 envs, then 4 takes each of the +100 / +200 checkpoints (deterministic mean policy, hop play env). read: python3 ~/Pollen/hop-score-2026-10-27.py --dir ~/Pollen/clips/hop-sweep-L2-<N> L2i<N>
S=${S:-L2}; W=${W:-12,6,6,0.02}; STD=${STD:-0.6}; ITS=${ITS:-200}; ENT=${ENT:-0.02}   # variants of the exploration lever reuse this script (S = setting name)
exec >> /home/witcheer/Pollen/hop-lever2-2026-10-27.log 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
P=/home/witcheer/Pollen; RL=$P/microduck_rl; T=Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck
SEEDPT=$(ls $RL/logs/rsl_rl/duckvelbl/*_duckvelbl/model_7000.pt | tail -n 1)
exp=probe-hop-$S; seed=seed-it7000; cd $RL
rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed
uv run python - "$SEEDPT" logs/rsl_rl/$exp/$seed/model_7000.pt "$STD" <<'PY' 2>&1 | grep -v Warning
import sys, torch
ck = torch.load(sys.argv[1], map_location="cpu", weights_only=False)
sp = ck["actor_state_dict"]["distribution.std_param"]; print("std_param before", float(sp.mean()))
ck["actor_state_dict"]["distribution.std_param"] = torch.full_like(sp, float(sys.argv[3]))
torch.save(ck, sys.argv[2]); print("std_param after", float(sys.argv[3]))
PY
echo "=== $(date -u +%T) $S: $ITS warm-start iterations, std $STD, entropy $ENT, weights $W, 4096 envs ==="
( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > $P/hop-sweep-$S-vram.log & SP=$!
t0=$(date +%s)
MICRODUCK_HOP_W=$W MICRODUCK_HOP_FREE=1 timeout 1500 uv run train $T --env.scene.num-envs 4096 --agent.max-iterations $((ITS+1)) --agent.save-interval 50 --agent.logger tensorboard \
  --agent.algorithm.entropy-coef $ENT --agent.experiment-name $exp --agent.run-name $exp --agent.resume True --agent.load-run $seed --agent.load-checkpoint model_7000.pt > $P/hop-sweep-$S.train.log 2>&1; rc=$?
kill $SP 2>/dev/null
echo "$S train rc=$rc in $(( $(date +%s)-t0 )) s, card peak MiB $(sort -n $P/hop-sweep-$S-vram.log | tail -n 1)"
grep -a "Loading model checkpoint\|size mismatch" $P/hop-sweep-$S.train.log | head -n 2
python3 - $P/hop-sweep-$S.train.log <<'PY'
import re, sys
t = open(sys.argv[1], errors='replace').read(); blocks = re.split(r'Learning iteration (\d+)/\d+', t)
rows = {}
for i in range(1, len(blocks) - 1, 2):
    it = int(blocks[i]); b = blocks[i + 1]
    g = lambda k: (re.search(k + r':\s*(-?[\d.]+)', b) or [None, 'nan'])[1]
    rows[it] = (g('Mean reward'), g('Episode_Reward/hop_flight'), g('Episode_Reward/hop_clearance'), g('Episode_Reward/hop_vz'), g('Episode_Reward/hop_impact'), g('Episode_Termination/fell_over'), g('Mean episode length'), g('Mean action noise std'))
for it in sorted(rows):
    if it % 40 == 0 or it == max(rows) or it == min(rows): print('  it', it, 'mean', rows[it][0], 'flight', rows[it][1], 'clear', rows[it][2], 'vz', rows[it][3], 'impact', rows[it][4], 'fell_over', rows[it][5], 'ep_len', rows[it][6], 'std', rows[it][7])
PY
for N in 100 200; do
  run=$(ls -d $RL/logs/rsl_rl/$exp/*_$exp/ | tail -n 1); ck=$run/model_$((7000+N)).pt
  ( bash $P/hop-takes-2026-10-27.sh hop-sweep-$S-$N ${S}i$N $ck 4 > /dev/null 2>&1 ) &
done
wait
for N in 100 200; do echo "$S +$N it:"; python3 $P/hop-score-2026-10-27.py --dir $P/clips/hop-sweep-$S-$N ${S}i$N; done
echo "=== $(date -u +%T) LEVER2_END ==="
