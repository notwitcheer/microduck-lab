#!/bin/bash
# publish-2026-10-15-push.sh MODE=dry|real: 09z4 (walk-flat v2 + 3,000 it under doubled training shoves) as NEW public model repo witcheer/microduck-walk-push, tag v1.
# dry run staged 2026-10-15 evening (subagent). MODE=real only after the operator's yes on content/2026-10-15-hf-publish-walk-push.md.
# verdict: NO MEASURABLE GAIN on the pre-registered condition (a); the description says so first (operator 2026-10-15: publish neutral results too).
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/velpush-2026-10-15-it10000.onnx
DESC="Walk on flat ground with +-1 deg of gear play in every servo, fine-tuned under harder shoves: walk-flat v2 plus 3,000 iterations (7,000 to 10,000) with the training shove doubled to +-0.6 m/s, still every 3-6 s (our one-change fork Mjlab-Velocity-Flat-Backlash-Push-MicroDuck), 4096 envs, 58 min on one RTX 5090. Trained in simulation only. The condition we picked in advance, doubled shoves every 0.5-1 s, showed no measurable gain: on its feet in 3 of 15 20 s takes against 0 of 15 for walk-flat v2 (one-sided Fisher p 0.11). With doubled shoves at the training interval of 3-6 s it held 14 of 15 against 5 of 15, and under the maker's own shove every 0.5-1 s 15 of 15 against 10 of 15. Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-push --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-push --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
