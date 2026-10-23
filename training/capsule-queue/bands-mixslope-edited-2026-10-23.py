# blueprint-look overlay frames for the walk-mixslope edit (PIL, no drawtext in this ffmpeg)
import os
from PIL import Image, ImageDraw, ImageFont
W=os.path.expanduser('~/promo-pilot/duck-mixslope'); F=W+'/fonts/'
CW,CH=1280,900; TOP=140; FOOT_Y=TOP+720  # footage window 1280x720 at y=140
BG=(14,58,102); MINOR=(31,82,132); MAJOR=(52,108,165); PAPER=(242,247,252); CYAN=(143,211,255); DIM=(176,201,226)
semi=ImageFont.truetype(F+'IBMPlexMono-SemiBold.ttf',54)
med=ImageFont.truetype(F+'IBMPlexMono-Medium.ttf',24)
reg=ImageFont.truetype(F+'IBMPlexMono-Regular.ttf',21)
tagf=ImageFont.truetype(F+'IBMPlexMono-SemiBold.ttf',28)
def panel(d,y0,y1):
    d.rectangle([0,y0,CW,y1],fill=BG)
    for x in range(0,CW+1,20): d.line([x,y0,x,y1],fill=MAJOR if x%100==0 else MINOR,width=1)
    for y in range(y0,y1+1,20): d.line([0,y,CW,y],fill=MAJOR if (y-y0)%100==0 else MINOR,width=1)
def ticks(d,x0,y0,x1,y1,L=16):
    for (x,y,sx,sy) in ((x0,y0,1,1),(x1,y0,-1,1),(x0,y1,1,-1),(x1,y1,-1,-1)):
        d.line([x,y,x+sx*L,y],fill=CYAN,width=3); d.line([x,y,x,y+sy*L],fill=CYAN,width=3)
def make(num,title,tag,realtime,out):
    im=Image.new('RGBA',(CW,CH),(0,0,0,0)); d=ImageDraw.Draw(im)
    panel(d,0,TOP-1); panel(d,FOOT_Y,CH)
    d.line([0,TOP-2,CW,TOP-2],fill=CYAN,width=3); d.line([0,FOOT_Y+1,CW,FOOT_Y+1],fill=CYAN,width=3)
    ticks(d,14,12,CW-15,TOP-16)
    d.text((40,22),'Microduck  ·  one walk for steps and hills',font=med,fill=DIM)
    d.text((40,58),num,font=semi,fill=CYAN)
    nx=40+d.textlength(num+'  ',font=semi)
    d.text((nx,58),title,font=semi,fill=PAPER)
    # speed tag, right aligned
    tw=d.textlength(tag,font=tagf); bx1=CW-40; bx0=int(bx1-tw-36); by0,by1=62,112
    if realtime:
        d.rectangle([bx0,by0,bx1,by1],outline=CYAN,width=3); d.text((bx0+18,by0+8),tag,font=tagf,fill=CYAN)
    else:
        d.rectangle([bx0,by0,bx1,by1],fill=CYAN); d.text((bx0+18,by0+8),tag,font=tagf,fill=BG)
    assert nx+d.textlength(title,font=semi) < bx0-30, ('title collides with tag',title)
    d.text((40,FOOT_Y+9),'walk-mixslope  ·  open-source robot',font=reg,fill=DIM)
    s='MuJoCo simulation only  ·  not yet on a real robot'; d.text((CW-40-d.textlength(s,font=reg),FOOT_Y+9),s,font=reg,fill=PAPER)
    im.save(out)
make('01','down a 25 mm step','1x real time',True,W+'/band1.png')
make('02','across the floor','4x speed',False,W+'/band2.png')
make('03','onto a hill','1x real time',True,W+'/band3.png')
print('bands ok')
