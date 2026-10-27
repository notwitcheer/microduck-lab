#!/bin/bash
# hop-sweep-2026-10-27.sh: pre-queue design probe of 09z16 (Microduck HOP). answers the two questions before any queueing:
#   (1) the SEED through the condition: velbl model_7000 (walk-flat v2, the warm start) in the hop play env, per-step flight log (does it ever have both feet off the ground? expected: no).
#   (2) can the hop be DISCOVERED from that seed at all: for each reward setting W in "S1 S2 S3": 200 warm-start iterations at 4096 envs (task Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck,
#       MICRODUCK_HOP_W=flight,clearance,vz,impact), checkpoints every 50 it, then 1-env takes (hop_play --hop-log, 6 s) of the +100 and +200 checkpoints.
# settings (flight,clearance,vz,impact):  S1 8,4,1.5,0.05 (module default)   S2 12,6,3,0.02 (stronger push-off pay)   S3 0,8,2,0.05 (no flight bonus: the dense clearance gradient alone)
# read with: python3 ~/Pollen/hop-score-2026-10-27.py --dir ~/Pollen/clips/<out> <prefix>. runs under hop-wrap (shared-card protocol). ~15 min of training + ~3 min of takes.
# env: WS (settings to run), ITS (iterations, default 200), SEEDPT, TAKES (per checkpoint, default 4)
exec >> /home/witcheer/Pollen/hop-sweep-2026-10-27.log 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH MUJOCO_GL=egl
P=/home/witcheer/Pollen; RL=$P/microduck_rl; T=Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck
SEEDPT=${SEEDPT:-$(ls $RL/logs/rsl_rl/duckvelbl/*_duckvelbl/model_7000.pt | tail -n 1)}
ITS=${ITS:-200}; TAKES=${TAKES:-4}; WS=${WS:-"S1 S2 S3"}
declare -A WV=( [S1]="8,4,1.5,0.05" [S2]="12,6,3,0.02" [S3]="0,8,2,0.05" [S4]="${S4_W:-8,8,1.5,0.05}" )
cd $RL
md5sum $SEEDPT
echo "=== $(date -u +%T) seed takes (velbl 7000 in the hop play env) ==="
bash $P/hop-takes-2026-10-27.sh hop-sweep-seed seed $SEEDPT 8 > /dev/null 2>&1
python3 $P/hop-score-2026-10-27.py --dir $P/clips/hop-sweep-seed seed | tail -n 9
for S in $WS; do
  exp=probe-hop-$S; seed=seed-it7000
  rm -rf logs/rsl_rl/$exp; mkdir -p logs/rsl_rl/$exp/$seed; cp $SEEDPT logs/rsl_rl/$exp/$seed/model_7000.pt
  echo "=== $(date -u +%T) $S (${WV[$S]}): $ITS warm-start iterations, 4096 envs ==="
  ( while sleep 2; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; done ) > $P/hop-sweep-$S-vram.log & SP=$!
  t0=$(date +%s)
  MICRODUCK_HOP_W=${WV[$S]} timeout 1500 uv run train $T --env.scene.num-envs 4096 --agent.max-iterations $((ITS+1)) --agent.save-interval 50 --agent.logger tensorboard \
    --agent.experiment-name $exp --agent.run-name $exp --agent.resume True --agent.load-run $seed --agent.load-checkpoint model_7000.pt > $P/hop-sweep-$S.train.log 2>&1; rc=$?
  kill $SP 2>/dev/null
  echo "$S train rc=$rc in $(( $(date +%s)-t0 )) s, card peak MiB $(sort -n $P/hop-sweep-$S-vram.log | tail -n 1)"
  grep -a "Loading model checkpoint\|size mismatch" $P/hop-sweep-$S.train.log | head -n 2
  grep -a "Iteration time" $P/hop-sweep-$S.train.log | awk '{s+=$3; n++} END{print "mean Iteration time", s/n, "s over", n}'
  python3 - $P/hop-sweep-$S.train.log <<'PY'
import re, sys
t = open(sys.argv[1], errors='replace').read(); blocks = re.split(r'Learning iteration (\d+)/\d+', t)
rows = {}
for i in range(1, len(blocks) - 1, 2):
    it = int(blocks[i]); b = blocks[i + 1]
    g = lambda k: (re.search(k + r':\s*(-?[\d.]+)', b) or [None, 'nan'])[1]
    rows[it] = (g('Mean reward'), g('Episode_Reward/hop_flight'), g('Episode_Reward/hop_clearance'), g('Episode_Reward/hop_vz'), g('Episode_Reward/hop_impact'), g('Episode_Termination/fell_over'), g('Mean episode length'))
for it in sorted(rows):
    if it % 40 == 0 or it == max(rows) or it == min(rows): print('  it', it, 'mean', rows[it][0], 'flight', rows[it][1], 'clear', rows[it][2], 'vz', rows[it][3], 'impact', rows[it][4], 'fell_over', rows[it][5], 'ep_len', rows[it][6])
PY
done
echo "=== $(date -u +%T) takes: $TAKES per checkpoint, batches in parallel ==="
for S in $WS; do for N in 100 200; do
  run=$(ls -d $RL/logs/rsl_rl/probe-hop-$S/*_probe-hop-$S/ 2>/dev/null | tail -n 1); ck=$run/model_$((7000+N)).pt
  ( bash $P/hop-takes-2026-10-27.sh hop-sweep-$S-$N ${S}i$N $ck $TAKES > /dev/null 2>&1 ) &
done; done
wait
echo "=== $(date -u +%T) READ ==="
echo "seed (velbl 7000):"; python3 $P/hop-score-2026-10-27.py --dir $P/clips/hop-sweep-seed seed | tail -n 1
for S in $WS; do for N in 100 200; do echo "$S (${WV[$S]}) +$N it:"; python3 $P/hop-score-2026-10-27.py --dir $P/clips/hop-sweep-$S-$N ${S}i$N; done; done
echo "=== $(date -u +%T) SWEEP_END ==="
