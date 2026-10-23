#!/bin/bash
# publish-2026-10-02.sh: standup v2 (backlash twin, same repo, tag v2) + walk-recover-rough v1 (new repo, VelStand-Rough on the ladder).
# MODE=dry (default) writes publish-<name>/ locally and uploads nothing. MODE=real needs the operator's yes on
# 60-robotics/microduck/content/2026-10-02-hf-publish-standup-v2-walk-recover-rough.md (one yes = one real run).
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
MODE=${MODE:-dry}
P=/home/witcheer/Pollen/policies-ours
run() { local name=$1 flag=$2; shift 2; echo "=== $name ($MODE) $(date +%T)"; timeout 600 uv run publish --repo witcheer/microduck-$name "$@" $flag 2>&1 | grep -v "Processing Files\|New Data Upload\|kB /" ; echo "rc=${PIPESTATUS[0]}"; }
f2="--dry-run"; fn="--dry-run"
[ "$MODE" = "real" ] && f2="--no-dry-run --force --tag v2" && fn="--no-dry-run --no-private --tag v1"

run standup "$f2" --onnx $P/subl-2026-10-02-it28000.onnx --kind episodic --duration-s 6.0 --entry-pose "on the ground (sitting or face down)" \
  --description "v2: the v1 get-up policy fine-tuned with +-1 deg of gear play in every servo (Mjlab-StandUp-Flat-Backlash-MicroDuck), simulation only: v1's 25,000 iterations plus 3,000 with the slop, 4096 envs, 63 min on one RTX 5090. With the slop it stood from face down (3 of 3, still leaning forward about 35 deg) and from sitting (3 of 3) and held a standing start (3 of 3), the same as v1 in the same sim; from flat on its back it still freezes half-rolled (0 of 3). Not yet tested on a real Microduck."

run walk-recover-rough "$fn" --onnx $P/vsrough3-2026-10-02-it23000.onnx --kind perpetual --slot walk \
  --description "Walk-and-recover policy retrained for rough ground (Mjlab-VelStand-Rough-MicroDuck), simulation only: walk-recover v1's 20,000 iterations plus 3,000 on stairs, slopes and block grids ordered by difficulty, 4096 envs, about 3 h on one RTX 5090. On the hardest row it stayed on its feet for 20 s in 7 of 9 takes (walk-recover v1: 6 of 9), the gap is on stairs (2 of 3 vs 0 of 3, small sample); from lying on its belly or back it did not get up (0 of 9). Not yet tested on a real Microduck."
echo "=== END $(date +%T)"
