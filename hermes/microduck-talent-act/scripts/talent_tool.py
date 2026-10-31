#!/usr/bin/env python3
"""talent_tool.py: check a MicroDuck Got a Talent timeline.json, and play it on the Arena's stage.

  talent_tool.py check FILE.json     schema check (the Arena's own rules, stdlib only) + policy-limit
                                     warnings + an act sheet (what happens when, what is heard)
  talent_tool.py stage FILE.json     check, then play it on the real Arena stage with the policy
                                     (physics on the stage box, about 15 s) and print what the duck did

Exit 0 = valid (warnings allowed), 1 = the Arena would refuse the file.
Rules mirror arena/timeline.py of pollen-robotics/microduck-arena at bbddfe5 (checked against it:
see check-vs-arena notes in the run log). Limits of the policy come from microduck-challenges
got_a_talent/AGENTS.md and from measurements on Pollen's reference policy.
"""
import hashlib, json, math, re, subprocess, sys
from pathlib import Path

CTRL_DT = 0.02
MAX_KEYFRAMES, MAX_VALUE, MAX_NOTES, MAX_DURATION = 1000, 10.0, 1000, 20.0
GROUPS = (("twist", 3), ("head", 4), ("body", 6))
VOICE_KNOBS = ("pitch", "brightness", "buzz", "vibrato", "breath")
DYNAMICS = ("ppp", "pp", "p", "mp", "mf", "f", "ff")
VOWELS = ("ah", "eh", "ee", "oh", "oo", "mm")
NOTE = re.compile(r"([A-Ga-g])([#b]?)(-?\d{1,2})")
STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
STAGE = (2.6, 3.8)            # depth along x, width along y, metres
MARGIN, SPACING, MAX_DUCKS = 0.3, 0.3, 8
HEX_REF = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}")
# what training showed the got-a-talent policy (AGENTS.md of the challenge folder)
HEAD_TRAINED = (1.10, 1.10, 1.40, 0.31)   # neck_pitch, head_pitch, head_yaw, head_roll, rad
HEAD_NAMES = ("neck_pitch", "head_pitch", "head_yaw", "head_roll")
# The Arena's fixed camera cycle for a stage (app/src/talent-stage.js CYCLE at bbddfe5): opening 0-3 s, front 3-7, three-quarter 7-11,
# jury 11-14, low-front 14-18, then the crane holds, on the broadcast clock. The performance's own clock starts 3.5 s in (3 s opening + the
# stage's 0.5 s settle; read off the clip's timer), so the shots in performance seconds are:
CAMERA = (("front", -0.5, 3.5, "close"), ("three-quarter", 3.5, 7.5, "close"), ("jury", 7.5, 10.5, "side, 3.5 m back"),
          ("low-front", 10.5, 14.5, "close"), ("crane", 14.5, 1e9, "wide, 6 to 8 m back"))
def shot_at(t):
    for name, a, b, how in CAMERA:
        if a <= t < b:
            return name, how
    return CAMERA[-1][0], CAMERA[-1][3]
MIN_POSTURE_GAP_S = 1.5       # measured on the reference policy: flips 1.0 s apart mostly work, 0.5 s never sit

class Refused(Exception):
    pass

def num(v, where):
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        raise Refused(f"{where}: expected a number, got {v!r}")
    v = float(v)
    if not math.isfinite(v):
        raise Refused(f"{where}: must be finite")
    return v

def midi_of(name, where):
    m = NOTE.fullmatch(name) if isinstance(name, str) else None
    if not m:
        raise Refused(f"{where}: {name!r} is not a note name (A-G, optional # or b, octave; C4 = middle C)")
    letter, acc, octave = m.groups()
    midi = (int(octave) + 1) * 12 + STEPS[letter.upper()] + {"#": 1, "b": -1, "": 0}[acc]
    if not 36 <= midi <= 96:
        raise Refused(f"{where}: {name!r} is outside C2 to C7")
    return midi

def keyframes(raw, duration, prefix):
    if not isinstance(raw, list) or not 1 <= len(raw) <= MAX_KEYFRAMES:
        raise Refused(f"{prefix}keyframes: expected 1 to {MAX_KEYFRAMES} keyframes in a list")
    out, prev = [], None
    for i, kf in enumerate(raw):
        where = f"{prefix}keyframes[{i}]"
        if not isinstance(kf, dict):
            raise Refused(f"{where}: expected an object")
        unknown = sorted(set(kf) - {"t", "triggers", "twist", "head", "body"})
        if unknown:
            raise Refused(f"{where}: unknown keys {unknown} (allowed: t, twist, head, body, triggers)")
        if "t" not in kf:
            raise Refused(f"{where}: missing 't'")
        t = num(kf["t"], f"{where}.t")
        if prev is None and t != 0.0:
            raise Refused(f"{where}.t: the first keyframe starts at 0.0, got {t}")
        if prev is not None and t <= prev:
            raise Refused(f"{where}.t: {t} does not come after {prev}")
        if t >= duration:
            raise Refused(f"{where}.t: {t} is not before the end of the performance ({duration:g} s)")
        cmd = {}
        for name, width in GROUPS:
            vals = kf.get(name, [0.0] * width)
            if not isinstance(vals, list) or len(vals) != width:
                raise Refused(f"{where}.{name}: expected {width} numbers, got {vals!r}")
            cmd[name] = []
            for j, v in enumerate(vals):
                v = num(v, f"{where}.{name}[{j}]")
                if abs(v) > MAX_VALUE:
                    raise Refused(f"{where}.{name}[{j}]: {v} is outside +-{MAX_VALUE:g}")
                cmd[name].append(v)
        trig = kf.get("triggers", [0.0, 0.0])
        if not isinstance(trig, list) or len(trig) != 2:
            raise Refused(f"{where}.triggers: expected 2 numbers [rt, lt], got {trig!r}")
        trig = [num(v, f"{where}.triggers[{j}]") for j, v in enumerate(trig)]
        if any(not 0.0 <= v <= 1.0 for v in trig):
            raise Refused(f"{where}.triggers: values must be within [0, 1], got {trig}")
        out.append({"t": t, "twist": cmd["twist"], "head": cmd["head"], "body": cmd["body"], "triggers": trig})
        prev = t
    return out

def voice(raw, where):
    if not isinstance(raw, dict):
        raise Refused(f"{where}: expected an object")
    unknown = sorted(set(raw) - set(VOICE_KNOBS))
    if unknown:
        raise Refused(f"{where}: unknown keys {unknown} (allowed: {', '.join(VOICE_KNOBS)})")
    for k, v in raw.items():
        if not 0.0 <= num(v, f"{where}.{k}") <= 1.0:
            raise Refused(f"{where}.{k}: {v} is outside [0, 1]")
    return dict(raw)

def song(raw, duration, where):
    if not isinstance(raw, list) or not 1 <= len(raw) <= MAX_NOTES:
        raise Refused(f"{where}: expected 1 to {MAX_NOTES} notes in a list")
    notes, last_end = [], 0.0
    for i, n in enumerate(raw):
        w = f"{where}[{i}]"
        if not isinstance(n, dict):
            raise Refused(f"{w}: expected an object")
        unknown = sorted(set(n) - {"t", "note", "for", "dynamic", "vowel"})
        if unknown:
            raise Refused(f"{w}: unknown keys {unknown} (allowed: t, note, for, dynamic, vowel)")
        for k in ("t", "note", "for"):
            if k not in n:
                raise Refused(f"{w}: missing {k!r}")
        t, length = num(n["t"], f"{w}.t"), num(n["for"], f"{w}.for")
        if t < 0:
            raise Refused(f"{w}.t: {t} is before the start")
        if length < CTRL_DT - 1e-9:
            raise Refused(f"{w}.for: must be at least {CTRL_DT} s, got {length}")
        if notes and t < last_end - 1e-9:
            raise Refused(f"{w}.t: {t} starts before {where}[{i-1}] ends ({last_end:g}): one voice, one note at a time")
        if t + length > duration + 1e-9:
            raise Refused(f"{w}: ends at {t+length:g}, after the end of the performance ({duration:g} s)")
        dyn, vow = n.get("dynamic", "mf"), n.get("vowel", "ah")
        if dyn not in DYNAMICS:
            raise Refused(f"{w}.dynamic: {dyn!r} is not one of {' '.join(DYNAMICS)}")
        if vow not in VOWELS:
            raise Refused(f"{w}.vowel: {vow!r} is not one of {' '.join(VOWELS)}")
        notes.append({"t": t, "for": length, "note": n["note"], "midi": midi_of(n["note"], f"{w}.note"),
                      "dynamic": dyn, "vowel": vow})
        last_end = t + length
    return notes

