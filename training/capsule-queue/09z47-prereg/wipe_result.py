"""wipe_result.py: builds the frozen 09z47 result text from the three counted arm JSONs (pre-registered rule, PREREG.md).

usage: python3 wipe_result.py <dir with counted-W1.5.json counted-W3.0.json counted-W4.5.json> <out.txt>
Line 1 is built ONLY from the W3.0 arm (the pre-registered headline). Missing or non-1024 arms are reported as failed,
and the headline is withheld in that case.
"""
import json
import os
import sys

ARMS = [("W1.5", 1.5), ("W3.0", 3.0), ("W4.5", 4.5)]
HEADLINE = "W3.0"
THREE_TURNS_N = 1024


def load(d, tag):
    p = os.path.join(d, f"counted-{tag}.json")
    if not os.path.exists(p):
        return None
    with open(p) as f:
        return json.load(f)


def verdict_words(pct):
    if pct >= 90.0:
        return "mostly stood"
    if pct >= 50.0:
        return "partly held"
    return "mostly fell"


def main():
    d, out = sys.argv[1], sys.argv[2]
    lines = []
    rows = {}
    for tag, w in ARMS:
        r = load(d, tag)
        ok = r is not None and r.get("envs") == THREE_TURNS_N and r.get("standing") is not None
        rows[tag] = (r, ok)
        if not ok:
            lines.append(f"ARM {tag} FAILED (missing or envs != {THREE_TURNS_N})")
            continue
        pct = round(100.0 * r["standing"] / THREE_TURNS_N, 1)
        lines.append(f"ARM {tag} W={w} rad/s: standing {r['standing']}/{THREE_TURNS_N} = {pct}% ({verdict_words(pct)}); "
                     f"contact envs {r['contact_envs']}/{THREE_TURNS_N}, contact steps med {r['contact_steps_med']:.1f} "
                     f"max {r['contact_steps_max']}; z med {r['z_med_mm']} mm (threshold {r['thr_mm']} mm)")
    hr, hok = rows[HEADLINE]
    if hok:
        pct = round(100.0 * hr["standing"] / THREE_TURNS_N, 1)
        line1 = f"1,024 Microducks, one spinning bar: {pct}% still standing after three turns"
        verdict = f"VERDICT (pre-registered): {verdict_words(pct)} at {HEADLINE} ({pct}%)"
    else:
        line1 = "HEADLINE WITHHELD: W3.0 arm missing or invalid"
        verdict = "VERDICT: none (headline arm failed)"
    text = "\n".join([line1, verdict] + lines + [
        "Framing: wipeout is physics. The duck did not learn to dodge. No policy was trained for this item.",
        "Freeze: PREREG.md + FROZEN.sha256 checked at PLAN phase.",
    ]) + "\n"
    with open(out, "w") as f:
        f.write(text)
    print(text)


if __name__ == "__main__":
    main()
