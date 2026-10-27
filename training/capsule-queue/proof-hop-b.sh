#!/bin/bash
# proof-hop-b (2026-10-27, staged with 09z16): the REFERENCE = the 09z16 seed, walk-flat v2 (duckvelbl model_7000), taken in the SAME hop play env (zero command, no shoves, 6 s), 15 takes. see proof-hop-a.sh for the pre-registered rule.
# test hooks: PROOF_TAG, PROOF_N, HOP_REF (reference checkpoint override).
OUT=/home/witcheer/Pollen/clips/proof-hop-b-${PROOF_TAG:-2026-10-27}
export HOP_VIDEO=1
. /home/witcheer/Pollen/proof-hop-common.sh
R=${HOP_REF:-$(ls -1 /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/*_duckvelbl/model_7000.pt 2>/dev/null | tail -n 1)}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
echo "hop ref (href, duckvelbl model_7000): $R  env: $(env | grep ^MICRODUCK_ | tr '\n' ' ')"
C="--episode-s 6 --no-push --cam-world auto --cam-world-z 0.08 --cam-distance 0.7 --cam-elevation -5 --cam-azimuth 110"
for i in $(seq 1 ${PROOF_N:-15}); do play href-t$i Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck $R 300 $C; done
echo "=== $(date -u +%T) PROOF_HOP_B_END ==="
