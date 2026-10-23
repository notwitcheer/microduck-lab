#!/bin/bash
# velbl-takes.sh (2026-09-26): proof takes for the level 1 backlash twin (09j), same method as the level 5 twin (vsbl-*.sh).
# seed = level 1 walk-flat model_4000 (no backlash training), twin = model_7000 (+3k it with +-1 deg play), both in the BACKLASH env;
# reference: seed in its own env. standing spawn (the velocity task has no prone spawn), trunk-tracking camera, 20 s episodes, 0.1 s sampling.
exec > >(tee -a /home/witcheer/Pollen/velbl-takes.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
OUT=/home/witcheer/Pollen/clips/velbl-2026-09-26; mkdir -p $OUT
play() { local name=$1 task=$2 ck=$3; shift 3; local d=$(dirname "$ck")
  echo "=== $(date -u +%T) clip $name ==="; local t0=$(date +%s)
  rm -f "$d/videos/play/rl-video-step-0.mp4"
  timeout 900 uv run python headless_play.py "$task" --checkpoint-file "$ck" --num-envs 1 --video True --video-length 1000 \
      --video-width 1280 --video-height 720 --episode-s 20 --log-every 5 --cam-distance 0.55 --cam-elevation -10 "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ -f "$d/videos/play/rl-video-step-0.mp4" ]; then mv "$d/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
}
BL=Mjlab-Velocity-Flat-Backlash-MicroDuck
BASE=Mjlab-Velocity-Flat-MicroDuck
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_00-00-00_seed-velocity-it4000/model_4000.pt
TWIN=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
ls -la $SEED $TWIN || exit 2
for i in 1 2 3 4 5; do
  play twin-t$i $BL $TWIN
  play seed-t$i $BL $SEED
done
for i in 1 2 3; do play ref-seed-t$i $BASE $SEED; done
echo "=== $(date -u +%T) VELBL_TAKES_END ==="
