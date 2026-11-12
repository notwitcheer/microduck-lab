"""wipe_card.py: the ~8 s RESULT CARD for 09z47 (1920x1080 png), built from the frozen result text only.

usage: python3 wipe_card.py <result-09z47.txt> <out.png>
Line 1 is the pre-registered builder line. Numbers come only from the result file; nothing is typed in here.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1080
BG = (14, 16, 22)
FG = (240, 240, 240)
GREY = (150, 150, 160)
ACC = (255, 120, 40)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(p, s):
    return ImageFont.truetype(p, s)


def wrap(draw, text, fnt, max_w):
    """word-wrap by measured pixel width, so nothing runs past the frame."""
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def main():
    src, out = sys.argv[1], sys.argv[2]
    lines = [l.rstrip("\n") for l in open(src) if l.strip()]
    line1 = lines[0]
    verdict = next((l for l in lines if l.startswith("VERDICT")), "")
    arms = [l for l in lines if l.startswith("ARM ")]
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    MAXW = W - 160
    d.text((80, 80), "a spinning bar vs 1,024 Microducks", font=font(REG, 46), fill=GREY)
    y = 160
    for l in wrap(d, line1, font(BOLD, 70), MAXW):
        d.text((80, y), l, font=font(BOLD, 70), fill=FG)
        y += 84
    vt = verdict.replace("VERDICT (pre-registered): ", "")
    for l in wrap(d, vt, font(BOLD, 52), MAXW):
        d.text((80, y + 20), l, font=font(BOLD, 52), fill=ACC)
        y += 66
    y = max(y + 24, 480)
    for a in arms[:3]:
        d.text((80, y), a.split(":")[0], font=font(BOLD, 40), fill=FG)
        y += 50
        for l in wrap(d, a.split(":", 1)[1].strip(), font(REG, 26), MAXW):
            d.text((80, y), l, font=font(REG, 26), fill=FG)
            y += 34
        y += 14
    assert y < 890, f"arm block ends at y={y}, collides with footer"
    foot = "how it was measured: 1,024 envs, stock walk policy (no training), 3 turns per arm, survival = trunk >= 0.90 x standing height."
    fy = 900  # footer top; the assert above guarantees the arm block ends above it
    for l in wrap(d, foot, font(REG, 26), MAXW):
        d.text((80, fy), l, font=font(REG, 26), fill=GREY)
        fy += 34
    d.text((80, 1020), "wipeout is physics. the duck did not learn to dodge. sim only.", font=font(REG, 30), fill=GREY)
    im.save(out)
    print("card", out, im.size)


if __name__ == "__main__":
    main()
