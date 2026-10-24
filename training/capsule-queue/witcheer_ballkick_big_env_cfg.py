"""witcheer fork: Microduck BallKick with a GIANT ball (300 mm, bigger than the duck), gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-BallKick-Flat-Backlash-Big-MicroDuck`` by one import line appended to the end of
``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why: the plain kick (level 7, 70 mm / 15 g ball) is the one trick of ours that already reads in a
single frame, and the obvious visual question is how big a ball this little duck can kick. A
feasibility sweep on 2026-10-24 (seed policy only, no training, 1-env takes, flat floor, goal at 1.2-1.4 m)
answered "all of them": the backlash kick (09l kickbl model_13000, trained on the 70 mm ball) moved balls of
radius 0.09 / 0.105 / 0.12 / 0.15 / 0.18 m (0.10 / 0.135 / 0.176 / 0.275 / 0.397 kg, mass scaled with r^2 from the
maker's ball) every take, upright, with the ball ending in the goal. Median ball travel from its start at
t = 1 s / 2 s: 0.80 / 1.25 m on the maker's 70 mm ball (32 takes), then 0.66 / 1.23, 0.54 / 1.12, 0.47 / 1.01,
0.35 / 0.74 and 0.27 / 0.57 m (6 takes each, r = 0.09 ... 0.18). So a giant ball needs no training to MOVE, but the
kick gets weaker the bigger the ball (the policy was rewarded for 1.0 m/s on a 15 g ball), and that is what this
item trains.

The ball: radius 0.15 m (300 mm across, 1.2x the 250 mm duck, ~3x the width of its head, ~92 x 128 mm
in the model), mass 0.275 kg (thin hollow shell, 15 g x (0.15/0.035)^2, inertia 2/3 m r^2), blue
(contrast on camera, no physics effect). Seed on this ball: 0.35 m at 1 s, 0.74 m at 2 s (max 0.86 of 6
takes), roughly 0.45 m/s of ball speed, so the capped forward-velocity term pays ~5 of its 12.

What changes against ``Mjlab-BallKick-Flat-Backlash-MicroDuck`` (every other line of the cfg is
reused, nothing copied):

- the ball entity (radius, mass, colour as above);
- ``reset_ball``: nominal ball-centre offset in the robot's yaw frame x = 0.205 (was 0.09), y = -0.042
  (the right foot's line, unchanged), ``ball_radius`` 0.15 so the ball spawns resting on the floor.
  0.205 - 0.15 = 0.055 keeps the nominal REAR SURFACE of the ball where the small ball's was
  (0.09 - 0.035), so the strike point on the foot is the one the seed learned; the +-0.015 m placement
  noise is unchanged. Proven by the 1-env takes: the ball stays put until the swing (no solver ejection
  at reset) up to radius 0.18.
- NOTHING else: rewards, target kick speed (1.0 m/s, forward term capped at it, overshoot penalty),
  curricula, obs, command, DR and terminations are the backlash kick's. One variable moves (the ball),
  so a reward or take difference against the seed is the ball. An optional aim term (``ball_lateral``,
  speed perpendicular to the reset heading, weight -``MICRODUCK_BIGKICK_AIM_W``) exists but is OFF
  (default 0): the seed already puts 84% of its takes (27 of 32, 70 mm... see below) inside a 0.70 m goal
  at 1.2 m with a median aim of +11 degrees, so aim is not the limiting factor.

Verdict / clip overrides (read at import, i.e. at process start; training never sets them):

- ``MICRODUCK_BIGBALL_RADIUS`` (m, default 0.15) and ``MICRODUCK_BIGBALL_MASS`` (kg, default 0.275).
- ``MICRODUCK_BIGKICK_GOAL=1`` (PLAY cfg only): adds a static GOAL entity (four posts, two crossbars,
  two top rails, a soft net) with the mouth line at x = ``MICRODUCK_BIGKICK_GOAL_X`` m (default 1.4) on the
  world +x axis, 1.00 m wide, 0.50 m high, 0.40 m deep, and a reset event ``face_goal`` (between
  ``set_ground_state`` and ``reset_ball``, so the ball spawns from the final pose) that turns the standing
  duck to face +x and zeroes the spawn xy offset, so every take is a penalty: the policy is BLIND to the
  ball and the goal, the kick goes along the heading at reset, and the goal only shows where that heading
  leads. Training never builds the goal. The net geoms carry an overdamped contact (a stiff net bounced the
  ball back out of the goal in the first build). Goal geometry, the face_goal yaw and the ball offset are
  proven by ``bigkick-play-check-2026-10-24.sh``.
"""

