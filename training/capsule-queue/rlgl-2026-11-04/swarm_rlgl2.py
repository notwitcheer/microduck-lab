"""swarm_rlgl2.py: RED LIGHT, GREEN LIGHT physics for a field of walking ducks, trajectory dump only (2026-11-04, witcheer lane, simulation only).

derived from swarm_rlgl.py (2026-11-03). the render is split out (rlgl_render.py reads the dump and the saved MuJoCo model), so the picture can be
iterated without re-running the physics. policy: walk-flat v2 (`duckvelbl` model_7000, Mjlab-Velocity-Flat-Backlash-MicroDuck), blind to the game.
one duck per env (no duck-duck contact), grid at --spacing m. frozen params (pre-registered in 09z25-duck-rlgl.sh): grace 0.9 s, thr 0.06 m/s,
react median 0.2 s (lognormal sigma 0.6), 4 lights of 2 s red / 3 s green, 456 envs. survivor = never above thr after the grace in any red phase
and never tilted past 60 deg. eliminated ducks keep physics (command 0 from then on).

usage (from ~/Pollen/microduck_rl, CPU): CUDA_VISIBLE_DEVICES= .venv/bin/python swarm_rlgl2.py Mjlab-Velocity-Flat-Backlash-MicroDuck \
    --checkpoint-file <model_7000.pt> --device cpu --num-envs 456 --spacing 0.55 --grace 0.9 --react-med 0.2 --cycles 4 --traj rlgl-traj.npz --model-out duck.mjb
"""
import math
import os
import sys
import time

argv = sys.argv[1:]


def take(flag, default, cast):
    if flag in argv:
        i = argv.index(flag)
        val = cast(argv[i + 1])
        del argv[i : i + 2]
        return val
    return default


spacing = take("--spacing", 0.55, float)
cycles = take("--cycles", 4, int)
green_s = take("--green", 3.0, float)
red_s = take("--red", 2.0, float)
grace = take("--grace", 0.9, float)
thr = take("--thr", 0.06, float)
react_med = take("--react-med", 0.2, float)
react_sig = take("--react-sig", 0.6, float)
vmin = take("--vmin", 0.30, float)
vmax = take("--vmax", 0.40, float)
SEED = take("--seed", 1, int)
lead_in = take("--lead-in", 1.0, float)
HOLD_K = take("--hold-k", 1.5, float)
fps = take("--fps", 25, int)
traj_path = take("--traj", "rlgl-traj.npz", str)
TOTAL = take("--total-envs", 0, int)  # the whole field (default = --num-envs); a shard simulates a slice of it
SHARD = take("--shard", 0, int)
NSHARD = take("--shards", 1, int)
model_out = take("--model-out", "", str)

import numpy as np  # noqa: E402
import torch  # noqa: E402

import mjlab.scripts.play as play  # noqa: E402


