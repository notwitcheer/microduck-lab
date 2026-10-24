#!/bin/bash
# clip-bigkick-2026-10-24.sh: cuts the 09z10 X clips from the proof-bk-a takes (camera D, 1280x720, 50 fps, 6 s). runs ON capsule (CPU only, nice 19, no GPU), imageio_ffmpeg binary
# (no drawtext: captions are PIL strips padded UNDER the frame so nothing covers the feet). outputs in ~/Pollen/clips/x-bigkick-2026-10-24/:
#   bigkick-x.mp4            hero: after take at 1x (0-3.2 s), then the same take 0.2-2.6 s at 0.5x. 1280x844.
#   bigkick-x-beforeafter.mp4  the seed's median take on the giant ball first (0-3.2 s, "before"), then the hero cut. single panel each, sequential (his standing rule: no side-by-side).
# usage: bash clip-bigkick-2026-10-24.sh [batch tag, default 2026-10-24] [new prefix] [seed prefix]    (test: bash clip-bigkick-2026-10-24.sh s15a bkna bksa uses the seed as both)
# the caption only states what the take shows: the "into the goal" wording is added only when bk-pick says GOAL=1 for the picked take; the training time comes from
# ~/duckbigkick-status.json (train detail "<it> iterations, <s/it> s/it ...") and is omitted when the manifest is missing (test runs).
set -euo pipefail
TAG=${1:-2026-10-24}; NP=${2:-bkna}; SP=${3:-bksa}
P=/home/witcheer/Pollen; PY=$P/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
B=$P/clips/proof-bk-a-$TAG; D=$P/clips/x-bigkick-$TAG; mkdir -p $D
PICK=$(/usr/bin/python3 $P/bk-pick-2026-10-24.py $B $NP $SP); echo "$PICK"
NEW=$(echo "$PICK" | awk '/^NEW/{print $2}'); SEED=$(echo "$PICK" | awk '/^SEED/{print $2}'); GOAL=$(echo "$PICK" | sed -n 's/^NEW.* goal=\([01]\).*/\1/p')
MIN=""; if [ -s /home/witcheer/duckbigkick-status.json ]; then MIN=$($PY - <<'PY'
import json,re
d=json.load(open('/home/witcheer/duckbigkick-status.json'))['phases'].get('train',{}).get('detail','')
m=re.search(r'([\d.]+) s/it',d)
print(round(3000*float(m[1])/60/5)*5 if m else '')
PY
); fi
$PY - $D "$GOAL" "$MIN" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
D, goal, mins = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 1280, 124
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def fit(txt, path, size, d):  # shrink until the line fits inside 1200 px (never clipped at the frame edge)
    while size > 18 and d.textlength(txt, font=ImageFont.truetype(path, size)) > 1200: size -= 1
    return ImageFont.truetype(path, size)
train = f"after 3,000 more iterations{f' (about {mins} min on one GPU)' if mins else ''}"
caps = {
 'before': ("before: the kick policy trained on a 70 mm ball, now a 300 mm one", "Microduck, simulation only, not yet on a real robot"),
 'after':  (f"Microduck kicks a 300 mm ball, bigger than itself: {train}", "simulation only, not yet on a real robot. the policy is blind to the ball and the goal"),
 'slow':   (("same take at 0.5x: the shot goes into the goal" if goal == '1' else "same take at 0.5x"), "simulation only, not yet on a real robot"),
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
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/bigkick-x.mp4
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t 3.2 -i $B/$SEED.mp4 -loop 1 -t 3.2 -i $D/cap-before.png \
 -ss 0 -t 3.2 -i $B/$NEW.mp4 -loop 1 -t 3.2 -i $D/cap-after.png \
 -ss 0.2 -t 2.4 -i $B/$NEW.mp4 -loop 1 -t 4.8 -i $D/cap-slow.png \
 -filter_complex "[0:v]pad=1280:844:0:0:black,setsar=1[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]pad=1280:844:0:0:black,setsar=1[b0];[b0][3:v]overlay=0:720,fps=50,format=yuv420p[b];[4:v]setpts=2.0*(PTS-STARTPTS),pad=1280:844:0:0:black,setsar=1[c0];[c0][5:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[c];[a][b][c]concat=n=3:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/bigkick-x-beforeafter.mp4
for f in bigkick-x bigkick-x-beforeafter; do ls -la $D/$f.mp4; { $FF -hide_banner -i $D/$f.mp4 2>&1 || true; } | grep -E "Duration|Stream" | head -n 2 || true; done
for t in 0.3 1.0 3.6 5.0; do $FF -loglevel error -y -ss $t -i $D/bigkick-x.mp4 -frames:v 1 $D/still-hero-$t.png; done
echo "CUT_DONE NEW=$NEW SEED=$SEED GOAL=$GOAL"
