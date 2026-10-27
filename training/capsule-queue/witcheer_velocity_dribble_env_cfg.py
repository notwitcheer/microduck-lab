"""witcheer fork: Microduck WALKS a GIANT BALL (300 mm, bigger than the duck) forward = dribbling, gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck`` by one import line appended to the end of
``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why (2026-10-27): the giant-ball kick (09z10 power, 09z12 aim) is the lane's visual franchise; the next milestone
picture is the duck WALKING that ball across the pitch instead of kicking it once. The policy is blind to the ball
by design (obs 61 / 14 actions, so every walk checkpoint warm-starts), so "dribble" can only mean "walk forward gently
enough that the ball ahead stays in reach", learnt through contact.

Two facts that shaped it (2026-10-27, vault log): (1) the giant ball of the kick tasks NEVER SLOWS DOWN: MuJoCo ignores the rolling-friction term at the default condim 3 (a CPU check:
0.300 m/s held for 5 s), so with a blind walker every foot strike ratchets the ball speed up to the duck's peak gait speed and the ball leaves its reach after 3-9 s (seed takes, 24 of 24).
This task puts the ball geom at condim 6 with a rolling coefficient ``DRIB_ROLL`` (default 0.008 m, Crr = 0.008 / 0.15 m = 0.053, a ball on a soft floor; UNVERIFIED against a real ball): the ball
stops when the duck stops pushing, so the duck has to keep walking into it. (2) a reward that pays "ball near the feet" alone pays a STANDING duck.

What this task is: the Velocity-Flat-Backlash walk (``make_microduck_velocity_env_cfg`` + the walk backlash robot,
exactly the walk-flat v2 / walk-mix family) with
- the 300 mm ball (``_big_ball_spec`` of the Big kick module, so ball geometry, mass 0.275 kg, rolling friction are
  the giant-ball kick's) spawned on the centre line, ball centre ``DRIB_X`` ahead of the root in the yaw frame (default
  0.27 m, i.e. the rear surface 0.12 m ahead of the root, ~8.6 cm clear of the toe tip at HOME) with +-1.5 cm placement noise;
- the twist command fixed to a forward walk (vx in ``DRIB_VX``, default 0.10-0.30 m/s, vy 0, wz 0, no standing / turn
  envs, one command per 20 s episode) and the ``standing_envs`` curriculum dropped (it would re-impose standing envs
  on a resumed checkpoint);
- ONE ball reward on top of the stock walk rewards, which stay as they are: ``ball_carry`` = (gaussian of the ball's position in the
  base frame around (``DRIB_X``, 0), std ``DRIB_STD``: the ball is at the feet) x (ball speed along the per-env heading at reset,
  clamped to [0, ``DRIB_CAP``]: the ball actually travels), weight ``DRIB_W_CARRY`` (20); ``ball_lateral`` weight 10 is ON by default (the heading drifts otherwise). it is a PRODUCT on purpose: the ball spawns inside
  the gaussian, so a stand-still duck would be paid for "ball at the feet" all episode by a separate near-term (found while designing
  this item, 2026-10-27); the product pays only while the ball rolls forward AND stays close. optional ``ball_lateral`` (the Big
  kick's term: ball speed perpendicular to the heading at reset, absolute value, weight -``DRIB_W_LAT``).
  the critic does NOT see the ball (adding critic obs would break the warm start's size match; the actor is blind either way).

Verdict / clip overrides (read at import, i.e. at process start; training never sets the goal):
- ``MICRODUCK_DRIBBLE_X``, ``MICRODUCK_DRIBBLE_VX=lo,hi``, ``MICRODUCK_DRIBBLE_W_CARRY``, ``MICRODUCK_DRIBBLE_W_LAT``,
  ``MICRODUCK_DRIBBLE_CAP``, ``MICRODUCK_DRIBBLE_STD`` (the sweep sets these; the item sets none, the defaults below are the item);
- ``MICRODUCK_DRIBBLE_GOAL=1`` (PLAY cfg only): the Big kick's goal entity (posts, bars, overdamped net) with its mouth line
  at x = ``MICRODUCK_DRIBBLE_GOAL_X`` (default 1.8 m) on the world +x axis, and the Big kick's ``face_goal`` reset event
  (duck turned to +x, xy at the env origin) placed between the base reset and the ball spawn. the policy never sees the goal.
"""

import os

import torch

from mjlab.entity import EntityCfg
from mjlab.managers import EventTermCfg, RewardTermCfg, TerminationTermCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_WALK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks import mdp as microduck_mdp
from mjlab_microduck.tasks import witcheer_ballkick_big_env_cfg as big
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Dribble-MicroDuck"

DRIB_X = float(os.environ.get("MICRODUCK_DRIBBLE_X", "0.27"))
DRIB_VX = tuple(float(v) for v in os.environ.get("MICRODUCK_DRIBBLE_VX", "0.15,0.30").split(","))
DRIB_STD = float(os.environ.get("MICRODUCK_DRIBBLE_STD", "0.20"))
DRIB_CAP = float(os.environ.get("MICRODUCK_DRIBBLE_CAP", "0.30"))
W_CARRY = float(os.environ.get("MICRODUCK_DRIBBLE_W_CARRY", "20.0"))
W_LAT = float(os.environ.get("MICRODUCK_DRIBBLE_W_LAT", "10.0"))
ROLL = float(os.environ.get("MICRODUCK_DRIBBLE_ROLL", "0.008"))  # ball rolling-resistance coefficient (m); 0 = the giant-ball kick tasks' ball (rolls forever); > 0 sets condim 6 on the ball geom
FAR_GAP = float(os.environ.get("MICRODUCK_DRIBBLE_FAR", "0.0"))  # m; > 0 adds the ball_escaped termination (OFF in the item: not tested to a gain) (ball centre further than this ahead of the trunk, or 0.5 m sideways, after FAR_GRACE_S)
FAR_GRACE_S = float(os.environ.get("MICRODUCK_DRIBBLE_FAR_GRACE", "1.5"))
GOAL_ON = os.environ.get("MICRODUCK_DRIBBLE_GOAL", "") not in ("", "0")
GOAL_X = float(os.environ.get("MICRODUCK_DRIBBLE_GOAL_X", "1.8"))


