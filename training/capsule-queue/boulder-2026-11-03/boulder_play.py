"""boulder_play.py: the boulder chase (render-only feasibility, no training): a rolling boulder bigger than the duck comes up behind a
walking Microduck; optional Hermes-style reflex controller sidesteps it.

witcheer lane, simulation only. derived from cond_probe.py (Velocity task, forced command, terminations off) + bowl_play.py (play-only
entity added in the play cfg, per-env reset event, one-env offscreen render). NOTHING in Pollen's tree or our fork modules is edited.
policy: walk-flat v2 (`duckvelbl` model_7000, task `Mjlab-Velocity-Flat-Backlash-MicroDuck`); the policy is blind to the boulder.

the boulder is a free-body sphere (radius --r, mass --mass, rock colour + dark patches that rotate with it) placed --gap m behind the duck's
trunk (surface to trunk) with a per-env lateral offset (uniform +-0.08 m). SCRIPTED SPEED: before every policy step the boulder's linear x
velocity is written to v(t) = min(vmax, v0 + acc t) and its angular y velocity to v(t) / r (rolling without slipping), so it is an
unstoppable roller (MuJoCo ignores rolling friction at condim 3, so a plain pushed ball would never slow or speed up). the duck is the
only thing that can get out of the way. reflex (--reflex 1): once time-to-contact tau = (surface gap) / (boulder vx - duck vx) drops under
--tau the duck commands a sidestep (vy = +-dodge-vy away from the boulder's line, vx = dodge-vx) for --dodge-s seconds, then walks on.

usage (from ~/Pollen/microduck_rl, MUJOCO_GL=egl, CPU: CUDA_VISIBLE_DEVICES= and --device cpu):
  .venv/bin/python boulder_play.py Mjlab-Velocity-Flat-Backlash-MicroDuck --checkpoint-file <model_7000.pt> --num-envs 16 --device cpu \\
      --reflex 0|1 --dur 14                       # numbers only (per-env lines + RESULT)
  ... --num-envs 1 --render 1 --out boulder.mp4 --stills 10,60,..          # the rendered take (env 0)
flags: --r, --mass, --gap, --v0, --acc, --vmax, --cmd-vx, --reflex, --tau, --dodge-vy, --dodge-vx, --dodge-s, --control 1 (boulder 40 m
away: the no-boulder control for Z_STAND), --seed, --cam p:dist:elev:az:dx:dz keyframes (look-at tracks the duck, dx = offset ahead of it),
--out --w --h --fps --crf --band-top --band-bottom --floor --stills --log-every.
numbers printed: per-env hit (ball-robot contact or clearance), min clearance, tilt max, trunk z median/low share, duck travel; RESULT lines.
"""
import math
import os
import sys

os.environ.setdefault("MUJOCO_GL", "egl")
argv = sys.argv[1:]


def take(flag, default, cast):
    if flag in argv:
        i = argv.index(flag)
        val = cast(argv[i + 1])
        del argv[i : i + 2]
        return val
    return default


