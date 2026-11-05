#!/bin/bash
# proof-hop2-b (2026-10-29, staged with 09z22): the REFERENCE = the hop2 seed, walk-flat v2 (duckvelbl model_7000), 15 takes in the SAME hop2 play env (strict logger, video). see proof-hop2-a.sh for the pre-registered rule.
# test hooks: PROOF_TAG, PROOF_N, HOP2_REF (reference checkpoint override).
P=/home/witcheer/Pollen; TAG=${PROOF_TAG:-2026-10-29}; TASK=Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck
R=${HOP2_REF:-$(ls -1 $P/microduck_rl/logs/rsl_rl/duckvelbl/*_duckvelbl/model_7000.pt 2>/dev/null | tail -n 1)}
[ -f "$R" ] || { echo "NO_REF_CHECKPOINT $R"; exit 2; }
echo "hop2 ref (href, duckvelbl model_7000): $R"
STRICT_VIDEO=1 OUTBASE=$P/clips bash $P/strict-takes-2026-10-29.sh proof-hop2-b-$TAG href $R ${PROOF_N:-15} 3 $TASK
echo "=== $(date -u +%T) PROOF_HOP2_B_END ==="