def duck_body(raw, duration, prefix):
    kfs = keyframes(raw.get("keyframes"), duration, prefix)
    v = voice(raw["voice"], f"{prefix}voice") if "voice" in raw else {}
    s = song(raw["song"], duration, f"{prefix}song") if "song" in raw else []
    return {"keyframes": kfs, "voice": v, "song": s}

def load(path):
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
    except OSError as exc:
        raise Refused(f"{path}: {exc.strerror or exc}")
    except ValueError as exc:
        raise Refused(f"{Path(path).name}: not a JSON file ({exc})")
    if not isinstance(raw, dict):
        raise Refused("expected a JSON object at the top level")
    ver = raw.get("timeline_version")
    if isinstance(ver, bool) or ver not in (1, 2):
        raise Refused(f"timeline_version: this Arena plays version 1 or 2, got {ver!r}")
    top = ("timeline_version", "duration_s", "keyframes") if ver == 1 else ("timeline_version", "duration_s", "ducks")
    extra = ("voice", "song") if ver == 1 else ()
    unknown = sorted(set(raw) - set(top) - set(extra))
    if unknown:
        raise Refused(f"top level: unknown keys {unknown}")
    for k in top:
        if k not in raw:
            raise Refused(f"top level: missing {k!r}")
    dur = num(raw["duration_s"], "duration_s")
    if dur < CTRL_DT:
        raise Refused(f"duration_s: must be at least {CTRL_DT}")
    if dur > MAX_DURATION:
        raise Refused(f"duration_s: {dur:g} s is longer than this event's {MAX_DURATION:g} s")
    if ver == 1:
        return ver, dur, [{"policy": "self", "start": (0.0, 0.0, 0.0), **duck_body(raw, dur, "")}]
    ducks = raw["ducks"]
    if not isinstance(ducks, list) or not 1 <= len(ducks) <= MAX_DUCKS:
        raise Refused(f"ducks: expected 1 to {MAX_DUCKS} ducks in a list")
    out = []
    for i, d in enumerate(ducks):
        w = f"ducks[{i}]"
        if not isinstance(d, dict):
            raise Refused(f"{w}: expected an object")
        unknown = sorted(set(d) - {"policy", "start", "keyframes", "voice", "song"})
        if unknown:
            raise Refused(f"{w}: unknown keys {unknown}")
        for k in ("policy", "keyframes"):
            if k not in d:
                raise Refused(f"{w}: missing {k!r}")
        pol = d["policy"]
        if i == 0 and pol != "self":
            raise Refused(f'{w}.policy: the first duck is the entry\'s own policy: "self"')
        if i > 0 and not (pol == "self" or (isinstance(pol, str) and HEX_REF.fullmatch(pol))):
            raise Refused(f'{w}.policy: must be "self" or owner/repo@<40-hex commit>, got {pol!r}')
        st = d.get("start", {})
        if not isinstance(st, dict) or set(st) - {"x", "y", "yaw"}:
            raise Refused(f"{w}.start: expected an object with x, y, yaw")
        x, y, yaw = (num(st.get(k, 0.0), f"{w}.start.{k}") for k in ("x", "y", "yaw"))
        if abs(yaw) > 180:
            raise Refused(f"{w}.start.yaw: {yaw:g} is outside +-180 degrees")
        if abs(x) > STAGE[0] / 2 - MARGIN + 1e-9 or abs(y) > STAGE[1] / 2 - MARGIN + 1e-9:
            raise Refused(f"{w}.start: off the stage (|x| <= {STAGE[0]/2-MARGIN:g}, |y| <= {STAGE[1]/2-MARGIN:g} m)")
        for j, o in enumerate(out):
            if math.hypot(x - o["start"][0], y - o["start"][1]) < SPACING - 1e-9:
                raise Refused(f"{w}.start: closer than {SPACING:g} m to ducks[{j}]")
        out.append({"policy": pol, "start": (x, y, yaw), **duck_body(d, dur, f"{w}.")})
    return ver, dur, out

