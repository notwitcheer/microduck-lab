#!/bin/bash
# wduck-z7-verdicts.sh: one-shot 09z7 verdict launcher (nogpu watcher, tmux "wduckz7"). waits for
# ~/Pollen/policies-ours/velmixslope-*-it16000.onnx, then launches proof-z7-{a,b,c} in detached tmux prz7-a/b/c (1-env takes, ~4 GB
# each, share the card with a bench leg harmlessly) and scores them with z7-score-2026-10-22.py once all three END markers land
# (score -> ~/Pollen/proof-z7-score.txt). gives up mon 2026-10-26 06:10 local.
# LIVENESS (09z5/09z6 watcher wduckv died silently 2026-10-18): heartbeat line in the log every 30 min ("alive ...") and
# ~/Pollen/wduck-z7.alive touched every loop; a status turn or the verdict cron reads `tmux has-session -t =wduckz7` + the alive
# file age (> 10 min stale = dead watcher: relaunch the staged proof-z7 batches by hand if the onnx exists).
# log ~/Pollen/wduck-z7-verdicts.log
exec >> /home/witcheer/Pollen/wduck-z7-verdicts.log 2>&1
cd /home/witcheer/Pollen
STOP=$(date -d '2026-10-26 06:10' +%s); hb=0; launched=0
echo "$(date -u +%FT%TZ) watcher start (pid $$)"
while [ "$(date +%s)" -lt "$STOP" ]; do
  now=$(date +%s); touch /home/witcheer/Pollen/wduck-z7.alive
  [ $(( now - hb )) -ge 1800 ] && { echo "$(date -u +%FT%TZ) alive, launched=$launched, onnx: $(ls policies-ours/velmixslope-*-it16000.onnx 2>/dev/null || echo none)"; hb=$now; }
  if [ $launched = 0 ] && ls policies-ours/velmixslope-*-it16000.onnx >/dev/null 2>&1; then
    sleep 30
    for b in a b c; do
      if [ -d clips/proof-z7-$b-2026-10-22 ] || tmux has-session -t =prz7-$b 2>/dev/null; then echo "$(date -u +%FT%TZ) proof-z7-$b already present/running, not relaunching"; continue; fi
      tmux new -d -s prz7-$b "bash /home/witcheer/Pollen/proof-z7-$b.sh > /home/witcheer/Pollen/proof-z7-$b.out 2>&1"
    done
    launched=1; echo "$(date -u +%FT%TZ) velmixslope export seen ($(ls policies-ours/velmixslope-*-it16000.onnx)), proof-z7 a/b/c launched"
  fi
  if [ $launched = 1 ] && grep -q PROOF_Z7_A_END proof-z7-a.out 2>/dev/null && grep -q PROOF_Z7_B_END proof-z7-b.out 2>/dev/null && grep -q PROOF_Z7_C_END proof-z7-c.out 2>/dev/null; then
    /usr/bin/python3 z7-score-2026-10-22.py > proof-z7-score.txt 2>&1
    echo "$(date -u +%FT%TZ) all three batches ended, scored:"; cat proof-z7-score.txt
    echo "$(date -u +%FT%TZ) watcher end (done)"; exit 0
  fi
  sleep 60
done
echo "$(date -u +%FT%TZ) watcher end (gave up at mon 06:10, launched=$launched)"
