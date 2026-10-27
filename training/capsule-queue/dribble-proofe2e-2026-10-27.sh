#!/bin/bash
# dribble-proofe2e-2026-10-27.sh: e2e of the PROOF item 09z15 with test hooks (n=1 per batch, tag e2e, the e2e clone's checkpoint as the "new" policy, the walk-stairs seed as the reference): the four batch scripts, scorer, picker and the clip cut run;
# the VERDICT line is meaningless at n=1. run through dribble-wrap-2026-10-27.sh 0 dribble <this> (1-env takes, no drain). artefacts: clips/proof-dr-*-e2e, proof-dr-score-e2e.txt, clip-dribble-cut-e2e.log, clips/x-dribble-e2e.
exec >> /home/witcheer/Pollen/dribble-proofe2e-2026-10-27.log 2>&1
set -uo pipefail
P=/home/witcheer/Pollen; RL=$P/microduck_rl
SEED=$RL/logs/rsl_rl/duckdribble/2026-10-27_00-00-00_seed-velstairs-it19000/model_19000.pt
E2EDIR=$(ls -d $RL/logs/rsl_rl/duckdribblee2e/*_duckdribblee2e | tail -n 1); N=$(ls $E2EDIR/model_*.pt | sed 's/.*model_//; s/.pt//' | sort -n | tail -n 1)
mkdir -p $P/e2e-2026-10-27-dribble-item
for x in $P/proof-dr-?*.out $P/clips/proof-dr-?-e2e $P/clips/proof-dr-?-e2e.log $P/clips/x-dribble-e2e $P/proof-dr-score-e2e.txt; do [ -e "$x" ] && mv "$x" $P/e2e-2026-10-27-dribble-item/aside-$(basename $x)-$(date +%s); done
export PROOF_TAG=e2e PROOF_N=1 DR_CKPT=$E2EDIR/model_$N.pt DR_REF=$SEED PROOF_ONNX_GLOB='dribblee2e-*.onnx'
echo "=== $(date -u +%T) e2e of the proof item 09z15 (hooks, n=1), ckpt $DR_CKPT"
bash $P/queue-staging/09z15-duck-proof-dribble.sh; echo "09z15 e2e rc=$?"
echo "=== $(date -u +%T) PROOFE2E_END"
