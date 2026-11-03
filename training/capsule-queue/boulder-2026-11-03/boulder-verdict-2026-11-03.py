#!/usr/bin/env python3
"""boulder-verdict-2026-11-03.py <batch dir> : apply the pre-registered boulder-chase rule to the batch logs and print VERDICT.

batch dir holds boulder_play.py logs named  A-s<seed>.log  (no reflex, the 'before')  and  B-s<seed>.log  (the Hermes-written reflex), plus
C.log (no-boulder control, same 16-env CPU harness, for Z_STAND). each RESULT line counts takes where the boulder never touched the duck,
the duck stayed upright (tilt <= 60 deg), kept a normal walking height (median trunk z >= 0.9 x Z_STAND AND <= 10% of steps under 0.8 x Z_STAND
after the 0.5 s settle) and the boulder rolled past.

PRE-REGISTERED (written 2026-11-03 before any item take): GAIN iff  B_success >= 40 of 48  AND  A_success <= 8 of 48  AND  one-sided Fisher p < 0.001
AND the control batch has 16 of 16 tall. otherwise NO GAIN (and the clip is the hero take only, never a before/after).
"""
import glob
import math
import os
import re
import sys

d = sys.argv[1]


def read(pattern):
    n = s = 0
    seeds = []
    for f in sorted(glob.glob(os.path.join(d, pattern))):
        txt = open(f, errors="replace").read()
        m = re.search(r"RESULT touched=(\d+)/(\d+) up\(tilt<=60\)=(\d+)/\d+ tall=(\d+)/\d+ passed=(\d+)/\d+ SUCCESS\(clean\+up\+tall\+passed\)=(\d+)/(\d+)", txt)
        if not m or "[boulder] done" not in txt:
            print(f"[verdict] {os.path.basename(f)}: not finished / no RESULT line")
            continue
        n += int(m.group(7))
        s += int(m.group(6))
        seeds.append((os.path.basename(f), int(m.group(6)), int(m.group(7)), int(m.group(1))))
    return s, n, seeds


def fisher_greater(a, n1, b, n2):
    """one-sided p that group 1 (a/n1) has a higher rate than group 2 (b/n2): hypergeometric tail."""
    k = a + b
    tot = n1 + n2
    p = 0.0
    for x in range(a, min(n1, k) + 1):
        p += math.comb(n1, x) * math.comb(n2, k - x) / math.comb(tot, k)
    return p


bs, bn, bseeds = read("B-s*.log")
as_, an, aseeds = read("A-s*.log")
ctl = glob.glob(os.path.join(d, "C.log"))
ctl_tall = ctl_n = 0
if ctl:
    txt = open(ctl[0], errors="replace").read()
    m = re.search(r"RESULT touched=\d+/(\d+) up\(tilt<=60\)=\d+/\d+ tall=(\d+)/", txt)
    if m:
        ctl_n, ctl_tall = int(m.group(1)), int(m.group(2))
for nm, s_, n_, t_ in [(a, b, c, e) for a, b, c, e in aseeds]:
    print(f"[verdict] A {nm}: success {s_}/{n_}, touched {t_}")
for nm, s_, n_, t_ in [(a, b, c, e) for a, b, c, e in bseeds]:
    print(f"[verdict] B {nm}: success {s_}/{n_}, touched {t_}")
print(f"[verdict] control (no boulder): tall {ctl_tall}/{ctl_n}")
p = fisher_greater(bs, bn, as_, an) if bn and an else float("nan")
print(f"A (no reflex): {as_}/{an}   B (Hermes reflex): {bs}/{bn}   one-sided Fisher p = {p:.2e}")
ok = bn == 48 and an == 48 and bs >= 40 and as_ <= 8 and p < 0.001 and ctl_n == 16 and ctl_tall == 16
print(f"VERDICT: {'GAIN' if ok else 'NO GAIN'}")
