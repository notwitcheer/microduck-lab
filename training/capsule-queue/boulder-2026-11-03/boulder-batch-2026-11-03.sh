#!/bin/bash
# boulder-batch-2026-11-03.sh <A|B|C> <seed> <out dir>: one batch of CPU takes of the boulder chase (no card, no queue).
#   A = no reflex (the 'before'), B = the Hermes-written reflex (BOULDER_REFLEX), C = no-boulder control (Z_STAND check).
# writes <out dir>/A-s<seed>.log, B-s<seed>.log or C.log. env hooks (e2e only): BOULDER_ENVS (16), BOULDER_DUR (14), BOULDER_CKPT, BOULDER_REFLEX.
set -uo pipefail
K=$1; SEED=$2; OUT=$3
P=/home/witcheer/Pollen
CK=${BOULDER_CKPT:-$P/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt}
RF=${BOULDER_REFLEX:-$P/boulder-item/reflex_hermes.py}
mkdir -p "$OUT"
case $K in
  A) EXTRA="--reflex 0"; LOG="$OUT/A-s$SEED.log";;
  B) EXTRA="--reflex-file $RF"; LOG="$OUT/B-s$SEED.log";;
  C) EXTRA="--control 1 --reflex 0"; LOG="$OUT/C.log";;
  *) echo "bad kind $K"; exit 2;;
esac
cd $P/microduck_rl || exit 2
CUDA_VISIBLE_DEVICES= MUJOCO_GL=egl nice -n 19 .venv/bin/python boulder_play.py Mjlab-Velocity-Flat-Backlash-MicroDuck \
  --checkpoint-file "$CK" --num-envs ${BOULDER_ENVS:-16} --device cpu --dur ${BOULDER_DUR:-14} --cmd-vx 0.4 --v0 0.3 --acc 0.1 $EXTRA --seed "$SEED" > "$LOG" 2>&1
echo "BATCH_END $K $SEED rc=$?" >> "$LOG"
