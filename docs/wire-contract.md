---
robot: microduck
phase: 1
doc: robotd wire contract, as the Hermes tool needs it
pinned_commit_microduck: 6507d2e (2026-09-10)
pinned_commit_microduck_rl: 53b8971 (2026-09-09)
read_on: 2026-09-24, a local clone of pollen-robotics/microduck (source) + live sim robotd 0.12.0
status: verified against the sim (see "proof" at the end)
---

# microduck phase 1: the robotd wire contract

Every line cites `file:line` in `pollen-robotics/microduck` at 6507d2e unless it says `microduck_rl`. Anything not stated by the source is marked INFERRED. "live" means seen on the sim robotd on 2026-09-24.

## 1. transport

- **encoding and framing:** JSON-RPC 2.0, one object per line (NDJSON), framed by a single newline, over a unix socket. `duck-ipc-proto/src/lib.rs:9-12`. `"jsonrpc":"2.0"` constant `lib.rs:35`.
- **no broker, one socket per daemon:** `lib.rs:1012-1017`. robotd's methods are routed `(Robot, Prompt)` except `robot.subscribe`, which is `(Robot, Stream)`: `lib.rs:1255-1282`.
- **socket paths:**
  - real duck: `/run/robotd.sock` (`lib.rs:384`; robotd `--socket` default `robotd/src/main.rs:227-228`; robotctl `--robot-socket` default `robotctl/src/main.rs:85-86`). These are defaults, every daemon takes `--socket` (`lib.rs:375-380`).
  - sim: `~/.cache/duck-sim/duck-a.sock`, with `~/.cache/duck-sim/duck.sock` a symlink to the duck `ctl` talks to (`scripts/duck-sim:32`, `:58`, `:286-293`; `docs/robot/simulation.md:73-75`). live: `duck.sock -> duck-a.sock`.
  - runtime dir: `/run` unless `DUCK_RUNTIME_DIR` (`lib.rs:412-421`); duck-sim sets it to the state dir (`scripts/duck-sim:285`).
- **permissions:** robotd chmods its socket `0660`, "the group decides who may ask" (`robotd/src/main.rs:60-61`, applied `:3363`). live log: `serving robot IPC path=... mode="660"`. For the real duck over ssh, the ssh user must be the socket's owner or in its group: which group is UNVERIFIED until the robot lands.
- **line limit:** 64 KiB per line (`robotd/src/main.rs:63`); longer lines get `-32600 "request too large"` (`:3502-3508`).
- **concurrency:** each connection is served one request at a time; a subscribed connection becomes a request channel AND a state stream (`robotd/src/main.rs:3398-3413`, rationale `lib.rs:1032-1048`). Our client opens a separate connection for state reads. INFERRED best practice, matches robotctl opening its own connection per command (`robotctl/src/main.rs:2675`).
- **handshake:** `hello {api_version}` answers `{api_version, daemon_version, revision}` (`lib.rs:1989-1991`, `:2880-2888`; served `robotd/src/main.rs:4524-4530`). It is a liveness check, **not a gate**: no daemon refuses on a version difference (`lib.rs:57-64`; robotctl `robotctl/src/main.rs:1349-1358`). Current `API_VERSION = 28` (`lib.rs:340`). live: `{"api_version": 28, "daemon_version": "0.12.0", "revision": null}`.
- **messages:** `Request {jsonrpc, id?, method, params?}`, no `id` = notification (`lib.rs:1734-1743`). `Response {jsonrpc, id, result? | error?}` (`lib.rs:1874-1883`), `Error {code, message, data?}` (`lib.rs:1916-1923`).
- **params strictness:** every params type denies unknown fields, so an unknown member is `-32602` naming it (`lib.rs:1975-1986`); an unknown method is `-32601` (`lib.rs:1535-1540`). No-param methods accept `params` absent, `null`, `{}` or anything (`lib.rs:1446`, test `:5290-5310`).
- **units and frame, stated once by Pollen:** radians and rad/s, trunk frame, right-handed, x forward, y left, z up, positive `vyaw` turns left (`lib.rs:2001-2003`).

## 2. two message families (this decides how walk works)