def _dribble_ball_spec():
    """the giant ball of the kick tasks; with ROLL > 0 the ball geom gets condim 6 and rolling friction ROLL (MuJoCo ignores the rolling term at the default condim 3, which is why the kick ball never slowed down)."""
    spec = big._big_ball_spec()
    if ROLL > 0.0:
        g = spec.geom("ball_geom")
        g.condim = 6
        g.friction[:] = (0.5, 0.005, ROLL)
    return spec


def ball_carry(env, asset_name: str = "ball", target_x: float = DRIB_X, std: float = DRIB_STD, max_speed: float = DRIB_CAP) -> torch.Tensor:
    """exp(-d^2/std^2) x clamp(ball speed along the heading at reset, 0, max_speed); d = distance of the ball centre from (target_x, 0) in the base frame (xy)."""
    rel = microduck_mdp.ball_pos_in_base(env, asset_name=asset_name)
    d2 = (rel[:, 0] - target_x) ** 2 + rel[:, 1] ** 2
    near = torch.exp(-d2 / (std * std))
    fwd = microduck_mdp.ball_forward_velocity(env, asset_name=asset_name, max_speed=max_speed)
    return torch.nan_to_num(near * fwd, nan=0.0)


def ball_escaped(env, asset_name: str = "ball", max_gap: float = 1.0, max_lat: float = 0.5, grace_s: float = 1.5) -> torch.Tensor:
    """termination: the ball left the duck's reach (centre more than max_gap ahead of the trunk, or max_lat sideways) after grace_s of the episode."""
    rel = microduck_mdp.ball_pos_in_base(env, asset_name=asset_name)
    far = (rel[:, 0] > max_gap) | (rel[:, 1].abs() > max_lat)
    return far & (env.episode_length_buf * env.step_dt > grace_s)


def _goal_spec_dribble():
    """the Big kick's goal geometry with the mouth line at GOAL_X (its module global is read when the spec is built)."""
    old = big.GOAL_X
    big.GOAL_X = GOAL_X
    try:
        return big._goal_spec()
    finally:
        big.GOAL_X = old


def make_witcheer_velocity_dribble_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    cfg.scene.entities = {
        **cfg.scene.entities,
        "ball": EntityCfg(spec_fn=_dribble_ball_spec, init_state=EntityCfg.InitialStateCfg(pos=(0.3, 0.0, big.BALL_RADIUS))),
    }
    cfg.sim.nconmax = max(int(getattr(cfg.sim, "nconmax", 0) or 0), 50)  # ball-terrain + ball-robot contacts on top of the full-collision robot

    # forward walk only, one command per episode
    tw = cfg.commands["twist"]
    tw.ranges.lin_vel_x = DRIB_VX
    tw.ranges.lin_vel_y = (0.0, 0.0)
    tw.ranges.ang_vel_z = (0.0, 0.0)
    for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs"):
        if hasattr(tw, k):
            setattr(tw, k, 0.0)
    if hasattr(tw, "resampling_time_range"):
        tw.resampling_time_range = (cfg.episode_length_s, cfg.episode_length_s)
    cfg.curriculum.pop("standing_envs", None)

    # ball spawn (after the base reset, so the robot pose is final); play goal mode turns the duck to the goal first
    events = dict(cfg.events)
    if play and GOAL_ON:
        cfg.scene.entities["goal"] = EntityCfg(spec_fn=_goal_spec_dribble, init_state=EntityCfg.InitialStateCfg(pos=(0.0, 0.0, 0.0)))
        events["face_goal"] = EventTermCfg(func=big.face_goal, mode="reset", params={"yaw": 0.0, "zero_xy": True})
    events["reset_ball"] = EventTermCfg(
        func=microduck_mdp.reset_ball_in_front_of_foot,
        mode="reset",
        params={"offset": (DRIB_X, 0.0), "noise_xy": 0.015, "ball_radius": big.BALL_RADIUS, "asset_name": "ball"},
    )
    cfg.events = events

    cfg.rewards["ball_carry"] = RewardTermCfg(func=ball_carry, weight=W_CARRY, params={"asset_name": "ball"})
    if FAR_GAP > 0.0:  # a lost ball ends the episode: the policy then keeps collecting reward only by keeping the ball within reach
        cfg.terminations["ball_escaped"] = TerminationTermCfg(
            func=ball_escaped, time_out=False, params={"asset_name": "ball", "max_gap": FAR_GAP, "max_lat": 0.5, "grace_s": FAR_GRACE_S}
        )
    if W_LAT != 0.0:
        cfg.rewards["ball_lateral"] = RewardTermCfg(func=big.ball_lateral_speed, weight=-W_LAT, params={"asset_name": "ball"})
    return make_backlash_variant(cfg, MICRODUCK_WALK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_dribble_env_cfg(),
    play_env_cfg=make_witcheer_velocity_dribble_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
