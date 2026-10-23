#!/bin/bash
# duck-cut.sh (2026-10-23): edited walk-mixslope clip, blueprint look. source = fresh take zc2-t1 (40 s, 50 fps, 1280x720, real time).
# ramp: 4.5-9.0 s at 1x (step-down 6-8 s), 9.0-33.0 s at 4x (title 'across the floor': the take brushes the hill foot near 19-22 s, so not 'flat'), 33.0-39.5 s at 1x (onto the hill), last frame held 2 s.
set -euo pipefail
W=$HOME/promo-pilot/duck-mixslope; cd $W
FF=$(cat ffpath); V=$HOME/promo-pilot/vv/bin/python
nice -n 19 $V duck-bands.py
FC="[0:v]trim=start=4.5:end=9.0,setpts=PTS-STARTPTS,fps=30,pad=1280:900:0:140:black[a0];[a0][1:v]overlay=0:0:shortest=1,format=yuv420p,setsar=1[a];\
[0:v]trim=start=9.0:end=33.0,setpts=(PTS-STARTPTS)/4,fps=30,pad=1280:900:0:140:black[b0];[b0][2:v]overlay=0:0:shortest=1,format=yuv420p,setsar=1[b];\
[0:v]trim=start=33.0:end=39.5,setpts=PTS-STARTPTS,fps=30,tpad=stop_mode=clone:stop_duration=2,pad=1280:900:0:140:black[c0];[c0][3:v]overlay=0:0:shortest=1,format=yuv420p,setsar=1[c];\
[a][b][c]concat=n=3:v=1:a=0[o]"
nice -n 19 $FF -nostdin -y -loglevel error -i src-zc2-t1.mp4 -loop 1 -i band1.png -loop 1 -i band2.png -loop 1 -i band3.png \
  -filter_complex "$FC" -map "[o]" -c:v libx264 -threads 4 -preset slow -crf 16 -profile:v high -pix_fmt yuv420p -r 30 -t 19.0 -movflags +faststart -an master.mp4
# discord / X size: crf 22, same chain output re-encoded from master
nice -n 19 $FF -nostdin -y -loglevel error -i master.mp4 -c:v libx264 -threads 4 -preset slow -crf 21 -profile:v high -pix_fmt yuv420p -r 30 -movflags +faststart -an -map_metadata -1 duck-mixslope-edited.mp4
ls -la master.mp4 duck-mixslope-edited.mp4
$FF -hide_banner -i duck-mixslope-edited.mp4 2>&1 | grep -E "Duration|Stream" || true
$FF -hide_banner -i master.mp4 2>&1 | grep -E "Duration|Stream" || true
echo CUT_DONE