dur = take("--dur", 14.0, float)
B_R = take("--r", 0.25, float)
B_MASS = take("--mass", 8.0, float)
GAP = take("--gap", 1.2, float)
GAP_JIT = take("--gap-jit", 0.0, float)  # +- m, per env
LAT_JIT = take("--lat-jit", 0.08, float)  # +- m lateral offset of the boulder's line, per env
V0 = take("--v0", 0.15, float)
ACC = take("--acc", 0.08, float)
VMAX = take("--vmax", 0.7, float)
CMD_VX = take("--cmd-vx", 0.3, float)
REFLEX = take("--reflex", 0, int)
TAU = take("--tau", 3.0, float)
DODGE_VY = take("--dodge-vy", 0.3, float)
DODGE_VX = take("--dodge-vx", 0.15, float)
DODGE_S = take("--dodge-s", 3.0, float)
CONTROL = take("--control", 0, int)
LABEL = take("--label", "", str)  # bottom caption (render only); default names the duck and the boulder
OUT2 = take("--out2", "", str)  # second video of the SAME run from a second camera (plan view): --cam2 dist:elev:az:dx:dz (one fixed key, look-at tracks the duck in x only)
CAM2 = [float(x) for x in take("--cam2", "2.6:-84:90:0.0:0.0", str).split(":")]
TRACKY = take("--track-y", 1, int)  # render camera follows the duck in y too (0 = fixed lateral position, a sidestep then shows)
LANES = take("--lanes", 1, int)  # render only: visual-only floor stripes (static entity, contype 0) so travel and scale read
REFLEX_FILE = take("--reflex-file", "", str)  # python file with reflex(**state) -> (vx, vy, vyaw): the controller Hermes Agent writes (overrides --reflex)
CAFF = take("--boulder-caff", 3, int)  # boulder conaffinity: 1 = floor + feet only (the shell hulls are contype 2), 3 = also the duck's group-3 collision hulls
HOLD = take("--hold-heading", 1, int)  # P controller on yaw (vyaw = -K * heading): the open-loop walk drifts +-2 m sideways in 14 s
HOLD_K = take("--hold-k", 1.5, float)
SEED = take("--seed", 1, int)
do_render = take("--render", 0, int)
render_env = take("--render-env", 0, int)
out_path = take("--out", "boulder.mp4", str)
stills_arg = take("--stills", "", str)
W = take("--w", 1920, int)
H = take("--h", 1080, int)
fps = take("--fps", 25, int)
crf = take("--crf", 20, int)
band_top = take("--band-top", 130, int)
band_bot = take("--band-bottom", 56, int)
log_every = take("--log-every", 25, int)
floor_rgb = [float(x) for x in take("--floor", "0.16,0.18,0.17", str).split(",")]
CAM_KEYS = [tuple(float(x) for x in k.split(":")) for k in take("--cam-keys", "0:1.5:-14:90:0.2:0.1,1:1.5:-14:90:0.2:0.1", str).split(",")]
Z_STAND_MM = take("--z-stand", 116.1, float)  # CPU seed walk, fixed from the control takes BEFORE the boulder takes (see the note)

import mujoco  # noqa: E402
import torch  # noqa: E402

RF = None
if REFLEX_FILE:
    import importlib.util

    _spec = importlib.util.spec_from_file_location("hermes_reflex", REFLEX_FILE)
    RF = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(RF)

import mjlab.scripts.play as play  # noqa: E402
from mjlab.entity import EntityCfg  # noqa: E402
from mjlab.managers import EventTermCfg  # noqa: E402

BOULDER_XML = """
<mujoco model="boulder">
  <worldbody>
    <body name="boulder" pos="0 0 {r}">
      <freejoint name="boulder_free"/>
      <inertial pos="0 0 0" mass="{m}" diaginertia="{i} {i} {i}"/>
      <geom name="boulder_geom" type="sphere" size="{r}" rgba="0.48 0.40 0.32 1" friction="1.0 0.005 0.0001" contype="1" conaffinity="{caff}"/>
      {patches}
    </body>
  </worldbody>
</mujoco>
"""


def _boulder_spec() -> mujoco.MjSpec:
    # dark rock patches embedded in the surface (contype 0: visual only) so the rolling reads on camera
    pts = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1), (0.7, 0.7, 0), (-0.7, 0.7, 0), (0.7, -0.7, 0), (-0.7, -0.7, 0),
           (0.6, 0, 0.8), (-0.6, 0, 0.8), (0, 0.6, 0.8), (0, -0.6, 0.8), (0.6, 0, -0.8), (0, 0.6, -0.8)]
    patches = ""
    for k, (x, y, z) in enumerate(pts):
        n = math.sqrt(x * x + y * y + z * z)
        patches += (f'<geom name="rock{k}" type="sphere" size="{B_R * 0.24:.4f}" pos="{B_R * 0.93 * x / n:.4f} {B_R * 0.93 * y / n:.4f} {B_R * 0.93 * z / n:.4f}" '
                    f'rgba="0.22 0.19 0.16 1" contype="0" conaffinity="0"/>')
    inertia = 0.4 * B_MASS * B_R**2  # solid sphere
    return mujoco.MjSpec.from_string(BOULDER_XML.format(r=B_R, m=B_MASS, i=inertia, patches=patches, caff=CAFF))