def phase_at(t):
    if t < lead_in:
        return False, None
    u = t - lead_in
    per = red_s + green_s
    c = int(u // per)
    r = u - c * per
    if r < red_s:
        return True, lead_in + c * per
    return False, None


class RlglViewer:
    def __init__(self, env, policy, checkpoint_manager=None):
        self.env = env
        self.policy = policy

    def run(self, num_steps=None, catch_sigint=True):
        import mujoco

        base = self.env.unwrapped
        robot = base.scene["robot"]
        model = base.sim.mj_model
        n = base.num_envs
        dt = base.step_dt
        total = lead_in + cycles * (red_s + green_s)
        steps = int(round(total / dt))
        stride = max(1, int(round(1.0 / (fps * dt))))
        origins = base.scene.env_origins.cpu().numpy()
        term = base.command_manager.get_term("twist")
        dev = base.device
        g = torch.Generator(device="cpu").manual_seed(SEED)
        NT = TOTAL or n
        lo = SHARD * (NT // NSHARD)
        speed_all = vmin + (vmax - vmin) * torch.rand(NT, generator=g)
        react_all = torch.exp(math.log(react_med) + react_sig * torch.randn(NT, generator=g)).clamp(0.05, 1.5)
        speed_i = speed_all[lo : lo + n].to(dev)  # every duck of the field draws from ONE generator: a shard is a slice, results do not depend on the sharding
        react_i = react_all[lo : lo + n].to(dev)
        print(f"[rlgl] envs={n} spacing={spacing} step_dt={dt} total={total:.1f}s cycles={cycles} green={green_s} red={red_s} lead_in={lead_in} grace={grace} thr={thr} "
              f"react median {float(react_i.median()):.2f}s p90 {float(react_i.quantile(0.9)):.2f}s speed {vmin}-{vmax} seed={SEED} term.cfg.rel_standing_envs={term.cfg.rel_standing_envs}", flush=True)
        if model_out:
            mujoco.mj_saveModel(model, model_out)
            print(f"[rlgl] saved model {model_out} nq={model.nq}", flush=True)
        elim = torch.zeros(n, dtype=torch.bool, device=dev)
        fell = torch.zeros(n, dtype=torch.bool, device=dev)
        cyc_elim = [0] * cycles
        cyc_alive_at_end = [0] * cycles
        stop_lat = [[] for _ in range(cycles)]
        stopped_at = torch.full((n,), -1.0, device=dev)
        pos_hist = []
        walking_share_green = []
        qpos_frames, elim_frames, red_frames, t_frames, maxspd_after_grace = [], [], [], [], []
        t_wall = time.time()
        with torch.inference_mode():
            obs, _ = self.env.reset()
            term.is_standing_env[:] = False  # reset drew rel_standing_envs (0.25): a standing env zeroes its command every step
            term.vel_command_b[:, :] = 0.0
            for k in range(steps):
                t = k * dt
                red, t_red0 = phase_at(t)
                cyc = int((t_red0 - lead_in) // (red_s + green_s)) if red else None
                cmd = torch.zeros(n, 3, device=dev)
                hd = robot.data.heading_w
                cmd[:, 2] = torch.clamp(-HOLD_K * torch.atan2(torch.sin(hd), torch.cos(hd)), -0.6, 0.6)
                if red:
                    go = (t - t_red0) < react_i
                    go &= ~elim
                else:
                    go = ~elim
                cmd[:, 0] = torch.where(go, speed_i, torch.zeros_like(speed_i))
                term.vel_command_b[:, :] = cmd
                out = self.env.step(self.policy(obs))
                obs = out[0]
                rp = robot.data.root_link_pos_w
                xy = rp[:, :2]
                pos_hist.append(xy.clone())
                if len(pos_hist) > 5:
                    spd = torch.linalg.norm(xy - pos_hist[-6], dim=1) / (5 * dt)
                    pos_hist.pop(0)
                else:
                    spd = torch.zeros(n, device=dev)
                gz = robot.data.projected_gravity_b[:, 2]
                tilt = torch.rad2deg(torch.acos(torch.clamp(-gz, -1.0, 1.0)))
                newly_fell = (tilt > 60.0) & ~fell
                fell |= newly_fell
                if red and cyc is not None:
                    tt = (k + 1) * dt - t_red0
                    ok_stop = (spd < thr) & (stopped_at < 0) & (tt > 0.1)
                    stopped_at[ok_stop & ~elim] = tt
                    if tt > grace:
                        movers = (spd > thr) & ~elim
                        if movers.any():
                            elim |= movers
                            cyc_elim[cyc] += int(movers.sum())
                # a duck that tilts past 60 deg is out at once, in any phase (survivor = never tilted past 60 deg); counted against the current / last red light
                nf = newly_fell & ~elim
                if nf.any():
                    elim |= nf
                    cf = cyc if (red and cyc is not None) else max(0, min(cycles - 1, int((t - lead_in) // (red_s + green_s))))
                    cyc_elim[cf] += int(nf.sum())
                if red and cyc is not None and (k + 1) * dt >= t_red0 + red_s - 1e-6:
                    cyc_alive_at_end[cyc] = int((~elim).sum())
                if (not red) and k > 5 and k % 10 == 0:
                    walking_share_green.append(float(((spd > 0.2) & ~elim).float().sum() / max(1, int((~elim).sum()))))
                if (not red) and (stopped_at >= 0).any():
                    c_prev = int(((t - lead_in) // (red_s + green_s)))
                    vals = stopped_at[stopped_at >= 0].cpu().numpy()
                    if 0 <= c_prev < cycles:
                        stop_lat[c_prev] = vals.tolist()
                    stopped_at[:] = -1.0
                if (k + 1) % stride == 0:
                    qpos_frames.append(base.sim.data.qpos.cpu().numpy().astype(np.float32))
                    elim_frames.append(elim.cpu().numpy().copy())
                    red_frames.append(bool(red))
                    t_frames.append((k + 1) * dt)
                if (k + 1) % 50 == 0:
                    print(f"[rlgl] t={(k + 1) * dt:5.2f}s {'RED  ' if red else 'GREEN'} alive={int((~elim).sum())}/{n} eliminated={int(elim.sum())} fell={int(fell.sum())} "
                          f"walking(>0.2m/s)={int((spd > 0.2).sum())} wall={time.time() - t_wall:.0f}s", flush=True)
        el_end = elim.cpu().numpy()
        alive_frames = np.array([int((~e).sum()) for e in elim_frames])
        mono = bool(np.all(np.diff(alive_frames) <= 0))
        np.savez_compressed(traj_path, qpos=np.stack(qpos_frames), elim=np.stack(elim_frames), red=np.array(red_frames), t=np.array(t_frames), origins=origins,
                            react=react_i.cpu().numpy(), speed=speed_i.cpu().numpy(), fell=fell.cpu().numpy(), cycles=cycles,
                            cyc_elim=np.array(cyc_elim), cyc_alive_end=np.array(cyc_alive_at_end), shard=SHARD, nshard=NSHARD,
                            **{f"stop_lat_{c}": np.array(stop_lat[c], dtype=np.float32) for c in range(cycles)}, red_s=red_s, green_s=green_s, lead_in=lead_in,
                            grace=grace, thr=thr, spacing=spacing)
        print(f"[rlgl] wrote {traj_path} frames={len(t_frames)}", flush=True)
        print(f"[rlgl] RESULT field n={n} cycles={cycles} eliminated_total={int(el_end.sum())} ({100 * el_end.mean():.1f}%) fell_total={int(fell.sum())} survivors={int((~elim).sum())}", flush=True)
        print(f"[rlgl] RESULT counter_monotone={mono} alive_first={int(alive_frames[0])} alive_last={int(alive_frames[-1])} frames={len(alive_frames)}", flush=True)
        for c in range(cycles):
            sl = np.array(stop_lat[c]) if stop_lat[c] else np.array([float("nan")])
            print(f"[rlgl] RESULT cycle {c + 1}: eliminated {cyc_elim[c]} alive_at_end_of_red {cyc_alive_at_end[c]} stop_latency_med_s={np.nanmedian(sl):.2f} p90={np.nanpercentile(sl, 90):.2f} (ducks that stopped {len(stop_lat[c])})", flush=True)
        ws = np.array(walking_share_green) if walking_share_green else np.array([float("nan")])
        print(f"[rlgl] RESULT walking share of alive ducks during green (speed>0.2 m/s, 10-step samples): median {np.nanmedian(ws):.2f}", flush=True)
        print("[rlgl] done", flush=True)


_RealEnv = play.ManagerBasedRlEnv


def _env_hook(cfg, **kw):
    cfg.scene.env_spacing = spacing
    cfg.terminations = {}
    cfg.episode_length_s = 1000.0
    pr = cfg.events["reset_base"].params["pose_range"]
    pr["x"], pr["y"], pr["yaw"] = (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)
    cfg.events.pop("push_robot", None)
    if isinstance(cfg.curriculum, dict):
        for cname, ct in list(cfg.curriculum.items()):
            if (getattr(ct, "params", None) or {}).get("event_name") == "push_robot":
                cfg.curriculum.pop(cname)
    tw = cfg.commands["twist"]
    tw.ranges.lin_vel_x, tw.ranges.lin_vel_y, tw.ranges.ang_vel_z = (0.3, 0.3), (0.0, 0.0), (0.0, 0.0)
    for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs", "rel_forward_envs", "rel_world_envs"):
        if hasattr(tw, k):
            setattr(tw, k, 0.0)
    tw.resampling_time_range = (1.0e6, 1.0e6)
    return _RealEnv(cfg=cfg, **kw)


play.ManagerBasedRlEnv = _env_hook
play.ViserPlayViewer = RlglViewer
play.NativeMujocoViewer = RlglViewer
sys.argv = [sys.argv[0]] + argv + ["--viewer", "viser"]
play.main()
