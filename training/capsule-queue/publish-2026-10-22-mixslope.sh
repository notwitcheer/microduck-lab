#!/bin/bash
# publish-2026-10-22-mixslope.sh MODE=dry|real: 09z7 (walk-mix v1 + 3,000 it with the 09z5 hill tiles added to the mix floor) as NEW public model repo witcheer/microduck-walk-mixslope, tag v1.
# dry run staged 2026-10-22 evening (mercury cron). MODE=real only after the operator's yes on 60-robotics/microduck/content/2026-10-22-hf-publish-walk-mixslope.md.
# verdict: NO GAIN on the pre-registered condition a (5/15 vs walk-mix 3/15, one-sided Fisher p 0.34); no loss on b (15/15 vs walk-slope 15/15) or c (7/15 vs walk-mix 5/15, p 0.71).
# a new repo, not walk-mix v2: the refinement rule (better only if it wins its target condition) keeps walk-mix v1 as the default mixed-floor walk.
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/velmixslope-2026-10-22-it16000.onnx
DESC="walk-mix with hills added, with +-1 deg of gear play in every servo: walk-mix v1 plus 3,000 iterations (13,000 to 16,000) on a floor where each 4 m tile is either a single 10-25 mm step or a pyramid hill of slope 0.05-0.15, foot friction from 0.2 to 1.3 and the training shove doubled to +-0.6 m/s every 3-6 s (our fork Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck), 4096 envs, 120 min on one RTX 5090. Trained in simulation only. Result: no measurable gain over walk-mix. On the test picked before training (0.15 hill + 25 mm step + friction 0.2 + doubled shoves, walking straight ahead at 0.3 m/s) it stayed on its feet for 20 s in 5 of 15 takes against 3 of 15 for walk-mix (one-sided Fisher p 0.34). No loss elsewhere: 0.15 hill without shoves 15 of 15, same as walk-slope; walk-mix's own mixed floor 7 of 15 vs walk-mix 5 of 15 (p 0.71). Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-mixslope --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-mixslope --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
