#!/bin/bash
# vsbl-record.sh (2026-09-26): proof takes for the level 5 backlash twin (09k).
# both policies played IN THE BACKLASH ENV (Mjlab-VelStand-Flat-Backlash-MicroDuck, +-1 deg play per servo):
#   seed = level 5 model_20000 (never trained with backlash), twin = model_23000 (3k it with backlash).
# 4 random-spawn takes each, 20 s episodes, cam-world auto 0.5 m (same framing as level 5, duck-0920.sh).
# shares the card with the live 32k bench leg (1 env, ~1 min per take).
exec > >(tee -a /home/witcheer/Pollen/vsbl-record.log) 2>&1
set -uo pipefail
export PATH=/home/witcheer/.cargo/bin:/home/witcheer/.local/bin:$PATH
export MUJOCO_GL=egl
cd /home/witcheer/Pollen/microduck_rl
OUT=/home/witcheer/Pollen/clips/vsbl-2026-09-26; mkdir -p $OUT
TASK=Mjlab-VelStand-Flat-Backlash-MicroDuck
play() { local name=$1 ck=$2; shift 2; local d=$(dirname "$ck")
  echo "=== $(date -u +%T) clip $name ==="; local t0=$(date +%s)
  rm -f "$d/videos/play/rl-video-step-0.mp4"
  timeout 900 uv run python headless_play.py "$TASK" --checkpoint-file "$ck" --num-envs 1 --video True --video-length 1000 \
      --video-width 1280 --video-height 720 --episode-s 20 "$@" > $OUT/$name.full.log 2>&1
  echo "rc=$? in $(( $(date +%s)-t0 )) s"
  grep -a "headless_play\|Loading\|RESET\|Error\|error" $OUT/$name.full.log > $OUT/$name.log
  if [ -f "$d/videos/play/rl-video-step-0.mp4" ]; then mv "$d/videos/play/rl-video-step-0.mp4" $OUT/$name.mp4; ls -la $OUT/$name.mp4; else echo "NO_CLIP $name"; tail -15 $OUT/$name.full.log; fi
}
SEED=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsbl/2026-09-25_00-00-00_seed-velstand-it20000/model_20000.pt
TWIN=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvsbl/2026-09-26_00-10-19_duckvsbl/model_23000.pt
ls -la $SEED $TWIN || exit 2
for i in 1 2 3 4; do
  play twin-it23000-t$i $TWIN --cam-world auto --cam-distance 0.5 --cam-elevation -8
  play seed-it20000-t$i $SEED --cam-world auto --cam-distance 0.5 --cam-elevation -8
done
echo "=== $(date -u +%T) VSBL_RECORD_END ==="
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader
