---
name: microduck-sim
description: "Drive the Microduck robot (simulated or real) with plain sentences: stand, sit, walk, turn, look, stop, health."
version: 0.1.0
metadata:
  hermes:
    tags: [robotics, microduck, pollen-robotics, robotd]
---

# microduck-sim: drive the duck

The Microduck is a small two-legged robot from Pollen Robotics. Its daemon `robotd` owns the motors and the safety layer; you only send **intents** through one command-line client. You never touch motors, never go limp, never change policies.

Every action is one terminal command:

```
python3 /path/to/duck-intents.py <command> [options]
```

The client finds the simulator socket by itself (`~/.cache/duck-sim/duck.sock`). For the real robot later the same commands take `--ssh-host microduck`.

## commands

- `health`: is the robot up and healthy (control loop Hz, missed ticks, mode). Run it FIRST, once.
- `status`: one state frame (policy label: stand / walk / sit / rise; odometry position in metres; fallen yes/no).
- `stand`: stand up (also rises from sitting).
- `sit`: sit down (does nothing if already sitting).
- `walk --vx <m/s> --seconds <s>`: walk forward (negative vx = backward). Optional `--vyaw <rad/s>` to turn while walking (positive = left), `--vy <m/s>` to step sideways (positive = left). Blocks for the whole duration, then stops by itself.
- `look --yaw <rad> --pitch <rad>`: aim the head (positive yaw = left).
- `stop`: zero the velocity immediately. Not limp: the robot keeps standing.

## limits (the client refuses anything outside them, exit code 2)

- `--vx` between -0.4 and 0.4 m/s. Use 0.3 for a normal forward walk.
- `--vy` between -0.3 and 0.3 m/s.
- `--vyaw` between -1.0 and 1.0 rad/s. A quarter turn is about 1.57 rad, so `--vyaw 0.8 --seconds 2` turns roughly 90 degrees.
- speeds below about 0.05 do not walk at all (the robot keeps standing).

## how to do a request

1. `health` once.
2. If the robot is sitting and the request involves moving, `stand` first.
3. Run each step as its own command, in order, waiting for each to finish. `walk` already stops at the end of its duration.
4. After the last step run `status` and tell the user, in one or two sentences, what the robot did, using the numbers from the output (final policy label, distance walked). Do not claim anything the output does not show.
   - `odom_xyz` is the robot's own position estimate in metres **since the daemon started**, not since your request. Distance walked = `after.odom_xyz[0] - before.odom_xyz[0]` from the `walk` output. Never report a raw `odom_xyz` value as "distance from start".
   - `odom_xyz[2]` is trunk height: about 0.118 m standing, about 0.066 m sitting.
5. If a command prints `accepted: false` or exits non-zero, stop, run `stop`, and report the reason printed.
