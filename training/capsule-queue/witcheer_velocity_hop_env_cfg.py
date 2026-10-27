"""witcheer fork: Microduck HOP (both feet leave the ground, land upright, repeat), gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck`` by one import line appended to the end of ``tasks/__init__.py``;
nothing else in the Pollen tree is edited. The maker's task registry (33 ids at 53b8971) has no jump / hop task:
the only mentions are a comment in the BallKick cfg ("a la jump/ground-pick") and its anti-hop left-foot reward.

What this is: the maker's backlash walk env (``Mjlab-Velocity-Flat-Backlash-MicroDuck`` on the GROUNDCONTACT backlash robot, the VelStand collision model; BAM xl330 actuators with
battery-voltage and delay DR, gear play, 61-dim actor obs, 14 actions) with the command held at ZERO (the duck stands in
place) and a hop reward layer on top. The actor has no clock and no contact obs, so the hop is a limit cycle (crouch,
extend, flight, absorb, repeat), not a timed one-shot; the verdict counts hops inside a 6 s take.

Rewards added (all gated on being upright, tilt < 30-35 deg, trunk above 80 mm so sitting or tipping cannot farm them, and not in the first 15 steps of an episode, where the spawn drop is a flight nobody earned):
- ``hop_flight``   (+12) 1.0 on every 20 ms policy step where BOTH feet have no ground contact (the feet_ground_contact sensor).
- ``hop_clearance`` (+6) dense gradient before any flight exists: the LOWER sole's height above its standing height (3 mm dead band, capped at 30 mm), paid only while at least one foot has no contact (the ankle body origin is not used: it rises 15 mm on tiptoe).
- ``hop_vz``       (+6) upward trunk speed, capped at 1.2 m/s (the crouch-extend push-off).
- ``hop_impact``   (-0.1 per N) foot contact force above 20 N (standing load is ~3.6 N per foot): the landing tax.
Everything else is the maker's velocity layer, retuned only where it fights a crouch: ``pose`` weight 1.0 -> 0.1 with wider
std (a hop needs knee and hip excursions the stand-still posture reward charges for), action_rate curriculum replaced by one
step-0 stage at -0.02 (the maker's ramp ends at -1.0, which charges an explosive push-off ~1 per step), the standing-envs
curriculum fixed at 100% (zero twist command always), 8 s episodes, the training shoves removed (the first discovery needs
the duck to be allowed to bounce; the verdict takes run without shoves too). Terminations, DR, observations, robot unchanged.

Reward weights are read from the environment at import (unset = the defaults below, which the queue item uses; the item sets no env var):
``MICRODUCK_HOP_W=flight,clearance,vz,impact``. Pre-queue sweep 2026-10-27 (200 warm-start iterations each, 4096 envs): the plain warm start with three reward settings
(8,4,1.5,0.05 / 12,6,3,0.02 / 0,8,2,0.05, pose 0.4, action_rate -0.15) found no flight; the exploration lever (std 0.19 -> 0.6, entropy-coef 0.02, FREE penalties,
12,6,6,0.02 = L2, 12,6,6,0.1 = L3) produced hops by +100 iterations. The deterministic seed policy is what takes see; the training noise is the lever.

Physics note (read before calling a take a skill): the sim actuator is the BAM xl330 m6 fit with a 6.5-8.2 V battery range,
force limit +-1.07 N m at 8.2 V (0.96 at 7.4 V), no firmware current cap. The Robotis XL330-M288 datasheet (tribotix.com spec
table, read 2026-10-27) lists stall 0.60 N m at 6.0 V and no-load 123 rpm at 6.0 V. A hop that needs more than ~0.6 N m of
joint torque is therefore a statement about the sim motor, not about a servo at the datasheet limit; the proof scores the
peak joint torque of every take and reports the share of airborne takes that stay under 0.60 N m.
"""

import math
import os

import torch
from mjlab.managers import CurriculumTermCfg, RewardTermCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.robot.microduck_constants import MICRODUCK_BACKLASH_ROBOT_CFG
from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks import mdp as microduck_mdp
from mjlab_microduck.tasks.backlash import make_backlash_variant
from mjlab_microduck.tasks.microduck_velocity_env_cfg import make_microduck_velocity_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Hop-MicroDuck"

FOOT_REST_Z = 0.0005  # sole site height (left_foot / right_foot sites) with the duck standing on a flat plane (measured 2026-10-27: 0.5 mm). NOT the ankle body: its origin rises 15 mm when the foot pitches onto its toes with the sole still in contact
_DEFAULTS = (12.0, 6.0, 6.0, 0.1)   # flight, clearance, vz, impact: the "L3" setting of the 2026-10-27 pre-queue sweep (std 0.6 + entropy 0.02 warm start)


FREE = os.environ.get("MICRODUCK_HOP_FREE", "1") == "1"   # default ON: pose 0.4 -> 0.1, action_rate -0.15 -> -0.02 (the penalties a push-off fights); MICRODUCK_HOP_FREE=0 gives the first-sweep settings