- **continuous intents** (`robot.move`, `robot.head`, `robot.pose`, `robot.mouth`): sent as **notifications**, 20-50 Hz, last-writer-wins, expiring (`lib.rs:490-496`, `Request::notify` `:1755-1768`). robotd applies them without a reply (`robotd/src/main.rs:3525-3533`, `apply_intent` `:3564-3609`). Sent WITH an id they are still applied and answered `{"accepted":true}` (`robotd/src/main.rs:4122-4128`).
- **discrete intents** (`robot.stop`, `robot.enable`, `robot.look`, `robot.do`, `robot.init`, `robot.relax`...): sent as **requests**, answered, because the caller needs "accepted or why not" (`lib.rs:497-498`, `:1759-1760`).
- **refusal is not an error:** discrete intents answer `IntentResult {accepted: bool, reason?}`; `accepted:false` is a normal outcome with a displayable reason (`lib.rs:3349-3389`). robotctl maps it to exit 5 REFUSED (`robotctl/src/main.rs:2747-2755`, `:63`).

## 3. robot.* methods (robotd), what the Hermes tool uses first

| method | family | params (types, units) | answer | robotd behaviour / refusals | cite |
|---|---|---|---|---|---|
| `robot.health` | request, read | none | `HealthResult` (below) | never refused; an unhealthy robot answers unhealthy rather than failing | proto `lib.rs:478`, `:3159-3229`; serve `robotd/src/main.rs:4510`, `:718-800` |
| `robot.mode` | request, read | none | `{mode: "walk"\|"roller"}` | | `lib.rs:599-604`, `:2257-2264`; `robotd/src/main.rs:4358` |
| `robot.subscribe` | request, then stream | `{hz?: u32}` absent/0 = every tick (50 Hz) | `SubscribeResult {accepted, walk?, stand?, sitstand?, ground_pick?, skills[], unavailable?}` then `robot.state` notifications | per-subscriber server-side decimation; resubscribing replaces the rate; slow subscriber loses frames, never back-pressures the loop | `lib.rs:685-695`, `:2576-2628`; `robotd/src/main.rs:3541-3550`, `:3470-3491`, `:4422-4443` |
| `robot.move` | **notification** | `{vx: m/s fwd, vy: m/s left, vyaw: rad/s left}` all f64, default 0 | none (or `{"accepted":true}` if sent with id) | stored stamped; **deadman zeroes the twist 500 ms after the last one** (below). **No velocity clamp in robotd** | `lib.rs:500-501`, `:2011-2021`; `robotd/src/main.rs:3569-3572`; `robotd/src/intents.rs:300-305` |
| `robot.stop` | request | none | `{"accepted":true}` | "zero the velocity. Not go limp"; sets the twist to 0 (fresh stamp); never refused | `lib.rs:507-508`; `robotd/src/main.rs:4445-4448`; `robotd/src/intents.rs:314-317` |
| `robot.enable` | request | `{on: bool, toggle?: bool=false}` | `{"accepted":true, reason:"enabled — driving" \| "disabled — returning to the home pose"}` | hands the robot to its policy; **never refused for being down**; off returns to the home pose. On the sim this is what stands the duck up | `lib.rs:509-510`, `:2630-2649`; `robotd/src/main.rs:4453-4480`; robotctl help `robotctl/src/main.rs:438-458`; `scripts/duck-sim:364-384` |
| `robot.do` | request (or notification = "button held") | `{skill: string}`; names = `ground_pick` (if loaded), `sit_toggle` (if sitstand loaded), then config skills (sim: `roulade`, `kick_left`, `kick_right`) | `IntentResult` | **refused** when the policy is not enabled ("the policy is not driving — press Start on the pad"), while homing ("still going to its home pose"), or unknown name (lists known names). Not refused for being fallen | `lib.rs:549-551`, `:2182-2209`; `robotd/src/main.rs:4155-4191`, `do_names` `:4072-4092`, `queue_skill` `:4094-4110` |
| `robot.look` | request | `{x, y, z: m trunk frame (z is trunk, floor ~0.12 m below), neck_pitch: rad posture, default 0}` | `LookResult {head:{neck_pitch, head_pitch, head_yaw, head_roll}, clamped}` | IK against the MJCF; **never refused**, out-of-reach gives the closest gaze with `clamped:true`; result is fed to the `robot.head` slot | `lib.rs:504-506`, `:2037-2062`; `robotd/src/main.rs:4130-4153` |
| `robot.head` | notification | `{neck_pitch, head_pitch, head_yaw, head_roll}` rad | none | joint-space head targets; no deadman on the head (a stale head pose is held) | `lib.rs:502-503`, `:2023-2035`; `duck-control/src/safety.rs:226-237`; `robotd/src/intents.rs:242-243` |
| `robot.pose` | notification | `{z: m, roll, pitch: rad, active: bool=true}` trained z -0.025..+0.010, roll/pitch ±0.26; robot clamps nothing | none | | `lib.rs:552-556`, `:2211-2237` |
| `robot.init` / `robot.relax` | request | none | `IntentResult` accepted | init = torque on + ramp to home, no policy (tips the sim duck over, `scripts/duck-sim:364-369`); relax = torque off, **robot collapses**. Never refused. NOT used by our tool | `lib.rs:512-534`; `robotd/src/main.rs:4482-4502` |
| `robot.shutdown` | request | none | accepted | sit then power the machine off. NOT used by our tool | `lib.rs:597-598`; `robotd/src/main.rs:4257-4263` |
| `robot.policies`, `robot.skills`, `robot.model`, `robot.safeToRestart`, `robot.modelApi` | request, read | none | see proto | reads | `lib.rs:614-622`, `:749`, `:475-480`; `robotd/src/main.rs:4295-4322`, `:4511-4517` |
| others (`robot.setMode`, `robot.loadPolicy`, `robot.reloadPolicies`, `robot.setSkill`, `robot.removeSkill`, `robot.sound`, `robot.theremin`, `robot.chorale`, `robot.mouth`, `robot.rebootMotors`) | | | | out of scope for phase 1: they change config, policies or power | `lib.rs:536-637`, `:749-751` |

