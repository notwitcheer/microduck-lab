import subprocess, sys, os
from PIL import Image, ImageDraw, ImageFont
W=os.path.expanduser('~/promo-pilot/duck-mixslope'); FF=open(W+'/ffpath').read().strip()
src=sys.argv[1]; out=sys.argv[2]; times=[float(x) for x in sys.argv[3].split(',')]; tw=int(sys.argv[4]) if len(sys.argv)>4 else 400
fr=W+'/frames'; os.makedirs(fr,exist_ok=True); ims=[]
for t in times:
    p=f'{fr}/s{t:06.2f}.png'
    subprocess.run(['nice','-n','19',FF,'-nostdin','-loglevel','error','-y','-ss',str(t),'-i',src,'-frames:v','1',p],check=True)
    im=Image.open(p).convert('RGB'); im=im.resize((tw,int(im.height*tw/im.width)))
    d=ImageDraw.Draw(im); f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',18)
    d.rectangle([0,0,90,24],fill='black'); d.text((4,2),f'{t:.1f}s',font=f,fill='yellow'); ims.append(im)
cols=4; rows=(len(ims)+cols-1)//cols; h=ims[0].height
sheet=Image.new('RGB',(cols*tw,rows*h),'white')
for i,im in enumerate(ims): sheet.paste(im,((i%cols)*tw,(i//cols)*h))
sheet.save(out); print(out, sheet.size)
