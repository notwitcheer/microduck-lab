#!/bin/bash
# publish-2026-10-14-step.sh MODE=dry|real: 09z3 (walk-flat v2 + 3,000 it on a floor with single 10-25 mm steps) as NEW public model repo witcheer/microduck-walk-step, tag v1.
# dry run staged 2026-10-14 evening (subagent). MODE=real only after the operator's yes on content/2026-10-14-hf-publish-walk-step.md.
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/velstep-2026-10-14-it10000.onnx
DESC="Walk on flat ground with +-1 deg of gear play in every servo, fine-tuned for single steps: walk-flat v2 plus 3,000 iterations (7,000 to 10,000) on a floor that is flat except for one 1.5 m platform 10-25 mm high per 4 m tile (our one-change fork Mjlab-Velocity-Flat-Backlash-Step-MicroDuck), 4096 envs, 64 min on one RTX 5090. It has no terrain scan and meets the step blind. Trained in simulation only. In 20 s takes walking straight ahead over a 25 mm step with no shoves it stayed on its feet in 11 of 15 takes against at most 5 of 15 for walk-flat v2; on the same layout at 1 mm with shoves 10 of 15 against at most 7 of 15. Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-step --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-step --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
