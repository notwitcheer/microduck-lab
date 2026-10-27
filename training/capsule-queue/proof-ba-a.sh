#!/bin/bash
# proof-ba-a (2026-10-26, staged with 09z12): GIANT BALL (r 0.15 m, 0.275 kg), goal at 1.4 m, duck turned to face it (face_goal), NO shoves. PRE-REGISTERED GAIN CONDITION (A): success = held (no tilt fall, no mid RESET) AND the ball centre enters the goal mouth footprint at any 0.1 s sample of the 6 s episode; new vs ref one-sided exact Fisher p < 0.05. the same takes also carry the POWER no-loss check (P): held AND ball >= 1.25 m from its start by t = 2.0 s, two-sided, a loss = p < 0.05 with new lower.
# policies: bana-tN = the 09z12 aiming giant-ball kick (duckbigaim model_19000, task Big-Aim), bkra-tN = the 09z10 giant-ball kick it was warm-started from (duckbigkick model_16000, task Big), re-taken today, NOT reused from proof-bk. both play envs are identical (the aim term is a training reward only).
# 15 takes per policy, 1 env, standing spawn, 6 s episodes, 0.1 s samples, 1280x720, camera D (fixed world camera, az 65 / 1.75 m / -18 deg, lookat 0.8,0,0.12: duck, giant ball and goal in frame).
# test hooks (e2e of the proof item only): PROOF_TAG (OUT suffix), PROOF_N (takes per policy), BA_CKPT (new-policy checkpoint override), BA_REF (reference checkpoint override); defaults are the real run.
# take names carry a per-batch prefix (bana/bkra), unique across proof-ba a/b/c; proof-common.sh keys its tmp dir by batch. scored with ba-score-2026-10-26.py.
export MICRODUCK_BIGKICK_GOAL=1
OUT=/home/witcheer/Pollen/clips/proof-ba-a-${PROOF_TAG:-2026-10-26}
. /home/witcheer/Pollen/proof-common.sh
Z=${BA_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigaim/*_duckbigaim/model_19000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_BA_CHECKPOINT (09z12 model_19000 missing: item cut or not run)"; exit 2; }
R=${BA_REF:-/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckbigkick/2026-10-25_08-12-58_duckbigkick/model_16000.pt}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
echo "ba ckpt: $Z  ref (bkra, duckbigkick model_16000): $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 6 --log-every 5 --spawn standing --no-push --cam-world 0.8,0,0.12 --cam-distance 1.75 --cam-elevation -18 --cam-azimuth 65"
for i in $(seq 1 ${PROOF_N:-15}); do
  play bana-t$i Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck $Z 300 $C
  play bkra-t$i Mjlab-BallKick-Flat-Backlash-Big-MicroDuck $R 300 $C
done
echo "=== $(date -u +%T) PROOF_BA_A_END ==="
