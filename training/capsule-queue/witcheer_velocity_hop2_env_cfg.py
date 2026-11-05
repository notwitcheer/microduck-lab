"""witcheer fork: Microduck HOP v2 (whole-body airtime only), gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as ``Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck`` by one import line
appended to the end of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why v2 (log.md 2026-10-28 + 2026-10-29 diagnostic): the v1 hop task (``Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck``) paid ``hop_flight`` when neither SOLE had floor contact.
The groundcontact robot also collides through its trunk, hip, leg and head shells, and the 3,000-iteration policy learned to rest the head/jaw shell on the floor with
both soles kicked up (trunk 84-91 mm against the 115.7 mm stand): a reward hack on the sole-contact sensor, not a jump. The strict per-body floor-contact diagnostic
(``strict_play.py --strict-log``, scorer ``hop2-score-2026-10-29.py``) is in the vault log.md.

What v2 pays (everything else is the v1 hop env unchanged: backlash walk env on the groundcontact backlash robot, zero twist command, no shoves, 8 s episodes, 61-dim actor obs and
14 actions, the published walk policies' dims, so the warm start is a true resume; pose 0.1, action_rate -0.02):
- ``hop2_flight``    (+12) 1.0 on every policy step where NO robot body touches the floor (a contact sensor over every body of the robot against the terrain, any of the 4 physics substeps)
                     AND the trunk is >= STAND + 10 mm AND upright (tilt < 30 deg) and settled (not in the first 15 steps of an episode, the spawn drop). The whole duck is in the air.
- ``hop2_clearance`` (+6)  dense gradient: TRUNK height above the standing trunk height (3 mm dead band, capped at 30 mm), paid only while at least one sole is off the floor, upright,
                     settled and NO non-sole body is on the floor (the v1 term measured the lower SOLE, which the head-down hack raised to 180 mm).
- ``hop2_vz``        (+6)  upward trunk speed capped at 1.2 m/s, upright, no non-sole body on the floor.
- ``hop2_impact``    (-0.1 per N) sole contact force above 20 N (the landing tax, v1 unchanged).
- ``hop2_nonsole``   (-5 per body per step) every NON-sole robot body (trunk, hip, leg, head/jaw shells ...) on the floor after the settle window: a knee, shin, trunk or chin touch costs more than any one hop term pays.
- optional termination (``MICRODUCK_HOP2_TERM=1``, default OFF, TRAIN env only, the play env never has it): the episode ends on the first non-sole floor contact after the settle window.
Weights: ``MICRODUCK_HOP2_W=flight,clearance,vz,impact,nonsole``.

STAND is the standing trunk height in this env: 116.1 mm, the median of the per-take median trunk z over 0.5-1.5 s of 15 seed takes (hop2-score-2026-10-29.py --zstand; same value as the scorer's Z_STAND).
Real-robot caveat as in v1: the sim actuator ceiling is 0.641 N m, the XL330-M288 stall at 6 V is 0.60 N m, so a hop that pins the sim torque is simulation only.
"""

import math
import os

import torch
from mjlab.managers import CurriculumTermCfg, RewardTermCfg, TerminationTermCfg
from mjlab.sensor import ContactMatch, ContactSensorCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks import mdp as microduck_mdp
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Hop2-MicroDuck"

STAND = 0.1161          # m, standing trunk height in this env: median of 15 seed takes, 116.1 mm (CPU strict logger; the 2026-10-27 GPU seed takes read 115.7 mm)
LIFT = 0.010            # m, the trunk must be this far above STAND for a flight to be paid
SETTLE_STEPS = 15       # the reset spawns the duck ~8 mm above the floor: every episode starts with a few steps no policy earned
_DEFAULTS = (12.0, 6.0, 6.0, 0.1, 5.0)   # flight, clearance, vz, impact, nonsole
SENSOR = "hop2_body_floor"
SOLES = ("ankle_left", "ankle_right")
FREE = os.environ.get("MICRODUCK_HOP2_FREE", "1") == "1"
TERM = os.environ.get("MICRODUCK_HOP2_TERM", "0") == "1"


