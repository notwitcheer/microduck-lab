#!/bin/bash
# wduck-verdicts-2026-10-17.sh: weekend verdict launcher (nogpu watcher, tmux "wduckv"). waits for each duck item's export, then
# launches its proof-take batches in detached tmux (1-env takes share the card with a bench leg harmlessly, ~4 GB).
#   09z5 velslope: ~/Pollen/policies-ours/velslope-*-it10000.onnx -> proof-z5-{a,b,c} (OUT dirs keep the 2026-10-16 label)
#   09z6 velmix:   ~/Pollen/policies-ours/velmix-*-it13000.onnx   -> proof-z6-{a,b,c,d} (OUT dirs labelled 2026-10-17)
# gives up at mon 2026-10-19 06:10 local. log ~/Pollen/wduck-verdicts.log.
exec >> /home/witcheer/Pollen/wduck-verdicts.log 2>&1
cd /home/witcheer/Pollen
STOP=$(date -d '2026-10-19 06:10' +%s); z5=0; z6=0
echo "$(date -u +%FT%TZ) watcher start"
while [ "$(date +%s)" -lt "$STOP" ] && { [ $z5 = 0 ] || [ $z6 = 0 ]; }; do
  if [ $z5 = 0 ] && ls policies-ours/velslope-*-it10000.onnx >/dev/null 2>&1; then
    sleep 30; for b in a b c; do tmux new -d -s prz5-$b "bash /home/witcheer/Pollen/proof-z5-$b.sh > /home/witcheer/Pollen/proof-z5-$b.out 2>&1"; done
    z5=1; echo "$(date -u +%FT%TZ) velslope export seen, proof-z5 a/b/c launched"; fi
  if [ $z6 = 0 ] && ls policies-ours/velmix-*-it13000.onnx >/dev/null 2>&1; then
    sleep 30; for b in a b c d; do tmux new -d -s prz6-$b "bash /home/witcheer/Pollen/proof-z6-$b.sh > /home/witcheer/Pollen/proof-z6-$b.out 2>&1"; done
    z6=1; echo "$(date -u +%FT%TZ) velmix export seen, proof-z6 a/b/c/d launched"; fi
  sleep 120
done
echo "$(date -u +%FT%TZ) watcher end z5=$z5 z6=$z6"
