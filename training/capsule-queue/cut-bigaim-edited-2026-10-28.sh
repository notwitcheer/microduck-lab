#!/bin/bash
# cut-bigaim-edited-2026-10-28.sh: edited giant-ball AIM clip (09z12 / 09z13), "floodlit scoreboard" look (charcoal + LED amber + red pill),
# same edit structure as the 10-26 bigkick cut (kicker line, numbered title band, speed tag, two footer lines, SIMULATION ONLY pill, PIL bands over
# 1280x640 footage, imageio_ffmpeg without drawtext). runs ON capsule, CPU only, nice 19, no GPU.
# sources (batch proof-ba-a-2026-10-26, camera D, 1280x720, 50 fps; top 80 px of the sim render is a black panel and is cropped):
#   ref.mp4 = bkra-t14, the previous policy's MEDIAN-aim take (aim -29.5 deg, GOAL=0)   new.mp4 = bana-t6 (GOAL=1, aim -8.8 deg, one of 15 goals in 15)
# structure: 01 before (ref 0-3.0 s, 1x) | 02 after (new 0-2.6 s, 1x) | 03 same new take 0.1-2.7 s at 0.5x (5.2 s) + last frame held 1.2 s.
# on-screen claims: "into the goal" / "the ball goes in" only on the GOAL=1 take; "wide" only on the GOAL=0 take; counts from ~/Pollen/proof-ba-score.txt.
# usage: bash cut-bigaim-edited-2026-10-28.sh <work dir containing ref.mp4 new.mp4 fonts/ ffpath>
set -euo pipefail
W=${1:?work dir}; cd "$W"
FF=$(cat ffpath); V=$HOME/promo-pilot/vv/bin/python
WD="$W" nice -n 19 $V - <<'PY'
import os
from PIL import Image, ImageDraw, ImageFont
W=os.environ['WD']; F=W+'/fonts/'
CW=1280; TOP=124; VH=640; BOT=88; CH=TOP+VH+BOT; FOOT_Y=TOP+VH
BG=(16,18,22); DOT=(30,33,40); LINE=(244,241,232); AMB=(255,176,0); RED=(255,92,80); DIM=(176,182,190)
anton=ImageFont.truetype(F+'Anton-Regular.ttf',50)
kick=ImageFont.truetype(F+'BarlowSemiCondensed-SemiBold.ttf',24)
r1f=ImageFont.truetype(F+'BarlowSemiCondensed-Bold.ttf',29)
r2f=ImageFont.truetype(F+'BarlowSemiCondensed-Medium.ttf',23)
tagf=ImageFont.truetype(F+'Anton-Regular.ttf',28)
pillf=ImageFont.truetype(F+'BarlowSemiCondensed-Bold.ttf',22)
def board(d,y0,y1):
    d.rectangle([0,y0,CW,y1],fill=BG)
    for yy in range(y0+6,y1,14):
        for xx in range(6,CW,14): d.rectangle([xx,yy,xx+2,yy+2],fill=DOT)