def _lanes_spec() -> mujoco.MjSpec:
    g = ""
    for k in range(-10, 21):  # transverse stripes every 0.5 m (x from -5 to +10)
        g += f'<geom type="box" size="0.012 1.0 0.0008" pos="{k * 0.5:.2f} 0 0.0009" rgba="0.55 0.58 0.55 1" contype="0" conaffinity="0"/>'
    for sy in (-1.0, 1.0):  # lane edges
        g += f'<geom type="box" size="8.0 0.02 0.0008" pos="2.5 {sy:.2f} 0.0009" rgba="0.85 0.8 0.35 1" contype="0" conaffinity="0"/>'
    return mujoco.MjSpec.from_string(f'<mujoco model="lanes"><worldbody><body name="lanes" pos="0 0 0">{g}</body></worldbody></mujoco>')


_rng = {"gap": None, "lat": None}


def reset_boulder(env, env_ids):
    if env_ids is None or len(env_ids) == 0:
        return
    env_ids = env_ids.to(env.device)
    n = len(env_ids)
    ent = env.scene["boulder"]
    g = torch.Generator(device="cpu").manual_seed(SEED)
    if _rng["gap"] is None or _rng["gap"].shape[0] != env.num_envs:
        _rng["lat"] = (torch.rand(env.num_envs, generator=g) * 2 - 1) * LAT_JIT
        _rng["gap"] = GAP + (torch.rand(env.num_envs, generator=g) * 2 - 1) * GAP_JIT
        if CONTROL:
            _rng["gap"] = torch.full((env.num_envs,), 40.0)
    pose = torch.zeros(n, 7, device=env.device)
    pose[:, 0] = env.scene.env_origins[env_ids, 0] - (_rng["gap"][env_ids.cpu()].to(env.device) + B_R + 0.05)
    pose[:, 1] = env.scene.env_origins[env_ids, 1] + _rng["lat"][env_ids.cpu()].to(env.device)
    pose[:, 2] = B_R
    pose[:, 3] = 1.0
    ent.write_root_link_pose_to_sim(pose, env_ids)
    ent.write_root_link_velocity_to_sim(torch.zeros(n, 6, device=env.device), env_ids)