import math
import os

import mujoco
import torch

from mjlab.entity import EntityCfg
from mjlab.managers import EventTermCfg, RewardTermCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_BACKLASH_ROBOT_CFG, MICRODUCK_BALL_XML
from mjlab_microduck.tasks import MicroduckBallKickRlCfg, MicroduckOnPolicyRunner
from mjlab_microduck.tasks import mdp as microduck_mdp
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_ball_kick_env_cfg import (
    BALL_OFFSET_ABS_Y,
    make_microduck_ball_kick_env_cfg,
)

TASK_ID = "Mjlab-BallKick-Flat-Backlash-Big-MicroDuck"

BALL_RADIUS = float(os.environ.get("MICRODUCK_BIGBALL_RADIUS", "0.15"))
BALL_MASS = float(os.environ.get("MICRODUCK_BIGBALL_MASS", "0.275"))
# nominal rear surface of the ball in the robot yaw frame = the small ball's (0.09 - 0.035)
BALL_REAR_X = 0.055
BALL_OFFSET_X = BALL_REAR_X + BALL_RADIUS
BALL_RGBA = (0.10, 0.45, 1.00, 1.0)

AIM_W = float(os.environ.get("MICRODUCK_BIGKICK_AIM_W", "0.0"))

GOAL_ON = os.environ.get("MICRODUCK_BIGKICK_GOAL", "") not in ("", "0")
GOAL_X = float(os.environ.get("MICRODUCK_BIGKICK_GOAL_X", "1.4"))
GOAL_W, GOAL_H, GOAL_D, POST_R = 1.00, 0.50, 0.40, 0.015


def _big_ball_spec() -> mujoco.MjSpec:
    spec = mujoco.MjSpec.from_file(str(MICRODUCK_BALL_XML))
    geom = spec.geom("ball_geom")
    geom.size[0] = BALL_RADIUS
    geom.rgba[:] = BALL_RGBA
    body = spec.body("ball")
    body.pos[:] = (0.3, 0.0, BALL_RADIUS)
    body.mass = BALL_MASS
    inertia = (2.0 / 3.0) * BALL_MASS * BALL_RADIUS**2  # thin hollow sphere, as ball.xml
    body.inertia[:] = (inertia, inertia, inertia)
    return spec


def _goal_spec() -> mujoco.MjSpec:
    """Static goal in WORLD coordinates (the entity sits at the origin): mouth line at x = GOAL_X, opening along y."""
    spec = mujoco.MjSpec()
    body = spec.worldbody.add_body(name="goal")
    x0, x1, hw = GOAL_X, GOAL_X + GOAL_D, GOAL_W / 2
    white, net = (0.97, 0.97, 0.97, 1.0), (0.9, 0.95, 1.0, 0.28)

    def cyl(name, p0, p1):
        # cylinder from p0 to p1 (MuJoCo "fromto" capsule-free cylinder), frame-agnostic
        g = body.add_geom(name=name, type=mujoco.mjtGeom.mjGEOM_CYLINDER, size=[POST_R, 0, 0], rgba=white)
        g.fromto[:] = (*p0, *p1)

    for sx, x in (("f", x0), ("b", x1)):
        for sy, y in (("l", -hw), ("r", hw)):
            cyl(f"post_{sx}{sy}", (x, y, 0.0), (x, y, GOAL_H))
        cyl(f"bar_{sx}", (x, -hw, GOAL_H), (x, hw, GOAL_H))
    for sy, y in (("l", -hw), ("r", hw)):
        cyl(f"rail_{sy}", (x0, y, GOAL_H), (x1, y, GOAL_H))
    # nets: thin boxes that stop the ball (back + both sides, roof left open on purpose). a stiff default contact bounced the ball
    # back OUT of the goal at ~0.5 m/s (seed takes, 2026-10-24), so the net geoms carry priority 1 (their solref wins the contact mix)
    # and an overdamped solref (time constant 0.05 s, damping ratio 1.5): the ball sinks ~4 cm into the net and stays, like a net.
    def soft(g):
        g.priority = 1
        g.solref[:] = (0.05, 1.5)

    soft(body.add_geom(name="net_back", type=mujoco.mjtGeom.mjGEOM_BOX, size=[0.003, hw, GOAL_H / 2],
                       pos=[x1, 0.0, GOAL_H / 2], rgba=net))
    for sy, y in (("l", -hw), ("r", hw)):
        soft(body.add_geom(name=f"net_{sy}", type=mujoco.mjtGeom.mjGEOM_BOX, size=[GOAL_D / 2, 0.003, GOAL_H / 2],
                           pos=[(x0 + x1) / 2, y, GOAL_H / 2], rgba=net))
    return spec