def _weights():
    v = os.environ.get("MICRODUCK_HOP2_W")
    if not v:
        return _DEFAULTS
    w = tuple(float(x) for x in v.split(","))
    assert len(w) == 5, "MICRODUCK_HOP2_W = flight,clearance,vz,impact,nonsole"
    return w


_CACHE = {}


def _sole_mask(env):
    """bool (n_bodies,): True for the two ankle bodies (they carry the sole collision geoms), in the sensor's primary order."""
    key = id(env)
    if key not in _CACHE:
        s = env.scene[SENSOR]
        names = []
        for sl in s._slots:
            if sl.primary_name not in names:
                names.append(sl.primary_name)
        m = torch.tensor([n.split("/")[-1] in SOLES for n in names], device=env.device, dtype=torch.bool)
        assert int(m.sum()) == 2, f"expected 2 sole bodies in {names}"
        _CACHE[key] = m
    return _CACHE[key]


def _touch(env):
    """(N, n_bodies) bool: this body touched the floor in ANY physics substep of the last policy step."""
    d = env.scene[SENSOR].data
    t = d.found > 0
    if d.force_history is not None:
        t = t | (torch.nan_to_num(d.force_history.norm(dim=-1)).max(dim=-1).values > 0.0)
    return t


def _upright(env, max_tilt_deg):
    q = env.scene["robot"].data.root_link_quat_w
    cos_tilt = 1.0 - 2.0 * (q[:, 1] ** 2 + q[:, 2] ** 2)
    return torch.nan_to_num(cos_tilt, nan=-1.0) > math.cos(math.radians(max_tilt_deg))


def _trunk_z(env):
    return env.scene["robot"].data.root_link_pos_w[:, 2] - env.scene.terrain.env_origins[:, 2]


def _settled(env):
    return env.episode_length_buf > SETTLE_STEPS


def hop2_flight(env, max_tilt_deg=30.0):
    """1.0 while NO robot body touches the floor, the trunk is >= STAND + LIFT, upright, settled: a whole-body flight."""
    touch = _touch(env)
    return ((~touch.any(dim=1)) & (_trunk_z(env) >= STAND + LIFT) & _upright(env, max_tilt_deg) & _settled(env)).float()


def hop2_clearance(env, deadband=0.003, cap=0.03, max_tilt_deg=35.0):
    """TRUNK height above STAND (0..1 over `cap` m), paid only while a sole is off the floor and no non-sole body is on it."""
    touch = _touch(env)
    sole = _sole_mask(env)
    nonsole = touch[:, ~sole].any(dim=1)
    some_sole_air = ~touch[:, sole].all(dim=1)
    r = torch.clamp(_trunk_z(env) - STAND - deadband, min=0.0, max=cap) / cap
    return r * (some_sole_air & (~nonsole) & _upright(env, max_tilt_deg) & _settled(env)).float()


def hop2_vz(env, cap=1.2, max_tilt_deg=35.0):
    """upward trunk speed (m/s, capped), upright, no non-sole body on the floor."""
    touch = _touch(env)
    nonsole = touch[:, ~_sole_mask(env)].any(dim=1)
    vz = env.scene["robot"].data.root_link_lin_vel_w[:, 2]
    return torch.clamp(vz, min=0.0, max=cap) * ((~nonsole) & _upright(env, max_tilt_deg)).float()


def hop2_impact(env, sensor_name="feet_ground_contact", threshold=20.0):
    """sum over soles of the contact force above `threshold` newtons (v1 landing tax; a positive cost, the weight is negative)."""
    f = env.scene[sensor_name].data.force
    mag = torch.nan_to_num(f.norm(dim=-1), nan=0.0)
    return torch.clamp(mag - threshold, min=0.0).sum(dim=1)