There is **no `robot.stand` or `robot.sit` method.** Our `stand` = `robot.enable {on:true}` (plus `robot.do sit_toggle` when the state says `sit`); our `sit` = `robot.do sit_toggle` when the state does not say `sit`. `sit_toggle` is a toggle (`robotd/src/control.rs:384-403`), refused mid-rise ("already standing up", `:401`), so the client must read the state first.

### HealthResult (live shape confirmed)

`{healthy, degraded?, reason?, battery?{volts, percent}, motors?{hottest, max_c, mean_c}, cpu_temp_c?, control_loop?{target_hz, achieved_hz, ticks, missed, last_tick_age_ms}, bus{consecutive_errors, startup_failures}, imu?{ready, stale_blocks, consecutive_stale_blocks}}` (`lib.rs:3169-3302`). Battery and temperatures are "reported, never judged" (`lib.rs:3187-3203`). Unhealthy reasons robotd emits: forced, bus not up (degraded), "control loop has not completed a cycle yet", "policy unavailable: ..." (`robotd/src/main.rs:751-791`).

## 4. the safety layer: what is refused and when

- **the only motor writer:** `Safety` owns the only `RobotIo`; nothing above it can command a motor (`duck-control/src/safety.rs:1-10`). Client calls only set intent slots (`robotd/src/intents.rs:1-13`); `robot.init/relax` "only ask" (`robotd/src/main.rs:4485-4486`).
- **deadman (walk needs a keepalive):** if the twist is older than `deadman_ms` the twist is zeroed and `limited_by` carries `"deadman"`; head and body untouched (`duck-control/src/safety.rs:226-237`; loop `robotd/src/main.rs:2006-2008`; name `:3230-3237`). Default **500 ms** (`robotd-params/src/lib.rs:1680-1681`, `:1764`; `duck-control/src/safety.rs:74`). Intents start maximally stale so a fresh robotd holds still (`robotd/src/intents.rs:264-270`). Pollen's own drive client resends at 10 Hz for that reason (`scripts/duck-sim:515-531`). live: every idle frame shows `limited_by: ["deadman"]`, and it disappears while `robot.move` flows.
- **stop is not limp:** losing comms makes the robot stand still (`duck-control/src/safety.rs:17-20`).
- **range clamp and NaN rejection** on joint targets, `limited_by` `joint_range` / `not_finite`; the range is the actuator's ±π, not per-joint anatomy (`duck-control/src/safety.rs:12-15`, `:40-48`, `:84-91`).
- **no velocity limit in robotd.** Nothing clamps `vx/vy/vyaw` (the gate touches only staleness). The velocity task trains on `lin_vel_x ±0.4, lin_vel_y ±0.3, ang_vel_z ±1.0` (`microduck_rl` 53b8971 `src/mjlab_microduck/tasks/microduck_velocity_env_cfg.py:648-650`); Pollen's shipped `alpha_walking.onnx` may have been trained on other ranges (INFERRED). duckctl enforces those ranges client-side and says so.
- **command smoothing:** the twist is EMA-smoothed at the tick rate, `cmd += α(target − cmd)`, `cmd_alpha` default 0.2 (`robotd/src/main.rs:1807-1813`; `robotd-params/src/lib.rs:1798`, `:1850`). live: after `robot.stop` the monitor showed `req[+0.00] app[+0.15]` for one frame, then 0.
- **stand vs walk network:** the standing policy runs when the twist magnitude is ≤ 0.05 (`duck-control/src/policy.rs:28`, `:310-314`; used `robotd/src/control.rs:526-536`). So commands below ~0.05 m/s do not walk.
- **fall:** `fallen` = projected gravity z above -0.5 for 200 ms (`robotd-params/src/lib.rs:1675-1679`, `:1762-1763`). The verdict is a **report, not a rule**: it preempts nothing (`duck-control/src/safety.rs:22-32`). Limp-fall (default on) drops to gain 50 while falling, then poses and hands to the stand policy (`robotd-params/src/lib.rs:1689-1727`, `:1765-1776`).
- **refusals a client meets** (all as `accepted:false` with a reason, not as JSON-RPC errors): `robot.do` when not enabled / homing / unknown skill (`robotd/src/main.rs:4167-4189`); `robot.theremin`, `robot.sound`, `robot.setMode` for missing capability (`:4203-4288`). `robot.enable`, `robot.init`, `robot.relax`, `robot.stop`, `robot.look` are never refused (`:4133-4134`, `:4458-4460`, `:4488-4501`, `:4445-4448`).
- **policy label per tick** (`robot.state.policy`): `walk`, `stand`, `sit`, `rise`, `ground_pick`, a skill name (`:unwind` suffix while unwinding), or `held` when nothing drives (`robotd/src/control.rs:483-537`; `robotd/src/main.rs:2848`, `:2862`).

