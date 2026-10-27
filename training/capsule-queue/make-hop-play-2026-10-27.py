#!/usr/bin/env python3
"""make-hop-play-2026-10-27.py: derive ~/Pollen/microduck_rl/hop_play.py from headless_play.py (never edits the shared recorder).

hop_play.py = headless_play.py + `--hop-log`: one `[hop]` line per 20 ms policy step with
  air=<1 when BOTH feet have no ground contact> z=<trunk mm above the env origin> fz=<lower sole site's height above its standing height, mm> tilt=<deg> zl=<left sole site height mm> zr=<right> tq=<max |motor torque| over the 14 servos, N m>
  fl=<left foot contact force N> fr=<right>
so a hop can be scored per step (flight ms, lift in mm, landing tilt, torque against the datasheet) from a take log.
usage on capsule: python3 ~/Pollen/make-hop-play-2026-10-27.py   (then: uv run python hop_play.py <task> ... --hop-log)
"""
import re
from pathlib import Path

src = Path.home() / "Pollen/microduck_rl/headless_play.py"
dst = Path.home() / "Pollen/microduck_rl/hop_play.py"
s = src.read_text()

# 1. flag
s = s.replace('no_push = "--no-push" in argv',
              'hop_log = "--hop-log" in argv\nif hop_log:\n    argv.remove("--hop-log")\nno_push = "--no-push" in argv', 1)

# 2. setup before the loop
setup = '''        if hop_log:
            _sensor = base.scene["feet_ground_contact"]
            _names = [n for n in robot.joint_names if not n.startswith("passive_")]
            _vadr = robot.indexing.joint_v_adr[torch.tensor([robot.joint_names.index(n) for n in _names], device=base.device)]
            _feet, _ = robot.find_sites(["left_foot", "right_foot"], preserve_order=True)
            _feet = torch.as_tensor(_feet, device=base.device, dtype=torch.long)
            print(f"[hop] log on: {len(_names)} servos", flush=True)
'''
s = s.replace("        with torch.inference_mode():\n            for k in range(steps):", setup + "        with torch.inference_mode():\n            for k in range(steps):", 1)

# 3. per step line, right after obs = out[0]
per = '''                if hop_log:
                    _found = _sensor.data.found[0]
                    _air = int(float(_found.sum()) == 0.0)
                    _q = robot.data.root_link_quat_w[0]
                    _tilt = float(torch.acos(torch.clamp(1.0 - 2.0 * (_q[1] ** 2 + _q[2] ** 2), -1.0, 1.0))) * 57.29578
                    _z = float(robot.data.root_link_pos_w[0, 2] - base.scene.terrain.env_origins[0, 2]) * 1000.0
                    _fz = (float(robot.data.site_pos_w[0, _feet, 2].min()) - 0.0005) * 1000.0
                    _zs = robot.data.site_pos_w[0, _feet, 2] * 1000.0
                    _tq = float(base.sim.data.qfrc_actuator[0, _vadr].abs().max())
                    _f = _sensor.data.force[0].norm(dim=-1)
                    print(f"[hop] k={k:4d} t={k * dt:6.2f} air={_air} z={_z:6.1f} fz={_fz:6.1f} tilt={_tilt:5.1f} zl={float(_zs[0]):6.1f} zr={float(_zs[1]):6.1f} tq={_tq:5.3f} fl={float(_f[0]):6.2f} fr={float(_f[1]):6.2f}", flush=True)
'''
s = s.replace("                obs = out[0]\n", "                obs = out[0]\n" + per, 1)
assert "_zs" in s and "_fz" in s and "hop_log" in s and "[hop] k=" in s and "_vadr" in s
dst.write_text(s)
print("wrote", dst, len(s.splitlines()), "lines")