def _weights():
    v = os.environ.get("MICRODUCK_HOP_W")
    if not v:
        return _DEFAULTS
    w = tuple(float(x) for x in v.split(","))
    assert len(w) == 4, "MICRODUCK_HOP_W = flight,clearance,vz,impact"
    return w


_FOOT_IDS = {}


def _feet(env):
    key = id(env)
    if key not in _FOOT_IDS:
        robot = env.scene["robot"]
        ids, _ = robot.find_sites(["left_foot", "right_foot"], preserve_order=True)
        _FOOT_IDS[key] = torch.as_tensor(ids, device=env.device, dtype=torch.long)
    return _FOOT_IDS[key]


def _upright(env, max_tilt_deg):
    q = env.scene["robot"].data.root_link_quat_w
    cos_tilt = 1.0 - 2.0 * (q[:, 1] ** 2 + q[:, 2] ** 2)
    return torch.nan_to_num(cos_tilt, nan=-1.0) > math.cos(math.radians(max_tilt_deg))


SETTLE_STEPS = 15  # the reset spawns the duck ~8 mm above the floor: every episode starts with ~3 steps of "both feet in the air" that no policy earned


def hop_flight(env, sensor_name="feet_ground_contact", min_trunk_z=0.08, max_tilt_deg=30.0):
    """1.0 while both feet are out of contact, trunk upright and above min_trunk_z (not in the first SETTLE_STEPS steps of an episode)."""
    found = env.scene[sensor_name].data.found  # (N, 2) contact point counts, left then right
    both_air = found.sum(dim=1) == 0
    z = env.scene["robot"].data.root_link_pos_w[:, 2]
    settled = env.episode_length_buf > SETTLE_STEPS
    return (both_air & _upright(env, max_tilt_deg) & (z > min_trunk_z) & settled).float()


def hop_clearance(env, sensor_name="feet_ground_contact", rest=FOOT_REST_Z, deadband=0.003, cap=0.03, max_tilt_deg=35.0):
    """height of the LOWER sole site above its standing height, 0..1 over `cap` metres, paid only while at least one foot has no ground contact
    (standing on tiptoe with both soles touching earns nothing; marching earns ~0 because the stance foot is the lower one)."""
    fz = env.scene["robot"].data.site_pos_w[:, _feet(env), 2].min(dim=1).values
    found = env.scene[sensor_name].data.found
    some_air = (found > 0).sum(dim=1) < 2
    r = torch.clamp(fz - rest - deadband, min=0.0, max=cap) / cap
    return r * (some_air & _upright(env, max_tilt_deg) & (env.episode_length_buf > SETTLE_STEPS)).float()


def hop_vz(env, cap=1.2, max_tilt_deg=35.0):
    """upward trunk speed (m/s, capped), the push-off of the crouch-extend cycle."""
    vz = env.scene["robot"].data.root_link_lin_vel_w[:, 2]
    return torch.clamp(vz, min=0.0, max=cap) * _upright(env, max_tilt_deg).float()


def hop_impact(env, sensor_name="feet_ground_contact", threshold=20.0):
    """sum over feet of the contact force above `threshold` newtons (a returned positive cost; the weight is negative)."""
    f = env.scene[sensor_name].data.force  # (N, 2, 3)
    mag = torch.nan_to_num(f.norm(dim=-1), nan=0.0)
    return torch.clamp(mag - threshold, min=0.0).sum(dim=1)


def make_witcheer_velocity_hop_env_cfg(play: bool = False):
    cfg = make_microduck_velocity_env_cfg(play=play)
    wf, wc, wv, wi = _weights()

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

    # the stand-still posture reward charges the crouch: weaker and wider
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

    cfg.rewards["hop_flight"] = RewardTermCfg(func=hop_flight, weight=wf, params={})
    cfg.rewards["hop_clearance"] = RewardTermCfg(func=hop_clearance, weight=wc, params={})
    cfg.rewards["hop_vz"] = RewardTermCfg(func=hop_vz, weight=wv, params={})
    cfg.rewards["hop_impact"] = RewardTermCfg(func=hop_impact, weight=-wi, params={})

    cfg.events.pop("push_robot", None)
    cfg.episode_length_s = 8.0
    # groundcontact backlash robot (the VelStand / StandUp collision model: trunk, legs, head shells collide with the floor), NOT the walk model:
    # the walk model collides only through the feet, and a 2026-10-27 open-loop search showed random squat-extend trajectories sinking the whole
    # trunk to -105 mm below the floor plane (z=5 mm upright mid-squat), a push-off stroke the real duck does not have
    return make_backlash_variant(cfg, MICRODUCK_BACKLASH_ROBOT_CFG)


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_velocity_hop_env_cfg(),
    play_env_cfg=make_witcheer_velocity_hop_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
