"""witcheer fork of the Microduck StandUp task: get up from the BACK.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-StandUpBack-Flat-MicroDuck`` by one import line appended to the end
of ``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why: our StandUp run (logs/rsl_rl/duckstandup, model_25000 = maker's 15k +
10k extension) stands from sitting and from face-down, but from its back it
freezes half-rolled: body-frame gravity ~(-0.90, 0, -0.44) at trunk ~59 mm,
0 of 2 takes. Ten thousand extra iterations did not move it, so this fork
changes the task instead of the budget (3k budget rule, operator 2026-09-23).

Built on ``make_microduck_standup_env_cfg()`` with exactly two changes:

1. SPAWN MIX (``ground_state_mix`` curriculum + the ``set_ground_state`` event
   defaults): one flat stage, face_up 0.50 / face_down 0.20 / sitting 0.15 /
   standing 0.15. The maker's stages are keyed on ``common_step_counter`` and
   mjlab's runner restores that counter from the checkpoint (600072 in
   model_25000.pt), so a warm start would sit on the maker's last stage
   (face_up 0.35) forever; a single stage at step 0 is what applies after the
   resume. Sitting/standing/face-down stay in the mix so the skills the policy
   already has keep being exercised.

2. ONE REWARD TERM, ``supine_turnover_progress`` (defined below, weight 10):
   potential-based shaping on how far the robot is on its back.
       phi(s) = min(g_b.x, 0) * lowgate(z)
   g_b = gravity in the trunk frame (on the back g_b.x ~ -1, face down ~ +1,
   upright ~ 0), lowgate = 1 at or below 0.09 m trunk height, 0 at or above
   0.11 m (smoothstep). 0.09 m is the top of the prone spawn band
   (prone_z_max), so a face-up spawn starts at its full phi and the ~2 cm drop
   onto the back after reset charges nothing (a 0.08 m gate did: the 64-env
   probe logged the term slightly negative from that landing alone). The
   term pays phi(t) - phi(t-1) each step. Why this shape:
   - the freeze sits at g_b.x ~ -0.90; every way out (roll onto the side or
     belly, or pitch up over the feet) moves g_b.x toward 0, and the term pays
     for that motion from the first centimetre. In the maker's reward set the
     roll off the back COSTS reward: upright_linear is cos(tilt) and falls
     from ~0.44 (the reclined freeze) to 0 on the side, so partial rolls are
     net-negative until the face-down rise pays much later (the maker's own
     note at set_random_ground_state calls the supine->prone landscape flat).
   - it telescopes: the episode total is phi(end) - phi(start) <= 1 x weight,
     so no pose can farm it (holding anything pays 0, rocking nets 0). Same
     construction as the maker's upright_progress / height_progress in
     mdp.py (velstand), which were adopted after gated state rewards were
     farmed three runs in a row. Standing, face-down and on-side poses all
     have phi = 0; only back-lying low poses are negative.
   - not upright_progress itself: Delta cos(tilt) is NEGATIVE along the roll
     off the back (cos 0.44 -> 0), i.e. it would push toward the freeze.
   - weight 10: a 0.5 s roll from the freeze to the side pays ~0.36/step
     (unscaled), about the ~0.33/step average upright_linear dip along that
     roll, so a roll attempt is no longer net-negative; the whole turn is worth
     <= 10 (unscaled) once per episode, well under the stand attractors
     (task mass ~12 per step while standing).

Everything else, including the late attempt-taxes (arrival_damping,
head_pose_bias, joint_torque_rate), stays exactly as in StandUp. With the
counter restored at 600072 those curricula are already on their final stages,
the same regime the policy trained under from iter ~4000 to 25000, so the
warm start sees no weight shock. If the back freeze survives this run, the
maker's documented next lever (standup cfg comment on body_ang_vel) is to halve
body_ang_vel to -0.025, then soften action_rate's end to -0.6.
"""

import torch

from mjlab.envs.manager_based_rl_env import ManagerBasedRlEnv
from mjlab.managers import RewardTermCfg
from mjlab.managers.scene_entity_config import SceneEntityCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.tasks import MicroduckOnPolicyRunner
from mjlab_microduck.tasks.microduck_standup_env_cfg import (
    MicroduckStandUpRlCfg,
    make_microduck_standup_env_cfg,
)

TASK_ID = "Mjlab-StandUpBack-Flat-MicroDuck"

# Spawn mix (probabilities are normalised by set_random_ground_state).
BACK_MIX = {
    "standing_prob": 0.15,
    "sitting_prob": 0.15,
    "face_down_prob": 0.20,
    "face_up_prob": 0.50,
}

TURNOVER_WEIGHT = 10.0
TURNOVER_GATE_Z_FULL = 0.09  # m, full gate at or below (= prone_z_max, top of the prone spawn band)
TURNOVER_GATE_Z_ZERO = 0.11  # m, zero gate at or above (standing_z_min)


def supine_turnover_progress(
    env: ManagerBasedRlEnv,
    gate_z_full: float = TURNOVER_GATE_Z_FULL,
    gate_z_zero: float = TURNOVER_GATE_Z_ZERO,
    asset_cfg: SceneEntityCfg = SceneEntityCfg("robot", body_names=("trunk_base",)),
) -> torch.Tensor:
    """Potential-based shaping: Delta of phi = min(g_b.x, 0) * lowgate(z).

    Positive while the robot turns off its back (g_b.x from -1 toward 0),
    negative when it falls onto its back, zero for holding any pose. Freshly
    reset envs get no spurious delta from the previous episode's end state
    (same guard as mdp.upright_progress).
    """
    asset = env.scene[asset_cfg.name]
    gx = torch.nan_to_num(asset.data.projected_gravity_b[:, 0], nan=0.0)
    z = torch.nan_to_num(
        asset.data.root_link_pos_w[:, 2] - env.scene.terrain.env_origins[:, 2], nan=1.0
    )
    t = torch.clamp((gate_z_zero - z) / max(gate_z_zero - gate_z_full, 1e-6), 0.0, 1.0)
    low = t * t * (3.0 - 2.0 * t)
    phi = torch.clamp(gx, max=0.0) * low
    if not hasattr(env, "_witcheer_turnover_phi_prev"):
        env._witcheer_turnover_phi_prev = phi.clone()
    fresh = env.episode_length_buf <= 1
    env._witcheer_turnover_phi_prev[fresh] = phi[fresh]
    delta = phi - env._witcheer_turnover_phi_prev
    env._witcheer_turnover_phi_prev = phi.clone()
    return delta


def make_witcheer_standup_backgetup_env_cfg(play: bool = False):
    cfg = make_microduck_standup_env_cfg(play=play)

    # 1. spawn mix weighted to the back, flat from step 0 (see module doc).
    cfg.events["set_ground_state"].params.update(BACK_MIX)
    cfg.curriculum["ground_state_mix"].params["param_stages"] = [
        {"step": 0, "params": dict(BACK_MIX)},
    ]

    # 2. the one reward change: pay the turn off the back.
    cfg.rewards["supine_turnover_progress"] = RewardTermCfg(
        func=supine_turnover_progress,
        weight=TURNOVER_WEIGHT,
        params={
            "gate_z_full": TURNOVER_GATE_Z_FULL,
            "gate_z_zero": TURNOVER_GATE_Z_ZERO,
            "asset_cfg": SceneEntityCfg("robot", body_names=("trunk_base",)),
        },
    )
    return cfg


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_standup_backgetup_env_cfg(),
    play_env_cfg=make_witcheer_standup_backgetup_env_cfg(play=True),
    rl_cfg=MicroduckStandUpRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
