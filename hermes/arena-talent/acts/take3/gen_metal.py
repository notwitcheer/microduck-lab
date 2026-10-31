import json, math, os
T=14.5
kf=[]; song=[]
def K(t, sit=0, head=(0,0,0,0), rt=0, lt=0):
    d={"t":round(t,3),"twist":[sit,0,0],"head":[round(x,3) for x in head]}
    if rt or lt: d["triggers"]=[rt,lt]
    kf.append(d)
DOWN=lambda yaw=0,roll=0,a=1.0:(-0.9*a,0.85*a,yaw,roll)
UP=lambda yaw=0,roll=0:(0.4,-0.45,yaw,roll)
# intro: head bowed, still
K(0,0,(0,0.6,0,0)); K(0.9,0,(0,0.6,0,0))
# count-in: slow nods with quacks (sticks)
for t in (1.0,1.5,2.0,2.25):
    K(t,0,DOWN(0,0,0.6),rt=1); K(t+0.12,0,UP(0,0))
# verse riff 2.5..7.5, bang period 0.5, notes on each down-hit
riff=["C2","C2","Eb2","C2","F2","C2","Eb2","G2","C2","C2"]
t=2.5; i=0; side=1
while t<7.49:
    yaw=0.3*side; roll=0.2*side
    K(t,0,DOWN(yaw,roll)); K(t+0.25,0,UP(-yaw,-roll))
    song.append({"t":round(t,3),"note":riff[i%len(riff)],"for":0.42,"dynamic":"ff","vowel":"oh"})
    side=-side; i+=1; t+=0.5
# blast section 7.5..9.4, period 0.4
blast=["C3","C3","Db3","C3"]
t=7.5; i=0
while t<9.3:
    K(t,0,DOWN(0.2*side,0)); K(t+0.2,0,UP(0,0))
    song.append({"t":round(t,3),"note":blast[i%4],"for":0.17,"dynamic":"ff","vowel":"ah"})
    song.append({"t":round(t+0.2,3),"note":blast[(i+1)%4],"for":0.17,"dynamic":"ff","vowel":"ah"})
    side=-side; i+=1; t+=0.4
# breakdown: sit at 9.4, slow heavy bangs sitting
t=9.4
K(t,1,(0,0.3,0,0)); 
for tt in (9.9,):
    K(tt,1,(-0.6,0.8,0,0))
song.append({"t":9.9,"note":"C2","for":0.5,"dynamic":"ff","vowel":"oh"})
K(10.2,1,(0.3,-0.3,0,0))
# stand + windmill 10.5..13.4 with guttural scream (LT), no notes here
t=10.5; P=0.7
while t<13.35:
    ph=2*math.pi*(t-10.5)/P
    head=(-0.2+0.6*math.cos(ph)*-1, 0.2+0.8*math.cos(ph), 1.0*math.sin(ph), 0.3*math.sin(ph+1.0))
    # keep within training range
    head=(max(-1.1,min(1.1,head[0])),max(-1.1,min(1.1,head[1])),head[2],head[3])
    K(t,0,head,lt=1 if t>=10.7 else 0)
    t+=0.1
# finale: look to heavens, silence, final slam + quack
K(13.4,0,(0.1,-0.85,0,0)); K(13.9,0,(0.1,-0.85,0,0))
K(14.1,0,(-1.0,1.0,0,0),rt=1); K(14.25,0,(-1.0,1.0,0,0))
out={"timeline_version":1,"duration_s":T,
 "voice":{"pitch":0.0,"brightness":0.3,"buzz":1.0,"vibrato":0.0,"breath":0.8},
 "song":song,"keyframes":kf}
p=os.path.join(os.environ.get("TMPDIR","/tmp"),"talent-acts","death-metal-headbang.json")
json.dump(out,open(p,"w"),indent=1); print(p,len(kf),len(song))
