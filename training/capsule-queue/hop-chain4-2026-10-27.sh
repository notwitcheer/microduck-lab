#!/bin/bash
# hop-chain4-2026-10-27.sh: after lever 2 showed hops: (a) VIDEO takes of the L2 +100 / +200 checkpoints (is it a real hop?), (b) lever variants L3 (impact tax 0.1) and L4 (std 0.4), (c) export probe on the L2 +200 checkpoint. one slot, own flag ~/hop4-BUSY taken atomically if no other flag exists.
export PATH=$HOME/.local/bin:$PATH MUJOCO_GL=egl
P=~/Pollen; RL=$P/microduck_rl
while true; do
  b=$(ls ~/*-BUSY 2>/dev/null | grep -v "/hop4-BUSY$"); f=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader | head -n1)
  if [ -z "$b" ] && [ -z "$f" ]; then echo "hop4 $$ $(date -u +%FT%TZ)" > ~/hop4-BUSY; sleep 20; b=$(ls ~/*-BUSY 2>/dev/null | grep -v "/hop4-BUSY$"); [ -z "$b" ] && break; fi
  sleep 20
done
trap "rm -f ~/hop4-BUSY" EXIT
echo "chain4 start $(date -u +%T)"
run=$(ls -d $RL/logs/rsl_rl/probe-hop-L2/*_probe-hop-L2/ | tail -n 1)
for N in 100 200; do HOP_VIDEO=1 bash $P/hop-takes-2026-10-27.sh hop-video-L2-$N L2v$N $run/model_$((7000+N)).pt 2; done
S=L3 W=12,6,6,0.1 bash $P/hop-lever2-2026-10-27.sh
S=L4 W=12,6,6,0.02 STD=0.4 bash $P/hop-lever2-2026-10-27.sh
cd $RL; ck=$run/model_7200.pt
timeout 600 uv run scripts/export.py Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck --checkpoint-file $ck --onnx-file /tmp/probe-hop.onnx > $P/hop-export-probe.log 2>&1; echo "export rc=$? size=$(stat -c %s /tmp/probe-hop.onnx 2>/dev/null)"
echo "chain4 end $(date -u +%T)"
