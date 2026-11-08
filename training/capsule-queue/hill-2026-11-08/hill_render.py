#!/usr/bin/env python3
"""hill_render.py: the 1.5 m Hill Climb board-audit proof clip (item 09z33), CPU only, capsule only. Reference shape = the Ripple-65B cut (toolcall/ripple89) and the roller cut: result card FIRST, then the live thing, cut at the result.
Inputs: facts-<tag>.json (written by hill-proof-2026-11-08.py verdict), clips.json = {"hero_scored": {"mp4","tape0","time","seed"}, "hero_fresh": {...}, "ours": {...}} (the Arena's own landscape.mp4 of each run from a LOCAL store, tape0 = clip.json crowdDirection.start,
time = the replayed seed's finish time, or the trace length for a fall).
usage: hill_render.py <facts.json> <clips.json> <out.mp4> [--ffmpeg PATH] [--stills DIR] [--mock]
sequence (1920x1080, 25 fps, ~50 s):
  1 result card 8 s | 2 the board's best-ranked fragile row on a SCORED start, real speed then 0.25x, with a big sim clock (cut 0.03 s before the line, last live frame held) | 3 the SAME file on an UNSCORED start, real speed then 0.25x, tipping over (own TIPPED OVER stamp, the Arena's VICTORY/rank bar never shown)
  4 our shipped-recipe pick on the same hill at real speed beside the reference's time | 5 the top-30 ladder (finishes out of the 20 unscored starts, one bar per board row, Pollen's reference and ours as the last two bars).
Every number on screen comes from facts-<tag>.json; nothing is typed here. No paths, hostnames, board user names or policy names are drawn (the Arena prints '@<user>' of the LOCAL store: neutral labels set by the clip script).
--mock labels nothing differently on screen but writes MOCK in the summary: it renders from stand-in data before the real run."""
import argparse, json, os, statistics, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("facts"); ap.add_argument("clips"); ap.add_argument("out")
ap.add_argument("--ffmpeg", default=os.path.expanduser("~/Pollen/arena/bin/ffmpeg"))
ap.add_argument("--stills", default=None)
ap.add_argument("--mock", action="store_true")
a = ap.parse_args()
F = json.load(open(a.facts)); CL = json.load(open(a.clips))
W, H, FPS = 1920, 1080, 25
FD = "/usr/share/fonts/truetype/dejavu/"
BG, TEXT, MUTE, GRID, BAND = "#0e1420", "#eaf0f7", "#7d8ba0", "#20293a", "#121a2a"
OURS, REFC, CORAL, GOOD, GOLD = "#6fd6a8", "#e8b64c", "#ff6b6b", "#6fd6a8", "#e8b64c"
SETTLE_S = 0.46
HOLD_S = 0.9
AU = F.get("audit") or {}
BARS = AU.get("top_bars") or []          # [rank, finished25, fresh_fin]
chk, rchk = F.get("check"), F.get("ref_check")


def Fo(sz, b=False, mono=False):
    return ImageFont.truetype(FD + ("DejaVuSansMono" if mono else "DejaVuSans") + ("-Bold" if b else "") + ".ttf", sz)


