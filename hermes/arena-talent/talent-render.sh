#!/bin/bash
# talent-render.sh POLICY.onnx TAG ACT.json...   renders each act through the Arena's own path (arena score --store, arena clip), CPU (SwiftShader) unless ARENA_CLIP_GPU=1.
# output ~/Pollen/arena-talent/final/<TAG>/<act>-{landscape,vertical}.mp4 + <act>.run (run id) + <act>.score.txt
exec > >(tee -a ~/Pollen/arena-talent/render-$2.log) 2>&1
export LD_LIBRARY_PATH=$HOME/voxelbench/lib PATH=$HOME/Pollen/arena-talent/bin:$HOME/.local/bin:$PATH CHROME=$HOME/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome
POL=$1; TAG=$2; shift 2
AT=$HOME/Pollen/arena-talent; OUT=$AT/final/$TAG; STORE=$AT/board-$TAG; mkdir -p $OUT
cd $AT/microduck-challenges
for act in "$@"; do
  n=$(basename $act .json)
  echo "$(date -u +%T) score $n"
  uv run arena score $POL --event got-a-talent --timeline $act --user witcheer --name "$n" --store $STORE > $OUT/$n.score.txt 2>&1
  cat $OUT/$n.score.txt | grep -v '^\[mdp\]'
  RID=$(grep -o 'recorded [0-9A-Z]*' $OUT/$n.score.txt | awk '{print $2}')
  echo $RID > $OUT/$n.run
  echo "$(date -u +%T) clip $n run $RID"
  nice -n 10 uv run arena clip $RID --store $STORE 2>&1 | tail -n 3
  for l in landscape vertical; do cp $STORE/clips/$RID/$l.mp4 $OUT/$n-$l.mp4 2>/dev/null; done
  cp $STORE/clips/$RID/poster.png $OUT/$n-poster.png 2>/dev/null
  # our edit treatment (caption band: the sentence, "Hermes Agent wrote this act", simulation only), needs acts/<n>.sentence
  if [ -f $AT/acts/$n.sentence ]; then
    for l in landscape vertical; do
      FFMPEG=$AT/bin/ffmpeg python3 $AT/talent-edit.py $OUT/$n-$l.mp4 $OUT/$n-$l-edit.mp4 "$(cat $AT/acts/$n.sentence)" $l
      DUR=$(python3 -c "import json;print(json.load(open('$act'))['duration_s'])") FFMPEG=$AT/bin/ffmpeg python3 $AT/talent-edit.py $OUT/$n-$l.mp4 $OUT/$n-$l-cut.mp4 "$(cat $AT/acts/$n.sentence)" $l
    done
  fi
  echo "$(date -u +%T) done $n: $(ls -la $OUT/$n-landscape.mp4 2>&1 | awk '{print $5}')"
done
echo RENDER_DONE