## 5. monitor / stream interface

- `robot.subscribe {hz}` then `robot.state` notifications (no id) on that connection until it closes (`lib.rs:685-695`; `robotd/src/main.rs:3444-3491`). Frames are only assembled while someone is subscribed (`robotd/src/main.rs:3052-3057`).
- `RobotState` (`lib.rs:3391-3446`): `t` s since start; `move {requested[3], applied[3], limited_by[]}` (`:3560-3567`); `head[4]`; `policy`; `safety {fallen, limp, gravity[3], gain?}` (`:3571-3590`); `loop {hz, missed}` (`:3592-3598`); `joints[15]`, `targets[15]` in `JOINT_NAMES` order (`:432-448`); `odom {position[3] m, yaw rad}` contact odometry in the boot frame (`:3548-3558`); optional `theremin`, `chorale`, `imu`, `frames`, `skeleton`; `t_ns` CLOCK_MONOTONIC.
- `robotctl monitor [--hz N=10] [--json]`: subscribes at N Hz; on a pipe prints one line per frame (`robotctl/src/main.rs:282-304`; line format `robotctl/src/monitor.rs:410`). live line: `70.26 walk 50.0Hz miss=0 ok g[+0.02 -0.01 -1.00] kp=200 req[+0.30 +0.00 +0.00] app[+0.30 +0.00 +0.00]`.
- other streams on their own sockets: `tof.stream` from tofd (`lib.rs:770-798`, socket `:394-397`), `pad.input` from padd (`:753-768`), `head_imu.stream` (`:800-805`). Not needed for phase 1.

## 6. how robotctl calls it

