#!/bin/bash
# hop2-chain-2026-10-29.sh: the three short hop2 warm-start sweeps in ONE shared-card slot (run under hop2-wrap): A = v2 rewards, penalty only (std 0.6); B = A + termination on a non-sole floor contact (train env only); C = A with std 0.4 (L4-like exploration).
# 300 it each (~7 min of card time each at 1.3 s/it), CPU takes after each. total card time well under the 90 min budget.
for spec in "A 0.6 0" "B 0.6 1" "C 0.4 0"; do
  set -- $spec
  S=$1 STD=$2 H2TERM=$3 bash /home/witcheer/Pollen/hop2-dev/hop2-sweep-2026-10-29.sh
  echo "sweep $1 rc=$?"
done
echo "CHAIN_END $(date -u +%T)"
