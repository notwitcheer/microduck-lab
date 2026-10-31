#!/bin/bash
# talent pace probe: 4096 envs, 30 it of Mjlab-GotATalent-MicroDuck on the free card, then a dry-run export.
exec > >(tee -a ~/Pollen/arena-talent/probe-pace.log) 2>&1
export PATH=~/.local/bin:$PATH
cd ~/Pollen/arena-talent/microduck-challenges
for i in $(seq 1 60); do
  if ls ~/*-BUSY >/dev/null 2>&1 && ! ls ~/talent-BUSY >/dev/null 2>&1; then echo "$(date -u +%T) sibling BUSY flag present: $(ls ~/*-BUSY | tr '\n' ' ')"; sleep 10; else break; fi
done
touch ~/talent-BUSY
trap 'rm -f ~/talent-BUSY' EXIT
echo "$(date -u +%T) gpu: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
rm -rf logs/rsl_rl/got_a_talent/*_probe
( while true; do nvidia-smi --query-gpu=memory.used --format=csv,noheader >> ~/Pollen/arena-talent/probe-vram.log; sleep 3; done ) &
SAMP=$!
S=$(date +%s)
uv run train Mjlab-GotATalent-MicroDuck --env.scene.num-envs 4096 --agent.max-iterations 30 --agent.save-interval 10 --agent.seed 1 --agent.logger tensorboard --agent.run-name probe > ~/Pollen/arena-talent/probe-train.log 2>&1
echo "$(date -u +%T) train rc=$? wall=$(( $(date +%s) - S )) s"
kill $SAMP
sort -n ~/Pollen/arena-talent/probe-vram.log | tail -n 1 | sed 's/^/peak vram: /'
grep -o "Learning iteration [0-9]*/[0-9]*" ~/Pollen/arena-talent/probe-train.log | tail -n 1
grep -iE "iteration time|Time elapsed|Computation:" ~/Pollen/arena-talent/probe-train.log | tail -n 4
ls logs/rsl_rl/got_a_talent/*_probe/
echo PROBE_DONE
