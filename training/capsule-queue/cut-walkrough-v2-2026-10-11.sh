#!/bin/bash
# cut the walk-rough v2 vs v1 pair (2026-10-11): y-L9-random_grid-t1 (09y it11000) | v1-L9-random_grid-t3 (velrough it8000),
# both in Mjlab-Velocity-Rough-Backlash-MicroDuck, forced row 9 random_grid, 0-7.10 s (v1 reset at 7.12 s), last frame held 1.5 s.
cd /opt/data/tmp/proof-2026-10-11
ffmpeg -v error -y -t 7.10 -i y-L9-random_grid-t1.mp4 -t 7.10 -i v1-L9-random_grid-t3.mp4 -filter_complex "\
[0:v]crop=1024:720:128:0,tpad=stop_mode=clone:stop_duration=1.5,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:textfile=lab1.txt:fontsize=40:fontcolor=white:x=24:y=24:box=1:boxcolor=black@0.55:boxborderw=12[a];\
[1:v]crop=1024:720:128:0,tpad=stop_mode=clone:stop_duration=1.5,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:textfile=lab2.txt:fontsize=40:fontcolor=white:x=24:y=24:box=1:boxcolor=black@0.55:boxborderw=12[b];\
[a][b]hstack=inputs=2,pad=iw:ih+124:0:0:black,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:textfile=cap1.txt:fontsize=30:fontcolor=white:x=(w-text_w)/2:y=h-104,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:textfile=cap2.txt:fontsize=30:fontcolor=white:x=(w-text_w)/2:y=h-56" \
 -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -movflags +faststart -an walk-rough-v2-vs-v1-grid-x.mp4
echo rc=$?
ffprobe -v error -show_entries stream=width,height:format=duration -of csv walk-rough-v2-vs-v1-grid-x.mp4