def make(num,title,tag,realtime,kicker,r1,r2,out):
    im=Image.new('RGBA',(CW,CH),(0,0,0,0)); d=ImageDraw.Draw(im)
    board(d,0,TOP-1); board(d,FOOT_Y,CH)
    d.line([0,TOP-3,CW,TOP-3],fill=AMB,width=4); d.line([0,FOOT_Y+2,CW,FOOT_Y+2],fill=AMB,width=4)
    d.text((40,16),kicker,font=kick,fill=DIM)
    d.rectangle([40,52,40+70,52+54],fill=AMB); d.text((40+35,52+27),num,font=anton,fill=BG,anchor='mm')
    tx=134; d.text((tx,52),title.upper(),font=anton,fill=LINE)
    tag=tag.upper(); w=d.textlength(tag,font=tagf); bx1=CW-40; bx0=int(bx1-w-40); by0,by1=56,106
    if realtime: d.rectangle([bx0,by0,bx1,by1],outline=AMB,width=3); d.text((bx0+20,by0+5),tag,font=tagf,fill=AMB)
    else: d.rectangle([bx0,by0,bx1,by1],fill=AMB); d.text((bx0+20,by0+5),tag,font=tagf,fill=BG)
    assert tx+d.textlength(title.upper(),font=anton) < bx0-30, ('title collides with tag',title)
    d.text((40,FOOT_Y+10),r1,font=r1f,fill=LINE)
    pill='SIMULATION ONLY'; pw=d.textlength(pill,font=pillf); px1=CW-40; px0=int(px1-pw-28)
    d.rectangle([px0,FOOT_Y+50,px1,FOOT_Y+80],outline=RED,width=2); d.text((px0+14,FOOT_Y+53),pill,font=pillf,fill=RED)
    d.text((40,FOOT_Y+51),r2,font=r2f,fill=DIM)
    assert 40+d.textlength(r2,font=r2f) < px0-20, ('r2 collides with pill',r2)
    assert 40+d.textlength(r1,font=r1f) < CW-40, ('r1 too wide',r1)
    im.save(out)
K='aiming the giant-ball kick  \u00b7  300 mm ball, 25 cm Microduck'
make('01','before: the previous kick policy','1x real time',True,K,
 'the ball rolls wide: the previous kick ended in the goal in 2 of 15 tries','this take: 29.5 degrees off straight, the median of its 15 tries',W+'/band1.png')
make('02','after: one more hour of training','1x real time',True,K,
 'the ball goes in: 15 of 15 tries ended in the goal (previous kick: 2 of 15)','62 min and 3,000 more rounds, with a penalty on sideways ball speed',W+'/band2.png')
make('03','the same take, slower','0.5x slow motion',False,K,
 'median new kick: 1.5 degrees off straight (previous kick: 29.5 degrees)','power kept: ball 1.25 m or more away after 2 s in 15 of 15 tries',W+'/band3.png')
print('bands ok',CW,CH)
PY
PAD="crop=1280:640:0:80,pad=1280:852:0:124:black"
FC="[0:v]trim=start=0:end=3.0,setpts=PTS-STARTPTS,fps=50,$PAD[a0];[a0][2:v]overlay=0:0:shortest=1,format=yuv420p,setsar=1[a];\
[1:v]trim=start=0:end=2.6,setpts=PTS-STARTPTS,fps=50,$PAD[b0];[b0][3:v]overlay=0:0:shortest=1,format=yuv420p,setsar=1[b];\
[1:v]trim=start=0.1:end=2.7,setpts=2*(PTS-STARTPTS),fps=50,tpad=stop_mode=clone:stop_duration=1.2,$PAD[c0];[c0][4:v]overlay=0:0:shortest=1,format=yuv420p,setsar=1[c];\
[a][b][c]concat=n=3:v=1:a=0[o]"
nice -n 19 $FF -nostdin -y -loglevel error -i ref.mp4 -i new.mp4 -loop 1 -i band1.png -loop 1 -i band2.png -loop 1 -i band3.png \
  -filter_complex "$FC" -map "[o]" -c:v libx264 -threads 4 -preset slow -crf 16 -profile:v high -pix_fmt yuv420p -r 50 -t 13 -movflags +faststart -an master.mp4
nice -n 19 $FF -nostdin -y -loglevel error -i master.mp4 -c:v libx264 -threads 4 -preset slow -crf 21 -profile:v high -pix_fmt yuv420p -r 50 -movflags +faststart -an -map_metadata -1 bigaim-edited.mp4
ls -la master.mp4 bigaim-edited.mp4
{ $FF -hide_banner -i bigaim-edited.mp4 2>&1 || true; } | grep -E "Duration|Stream"
for t in 0.4 2.0 3.6 4.6 5.4 8.0 11.0 12.0; do nice -n 19 $FF -nostdin -loglevel error -y -ss $t -i bigaim-edited.mp4 -frames:v 1 qa-$t.png; done
md5sum bigaim-edited.mp4
echo CUT_DONE
