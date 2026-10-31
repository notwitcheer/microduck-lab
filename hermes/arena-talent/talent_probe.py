
"""talent_probe.py: play timelines on the Arena's got-a-talent stage with one policy, report what the
policy actually did (run inside microduck-challenges: uv run --group workshop python talent_probe.py ...).

usage: talent_probe.py POLICY.onnx TIMELINE.json [TIMELINE.json ...] [--json OUT]
Per timeline: fell_at, seated_s, standing_s, per flag segment the posture reach time and whether it held,
per keyframe the head error over the last 40 percent of the hold (min 0.2 s) in rad, and a one-line verdict.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
from arena import stage
from arena.constants import CTRL_DT, DEFAULT_POSE, JOINT_NAMES
from arena.cast import cast_of
from arena.evaluate import evaluate
from arena.manifest import load_event
from arena.policy import load_policy
from arena.timeline import load_troupe, solo

HEAD = [JOINT_NAMES.index(n) for n in ("neck_pitch", "head_pitch", "head_yaw", "head_roll")]

def play(event, policy, path):
    tl = load_troupe(Path(path), event, allow_local=True).ducks[0].timeline
    res = evaluate(event, policy, cast_of(event, solo(tl), policy, None, {}).performers)
    return tl, res.trace[0]

def metrics(event, tl, trace):
    seated, standing = stage.seated(trace), stage.standing(trace)
    fell = stage.fell_at(trace, event.termination)
    ends = list(tl.times[1:]) + [tl.duration_s]
    segs = []
    prev = None
    for t, c, e in zip(tl.times, tl.commands, ends):
        sit = c[0] >= 0.5
        if prev is None or prev["sit"] != sit:
            if prev: prev["end"] = t
            prev = {"start": t, "end": tl.duration_s, "sit": sit}
            segs.append(prev)
    for s in segs:
        a, b = round(s["start"] / CTRL_DT), round(s["end"] / CTRL_DT)
        w = (seated if s["sit"] else standing)[a:b]
        if w.any():
            f = int(np.argmax(w)); s["reach_s"] = round(f * CTRL_DT, 2); s["held"] = bool(w[f:].all())
        else:
            s["reach_s"] = None; s["held"] = False
    heads = []
    for t, c, e in zip(tl.times, tl.commands, ends):
        n = max(int(round((e - t) * 0.4 / CTRL_DT)), 10)
        b = round(e / CTRL_DT); a = max(b - n, round(t / CTRL_DT))
        ang = trace[a:b][:, [7 + j for j in HEAD]]
        if len(ang):
            err = float(np.abs(ang.mean(axis=0) - (DEFAULT_POSE[HEAD] + np.asarray(c[3:7]))).max())
        else:
            err = None
        heads.append({"t": t, "hold_s": round(e - t, 2), "head_err": None if err is None else round(err, 3)})
    errs = [h["head_err"] for h in heads if h["head_err"] is not None and h["hold_s"] >= 0.4]
    return {"fell_at": fell, "seated_s": round(float(seated.sum() * CTRL_DT), 2),
            "standing_s": round(float(standing.sum() * CTRL_DT), 2), "segments": segs, "heads": heads,
            "max_head_err": max(errs) if errs else None,
            "min_z": round(float(trace[:, 2].min()), 3), "max_tilt_deg": round(float(stage.tilt_deg(trace).max()), 1)}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("onnx"); ap.add_argument("timelines", nargs="+")
    ap.add_argument("--json"); a = ap.parse_args()
    event = load_event("got-a-talent"); policy = load_policy(Path(a.onnx)); out = {}
    for p in a.timelines:
        try:
            tl, trace = play(event, policy, p); m = metrics(event, tl, trace)
        except Exception as exc:
            m = {"error": str(exc)}
        out[Path(p).name] = m
        if "error" in m: print(f"{Path(p).name}: ERROR {m['error']}"); continue
        late = [s for s in m["segments"] if s["reach_s"] is None or not s["held"]]
        print(f"{Path(p).name}: fell={m['fell_at']} seated={m['seated_s']}s standing={m['standing_s']}s "
              f"segments={len(m['segments'])} unreached/unheld={len(late)} max_head_err={m['max_head_err']} "
              f"max_tilt={m['max_tilt_deg']} min_z={m['min_z']}")
    if a.json: Path(a.json).write_text(json.dumps(out, indent=1))
main()
