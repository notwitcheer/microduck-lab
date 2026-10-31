
import sys, numpy as np
from pathlib import Path
from arena.constants import CTRL_DT, DEFAULT_POSE, JOINT_NAMES
from arena.cast import cast_of
from arena.evaluate import evaluate
from arena.manifest import load_event
from arena.policy import load_policy
from arena.timeline import load_troupe
ev = load_event("got-a-talent"); pol = load_policy(Path(sys.argv[1]))
tr = load_troupe(Path(sys.argv[2]), ev)
res = evaluate(ev, pol, cast_of(ev, tr, pol, None, {}).performers).trace[0]
H = {n: JOINT_NAMES.index(n) for n in ("neck_pitch","head_pitch","head_yaw","head_roll")}
for a, b in [(float(x), float(y)) for x, y in (w.split("-") for w in sys.argv[3:])]:
    seg = res[round(a/CTRL_DT):round(b/CTRL_DT)]
    out = []
    for n, j in H.items():
        ang = seg[:, 7 + j] - DEFAULT_POSE[j]
        # peak-to-peak and number of direction reversals larger than 0.15 rad
        d = np.diff(ang); sg = np.sign(d[np.abs(d) > 1e-3])
        rev = int((np.diff(sg) != 0).sum()) if len(sg) > 1 else 0
        out.append(f"{n} p2p {ang.max()-ang.min():.2f} rad, {rev} reversals")
    print(f"perf {a}-{b} s: " + "; ".join(out))
