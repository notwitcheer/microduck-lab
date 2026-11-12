"""wipeout_count.py: 09z47 duck wipeout, the COUNTED run. 1,024 envs, one kinematic spinning bar per env (wipeout_common.py),
the stock walking policy (seed walk-flat v2 model_7000, md5 d16ed76e, NO training), terminations off, forced forward command
FWD_VX, no pushes. Survival per env = trunk height >= 0.90 x Z_STAND after TURNS revolutions of the bar (pre-registered, PREREG.md).

usage (from ~/Pollen/microduck_rl, MUJOCO_GL=egl):
  WIPE_W=3.0 uv run python wipeout_count.py Mjlab-Velocity-Flat-Backlash-MicroDuck --checkpoint-file <model_7000.pt> \
      --num-envs 1024 --label W3 --json <out.json>
Prints one `[wipe] RESULT` and one `[wipe] CONTACT` line; --json writes the same numbers as a json file.
"""
import json
import os
import sys

os.environ.setdefault("MUJOCO_GL", "egl")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
argv = sys.argv[1:]


def take(flag, default, cast):
    if flag in argv:
        i = argv.index(flag)
        val = cast(argv[i + 1])
        del argv[i : i + 2]
        return val
    return default


label = take("--label", "", str)
json_out = take("--json", "", str)
import wipeout_common as wc  # noqa: E402

import mjlab.scripts.play as play  # noqa: E402

_RealEnv = play.ManagerBasedRlEnv


class CountViewer:
    def __init__(self, env, policy, checkpoint_manager=None):
        self.env = env
        self.policy = policy

    def run(self, num_steps=None, catch_sigint=True):
        import numpy as np
        import torch

        base = self.env.unwrapped
        robot = base.scene["robot"]
        bar = base.scene["bar"]
        dt = base.step_dt
        steps = wc.revolution_steps(dt)
        n = base.num_envs
        d = base.sim.data
        bar_gid = np.asarray(bar.indexing.geom_ids.cpu().tolist(), dtype=np.int64)
        rob_gid = np.asarray(robot.indexing.geom_ids.cpu().tolist(), dtype=np.int64)
        print(f"[wipe] W={wc.W} rad/s TURNS={wc.TURNS} steps={steps} ({steps * dt:.2f} s) dt={dt} envs={n} "
              f"thr={wc.THR_M * 1000:.1f}mm fwd_vx={wc.FWD_VX} tip_speed={wc.W * wc.BAR_HALF_L:.2f}m/s", flush=True)
        obs, _ = self.env.reset()
        contact_steps = np.zeros(n, dtype=np.int64)
        with torch.inference_mode():
            for k in range(steps):
                obs = self.env.step(self.policy(obs))[0]
                nacon = int(d.nacon.reshape(-1)[0])
                if nacon:
                    geom = d.contact.geom.cpu().numpy()[:nacon].reshape(nacon, 2)
                    wid = d.contact.worldid.cpu().numpy()[:nacon].reshape(nacon)
                    hit = (np.isin(geom[:, 0], bar_gid) & np.isin(geom[:, 1], rob_gid)) | (
                        np.isin(geom[:, 1], bar_gid) & np.isin(geom[:, 0], rob_gid))
                    step_hit = np.zeros(n, dtype=bool)
                    step_hit[np.unique(wid[hit]).astype(np.int64)] = True
                    contact_steps += step_hit
                if k % 100 == 0:
                    print(f"[wipe] step {k}/{steps}", flush=True)
        z = robot.data.root_link_pos_w[:, 2].cpu().numpy()
        gz = robot.data.projected_gravity_b[:, 2].cpu().numpy()
        tilt = np.degrees(np.arccos(np.clip(-gz, -1.0, 1.0)))
        survive = z >= wc.THR_M
        n_s = int(survive.sum())
        res = dict(label=label, W=wc.W, turns=wc.TURNS, envs=n, standing=n_s, pct=round(100.0 * n_s / n, 2),
                   z_med_mm=round(float(np.median(z)) * 1000, 1), tilt_med_deg=round(float(np.median(tilt)), 1),
                   thr_mm=round(wc.THR_M * 1000, 1), fwd_vx=wc.FWD_VX, steps=steps, dt=dt,
                   contact_envs=int((contact_steps > 0).sum()), contact_steps_med=float(np.median(contact_steps)),
                   contact_steps_max=int(contact_steps.max()))
        print(f"[wipe] RESULT label={label} W={wc.W} turns={wc.TURNS} envs={n} standing={n_s}/{n} pct={res['pct']:.1f} "
              f"z_med_mm={res['z_med_mm']} tilt_med_deg={res['tilt_med_deg']} thr_mm={res['thr_mm']}", flush=True)
        print(f"[wipe] CONTACT label={label} W={wc.W} envs_with_bar_contact={res['contact_envs']}/{n} "
              f"contact_steps_med={res['contact_steps_med']:.1f} contact_steps_max={res['contact_steps_max']}", flush=True)
        if json_out:
            with open(json_out, "w") as f:
                json.dump(res, f, indent=1)
            print(f"[wipe] json {json_out}", flush=True)
        print("[wipe] done", flush=True)


def _env_hook(cfg, **kw):
    cfg.scene.env_spacing = wc.ENV_SPACING
    cfg.terminations = {}
    cfg.episode_length_s = wc.revolution_steps() * wc.POLICY_DT + 5.0
    pr = cfg.events["reset_base"].params["pose_range"]
    pr["x"], pr["y"], pr["yaw"] = (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)
    cfg.events.pop("push_robot", None)
    if isinstance(cfg.curriculum, dict):
        for cname, ct in list(cfg.curriculum.items()):
            if (getattr(ct, "params", None) or {}).get("event_name") == "push_robot":
                cfg.curriculum.pop(cname)
    tw = cfg.commands["twist"]
    tw.ranges.lin_vel_x, tw.ranges.lin_vel_y, tw.ranges.ang_vel_z = (wc.FWD_VX, wc.FWD_VX), (0.0, 0.0), (0.0, 0.0)
    for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs", "rel_forward_envs", "rel_world_envs"):
        if hasattr(tw, k):
            setattr(tw, k, 0.0)
    wc.add_bar(cfg)
    return _RealEnv(cfg=cfg, **kw)


play.ManagerBasedRlEnv = _env_hook
play.ViserPlayViewer = CountViewer
play.NativeMujocoViewer = CountViewer
sys.argv = [sys.argv[0]] + argv + ["--viewer", "viser"]
play.main()
