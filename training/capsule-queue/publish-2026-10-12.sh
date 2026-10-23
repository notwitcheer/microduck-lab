#!/bin/bash
# publish-2026-10-12.sh MODE=dry|real: level 11c (09w) as NEW public model repo witcheer/microduck-walk-getup, tag v1.
# runs from the soft_carpet worktree so the manifest's training block names the branch the policy trained on (695f3b7).
# operator yes: GPU thread 2026-10-12 ~08:45 CEST "for the two decisions, I am following your leads on both. go".
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl-carpet
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/carpetbl-2026-10-07-it9000.onnx
DESC="Walk, and get back up after a fall, with +-1 deg of gear play in every servo (Mjlab-VelStand-Flat-Backlash-MicroDuck on Pollen's soft_carpet branch). Trained in simulation only with Pollen's own recipe from that branch: behaviour cloning from their alpha_stand get-up expert on fallen frames plus a walk anchor on upright frames, 3,000 iterations on top of our 6,000-iteration run, 4096 envs, 83 min on one RTX 5090. In 7 forced-spawn takes of 12 s with a shove every 1-2 s it went down 35 times and got back up 31 times. Deep (10 mm) soft carpet with the motor model still knocks it down. Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-getup --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-getup --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
