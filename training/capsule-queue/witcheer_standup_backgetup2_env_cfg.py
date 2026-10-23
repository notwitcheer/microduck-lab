"""witcheer fork v2 of the Microduck StandUp task: get up from the BACK.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-StandUpBack2-Flat-MicroDuck`` by one import line appended to the end
of ``tasks/__init__.py`` (after the v1 line); nothing else in the Pollen tree
is edited.

Why v2: v1 (``Mjlab-StandUpBack-Flat-MicroDuck``, warm start StandUp
model_25000, 3k iterations, run 2026-09-24_16-01-44_duckbackgetup) changed
nothing: 0 of 3 forced face-up takes got up, all frozen at body-frame gravity
~(-0.90, 0, -0.44) at trunk ~60 mm, reward flat from it25500, and its
``supine_turnover_progress`` term read NEGATIVE the whole run (-0.0040 to
-0.0049), i.e. it never paid a single turn and only charged the landing.

Built on v1's ``make_witcheer_standup_backgetup_env_cfg()`` (same flat spawn
mix face_up 0.50 / face_down 0.20 / sitting 0.15 / standing 0.15) with
exactly three env cfg changes; the fourth v2 change (exploration std) lives in
the seed checkpoint plus one RL cfg value, see the end of this docstring.

1. TAXES OFF (reopen the discovery window). The maker's three late
   "attempt-taxes" (``arrival_damping`` -0.05, ``head_pose_bias`` 1.5,
   ``joint_torque_rate_l2`` -1e-3) are introduced at iter 3000/4000 by
   step-keyed curricula, and the maker's own comment at arrival_damping says
   ANY attempt-tax active during recovery discovery prevents the flip from
   being found ("taxing it makes attempts net-negative, do nothing wins").
   mjlab's runner restores ``common_step_counter`` from the checkpoint, so a
   warm start sits on their final stages forever. v2 overrides each of the
   three curricula with a single step-0 stage at weight 0.0 and sets the
   reward weights to 0.0, which is the maker's own discovery regime (iters
   0-3000). If v2 learns the turn, a later polish run can put them back.

2. body_ang_vel HALVED, -0.05 -> -0.025. The maker's documented first lever
   (standup cfg, sim2real regulariser block): "If recovery freezes: halve
   body_ang_vel to -0.025 first, then soften the action_rate curriculum end
   to -0.6." Only the first half is taken here; action_rate stays at -1.0 so
   one run tests one lever family.

3. TURNOVER REWARD FIXED so the spawn drop is not penalised. v1 paid
   Delta phi with phi = min(g_b.x, 0) * lowgate(z) and a baseline reset only
   at episode_length_buf <= 1. Face-up spawns are rolled up to +-90 deg about
   the long axis (``face_up_roll_max``) and dropped from 0.05-0.09 m, so most
   of them flop BACK onto the flat back during the first steps: g_b.x moves
   from -cos(roll) toward -1 and phi falls, charging every rolled spawn for a
   landing the policy did not choose (and the freeze pose then pays 0 for
   ever). v2 measures progress from the episode's running minimum instead:
       m_t   = min(phi_0 .. phi_t)          (most on-its-back point so far)
       psi_t = phi_t - m_t                  (>= 0, 0 at that point)
       r_t   = psi_t - psi_(t-1)
   Falling to a NEW low (the spawn flop, a fall from standing) costs 0; losing
   progress already made (rolling back after a partial turn) costs exactly
   what it paid; every centimetre of turn off the lowest point pays. It still
   telescopes: the episode total is psi_end <= -m <= 1 (x weight), so no pose
   can farm it (holding pays 0, rocking nets 0). Same key name
   (``supine_turnover_progress``) and weight 10 as v1 so the two runs'
   Episode_Reward curves compare line for line.

4. EXPLORATION STD (not in this file). rsl_rl restores the actor's
   ``distribution.std_param`` from the checkpoint on resume, so the cfg's
   init_std (1.0) is ignored by a warm start. The StandUp lineage collapsed
   it to ~0.16-0.18 (v1 run log "Mean action std: 0.17-0.18"). The v2 seed
   checkpoint (v1 model_28000, copied by ``prep-backgetup2-seed.py``) has
   std_param multiplied by 2.0 per joint; everything else in the checkpoint is
   byte-for-byte v1's.
   On its own that bump does not last: PPO at the maker's entropy_coef 0.01
   pulled it from 0.33 back to 0.18 within 100 iterations (sweep 2026-09-24,
   4096 envs from this seed: ent 0.01 -> 0.33/0.26/0.22/0.20/0.18 at
   +0/25/50/75/100 it; ent 0.02 -> 0.33/0.33/0.31/0.28/0.27; ent 0.03 ->
   0.33/0.43/0.45/0.43/0.39 with mean reward collapsing to 0.3-9). So v2's
   RL cfg raises entropy_coef to 0.02 (``ENTROPY_COEF``), the middle value:
   std decays at a third of the rate without the 0.03 blow-up (the 300-it
   exact-argv probe in 60-robotics/microduck/log.md 2026-09-24 has the trend). Everything else in the RL cfg is
   the maker's StandUp cfg.
"""