def sound_events(duck, dur):
    """What is heard: quacks (RT crossing 0.3 upward), wheee spans (LT >= 0.3), notes. Silent pulls flagged."""
    ev, warn = [], []
    notes = duck["song"]
    def singing(t):
        return any(n["t"] <= t < n["t"] + n["for"] for n in notes)
    rt_prev, lt_on = 0.0, None
    kfs = duck["keyframes"]
    for k, kf in enumerate(kfs):
        t = kf["t"]; rt, lt = kf["triggers"]
        if rt >= 0.3 and rt_prev < 0.3:
            if singing(t):
                warn.append(f"t={t:g}: RT quack while a song note sounds: the beak opens, no quack is heard")
            elif lt_on is not None:
                warn.append(f"t={t:g}: RT quack during a wheee is not heard")
            else:
                ev.append((t, f"quack (RT {rt:g})", t))
        elif rt >= 0.3 and rt_prev >= 0.3:
            warn.append(f"t={t:g}: RT still held from the previous keyframe: no new quack (release it first, below 0.3)")
        rt_prev = rt
        if lt >= 0.3 and lt_on is None:
            lt_on = t
        elif lt < 0.3 and lt_on is not None:
            ev.append((lt_on, f"wheee until t={t:g}", t)); lt_on = None
    if lt_on is not None:
        ev.append((lt_on, f"wheee until the end ({dur:g})", dur))
    for n in notes:
        ev.append((n["t"], f"note {n['note']} {n['for']:g}s {n['dynamic']} on '{n['vowel']}'", n["t"] + n["for"]))
    return sorted(ev), warn

def policy_warnings(duck, dur):
    w, kfs = [], duck["keyframes"]
    prev_flag, last_flip = None, None
    for k, kf in enumerate(kfs):
        t = kf["t"]; flag = kf["twist"][0]
        if flag not in (0.0, 1.0):
            w.append(f"t={t:g}: sit flag {flag:g}: training only saw exactly 0 or 1 (0.5 was measured: the duck stays standing)")
        if kf["twist"][1] or kf["twist"][2] or any(kf["body"]):
            w.append(f"t={t:g}: twist[1], twist[2] and body are unused by this policy: they do nothing")
        if prev_flag is not None and flag != prev_flag:
            if last_flip is not None and t - last_flip < MIN_POSTURE_GAP_S:
                w.append(f"t={t:g}: posture flips {t-last_flip:.2f} s after the last one: under {MIN_POSTURE_GAP_S} s the duck may not complete the sit or the stand")
            last_flip = t
        prev_flag = flag
        for i, (v, lim) in enumerate(zip(kf["head"], HEAD_TRAINED)):
            if abs(v) > lim + 1e-9:
                w.append(f"t={t:g}: {HEAD_NAMES[i]} {v:g} rad is beyond what training saw (+-{lim:g}); the joint may not follow")
    flag0 = kfs[0]["twist"][0]
    for kf in kfs[1:]:
        if kf["t"] >= 14.5 and kf["twist"][0] != flag0:
            w.append(f"t={kf['t']:g}: posture flips in the wide crane shot (camera 6 to 8 m back, the duck is tiny): the picture is lost unless the sound carries it; move the big sit or stand into 10.5 to 14.5 s")
        flag0 = kf["twist"][0]
    ends = [kf["t"] for kf in kfs[1:]] + [dur]
    if kfs[0]["t"] == 0.0 and len(kfs) > 1 and kfs[1]["t"] < 0.5:
        w.append("the first keyframe lasts under 0.5 s: the stage settles the duck for 0.5 s, make the opening hold longer")
    return w

