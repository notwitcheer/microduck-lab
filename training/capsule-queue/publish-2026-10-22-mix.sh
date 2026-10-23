#!/bin/bash
# publish-2026-10-22-mix.sh MODE=dry|real: 09z6 (walk-step v1 + 3,000 it under step + slippery floor + doubled training shoves at once) as NEW public model repo witcheer/microduck-walk-mix, tag v1.
# dry run staged 2026-10-22 (subagent). MODE=real only after the operator's yes on 60-robotics/microduck/content/2026-10-22-hf-publish-walk-mix.md.
# verdict: GAIN on the pre-registered condition a (9/15 vs 0/15, one-sided Fisher p 0.0003), no loss on b/c/d. numbers re-read 2026-10-22 from z6-score-2026-10-17.py;
# the c line (walk-slip 3/15) re-read against the 09z2 takes + two diagnostic batches the same morning (7/15, 6/15): a low draw on a harder harness, not a regression.
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/velmix-2026-10-18-it13000.onnx
DESC="One walk for three conditions at once, with +-1 deg of gear play in every servo: walk-step v1 plus 3,000 iterations (10,000 to 13,000) on a floor with single 10-25 mm steps, foot friction from 0.2 to 1.3 and the training shove doubled to +-0.6 m/s every 3-6 s (our fork Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck), 4096 envs, 64 min on one RTX 5090. Trained in simulation only. With all three at once (25 mm step, friction 0.2, doubled shoves), walking straight ahead at 0.3 m/s, it stayed on its feet for 20 s in 9 of 15 takes against 0 of 15 for walk-flat v2 (one-sided Fisher p 0.0003). Against each single-condition policy on its own condition it showed no measurable loss: step 10 of 15 vs walk-step 13 of 15 (p 0.39), doubled shoves 10 of 15 vs walk-push 9 of 15, slippery floor with shoves 11 of 15 vs walk-slip 3 of 15 (a low draw: walk-slip held 6 to 8 of 15 in three other 15-take sets at that friction and shove, so read it as no loss, not a win). Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-mix --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-mix --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
