#!/bin/bash
# proof-bk-c (2026-10-24, staged with 09z10): SMALL BALL (the stock backlash kick task, 70 mm / 15 g), random heading, NO shoves. NO-LOSS CONDITION: success = held AND the ball >= 1.0 m from its start by 3 s; two-sided Fisher, a loss = significant with the new policy lower.
# policies: bknc-tN = the 09z10 giant-ball kick (duckbigkick model_16000), bksc-tN = its seed (09l kickbl model_13000, trained on the 70 mm / 15 g ball).
# 10 takes per policy, 1 env, standing spawn, 6 s episodes, 0.1 s samples, 1280x720, camera D (fixed world camera, az 65 / 1.75 m / -18 deg, lookat 0.8,0,0.12: duck, giant ball and goal in frame; checked on seed takes 2026-10-24).
# test hooks (e2e of the proof item only): PROOF_TAG (OUT suffix), PROOF_N (takes per policy), BK_CKPT (checkpoint override); defaults are the real run.
# take names carry a per-batch prefix (bknc/bksc), unique across proof-bk a/b/c; proof-common.sh keys its tmp dir by batch. scored with bk-score-2026-10-24.py.
# no goal, stock task: random heading, the score reads ball distance only
TASK=Mjlab-BallKick-Flat-Backlash-MicroDuck; OUT=/home/witcheer/Pollen/clips/proof-bk-c-${PROOF_TAG:-2026-10-24}
. /home/witcheer/Pollen/proof-common.sh
Z=${BK_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigkick/*_duckbigkick/model_16000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_BK_CHECKPOINT (09z10 model_16000 missing: item cut or not run)"; exit 2; }
R=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckkickbl/2026-09-28_14-10-20_duckkickbl/model_13000.pt
[ -f "$R" ] || { echo "NO_SEED_CHECKPOINT $R"; exit 2; }
echo "bk ckpt: $Z  seed (bksc, kickbl model_13000): $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 6 --log-every 5 --spawn standing --no-push --cam-world 0.8,0,0.12 --cam-distance 1.75 --cam-elevation -18 --cam-azimuth 65"
for i in $(seq 1 ${PROOF_N:-10}); do for q in bknc:$Z bksc:$R; do
  play ${q%%:*}-t$i $TASK ${q#*:} 300 $C; done; done
echo "=== $(date -u +%T) PROOF_BK_C_END ==="
