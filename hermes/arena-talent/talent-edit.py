#!/usr/bin/env python3
"""talent-edit.py IN.mp4 OUT.mp4 "<sentence>" [landscape|vertical]
Our edit treatment for an Arena Got a Talent clip, ffmpeg + libass (the static build has no drawtext): the clip keeps every pixel (landscape
is padded to 1920x1240, vertical is scaled to 83% and padded to 1080x1920) and a caption band below it carries, the whole clip long,
"TYPED TO HERMES AGENT" + the sentence, "Hermes Agent wrote this act" and "simulation only: not tested on a real robot".
Runs on the box that holds the clips (ffmpeg at $FFMPEG or PATH)."""
import os, subprocess, sys, tempfile
src, out, sentence = sys.argv[1:4]
layout = sys.argv[4] if len(sys.argv) > 4 else "landscape"
BG = "0x0b0b1a"
if layout == "landscape":
    W, H, band_y, vf_pre = 1920, 1240, 1080, f"pad=1920:1240:0:0:color={BG}"
    kick, sent_fs, small, wrap, x0, ky, sy, ry, fy = 26, 42, 24, 62, 48, 1094, 1134, 1094, 1094
else:
    W, H, band_y, vf_pre = 1080, 1920, 1600, f"scale=900:1600,pad=1080:1920:90:0:color={BG}"
    kick, sent_fs, small, wrap, x0, ky, sy, ry, fy = 26, 40, 28, 38, 54, 1616, 1652, 0, 1836
def t(s):
    return f"{int(s//3600)}:{int(s%3600//60):02d}:{s%60:05.2f}"
sent = sentence.replace("{", "(").replace("}", ")")
words, lines, cur = sent.split(), [], ""
for w in words:
    if len(cur) + len(w) + 1 > wrap and cur:
        lines.append(cur); cur = w
    else:
        cur = (cur + " " + w).strip()
lines.append(cur)
quote = "\\N".join(lines)
quote = "\u201c" + quote + "\u201d"
styles = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Kick,DejaVu Sans,{kick},&H00F0D040&,&H000000FF&,&H00000000&,&H00000000&,-1,0,0,0,100,100,3,0,1,0,0,7,{x0},40,0,1
Style: Sent,DejaVu Sans,{sent_fs},&H00FFFFFF&,&H000000FF&,&H00000000&,&H00000000&,-1,0,0,0,100,100,0,0,1,0,0,7,{x0},40,0,1
Style: Chip,DejaVu Sans,{small},&H00D0D0FF&,&H000000FF&,&H00000000&,&H00000000&,-1,0,0,0,100,100,1,0,1,0,0,9,40,{x0},0,1
Style: Foot,DejaVu Sans,{small},&H00E8E8E8&,&H000000FF&,&H00000000&,&H00000000&,0,0,0,0,100,100,1,0,1,0,0,{8 if layout == 'landscape' else 7},40,{x0},0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
ev = f"Dialogue: 0,{t(0)},{t(40)},Kick,,0,0,0,,{{\\pos({x0},{ky})}}TYPED TO HERMES AGENT\n"
ev += f"Dialogue: 0,{t(0)},{t(40)},Sent,,0,0,0,,{{\\pos({x0},{sy})}}{quote}\n"
if layout == "landscape":
    ev += f"Dialogue: 0,{t(0)},{t(40)},Chip,,0,0,0,,{{\\pos({W-x0},{ry})}}Hermes Agent wrote this act\n"
    ev += f"Dialogue: 0,{t(0)},{t(40)},Foot,,0,0,0,,{{\\pos({W//2},{fy})}}simulation only: not tested on a real robot\n"
else:
    ev += f"Dialogue: 0,{t(0)},{t(40)},Chip,,0,0,0,,{{\\pos({W-x0},{ky-2})}}Hermes Agent wrote this act\n"
    ev += f"Dialogue: 0,{t(0)},{t(40)},Foot,,0,0,0,,{{\\pos({x0},{fy})}}simulation only: not tested on a real robot\n"
fd, path = tempfile.mkstemp(suffix=".ass"); os.write(fd, (styles + ev).encode()); os.close(fd)
ff = os.environ.get("FFMPEG", "ffmpeg")
# DUR=<act duration_s> -> the CUT: skip the first 3.0 s (the stage reveal; the close shot starts at 3.0) and stop 1.5 s after the performance ends (the Arena holds
# its verdict card for ~3 s more); the performance clock starts at video 3.5 s
dur = os.environ.get("DUR")
trim_in = ["-ss", "3.0"] if dur else []
trim_out = ["-t", f"{float(dur) + 3.5 + 1.5 - 3.0:.2f}"] if dur else []
cmd = [ff, "-y", "-loglevel", "error"] + trim_in + ["-i", src] + trim_out + ["-vf", f"{vf_pre},ass={path}", "-c:v", "libx264", "-crf", "18", "-preset", "medium",
       "-pix_fmt", "yuv420p", "-c:a", "aac" if dur else "copy"] + (["-b:a", "160k"] if dur else []) + ["-movflags", "+faststart", out]
r = subprocess.run(cmd, capture_output=True, text=True)
print(r.stderr.strip() or f"wrote {out}")
os.unlink(path)
sys.exit(r.returncode)
