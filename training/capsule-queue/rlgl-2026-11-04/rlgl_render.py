"""rlgl_render.py: render the red light, green light field from a saved trajectory (CPU, 2026-11-04, simulation only).

reads the npz written by swarm_rlgl2.py and the saved MuJoCo model (.mjb). physics is per-duck independent (one env per duck), so the render
re-lays the field out freely: --cols x rows at --dx/--dy spacing, ducks walk toward the camera, a chequered finish line sits across the field.
burnt in: traffic light + GREEN/RED LIGHT, N of 456 still in (live), SIMULATION ONLY pill, caption. no paths, usernames or hostnames on screen.

usage: MUJOCO_GL=egl .venv/bin/python rlgl_render.py --traj t.npz --model duck.mjb --out out.mp4 [--stills 10,60,130 --still-dir d] [--t0 0 --t1 99] [--cam ...]
"""
import argparse
import math
import os
import sys

os.environ.setdefault("MUJOCO_GL", "egl")
import mujoco  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--traj", required=True)
ap.add_argument("--model", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--w", type=int, default=1920)
ap.add_argument("--h", type=int, default=1080)
ap.add_argument("--fps", type=int, default=25)
ap.add_argument("--crf", type=int, default=23)
ap.add_argument("--cols", type=int, default=22)
ap.add_argument("--dx", type=float, default=0.45, help="lateral spacing (m)")
ap.add_argument("--dy", type=float, default=0.45, help="row spacing along the walk (m)")
ap.add_argument("--finish-gap", type=float, default=2.6, help="distance (m) from the front row's start to the finish line")
ap.add_argument("--cam-keys", default="0:3.6:-25:0:0:-3.6,0.15:4.6:-27:0:0:-3.4,0.35:5.8:-30:0:0:-3.0,1:6.0:-30:0:0:-2.2", help="p:dist:elev:azim:lat:along keys (lookat offset from the field centre line / finish line)")
ap.add_argument("--stills", default="")
ap.add_argument("--still-dir", default="")
ap.add_argument("--t0", type=float, default=0.0)
ap.add_argument("--t1", type=float, default=1e9)
ap.add_argument("--band-top", type=int, default=150)
ap.add_argument("--band-bottom", type=int, default=100)
ap.add_argument("--cull", type=float, default=14.0)
ap.add_argument("--ambient", type=float, default=0.55)
ap.add_argument("--diffuse", type=float, default=0.75)
ap.add_argument("--hold", type=float, default=3.0, help="seconds to hold the last state at the end (end card)")
ap.add_argument("--pre", type=float, default=0.3, help="seconds of pre-roll on sim frame 0 (ducks standing, camera pulling back)")
ap.add_argument("--seg", type=int, default=-1, help="segment index (with --nseg): renders its slice of the output frames")
ap.add_argument("--nseg", type=int, default=1)
ap.add_argument("--g0", type=int, default=0, help="first output frame (segment render)")
ap.add_argument("--g1", type=int, default=10**9, help="last output frame + 1 (segment render)")
ap.add_argument("--elim-rgb", default="1.0,0.15,0.1")
ap.add_argument("--floor-green", default="0.10,0.55,0.20")
ap.add_argument("--floor-red", default="0.30,0.04,0.04")
a = ap.parse_args()

d = np.load(a.traj)
qpos, elim, red, tt = d["qpos"], d["elim"], d["red"], d["t"]
n = qpos.shape[1]
F = qpos.shape[0]
origins = d["origins"]
model = mujoco.MjModel.from_binary_path(a.model)
W, H = a.w, a.h
HS = H - a.band_top - a.band_bottom
model.vis.global_.offwidth = max(W, model.vis.global_.offwidth)
model.vis.global_.offheight = max(H, model.vis.global_.offheight)
model.stat.extent = 12.0
model.vis.headlight.ambient[:] = a.ambient
model.vis.headlight.diffuse[:] = a.diffuse
plane_ids = [gi for gi in range(model.ngeom) if model.geom_type[gi] == mujoco.mjtGeom.mjGEOM_PLANE]
for gi in plane_ids:
    model.geom_matid[gi] = -1
renderer = mujoco.Renderer(model, HS, W, max_geom=max(30000, n * 90))
renderer.scene.flags[mujoco.mjtRndFlag.mjRND_SHADOW] = 0
opt, pert = mujoco.MjvOption(), mujoco.MjvPerturb()
catmask = mujoco.mjtCatBit.mjCAT_DYNAMIC.value
data = mujoco.MjData(model)
cam = mujoco.MjvCamera()
mujoco.mjv_defaultFreeCamera(model, cam)
cam.type = mujoco.mjtCamera.mjCAMERA_FREE.value

# layout: duck i -> (x, y); rows along x (walk direction +x), front row has the largest x; field centred on y = 0
rows = int(math.ceil(n / a.cols))
idx = np.arange(n)
col, row = idx % a.cols, idx // a.cols
lay_y = (col - (a.cols - 1) / 2.0) * a.dx
lay_x = -(row) * a.dy  # row 0 = front row at x = 0 ; later rows behind (more negative x)
# the front row starts a.finish_gap before the finish line at x = 0 + gap (finish line x)
FIN_X = a.finish_gap
# the camera looks toward -x (azimuth 180) from beyond the finish line, so the ducks walk toward it
shift = np.stack([lay_x, lay_y], axis=1) - origins[:, :2]  # add to each duck's world xy

bold = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
fdir = os.path.expanduser("~/promo-pilot/duck-bigaim-2026-10-28/fonts")
anton = [os.path.join(fdir, f) for f in os.listdir(fdir) if f.lower().startswith("anton")] if os.path.isdir(fdir) else []
big = anton[0] if anton else bold
f_big = ImageFont.truetype(big, 96)
f_mid = ImageFont.truetype(big, 64)
f_cap = ImageFont.truetype(bold, 44)
f_pill = ImageFont.truetype(bold, 36)

CAM_KEYS = [tuple(float(x) for x in k.split(":")) for k in a.cam_keys.split(",")]
lerp = lambda p, q, u: p + (q - p) * u  # noqa: E731
GREEN_FLOOR = tuple(float(x) for x in a.floor_green.split(","))
RED_FLOOR = tuple(float(x) for x in a.floor_red.split(","))
ELIM = (*[float(x) for x in a.elim_rgb.split(",")], 1.0)


def add_box(scn, size, pos, rgba):
    if scn.ngeom >= scn.maxgeom:
        return
    g = scn.geoms[scn.ngeom]
    mujoco.mjv_initGeom(g, mujoco.mjtGeom.mjGEOM_BOX, np.array(size, dtype=float), np.array(pos, dtype=float), np.eye(3).flatten(), np.array(rgba, dtype=np.float32))
    g.category = mujoco.mjtCatBit.mjCAT_DYNAMIC
    scn.ngeom += 1


def add_cyl(scn, rad, half, pos, rgba):
    if scn.ngeom >= scn.maxgeom:
        return
    g = scn.geoms[scn.ngeom]
    mujoco.mjv_initGeom(g, mujoco.mjtGeom.mjGEOM_CYLINDER, np.array([rad, half, 0.0]), np.array(pos, dtype=float), np.eye(3).flatten(), np.array(rgba, dtype=np.float32))
    g.category = mujoco.mjtCatBit.mjCAT_DYNAMIC
    scn.ngeom += 1


def finish_line(scn, lat_half):
    # chequered tape on the floor (4 rows) across the whole field, two tall posts and a chequered banner high above the line (seen from behind the ducks)
    cell = 0.30
    ncell = int(2 * lat_half / cell) + 2
    for k in range(ncell):
        y = -lat_half + k * cell
        for r in range(4):
            on = (k + r) % 2 == 0
            add_box(scn, [cell / 2, cell / 2, 0.002], [FIN_X + (r - 1.5) * cell, y, 0.004], (0.97, 0.97, 0.97, 1.0) if on else (0.04, 0.04, 0.04, 1.0))
    top = 1.15
    for sgn in (-1, 1):
        yy = sgn * (lat_half + 0.2)
        add_cyl(scn, 0.05, top / 2, [FIN_X, yy, top / 2], (0.97, 0.97, 0.97, 1.0))
    for k in range(ncell):
        y = -lat_half + k * cell
        for r in range(2):
            on = (k + r) % 2 == 0
            add_box(scn, [0.03, cell / 2, cell / 2], [FIN_X, y, top - 0.15 + (r - 0.5) * cell], (0.97, 0.97, 0.97, 1.0) if on else (0.04, 0.04, 0.04, 1.0))


def lamp(dr, cx, cy, r, on, colour):
    dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour if on else (60, 60, 60, 255), outline=(230, 230, 230, 255), width=4)


