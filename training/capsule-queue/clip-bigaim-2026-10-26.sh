#!/bin/bash
# clip-bigaim-2026-10-26.sh: cuts the 09z12 X clips from the proof-ba-a takes (camera D, 1280x720, 50 fps, 6 s). runs ON capsule (CPU only, nice 19, no GPU), imageio_ffmpeg binary
# (no drawtext: captions are PIL strips padded UNDER the frame so nothing covers the feet). outputs in ~/Pollen/clips/x-bigaim-<tag>/:
#   bigaim-x.mp4             hero (the held new take with the ball in the goal, longest 2 s travel): 1x (0-3.2 s), then the same take 0.2-2.6 s at 0.5x. 1280x844.
#   bigaim-x-beforeafter.mp4 the "before" first (the 09z10 giant-ball kick, the reference take with the MEDIAN aim, 0-3.2 s), then the hero cut. single panel each, sequential (no side-by-side).
# usage: bash clip-bigaim-2026-10-26.sh [batch tag, default 2026-10-26] [new prefix] [ref prefix]
# the caption only states what the take shows: "into the goal" is added only when ba-pick says GOAL=1 for the picked take, "wide of the goal" for the before take only when its GOAL=0; the training time
# comes from ~/duckbigaim-status.json (train detail "<it> iterations, <s/it> s/it ...") and is omitted when the manifest is missing (test runs).
set -euo pipefail
TAG=${1:-2026-10-26}; NP=${2:-bana}; RP=${3:-bkra}
P=/home/witcheer/Pollen; PY=$P/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
B=$P/clips/proof-ba-a-$TAG; D=$P/clips/x-bigaim-$TAG; mkdir -p $D
PICK=$(/usr/bin/python3 $P/ba-pick-2026-10-26.py $B $NP $RP); echo "$PICK"
NEW=$(echo "$PICK" | awk '/^NEW/{print $2}'); REF=$(echo "$PICK" | awk '/^REF/{print $2}')
GOAL=$(echo "$PICK" | sed -n 's/^NEW.* goal=\([01]\).*/\1/p'); RGOAL=$(echo "$PICK" | sed -n 's/^REF.* goal=\([01]\).*/\1/p')
MIN=""; if [ -s /home/witcheer/duckbigaim-status.json ]; then MIN=$($PY - <<'PY'
import json,re
d=json.load(open('/home/witcheer/duckbigaim-status.json'))['phases'].get('train',{}).get('detail','')
m=re.search(r'([\d.]+) s/it',d)
print(round(3000*float(m[1])/60/5)*5 if m else '')
PY
); fi
$PY - $D "$GOAL" "$RGOAL" "$MIN" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
D, goal, rgoal, mins = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
W, H = 1280, 124
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def fit(txt, path, size, d):  # shrink until the line fits inside 1200 px (never clipped at the frame edge)
    while size > 18 and d.textlength(txt, font=ImageFont.truetype(path, size)) > 1200: size -= 1
    return ImageFont.truetype(path, size)
train = f"after 3,000 more iterations{f' (about {mins} min on one GPU)' if mins else ''}"
caps = {
 'before': ("before: the 300 mm ball goes wide of the goal" if rgoal == '0' else "before: the same 300 mm ball, 3,000 iterations earlier", "Microduck, simulation only, not yet on a real robot"),
 'after':  ((f"{train}: the same 300 mm ball, into the goal" if goal == '1' else f"Microduck kicks a 300 mm ball, bigger than itself: {train}"), "simulation only, not yet on a real robot. the policy is blind to the ball and the goal"),
 'slow':   ((" same take at 0.5x: the shot goes into the goal".strip() if goal == '1' else "same take at 0.5x"), "simulation only, not yet on a real robot"),
}
for k, (l1, l2) in caps.items():
    im = Image.new('RGB', (W, H), 'black'); d = ImageDraw.Draw(im)
    for txt, path, size, y in ((l1, B, 30, 18), (l2, R, 26, 70)):
        f = fit(txt, path, size, d); w = d.textlength(txt, font=f); d.text(((W - w) / 2, y), txt, font=f, fill='white')
    im.save(f'{D}/cap-{k}.png')
PY
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t 3.2 -i $B/$NEW.mp4 -loop 1 -t 3.2 -i $D/cap-after.png \
 -ss 0.2 -t 2.4 -i $B/$NEW.mp4 -loop 1 -t 4.8 -i $D/cap-slow.png \
 -filter_complex "[0:v]pad=1280:844:0:0:black,setsar=1[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]setpts=2.0*(PTS-STARTPTS),pad=1280:844:0:0:black,setsar=1[b0];[b0][3:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[b];[a][b]concat=n=2:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/bigaim-x.mp4
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t 3.2 -i $B/$REF.mp4 -loop 1 -t 3.2 -i $D/cap-before.png \
 -ss 0 -t 3.2 -i $B/$NEW.mp4 -loop 1 -t 3.2 -i $D/cap-after.png \
 -ss 0.2 -t 2.4 -i $B/$NEW.mp4 -loop 1 -t 4.8 -i $D/cap-slow.png \
 -filter_complex "[0:v]pad=1280:844:0:0:black,setsar=1[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]pad=1280:844:0:0:black,setsar=1[b0];[b0][3:v]overlay=0:720,fps=50,format=yuv420p[b];[4:v]setpts=2.0*(PTS-STARTPTS),pad=1280:844:0:0:black,setsar=1[c0];[c0][5:v]overlay=0:720,fps=50,format=yuv420p[c];[a][b][c]concat=n=3:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/bigaim-x-beforeafter.mp4
for f in bigaim-x bigaim-x-beforeafter; do ls -la $D/$f.mp4; { $FF -hide_banner -i $D/$f.mp4 2>&1 || true; } | grep -E "Duration|Stream" | head -n 2 || true; done
for t in 0.3 1.0 3.6 5.0; do $FF -loglevel error -y -ss $t -i $D/bigaim-x.mp4 -frames:v 1 $D/still-hero-$t.png; done
echo "CUT_DONE NEW=$NEW REF=$REF GOAL=$GOAL RGOAL=$RGOAL"
