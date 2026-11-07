#!/bin/bash
# e2e-heist-2026-11-05.sh: CPU end-to-end of the 09z28 body + 09z29 proof on a tiny clone (run name e2a, 16 envs, 3 then 6 iterations = a RESUME), no card, no Donald, no lane record, no clip render.
# cleans its own run dirs, cands, eval, check, status files at the end. lane-state cmp before/after.
set -u
P=/home/witcheer/Pollen; A=$P/arena/heist; cp ~/duck-lane-state /tmp/lane.bak-e2e-heist
export DUCK_LANE_OFF=1 HEIST_NODRAIN=1 HEIST_ENVS=16 HEIST_TRAIN_ARGS="--gpu-ids None" CUDA_VISIBLE_DEVICES= NOT_BEFORE=0
mk() { # <target>: header + runs file clones
  cat > $P/e2e-runs.sh <<R
RUNS=("e2a|microduck-challenges|1|$1|16")
HEADLINE_RUNS="e2a"
VARIANT_RUNS=""
R
  sed -e 's#^ITEM=09z28#ITEM=e2e#' -e 's#heist09z28-status#heiste2e-status#' -e 's#heist-runs-09z28.sh#e2e-runs.sh#' -e 's#^NOT_BEFORE=.*#NOT_BEFORE=0#' -e 's#^SAVE_EVERY=100#SAVE_EVERY=1#' $P/queue-staging/09z28-duck-sockheist.sh > $P/e2e-item.sh
}
echo "--- leg 1: target 3 (fresh)"; mk 3; bash -n $P/e2e-item.sh; bash $P/e2e-item.sh 2>&1 | grep -a -E "\[heiste2e\]" | cut -c1-210
echo "--- leg 2: target 6 (resume from the leg-1 run)"; mk 6; bash $P/e2e-item.sh 2>&1 | grep -a -E "\[heiste2e\]" | cut -c1-210
ls $A/microduck-challenges/logs/rsl_rl/sock_heist_6m/ | grep e2a; ls $A/microduck-challenges/logs/rsl_rl/sock_heist_6m/*_e2a/ | tr '\n' ' '; echo
echo "--- proof on the e2e run (clip skipped)"
sed -e 's#heistproof-status#heiste2eproof-status#' $P/queue-staging/09z29-duck-proof-sockheist.sh > $P/e2e-proof.sh
HEIST_RUNS=$P/e2e-runs.sh HEIST_MIN_IT=1 PROOF_TAG=e2e PROOF_NOCLIP=1 bash $P/e2e-proof.sh 2>&1 | grep -a -v '^\s*$' | cut -c1-260 | tail -n 40
cmp ~/duck-lane-state /tmp/lane.bak-e2e-heist && echo "lane state identical"