- blocking std unix socket, one request at a time, id counter from 1; notifications skipped, replies matched by id (`robotctl/src/main.rs:1249-1347`).
- every robot command does `hello` first, then the call (`robotctl/src/main.rs:2675-2676`, `:1356-1382`).
- `robotctl robot init|enable [--off|--toggle]|relax --yes|reboot-motors|do <skill>|mode|look X Y Z [--neck-pitch]` (`robotctl/src/main.rs:423-528`, dispatch `:2662-2716`). `relax` demands `--yes` client-side (`:2667-2673`).
- **robotctl has no drive/move command.** Driving is `padd` (the pad) or a raw client; duck-sim's `drive` is a 13-line python loop of `robot.move` notifications at 10 Hz for 8 s (`scripts/duck-sim:515-533`).
- robotctl `health`/`version` read `robot.health` over `--robot-socket` (`robotctl/src/main.rs:83-86`, `:321-325`, `:1531`). duck-sim `status` = `ctl health | head -4` + a trunk-height read from the body server (`scripts/duck-sim:887`, `:386-413`).
- **doc drift, noted not fixed:** `scripts/duck-sim:371` says "there is no robotctl subcommand" for enable and `robotd/src/main.rs:4168-4170` says robotctl "has no `enable`", but `robotctl robot enable` exists at this commit (`robotctl/src/main.rs:438-458`, `:2681-2687`). Candidate for a gated upstream docs fix.

## 7. naming collision

Pollen already ships a `duckctl`: their laptop client over Bluetooth/LAN (crate `duckctl/`, `docs/robot/duckctl.md:1`). Ours was renamed to `duck-intents.py` for that reason.

## 8. proof on the sim (2026-09-24, Linux box, CPU only)

a small wrapper around `DUCK_SIM_VIEWER=0 scripts/duck-sim` (sudo shim on PATH) -> `robot healthy`, `loop 50.0 of 50.0 Hz`, `duck-a: standing (trunk 0.116 m, gravity z -1.000)`. Then `~/Pollen/duck-p1-proof.sh` ran `python3 duck-intents.py` against `~/.cache/duck-sim/duck.sock`:

- `health` rc 0: `hello {"api_version": 28, "daemon_version": "0.12.0"}`, `healthy: true`, `control_loop achieved_hz 50.01, missed 0`, `imu ready`, `mode walk`.
- `status`: ack names `alpha_walking.onnx`, `alpha_stand.onnx`, `alpha_sitstand.onnx`, `alpha_ground_pick.onnx`, skills `roulade, kick_left, kick_right`; frame `policy stand`, `limited_by ["deadman"]`.
- `stand`: `robot.enable -> {"accepted": true, "reason": "enabled — driving"}` (duck already standing from duck-sim's own enable).
- `walk --vx 0.3 --seconds 3`: 30 `robot.move` notifications at 10 Hz, `robot.stop -> {"accepted": true}`; per-second samples `policy walk`, `applied [0.3, 0, 0]`, `limited_by []`; odometry x 0.071 -> 0.382 m, **delta +0.311 m in ~3.6 s** (includes the smoothing tail), yaw delta -0.039 rad, never fallen. `robotctl monitor` in parallel: `stand ... [deadman]` -> five `walk ... req[+0.30] app[+0.30]` lines -> `walk req[+0.00] app[+0.15]` -> `stand ... [deadman]`.
- `stop`: `{"accepted": true}`. `duck-sim status` after: `robot healthy`, `standing (trunk 0.116 m, gravity z -1.000)`.
- `look --yaw 0.4 --pitch -0.2`: `head_yaw 0.393, head_pitch 0.359, clamped false`. `look --point 1 0 0`: `head_pitch 0.130, head_yaw -0.000001`.
- `sit`: `robot.do sit_toggle -> accepted`, policy `stand -> sit`, odom z 0.118 -> 0.066 m. `stand` from sit: enable + `sit_toggle` accepted, policy `sit -> stand`, z back to 0.118. robotd log: `sit toggle direction="sit"` then `direction="stand"`.
- client guard: `walk --vx 0.9` -> `duck-intents: --vx 0.9 outside the trained range +-0.4 (client guard)`, rc 2, nothing sent.
- **ssh tunnel shape proven from a second machine:** `duck-intents.py --ssh-host <host> --remote-socket ~/.cache/duck-sim/duck.sock health|status|stop` all rc 0 through `ssh -N -L <local.sock>:<remote.sock>` (OpenSSH 10.0 client); tunnel and temp dir cleaned up after.
- teardown: `scripts/duck-sim down` rc 0, no pidfiles left, no robotd/tofd/body_server processes, port 7801 closed, stray `duck-a-tof.sock` removed by hand. GPU untouched.
