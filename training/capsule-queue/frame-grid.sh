#!/bin/bash
# grid.sh <mp4> <out.png> <t1> <t2> ... : stills at given seconds, 2-col grid with time labels (RL venv PIL + imageio_ffmpeg)
V=$1; O=$2; shift 2
PY=/home/witcheer/Pollen/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
D=$(mktemp -d)
for t in "$@"; do $FF -loglevel error -y -ss $t -i "$V" -frames:v 1 -vf scale=640:-1 $D/f-$t.png; done
$PY - "$D" "$O" "$@" <<'PY'
import sys,os
from PIL import Image,ImageDraw
d,o,ts=sys.argv[1],sys.argv[2],sys.argv[3:]
ims=[Image.open(f"{d}/f-{t}.png") for t in ts]
w,h=ims[0].size; cols=2; rows=(len(ims)+1)//2
g=Image.new('RGB',(w*cols,h*rows),'black')
for i,(im,t) in enumerate(zip(ims,ts)):
    g.paste(im,((i%cols)*w,(i//cols)*h)); ImageDraw.Draw(g).text(((i%cols)*w+8,(i//cols)*h+8),f"t={t}s",fill='yellow')
g.save(o)
PY
rm -rf $D