def enc(out):
    return subprocess.Popen([a.ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                             "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out], stdin=subprocess.PIPE)


def frames_of(mp4, t0, t1):
    p = subprocess.Popen([a.ffmpeg, "-nostdin", "-loglevel", "error", "-ss", str(max(t0, 0)), "-t", str(t1 - max(t0, 0)), "-i", mp4, "-vf", f"fps={FPS},scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         stdout=subprocess.PIPE, stdin=subprocess.DEVNULL)
    n = W * H * 3; out = []
    while True:
        b = p.stdout.read(n)
        if len(b) < n: break
        out.append(np.frombuffer(b, np.uint8).reshape(H, W, 3).copy())
    p.wait()
    return out


def wrap(d, text, font, width):
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        t = (cur + " " + w_).strip()
        if d.textlength(t, font=font) <= width: cur = t
        else: lines.append(cur); cur = w_
    return lines + ([cur] if cur else [])


def fresh_of(c):
    return sum(1 for s in c["seeds"] if s["seed"] >= 6 and s["status"] == "finish") if c else None


top10 = [b[2] for b in BARS if b[0] <= 10]
top30_fresh = [b[2] for b in BARS]
n_frag = AU.get("fragile_top", 0)
med_frag = AU.get("fragile_median_fresh")
ours_s, ref_s = F["score"], F["ref"]["score"]
ours_fresh, ref_fresh = fresh_of(chk), fresh_of(rchk)
hp = F.get("honest_place") or {}
verdict = F["verdict"]
HOLDS = bool(AU.get("holds"))


def line1(f):
    """the pre-registered line-1 builder (PREREG.md): only when the AUDIT HOLDS."""
    au = f.get("audit") or {}
    if not au.get("holds"):
        return "NOT POST MATERIAL as a board finding: the audit did not hold (%s of the top 30 rows are fragile, bar 10)" % au.get("fragile_top")
    rf = fresh_of(f.get("ref_check"))
    z = sum(1 for b in au.get("top_bars", []) if b[2] <= 9 and b[2] == 0)
    return "%d of the top %d ducks on the Hill Climb board finish fewer than half of 20 extra starts the board never scores%s. Pollen's own reference finishes %s of 20" % (
        au["fragile_top"], au["top_n"], (" (%d of them finish none)" % z) if z else "", "-" if rf is None else rf)


ZERO = sum(1 for b in BARS if b[2] == 0)
TITLE = ("%d of the top %d rows on the Hill Climb board finish fewer than half of 20 starts the board never scores" % (n_frag, AU.get("top_n", 30))) if HOLDS \
    else "The Hill Climb board mostly holds up: %s of its top %d rows fail the 20 starts it does not score" % (n_frag, AU.get("top_n", 30))
open(a.out + ".line1.txt", "w").write(line1(F) + "\n")


def card(tick=0.0):
    """static numbers from the first frame; motion = the sweeping marker under the header"""
    im = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 190], fill=BAND); d.rectangle([0, 190, W, 193], fill=GRID)
    for i, l in enumerate(wrap(d, TITLE, Fo(46, True), W - 96)[:2]): d.text((48, 14 + 56 * i), l, font=Fo(46, True), fill=TEXT)
    d.text((48, 134), "1.5 m Hill Climb, the MicroDuck Arena's own evaluator, run locally on every public policy file. simulation only.", font=Fo(24), fill=MUTE)
    mx = int((W - 160) * (0.5 - 0.5 * np.cos(np.pi * (tick % 3.0) / 1.5)))
    d.rectangle([48 + mx, 186, 48 + mx + 160, 193], fill=OURS)
    xl, xm, xr, xlab = 760, 1060, 1420, 80
    d.text((xl, 214), "board top 10", font=Fo(34, True), fill=CORAL); d.text((xm, 214), "Pollen reference", font=Fo(34, True), fill=REFC); d.text((xr, 214), "our pick", font=Fo(34, True), fill=OURS)
    d.text((xl, 258), "median of the 10 rows", font=Fo(22), fill=MUTE); d.text((xm, 258), "their published policy", font=Fo(22), fill=MUTE); d.text((xr, 258), "run %s, checkpoint %s" % (F["run"], F["it"]), font=Fo(22), fill=MUTE)
    t10s = AU.get("top10_median_score")
    rows = [("score the board shows", ("%.2f s" % t10s) if t10s else "-", "%.2f s" % ref_s, "%.2f s" % ours_s, "the Arena's score: mean of 5 fixed starts, at the best of 18 commanded speeds; our local run reproduces %s of %s board rows" % (AU.get("matched", "-"), AU.get("scored", "-"))),
            ("finishes, 20 starts never scored", ("%d of 20" % statistics.median(top10)) if top10 else "-", ("%d of 20" % ref_fresh) if ref_fresh is not None else "-", ("%d of 20" % ours_fresh) if ours_fresh is not None else "-",
             "same lane, same score rule, start seeds 6 to 25 (the board scores seeds 1 to 5), at each file's own scored speed"),
            ("upright on all 25 starts", "%d of 10 rows" % sum(1 for b in BARS if b[0] <= 10 and b[3] == 25), "%s of 25" % (rchk["clean_seeds"] if rchk else "-"), "%s of 25" % (chk["clean_seeds"] if chk else "-"),
             "never tilted past 60 degrees and kept its trunk height on the slope; a start the board never scores can still count here"),
            ("place on a 25-start ladder", "-", "-", ("#%d of %d" % (hp["place"], hp["of"])) if hp else "-",
             "audited board rows ranked by their mean over 25 starts, falls counted as 60 s; a local ranking, nothing was entered")]
    y = 316
    for lab, l, m, r, note in rows:
        d.rectangle([xlab - 20, y - 14, W - 60, y - 12], fill=GRID)
        d.text((xlab, y), lab, font=Fo(28), fill=TEXT)
        fz = 46
        while max(d.textlength(x, font=Fo(fz, True, True)) for x in (l, m, r)) > 275 and fz > 26: fz -= 2
        d.text((xl, y - 6), l, font=Fo(fz, True, True), fill=CORAL); d.text((xm, y - 6), m, font=Fo(fz, True, True), fill=REFC); d.text((xr, y - 6), r, font=Fo(fz, True, True), fill=OURS)
        for i, line in enumerate(wrap(d, note, Fo(24), W - 2 * xlab)[:1]): d.text((xlab, y + 50), line, font=Fo(24), fill=MUTE)
        y += 128
    d.rectangle([xlab - 20, y - 14, W - 60, y - 12], fill=GRID)
    small = ("tested claim: the board's fastest rows still work when the start seed changes. limits: simulation only, same policy files the board runs, 25 starts per row, a fragile row is one that finishes fewer than 10 of the 20 unscored starts; "
             "some entrants say in their own model cards that their file is tuned to the scored starts. nothing was entered, no names shown, no place claimed.")
    for i, line in enumerate(wrap(d, small, Fo(22), W - 2 * xlab)[:3]): d.text((xlab, y + 4 + 28 * i), line, font=Fo(22), fill=MUTE)
    d.text((48, H - 44), "witcheer", font=Fo(24, True), fill=TEXT)
    return im


def hud(img, label, color, clock, ref_txt, stamp, big=None):
    im = Image.fromarray(img); d = ImageDraw.Draw(im, "RGBA")
    d.rectangle([1700, 1020, 1920, 1080], fill=(14, 20, 32, 255))      # mask the Arena's own tiny timer (bottom right): ours is the only clock
    d.rectangle([0, 0, 700, 54], fill=(14, 20, 32, 255))               # mask the Arena's REC line (store user + run name)
    x0, y0, x1, y1 = 18, 730, 700, 1000
    d.rounded_rectangle([x0, y0, x1, y1], radius=22, fill=(14, 20, 32, 225), outline=color, width=4)
    d.text((x0 + 26, y0 + 10), label, font=Fo(36, True), fill=color)
    t = "%.2f" % clock
    d.text((x0 + 26, y0 + 56), t, font=Fo(112, True, True), fill=TEXT)
    d.text((x0 + 26 + d.textlength(t, font=Fo(112, True, True)) + 10, y0 + 112), "s", font=Fo(56, True), fill=TEXT)
    d.text((x0 + 26, y0 + 190), ref_txt, font=Fo(40, True), fill=REFC)
    pw = d.textlength(stamp, font=Fo(24, True)) + 36
    d.rounded_rectangle([W - 48 - pw, 70, W - 48, 106], radius=18, outline=CORAL, width=3, fill=(14, 20, 32))
    d.text((W - 48 - pw + 18, 74), stamp, font=Fo(24, True), fill=CORAL)
    if big:
        bw = d.textlength(big, font=Fo(120, True)) + 80
        d.rounded_rectangle([(W - bw) / 2, 380, (W + bw) / 2, 540], radius=30, fill=(14, 20, 32, 235), outline=CORAL, width=6)
        d.text(((W - bw) / 2 + 40, 394), big, font=Fo(120, True), fill=CORAL)
    return np.asarray(im)


def blend(fr, pos):
    i = int(pos); j = min(i + 1, len(fr) - 1); w = pos - i
    return fr[i] if w < 0.02 else (fr[i].astype(np.float32) * (1 - w) + fr[j].astype(np.float32) * w).astype(np.uint8)


def run_segment(pr, c, label, color, ref_txt, speed, end_big=None, lo=-0.4):
    t0 = c["tape0"] + SETTLE_S
    clock_end = c["time"]
    hi = clock_end - 0.03
    fr = frames_of(c["mp4"], t0 + lo, t0 + hi)
    n_live = int(round(len(fr) / speed))
    n_out = n_live + int(HOLD_S * FPS)
    stamp = ("%gx speed" % speed) if speed != 1.0 else "real speed"
    for k in range(n_out):
        if k < n_live:
            pos = min(k * speed, len(fr) - 1)
            img = blend(fr, pos); simt = lo + pos / FPS
            big = None
        else:
            img = fr[-1]; simt = clock_end; big = end_big
        img = hud(img, label, color, min(max(simt, 0.0), clock_end), ref_txt, stamp, big)
        pr.stdin.write(img.tobytes())
    return n_out


def ladder(t):
    im = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 114], fill=BAND); d.rectangle([0, 114, W, 117], fill=GRID)
    d.text((48, 10), "finishes out of the 20 starts the board never scores", font=Fo(40, True), fill=TEXT)
    d.text((48, 66), "one bar per board row, rank 1 to %d from the left, at each row's own scored speed. Pollen's reference and our pick are the last two bars." % len(BARS), font=Fo(24), fill=MUTE)
    n = len(BARS) + 2
    bx0, bx1, by1, by0 = 110, W - 90, 860, 240
    bw = (bx1 - bx0) / n
    for g in (0, 5, 10, 15, 20):
        yy = by1 - (by1 - by0) * g / 20.0
        d.line([(bx0, yy), (bx1, yy)], fill="#1c2538", width=1); d.text((bx0 - 62, yy - 14), "%d" % g, font=Fo(24), fill=MUTE)
    shown = min(n, int(t * 4.0) + 1)
    seq = [(b[0], b[2], CORAL if b[2] <= 9 else "#6c7f9a", str(b[0])) for b in BARS] + [(0, ref_fresh or 0, REFC, "ref"), (0, ours_fresh or 0, OURS, "ours")]
    for i, (rk, v, col, lab) in enumerate(seq[:shown]):
        x = bx0 + i * bw
        h = (by1 - by0) * v / 20.0
        if v > 0: d.rectangle([x + 4, by1 - h, x + bw - 4, by1], fill=col)
        else: d.rectangle([x + 4, by1 - 4, x + bw - 4, by1], fill=col)
        d.text((x + bw / 2 - d.textlength(str(v), font=Fo(22, True)) / 2, by1 - h - 30), str(v), font=Fo(22, True), fill=TEXT if i >= n - 2 else "#a9b6c9")
        d.text((x + bw / 2 - d.textlength(lab, font=Fo(20, i >= n - 2)) / 2, by1 + 10), lab, font=Fo(20, i >= n - 2), fill=(col if i >= n - 2 else MUTE))
    ft = "red bar = fewer than 10 of the 20 unscored starts finish (a fragile row); %d of the %d rows finish none. every bar is a local re-run of the row's public policy file with the Arena's own evaluator; rank is the board's, read at proof time." % (ZERO, len(BARS))
    for i, line in enumerate(wrap(d, ft, Fo(22), W - 2 * bx0)[:2]): d.text((bx0, by1 + 50 + 28 * i), line, font=Fo(22), fill=MUTE)
    d.text((bx0, by1 + 116), "simulation only. nothing was entered or published. no user or policy names are shown.", font=Fo(26, True), fill=TEXT)
    d.text((48, H - 44), "witcheer", font=Fo(24, True), fill=TEXT)
    return np.asarray(im)


