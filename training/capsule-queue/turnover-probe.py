"""turnover-probe.py: v1 vs v2 supine_turnover_progress on the SAME rollouts.

Builds the v2 play env (Mjlab-StandUpBack2-Flat-MicroDuck) with N envs, forces
every spawn face_up (the set_ground_state mix, curriculum dropped, as in
headless_play.py --spawn face_up), runs a checkpoint's policy for STEPS steps
(< one 6 s episode, so no time_out reset inside the window) and computes per
env, from the same state each step:
  v1 = sum of Delta phi            (baseline reset only at episode step <= 1)
  v2 = sum of Delta (phi - running min phi)
independently of the env's own reward term, then cross-checks v2 against the
registered term's episode sum in the reward manager (weight x dt scaled).
Reports the spawn-settle window (first SETTLE steps) separately: that is the
drop the fix is about.

usage (from ~/Pollen/microduck_rl, MUJOCO_GL=egl):
  uv run python turnover-probe.py Mjlab-StandUpBack2-Flat-MicroDuck \
      --checkpoint-file <model_N.pt> --num-envs 256 [--probe-steps 290]
"""
import os
import sys

os.environ.setdefault("MUJOCO_GL", "egl")
argv = sys.argv[1:]


def take(flag, default, cast):
    if flag in argv:
        i = argv.index(flag)
        v = cast(argv[i + 1])
        del argv[i : i + 2]
        return v
    return default


STEPS = take("--probe-steps", 290, int)
SETTLE = take("--settle-steps", 25, int)  # 0.5 s at 50 Hz
ZF, ZZ = 0.09, 0.11

import mjlab.scripts.play as play  # noqa: E402


def phi_of(robot, base):
    import torch

    gx = torch.nan_to_num(robot.data.projected_gravity_b[:, 0], nan=0.0)
    z = torch.nan_to_num(robot.data.root_link_pos_w[:, 2] - base.scene.terrain.env_origins[:, 2], nan=1.0)
    t = torch.clamp((ZZ - z) / (ZZ - ZF), 0.0, 1.0)
    return torch.clamp(gx, max=0.0) * t * t * (3.0 - 2.0 * t), gx, z


class ProbeViewer:
    def __init__(self, env, policy, checkpoint_manager=None):
        self.env, self.policy = env, policy

    def run(self, num_steps=None, catch_sigint=True):
        import torch

        obs, _ = self.env.reset()
        base = self.env.unwrapped
        robot = base.scene["robot"]
        rm = base.reward_manager
        n = base.num_envs
        name = "supine_turnover_progress"
        w = rm._term_cfgs[rm._term_names.index(name)].weight if hasattr(rm, "_term_names") else None
        rm._episode_sums[name][:] = 0.0
        v1 = torch.zeros(n, device=base.device); v2 = torch.zeros(n, device=base.device)
        v1s = torch.zeros(n, device=base.device); v2s = torch.zeros(n, device=base.device)
        prev = None; mn = None; psi_prev = None
        resets = 0
        gx0 = None
        with torch.inference_mode():
            for k in range(STEPS):
                out = self.env.step(self.policy(obs))
                obs = out[0]
                if bool(out[2].any()) or (len(out) > 3 and hasattr(out[3], "any") and bool(out[3].any())):
                    resets += int(out[2].sum()) + (int(out[3].sum()) if len(out) > 3 and hasattr(out[3], "sum") else 0)
                phi, gx, z = phi_of(robot, base)
                if prev is None:  # first step after reset = episode step 1: baseline, no delta (both versions)
                    prev = phi.clone(); mn = phi.clone(); psi_prev = torch.zeros_like(phi); gx0 = gx.clone(); z0 = z.clone()
                    continue
                d1 = phi - prev; prev = phi.clone()
                mn = torch.minimum(mn, phi); psi = phi - mn; d2 = psi - psi_prev; psi_prev = psi
                v1 += d1; v2 += d2
                if k < SETTLE:
                    v1s += d1; v2s += d2
        reg = rm._episode_sums[name].clone()
        dt = base.step_dt
        f = lambda t: f"mean {float(t.mean()):+.4f}  min {float(t.min()):+.4f}  max {float(t.max()):+.4f}  neg {int((t < -1e-6).sum())}/{n}  pos {int((t > 1e-6).sum())}/{n}"
        print(f"[probe] envs={n} steps={STEPS} ({STEPS * dt:.2f} s) settle window={SETTLE} steps; terminations/timeouts in window: {resets}")
        print(f"[probe] spawn g_b.x at step 1: mean {float(gx0.mean()):+.3f} (min {float(gx0.min()):+.3f}, max {float(gx0.max()):+.3f}); trunk z mean {float(z0.mean())*1000:.1f} mm")
        phi, gx, z = phi_of(robot, base)
        print(f"[probe] end g_b.x mean {float(gx.mean()):+.3f}; trunk z mean {float(z.mean())*1000:.1f} mm; envs with z>0.10 m at end {int((z > 0.10).sum())}/{n}")
        print(f"[probe] v1 unscaled episode sum, settle window : {f(v1s)}")
        print(f"[probe] v2 unscaled episode sum, settle window : {f(v2s)}")
        print(f"[probe] v1 unscaled episode sum, whole window  : {f(v1)}")
        print(f"[probe] v2 unscaled episode sum, whole window  : {f(v2)}")
        if w is not None:
            exp = v2 * w * dt
            print(f"[probe] registered term episode sum (x w={w} x dt={dt}): mean {float(reg.mean()):+.5f} vs independent v2 x w x dt {float(exp.mean()):+.5f}; max |diff| {float((reg - exp).abs().max()):.2e}")
        print("[probe] done", flush=True)


def _env(cfg, **kw):
    ev = cfg.events["set_ground_state"]
    for k in ("standing_prob", "sitting_prob", "face_down_prob", "face_up_prob"):
        ev.params[k] = 0.0
    ev.params["face_up_prob"] = 1.0
    if hasattr(cfg.curriculum, "pop"):
        cfg.curriculum.pop("ground_state_mix", None)
    print("[probe] spawn forced: face_up; episode_length_s", cfg.episode_length_s, flush=True)
    return _RealEnv(cfg=cfg, **kw)


_RealEnv = play.ManagerBasedRlEnv
play.ManagerBasedRlEnv = _env
play.ViserPlayViewer = ProbeViewer
play.NativeMujocoViewer = ProbeViewer
sys.argv = [sys.argv[0]] + argv + ["--viewer", "viser"]
play.main()