class BoulderViewer:
    def __init__(self, env, policy, checkpoint_manager=None):
        self.env = env
        self.policy = policy

    def run(self, num_steps=None, catch_sigint=True):
        import numpy as np

        base = self.env.unwrapped
        robot = base.scene["robot"]
        ball = base.scene["boulder"]
        model = base.sim.mj_model
        n = base.num_envs
        dt = base.step_dt
        steps = int(round(dur / dt))
        origins = base.scene.env_origins
        term = base.command_manager.get_term("twist")
        dev = base.device
        bgid = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_GEOM, "boulder/boulder_geom")
        if bgid < 0:
            bgid = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_GEOM, "boulder_geom")
        rgeoms = {gi for gi in range(model.ngeom) if model.geom_bodyid[gi] > 0 and mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_BODY, int(model.geom_bodyid[gi])).startswith("robot/") and (model.geom_contype[gi] or model.geom_conaffinity[gi])}
        bmass = float(model.body_mass[mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, "boulder/boulder")]) if mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, "boulder/boulder") >= 0 else float("nan")
        print(f"[boulder] hold_heading={HOLD} k={HOLD_K}", flush=True)
        print(f"[boulder] envs={n} step_dt={dt} steps={steps} r={B_R} mass(model)={bmass:.2f} gap={GAP} lat_jit={LAT_JIT} v0={V0} acc={ACC} vmax={VMAX} "
              f"cmd_vx={CMD_VX} reflex={REFLEX} tau={TAU} dodge=({DODGE_VX},{DODGE_VY},{DODGE_S}s) control={CONTROL} boulder_geom={bgid} robot_geoms={len(rgeoms)}", flush=True)

        def contact_flags():
            """per env: any contact between the boulder geom and a robot geom in the last substep (mujoco_warp contact buffer)."""
            try:
                d = base.sim.data
                nac = int(d.nacon.cpu().numpy().reshape(-1)[0])
                cg = d.contact.geom.cpu().numpy()[:nac]
                cw = d.contact.worldid.cpu().numpy()[:nac]
                out = np.zeros(n, dtype=bool)
                for (a, b), w in zip(cg, cw):
                    if (a == bgid and b in rgeoms) or (b == bgid and a in rgeoms):
                        out[int(w)] = True
                return out
            except Exception as e:  # noqa: BLE001
                if not getattr(contact_flags, "warned", False):
                    print(f"[boulder] contact read failed ({e}); falling back to clearance only", flush=True)
                    contact_flags.warned = True
                return np.zeros(n, dtype=bool)

        writer = renderer = None
        if do_render:
            import imageio_ffmpeg
            from PIL import Image, ImageDraw, ImageFont

            model.vis.global_.offwidth = max(W, model.vis.global_.offwidth)
            model.vis.global_.offheight = max(H, model.vis.global_.offheight)
            for gi in range(model.ngeom):
                if model.geom_type[gi] == mujoco.mjtGeom.mjGEOM_PLANE:
                    model.geom_matid[gi] = -1
                    model.geom_rgba[gi] = [floor_rgb[0], floor_rgb[1], floor_rgb[2], 1.0]
            HS = H - band_top - band_bot
            renderer = mujoco.Renderer(model, HS, W, max_geom=20000)
            renderer.scene.flags[mujoco.mjtRndFlag.mjRND_SHADOW] = 1
            data = mujoco.MjData(model)
            cam = mujoco.MjvCamera()
            mujoco.mjv_defaultFreeCamera(model, cam)
            cam.type = mujoco.mjtCamera.mjCAMERA_FREE.value
            bold = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
            fdir = os.path.expanduser("~/promo-pilot/duck-bigaim-2026-10-28/fonts")
            try:
                anton = [os.path.join(fdir, f) for f in os.listdir(fdir) if f.lower().startswith("anton")]
                f_big = ImageFont.truetype(anton[0] if anton else bold, 80)
            except Exception:  # noqa: BLE001
                f_big = ImageFont.truetype(bold, 80)
            f_pill = ImageFont.truetype(bold, 30)
            writer = imageio_ffmpeg.write_frames(
                out_path, (W, H), fps=fps, codec="libx264", pix_fmt_in="rgb24", pix_fmt_out="yuv420p", macro_block_size=1,
                output_params=["-crf", str(crf), "-preset", "medium", "-movflags", "+faststart"],
            )
            writer.send(None)
        writer2 = None
        if do_render and OUT2:
            writer2 = imageio_ffmpeg.write_frames(
                OUT2, (W, H), fps=fps, codec="libx264", pix_fmt_in="rgb24", pix_fmt_out="yuv420p", macro_block_size=1,
                output_params=["-crf", str(crf), "-preset", "medium", "-movflags", "+faststart"],
            )
            writer2.send(None)

        def _hud(img, k, gapv, touch):
            im = Image.new("RGB", (W, H), (8, 12, 9))
            im.paste(Image.fromarray(img), (0, band_top))
            dr = ImageDraw.Draw(im, "RGBA")
            ty = (band_top - 80) // 2 - 12
            dr.text((48, ty), f"T {(k + 1) * dt:3.1f} S", font=f_big, fill=(190, 255, 70, 255))
            gtxt = f"BOULDER {max(0.0, gapv):.2f} M BEHIND" if gapv > 0 else ("PASSED" if not touch else "HIT")
            tw = dr.textlength(gtxt, font=f_big)
            dr.text((W - 48 - tw, ty), gtxt, font=f_big, fill=(244, 241, 232, 255))
            ptxt = "SIMULATION ONLY"
            pw = dr.textlength(ptxt, font=f_pill)
            px0, py0 = (W - pw) / 2 - 26, band_top / 2 - 27
            dr.rounded_rectangle([px0, py0, px0 + pw + 52, py0 + 54], radius=27, fill=(244, 241, 232, 255))
            dr.text((px0 + 26, py0 + 27), ptxt, font=f_pill, fill=(8, 12, 9, 255), anchor="lm")
            dr.text((48, H - band_bot / 2), (LABEL or f"one Microduck, a {int(B_R * 200)} cm boulder"), font=f_pill, fill=(244, 241, 232, 255), anchor="lm")
            return im

        stride = max(1, int(round(1.0 / (fps * dt))))
        still_set = {int(v) for v in stills_arg.split(",")} if stills_arg else set()
        lerp = lambda a, b, p: a + (b - a) * p  # noqa: E731

        trig_t = torch.full((n,), -1.0, device=dev)
        dodge_dir = torch.zeros(n, device=dev)
        clear_min = torch.full((n,), 9.0, device=dev)
        touched = np.zeros(n, dtype=bool)
        touch_t = [None] * n
        tilt_max = torch.zeros(n, device=dev)
        z_log, tilt_log = [], []
        cam_c = None
        frame_no = 0
        with torch.inference_mode():
            obs, _ = self.env.reset()
            term.is_standing_env[:] = False  # reset drew rel_standing_envs (0.25 in the built term): a standing env zeroes its command every step
            term.vel_command_b[:, :] = 0.0
            for k in range(steps):
                t = k * dt
                vb = min(VMAX, V0 + ACC * t)
                # scripted roll
                vel = torch.zeros(n, 6, device=dev)
                vel[:, 0] = vb
                vel[:, 4] = vb / B_R
                ball.write_root_link_velocity_to_sim(vel)
                # sense (privileged: the controller reads the ball's world position, as a Hermes-written reflex would from the state feed)
                rp = robot.data.root_link_pos_w
                bp = ball.data.root_link_pos_w
                dvx = robot.data.root_link_lin_vel_w[:, 0]
                gap_c = (rp[:, 0] - bp[:, 0]) - B_R  # surface to trunk along x
                closing = torch.clamp(vb - dvx, min=0.05)
                tau_c = gap_c / closing
                cmd = torch.zeros(n, 3, device=dev)
                cmd[:, 0] = CMD_VX
                if HOLD:
                    hd = robot.data.heading_w
                    cmd[:, 2] = torch.clamp(-HOLD_K * torch.atan2(torch.sin(hd), torch.cos(hd)), -0.6, 0.6)
                if RF is not None:
                    rpn = (rp - origins).cpu().numpy()
                    bpn = (bp - origins).cpu().numpy()
                    dvn = robot.data.root_link_lin_vel_w.cpu().numpy()
                    hdn = hd.cpu().numpy() if HOLD else robot.data.heading_w.cpu().numpy()
                    hdn = np.arctan2(np.sin(hdn), np.cos(hdn))
                    for i in range(n):
                        try:
                            c3 = RF.reflex(env=i, t=float(t), duck_x=float(rpn[i, 0]), duck_y=float(rpn[i, 1]), duck_vx=float(dvn[i, 0]), duck_vy=float(dvn[i, 1]),
                                           heading=float(hdn[i]), ball_x=float(bpn[i, 0]), ball_y=float(bpn[i, 1]), ball_vx=float(vb), ball_r=float(B_R))
                        except Exception as e:  # noqa: BLE001
                            if not getattr(self, "_rf_err", False):
                                print(f"[boulder] REFLEX FILE ERROR {type(e).__name__}: {e}", flush=True)
                                self._rf_err = True
                            c3 = (CMD_VX, 0.0, 0.0)
                        cmd[i, 0] = max(-0.4, min(0.4, float(c3[0])))
                        cmd[i, 1] = max(-0.3, min(0.3, float(c3[1])))  # the policy's trained lateral range
                        cmd[i, 2] = max(-1.0, min(1.0, float(c3[2])))
                elif REFLEX:
                    new = (trig_t < 0) & (tau_c < TAU) & (gap_c > -0.2)
                    if new.any():
                        trig_t[new] = t
                        dodge_dir[new] = torch.where(rp[new, 1] - bp[new, 1] >= 0.0, 1.0, -1.0)
                    active = (trig_t >= 0) & ((t - trig_t) < DODGE_S)
                    cmd[active, 0] = DODGE_VX
                    cmd[active, 1] = dodge_dir[active] * DODGE_VY
                term.vel_command_b[:, :] = cmd
                actions = self.policy(obs)
                out = self.env.step(actions)
                obs = out[0]
                if k == 5 or k == 100:
                    try:
                        print(f"[boulder] DBG k={k} is_standing_env sum={int(term.is_standing_env.sum())} rel_standing={getattr(term.cfg, 'rel_standing_envs', None)} "
                              f"cmd[:6]={term.vel_command_b[:6].cpu().numpy().round(2).tolist()} x[:6]={(robot.data.root_link_pos_w[:6, 0] - origins[:6, 0]).cpu().numpy().round(3).tolist()}", flush=True)
                    except Exception as e:  # noqa: BLE001
                        print(f"[boulder] DBG failed {e}", flush=True)
                rp = robot.data.root_link_pos_w
                bp = ball.data.root_link_pos_w
                d_planar = torch.sqrt((rp[:, 0] - bp[:, 0]) ** 2 + (rp[:, 1] - bp[:, 1]) ** 2)
                clear = d_planar - B_R
                clear_min = torch.minimum(clear_min, clear)
                gz = robot.data.projected_gravity_b[:, 2]
                tilt = torch.rad2deg(torch.acos(torch.clamp(-gz, -1.0, 1.0)))
                tilt_max = torch.maximum(tilt_max, tilt)
                cf = contact_flags()
                for e in np.nonzero(cf & ~touched)[0]:
                    touched[e] = True
                    touch_t[e] = (k + 1) * dt
                zrel = (rp[:, 2] - origins[:, 2]).cpu().numpy().copy()
                z_log.append(zrel)
                tilt_log.append(tilt.cpu().numpy().copy())
                if k % log_every == 0:
                    e = render_env if render_env < n else 0
                    print(f"[boulder] t={(k + 1) * dt:5.2f}s env{e} duck=({float(rp[e, 0] - origins[e, 0]):+.3f},{float(rp[e, 1] - origins[e, 1]):+.3f},{float(rp[e, 2]) * 1000 - 0:6.1f}mm) "
                          f"ball=({float(bp[e, 0] - origins[e, 0]):+.3f},{float(bp[e, 1] - origins[e, 1]):+.3f}) vb={float(ball.data.root_link_lin_vel_w[e, 0]):+.3f} gap={float(gap_c[e]):+.3f} "
                          f"tau={float(tau_c[e]):5.2f} clear={float(clear[e]):+.3f} tilt={float(tilt[e]):5.1f} trig={float(trig_t[e]):.2f} touched={bool(touched[e])}", flush=True)
                if do_render and (k + 1) % stride == 0:
                    e = render_env
                    p = (k + 1) / steps
                    for (pa, *va), (pb, *vb_) in zip(CAM_KEYS[:-1], CAM_KEYS[1:]):
                        if p <= pb or (pb, *vb_) == CAM_KEYS[-1]:
                            q = min(1.0, max(0.0, (p - pa) / max(1e-6, pb - pa)))
                            q = q * q * (3 - 2 * q)
                            dist, elev, azim, dx, dz = [lerp(a, b, q) for a, b in zip(va, vb_)]
                            break
                    tgt = np.array([float(rp[e, 0]), float(rp[e, 1])])
                    cam_c = tgt if cam_c is None else cam_c + 0.12 * (tgt - cam_c)
                    cam.lookat[:] = (cam_c[0] + dx, (cam_c[1] if TRACKY else 0.0), dz)
                    cam.distance, cam.elevation, cam.azimuth = dist, elev, azim
                    qpos = base.sim.data.qpos[e].cpu().numpy()
                    data.qpos[:] = qpos
                    mujoco.mj_kinematics(model, data)
                    renderer.update_scene(data, camera=cam)
                    img = renderer.render()
                    im = _hud(img, k, float(gap_c[e]), bool(touched[e]))
                    writer.send(np.asarray(im).tobytes())
                    if frame_no in still_set:
                        im.save(out_path.rsplit(".", 1)[0] + f"-f{frame_no:04d}.png")
                    if writer2 is not None:
                        d2, el2, az2, dx2, dz2 = CAM2
                        cam.lookat[:] = (cam_c[0] + dx2, 0.0, dz2)
                        cam.distance, cam.elevation, cam.azimuth = d2, el2, az2
                        renderer.update_scene(data, camera=cam)
                        im2 = _hud(renderer.render(), k, float(gap_c[e]), bool(touched[e]))
                        writer2.send(np.asarray(im2).tobytes())
                        if frame_no in still_set:
                            im2.save(out_path.rsplit(".", 1)[0] + f"-plan-f{frame_no:04d}.png")
                    frame_no += 1
        if writer is not None:
            writer.close()
            print(f"[boulder] wrote {out_path} frames={frame_no}", flush=True)
        if writer2 is not None:
            writer2.close()
            print(f"[boulder] wrote {OUT2}", flush=True)
        z = np.stack(z_log) * 1000.0  # (steps, n) mm
        tl = np.stack(tilt_log)
        settle = int(round(0.5 / dt))
        rp = robot.data.root_link_pos_w
        bp = ball.data.root_link_pos_w
        dxy = (rp - origins).cpu().numpy()
        bxy = (bp - origins).cpu().numpy()
        cm = clear_min.cpu().numpy()
        tm = tilt_max.cpu().numpy()
        zmed = np.median(z[settle:], axis=0)
        low = (z[settle:] < 0.8 * Z_STAND_MM).mean(axis=0)
        print("[boulder] per-env: env  hit(contact) clear_min_m tilt_max_deg trunk_z_med_mm low_share duck_end_xy boulder_end_x passed trig_t", flush=True)
        passed = bxy[:, 0] > dxy[:, 0] + 0.3
        for e in range(n):
            print(f"[boulder]   env{e:02d} touched={bool(touched[e])}@{touch_t[e]} clear_min={cm[e]:+.3f} tilt_max={tm[e]:5.1f} z_med={zmed[e]:6.1f} low={low[e]:.2f} "
                  f"duck_end=({dxy[e, 0]:+.2f},{dxy[e, 1]:+.2f}) boulder_end_x={bxy[e, 0]:+.2f} passed={bool(passed[e])} trig={float(trig_t[e]):.2f}", flush=True)
        up = tm <= 60.0
        tall = (zmed >= 0.9 * Z_STAND_MM) & (low <= 0.10)
        clean = ~touched
        success = clean & up & tall & (passed | bool(CONTROL))
        print(f"[boulder] RESULT config reflex={REFLEX} tau={TAU} dodge=({DODGE_VX},{DODGE_VY},{DODGE_S}) r={B_R} mass={B_MASS} gap={GAP} v0={V0} acc={ACC} vmax={VMAX} cmd_vx={CMD_VX} control={CONTROL} n={n}", flush=True)
        print(f"[boulder] RESULT touched={int(touched.sum())}/{n} up(tilt<=60)={int(up.sum())}/{n} tall={int(tall.sum())}/{n} passed={int(passed.sum())}/{n} "
              f"SUCCESS(clean+up+tall+passed)={int(success.sum())}/{n} clear_min_med={np.median(cm):+.3f} z_med_of_envs={np.median(zmed):.1f} mm (Z_STAND used {Z_STAND_MM:.1f}) "
              f"duck_dx_med={np.median(dxy[:, 0]):+.2f} m", flush=True)
        print("[boulder] done", flush=True)


