#!/usr/bin/env python3
"""make-gm-play-2026-10-28.py: generate microduck_rl/gm_play.py = headless_play.py + a `--gm-log` flag (per-step [gm] line) for the gale / moon proofs.

headless_play.py itself is not edited. [gm] line, one per 20 ms policy step (after the step):
  k t fwd lat z tilt lean air tq wind
  fwd/lat = trunk displacement from its post-reset position along / across the HEADING AT RESET (m), z = trunk height (mm), tilt = total trunk tilt (deg),
  lean = forward pitch from the projected gravity (deg, + = nose down = leaning forward), air = 1 when both feet have no ground contact (-1: no sensor),
  tq = peak servo torque (N m), wind = the gale event's force at this step (N; 0 when the task has none).
`--face-x`: spawn at the env origin with yaw 0 (fixed side camera).
usage: python3 make-gm-play-2026-10-28.py <headless_play.py> <out gm_play.py>
"""
import sys

src = open(sys.argv[1]).read()
n = 0


def sub(old, new):
    global src, n
    assert src.count(old) == 1, (src.count(old), old[:60])
    src = src.replace(old, new)
    n += 1


sub('no_bounds = "--no-bounds" in argv\n',
    'no_bounds = "--no-bounds" in argv\ngm_log = "--gm-log" in argv\nif gm_log:\n    argv.remove("--gm-log")\n')
sub("        with torch.inference_mode():\n            for k in range(steps):\n                actions = self.policy(obs)\n",
    '''        if gm_log:
            import math as _m
            _sensors = base.scene.sensors if hasattr(base.scene, "sensors") else {}
            _sensor = _sensors["feet_ground_contact"] if "feet_ground_contact" in _sensors else None
            _names = [n_ for n_ in robot.joint_names if not n_.startswith("passive_")]
            _vadr = robot.indexing.joint_v_adr[torch.tensor([robot.joint_names.index(n_) for n_ in _names], device=base.device)]
            _o = base.scene.terrain.env_origins[0]
            _q0 = robot.data.root_link_quat_w[0]
            _yaw0 = float(torch.atan2(2.0 * (_q0[0] * _q0[3] + _q0[1] * _q0[2]), 1.0 - 2.0 * (_q0[2] ** 2 + _q0[3] ** 2)))
            _p00 = robot.data.root_link_pos_w[0]
            _wind_fn = None
            try:
                from mjlab_microduck.tasks.witcheer_velocity_gale_env_cfg import wind_force_now as _wind_fn
            except Exception:  # noqa: BLE001
                _wind_fn = None
            print(f"[gm] log on: {len(_names)} servos, sensor={'yes' if _sensor is not None else 'none'}, yaw0={_yaw0:+.3f} rad, gravity_z={float(base.sim.mj_model.opt.gravity[2]):+.3f}", flush=True)
        with torch.inference_mode():
            for k in range(steps):
                actions = self.policy(obs)
''')
sub("                obs = out[0]\n                # a termination",
    '''                obs = out[0]
                if gm_log:
                    _p = robot.data.root_link_pos_w[0]
                    _dx, _dy = float(_p[0] - _p00[0]), float(_p[1] - _p00[1])
                    _fwd = _dx * _m.cos(_yaw0) + _dy * _m.sin(_yaw0)
                    _lat = -_dx * _m.sin(_yaw0) + _dy * _m.cos(_yaw0)
                    _q = robot.data.root_link_quat_w[0]
                    _tilt = float(torch.acos(torch.clamp(1.0 - 2.0 * (_q[1] ** 2 + _q[2] ** 2), -1.0, 1.0))) * 57.29578
                    _gb = robot.data.projected_gravity_b[0]
                    _lean = _m.degrees(_m.asin(max(-1.0, min(1.0, float(_gb[0])))))
                    _air = -1 if _sensor is None else int(float(_sensor.data.found[0].sum()) == 0.0)
                    _tq = float(base.sim.data.qfrc_actuator[0, _vadr].abs().max())
                    _w = float(_wind_fn(base)[0]) if _wind_fn is not None and hasattr(base, "_gale_peak") else 0.0
                    print(f"[gm] k={k:4d} t={k * dt:6.2f} fwd={_fwd:+7.3f} lat={_lat:+7.3f} z={float(_p[2] - _o[2]) * 1000.0:6.1f} tilt={_tilt:5.1f} lean={_lean:+6.1f} air={_air:2d} tq={_tq:5.3f} wind={_w:5.2f}", flush=True)
                # a termination''')
sub('gm_log = "--gm-log" in argv\nif gm_log:\n    argv.remove("--gm-log")\n',
    'gm_log = "--gm-log" in argv\nif gm_log:\n    argv.remove("--gm-log")\nface_x = "--face-x" in argv\nif face_x:\n    argv.remove("--face-x")\n')
sub("    if no_push:\n        dropped = cfg.events.pop(\"push_robot\", None)",
    "    if face_x:\n        _pr = cfg.events[\"reset_base\"].params[\"pose_range\"]\n        _pr[\"x\"], _pr[\"y\"], _pr[\"yaw\"] = (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)\n        print(\"[headless_play] face-x: spawn at the env origin, yaw 0 (the duck faces +x), so a fixed side camera sees the lean\", flush=True)\n    if no_push:\n        dropped = cfg.events.pop(\"push_robot\", None)")
open(sys.argv[2], "w").write(src)
print(f"gm_play written: {n} patches -> {sys.argv[2]}")
