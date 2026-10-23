#!/bin/bash
# publish-2026-10-11.sh: walk-rough v2 = 09y velroughbl it11000 (gear-play twin of walk-rough v1 on the ordered terrain ladder),
# same repo, --force --tag v2 (v1 tag untouched, @v1 stays installable).
# MODE=dry (default) writes publish-walk-rough/ locally and uploads nothing (v1 folder backed up first).
# MODE=real: operator approval recorded in 60-robotics/microduck/content/2026-10-11-hf-publish-walk-rough-v2.md
# (GPU thread 2026-10-11 "push on HF and GH our reports").
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
MODE=${MODE:-dry}
P=/home/witcheer/Pollen/policies-ours
[ -d publish-walk-rough ] && [ ! -d publish-walk-rough.v1-bak-2026-10-11 ] && cp -r publish-walk-rough publish-walk-rough.v1-bak-2026-10-11
f="--dry-run"; [ "$MODE" = "real" ] && f="--no-dry-run --force --tag v2"
echo "=== walk-rough v2 ($MODE) $(date +%T)"
timeout 580 uv run publish --repo witcheer/microduck-walk-rough --onnx $P/velroughbl-2026-10-09-it11000.onnx --kind perpetual --slot walk \
  --description "v2: walk-rough v1 fine-tuned with +-1 deg of gear play in every servo, on stairs, slopes and block grids ordered from easy to hard (Mjlab-Velocity-Rough-Backlash-MicroDuck), simulation only: v1's 8,000 iterations plus 3,000, 4096 envs, 147 min on one RTX 5090. With the gear play on, on the hardest terrain row it stayed on its feet for 20 s in 8 of 9 takes; v1 in the same sim did 4 of 9 (small sample). Not yet tested on a real Microduck." \
  $f 2>&1 | grep -v "Processing Files\|New Data Upload\|kB /"
echo "rc=${PIPESTATUS[0]}"
echo "=== END $(date +%T)"
