#!/bin/bash
# clip-hop-2026-10-27.sh: cuts the 09z16 X clips from the proof-hop-a/b takes (fixed world camera, 1280x720, 50 fps, 6 s). runs ON capsule (CPU only, nice 19, no GPU), imageio_ffmpeg
# (no drawtext: captions are PIL strips padded UNDER the frame so nothing covers the feet). outputs in ~/Pollen/clips/x-hop-<tag>/:
#   hop-x.mp4             hero (the success take with the highest foot lift): 3.2 s at 1x around its longest flight, then the flight window at 0.25x. 1280x844.
#   hop-x-beforeafter.mp4 the "before" first (the seed, the reference take with the MEDIAN foot lift, 0-3.2 s), then the hero cut. single panel each, sequential.
# usage: bash clip-hop-2026-10-27.sh [batch tag, default 2026-10-27]
# the caption only states what the take shows: the hop wording is added only when hop-pick says success=1; the numbers (hops in the take, longest both-feet-off-the-floor time, peak foot lift) come
# from the picked take's [hop] log; the training time comes from ~/duckhop-status.json and is omitted when the manifest is missing (test runs).
set -euo pipefail
TAG=${1:-2026-10-27}
P=/home/witcheer/Pollen; PY=$P/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
B=$P/clips/proof-hop-a-$TAG; BR=$P/clips/proof-hop-b-$TAG; D=$P/clips/x-hop-$TAG; mkdir -p $D
PICK=$(/usr/bin/python3 $P/hop-pick-2026-10-27.py $TAG); echo "$PICK"
NEW=$(echo "$PICK" | awk '/^NEW/{print $2}'); REF=$(echo "$PICK" | awk '/^REF/{print $2}')
OK=$(echo "$PICK" | sed -n 's/^NEW.* success=\([01]\).*/\1/p'); HOPS=$(echo "$PICK" | sed -n 's/^NEW.* hops=\([0-9]*\).*/\1/p')
AIR=$(echo "$PICK" | sed -n 's/^NEW.* longest=\([0-9]*\).*/\1/p'); FOOT=$(echo "$PICK" | sed -n 's/^NEW.* foot=\([0-9.]*\).*/\1/p'); T0=$(echo "$PICK" | sed -n 's/^NEW.* t=\([0-9.]*\) success.*/\1/p')
RHOPS=$(echo "$PICK" | sed -n 's/^REF.* hops=\([0-9]*\).*/\1/p'); RFOOT=$(echo "$PICK" | sed -n 's/^REF.* foot=\([0-9.]*\).*/\1/p')
SS1=$(python3 -c "print(max(0.0, round(float('$T0')-1.0, 2)))"); SS2=$(python3 -c "print(max(0.0, round(float('$T0')-0.4, 2)))")
MIN=""; if [ -s /home/witcheer/duckhop-status.json ]; then MIN=$($PY - <<'PY'
import json,re
d=json.load(open('/home/witcheer/duckhop-status.json'))['phases'].get('train',{}).get('detail','')
m=re.search(r'([\d.]+) s/it',d)
print(round(3000*float(m[1])/60/5)*5 if m else '')
PY
); fi
$PY - $D "$OK" "$HOPS" "$AIR" "$FOOT" "$RHOPS" "$RFOOT" "$MIN" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
D, ok, hops, air, foot, rhops, rfoot, mins = sys.argv[1:9]
W, H = 1280, 124
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def fit(txt, path, size, d):
    while size > 18 and d.textlength(txt, font=ImageFont.truetype(path, size)) > 1200: size -= 1
    return ImageFont.truetype(path, size)
train = f"after 3,000 iterations{f' (about {mins} min on one GPU)' if mins else ''}"
caps = {
 'before': (("before: the walking policy it started from, standing in place: no hop in this take" if rhops == '0' else "before: the walking policy it started from, standing in place"), "Microduck, simulation only, not yet on a real robot"),
 'after':  ((f"{train}: both feet leave the floor, {hops} hops in 6 s, longest {air} ms in the air" if ok == '1' else f"{train}"), "simulation only, not yet on a real robot. no jump was programmed: the reward pays for time off the floor and height"),
 'slow':   ((f"same take at 0.25x: both feet off the floor for {air} ms, peak foot lift {foot} mm" if ok == '1' else "same take at 0.25x"), "simulation only, not yet on a real robot"),
}
for k, (l1, l2) in caps.items():
    im = Image.new('RGB', (W, H), 'black'); d = ImageDraw.Draw(im)
    for txt, path, size, y in ((l1, B, 30, 18), (l2, R, 26, 70)):
        f = fit(txt, path, size, d); w = d.textlength(txt, font=f); d.text(((W - w) / 2, y), txt, font=f, fill='white')
    im.save(f'{D}/cap-{k}.png')
PY
nice -n 19 $FF -y -loglevel error \
 -ss $SS1 -t 3.2 -i $B/$NEW.mp4 -loop 1 -t 3.2 -i $D/cap-after.png \
 -ss $SS2 -t 1.2 -i $B/$NEW.mp4 -loop 1 -t 4.8 -i $D/cap-slow.png \
 -filter_complex "[0:v]pad=1280:844:0:0:black,setsar=1[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]setpts=4.0*(PTS-STARTPTS),pad=1280:844:0:0:black,setsar=1[b0];[b0][3:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[b];[a][b]concat=n=2:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/hop-x.mp4
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t 3.2 -i $BR/$REF.mp4 -loop 1 -t 3.2 -i $D/cap-before.png \
 -ss $SS1 -t 3.2 -i $B/$NEW.mp4 -loop 1 -t 3.2 -i $D/cap-after.png \
 -ss $SS2 -t 1.2 -i $B/$NEW.mp4 -loop 1 -t 4.8 -i $D/cap-slow.png \
 -filter_complex "[0:v]pad=1280:844:0:0:black,setsar=1[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]pad=1280:844:0:0:black,setsar=1[b0];[b0][3:v]overlay=0:720,fps=50,format=yuv420p[b];[4:v]setpts=4.0*(PTS-STARTPTS),pad=1280:844:0:0:black,setsar=1[c0];[c0][5:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[c];[a][b][c]concat=n=3:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/hop-x-beforeafter.mp4
for f in hop-x hop-x-beforeafter; do ls -la $D/$f.mp4; { $FF -hide_banner -i $D/$f.mp4 2>&1 || true; } | grep -E "Duration|Stream" | head -n 2 || true; done
for t in 0.3 1.0 3.6 5.0; do $FF -loglevel error -y -ss $t -i $D/hop-x.mp4 -frames:v 1 $D/still-hero-$t.png; done
echo "CUT_DONE NEW=$NEW REF=$REF SUCCESS=$OK"
