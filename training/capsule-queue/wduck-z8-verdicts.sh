#!/bin/bash
# wduck-z8-verdicts.sh: liveness + backstop for the 09z8 verdict (nogpu watcher, tmux "wduckz8"). the PRIMARY path is the queue item
# 09z9-duck-proof-velstairs.sh, which runs the three proof batches in the drain's own slot right after 09z8 exports (so they never share the card
# with the 29 GB bench leg that follows). this watcher exists for the cases the item cannot cover (drain not running, item cut):
#  - heartbeat line in ~/Pollen/wduck-z8-verdicts.log every 30 min and ~/Pollen/wduck-z8.alive touched every loop (a status turn or the verdict
#    cron reads `tmux has-session -t =wduckz8` + the alive file age; > 10 min stale = dead watcher).
#  - waits for ~/Pollen/policies-ours/velstairs-*-it19000.onnx. 20 min after it appears, if NO proof-z8 batch dir exists yet and no prz8-* tmux
#    lives (= the queue item did not start), it launches proof-z8-{a,b,c}.sh in detached tmux prz8-a/b/c, but ONLY when the card has room
#    (memory.used < 14000 MiB on two checks 20 s apart: a 29 GB bench leg starves 1-env takes, 09z7 lesson); otherwise it logs "waiting" each loop.
#  - when all three END markers exist and ~/Pollen/proof-z8-score.txt has no VERDICT line, it scores (z8-score-2026-10-23.py).
#  - exits when a VERDICT line exists. gives up Mon 2026-10-26 06:10 local.
exec >> /home/witcheer/Pollen/wduck-z8-verdicts.log 2>&1
cd /home/witcheer/Pollen
STOP=$(date -d '2026-10-26 06:10' +%s); hb=0; seen=0; room=0
echo "$(date -u +%FT%TZ) watcher start (pid $$)"
while [ "$(date +%s)" -lt "$STOP" ]; do
  now=$(date +%s); touch /home/witcheer/Pollen/wduck-z8.alive
  ONNX=$(ls policies-ours/velstairs-*-it19000.onnx 2>/dev/null | head -1)
  [ -n "$ONNX" ] && [ "$seen" = 0 ] && { seen=$now; echo "$(date -u +%FT%TZ) 09z8 export seen: $ONNX"; }
  [ $(( now - hb )) -ge 1800 ] && { echo "$(date -u +%FT%TZ) alive, onnx: ${ONNX:-none}, idleq tmux: $(tmux has-session -t =idleq 2>/dev/null && echo yes || echo no), vram used $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1) MiB, batches: $(ls -d clips/proof-z8-?-2026-10-23 2>/dev/null | tr '\n' ' ')"; hb=$now; }
  if [ -s proof-z8-score.txt ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' proof-z8-score.txt; then echo "$(date -u +%FT%TZ) scored: $(grep '^VERDICT' proof-z8-score.txt); watcher end (done)"; exit 0; fi
  if [ "$seen" != 0 ] && [ $(( now - seen )) -ge 1200 ] && ! ls -d clips/proof-z8-?-2026-10-23 >/dev/null 2>&1 && ! tmux ls -F '#{session_name}' 2>/dev/null | grep -q '^prz8-'; then
    u=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
    if [ "${u:-99999}" -lt 14000 ]; then
      sleep 20; u2=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' ')
      if [ "${u2:-99999}" -lt 14000 ]; then
        for b in a b c; do tmux new -d -s prz8-$b "bash /home/witcheer/Pollen/proof-z8-$b.sh > /home/witcheer/Pollen/proof-z8-$b.out 2>&1"; done
        echo "$(date -u +%FT%TZ) BACKSTOP: queue item did not run the batches, card at ${u2} MiB, proof-z8 a/b/c launched in tmux prz8-a/b/c"
      fi
    else echo "$(date -u +%FT%TZ) waiting: card at ${u} MiB (>= 14000), batches not launched"; sleep 240; fi
  fi
  if ls clips/proof-z8-a-2026-10-23 >/dev/null 2>&1 && grep -q PROOF_Z8_A_END proof-z8-a.out 2>/dev/null && grep -q PROOF_Z8_B_END proof-z8-b.out 2>/dev/null && grep -q PROOF_Z8_C_END proof-z8-c.out 2>/dev/null && ! { [ -s proof-z8-score.txt ] && grep -q '^VERDICT: \(GAIN\|NO GAIN\)' proof-z8-score.txt; }; then
    /usr/bin/python3 z8-score-2026-10-23.py > proof-z8-score.txt 2>&1
    echo "$(date -u +%FT%TZ) all three batches ended, scored:"; cat proof-z8-score.txt
  fi
  sleep 60
done
echo "$(date -u +%FT%TZ) watcher end (gave up at mon 06:10, seen=$seen)"
