#!/bin/bash
# proof-ba-b (2026-10-26, staged with 09z12): GIANT BALL, goal at 1.4 m, face_goal, WITH the maker's play shoves (0.5-1.0 s interval, +-0.3 m/s). secondary condition (B), reported, not part of the verdict line (play shoves are 3-6x harsher than the training interval).
# policies: banb-tN = duckbigaim model_19000 (Big-Aim), bkrb-tN = duckbigkick model_16000 (Big). 10 takes per policy, 1 env, standing spawn, 6 s episodes, 0.1 s samples, 1280x720, camera D.
# test hooks (e2e of the proof item only): PROOF_TAG (OUT suffix), PROOF_N (takes per policy), BA_CKPT (new-policy checkpoint override), BA_REF (reference checkpoint override); defaults are the real run.
# take names carry a per-batch prefix (banb/bkrb), unique across proof-ba a/b/c; proof-common.sh keys its tmp dir by batch. scored with ba-score-2026-10-26.py.
export MICRODUCK_BIGKICK_GOAL=1
OUT=/home/witcheer/Pollen/clips/proof-ba-b-${PROOF_TAG:-2026-10-26}
. /home/witcheer/Pollen/proof-common.sh
Z=${BA_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigaim/*_duckbigaim/model_19000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_BA_CHECKPOINT (09z12 model_19000 missing: item cut or not run)"; exit 2; }
R=${BA_REF:-/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigkick/2026-10-25_08-12-58_duckbigkick/model_16000.pt}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
echo "ba ckpt: $Z  ref (bkrb, duckbigkick model_16000): $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 6 --log-every 5 --spawn standing --cam-world 0.8,0,0.12 --cam-distance 1.75 --cam-elevation -18 --cam-azimuth 65"
for i in $(seq 1 ${PROOF_N:-10}); do
  play banb-t$i Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck $Z 300 $C
  play bkrb-t$i Mjlab-BallKick-Flat-Backlash-Big-MicroDuck $R 300 $C
done
echo "=== $(date -u +%T) PROOF_BA_B_END ==="
