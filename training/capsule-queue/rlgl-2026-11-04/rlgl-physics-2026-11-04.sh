#!/bin/bash
# rlgl-physics-2026-11-04.sh <out dir>: the physics of the red light, green light field, sharded over CPU cores (no card, nice 19).
#   RLGL_N (456) ducks, RLGL_SHARDS (8) parallel processes of N/SHARDS envs, RLGL_CYCLES (4) lights, RLGL_SEED (11), RLGL_SHARD_TIMEOUT (1700 s, the item passes up to 2400).
#   duck i's reaction delay and walking speed come from ONE generator over the whole field, so a shard is a slice and the numbers do not depend on RLGL_SHARDS.
#   finished shards (sh<k>.npz + a '[rlgl] done' line) are kept on a rerun; frozen params (pre-registered in 09z25-duck-rlgl.sh): grace 0.9 s, thr 0.06 m/s, react median 0.2 s, red 2 s / green 3 s.
set -uo pipefail
OUT=$(readlink -f "$1"); mkdir -p "$OUT"
N=${RLGL_N:-456}; S=${RLGL_SHARDS:-8}; C=${RLGL_CYCLES:-4}; SEED=${RLGL_SEED:-11}; TO=${RLGL_SHARD_TIMEOUT:-1700}
P=/home/witcheer/Pollen
CK=${RLGL_CKPT:-$P/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt}
per=$((N / S))
cd $P/microduck_rl || exit 2
for s in $(seq 0 $((S - 1))); do
  if grep -q '^\[rlgl\] done' $OUT/sh$s.log 2>/dev/null && [ -s $OUT/sh$s.npz ]; then echo "shard $s already done, kept"; continue; fi
  [ -f $OUT/sh$s.log ] && mv $OUT/sh$s.log $OUT/sh$s.log.partial-$(date +%s)
  MO=""; [ "$s" = 0 ] && MO="--model-out $OUT/duck.mjb"
  ( CUDA_VISIBLE_DEVICES= MUJOCO_GL=egl nice -n 19 timeout --kill-after=30 $TO .venv/bin/python swarm_rlgl2.py Mjlab-Velocity-Flat-Backlash-MicroDuck \
      --checkpoint-file "$CK" --device cpu --num-envs $per --total-envs $N --shard $s --shards $S --spacing 0.55 --grace 0.9 --thr 0.06 --react-med 0.2 \
      --cycles $C --seed $SEED --traj $OUT/sh$s.npz $MO > $OUT/sh$s.log 2>&1 < /dev/null
    echo "SHARD_END $s rc=$?" >> $OUT/sh$s.log ) &
done
wait
echo "PHYSICS_END shards=$S done=$(grep -l '^\[rlgl\] done' $OUT/sh*.log 2>/dev/null | wc -l)"
