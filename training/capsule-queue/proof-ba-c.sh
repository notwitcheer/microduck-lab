#!/bin/bash
# proof-ba-c (2026-10-26, staged with 09z12): SMALL BALL (the stock backlash kick task, 70 mm / 15 g), random heading, NO shoves. NO-LOSS CONDITION (C): success = held AND the ball >= 1.0 m from its start by 3 s; two-sided exact Fisher, a loss = p < 0.05 with the new policy lower.
# policies: banc-tN = duckbigaim model_19000, bkrc-tN = duckbigkick model_16000 (both on the stock task). 10 takes per policy, 1 env, standing spawn, 6 s episodes, 0.1 s samples, 1280x720, camera D. no goal: the score reads ball distance only.
# test hooks (e2e of the proof item only): PROOF_TAG (OUT suffix), PROOF_N (takes per policy), BA_CKPT (new-policy checkpoint override), BA_REF (reference checkpoint override); defaults are the real run.
# take names carry a per-batch prefix (banc/bkrc), unique across proof-ba a/b/c; proof-common.sh keys its tmp dir by batch. scored with ba-score-2026-10-26.py.
OUT=/home/witcheer/Pollen/clips/proof-ba-c-${PROOF_TAG:-2026-10-26}
. /home/witcheer/Pollen/proof-common.sh
Z=${BA_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigaim/*_duckbigaim/model_19000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_BA_CHECKPOINT (09z12 model_19000 missing: item cut or not run)"; exit 2; }
R=${BA_REF:-/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigkick/2026-10-25_08-12-58_duckbigkick/model_16000.pt}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
echo "ba ckpt: $Z  ref (bkrc, duckbigkick model_16000): $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 6 --log-every 5 --spawn standing --no-push --cam-world 0.8,0,0.12 --cam-distance 1.75 --cam-elevation -18 --cam-azimuth 65"
for i in $(seq 1 ${PROOF_N:-10}); do
  play banc-t$i Mjlab-BallKick-Flat-Backlash-MicroDuck $Z 300 $C
  play bkrc-t$i Mjlab-BallKick-Flat-Backlash-MicroDuck $R 300 $C
done
echo "=== $(date -u +%T) PROOF_BA_C_END ==="
