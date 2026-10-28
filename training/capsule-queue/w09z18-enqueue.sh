#!/bin/bash
# w09z18-enqueue.sh: moves 09z18-duck-gale + 09z19-duck-proof-gale + 09z20-duck-moon + 09z21-duck-proof-moon from ~/Pollen/queue-staging into ~/idle-queue AFTER today's Wed 2026-10-28 14:10-17:10 CET duck block has ended (gate 16:15 UTC = 17:15 CET) and BEFORE the Thu 01:10 CET block.
# why held: (1) a duck header queued now would run right behind 09z16/09z17 in today's block (ld == B continues) and take the tail the watcher w71r2 (14:25 CET) leaves to the bench item, i.e. it would change today's block; (2) prefix 09z18..21 sorts AFTER 09t1/09t2 and 09z16/17, so the order
# inside any duck block is tug, hop, gale, moon. why not later than 01:10 Thu: duck-lane.sh only advances its state when a duck item actually runs the check. with these four queued at Thu 01:10 CET and a bench item (71-voxel-trees-qwen-r2, maybe 72a) queued, ld (Wed 17:10 CET, set by hop) > ly, so
# they all exit 3 within seconds and record ly = Thu 06:10 CET, which makes Thu 14:10 CET a DUCK block: w09t1 (tug 09t1/09t2, enqueued Thu 06:12 CET) then trains first there, gale + moon behind it. if they were enqueued only after Thu 06:20 CET, nothing duck would be queued at 01:10, ly would stay at Tue 17:10, and
# Thu 14:10 would YIELD to any bench item still queued (the tug would slip to Fri 01:10). if NO bench item is queued at Thu 01:10 the lane trains instead of idling (gale then trains Thu 01:10 CET, ~60 min, proof ~25 min, moon ~60 min, proof ~25 min, all before 06:10 CET): not a harm to the tug unless a bench item is queued at Thu 14:10.
# gate 16:15 UTC, then wait for tmux idleq to be gone (up to 30 min), log the queue, `.new` + bash -n + chmod + mv in locale order (09z18, 09z19, 09z20, 09z21; an already-queued file is skipped), then DRYRUN=1 of each from the queue (lane state cmp before/after) and `ls | sort` into the log.
# run in tmux "w09z18" with "# nogpu" in the start command (the runner ignores such sessions). liveness: touches ~/Pollen/w09z18.alive every loop and logs "alive" every 30 min; log ~/Pollen/w09z18-enqueue.log. stub-test hooks: W_GO, W_Q, W_S, W_LOG, W_ALIVE, W_SLEEP, W_NODRY.
exec >> ${W_LOG:-/home/witcheer/Pollen/w09z18-enqueue.log} 2>&1
Q=${W_Q:-/home/witcheer/idle-queue}; S=${W_S:-/home/witcheer/Pollen/queue-staging}   # W_* = stub-test hooks only
ALIVE=${W_ALIVE:-/home/witcheer/Pollen/w09z18.alive}
GO=${W_GO:-$(date -u -d '2026-10-28 16:15:00' +%s)}
ITEMS="09z18-duck-gale.sh 09z19-duck-proof-gale.sh 09z20-duck-moon.sh 09z21-duck-proof-moon.sh"
echo "$(date -u +%FT%TZ) watcher start, enqueue at $(date -u -d @$GO +%FT%TZ) (Wed 17:15 CET), items: $(cd $S && ls $ITEMS 2>&1 | tr '\n' ' ')"
last=0
while [ "$(date +%s)" -lt "$GO" ]; do
  touch $ALIVE
  now=$(date +%s); [ $((now-last)) -ge 1800 ] && { echo "$(date -u +%FT%TZ) alive, $(( (GO-now)/60 )) min to the gate, queue now: $(ls $Q | tr '\n' ' ')"; last=$now; }
  sleep ${W_SLEEP:-60}
done
for i in $(seq 1 60); do touch $ALIVE; tmux has-session -t =idleq 2>/dev/null || break; sleep 30; done
echo "$(date -u +%FT%TZ) gate passed, idleq session: $(tmux has-session -t =idleq 2>/dev/null && echo STILL-UP || echo gone); queue before: $(ls $Q | tr '\n' ' ')"
echo "lane state before: $(cat /home/witcheer/duck-lane-state 2>/dev/null)"; [ -f /home/witcheer/duck-lane-state ] && cp /home/witcheer/duck-lane-state ${W_LANEBAK:-/home/witcheer/duck-lane-state.bak-w09z18}
for f in $ITEMS; do
  [ -f "$Q/$f" ] && { echo "$(date -u +%FT%TZ) $f already queued, skipping"; continue; }
  [ -f "$S/$f" ] || { echo "$(date -u +%FT%TZ) MISSING $S/$f"; continue; }
  cp $S/$f $Q/$f.new && bash -n $Q/$f.new && chmod +x $Q/$f.new && mv $Q/$f.new $Q/$f && echo "$(date -u +%FT%TZ) queued $f" || echo "$(date -u +%FT%TZ) ENQUEUE FAILED $f"
done
echo "$(date -u +%FT%TZ) queue after: $(ls $Q | tr '\n' ' ')"
if [ -z "${W_NODRY:-}" ]; then
  for f in $ITEMS; do [ -f "$Q/$f" ] && { echo "--- DRYRUN $f (from the queue)"; ( cd $Q && DRYRUN=1 timeout 120 bash $f 2>&1 | tail -4 ); }; done
  [ -f /home/witcheer/duck-lane-state.bak-w09z18 ] && echo "lane state cmp after DRYRUN: $(cmp -s /home/witcheer/duck-lane-state /home/witcheer/duck-lane-state.bak-w09z18 && echo identical || echo CHANGED)"
fi
echo "lane state: $(cat /home/witcheer/duck-lane-state 2>/dev/null)"; echo "ls sort: $(ls $Q/*.sh | xargs -n1 basename | sort | tr '\n' ' ')"
touch $ALIVE
