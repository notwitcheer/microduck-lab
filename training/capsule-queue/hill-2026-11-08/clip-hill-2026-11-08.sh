#!/bin/bash
# clip-hill-2026-11-08.sh <facts.json> <outdir>: the 1.5 m Hill Climb board-audit proof clip, CPU only, nice 19, nothing published, nothing entered.
# three runs, EACH in its own LOCAL store (a shared store draws the other runs as ghost ducks): (1) the audit's hero row (best-ranked fragile board row) on the Arena's own replay start, (2) the SAME file on the first unscored start it fails,
# (3) our shipped-recipe pick on the Arena's own replay start. arena clip (headless Chromium) renders each; hill_render.py cuts the card + slow motion + ladder. neutral store users ('board-row', 'ours'), never a board user name.
# every number on screen comes from facts.json (the proof's own score/check/audit files).
export PATH=/home/witcheer/Pollen/arena/bin:/home/witcheer/.local/bin:$PATH
export CHROME=$(ls /home/witcheer/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome)
export LD_LIBRARY_PATH=/home/witcheer/Pollen/arena/libs/root/usr/lib/x86_64-linux-gnu
export CUDA_VISIBLE_DEVICES=
FACTS=${1:?facts.json}; OUT=${2:?outdir}; mkdir -p $OUT
P=/home/witcheer/Pollen; A=${HILL_PROOF_DIR:-$P/arena/hill}; V=$P/arena/heist/microduck-challenges/.venv/bin
cd $P/arena/heist/microduck-challenges || exit 1
read -r OURS HERO RANK FSEED < <($V/python - "$FACTS" "$A" <<'PY'
import json, sys
f = json.load(open(sys.argv[1])); au = f.get("audit") or {}
hero = au.get("hero") or {}
rk = hero.get("rank", 1)
pat = dict((r, p) for r, p in au.get("patterns", [])).get(rk, "")
fs = next((i + 1 for i in range(5, len(pat)) if pat[i] == "x"), 7)       # the first unscored start (seed 6-25) the hero row fails
print(f["onnx"], f.get("hero_onnx") or "", rk, fs)
PY
)
[ -f "$OURS" ] && [ -f "$HERO" ] || { echo "missing onnx (ours=$OURS hero=$HERO)"; exit 2; }
one() { # <tag> <onnx> <user> <name> <seed|->   resumable: a tag with a meta file is kept; a render past the Arena's own budget (loaded box) is retried twice in a fresh store
  [ -s $OUT/$1.meta.json ] && { echo "$1 already rendered"; return 0; }
  local try RID S
  for try in 1 2 3; do
    S=$OUT/store-$1-$try; mkdir -p $S
    nice -n 19 $V/python $P/hill-store-run.py $2 hill-climb-1m5 "$3" "$4" $S $5 > $OUT/$1-score.txt 2>&1
    RID=$(sed -n 's/^recorded //p' $OUT/$1-score.txt)
    [ -n "$RID" ] || { echo "no run id for $1"; tail -n 3 $OUT/$1-score.txt; return 3; }
    if nice -n 19 $V/arena clip $RID --store $S --parallel 1 > $OUT/$1-clip.log 2>&1; then break; fi
    echo "arena clip failed for $1 (try $try): $(tail -n 1 $OUT/$1-clip.log | cut -c1-100)"; rm -rf $S; [ $try = 3 ] && return 4
  done
  cp $S/clips/$RID/landscape.mp4 $OUT/$1.mp4
  $V/python - "$1" "$S/clips/$RID/clip.json" "$OUT/$1-score.txt" "$OUT/$1.mp4" "$OUT/$1.meta.json" <<'PY'
import json, sys
tag, cj, sc, mp4, out = sys.argv[1:6]
meta = json.loads(next(l for l in open(sc) if l.startswith("META "))[5:])
tape0 = json.load(open(cj))["layouts"]["landscape"]["crowdDirection"]["start"]
t = meta["time_s"] if meta["time_s"] is not None else meta["dur"]
json.dump({"mp4": mp4, "tape0": tape0, "time": t, "seed": meta["seed"], "status": meta["status"]}, open(out, "w"))
PY
}
# one render at a time: three parallel Chromium renders on a loaded box ran past the Arena's own frame budget (2026-11-08 mock)
one hero-scored $HERO board-row "scored start" -; r1=$?
one hero-fresh $HERO board-row "unscored start" $FSEED; r2=$?
one ours $OURS ours "shipped recipe" -; r3=$?
[ $r1 = 0 ] && [ $r2 = 0 ] && [ $r3 = 0 ] || { echo "a clip failed: $r1 $r2 $r3"; exit 5; }
$V/python - "$OUT" <<'PY'
import json, sys
o = sys.argv[1]
json.dump({"hero_scored": json.load(open(o + "/hero-scored.meta.json")), "hero_fresh": json.load(open(o + "/hero-fresh.meta.json")), "ours": json.load(open(o + "/ours.meta.json"))}, open(o + "/clips.json", "w"))
PY
nice -n 19 $V/python $P/hill_render.py $FACTS $OUT/clips.json $OUT/hill-x.mp4 --stills $OUT/stills > $OUT/render.log 2>&1 && echo "CUT_DONE $OUT/hill-x.mp4" || { echo "render failed"; tail -n 5 $OUT/render.log; exit 6; }
tail -n 1 $OUT/render.log
