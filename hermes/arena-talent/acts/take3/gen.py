import json
N, MISS, DUR = 8, 5, 15.8
IDLE = [0, 0.3, 0, 0]
UP = [0.3, -0.9, 0, 0]
ev = {i: [] for i in range(N)}
def at(i, t, **u): ev[i].append((round(t, 3), u))
def stand(i, t, hold):
    at(i, t, sit=0, head=UP, rt=1); at(i, t+0.2, rt=0)
    at(i, t+hold, sit=1, head=IDLE)
for i in range(N):
    at(i, 0, sit=1, head=IDLE, rt=0, lt=0)
def wave(start, sp, hold):
    for i in range(N):
        if i != MISS: stand(i, start+sp*i, hold)
wave(1.2, 0.35, 1.1); wave(6.4, 0.35, 1.1); wave(10.2, 0.3, 1.0)
m = MISS
# wave 1: asleep at its turn, stands late and alone
at(m, 2.95, head=[0, 0.9, 0, 0.25])
stand(m, 5.2, 1.0); at(m, 5.6, head=[0.3, -0.5, 0.9, 0]); at(m, 5.9, head=[0.3, -0.5, -0.9, 0])
# wave 2: seated, watches the wave pass, slumps, sad womp
at(m, 8.15, head=[0, 0.3, -0.9, 0]); at(m, 8.5, head=[0, 0.3, 0.9, 0]); at(m, 8.85, head=[0, 0.3, 1.2, 0])
at(m, 9.4, head=[0, 0.9, 0, 0.2])
# wave 3: hyped, misses again, droops, then stands alone after everyone sat
at(m, 11.0, head=[0.3, -0.5, 0, 0]); at(m, 11.7, head=[0.3, -0.5, -0.7, 0])
at(m, 12.0, head=[0.3, -0.5, 0.7, 0]); at(m, 12.3, head=[0, 0.9, 0, 0.2])
at(m, 14.0, sit=0, head=UP, rt=1); at(m, 14.2, rt=0)
at(m, 14.4, lt=1); at(m, 15.2, lt=0, head=[0, 0.0, 0, 0])
for i in range(N):
    if i != m: at(i, 14.2 + 0.05*(i % 3), head=[0, 0.3, 0.9 if i < m else -0.9, 0])
songs = [(9.8, "G3", 0.3), (10.15, "F#3", 0.3), (10.5, "E3", 0.9)]
ducks = []
for i in range(N):
    st = dict(sit=1, head=IDLE, rt=0, lt=0)
    kfs = []; byt = {}
    for t, u in sorted(ev[i], key=lambda e: e[0]): byt.setdefault(t, {}).update(u)
    for t in sorted(byt):
        st.update(byt[t])
        kf = {"t": t, "twist": [st["sit"], 0, 0], "head": st["head"]}
        if st["rt"] or st["lt"]: kf["triggers"] = [st["rt"], st["lt"]]
        kfs.append(kf)
    d = {"policy": "self", "start": {"x": 0, "y": round((i-3.5)*0.35, 3), "yaw": 0},
         "voice": {"pitch": 0.9 if i == m else round(0.2+0.05*i, 2)}, "keyframes": kfs}
    if i == m:
        d["song"] = [{"t": t, "note": n, "for": f, "dynamic": "mp", "vowel": "oh"} for t, n, f in songs]
        d["voice"].update(vibrato=0.6)
    ducks.append(d)
json.dump({"timeline_version": 2, "duration_s": DUR, "ducks": ducks}, open("wobbly-wave.json", "w"), indent=1)
