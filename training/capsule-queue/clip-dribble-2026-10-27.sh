#!/bin/bash
# clip-dribble-2026-10-27.sh: cuts the 09z14 X clips from the proof-dr-a takes (tracking camera 1280x720, 50 fps, 24 s). runs ON capsule (CPU only, nice 19, no GPU), imageio_ffmpeg binary
# (no drawtext: captions are PIL strips padded UNDER the frame so nothing covers the feet). outputs in ~/Pollen/clips/x-dribble-<tag>/:
#   dribble-x.mp4             hero (the held CARRIED take with the earliest goal time): 0-2 s at 1x, the middle at 4x (speed said in the caption strip), the last 3 s before the goal and 2 s after at 1x. 1280x844.
#   dribble-x-beforeafter.mp4 the "before" first (the reference take with the MEDIAN longest near streak, 0 to first_far + 2.5 s, 1x, max 10 s), then the hero cut. single panels, sequential (no side-by-side).
# usage: bash clip-dribble-2026-10-27.sh [batch tag] [new prefix] [ref prefix]
# captions only state what the take shows: "into the goal" only when dr-pick says carried=1 (CARRIED: held, ball in the goal, never more than 0.60 m from the trunk until it went in); the "before" line only quotes first_far
# of the picked reference take; the training time comes from ~/duckdribble-status.json (train detail "<s/it> s/it"), omitted when the manifest is missing (test runs).
set -euo pipefail
TAG=${1:-$(date +%F)}; NP=${2:-dra}; RP=${3:-drsa}
P=/home/witcheer/Pollen; PY=$P/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
B=$P/clips/proof-dr-a-$TAG; D=$P/clips/x-dribble-$TAG; mkdir -p $D
PICK=$(/usr/bin/python3 $P/dr-pick-2026-10-27.py $B $NP $RP); echo "$PICK"
NEW=$(echo "$PICK" | awk '/^NEW/{print $2}'); REF=$(echo "$PICK" | awk '/^REF/{print $2}')
CAR=$(echo "$PICK" | sed -n 's/^NEW.* carried=\([01]\).*/\1/p'); TG=$(echo "$PICK" | sed -n 's/^NEW.* goal=\([0-9.]*\) .*/\1/p')
FAR=$(echo "$PICK" | sed -n 's/^REF.* first_far=\([0-9.]*\).*/\1/p'); RCAR=$(echo "$PICK" | sed -n 's/^REF.* carried=\([01]\).*/\1/p')
MIN=""; if [ -s /home/witcheer/duckdribble-status.json ]; then MIN=$($PY - <<'PY'
import json,re
d=json.load(open('/home/witcheer/duckdribble-status.json'))['phases'].get('train',{}).get('detail','')
m=re.search(r'([\d.]+) s/it',d)
print(round(3000*float(m[1])/60/5)*5 if m else '')
PY
); fi
[ -n "$TG" ] || TG=14   # no goal time (carried=0): cut the first 14 s
$PY - $D "$CAR" "$FAR" "$RCAR" "$MIN" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
D, car, far, rcar, mins = sys.argv[1:6]
W, H = 1280, 124
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def fit(txt, path, size, d):
    while size > 18 and d.textlength(txt, font=ImageFont.truetype(path, size)) > 1200: size -= 1
    return ImageFont.truetype(path, size)
train = f"after 3,000 more iterations{f' (about {mins} min on one GPU)' if mins else ''}"
caps = {
 'before': ((f"before: the same 300 mm ball, 3,000 iterations earlier: it rolls out of reach after {float(far):.0f} s" if (far and rcar == '0') else "before: the same 300 mm ball, 3,000 iterations earlier"), "Microduck, simulation only, not yet on a real robot"),
 'after1': (("Microduck walks a 300 mm ball, bigger than itself, into the goal" if car == '1' else "Microduck walks a 300 mm ball, bigger than itself"), f"{train}. simulation only, not yet on a real robot"),
 'fast':   (("same take at 4x speed: the ball stays within reach the whole way" if car == '1' else "same take at 4x speed"), "simulation only, not yet on a real robot. the policy is blind to the ball and the goal"),
 'after2': ((f"same take, 1x: the ball goes into the goal" if car == '1' else "same take, 1x"), "simulation only, not yet on a real robot"),
}
for k, (l1, l2) in caps.items():
    im = Image.new('RGB', (W, H), 'black'); d = ImageDraw.Draw(im)
    for txt, path, size, y in ((l1, B, 30, 18), (l2, R, 26, 70)):
        f = fit(txt, path, size, d); w = d.textlength(txt, font=f); d.text(((W - w) / 2, y), txt, font=f, fill='white'); print(f'CAPTION {k} size {f.size} width {w:.0f}: {txt}')
    im.save(f'{D}/cap-{k}.png')
PY
T0=$(python3 -c "print(max(3.0, $TG-3.0))"); TE=$(python3 -c "print(min(24.0, $TG+2.0))"); FDUR=$(python3 -c "print(max(0.5, $T0-2.0)/4)"); TLAST=$(python3 -c "print($TE-$T0)")
BEF=$(python3 -c "print(min(10.0, ${FAR:-8}+2.5))")
SEG='pad=1280:844:0:0:black,setsar=1'
# hero: 1x (0-2 s), 4x (2 s .. T0), 1x (T0 .. TE)
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t 2 -i $B/$NEW.mp4 -loop 1 -t 2 -i $D/cap-after1.png \
 -ss 2 -t $(python3 -c "print($T0-2.0)") -i $B/$NEW.mp4 -loop 1 -t $FDUR -i $D/cap-fast.png \
 -ss $T0 -t $TLAST -i $B/$NEW.mp4 -loop 1 -t $TLAST -i $D/cap-after2.png \
 -filter_complex "[0:v]$SEG[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]setpts=0.25*(PTS-STARTPTS),$SEG[b0];[b0][3:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[b];[4:v]$SEG[c0];[c0][5:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[c];[a][b][c]concat=n=3:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/dribble-x.mp4
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t $BEF -i $B/$REF.mp4 -loop 1 -t $BEF -i $D/cap-before.png \
 -i $D/dribble-x.mp4 \
 -filter_complex "[0:v]$SEG[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]fps=50,format=yuv420p[b];[a][b]concat=n=2:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/dribble-x-beforeafter.mp4
for f in dribble-x dribble-x-beforeafter; do ls -la $D/$f.mp4; { $FF -hide_banner -i $D/$f.mp4 2>&1 || true; } | grep -E "Duration|Stream" | head -n 2 || true; done
for t in 0.5 3.0 5.0 7.0; do $FF -loglevel error -y -ss $t -i $D/dribble-x.mp4 -frames:v 1 $D/still-hero-$t.png; done
echo "CUT_DONE NEW=$NEW REF=$REF CARRIED=$CAR TG=$TG FAR=$FAR"
