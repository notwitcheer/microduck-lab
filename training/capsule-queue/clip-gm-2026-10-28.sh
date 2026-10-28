#!/bin/bash
# clip-gm-2026-10-28.sh <gale|moon> [tag]: cuts the X clips of 09z19 (gale) / 09z21 (moon) from the proof batch a (fixed side camera 1280x720, 50 fps). runs ON capsule (CPU only, nice 19, no GPU),
# imageio_ffmpeg (no drawtext: a PIL meter strip per frame + a caption strip are padded UNDER the frame, 1280x924). outputs in ~/Pollen/clips/x-<mode>-<tag>/:
#   <mode>-x.mp4               hero (gm-pick-2026-10-28.py NEW): the whole take at 1x with the live meter (gale: wind force bar in N, moon: gravity + distance walked).
#   <mode>-x-beforeafter.mp4   ONLY WHEN THE VERDICT IS GAIN: the "before" first (the reference take with the MEDIAN wind held / forward progress, cut to its fall + 1.5 s for the gale), then the hero.
#                              on NO GAIN the before/after is NOT cut (picker fix owed since 09z14, 2026-10-28: a before/after on a NO GAIN made the "before" look better than the "after").
# captions state only what the picked take shows: the claim wording is used only when pick says success=1; the training time comes from ~/duck<skill>-status.json (omitted when missing). every strip says
# "simulation only, not yet on a real robot". the verdict is read from ~/Pollen/proof-<mode>-score.txt (a missing / incomplete score = treated as NO GAIN: no before/after).
set -euo pipefail
MODE=${1:?gale|moon}; TAG=${2:-2026-10-28}
P=/home/witcheer/Pollen; PY=$P/microduck_rl/.venv/bin/python
FF=$($PY -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')
SKILL=$MODE; B=$P/clips/proof-$MODE-a-$TAG; D=$P/clips/x-$MODE-$TAG; mkdir -p $D
PF=g; [ $MODE = moon ] && PF=m
SCORE=$P/proof-$MODE-score${GM_SCORE_SUFFIX:-}.txt
VERD=NOGAIN; grep -q '^VERDICT: GAIN' "$SCORE" 2>/dev/null && VERD=GAIN
PICK=$(/usr/bin/python3 $P/gm-pick-2026-10-28.py $MODE $TAG); echo "$PICK"
NEW=$(echo "$PICK" | awk '/^NEW/{print $2}'); REF=$(echo "$PICK" | awk '/^REF/{print $2}')
f() { echo "$PICK" | grep "^$1" | sed -n "s/.* $2=\([-0-9.a-z]*\).*/\1/p"; }
OK=$(f NEW success); FWD=$(f NEW fwd_end); LEAN=$(f NEW lean_med); LMAX=$(f NEW lean_max); WH=$(f NEW wind_held); BND=$(f NEW bound_ms); FLN=$(f NEW flights)
RFELL=$(f REF fell); RFT=$(f REF fall_t); RWH=$(f REF wind_held); RFWD=$(f REF fwd_end)
MIN=""; if [ -s /home/witcheer/duck$SKILL-status.json ]; then MIN=$($PY - $SKILL <<'PY'
import json,re,sys
d=json.load(open(f'/home/witcheer/duck{sys.argv[1]}-status.json'))['phases'].get('train',{}).get('detail','')
m=re.search(r'([\d.]+) s/it',d)
print(round(3000*float(m[1])/60/5)*5 if m else '')
PY
); fi
TRAIN="after 3,000 iterations${MIN:+ (about $MIN min on one GPU)}"
SIMOK="simulation only, not yet on a real robot"
SIM3="$SIMOK"
if [ $MODE = gale ]; then
  H1="Microduck walking into a wind that rises from 0 to 3.0 N in 12 s"
  if [ "$OK" = 1 ]; then H2="$TRAIN: still on its feet at 3.0 N, ${FWD} m forward, leaning up to ${LMAX} deg"; else H2="$TRAIN"; fi
  H3="$SIMOK. the policy cannot see the wind: it only feels it"
  if [ "$RFELL" = 1 ]; then R1="before: the policy it started from, knocked over at ${RWH} N"; else R1="before: the policy it started from, same wind"; fi
  R3="$SIMOK"
  GL=""
else
  H1="Microduck on the Moon: gravity 1.62 m/s² instead of 9.81"
  if [ "$OK" = 1 ]; then H2="$TRAIN: ${FWD} m walked in 10 s, still on its feet"; else H2="$TRAIN"; fi
  if [ "$OK" = 1 ] && [ "${FLN:-0}" -ge 3 ] && [ "${BND:-0}" -ge 80 ]; then H2="$TRAIN: ${FWD} m walked in 10 s, ${FLN} flights, longest ${BND} ms in the air"; fi
  H3="$SIMOK"
  R1="before: the policy it started from, same Moon: ${RFWD} m in 10 s"
  R3="$SIMOK"
  GL="1.62"
fi
seg() { # name take t0 dur c1 c2 c3
  rm -rf $D/f-$1; $PY $P/clip-gm-frames-2026-10-28.py $MODE $B/$2.log $3 $4 $D/f-$1 "$5" "$6" "$7" ${GL:-1.62} | tee -a $D/frames-$1.log | grep -E "CAPTION|FRAMES"
  nice -n 19 $FF -y -loglevel error -ss $3 -t $4 -i $B/$2.mp4 -framerate 50 -i $D/f-$1/m%04d.png -loop 1 -t $4 -i $D/f-$1/caption.png \
   -filter_complex "[0:v]fps=50,pad=1280:924:0:0:black,setsar=1[a];[a][1:v]overlay=0:720:shortest=1[b];[b][2:v]overlay=0:800:shortest=1,format=yuv420p[o]" \
   -map "[o]" -r 50 -c:v libx264 -preset fast -crf 20 -movflags +faststart -an $D/seg-$1.mp4
}
seg hero $NEW 0 $([ $MODE = gale ] && echo 14 || echo 10) "$H1" "$H2" "$H3"
cp $D/seg-hero.mp4 $D/$MODE-x.mp4
if [ "$VERD" = GAIN ]; then
  if [ $MODE = gale ] && [ "$RFELL" = 1 ]; then RD=$(python3 -c "print(min(14.0, round(float('$RFT')+1.5, 1)))"); else RD=$([ $MODE = gale ] && echo 14 || echo 10); fi
  seg before $REF 0 $RD "$H1" "$R1" "$R3"
  printf "file '%s'\nfile '%s'\n" $D/seg-before.mp4 $D/seg-hero.mp4 > $D/concat.txt
  nice -n 19 $FF -y -loglevel error -f concat -safe 0 -i $D/concat.txt -c copy -movflags +faststart $D/$MODE-x-beforeafter.mp4
  echo "BEFOREAFTER cut (verdict GAIN)"
else
  rm -f $D/$MODE-x-beforeafter.mp4
  echo "BEFOREAFTER skipped: verdict is NOT GAIN (picker rule)"
fi
for f in $MODE-x $MODE-x-beforeafter; do [ -f $D/$f.mp4 ] && { ls -la $D/$f.mp4; { $FF -hide_banner -i $D/$f.mp4 2>&1 || true; } | grep -E "Duration|Stream" | head -n 2 || true; }; done
for t in 0.5 4.0 8.0 11.5; do $FF -loglevel error -y -ss $t -i $D/$MODE-x.mp4 -frames:v 1 $D/still-hero-$t.png || true; done
echo "CUT_DONE NEW=$NEW REF=$REF SUCCESS=$OK VERDICT=$VERD"