def hop2_nonsole(env):
    """number of NON-sole robot bodies on the floor this step (a positive cost, the weight is negative), after the settle window."""
    touch = _touch(env)
    return touch[:, ~_sole_mask(env)].float().sum(dim=1) * _settled(env).float()


def hop2_nonsole_term(env):
    touch = _touch(env)
    return touch[:, ~_sole_mask(env)].any(dim=1) & _settled(env)


def make_witcheer_velocity_hop2_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    wf, wc, wv, wi, wn = _weights()

    # zero twist command always: the duck stands in place and hops
    cmd = cfg.commands["twist"]
    cmd.ranges.lin_vel_x = (0.0, 0.0)
    cmd.ranges.lin_vel_y = (0.0, 0.0)
    cmd.ranges.ang_vel_z = (0.0, 0.0)
    cmd.rel_standing_envs = 1.0
    cmd.rel_turn_in_place_envs = 0.0
    cfg.curriculum["standing_envs"] = CurriculumTermCfg(
        func=microduck_mdp.standing_envs_curriculum,
        params={"command_name": "twist", "standing_stages": [{"step": 0, "rel_standing_envs": 1.0}]},
    )
    if "action_rate_weight" in cfg.curriculum:
        cfg.curriculum["action_rate_weight"] = CurriculumTermCfg(
            func=cfg.curriculum["action_rate_weight"].func,
            params={"reward_name": "action_rate_l2", "weight_stages": [{"step": 0, "weight": -0.15}]},
        )
    cfg.rewards["action_rate_l2"].weight = -0.15
    if FREE:
        cfg.curriculum["action_rate_weight"].params["weight_stages"] = [{"step": 0, "weight": -0.02}]
        cfg.rewards["action_rate_l2"].weight = -0.02

    pose = cfg.rewards["pose"]
    pose.weight = 0.1 if FREE else 0.4
    pose.params["std_standing"] = {
        r".*hip_yaw.*": 0.2,
        r".*hip_roll.*": 0.08,
        r".*hip_pitch.*": 0.6,
        r".*knee.*": 0.6,
        r".*ankle.*": 0.5,
    }
    cfg.rewards["head_pose_tracking"].weight = 1.0

    # a passive contact sensor over EVERY robot body against the floor (no obs, no physics change); history = all 4 substeps of a policy step
    cfg.scene.sensors = tuple(cfg.scene.sensors) + (
        ContactSensorCfg(
            name=SENSOR,
            primary=ContactMatch(mode="body", pattern=r".*", entity="robot"),
            secondary=ContactMatch(mode="body", pattern="terrain"),
            fields=("found", "force"),
            reduce="maxforce",
            num_slots=1,
            history_length=int(cfg.decimation),
        ),
    )

    cfg.rewards["hop2_flight"] = RewardTermCfg(func=hop2_flight, weight=wf, params={})
    cfg.rewards["hop2_clearance"] = RewardTermCfg(func=hop2_clearance, weight=wc, params={})
    cfg.rewards["hop2_vz"] = RewardTermCfg(func=hop2_vz, weight=wv, params={})
    cfg.rewards["hop2_impact"] = RewardTermCfg(func=hop2_impact, weight=-wi, params={})
    cfg.rewards["hop2_nonsole"] = RewardTermCfg(func=hop2_nonsole, weight=-wn, params={})
    if TERM and not play:   # train only: the proof takes (play env) never end on a contact, a touch is scored by the scorer
        cfg.terminations["hop2_nonsole_contact"] = TerminationTermCfg(func=hop2_nonsole_term, time_out=False)

    cfg.events.pop("push_robot", None)
    cfg.episode_length_s = 8.0
    return make_backlash_variant(cfg, MICRODUCK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_hop2_env_cfg(),
    play_env_cfg=make_witcheer_velocity_hop2_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
