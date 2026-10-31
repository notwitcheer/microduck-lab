
import json, sys
from pathlib import Path
import numpy as np
from arena.constants import CTRL_DT, DEFAULT_POSE, JOINT_NAMES
from arena.cast import cast_of
from arena.evaluate import evaluate
from arena.manifest import load_event
from arena.policy import load_policy
from arena.timeline import Timeline, solo
event = load_event("got-a-talent"); policy = load_policy(Path(sys.argv[1]))
HEAD = [JOINT_NAMES.index(n) for n in ("neck_pitch", "head_pitch", "head_yaw", "head_roll")]
names = ("neck_pitch", "head_pitch", "head_yaw", "head_roll")
vals = [0.0, 0.3, 0.6, 0.9, 1.2, 1.5, 2.0, -0.3, -0.6, -0.9, -1.2, -1.5, -2.0]
res = {}
for posture in (0, 1):
    for j, nm in enumerate(names):
        times, cmds = [0.0], [(float(posture),0,0,0,0,0,0,0,0,0,0,0,0)]
        t = 1.5
        for v in vals:
            h = [0.0]*4; h[j] = v
            times.append(t); cmds.append((float(posture),0,0, *h, 0,0,0,0,0,0)); t += 1.4
        dur = min(t, 20.0)
        # chunks of at most 13 values per 20 s: fits (13*1.4+1.5=19.7)
        tl = Timeline(dur, tuple(times), tuple(cmds), tuple((0.0,0.0) for _ in times))
        r = evaluate(event, policy, cast_of(event, solo(tl), policy, None, {}).performers)
        tr = r.trace[0]
        out = []
        for k, v in enumerate(vals):
            a = round((times[k+1] + 1.0) / CTRL_DT); b = round((times[k+1] + 1.4) / CTRL_DT)
            ang = tr[a:b][:, 7 + HEAD[j]].mean() - DEFAULT_POSE[HEAD[j]]
            out.append((v, round(float(ang), 2)))
        res[f"{'sit' if posture else 'stand'}:{nm}"] = out
for k, v in res.items():
    print(k, " ".join(f"{c:+.1f}->{a:+.2f}" for c, a in v))