still_set = {int(v) for v in a.stills.split(",") if v} if a.stills else set()
if a.still_dir:
    os.makedirs(a.still_dir, exist_ok=True)
HOLDN = int(round(a.hold * a.fps))
PREN = int(round(a.pre * a.fps))
GT = PREN + F + HOLDN  # output frames: pre-roll + F sim frames + hold
f0 = max(0, int(np.searchsorted(tt, a.t0))) if a.t0 > 0 else a.g0
f1 = min(GT, int(np.searchsorted(tt, a.t1, side="right")) if a.t1 < 1e8 else a.g1)
if a.seg >= 0:
    per = int(math.ceil(GT / a.nseg))
    f0, f1 = a.seg * per, min(GT, (a.seg + 1) * per)
print(f"[render] total output frames {GT} (pre {PREN} + sim {F} + hold {HOLDN}); this run frames {f0}..{f1}", flush=True)
import imageio_ffmpeg  # noqa: E402

writer = None
if a.out != "none":
    writer = imageio_ffmpeg.write_frames(a.out, (W, H), fps=a.fps, codec="libx264", pix_fmt_in="rgb24", pix_fmt_out="yuv420p", macro_block_size=1,
                                         output_params=["-crf", str(a.crf), "-preset", "medium", "-movflags", "+faststart"])
    writer.send(None)
