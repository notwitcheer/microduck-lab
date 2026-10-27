#!/bin/bash
# w09z16-enqueue.sh: moves 09z16-duck-hop + 09z17-duck-proof-hop into ~/idle-queue only AFTER the Wed 2026-10-28 01:10-06:10 CET duck block (hard stop 05:10 UTC), where the sibling's
# 09z14/09z15 (giant-ball dribble) train. rule (duck-queue-items.md section 7): two duck items staged the same day -> hold the second to the NEXT duck block.
# gate 05:12 UTC Wed, then wait for tmux idleq to be gone (up to 10 min), look at ~/idle-queue (the sibling's items must have left it, else the log says so and the enqueue still happens: the lane
# alternation orders them by prefix, 09z14/15 run before 09z16/17), then `.new` + bash -n + mv, 09z16 first, 09z17 right behind. run in tmux "w09z16" with "nogpu" in the start command (the runner ignores such sessions).
# liveness: touches ~/Pollen/w09z16.alive every loop and logs "alive" every 30 min; log ~/Pollen/w09z16-enqueue.log. the verdict cron checks both and the queue.
exec >> ${W_LOG:-/home/witcheer/Pollen/w09z16-enqueue.log} 2>&1
Q=${W_Q:-/home/witcheer/idle-queue}; S=${W_S:-/home/witcheer/Pollen/queue-staging}   # W_* = stub-test hooks only
ALIVE=${W_ALIVE:-/home/witcheer/Pollen/w09z16.alive}
GO=${W_GO:-$(date -u -d '2026-10-28 05:12:00' +%s)}
echo "$(date -u +%FT%TZ) watcher start, enqueue at $(date -u -d @$GO +%FT%TZ) (Wed 06:12 CET), items: $(ls $S/09z16-duck-hop.sh $S/09z17-duck-proof-hop.sh 2>&1 | tr '\n' ' ')"
last=0
while [ "$(date +%s)" -lt "$GO" ]; do
  touch $ALIVE
  now=$(date +%s); [ $((now-last)) -ge 1800 ] && { echo "$(date -u +%FT%TZ) alive, $(( (GO-now)/60 )) min to the gate, queue now: $(ls $Q | tr '\n' ' ')"; last=$now; }
  sleep ${W_SLEEP:-60}
done
for i in $(seq 1 20); do touch $ALIVE; tmux has-session -t =idleq 2>/dev/null || break; sleep 30; done
echo "$(date -u +%FT%TZ) gate passed, idleq session: $(tmux has-session -t =idleq 2>/dev/null && echo STILL-UP || echo gone); queue before: $(ls $Q | tr '\n' ' ')"
for f in 09z16-duck-hop.sh 09z17-duck-proof-hop.sh; do
  [ -f "$Q/$f" ] && { echo "$(date -u +%FT%TZ) $f already queued, skipping"; continue; }
  [ -f "$S/$f" ] || { echo "$(date -u +%FT%TZ) MISSING $S/$f"; continue; }
  cp $S/$f $Q/$f.new && bash -n $Q/$f.new && chmod +x $Q/$f.new && mv $Q/$f.new $Q/$f && echo "$(date -u +%FT%TZ) queued $f" || echo "$(date -u +%FT%TZ) ENQUEUE FAILED $f"
done
echo "$(date -u +%FT%TZ) queue after: $(ls $Q | tr '\n' ' ')"; echo "lane state: $(cat /home/witcheer/duck-lane-state 2>/dev/null)"
touch $ALIVE
