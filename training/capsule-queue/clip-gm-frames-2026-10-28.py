#!/usr/bin/env python3
"""clip-gm-frames-2026-10-28.py: writes the per-frame METER strip PNGs (1280x80, one per video frame at 50 fps) and the static caption strip PNG (1280x124) for one clip segment of the gale / moon cuts.
usage: clip-gm-frames-2026-10-28.py <gale|moon> <take log> <t0 s> <dur s> <out dir> <caption line 1> <caption line 2> <caption line 3> [g (moon gravity label, default 1.62)]
the meter reads the take's own [gm] log: gale = the wind force (N) at that frame with a bar (0..4 N); moon = a fixed gravity label + the distance walked so far (fwd, m). frame i <-> policy step round((t0 + i/50)/0.02).
captions are PIL strips padded UNDER the frame (nothing covers the feet). prints the caption widths (must be <= 1200 px).
"""
import os, re, sys
from PIL import Image, ImageDraw, ImageFont

mode, log, t0, dur, out, c1, c2, c3 = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8]
glabel = sys.argv[9] if len(sys.argv) > 9 else '1.62'
os.makedirs(out, exist_ok=True)
B, R = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
L = re.compile(r'\[gm\] k=\s*(\d+) t=\s*([\d.]+) fwd=\s*([-+\d.]+) lat=\s*([-+\d.]+) z=\s*([-\d.]+) tilt=\s*([\d.]+) lean=\s*([-+\d.]+) air=\s*(-?\d) tq=([\d.]+) wind=\s*([\d.]+)')
rows = {}
for m in L.finditer(open(log, errors='replace').read()):
    rows[int(m[1])] = dict(fwd=float(m[3]), wind=float(m[10]), tilt=float(m[6]), lean=float(m[7]))
last = max(rows)
W = 1280


def fit(txt, path, size, d):
    while size > 16 and d.textlength(txt, font=ImageFont.truetype(path, size)) > 1200: size -= 1
    return ImageFont.truetype(path, size)


# caption strip
im = Image.new('RGB', (W, 124), 'black'); d = ImageDraw.Draw(im)
for txt, path, size, y, col in ((c1, B, 30, 8, 'white'), (c2, R, 25, 50, 'white'), (c3, R, 22, 88, (200, 200, 200))):
    f = fit(txt, path, size, d); w = d.textlength(txt, font=f); d.text(((W - w) / 2, y), txt, font=f, fill=col)
    print(f'CAPTION size {f.size} width {w:.0f}{" WARN-TOO-WIDE" if w > 1230 else ""}: {txt}')
im.save(f'{out}/caption.png')
# meter frames
n = int(round(dur * 50))
fb, fr = ImageFont.truetype(B, 30), ImageFont.truetype(R, 26)
for i in range(n):
    k = min(last, int(round((t0 + i / 50.0) / 0.02)))
    r = rows[k] if k in rows else rows[max(x for x in rows if x <= k)]
    im = Image.new('RGB', (W, 80), (12, 16, 20)); d = ImageDraw.Draw(im)
    if mode == 'gale':
        d.text((24, 18), 'WIND', font=fb, fill=(150, 200, 255))
        x0, x1, y0, y1 = 140, 960, 20, 46
        d.rectangle([x0, y0, x1, y1], outline=(90, 110, 130), width=2)
        fill = int((x1 - x0 - 4) * min(1.0, r['wind'] / 4.0))
        d.rectangle([x0 + 2, y0 + 2, x0 + 2 + fill, y1 - 2], fill=(80, 170, 255))
        for nn in range(1, 5):
            xx = x0 + int((x1 - x0) * nn / 4.0); d.line([xx, y1 + 2, xx, y1 + 8], fill=(120, 140, 160), width=2)
            lab = f'{nn} N'; lw = d.textlength(lab, font=ImageFont.truetype(R, 15)); d.text((xx - lw / 2, y1 + 9), lab, font=ImageFont.truetype(R, 15), fill=(150, 160, 170))
        d.text((990, 18), f"{r['wind']:.1f} N", font=fb, fill='white')
        d.text((1100, 24), 'on the trunk', font=ImageFont.truetype(R, 18), fill=(150, 160, 170))
    else:
        d.text((24, 18), f'GRAVITY {glabel} m/s\u00b2', font=fb, fill=(255, 220, 150))
        d.text((460, 22), '(Earth 9.81)', font=fr, fill=(150, 160, 170))
        d.text((760, 18), f"walked {max(0.0, r['fwd']):.2f} m", font=fb, fill='white')
    im.save(f'{out}/m{i + 1:04d}.png')
print(f'FRAMES {n} -> {out}')