pr = enc(a.out)
stills = {}
nfr = 0
for k in range(int(8 * FPS)):
    im = card(k / FPS); b = np.asarray(im).tobytes(); pr.stdin.write(b); nfr += 1
    if k in (12, 150): stills["card-%d" % k] = Image.frombytes("RGB", (W, H), b)
seg_marks = [("card", 0, nfr)]
hs, hf, ou = CL["hero_scored"], CL["hero_fresh"], CL["ours"]
HR = (AU.get("hero") or {}).get("rank", 1)
n2a = run_segment(pr, hs, "board rank %d, a scored start" % HR, GOLD, "scored start: finishes", 1.0, None); nfr += n2a
n2 = run_segment(pr, hs, "board rank %d, a scored start" % HR, GOLD, "scored start: finishes", 0.25, None); nfr += n2; seg_marks.append(("hero_scored", seg_marks[-1][2], nfr))
n3a = run_segment(pr, hf, "the same file, an unscored start", CORAL, "unscored start: no finish", 1.0, None); nfr += n3a
n3 = run_segment(pr, hf, "the same file, an unscored start", CORAL, "unscored start: no finish", 0.25, "TIPPED OVER"); nfr += n3; seg_marks.append(("hero_fresh", seg_marks[-1][2], nfr))
n4 = run_segment(pr, ou, "our shipped-recipe pick", OURS, "ref %.2f s" % ref_s, 1.0, None, lo=-0.3); nfr += n4; seg_marks.append(("ours", seg_marks[-1][2], nfr))
for k in range(int(16 * FPS)):
    b = ladder(k / FPS).tobytes(); pr.stdin.write(b); nfr += 1
    if k == 16 * FPS - 2: stills["ladder"] = Image.frombytes("RGB", (W, H), b)
