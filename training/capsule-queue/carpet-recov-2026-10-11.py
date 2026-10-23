import re, glob, os, sys, math
d = sys.argv[1]
pat = re.compile(r"t=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*(-?[\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)")
for f in sorted(glob.glob(os.path.join(d, "*-t*.full.log"))):
    name = os.path.basename(f)[:-9]
    if "carpet-t" in name and not name.startswith("carpet-"):
        continue
    s = [(float(m[1]), float(m[2]), float(m[5])) for m in map(pat.search, open(f, errors="replace")) if m and float(m[1]) < 11.95]
    if not s:
        continue
    resets = [l.split("t=")[1].split("s")[0].strip() for l in open(f, errors="replace") if "RESET at" in l]
    state = "up" if s[0][2] < -0.9 and s[0][1] > 100 else "down"
    falls = rec = 0; down_t = 0.0 if state == "down" else None; times = []; up_s = 0.0
    prev = s[0][0]
    for t, z, gz in s:
        dt = t - prev; prev = t
        if state == "up":
            up_s += dt
        tilt = math.degrees(math.acos(max(-1, min(1, -gz))))
        if state == "up" and tilt > 60:
            state = "down"; falls += 1; down_t = t
        elif state == "down" and gz < -0.9 and z > 100:
            state = "up"; rec += 1; times.append(round(t - down_t, 1))
    start = "start-down" if s[0][2] > -0.9 else "start-up"
    print(f"{name:22s} {start:10s} falls={falls} rises={rec} rise_s={times} upright_frac={up_s/s[-1][0]:.2f} end={state} last_down_at={down_t} resets={resets}")
