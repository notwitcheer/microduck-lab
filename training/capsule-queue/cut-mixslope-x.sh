#!/bin/bash
# cut-mixslope-x.sh (2026-10-22): content clip for 09z7 walk-mixslope from fresh take zc2-t1 (clip-z7-fresh2-2026-10-22).
# window 3.0-39.5 s of the 40 s take (episode time-out RESET at 39.98 s is outside it; zero mid RESET lines), played at 2x.
# caption strip rendered with PIL (this ffmpeg has no drawtext), padded UNDER the frame so nothing covers the feet.
set -euo pipefail
PY=/home/witcheer/Pollen/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
IN=/home/witcheer/Pollen/clips/clip-z7-fresh2-2026-10-22/zc2-t1.mp4
D=/home/witcheer/Pollen/clips/x-mixslope-2026-10-22; mkdir -p $D
$PY - $D/caption.png <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
W,H=1280,124
im=Image.new('RGB',(W,H),'black'); d=ImageDraw.Draw(im)
f1=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',30)
f2=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',26)
l1="Microduck, walk-mixslope: off a 25 mm step, then onto a hill"
l2="simulation only, not yet on a real robot. clip at 2x speed"
for txt,f,y in ((l1,f1,18),(l2,f2,70)):
    w=d.textlength(txt,font=f); d.text(((W-w)/2,y),txt,font=f,fill='white')
im.save(sys.argv[1])
PY
$FF -y -loglevel error -ss 3.0 -t 36.5 -i $IN -i $D/caption.png -filter_complex \
 "[0:v]setpts=(PTS-STARTPTS)/2,pad=1280:844:0:0:black[v];[v][1:v]overlay=0:720,fps=50,format=yuv420p[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 21 -movflags +faststart -an $D/mixslope-x.mp4
ls -la $D/mixslope-x.mp4
$FF -hide_banner -i $D/mixslope-x.mp4 2>&1 | grep -E "Duration|Stream"
for t in 0 2 6 11 15 18; do $FF -loglevel error -y -ss $t -i $D/mixslope-x.mp4 -frames:v 1 $D/still-$t.png; done
echo CUT_DONE