def act_sheet(ver, dur, ducks):
    lines = [f"timeline_version {ver}, {dur:g} s, {len(ducks)} duck(s)"]
    for n, d in enumerate(ducks):
        kfs = d["keyframes"]
        lines.append(f"duck {n} ({d['policy']}) start x={d['start'][0]:g} y={d['start'][1]:g} yaw={d['start'][2]:g}: {len(kfs)} keyframes, {len(d['song'])} notes, voice {d['voice'] or 'default'}")
        flag, steps = 0.0, []
        for kf in kfs:
            if kf["twist"][0] != flag or kf is kfs[0]:
                steps.append(f"t={kf['t']:g} {'SIT' if kf['twist'][0] >= 0.5 else 'STAND'}")
                flag = kf["twist"][0]
        lines.append("  posture: " + ", ".join(steps))
        ev, warn = sound_events(d, dur)
        for t, text, end in ev:
            shots = []
            for name, a, b, how in CAMERA:
                if t < b and max(end, t + 1e-6) > a and name not in shots:
                    shots.append(name)
            far = [n for n in shots if n in ("jury", "crane")]
            tag = " -> ".join(shots) + (f"  (partly in {'/'.join(far)}: small on screen)" if far and end - t >= 0.8 else "")
            lines.append(f"  t={t:5.2f}  {text:44s} [{tag}]")
        d["_warn"] = warn
    return lines

def cmd_check(path):
    try:
        ver, dur, ducks = load(path)
    except Refused as exc:
        print(f"REFUSED: {exc}")
        return 1
    for line in act_sheet(ver, dur, ducks):
        print(line)
    print("camera (fixed by the Arena): close 0 to 7.5 s and 10.5 to 14.5 s; side view 7.5 to 10.5 s; wide crane from 14.5 s to the end")
    warns = []
    for n, d in enumerate(ducks):
        pre = f"duck {n}: " if len(ducks) > 1 else ""
        warns += [pre + x for x in d["_warn"]]
        if d["policy"] == "self" or n == 0:
            warns += [pre + x for x in policy_warnings(d, dur)]
    if dur > 14.6:
        warns.append(f"duration_s {dur:g}: the last {dur-14.5:.1f} s are filmed from the wide crane shot (the duck is a few pixels tall); ending near 14.4 s keeps the whole act in the close shots")
    sung = sum(1 for d in ducks if d["song"])
    if sung > 1:
        warns.append("two or more ducks sing: they sing as a choir chord, vibrato/buzz/breath are heard much less")
    for x in warns:
        print("WARNING:", x)
    print(f"VALID by the Arena's rules; {len(warns)} warning(s)")
    return 0

import os
STAGE_HOST = os.environ.get("TALENT_STAGE_HOST", "")      # ssh host that runs the Arena stage (see hermes/arena-talent/README.md)
STAGE_DIR = os.environ.get("TALENT_STAGE_DIR", "$HOME/arena-talent")
STAGE_CMD = ("export PATH=$HOME/.local/bin:$PATH; cd " + STAGE_DIR + "/microduck-challenges && "
             "uv run --group workshop python ../talent_stage_report.py {policy} {remote} 2>&1 | grep -v '^\\[mdp\\]'")

def cmd_stage(path, policy="reference"):
    rc = cmd_check(path)
    if rc:
        return rc
    if not STAGE_HOST:
        print("stage: set TALENT_STAGE_HOST to the ssh host that runs the Arena stage (hermes/arena-talent/README.md)")
        return 2
    remote = f"{STAGE_DIR}/hermes-runs/{Path(path).stem}-{hashlib.md5(Path(path).read_bytes()).hexdigest()[:8]}.json"
    subprocess.run(["ssh", STAGE_HOST, f"mkdir -p {STAGE_DIR}/hermes-runs"], check=True)
    subprocess.run(["ssh", STAGE_HOST, f"cat > {remote}"], input=Path(path).read_bytes(), check=True)
    pol = {"reference": "logs/reference/got-a-talent/policy.onnx"}.get(policy, policy)
    print("--- stage (the Arena's own physics, the policy named below, one start) ---")
    out = subprocess.run(["ssh", STAGE_HOST, STAGE_CMD.format(policy=pol, remote=remote)], capture_output=True, text=True)
    print(out.stdout.strip() or out.stderr.strip())
    return 0

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("check", "stage"):
        print(__doc__); sys.exit(2)
    sys.exit(cmd_check(sys.argv[2]) if sys.argv[1] == "check" else cmd_stage(sys.argv[2], *(sys.argv[3:4])))
