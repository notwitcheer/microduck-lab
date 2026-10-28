#!/bin/bash
# gm-takes-2026-10-28.sh: N 1-env CPU takes (no video) of one checkpoint in the gale or moon PLAY env, gm_play.py --gm-log, for the seed-through-the-condition probes and the CPU smoke.
# usage: bash gm-takes-2026-10-28.sh <out dir under ~/Pollen/gm-probe> <prefix> <checkpoint .pt> <task id> <episode s> <cmd vx> [N takes, default 6] [parallel, default 6]
# env knobs pass straight through (MICRODUCK_GALE_PEAK, MICRODUCK_GALE_RAMP, MICRODUCK_MOON_G, MICRODUCK_GALE_OFF ...). CPU only (CUDA_VISIBLE_DEVICES empty), nice 19, uses ~/Pollen/gm-dev unless GM_DEV=0.
OUT=$HOME/Pollen/gm-probe/${1:?out}; PFX=${2:?prefix}; CK=${3:?ckpt}; TASK=${4:?task}; EP=${5:?episode s}; VX=${6:?vx}; N=${7:-6}; PAR=${8:-6}
mkdir -p "$OUT"; cd $HOME/Pollen/microduck_rl || exit 2
export PATH=$HOME/.local/bin:$PATH MUJOCO_GL=egl CUDA_VISIBLE_DEVICES=""
GP=$HOME/Pollen/gm-dev/gm_play.py; [ "${GM_DEV:-1}" = 0 ] && GP=$HOME/Pollen/microduck_rl/gm_play.py
[ "${GM_DEV:-1}" = 1 ] && export PYTHONPATH=$HOME/Pollen/gm-dev/src
STEPS=$(python3 -c "print(int(round($EP/0.02))+5)")
one() { local i=$1; nice -n 19 timeout 600 .venv/bin/python $GP $TASK --checkpoint-file $CK --num-envs 1 --video False --steps $STEPS --episode-s $EP --no-push --cmd-vx $VX --gm-log --device cpu > $OUT/$PFX-t$i.full.log 2>&1; grep -a "\[gm\]\|RESET\|Error\|Traceback" $OUT/$PFX-t$i.full.log > $OUT/$PFX-t$i.log; }
i=1; while [ $i -le $N ]; do
  for j in $(seq 1 $PAR); do [ $i -le $N ] && { one $i & i=$((i+1)); }; done; wait
done
echo "=== $(date -u +%T) TAKES_END $PFX n=$N ==="
