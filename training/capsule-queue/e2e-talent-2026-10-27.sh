#!/bin/bash
# e2e clone of 09zt3-duck-talent.sh on a shared card: 512 envs, two legs (leg 2 resumes leg 1's checkpoint with a larger target), judge on 2 checkpoints.
# waits for sibling *-BUSY flags (reservation talent-wait-BUSY, claim talent-BUSY before the settle), DUCK_LANE_OFF=1, lane state cmp.
exec > >(tee -a ~/Pollen/arena-talent/e2e.log) 2>&1
export PATH=~/.local/bin:$PATH
AT=~/Pollen/arena-talent
trap 'rm -f ~/talent-BUSY ~/talent-wait-BUSY' EXIT
touch ~/talent-wait-BUSY
DEADLINE=$(date -u -d '2026-10-27 22:30:00' +%s)   # never hold the card into the 01:10 CET block (a GPU-owning tmux session makes the runner SKIP the whole block)
while true; do
  [ "$(date +%s)" -gt "$DEADLINE" ] && { echo "$(date -u +%T) gave up waiting for the card (deadline 22:30 UTC); e2e NOT run"; exit 4; }
  foreign=$(ls ~/*-BUSY 2>/dev/null | grep -v -E 'talent(-wait)?-BUSY' | tr '\n' ' ')
  tm=$(tmux ls 2>/dev/null | grep -E '^(vx-|flint|prz|hm|idleq)' | tr '\n' ' ')
  gpu=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
  if [ -z "$foreign" ] && [ -z "$tm" ] && [ "${gpu:-99999}" -lt 2500 ]; then
    touch ~/talent-BUSY; sleep 90
    foreign=$(ls ~/*-BUSY 2>/dev/null | grep -v -E 'talent(-wait)?-BUSY' | tr '\n' ' '); gpu=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
    [ -z "$foreign" ] && [ "${gpu:-99999}" -lt 2500 ] && break
    rm -f ~/talent-BUSY; echo "$(date -u +%T) lost the slot to: $foreign gpu=$gpu"
  fi
  echo "$(date -u +%T) waiting: foreign=[$foreign] tmux=[$tm] gpu=${gpu}MiB"; sleep 60
done
rm -f ~/talent-wait-BUSY
echo "$(date -u +%T) slot claimed"
cp ~/duck-lane-state ~/duck-lane-state.bak-e2e-09zt3-2026-10-27
export DUCK_LANE_OFF=1
mkdir -p $AT/acts-e2e; cp $AT/acts/*.json $AT/acts-e2e/ 2>/dev/null
sed -e 's#^NL_TAG=ducktalent#NL_TAG=ducktalente2e#' -e 's#/home/witcheer/ducktalent-status.json#/home/witcheer/ducktalente2e-status.json#' \
    -e "s#\$AT/acts/\*.json#\$AT/acts-e2e/*.json#" ~/idle-queue-staging/09zt3-duck-talent.sh > $AT/e2e-09zt3.sh 2>/dev/null || sed -e 's#^NL_TAG=ducktalent#NL_TAG=ducktalente2e#' -e 's#/home/witcheer/ducktalent-status.json#/home/witcheer/ducktalente2e-status.json#' -e "s#\$AT/acts/\*.json#\$AT/acts-e2e/*.json#" ~/Pollen/queue-staging/09zt3-duck-talent.sh > $AT/e2e-09zt3.sh
grep -n "e2e" $AT/e2e-09zt3.sh | head -n 5
rm -rf ~/ducktalente2e-status.json $AT/pick-e2e1.json $AT/pick-e2e2.json
common="TALENT_RUN_NAME=e2etalent ENVS=512 SAVE_EVERY=10 TALENT_JUDGE_MIN=20 TALENT_PICK_MIN=20"
export NL_HARD_STOP_EPOCH=$(( $(date +%s) + 3000 ))
echo "=== leg 1: target 40 ==="; env $common TARGET_IT=40 TALENT_JUDGE_TAG=e2e1 bash $AT/e2e-09zt3.sh; echo "leg1 rc=$?"
echo "=== leg 2: resume to 60 ==="; env $common TARGET_IT=60 TALENT_JUDGE_TAG=e2e2 bash $AT/e2e-09zt3.sh; echo "leg2 rc=$?"
cmp ~/duck-lane-state ~/duck-lane-state.bak-e2e-09zt3-2026-10-27 && echo "lane state unchanged"
ls $AT/pick-e2e*.json; cat $AT/pick-e2e2.json | head -n 12
echo E2E_DONE
