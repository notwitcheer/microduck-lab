#!/usr/bin/env python3
"""duck-intents.py: a thin intent client for Pollen's Microduck `robotd`.

witcheer's robotics lane, phase 1. Talks to the SAME unix socket a real duck serves
(`/run/robotd.sock`) or the simulator's (`~/.cache/duck-sim/duck.sock`). Intents only:
it never touches the servo bus, it asks `robotd`, whose safety layer decides.

Wire contract (full, with file:line citations): docs/wire-contract.md
  JSON-RPC 2.0, one object per line (NDJSON), newline framing, unix socket.
  Continuous intents (robot.move, robot.head) go as notifications (no id, no reply).
  Discrete intents (robot.stop, robot.enable, robot.do, robot.look) go as requests.
  robotd zeroes the twist 500 ms after the last robot.move (deadman), so `walk`
  resends at 10 Hz, like Pollen's own `scripts/duck-sim drive`.

NOT Pollen's `duckctl` (their Rust BLE laptop client, crate `duckctl/`); renamed to avoid the clash.

stdlib only. Python 3.8+.

Exit codes mirror robotctl (robotctl/src/main.rs:52-67): 0 ok, 1 failed, 2 usage,
3 unreachable, 5 refused by the robot.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

EXIT_OK, EXIT_FAILED, EXIT_USAGE, EXIT_UNREACHABLE, EXIT_REFUSED = 0, 1, 2, 3, 5

API_VERSION = 28  # duck-ipc-proto/src/lib.rs:340 at microduck 6507d2e
REAL_SOCKET = "/run/robotd.sock"  # duck-ipc-proto/src/lib.rs:384
SIM_SOCKET = os.path.expanduser("~/.cache/duck-sim/duck.sock")  # scripts/duck-sim:32,58

# Client-side guard, NOT robotd's: robotd clamps no velocity (only the deadman touches the
# twist, duck-control/src/safety.rs:226-237). These are the command ranges the velocity task
# trains on (microduck_rl 53b8971 microduck_velocity_env_cfg.py:648-650); outside them the
# policy sees inputs it never trained on.
VX_MAX, VY_MAX, VYAW_MAX = 0.4, 0.3, 1.0
WALK_MAX_SECONDS = 30.0
RESEND_HZ = 10.0  # well inside the 500 ms deadman (robotd-params/src/lib.rs:1764)


class DuckError(Exception):
    def __init__(self, code: int, message: str):
        super().__init__(message)
        self.code = code


# ── transport ────────────────────────────────────────────────────────────────


class SshTunnel:
    """Forward a local unix socket to the robot's robotd socket over ssh.

    Shape: `ssh -N -o ExitOnForwardFailure=yes -o StreamLocalBindUnlink=yes
             -L <local.sock>:<remote.sock> <host>`
    OpenSSH >= 6.7 forwards unix sockets. The remote user must be able to open the remote
    socket (on a real duck `/run/robotd.sock` permissions are UNVERIFIED until it lands).
    """

    def __init__(self, host: str, remote_socket: str, wait_s: float = 10.0):
        if not shutil.which("ssh"):
            raise DuckError(EXIT_FAILED, "no ssh client on PATH")
        self.dir = tempfile.mkdtemp(prefix="duck-intents-")
        self.local = os.path.join(self.dir, "robotd.sock")
        self.proc = subprocess.Popen(
            [
                "ssh", "-N", "-o", "BatchMode=yes", "-o", "ExitOnForwardFailure=yes",
                "-o", "StreamLocalBindUnlink=yes",
                "-L", f"{self.local}:{remote_socket}", host,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        deadline = time.monotonic() + wait_s
        while time.monotonic() < deadline:
            if os.path.exists(self.local):
                return
            if self.proc.poll() is not None:
                err = self.proc.stderr.read().decode(errors="replace").strip()
                raise DuckError(EXIT_UNREACHABLE, f"ssh tunnel to {host} failed: {err}")
            time.sleep(0.1)
        self.close()
        raise DuckError(EXIT_UNREACHABLE, f"ssh tunnel to {host}: no local socket after {wait_s}s")

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        shutil.rmtree(self.dir, ignore_errors=True)


class Conn:
    """One NDJSON JSON-RPC connection to robotd.

    robotd serves one connection one request at a time and a subscribed connection also
    carries robot.state notifications (robotd/src/main.rs:3398-3557), so state reads use
    their own connection (see `read_state`).
    """

    def __init__(self, path: str, timeout: float = 5.0):
        self.path = path
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        try:
            self.sock.connect(path)
        except FileNotFoundError:
            raise DuckError(EXIT_UNREACHABLE, f"no socket at {path}: is robotd (or duck-sim) up?")
        except ConnectionRefusedError:
            raise DuckError(EXIT_UNREACHABLE, f"{path} exists but nothing accepts on it (dead daemon?)")
        except OSError as e:
            raise DuckError(EXIT_UNREACHABLE, f"cannot connect to {path}: {e}")
        self.rfile = self.sock.makefile("r", encoding="utf-8", newline="\n")
        self.next_id = 1

    def close(self):
        try:
            self.rfile.close()
        finally:
            self.sock.close()

    def _send(self, obj: dict):
        self.sock.sendall((json.dumps(obj, separators=(",", ":")) + "\n").encode())

    def notify(self, method: str, params: dict | None = None):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        self._send(msg)

    def readline(self) -> dict:
        try:
            line = self.rfile.readline()
        except socket.timeout:
            raise DuckError(EXIT_UNREACHABLE, f"robotd went quiet on {self.path}")
        if not line:
            raise DuckError(EXIT_UNREACHABLE, "robotd closed the connection")
        return json.loads(line)

    def call(self, method: str, params: dict | None = None):
        """Request with an id; skips notifications; returns `result` or raises on `error`."""
        rid = self.next_id
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self._send(msg)
        while True:
            reply = self.readline()
            if "id" not in reply:  # a notification (robot.state etc.), not our answer
                continue
            if reply.get("id") != rid:
                continue
            if reply.get("error"):
                err = reply["error"]
                raise DuckError(EXIT_FAILED, f"[{err.get('code')}] {err.get('message')}")
            return reply.get("result")


def read_state(path: str, hz: int = 10, frames: int = 1, timeout: float = 5.0) -> list[dict]:
    """Subscribe on a fresh connection, collect `frames` robot.state notifications, close."""
    c = Conn(path, timeout=timeout)
    try:
        ack = c.call("robot.subscribe", {"hz": hz})
        out = []
        while len(out) < frames:
            msg = c.readline()
            if msg.get("method") == "robot.state":
                out.append(msg["params"])
        if out:
            out[0]["_subscribe_ack"] = ack
        return out
    finally:
        c.close()


# ── helpers ──────────────────────────────────────────────────────────────────


def summarise(state: dict) -> dict:
    mv = state.get("move", {})
    sf = state.get("safety", {})
    lp = state.get("loop", {})
    od = state.get("odom", {})
    return {
        "t": round(state.get("t", 0.0), 2),
        "policy": state.get("policy"),
        "requested": [round(v, 3) for v in mv.get("requested", [])],
        "applied": [round(v, 3) for v in mv.get("applied", [])],
        "limited_by": mv.get("limited_by", []),
        "fallen": sf.get("fallen"),
        "limp": sf.get("limp"),
        "gravity": [round(v, 3) for v in sf.get("gravity", [])],
        "loop_hz": round(lp.get("hz", 0.0), 1),
        "missed": lp.get("missed"),
        "odom_xyz": [round(v, 3) for v in od.get("position", [])],
        "odom_yaw": round(od.get("yaw", 0.0), 3),
    }


def intent_outcome(result: dict, what: str) -> dict:
    if not isinstance(result, dict) or "accepted" not in result:
        raise DuckError(EXIT_FAILED, f"{what}: unexpected answer {result!r}")
    if not result["accepted"]:
        raise DuckError(EXIT_REFUSED, f"{what} refused by robotd: {result.get('reason') or 'no reason given'}")
    return result


def emit(obj):
    print(json.dumps(obj, indent=2, sort_keys=False))


# ── commands ─────────────────────────────────────────────────────────────────


def cmd_health(path: str, args) -> int:
    c = Conn(path)
    try:
        hello = c.call("hello", {"api_version": API_VERSION})
        health = c.call("robot.health")
        mode = c.call("robot.mode")
    finally:
        c.close()
    # posture comes from the state stream (policy label). "hardware_mode" is walk/roller locomotion
    # hardware, NOT posture: a local model read "mode: walk" as "standing" and walked a seated duck
    # (phase 1 exit test take 2, 2026-09-24), so health now says the posture outright.
    try:
        st = summarise(read_state(path, hz=10, frames=1)[0])
        posture = st.get("policy")
    except Exception as e:  # health must still answer if the stream is slow
        posture = f"unknown ({e})"
    emit({"socket": path, "hello": hello, "health": health, "posture": posture,
          "hardware_mode": mode})
    if hello.get("api_version") != API_VERSION:
        print(f"note: robotd speaks API v{hello.get('api_version')}, this client was written "
              f"against v{API_VERSION}", file=sys.stderr)
    return EXIT_OK if health.get("healthy") else EXIT_FAILED


def cmd_status(path: str, args) -> int:
    frames = read_state(path, hz=args.hz, frames=args.frames)
    ack = frames[0].pop("_subscribe_ack", None)
    if args.raw:
        emit({"subscribe_ack": ack, "frames": frames})
    else:
        emit({"subscribe_ack": ack, "frames": [summarise(f) for f in frames]})
    return EXIT_OK


def cmd_stand(path: str, args) -> int:
    before = summarise(read_state(path)[0])
    c = Conn(path)
    try:
        c.call("hello", {"api_version": API_VERSION})
        out = {"before": before}
        # robot.enable hands the robot to its policy; from a seated/limp start the standing
        # policy stands it up (scripts/duck-sim:364-384, robotctl/src/main.rs:438-458).
        out["robot.enable"] = intent_outcome(c.call("robot.enable", {"on": True, "toggle": False}), "robot.enable")
        # If the sitstand network holds it seated, the posture toggle is what rises.
        if before["policy"] in ("sit", "seated"):
            time.sleep(0.2)
            out["robot.do sit_toggle"] = intent_outcome(c.call("robot.do", {"skill": "sit_toggle"}), "robot.do sit_toggle")
    finally:
        c.close()
    time.sleep(args.settle)
    out["after"] = summarise(read_state(path)[0])
    emit(out)
    return EXIT_OK


def cmd_sit(path: str, args) -> int:
    before = summarise(read_state(path)[0])
    if before["policy"] in ("sit", "seated"):
        emit({"before": before, "note": "already sitting; nothing sent"})
        return EXIT_OK
    c = Conn(path)
    try:
        c.call("hello", {"api_version": API_VERSION})
        # sit_toggle is a toggle (robotd/src/control.rs:384-403), hence the state read above.
        res = intent_outcome(c.call("robot.do", {"skill": "sit_toggle"}), "robot.do sit_toggle")
    finally:
        c.close()
    time.sleep(args.settle)
    emit({"before": before, "robot.do sit_toggle": res, "after": summarise(read_state(path)[0])})
    return EXIT_OK


def cmd_walk(path: str, args) -> int:
    for name, val, lim in (("vx", args.vx, VX_MAX), ("vy", args.vy, VY_MAX), ("vyaw", args.vyaw, VYAW_MAX)):
        if not math.isfinite(val) or abs(val) > lim:
            raise DuckError(EXIT_USAGE, f"--{name} {val} outside the trained range +-{lim} (client guard)")
    if not (0 < args.seconds <= WALK_MAX_SECONDS):
        raise DuckError(EXIT_USAGE, f"--seconds must be in (0, {WALK_MAX_SECONDS}]")
    before = read_state(path)[0]
    before.pop("_subscribe_ack", None)
    c = Conn(path)
    samples = []
    stop_res = None
    try:
        c.call("hello", {"api_version": API_VERSION})
        period = 1.0 / RESEND_HZ
        t0 = time.monotonic()
        n = 0
        try:
            while time.monotonic() - t0 < args.seconds:
                c.notify("robot.move", {"vx": args.vx, "vy": args.vy, "vyaw": args.vyaw})
                n += 1
                if args.sample and n % int(RESEND_HZ) == 0:
                    samples.append(summarise(read_state(path)[0]))
                time.sleep(max(0.0, t0 + n * period - time.monotonic()))
        finally:
            # Deliberate stop, answered, rather than waiting out the deadman.
            stop_res = c.call("robot.stop")
    finally:
        c.close()
    time.sleep(0.6)
    after = read_state(path)[0]
    after.pop("_subscribe_ack", None)
    b, a = summarise(before), summarise(after)
    dx = [round(a["odom_xyz"][i] - b["odom_xyz"][i], 3) for i in range(min(len(a["odom_xyz"]), len(b["odom_xyz"])))]
    emit({
        "sent": {"robot.move": {"vx": args.vx, "vy": args.vy, "vyaw": args.vyaw},
                 "notifications": n, "hz": RESEND_HZ, "seconds": args.seconds},
        "robot.stop": stop_res,
        "before": b, "samples_1hz": samples, "after": a,
        "odom_delta_xyz": dx, "odom_delta_yaw": round(a["odom_yaw"] - b["odom_yaw"], 3),
    })
    return EXIT_OK


def cmd_look(path: str, args) -> int:
    if args.point is not None:
        x, y, z = args.point
    else:
        # robot.look takes a trunk-frame POINT, metres (duck-ipc-proto/src/lib.rs:2037-2052).
        # pitch/yaw -> a point `distance` m away: yaw positive = left (lib.rs:2001-2003),
        # pitch positive = up. The pitch sign convention is ours (INFERRED, not Pollen's);
        # the point is from the trunk origin, not the camera, so the gaze is approximate.
        d = args.distance
        x = d * math.cos(args.pitch) * math.cos(args.yaw)
        y = d * math.cos(args.pitch) * math.sin(args.yaw)
        z = d * math.sin(args.pitch)
    c = Conn(path)
    try:
        c.call("hello", {"api_version": API_VERSION})
        res = c.call("robot.look", {"x": x, "y": y, "z": z, "neck_pitch": args.neck_pitch})
    finally:
        c.close()
    emit({"point_trunk_m": [round(x, 3), round(y, 3), round(z, 3)], "robot.look": res})
    return EXIT_OK


def cmd_stop(path: str, args) -> int:
    c = Conn(path)
    try:
        c.call("hello", {"api_version": API_VERSION})
        res = intent_outcome(c.call("robot.stop"), "robot.stop")
    finally:
        c.close()
    emit({"robot.stop": res})
    return EXIT_OK


# ── cli ──────────────────────────────────────────────────────────────────────


def default_socket() -> str:
    env = os.environ.get("DUCKCTL_SOCKET")
    if env:
        return env
    if os.path.exists(SIM_SOCKET):
        return SIM_SOCKET
    return REAL_SOCKET


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="duck-intents.py", description="Intent client for Microduck robotd (sim or real).")
    p.add_argument("--socket", default=None,
                   help=f"robotd socket (default: $DUCKCTL_SOCKET, else {SIM_SOCKET} if present, else {REAL_SOCKET})")
    p.add_argument("--ssh-host", default=None,
                   help="reach robotd on another host through an ssh unix-socket forward (e.g. `microduck`)")
    p.add_argument("--remote-socket", default=REAL_SOCKET,
                   help=f"robotd socket path on the --ssh-host (default {REAL_SOCKET})")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("health", help="hello + robot.health + robot.mode (read-only)")

    s = sub.add_parser("status", help="read robot.state frames (read-only)")
    s.add_argument("--frames", type=int, default=1)
    s.add_argument("--hz", type=int, default=10)
    s.add_argument("--raw", action="store_true", help="full frames, not the summary")

    s = sub.add_parser("stand", help="robot.enable on (policy stands it up); rises from sit if seated")
    s.add_argument("--settle", type=float, default=4.0, help="seconds to wait before reading the result")

    s = sub.add_parser("sit", help="robot.do sit_toggle, only if not already sitting")
    s.add_argument("--settle", type=float, default=4.0)

    s = sub.add_parser("walk", help="robot.move at 10 Hz for N seconds, then robot.stop")
    s.add_argument("--vx", type=float, default=0.0, help="forward m/s")
    s.add_argument("--vy", type=float, default=0.0, help="left m/s")
    s.add_argument("--vyaw", type=float, default=0.0, help="yaw rad/s, positive turns left")
    s.add_argument("--seconds", type=float, required=True)
    s.add_argument("--sample", action="store_true", help="read one state frame per second while walking")

    s = sub.add_parser("look", help="robot.look: aim the head (pitch/yaw rad, or --point x y z)")
    s.add_argument("--pitch", type=float, default=0.0, help="rad, positive up (our convention)")
    s.add_argument("--yaw", type=float, default=0.0, help="rad, positive left")
    s.add_argument("--distance", type=float, default=1.0, help="m, gaze point distance")
    s.add_argument("--point", type=float, nargs=3, metavar=("X", "Y", "Z"), help="trunk-frame point, metres")
    s.add_argument("--neck-pitch", type=float, default=0.0, help="posture the IK aims around, rad")

    sub.add_parser("stop", help="robot.stop: zero the velocity (not limp)")
    return p


COMMANDS = {
    "health": cmd_health, "status": cmd_status, "stand": cmd_stand, "sit": cmd_sit,
    "walk": cmd_walk, "look": cmd_look, "stop": cmd_stop,
}


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    tunnel = None
    try:
        if args.ssh_host:
            if args.socket:
                raise DuckError(EXIT_USAGE, "--socket and --ssh-host are exclusive (use --remote-socket)")
            tunnel = SshTunnel(args.ssh_host, args.remote_socket)
            path = tunnel.local
        else:
            path = args.socket or default_socket()
        return COMMANDS[args.cmd](path, args)
    except DuckError as e:
        print(f"duck-intents: {e}", file=sys.stderr)
        return e.code
    except KeyboardInterrupt:
        return EXIT_FAILED
    finally:
        if tunnel:
            tunnel.close()


if __name__ == "__main__":
    sys.exit(main())