lat_half = (a.cols - 1) / 2.0 * a.dx + 0.3
alive_prev = n
alive_hist = []
nfr = 0
for g in range(f0, f1):
    f = min(max(g - PREN, 0), F - 1)
    holding = g >= PREN + F
    p = min(1.0, g / max(1, GT - 1))  # global progress, so segments rendered in parallel share one camera path
    for (pa, *va), (pb, *vb) in zip(CAM_KEYS[:-1], CAM_KEYS[1:]):
        if p <= pb or (pb, *vb) == CAM_KEYS[-1]:
            q = min(1.0, max(0.0, (p - pa) / max(1e-6, pb - pa)))
            q = q * q * (3 - 2 * q)
            dist, elev, azim, lat, along = [lerp(x, y, q) for x, y in zip(va, vb)]
            break
    # ducks advance +x over the clip; the camera tracks the field's front row mean x so the ducks keep coming at it
    xs = qpos[f, :, 0] + shift[:, 0]
    front = xs[row == 0].mean() if (row == 0).any() else xs.max()
    cam.lookat[:] = (along, lat, 0.10)  # absolute x of the look-at (front row starts at x = 0, rows trail behind at negative x)
    cam.distance, cam.elevation, cam.azimuth = dist, elev, azim
    is_red = bool(red[f])
    rgb = RED_FLOOR if is_red else GREEN_FLOOR
    for gi in plane_ids:
        model.geom_rgba[gi] = [rgb[0], rgb[1], rgb[2], 1.0]
    qp0 = qpos[f, 0].astype(np.float64).copy()  # the model holds ONE duck: update_scene draws it, so it must be duck 0 at its shifted pose (a frozen frame-0 ghost otherwise)
    qp0[0] += shift[0, 0]
    qp0[1] += shift[0, 1]
    data.qpos[:] = qp0
    mujoco.mj_kinematics(model, data)
    renderer.update_scene(data, camera=cam)
    scn = renderer.scene
    if elim[f][0]:
        for j in range(scn.ngeom):
            if scn.geoms[j].category == mujoco.mjtCatBit.mjCAT_DYNAMIC:
                scn.geoms[j].rgba[:] = ELIM
    add_box(scn, [2000.0, 2000.0, 0.001], [0.0, 0.0, -0.001], (*rgb, 1.0))
    finish_line(scn, lat_half)
    el = elim[f]
    # cull: only ducks within a.cull m of the lookat
    px = qpos[f, :, 0] + shift[:, 0]
    py = qpos[f, :, 1] + shift[:, 1]
    near = np.nonzero((px - cam.lookat[0]) ** 2 + (py - cam.lookat[1]) ** 2 < (a.cull + 0.0) ** 2)[0]
    for i in near:
        if i == 0:
            continue
        qp = qpos[f, i].astype(np.float64).copy()
        qp[0] += shift[i, 0]
        qp[1] += shift[i, 1]
        data.qpos[:] = qp
        mujoco.mj_kinematics(model, data)
        s0 = scn.ngeom
        mujoco.mjv_addGeoms(model, data, opt, pert, catmask, scn)
        if el[i]:
            for j in range(s0, scn.ngeom):
                scn.geoms[j].rgba[:] = ELIM
    img = renderer.render().copy()
    # no skybox: the background above the (huge) floor's horizon is pure black. paint it with the floor colour sampled just below the horizon
    # (rows that are entirely black from the top down), so the floor runs to the top edge of the 3D area with no void.
    nb = 0
    while nb < img.shape[0] - 1 and int(img[nb].max()) <= 3:
        nb += 1
    if 0 < nb < img.shape[0] - 1:
        base_c = img[min(nb + 1, img.shape[0] - 1), 4].astype(np.float32)
        for yy in range(nb):
            k = 0.45 + 0.55 * (yy / max(1, nb - 1))
            img[yy] = (base_c * k).astype(np.uint8)
    im = Image.new("RGB", (W, H), (10, 12, 12))
    im.paste(Image.fromarray(img), (0, a.band_top))
    dr = ImageDraw.Draw(im, "RGBA")
    # red-phase frame: a thick red border round the 3D area so the state change survives a dark floor and a small screen
    if is_red:
        bw = 22
        dr.rectangle([0, a.band_top, W, a.band_top + bw], fill=(235, 30, 30, 255))
        dr.rectangle([0, H - a.band_bottom - bw, W, H - a.band_bottom], fill=(235, 30, 30, 255))
        dr.rectangle([0, a.band_top, bw, H - a.band_bottom], fill=(235, 30, 30, 255))
        dr.rectangle([W - bw, a.band_top, W, H - a.band_bottom], fill=(235, 30, 30, 255))
    # top band: traffic light + state word, live counter
    dr.rectangle([0, 0, W, a.band_top], fill=(70, 10, 10, 255) if is_red else (10, 40, 18, 255))
    bx0, by0, bx1, by1 = 40, 16, 40 + 232, a.band_top - 16
    dr.rounded_rectangle([bx0, by0, bx1, by1], radius=40, fill=(28, 28, 28, 255), outline=(230, 230, 230, 255), width=4)
    mid = (by0 + by1) // 2
    dr.ellipse([bx0 + 24, mid - 38, bx0 + 100, mid + 38], fill=(240, 40, 40, 255) if is_red else (95, 25, 25, 255), outline=(230, 230, 230, 255), width=4)
    dr.ellipse([bx0 + 114, mid - 38, bx0 + 190, mid + 38], fill=(60, 230, 90, 255) if not is_red else (20, 70, 30, 255), outline=(230, 230, 230, 255), width=4)
    word = "RED LIGHT" if is_red else "GREEN LIGHT"
    if holding:
        word = "FINISH"
    dr.text((bx1 + 36, mid), word, font=f_big, fill=(255, 90, 80, 255) if is_red else (120, 240, 140, 255), anchor="lm")
    alive = int((~el).sum())
    alive_hist.append(alive)
    ctxt = f"FINAL {alive} of {n}" if holding else f"{alive} of {n} still in"
    dr.text((W - 44, mid), ctxt, font=f_big, fill=(246, 243, 232, 255), anchor="rm")
    # bottom band
    yb = H - a.band_bottom
    dr.rectangle([0, yb, W, H], fill=(14, 16, 16, 255))
    dr.text((44, yb + a.band_bottom / 2), f"{n} Microducks play red light, green light", font=f_cap, fill=(246, 243, 232, 255), anchor="lm")
    # legend: red dot = out (survivors keep their grey/white colour)
    lx = 44 + dr.textlength(f"{n} Microducks play red light, green light", font=f_cap) + 60
    dr.ellipse([lx, yb + a.band_bottom / 2 - 16, lx + 32, yb + a.band_bottom / 2 + 16], fill=(255, 38, 26, 255))
    dr.text((lx + 46, yb + a.band_bottom / 2), "= OUT", font=f_cap, fill=(246, 243, 232, 255), anchor="lm")
    ptxt = "SIMULATION ONLY"
    pw = dr.textlength(ptxt, font=f_pill)
    px0 = W - 44 - pw - 52
    py0 = yb + (a.band_bottom - 60) / 2
    dr.rounded_rectangle([px0, py0, px0 + pw + 52, py0 + 60], radius=30, fill=(246, 243, 232, 255))
    dr.text((px0 + 26, py0 + 30), ptxt, font=f_pill, fill=(10, 12, 12, 255), anchor="lm")
    if holding:
        l1 = f"{alive} SURVIVED"
        l2 = f"{n - alive} OUT  |  {n} STARTED"
        tw = max(dr.textlength(l1, font=f_big), dr.textlength(l2, font=f_mid)) + 100
        cx0, cy0 = (W - tw) / 2, H - a.band_bottom - 40 - 190
        dr.rounded_rectangle([cx0, cy0, cx0 + tw, cy0 + 190], radius=30, fill=(10, 12, 12, 225))
        dr.text((W / 2, cy0 + 64), l1, font=f_big, fill=(255, 235, 120, 255), anchor="mm")
        dr.text((W / 2, cy0 + 143), l2, font=f_mid, fill=(246, 243, 232, 255), anchor="mm")
    elif g < PREN + int(1.6 * a.fps):
        # opening title (first ~1.6 s, fades out): says what this is before anything moves
        k = 1.0 if g < PREN + int(1.0 * a.fps) else max(0.0, 1.0 - (g - PREN - int(1.0 * a.fps)) / (0.6 * a.fps))
        t1, t2 = f"{n} ROBOT DUCKS", "RED LIGHT, GREEN LIGHT"
        tw = max(dr.textlength(t1, font=f_big), dr.textlength(t2, font=f_mid)) + 100
        cx0, cy0 = (W - tw) / 2, a.band_top + 36
        dr.rounded_rectangle([cx0, cy0, cx0 + tw, cy0 + 190], radius=30, fill=(10, 12, 12, int(215 * k)))
        dr.text((W / 2, cy0 + 64), t1, font=f_big, fill=(255, 235, 120, int(255 * k)), anchor="mm")
        dr.text((W / 2, cy0 + 143), t2, font=f_mid, fill=(246, 243, 232, int(255 * k)), anchor="mm")
    if writer is not None:
        writer.send(np.asarray(im).tobytes())
    if g in still_set and a.still_dir:
        im.save(os.path.join(a.still_dir, f"s{g:04d}.png"))
    nfr += 1
    if nfr % 25 == 0:
        print(f"[render] frame {nfr}/{f1 - f0} t={tt[f]:.2f}s alive={alive}", flush=True)
if writer is not None:
    writer.close()
mono = bool(np.all(np.diff(np.array(alive_hist)) <= 0))
_xl = qpos[F - 1, :, 0] + shift[:, 0]
crossed = int(((_xl > FIN_X) & ~elim[F - 1]).sum())
print(f"[render] RESULT field n={n} alive_final={int((~elim[F - 1]).sum())} alive_crossed_the_line={crossed} (line at {FIN_X:.1f} m from the front row's start)", flush=True)
print(f"[render] wrote {a.out} frames={nfr} counter_monotone={mono} first={alive_hist[0]} last={alive_hist[-1]}", flush=True)
