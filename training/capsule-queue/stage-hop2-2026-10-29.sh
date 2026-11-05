#!/bin/bash
# stage-hop2-2026-10-29.sh: the ONE-COMMAND staging of the hop2 items, to run only on the operator's yes (the frozen 300-it sweep gate said NO-GO, see vault log.md 2026-10-29; the informational continuation of sweep A reached 7/8 strict successes at +500 it).
# does: copies 09z22-duck-hop2.sh + 09z23-duck-proof-hop2.sh into ~/Pollen/queue-staging (.new + bash -n + mv), DRYRUN of both from staging with a lane-state cmp, then arms the time-gated watcher (tmux w09z22, "nogpu" in the start command)
# that enqueues them at Fri 2026-10-30 14:25 CET (after the Fri 14:10 CET duck block has started, behind tug, gale and moon). nothing enters ~/idle-queue before that. STG/KIT/NOWATCH are stub-test hooks.
set -uo pipefail
STG=${STG:-/home/witcheer/Pollen/queue-staging}; KIT=${KIT:-/home/witcheer/Pollen/hop2-dev/kit}
cp ~/duck-lane-state /tmp/lane.bak-stage-hop2
for f in 09z22-duck-hop2.sh 09z23-duck-proof-hop2.sh; do
  cp $KIT/$f $STG/$f.new && bash -n $STG/$f.new && chmod +x $STG/$f.new && mv $STG/$f.new $STG/$f && echo "staged $f" || { echo "STAGE FAILED $f"; exit 1; }
done
for f in 09z22-duck-hop2.sh 09z23-duck-proof-hop2.sh; do ( cd $STG && DRYRUN=1 bash $f 2>&1 | tail -n 3 ); done
rm -f ~/duckhop2-status.json ~/duckhop2proof-status.json
cmp ~/duck-lane-state /tmp/lane.bak-stage-hop2 && echo "lane state identical"
[ -n "${NOWATCH:-}" ] && exit 0
tmux has-session -t =w09z22 2>/dev/null && { echo "watcher w09z22 already armed"; exit 0; }
tmux new-session -d -s w09z22 "bash /home/witcheer/Pollen/w09z22-enqueue.sh # nogpu"; sleep 2; tmux ls | grep w09z22; tail -n 2 /home/witcheer/Pollen/w09z22-enqueue.log