def ball_lateral_speed(env, asset_name: str = "ball") -> torch.Tensor:
    """|ball velocity component perpendicular to the per-env kick direction| (m/s, xy). Used with a NEGATIVE weight: aim straight."""
    ball = env.scene[asset_name]
    v = ball.data.root_link_lin_vel_w[:, :2]
    d = microduck_mdp._ball_kick_dir(env)
    lat = -v[:, 0] * d[:, 1] + v[:, 1] * d[:, 0]
    return torch.nan_to_num(lat.abs(), nan=0.0)


def face_goal(env, env_ids, yaw: float = 0.0, zero_xy: bool = True):
    """Reset event (PLAY, goal mode): turn the freshly spawned standing duck to world yaw ``yaw`` and put it at its env origin xy.

    Rotates the existing orientation by (yaw - current yaw) about world z, so the +-5 deg tilt noise of
    ``set_ground_state`` survives. Must sit between set_ground_state and reset_ball in the event order.
    """
    if env_ids is None or len(env_ids) == 0:
        return
    env_ids = env_ids.to(env.device)
    robot = env.scene["robot"]
    root = env.sim.data.qpos[env_ids][:, robot.indexing.free_joint_q_adr].clone()
    w, x, y, z = root[:, 3], root[:, 4], root[:, 5], root[:, 6]
    cur = torch.atan2(2.0 * (w * z + x * y), 1.0 - 2.0 * (y * y + z * z))
    d = yaw - cur
    cw, sw = torch.cos(d / 2), torch.sin(d / 2)
    pose = root.clone()
    pose[:, 3] = cw * w - sw * z
    pose[:, 4] = cw * x - sw * y
    pose[:, 5] = cw * y + sw * x
    pose[:, 6] = cw * z + sw * w
    if zero_xy:
        pose[:, 0] = env.scene.terrain.env_origins[env_ids, 0]
        pose[:, 1] = env.scene.terrain.env_origins[env_ids, 1]
    robot.write_root_link_pose_to_sim(pose, env_ids)


def make_witcheer_ballkick_big_env_cfg(play: bool = False):
    cfg = make_microduck_ball_kick_env_cfg(play=play)
    cfg.scene.entities = {
        **cfg.scene.entities,
        "ball": EntityCfg(spec_fn=_big_ball_spec, init_state=EntityCfg.InitialStateCfg(pos=(0.3, 0.0, BALL_RADIUS))),
    }
    rb = cfg.events["reset_ball"].params
    rb["offset"] = (BALL_OFFSET_X, -BALL_OFFSET_ABS_Y)  # right foot line (the base task is right-footed)
    rb["ball_radius"] = BALL_RADIUS
    if AIM_W != 0.0:  # optional, off by default (see the docstring)
        cfg.rewards["ball_lateral"] = RewardTermCfg(func=ball_lateral_speed, weight=-AIM_W, params={"asset_name": "ball"})
    if play and GOAL_ON:
        cfg.scene.entities["goal"] = EntityCfg(spec_fn=_goal_spec, init_state=EntityCfg.InitialStateCfg(pos=(0.0, 0.0, 0.0)))
        events = {}
        for k, v in cfg.events.items():
            if k == "reset_ball":
                events["face_goal"] = EventTermCfg(func=face_goal, mode="reset", params={"yaw": 0.0, "zero_xy": True})
            events[k] = v
        cfg.events = events
    return make_backlash_variant(cfg, MICRODUCK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_ballkick_big_env_cfg(),
    play_env_cfg=make_witcheer_ballkick_big_env_cfg(play=True),
    rl_cfg=MicroduckBallKickRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