import dataclasses

import torch

from mjlab.envs.manager_based_rl_env import ManagerBasedRlEnv
from mjlab.managers import RewardTermCfg
from mjlab.managers.scene_entity_config import SceneEntityCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.tasks import MicroduckOnPolicyRunner
from mjlab_microduck.tasks.microduck_standup_env_cfg import MicroduckStandUpRlCfg
from mjlab_microduck.tasks.witcheer_standup_backgetup_env_cfg import (
    TURNOVER_GATE_Z_FULL,
    TURNOVER_GATE_Z_ZERO,
    TURNOVER_WEIGHT,
    make_witcheer_standup_backgetup_env_cfg,
)

TASK_ID = "Mjlab-StandUpBack2-Flat-MicroDuck"

ENTROPY_COEF = 0.02  # maker StandUp: 0.01 (see the doc: 0.01 undoes the std bump in ~100 it)
BODY_ANG_VEL_WEIGHT = -0.025  # maker's documented first lever (StandUp: -0.05)

# (curriculum term, reward term) pairs of the maker's late attempt-taxes.
TAXES = (
    ("arrival_damping_weight", "arrival_damping"),
    ("head_pose_bias_weight", "head_pose_bias"),
    ("torque_rate_weight", "joint_torque_rate_l2"),
)


def supine_turnover_progress_v2(
    env: ManagerBasedRlEnv,
    gate_z_full: float = TURNOVER_GATE_Z_FULL,
    gate_z_zero: float = TURNOVER_GATE_Z_ZERO,
    asset_cfg: SceneEntityCfg = SceneEntityCfg("robot", body_names=("trunk_base",)),
) -> torch.Tensor:
    """Progress off the back, measured from the episode's running minimum.

    phi = min(g_b.x, 0) * lowgate(z); psi = phi - min_so_far(phi); returns
    Delta psi. A new low (spawn flop, any fall onto the back) pays 0; turning
    off the lowest point pays; undoing earned progress costs what it paid.
    """
    asset = env.scene[asset_cfg.name]
    gx = torch.nan_to_num(asset.data.projected_gravity_b[:, 0], nan=0.0)
    z = torch.nan_to_num(
        asset.data.root_link_pos_w[:, 2] - env.scene.terrain.env_origins[:, 2], nan=1.0
    )
    t = torch.clamp((gate_z_zero - z) / max(gate_z_zero - gate_z_full, 1e-6), 0.0, 1.0)
    low = t * t * (3.0 - 2.0 * t)
    phi = torch.clamp(gx, max=0.0) * low
    if not hasattr(env, "_witcheer_turnover2_min"):
        env._witcheer_turnover2_min = phi.clone()
        env._witcheer_turnover2_psi = torch.zeros_like(phi)
    fresh = env.episode_length_buf <= 1
    env._witcheer_turnover2_min[fresh] = phi[fresh]
    env._witcheer_turnover2_psi[fresh] = 0.0
    m = torch.minimum(env._witcheer_turnover2_min, phi)
    psi = phi - m
    delta = psi - env._witcheer_turnover2_psi
    env._witcheer_turnover2_min = m
    env._witcheer_turnover2_psi = psi
    return delta


def make_witcheer_standup_backgetup2_env_cfg(play: bool = False):
    cfg = make_witcheer_standup_backgetup_env_cfg(play=play)  # v1: flat back-weighted spawn mix

    # 1. taxes off: single step-0 stage at weight 0 (the counter is restored, see doc).
    for cur_name, rew_name in TAXES:
        if cur_name in cfg.curriculum:
            cfg.curriculum[cur_name].params["weight_stages"] = [{"step": 0, "weight": 0.0}]
        if rew_name in cfg.rewards:
            cfg.rewards[rew_name].weight = 0.0

    # 2. body_ang_vel halved.
    cfg.rewards["body_ang_vel"].weight = BODY_ANG_VEL_WEIGHT

    # 3. turnover reward from the running minimum (same key and weight as v1).
    cfg.rewards["supine_turnover_progress"] = RewardTermCfg(
        func=supine_turnover_progress_v2,
        weight=TURNOVER_WEIGHT,
        params={
            "gate_z_full": TURNOVER_GATE_Z_FULL,
            "gate_z_zero": TURNOVER_GATE_Z_ZERO,
            "asset_cfg": SceneEntityCfg("robot", body_names=("trunk_base",)),
        },
    )
    return cfg


BackGetup2RlCfg = dataclasses.replace(
    MicroduckStandUpRlCfg,
    algorithm=dataclasses.replace(MicroduckStandUpRlCfg.algorithm, entropy_coef=ENTROPY_COEF),
)

register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_standup_backgetup2_env_cfg(),
    play_env_cfg=make_witcheer_standup_backgetup2_env_cfg(play=True),
    rl_cfg=BackGetup2RlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
