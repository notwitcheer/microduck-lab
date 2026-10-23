#!/bin/bash
# publish-2026-10-22-slope.sh MODE=dry|real: 09z5 (walk-flat v2 + 3,000 it on a floor of gentle pyramid hills) as NEW public model repo witcheer/microduck-walk-slope, tag v1.
# dry run staged 2026-10-22 (subagent). MODE=real only after the operator's yes on 60-robotics/microduck/content/2026-10-22-hf-publish-walk-slope.md.
# verdict: GAIN on the pre-registered read (a + b pooled, one-sided Fisher p 0.0041), control c no loss. numbers re-read 2026-10-22 from z5-score-2026-10-16.py.
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/velslope-2026-10-18-it10000.onnx
DESC="Walk on gentle hills with +-1 deg of gear play in every servo: walk-flat v2 plus 3,000 iterations (7,000 to 10,000) on a floor of pyramid hills, slope 0.05 to 0.15 rise per run (our one-change fork Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck), 4096 envs, about 128 min on one RTX 5090. Trained in simulation only. On a 0.15 hill, walking straight ahead at 0.3 m/s, it stayed on its feet for 20 s in 23 of 30 takes against 12 of 30 for walk-flat v2 (one-sided Fisher p 0.0041): 14 of 15 against 8 of 15 without shoves, 9 of 15 against 4 of 15 with shoves every 0.5-1 s. On the flat control both held 10 of 15. Only the 0.15 hill was tested, every take starting on a hilltop and walking off it. Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-slope --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-slope --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
