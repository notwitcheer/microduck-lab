
"""talent_stage_report.py POLICY.onnx TIMELINE.json [...] [--json OUT]
Plays a timeline (version 1 or a troupe whose ducks are all "self") on the Arena's got-a-talent stage with
the policy, as arena.evaluate does for an entry, and prints what each duck did in plain words.
Run inside microduck-challenges: uv run --group workshop python ../talent_stage_report.py ...
"""
import argparse, json
from pathlib import Path
import numpy as np
from arena import stage
from arena.constants import CTRL_DT, DEFAULT_POSE, JOINT_NAMES
from arena.cast import cast_of
from arena.evaluate import evaluate
from arena.manifest import load_event
from arena.policy import load_policy
from arena.timeline import load_troupe, SELF

HEAD = [JOINT_NAMES.index(n) for n in ("neck_pitch", "head_pitch", "head_yaw", "head_roll")]
HEAD_NAMES = ("neck_pitch", "head_pitch", "head_yaw", "head_roll")

def duck_metrics(event, tl, trace):
    seated, standing = stage.seated(trace), stage.standing(trace)
    ends = list(tl.times[1:]) + [tl.duration_s]
    segs, prev = [], None
    for t, c in zip(tl.times, tl.commands):
        sit = c[0] >= 0.5
        if prev is None or prev["sit"] != sit:
            if prev: prev["end"] = t
            prev = {"start": t, "end": tl.duration_s, "sit": sit}; segs.append(prev)
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
        if len(ang) and e - t >= 0.4:
            d = np.abs(ang.mean(axis=0) - (DEFAULT_POSE[HEAD] + np.asarray(c[3:7])))
            heads.append({"t": t, "hold_s": round(e - t, 2), "err": round(float(d.max()), 3), "joint": HEAD_NAMES[int(d.argmax())],
                          "cmd": [round(x, 2) for x in c[3:7]]})
    return {"fell_at": stage.fell_at(trace, event.termination), "seated_s": round(float(seated.sum() * CTRL_DT), 2),
            "standing_s": round(float(standing.sum() * CTRL_DT), 2), "segments": segs, "heads": heads,
            "max_tilt_deg": round(float(stage.tilt_deg(trace).max()), 1),
            "final_xy_m": [round(float(trace[-1, 0]), 2), round(float(trace[-1, 1]), 2)]}

def report(name, m, tl):
    print(f"[{name}] played {tl.duration_s:g} s; fell: {'no' if m['fell_at'] is None else 'at %.2f s' % m['fell_at']}; "
          f"seated {m['seated_s']} s, standing {m['standing_s']} s, worst tilt {m['max_tilt_deg']} deg, ended at x={m['final_xy_m'][0]} y={m['final_xy_m'][1]} m")
    bad = 0
    slow = 0
    for s in m["segments"]:
        want = "SIT" if s["sit"] else "STAND"
        if s["reach_s"] is None:
            bad += 1; print(f"  t={s['start']:5.2f}-{s['end']:5.2f} {want}: NOT REACHED")
        else:
            flag = "" if s["held"] and s["reach_s"] <= 1.5 else "  <-- slow or not held"
            bad += bool(flag)
            slow += bool(flag)
            print(f"  t={s['start']:5.2f}-{s['end']:5.2f} {want}: reached after {s['reach_s']:.2f} s, {'held' if s['held'] else 'LEFT before the segment ended'}{flag}")
    worst = [h for h in m["heads"] if h["err"] > 0.25]
    for h in m["heads"]:
        mark = "  <-- off" if h["err"] > 0.25 else ""
        print(f"  head t={h['t']:5.2f} (hold {h['hold_s']} s) command {h['cmd']}: worst joint {h['joint']} off by {h['err']} rad{mark}")
    verdict = "ALL MOVES LANDED" if bad == 0 and not worst and m["fell_at"] is None else \
        f"PROBLEMS: {bad} posture segment(s), {len(worst)} head hold(s) off by more than 0.25 rad{', a fall' if m['fell_at'] is not None else ''}"
    print(f"  => {verdict}")
    return {"posture_problems": bad, "head_off": len(worst), "fell": m["fell_at"] is not None,
            "total": bad + len(worst) + (1 if m["fell_at"] is not None else 0)}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("onnx"); ap.add_argument("timelines", nargs="+"); ap.add_argument("--json")
    a = ap.parse_args()
    event = load_event("got-a-talent"); policy = load_policy(Path(a.onnx)); out = {}
    for p in a.timelines:
        try:
            troupe = load_troupe(Path(p), event, allow_local=True)
            if any(d.policy != SELF for d in troupe.ducks):
                print(f"{Path(p).name}: borrowed ducks are not played by this report (self ducks only)"); continue
            res = evaluate(event, policy, cast_of(event, troupe, policy, None, {}).performers)
            summ = []
            for i, d in enumerate(troupe.ducks):
                m = duck_metrics(event, d.timeline, res.trace[i])
                prob = report(f"duck {i}" if len(troupe.ducks) > 1 else "star", m, d.timeline)
                out.setdefault(Path(p).name, []).append({"problems": prob, **m})
        except Exception as exc:
            print(f"{Path(p).name}: ERROR {exc}")
    if a.json: Path(a.json).write_text(json.dumps(out, indent=1))
main()
