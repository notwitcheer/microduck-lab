#!/bin/bash
# publish-v2-backlash.sh (2026-09-26): v2 of walk-flat and walk-recover = the +-1 deg gear-play (backlash) twins.
# same repos as v1; robotctl takes `org/name@v1` to pin the old one (robotctl/src/main.rs:960-961), so v1 stays installable.
# MODE=dry (default) writes publish-<name>/ locally and uploads nothing. MODE=real = --force (replace policy.onnx on main) + tag v2.
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
MODE=${MODE:-dry}
P=/home/witcheer/Pollen/policies-ours
flag="--dry-run"; [ "$MODE" = "real" ] && flag="--no-dry-run --force --tag v2"
pub() { local name=$1; shift; echo "=== $name ($MODE) $(date +%T)"; timeout 600 uv run publish --repo witcheer/microduck-$name "$@" $flag 2>&1 | grep -v "Processing Files\|New Data Upload\|kB /" ; echo "rc=${PIPESTATUS[0]}"; }

pub walk-flat --onnx $P/velbl-2026-09-25-it7000.onnx --kind perpetual --slot walk \
  --description "v2: the v1 flat-ground walk fine-tuned with +-1 deg of gear play in every servo (Mjlab-Velocity-Flat-Backlash-MicroDuck), simulation only: v1's 4,000 iterations plus 3,000 with the slop, 4096 envs, 57 min on one RTX 5090. With the slop it stayed on its feet for 20 s in 4 of 5 takes; v1 did 2 of 5 in the same sim (small sample, the training fall rate did not improve). Not yet tested on a real Microduck."

pub walk-recover --onnx $P/vsbl-2026-09-26-it23000.onnx --kind perpetual --slot walk \
  --description "v2: the v1 walk-and-recover policy fine-tuned with +-1 deg of gear play in every servo (Mjlab-VelStand-Flat-Backlash-MicroDuck), simulation only: v1's 20,000 iterations plus 3,000 with the slop, 4096 envs, 62 min on one RTX 5090. With the slop it stayed on its feet for 20 s in 6 of 7 standing takes (v1: 6 of 7); from lying on its belly or back it did not get up (0 of 3 each). Not yet tested on a real Microduck."

echo "=== END $(date +%T)"
