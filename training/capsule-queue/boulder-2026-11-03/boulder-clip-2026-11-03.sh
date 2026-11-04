#!/bin/bash
# boulder-clip-2026-11-03.sh <out dir> <score file> [tag]: render the 1-env takes, pick the hero + the 'before', cut the clips (CPU only, nice 19).
#   takes: H1..H<BOULDER_NH> (Hermes reflex) and N1..N<BOULDER_NN> (no reflex), each 1 env, rendered from TWO cameras of the same run
#   (--out = low front-left camera, --out2 = plan view), all in parallel. picker = boulder-pick-2026-11-03.py (rule fixed before any take).
# outputs in <out dir>/clips/: boulder-x-plan.mp4 + boulder-x-low.mp4 (the hero, ALWAYS), boulder-x-beforeafter.mp4 (plan view: the flattened no-reflex take,
#   then the hero) ONLY when the score file says VERDICT: GAIN (never a before/after on NO GAIN). prints HERO / BEFORE / CUT_DONE lines.
# env hooks (e2e only): BOULDER_NH (6), BOULDER_NN (3), BOULDER_DUR (10), BOULDER_SEED0 (101).
set -uo pipefail
OUT=$(readlink -f "$1"); SCORE=$(readlink -f "$2"); TAG=${3:-run}
P=/home/witcheer/Pollen
CK=${BOULDER_CKPT:-$P/microduck_rl/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt}
RF=${BOULDER_REFLEX:-$P/boulder-item/reflex_hermes.py}
NH=${BOULDER_NH:-6}; NN=${BOULDER_NN:-3}; DUR=${BOULDER_DUR:-10}; S0=${BOULDER_SEED0:-101}
C=$OUT/clips; mkdir -p "$C"
FF=$(cd $P/microduck_rl && .venv/bin/python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
cd $P/microduck_rl || exit 2
run1() { # <name> <seed> <extra args...>
  local n=$1 s=$2; shift 2
  CUDA_VISIBLE_DEVICES= MUJOCO_GL=egl nice -n 19 .venv/bin/python boulder_play.py Mjlab-Velocity-Flat-Backlash-MicroDuck --checkpoint-file "$CK" --num-envs 1 --device cpu \
    --dur $DUR --cmd-vx 0.4 --v0 0.3 --acc 0.1 --render 1 --track-y 0 --seed $s --out $C/$n.mp4 --out2 $C/$n-plan.mp4 --cam2 2.1:-84:90:0.2:0.0 \
    --cam-keys 0:1.5:-12:150:-0.3:0.12,1:1.5:-12:150:-0.3:0.12 "$@" > $C/$n.log 2>&1
}
for i in $(seq 1 $NH); do run1 H$i $((S0 + i)) --reflex-file $RF --label "the dodge was written by Hermes Agent" & done
for i in $(seq 1 $NN); do run1 N$i $((S0 + 50 + i)) --reflex 0 --label "no reflex: the same duck, the same boulder" & done
wait
echo "rendered: $(ls $C/*.mp4 2>/dev/null | wc -l) mp4"
PK=$(/usr/bin/python3 $P/boulder-item/boulder-pick-2026-11-03.py $C); echo "$PK" | grep -E '^(HERO|BEFORE|\[pick\])'
H=$(echo "$PK" | sed -n 's/^HERO=//p'); B=$(echo "$PK" | sed -n 's/^BEFORE=//p')
[ "$H" != NONE ] && [ -n "$H" ] || { echo "no hero take (no clean Hermes take): no clips"; exit 4; }
cp $C/H$H.mp4 $C/boulder-x-low.mp4; cp $C/H$H-plan.mp4 $C/boulder-x-plan.mp4
if [ -f "$SCORE" ] && grep -q '^VERDICT: GAIN' "$SCORE" && [ "$B" != NONE ] && [ -n "$B" ]; then
  $FF -nostdin -y -loglevel error -i $C/N$B-plan.mp4 -i $C/H$H-plan.mp4 -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[v]" -map "[v]" -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart $C/boulder-x-beforeafter.mp4 </dev/null \
    && echo "BEFOREAFTER cut: N$B then H$H" || echo "BEFOREAFTER cut FAILED"
else
  echo "BEFOREAFTER skipped: verdict is not GAIN (or no flattened take): hero only"
fi
echo "CUT_DONE hero=H$H before=N$B $(ls -la $C/boulder-x-*.mp4 | awk '{print $5, $9}' | tr '\n' ';')"
