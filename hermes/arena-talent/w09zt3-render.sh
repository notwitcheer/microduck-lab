#!/bin/bash
# w09zt3-render.sh: after 09zt3-duck-talent has judged its checkpoints (pick-ducktalent.json exists), render every Hermes act on OUR policy
# through the Arena's own clip path (CPU, SwiftShader, no GPU). run in tmux "w09zt3" with "nogpu" in the start command (the runner ignores it).
# liveness: touches ~/Pollen/arena-talent/w09zt3.alive every loop, "alive" line every 30 min, log ~/Pollen/arena-talent/w09zt3-render.log.
# gives up after Fri 2026-10-30 06:00 UTC. clips land in ~/Pollen/arena-talent/final/own/.
exec >> /home/witcheer/Pollen/arena-talent/w09zt3-render.log 2>&1
AT=/home/witcheer/Pollen/arena-talent; PICK=$AT/pick-ducktalent.json; ALIVE=$AT/w09zt3.alive
GIVEUP=$(date -u -d '2026-10-30 06:00:00' +%s)
echo "$(date -u +%FT%TZ) watcher start, waiting for $PICK"
last=0
while [ ! -s "$PICK" ]; do
  touch $ALIVE; now=$(date +%s)
  [ "$now" -gt "$GIVEUP" ] && { echo "$(date -u +%FT%TZ) gave up"; exit 1; }
  [ $((now-last)) -ge 1800 ] && { echo "$(date -u +%FT%TZ) alive, queue: $(ls /home/witcheer/idle-queue | tr '\n' ' ')"; last=$now; }
  sleep 60
done
sleep 30
N=$(python3 -c "import json;print(json.load(open('$PICK'))['pick'])")
ONNX=/home/witcheer/Pollen/policies-ours/talent-ducktalent-ck$N.onnx
echo "$(date -u +%FT%TZ) pick $N -> $ONNX"
[ -s "$ONNX" ] || { echo "MISSING $ONNX"; exit 1; }
# render order: the hero acts first (CPU clips take 6-10 min each under load)
ORDER=""; for h in death-metal-headbang proposal opera-death self-heckle interview aerobics wobbly-wave; do [ -f $AT/acts/$h.json ] && ORDER="$ORDER $AT/acts/$h.json"; done
cd $AT && bash $AT/talent-render.sh $ONNX own $ORDER > /dev/null
# review copy of what a real publish would upload for the hero act (dry run, nothing leaves the box)
RL=$AT/microduck-challenges; HERO=${TALENT_HERO:-death-metal-headbang}
RUNDIR=$(ls -d $RL/logs/rsl_rl/got_a_talent/*_talent 2>/dev/null | tail -n 1)
if [ -n "$RUNDIR" ]; then
  mkdir -p $AT/publish-dryrun; rm -rf $AT/publish-dryrun/*
  ( cd $RL && PATH=/home/witcheer/.local/bin:$PATH uv run publish --run $RUNDIR --checkpoint $N --repo witcheer/microduck-got-a-talent --name hermes-$HERO --no-private --timeline $AT/acts/$HERO.json --description "Got a Talent performer, Pollen's recipe as is (Mjlab-GotATalent-MicroDuck, seed 1, 3000 iterations, 4096 envs, one RTX 5090). Performance written by Hermes Agent from one plain sentence. Trained in simulation only. Not yet tested on a real Microduck." --code-url https://github.com/notwitcheer/microduck-lab/blob/main/training/capsule-queue/09zt3-duck-talent.sh --device cpu --dry-run > $AT/publish-dryrun/dryrun.log 2>&1 && mv publish-hermes-$HERO $AT/publish-dryrun/ )
  echo "$(date -u +%FT%TZ) publish dry run: $(ls $AT/publish-dryrun | tr '\n' ' ')"
fi
echo "$(date -u +%FT%TZ) render finished: $(ls $AT/final/own/*.mp4 2>/dev/null | wc -l) mp4"
touch $ALIVE