_RealEnv = play.ManagerBasedRlEnv


def _env_hook(cfg, **kw):
    cfg.terminations = {}
    cfg.episode_length_s = dur + 30.0
    pr = cfg.events["reset_base"].params["pose_range"]
    pr["x"], pr["y"], pr["yaw"] = (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)
    cfg.events.pop("push_robot", None)
    if isinstance(cfg.curriculum, dict):
        for cname, ct in list(cfg.curriculum.items()):
            if (getattr(ct, "params", None) or {}).get("event_name") == "push_robot":
                cfg.curriculum.pop(cname)
    tw = cfg.commands["twist"]
    tw.ranges.lin_vel_x, tw.ranges.lin_vel_y, tw.ranges.ang_vel_z = (CMD_VX, CMD_VX), (0.0, 0.0), (0.0, 0.0)
    for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs", "rel_forward_envs", "rel_world_envs"):
        if hasattr(tw, k):
            setattr(tw, k, 0.0)
    tw.resampling_time_range = (1.0e6, 1.0e6)
    print(f"[boulder] twist cfg {type(tw).__name__} rel_standing_envs={getattr(tw, 'rel_standing_envs', 'n/a')} fields={[f for f in dir(tw) if f.startswith('rel_')]}", flush=True)
    cfg.scene.entities["boulder"] = EntityCfg(spec_fn=_boulder_spec, init_state=EntityCfg.InitialStateCfg(pos=(-(GAP + B_R), 0.0, B_R)))
    if do_render and LANES:
        cfg.scene.entities["lanes"] = EntityCfg(spec_fn=_lanes_spec, init_state=EntityCfg.InitialStateCfg(pos=(0.0, 0.0, 0.0)))
    cfg.events["reset_boulder"] = EventTermCfg(func=reset_boulder, mode="reset", params={})
    cfg.scene.env_spacing = max(8.0, getattr(cfg.scene, "env_spacing", 4.0))
    print(f"[boulder] cfg: events={list(cfg.events.keys())} nconmax={cfg.sim.nconmax}", flush=True)
    return _RealEnv(cfg=cfg, **kw)


play.ManagerBasedRlEnv = _env_hook
play.ViserPlayViewer = BoulderViewer
play.NativeMujocoViewer = BoulderViewer
sys.argv = [sys.argv[0]] + argv + ["--viewer", "viser"]
play.main()
