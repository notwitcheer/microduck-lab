#!/bin/bash
# clip-hop2-2026-10-29.sh: cuts the 09z23 clips from the proof-hop2-a/b takes (fixed world camera, 1280x720, 50 fps, 6 s). runs ON capsule (CPU only, nice 19, no GPU), imageio_ffmpeg
# (no drawtext: captions are PIL strips padded UNDER the frame so nothing covers the feet). outputs in ~/Pollen/clips/x-hop2-<tag>/:
#   hop2-x.mp4             hero (the strict-success take with the highest trunk apex): 3.2 s at 1x ending 1 s after its longest flight starts, then the flight window at 0.25x (labelled). 1280x844.
#   hop2-x-beforeafter.mp4 ONLY on a GAIN verdict (read from the score file): the seed take with the MEDIAN apex first (before), then the hero cut. on NO GAIN the hero alone is cut, never a before/after.
# usage: bash clip-hop2-2026-10-29.sh [batch tag, default 2026-10-29]
# CAPTION RULE: numbers come ONLY from the picked take's own strict log (strict flights in the take, longest strict flight in ms, trunk apex above the standing height in mm); the hop wording is burnt in only when hop2-pickclip says success=1;
# every caption carries "simulation only, not yet on a real robot". the training time comes from ~/duckhop2-status.json (omitted when missing, e.g. test runs). the clip never says "jump" for a take without a strict flight.
set -euo pipefail
TAG=${1:-2026-10-29}
P=/home/witcheer/Pollen; PY=$P/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
B=$P/clips/proof-hop2-a-$TAG; BR=$P/clips/proof-hop2-b-$TAG; D=$P/clips/x-hop2-$TAG; mkdir -p $D
PICK=$(/usr/bin/python3 $P/hop2-pickclip-2026-10-29.py $TAG); echo "$PICK"
NEW=$(echo "$PICK" | awk '/^NEW/{print $2}'); REF=$(echo "$PICK" | awk '/^REF/{print $2}')
OK=$(echo "$PICK" | sed -n 's/^NEW.* success=\([01]\).*/\1/p'); FL=$(echo "$PICK" | sed -n 's/^NEW.* flights=\([0-9]*\).*/\1/p')
AIR=$(echo "$PICK" | sed -n 's/^NEW.* longest=\([0-9]*\).*/\1/p'); LIFT=$(echo "$PICK" | sed -n 's/^NEW.* lift=\([-0-9.]*\).*/\1/p'); T0=$(echo "$PICK" | sed -n 's/^NEW.* t=\([0-9.]*\) success.*/\1/p')
RFL=$(echo "$PICK" | sed -n 's/^REF.* flights=\([0-9]*\).*/\1/p')
SS1=$(python3 -c "print(max(0.0, min(2.7, round(float('$T0')-1.0, 2))))"); SS2=$(python3 -c "print(max(0.0, min(4.7, round(float('$T0')-0.4, 2))))")   # windows clamped inside the 6 s take (3.2 s + 1.2 s)
MIN=""; ITN=""; if [ -s /home/witcheer/duckhop2-status.json ]; then MIN=$($PY - <<'PY'
import json,re
d=json.load(open('/home/witcheer/duckhop2-status.json'))['phases'].get('train',{}).get('detail','')
m=re.search(r'([\d.]+) s/it',d)
print(round(3000*float(m[1])/60/5)*5 if m else '')
PY
); fi
PJ=/home/witcheer/Pollen/pick-hop2-$TAG.json; [ -s $PJ ] || PJ=/home/witcheer/Pollen/pick-hop2.json
[ -s $PJ ] && ITN=$($PY -c "import json;print(json.load(open('$PJ'))['pick']-7000)")
$PY - $D "$OK" "$FL" "$AIR" "$LIFT" "$RFL" "$MIN" "$ITN" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
D, ok, fl, air, lift, rfl, mins, itn = sys.argv[1:9]
W, H = 1280, 124
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def fit(txt, path, size, d):
    while size > 18 and d.textlength(txt, font=ImageFont.truetype(path, size)) > 1200: size -= 1
    return ImageFont.truetype(path, size)
train = f"after {int(itn):,} more iterations{f' (about {mins} min on one GPU)' if mins else ''}" if itn else "after training"
caps = {
 'before': (("before: the walking policy it started from, standing in place: the whole duck never leaves the floor" if rfl == '0' else "before: the walking policy it started from, standing in place"), "Microduck, simulation only, not yet on a real robot"),
 'after':  ((f"{train}: the whole duck leaves the floor, {fl} flights in 6 s, longest {air} ms, trunk up to {lift} mm above standing" if ok == '1' else f"{train}"), "simulation only, not yet on a real robot. no jump was programmed: the reward pays for time off the floor and trunk height"),
 'slow':   ((f"same take at 0.25x: no part of the duck touches the floor for {air} ms (trunk {lift} mm above standing at the best)" if ok == '1' else "same take at 0.25x"), "simulation only, not yet on a real robot"),
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
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/hop2-x.mp4
SC=$P/proof-hop2-score.txt; [ -s "$SC" ] || SC=$P/proof-hop2-score-$TAG.txt
if grep -q '^VERDICT: GAIN' "$SC" 2>/dev/null; then
nice -n 19 $FF -y -loglevel error \
 -ss 0 -t 3.2 -i $BR/$REF.mp4 -loop 1 -t 3.2 -i $D/cap-before.png \
 -ss $SS1 -t 3.2 -i $B/$NEW.mp4 -loop 1 -t 3.2 -i $D/cap-after.png \
 -ss $SS2 -t 1.2 -i $B/$NEW.mp4 -loop 1 -t 4.8 -i $D/cap-slow.png \
 -filter_complex "[0:v]pad=1280:844:0:0:black,setsar=1[a0];[a0][1:v]overlay=0:720,fps=50,format=yuv420p[a];[2:v]pad=1280:844:0:0:black,setsar=1[b0];[b0][3:v]overlay=0:720,fps=50,format=yuv420p[b];[4:v]setpts=4.0*(PTS-STARTPTS),pad=1280:844:0:0:black,setsar=1[c0];[c0][5:v]overlay=0:720:shortest=1,fps=50,format=yuv420p[c];[a][b][c]concat=n=3:v=1:a=0[o]" \
 -map "[o]" -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/hop2-x-beforeafter.mp4
else rm -f $D/hop2-x-beforeafter.mp4; echo "BEFOREAFTER skipped: verdict is not GAIN (picker rule, score file $SC)"; fi
for f in hop2-x hop2-x-beforeafter; do [ -f $D/$f.mp4 ] || continue; ls -la $D/$f.mp4; { $FF -hide_banner -i $D/$f.mp4 2>&1 || true; } | grep -E "Duration|Stream" | head -n 2 || true; done
for t in 0.3 1.0 3.6 5.0; do $FF -loglevel error -y -ss $t -i $D/hop2-x.mp4 -frames:v 1 $D/still-hero-$t.png; done
echo "CUT_DONE NEW=$NEW REF=$REF SUCCESS=$OK"
