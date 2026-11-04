#!/bin/bash
# rlgl-clip-2026-11-04.sh <out dir> <tag>: render the hero clip from <out dir>/traj.npz (CPU, nice 19, ffmpeg always -nostdin </dev/null), a 720p preview and 8 stills.
#   outputs in <out dir>/clips/: rlgl-hero.mp4 (1920x1080, 25 fps, ~24 s), rlgl-hero-preview.mp4 (1280x720, crf 28), still-1..8.png. render log: <out dir>/render.log
#   env hooks (e2e only): RLGL_COLS (22) lays the field out in that many columns.
set -uo pipefail
OUT=$(readlink -f "$1"); TAG=${2:-run}
P=/home/witcheer/Pollen; I=$P/rlgl-item
C=$OUT/clips; mkdir -p "$C"
cd $P/microduck_rl || exit 2
FF=$(.venv/bin/python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
MUJOCO_GL=egl CUDA_VISIBLE_DEVICES= nice -n 19 .venv/bin/python $I/rlgl_render.py --traj $OUT/traj.npz --model $OUT/duck.mjb --out $C/rlgl-hero.mp4 --cols ${RLGL_COLS:-22} < /dev/null > $OUT/render.log 2>&1
rc=$?
grep -E '^\[render\] (RESULT|wrote)' $OUT/render.log
[ $rc = 0 ] && [ -s $C/rlgl-hero.mp4 ] || { echo "render FAILED rc=$rc"; exit 4; }
nice -n 19 $FF -nostdin -y -loglevel error -i $C/rlgl-hero.mp4 -vf scale=1280:720 -c:v libx264 -crf 28 -pix_fmt yuv420p -movflags +faststart -an $C/rlgl-hero-preview.mp4 < /dev/null && echo "preview cut" || echo "preview FAILED"
DUR=$($FF -nostdin -i $C/rlgl-hero.mp4 < /dev/null 2>&1 | sed -n 's/.*Duration: \([0-9]*\):\([0-9]*\):\([0-9.]*\).*/\1 \2 \3/p' | awk '{print $1*3600+$2*60+$3}')
k=1
for t in 0.2 1.4 2.4 6.0 9.0 14.5 20.0 $(awk -v d="$DUR" 'BEGIN{printf "%.2f", d-0.6}'); do
  $FF -nostdin -y -loglevel error -ss $t -i $C/rlgl-hero.mp4 -frames:v 1 $C/still-$k.png < /dev/null
  k=$((k + 1))
done
echo "CUT_DONE tag=$TAG dur=$DUR $(ls -la $C/rlgl-hero.mp4 $C/rlgl-hero-preview.mp4 2>/dev/null | awk '{print $5, $9}' | sed 's#.*/##' | tr '\n' ';') stills=$(ls $C/still-*.png 2>/dev/null | wc -l)"
