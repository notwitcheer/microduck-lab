"""hop-feasibility-2026-10-27.py: can the Microduck's simulated actuators put BOTH feet in the air at all?

Open-loop CEM search over a parametrised squat-and-extend trajectory (mirrored legs, joint-target offsets from the default
pose, 50 Hz targets) in the REAL backlash walk env (BAM xl330 actuators, default DR incl. battery voltage, gear play).
4096 envs, one parameter set each. No policy, no reward: this only measures what the physics allows.

Per env it records: longest run of consecutive policy steps (20 ms) with BOTH feet out of contact (the `feet_ground_contact`
sensor `found`), peak base lift above the settled stance in mm, peak |joint torque| per joint (N m), the battery voltage of
that env, tilt at the end. Fitness for the search = max over time of the LOWER foot's height above its rest height (dense
gradient before any flight exists) + 10 * flight steps.
usage (from ~/Pollen/microduck_rl): uv run python ~/Pollen/hop-feasibility-2026-10-27.py [gens] [envs] [out.json]
"""
import json
import math
import sys
import time

import torch

import mjlab_microduck.tasks  # noqa: F401
from mjlab.envs import ManagerBasedRlEnv
from mjlab.tasks import registry

GENS = int(sys.argv[1]) if len(sys.argv) > 1 else 14
N = int(sys.argv[2]) if len(sys.argv) > 2 else 4096
OUT = sys.argv[3] if len(sys.argv) > 3 else "/home/witcheer/Pollen/hop-feasibility-2026-10-27.json"
import os
T = os.environ.get("HOP_FEAS_TASK", "Mjlab-Velocity-Flat-Backlash-MicroDuck")
STEPS = 150  # 3.0 s
SETTLE = 12
Z_REST = 0.115
FZ_REST = 0.0222
dev = "cuda:0"

cfg = registry.load_env_cfg(T, play=False)
cfg.scene.num_envs = N
cfg.events.pop("push_robot", None)
for k in ("fell_over", "out_of_terrain_bounds", "nan_state"):
    cfg.terminations.pop(k, None)
cfg.episode_length_s = 60.0
env = ManagerBasedRlEnv(cfg=cfg, device=dev)
robot = env.scene["robot"]
contact = env.scene["feet_ground_contact"]

names = [n for n in robot.joint_names if not n.startswith("passive_")]
idx = {n: i for i, n in enumerate(names)}
print("actuated order", names)
L = [idx["left_hip_pitch"], idx["left_knee"], idx["left_ankle"]]
R = [idx["right_hip_pitch"], idx["right_knee"], idx["right_ankle"]]
VADR = robot.indexing.joint_v_adr[torch.tensor([robot.joint_names.index(n) for n in names], device=dev)]
foot_bodies = robot.find_bodies(["ankle_left", "ankle_right"], preserve_order=True)[0]
print("foot bodies", [robot.body_names[i] for i in foot_bodies])

# actuator vin per env (battery voltage DR)
vin = None
for a in getattr(robot, "_actuators", []) or []:
    if hasattr(a, "vin_tensor") and a.vin_tensor is not None:
        vin = a.vin_tensor.view(-1).clone()
if vin is None:
    vin = torch.full((N,), float("nan"), device=dev)

# parameter bounds: [crouch dh dk da, extend dh dk da, t_ramp_c, t_hold_c, t_ramp_e, t_hold_e]
LO = torch.tensor([-1.2, -1.2, -1.2, -1.2, -1.2, -1.2, 0.20, 0.0, 0.03, 0.10], device=dev)
HI = torch.tensor([1.2, 1.2, 1.2, 1.2, 1.2, 1.2, 0.60, 0.40, 0.25, 0.40], device=dev)


def traj(params, t):
    """params (N,10), t scalar seconds -> (N,3) delta (hp,kn,an) for the left leg."""
    crouch, ext = params[:, 0:3], params[:, 3:6]
    rc, hc, re, he = params[:, 6:7], params[:, 7:8], params[:, 8:9], params[:, 9:10]
    t0 = torch.full_like(rc, t)
    a = torch.clamp(t0 / rc, 0, 1)  # ramp to crouch
    d = crouch * a
    s = rc + hc  # start of the extension ramp
    b = torch.clamp((t0 - s) / re, 0, 1)
    d = d + (ext - crouch) * b
    tend = s + re + he
    c = torch.clamp((t0 - tend) / 0.15, 0, 1)  # back to default
    d = d * (1 - c)
    return d


