#!/bin/bash
# proof-hop-a (2026-10-27, staged with 09z16): the NEW policy, duckhop model_10000 (task Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck), 15 takes. PRE-REGISTERED GAIN CONDITION (A), scorer hop-score-2026-10-27.py:
# success per take = at least 3 hops (both feet out of contact for >= 4 steps = 80 ms, tilt < 35 deg throughout, lower sole >= 12 mm above its standing height) AND upright in the last 0.5 s (tilt < 30, trunk > 70 mm, no RESET before 5.9 s).
# new vs ref (batch b, the seed taken in the same env) one-sided exact Fisher p < 0.05 = GAIN. 1 env, zero command, no shoves, 6 s, per-step [hop] log, video on (fixed world camera, cam-world auto, 0.7 m, az 110).
# test hooks (e2e of the proof item only): PROOF_TAG (OUT suffix), PROOF_N (takes), HOP_CKPT (new-policy checkpoint override); defaults are the real run.
OUT=/home/witcheer/Pollen/clips/proof-hop-a-${PROOF_TAG:-2026-10-27}
export HOP_VIDEO=1
. /home/witcheer/Pollen/proof-hop-common.sh
Z=${HOP_CKPT:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckhop/*_duckhop/model_10000.pt 2>/dev/null | tail -n 1)}
[ -n "$Z" ] || { echo "NO_HOP_CHECKPOINT (09z16 model_10000 missing: item cut or not run)"; exit 2; }
echo "hop ckpt: $Z  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 6 --no-push --cam-world auto --cam-world-z 0.08 --cam-distance 0.7 --cam-elevation -5 --cam-azimuth 110"
for i in $(seq 1 ${PROOF_N:-15}); do play hnew-t$i Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck $Z 300 $C; done
echo "=== $(date -u +%T) PROOF_HOP_A_END ==="
