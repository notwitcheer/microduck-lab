"""rlgl-verdict-2026-11-04.py <out dir> <physics|final> [tag]: the pre-registered render verdict of 09z25 (writes nothing, prints; the item redirects it to the score file).

physics stage: merges the shard trajectories (rlgl_merge.py) and prints the RESULT lines (survivors, eliminated, falls, per-light, counter monotone).
final stage: also checks the render and prints exactly one 'VERDICT:' line.
RENDER OK iff ALL of: merged field n == RLGL_N, counter monotone (merge) AND monotone (render) AND the burnt-in final counter (render 'last=') equals the logged survivors,
  falls <= 10, hero mp4 present at 1920x1080, 25 fps, duration 15-30 s.
The RESULT is the measured survivor count. It is not a pass/fail on the duck.  A survivor-share outside 20-60% is flagged (note only, not a failure).
"""
import os
import re
import subprocess
import sys

out, stage = sys.argv[1], sys.argv[2]
N = int(os.environ.get("RLGL_N", "456"))
P = "/home/witcheer/Pollen/rlgl-item"
PY = "/home/witcheer/Pollen/microduck_rl/.venv/bin/python"
shards = sorted(f for f in os.listdir(out) if re.fullmatch(r"sh\d+\.npz", f))
shards.sort(key=lambda f: int(f[2:-4]))
if not shards:
    print("VERDICT: RENDER FAILED reason=no shard trajectories")
    sys.exit(0)
r = subprocess.run([PY, f"{P}/rlgl_merge.py", f"{out}/traj.npz"] + [f"{out}/{f}" for f in shards], capture_output=True, text=True)
print(r.stdout.strip())
if r.returncode != 0:
    print(r.stderr.strip()[-400:])
    print("VERDICT: RENDER FAILED reason=merge failed")
    sys.exit(0)
m = re.search(r"RESULT field n=(\d+) cycles=(\d+) eliminated_total=(\d+) \(([\d.]+)%\) fell_total=(\d+) survivors=(\d+)", r.stdout)
mono = "counter_monotone=True" in r.stdout
if not m:
    print("VERDICT: RENDER FAILED reason=no RESULT line")
    sys.exit(0)
n, cyc, elim, pct, falls, surv = int(m[1]), int(m[2]), int(m[3]), float(m[4]), int(m[5]), int(m[6])
if stage == "physics":
    print(f"PHYSICS: n={n} survivors={surv} eliminated={elim} falls={falls} monotone={mono}")
    sys.exit(0)
reasons = []
if n != N:
    reasons.append(f"n={n} != {N}")
if not mono:
    reasons.append("merge counter not monotone")
if falls > 10:
    reasons.append(f"falls {falls} > 10")
rl = open(f"{out}/render.log").read() if os.path.exists(f"{out}/render.log") else ""
rm = re.search(r"counter_monotone=(\w+) first=(\d+) last=(\d+)", rl)
cr = re.search(r"alive_crossed_the_line=(\d+)", rl)
if not rm:
    reasons.append("no render summary line")
else:
    if rm[1] != "True":
        reasons.append("render counter not monotone")
    if int(rm[3]) != surv:
        reasons.append(f"burnt-in final counter {rm[3]} != survivors {surv}")
hero = f"{out}/clips/rlgl-hero.mp4"
FF = subprocess.run([PY, "-c", "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"], capture_output=True, text=True).stdout.strip()
if not os.path.exists(hero) or os.path.getsize(hero) < 100000:
    reasons.append("hero mp4 missing")
else:
    info = subprocess.run([FF, "-nostdin", "-i", hero], capture_output=True, text=True, stdin=subprocess.DEVNULL).stderr
    d = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info)
    dur = int(d[1]) * 3600 + int(d[2]) * 60 + float(d[3]) if d else 0.0
    if "1920x1080" not in info:
        reasons.append("not 1920x1080")
    if " 25 fps" not in info:
        reasons.append("not 25 fps")
    if not 15.0 <= dur <= 30.0 and N == 456:
        reasons.append(f"duration {dur:.1f}s outside 15-30")
    print(f"HERO: {hero} {os.path.getsize(hero)} bytes duration={dur:.1f}s")
share = 100.0 * surv / n
note = "" if 20.0 <= share <= 60.0 else f" NOTE=survivor share {share:.0f}% outside 20-60%"
print(f"RESULT: {surv} of {n} still in at the end ({elim} out, {falls} fell, crossed_line={cr[1] if cr else '?'}, lights={cyc}){note}")
if reasons:
    print("VERDICT: RENDER FAILED reason=" + "; ".join(reasons))
else:
    print(f"VERDICT: RENDER OK survivors={surv} of {n} out={elim} falls={falls}")