TRACE = []
def rollout(params, trace=False):
    env.reset()
    asset = robot
    z0 = None
    best_run = torch.zeros(N, device=dev)
    run = torch.zeros(N, device=dev)
    zmax = torch.full((N,), -1e9, device=dev)
    fz_max = torch.full((N,), -1e9, device=dev)
    tq = torch.zeros(N, 14, device=dev)
    tilt_max = torch.zeros(N, device=dev)
    for k in range(STEPS):
        t = k * 0.02
        d = traj(params, t)
        act = torch.zeros(N, 14, device=dev)
        act[:, L] = d
        act[:, R] = -d
        env.step(act)
        z = asset.data.root_link_pos_w[:, 2]
        fz = asset.data.body_link_pos_w[:, foot_bodies, 2].min(dim=1).values  # lower foot
        quat = asset.data.root_link_quat_w
        tilt = torch.acos(torch.clamp(1.0 - 2.0 * (quat[:, 1] ** 2 + quat[:, 2] ** 2), -1, 1))
        valid = (tilt < 0.6) & (z > 0.06) & (z < 0.30)  # upright and not through the floor
        # settle window: the spawn is ~8 mm above the floor, every env is "airborne" for ~3 steps after reset. measure from step 12 (0.24 s)
        # against constants measured on the plane (trunk 115 mm, ankle body 22.2 mm when standing)
        meas = k >= SETTLE
        if meas:
            zmax = torch.maximum(zmax, torch.where(valid, z - Z_REST, torch.full_like(z, -1e9)))
            fz_max = torch.maximum(fz_max, torch.where(valid, fz - FZ_REST, torch.full_like(z, -1e9)))
        both_air = ((contact.data.found.sum(dim=1) == 0) & valid & meas).float()
        run = (run + 1) * both_air
        best_run = torch.maximum(best_run, run)
        tq = torch.maximum(tq, env.sim.data.qfrc_actuator[:, VADR].abs())
        tilt_max = torch.maximum(tilt_max, tilt)
        if trace:
            TRACE.append(dict(k=k, z=[round(float(v) * 1000, 1) for v in z[:3]], fz=[round(float(v) * 1000, 1) for v in fz[:3]], found=[[float(x) for x in contact.data.found[i]] for i in range(3)], tilt=[round(float(v) * 57.3, 1) for v in tilt[:3]], tq=[round(float(v), 2) for v in tq.max(dim=1).values[:3]]))
    tilt_end = tilt
    landed = ((tilt_end < 0.4) & (env.scene['robot'].data.root_link_pos_w[:, 2] > 0.09)).float()
    fit = torch.clamp(fz_max, min=-0.05) + 0.1 * 0.02 * 10 * best_run - 0.5 * (1 - landed)
    return dict(landed=landed, fit=fit, run=best_run, zmax=zmax, fzmax=fz_max, tq=tq, tilt_end=tilt_end, tilt_max=tilt_max)


BEST_ANY = dict(run=-1)
mu = (LO + HI) / 2
sd = (HI - LO) / 3
best = None
hist = []
t_start = time.time()
for g in range(GENS):
    if g == 0:
        params = LO + (HI - LO) * torch.rand(N, 10, device=dev)
    else:
        params = torch.clamp(mu + sd * torch.randn(N, 10, device=dev), LO, HI)
    r = rollout(params)
    fit = r["fit"]
    elite_n = max(8, N // 20)
    top = torch.topk(fit, elite_n).indices
    mu = params[top].mean(0)
    sd = torch.clamp(params[top].std(0), min=0.02)
    bi = int(top[0])
    ia = int(r['run'].argmax())
    if float(r['run'][ia]) > BEST_ANY['run']:
        BEST_ANY = dict(run=float(r['run'][ia]), params=params[ia].tolist(), landed=float(r['landed'][ia]), tilt_end=float(r['tilt_end'][ia]) * 57.3)
    nflight = int(((r["run"] >= 1) & (r["landed"] > 0)).sum())
    n3 = int(((r["run"] >= 3) & (r["landed"] > 0)).sum())
    hist.append(dict(gen=g, best_fit=float(fit[bi]), best_run_steps=float(r["run"][bi]), max_run_steps_any=float(r["run"].max()), max_run_steps_landed=float((r["run"] * r["landed"]).max()),
                     n_hop_landed_ge1=nflight, n_hop_landed_ge3=n3, n_flight_ge3_any=int((r["run"] >= 3).sum()), best_lift_mm=float(r["zmax"][bi] * 1000),
                     max_lift_mm=float(r["zmax"].max() * 1000), best_foot_lift_mm=float(r["fzmax"][bi] * 1000), t=time.time() - t_start))
    print(json.dumps(hist[-1]), flush=True)
    if best is None or float(fit[bi]) > best["fit"]:
        best = dict(fit=float(fit[bi]), params=params[bi].tolist(), run_steps=float(r["run"][bi]), lift_mm=float(r["zmax"][bi] * 1000),
                    foot_lift_mm=float(r["fzmax"][bi] * 1000), tilt_end_deg=float(r["tilt_end"][bi] * 57.2958),
                    tilt_max_deg=float(r["tilt_max"][bi] * 57.2958), vin=float(vin[bi]), peak_torque=[round(float(x), 3) for x in r["tq"][bi]])
        # elite flight stats of this generation
        el = top
        best["elite_vin_mean"] = float(vin[el].mean())
        best["elite_run_steps_mean"] = float(r["run"][el].mean())
        best["elite_lift_mm_mean"] = float((r["zmax"][el]).mean() * 1000)
        best["elite_peak_torque_max_over_joints_mean"] = float(r["tq"][el].max(dim=1).values.mean())
    # flight by battery voltage tercile (all envs this gen)
    if g == GENS - 1:
        v = vin.cpu()
        for lo, hi in ((6.5, 7.2), (7.2, 7.9), (7.9, 8.21)):
            m = (v >= lo) & (v < hi)
            rr = r["run"].cpu()[m]
            best.setdefault("flight_by_vin", {})[f"{lo}-{hi}"] = dict(n=int(m.sum()), frac_flight=float((rr >= 1).float().mean()), max_run=float(rr.max()) if len(rr) else 0.0)
        best["last_gen_peak_torque_p99_all_joints"] = float(torch.quantile(r["tq"].max(dim=1).values, 0.99))
# traces: (1) the best landed parameter set, (2) the set with the longest both-feet-off run (first 3 envs of a batch that all use it)
bp = torch.tensor(best["params"], device=dev).unsqueeze(0).repeat(N, 1)
rt = rollout(bp, trace=True); T1 = list(TRACE); TRACE.clear()
ba = torch.tensor(BEST_ANY["params"], device=dev).unsqueeze(0).repeat(N, 1)
rt = rollout(ba, trace=True); T2 = list(TRACE)
json.dump(dict(best=best, best_any=BEST_ANY, hist=hist, names=names, trace_best=T1, trace_any=T2), open(OUT, "w"), indent=1)
print("BEST", json.dumps(best))
print("HOP_FEAS_END")
