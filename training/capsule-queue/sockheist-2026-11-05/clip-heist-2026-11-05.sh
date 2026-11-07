#!/bin/bash
# clip-heist-2026-11-05.sh <onnx> <name> <outdir> [caption line 2 override]: the Sock Heist freeze clip of ONE policy, CPU only, nice 19, nothing published.
# arena score --store (LOCAL store, never the Space) -> run id -> arena clip (headless Chromium, ~13 min for the 30 s tape on a loaded box, measured 783 s on 2026-11-05) ->
# cut: the tape starts at clip.json crowdDirection.start (3.0 s, measured: sim t=0 = clip 3.0 s; the 3 s before are the title/aerial intro, so the cut starts at tape +0.1 s = the duck already walking, no intro),
# 10 s window (covers the first red and the first green after it, the freeze is the picture), audio kept (crowd, horn, the giant's quack), scaled 1728x972 on a 1920x1080 canvas with a 108 px caption strip under it:
# 16:9 1920x1080, burnt-in "simulation only" line. imageio's static ffmpeg has no drawtext: the strip is a PIL PNG. caption numbers come ONLY from the score file and the 25-seed CHECK line of the replay seed.
# the Arena draws "@<user> · <name>" on the clip; the store user here is witcheer (public handle, already on the live board for other events).
export PATH=/home/witcheer/Pollen/arena/bin:/home/witcheer/.local/bin:$PATH
export CHROME=$(ls /home/witcheer/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome)
export LD_LIBRARY_PATH=/home/witcheer/Pollen/arena/libs/root/usr/lib/x86_64-linux-gnu
export CUDA_VISIBLE_DEVICES=
ONNX=${1:?onnx}; NAME=${2:?name}; OUT=${3:?outdir}
A=/home/witcheer/Pollen/arena/heist; STORE=$A/store; mkdir -p $OUT
cd $A/microduck-challenges || exit 1
V=.venv/bin
FF=/home/witcheer/Pollen/arena/bin/ffmpeg
# test hook: CLIP_REUSE_RID=<run id already in the store> skips the score + the 13-minute render and re-cuts the stored clip (score text re-read from CLIP_REUSE_SCORE)
if [ -n "${CLIP_REUSE_RID:-}" ]; then RID=$CLIP_REUSE_RID; cp "${CLIP_REUSE_SCORE:?}" $OUT/score.txt
else RID=$(nice -n 19 $V/arena score $ONNX --event sock-heist-6m --user witcheer --name "$NAME" --store $STORE 2>&1 | tee $OUT/score.txt | sed -n 's/^recorded //p'); fi
[ -n "$RID" ] || { echo "no run id"; exit 2; }
echo "RUN_ID $RID"; grep -E "^scored at|^score " $OUT/score.txt
if [ -z "${CLIP_REUSE_RID:-}" ]; then nice -n 19 $V/arena clip $RID --store $STORE --parallel 1 > $OUT/clip.log 2>&1 || { echo "arena clip failed"; tail -n 5 $OUT/clip.log; exit 3; }; fi
C=$STORE/clips/$RID; cp $C/landscape.mp4 $OUT/arena-landscape.mp4; cp $C/poster.png $OUT/arena-poster.png 2>/dev/null
SEED=$(sed -n 's/.*replay from seed \([0-9]*\).*/\1/p' $OUT/score.txt | head -1)
SPEED=$(sed -n 's/^scored at \([0-9.]*\) m\/s.*/\1/p' $OUT/score.txt | head -1)
SCORE=$(sed -n 's/^score \([0-9.]*\)s.*/\1/p' $OUT/score.txt | head -1)
TAPE0=$($V/python -c "import json;print(json.load(open('$C/clip.json'))['layouts']['landscape']['crowdDirection']['start'])")
nice -n 19 $V/python -m microduck_challenges.sock_heist_6m.check $ONNX --seeds 25 > $OUT/check25.txt 2>&1
LINE=$(grep -E "^seed $SEED · " $OUT/check25.txt | head -1)
REDS=$(echo "$LINE" | sed -n 's/.* \([0-9]*\) reds\{0,1\} met.*/\1/p'); DRIFT=$(echo "$LINE" | sed -n 's/.*worst drift \([0-9.]*\) cm.*/\1/p')
FIN=$(sed -n 's/^finished \([0-9]*\)\/\([0-9]*\) .*/\1 of \2/p' $OUT/check25.txt | head -1)
echo "CLIPFACTS seed=$SEED speed=$SPEED score=$SCORE reds=$REDS drift=$DRIFT tape0=$TAPE0 check=$FIN"
L1="simulation only, not yet on a real robot"
L2=${4:-"Microduck Arena, 6 m Sock Heist, local run at $SPEED m/s: ${SCORE} s for 6 m, ${FIN} seeds finished; the replay met ${REDS:-?} reds and drifted at most ${DRIFT:-?} cm (the giant's ring is 3 cm)"}
$V/python - "$OUT/strip.png" "$L1" "$L2" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont
out, l1, l2 = sys.argv[1:4]
W, H = 1920, 108
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
img = Image.new('RGB', (W, H), 'black'); d = ImageDraw.Draw(img)
for size in range(34, 19, -1):   # shrink the second line until it fits one line; the first line is fixed
    f2 = ImageFont.truetype(R, size)
    if d.textlength(l2, font=f2) <= W - 60: break
else:
    sys.exit("caption line 2 does not fit one line at 20 px: shorten it")
f1 = ImageFont.truetype(B, 38)
d.text(((W - d.textlength(l1, font=f1)) / 2, 8), l1, font=f1, fill='white')
d.text(((W - d.textlength(l2, font=f2)) / 2, 64), l2, font=f2, fill=(205, 205, 205))
img.save(out)
PY
[ -s $OUT/strip.png ] || { echo "caption does not fit"; exit 4; }
$FF -nostdin -y -loglevel error -ss $($V/python -c "print($TAPE0+0.1)") -t 10 -i $OUT/arena-landscape.mp4 -i $OUT/strip.png \
  -filter_complex "[0:v]scale=1728:972,pad=1920:972:96:0:black[a];[a][1:v]vstack=inputs=2[v]" -map "[v]" -map "0:a?" \
  -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart $OUT/heist-x.mp4 </dev/null && echo "CUT_DONE $OUT/heist-x.mp4"
$FF -nostdin -hide_banner -i $OUT/heist-x.mp4 2>&1 </dev/null | grep -E "Stream #0:0|Duration"
