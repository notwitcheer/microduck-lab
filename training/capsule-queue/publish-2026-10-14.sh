#!/bin/bash
# publish-2026-10-14.sh MODE=dry|real: 09z2 (walk-flat v2 + 3,000 it on a slippery floor) as NEW public model repo witcheer/microduck-walk-slip, tag v1.
# dry run staged 2026-10-14 (cron). MODE=real only after the operator's yes on content/2026-10-14-hf-publish-walk-slip.md.
set -e
MODE=${MODE:-dry}
cd /home/witcheer/Pollen/microduck_rl
export PATH=/home/witcheer/.local/bin:$PATH
ONNX=/home/witcheer/Pollen/policies-ours/velslip-2026-10-13-it10000.onnx
DESC="Walk on flat ground with +-1 deg of gear play in every servo, fine-tuned for slippery floors: walk-flat v2 plus 3,000 iterations (7,000 to 10,000) with foot friction randomised over 0.2-1.3 instead of the maker's 0.7-1.3 (our one-change fork Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck), 4096 envs, 58 min on one RTX 5090. Trained in simulation only. In 20 s takes at foot friction 0.2 with a shove every 0.5-1 s it stayed on its feet in 8 of 15 takes against 1 of 15 for walk-flat v2; at normal friction with shoves 9 of 15 against 8 of 15, no difference. Not yet tested on a real Microduck."
if [ "$MODE" = real ]; then
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-slip --kind perpetual --slot walk --description "$DESC" --tag v1 --no-dry-run --no-private
else
  uv run publish --onnx $ONNX --repo witcheer/microduck-walk-slip --kind perpetual --slot walk --description "$DESC" --tag v1 --dry-run
fi