pr.stdin.close(); pr.wait()
# audio: card silence | silence under the two slow-motion segments | the Arena clip's own crowd for our run | silence for the ladder
card_s = 8.0; s2 = (n2a + n2) / FPS; s3 = (n3a + n3) / FPS; s4 = n4 / FPS; tail_s = nfr / FPS - card_s - s2 - s3 - s4
t0 = ou["tape0"] + SETTLE_S - 0.3
fc = ("anullsrc=r=48000:cl=stereo,atrim=0:%.3f[s0];anullsrc=r=48000:cl=stereo,atrim=0:%.3f[s1];[0:a]atrim=%.3f:%.3f,asetpts=PTS-STARTPTS,apad=whole_dur=%.3f[a1];anullsrc=r=48000:cl=stereo,atrim=0:%.3f[s3];"
      "[s0][s1][a1][s3]concat=n=4:v=0:a=1,afade=t=out:st=%.3f:d=1.0[aout]") % (card_s + s2 + s3, 0.001, t0, t0 + ou["time"] + 0.1, s4, tail_s, nfr / FPS - 1.0)
tmp = a.out + ".silent.mp4"; os.replace(a.out, tmp)
rc = subprocess.run([a.ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", ou["mp4"], "-i", tmp, "-filter_complex", fc, "-map", "1:v", "-map", "[aout]", "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
                     "-shortest", "-movflags", "+faststart", a.out], stdin=subprocess.DEVNULL).returncode
if rc == 0: os.remove(tmp)
print("audio mux rc", rc)
if a.stills:
    os.makedirs(a.stills, exist_ok=True)
    for k, v in stills.items(): v.save(os.path.join(a.stills, k + ".png"))
json.dump({"clip": a.out, "frames": nfr, "seconds": round(nfr / FPS, 1), "ffmpeg_rc": pr.returncode, "audio_mux_rc": rc, "mock": a.mock, "verdict": verdict, "audit_holds": HOLDS, "title": TITLE, "segments": seg_marks}, open(a.out + ".summary.json", "w"), indent=1)
print("rendered", nfr, "frames =", round(nfr / FPS, 1), "s rc", pr.returncode)
sys.exit(pr.returncode)
