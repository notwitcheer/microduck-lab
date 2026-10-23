"""witcheer fork v3 of the Microduck StandUp task: get up from the BACK, third attempt.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered
as ``Mjlab-StandUpBack3-Flat-MicroDuck`` by one import line appended to the end
of ``tasks/__init__.py`` (after the v2 line); nothing else in the Pollen tree
is edited.

Why v3: v1 (09h, 25000 -> 28000) and v2 (09i, 28000 -> 31000, taxes off,
body_ang_vel halved, turnover from the running minimum, std x2 + entropy 0.02)
both scored 0 of 3 forced face-up takes: the same half-rolled freeze at
body-frame gravity ~(-0.89, 0, -0.45), trunk ~59-62 mm. Two levers were left
unused (60-robotics/microduck/log.md 2026-09-25):

1. ACTION_RATE SOFTENED, -1.0 -> -0.6. The maker's documented SECOND lever
   (standup cfg, sim2real regulariser block): "If recovery freezes: halve
   body_ang_vel to -0.025 first, then soften the action_rate curriculum end
   to -0.6." The same block records that raising the action_rate end to -1.2
   (old scale) killed back-recovery: the penalty blocks the fast whole-body
   motion a flip needs. mjlab restores ``common_step_counter`` on a warm
   start, so the curriculum sits on its last stage forever; v3 replaces the
   ``action_rate_weight`` stages with one step-0 stage at -0.6 and sets the
   reward weight to -0.6.

2. SPAWN MIX 80% ON THE BACK (v1/v2: 50%). face_up 0.80 / face_down 0.10 /
   sitting 0.05 / standing 0.05: most practice goes to the one pose it cannot
   do, and the other three stay in the mix so the get-ups it already has are
   not forgotten (the verdict takes check all four).

Everything else is v2 (taxes off, body_ang_vel -0.025, running-minimum
turnover at weight 10, entropy_coef 0.02). Warm start: v2's final
model_31000 as-is (its action std ended at 0.25, still ~1.5x the StandUp
lineage's 0.17, so no std bump this time).
"""

import dataclasses

from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.tasks import MicroduckOnPolicyRunner
from mjlab_microduck.tasks.witcheer_standup_backgetup2_env_cfg import (
    BackGetup2RlCfg,
    make_witcheer_standup_backgetup2_env_cfg,
)

TASK_ID = "Mjlab-StandUpBack3-Flat-MicroDuck"

ACTION_RATE_WEIGHT = -0.6  # maker's documented second lever (StandUp end stage: -1.0)

BACK3_MIX = {
    "standing_prob": 0.05,
    "sitting_prob": 0.05,
    "face_down_prob": 0.10,
    "face_up_prob": 0.80,
}


def make_witcheer_standup_backgetup3_env_cfg(play: bool = False):
    cfg = make_witcheer_standup_backgetup2_env_cfg(play=play)  # v2: taxes off, ang_vel halved, turnover v2

    # 1. action_rate softened: single step-0 stage (the counter is restored, see doc).
    cfg.curriculum["action_rate_weight"].params["weight_stages"] = [
        {"step": 0, "weight": ACTION_RATE_WEIGHT},
    ]
    cfg.rewards["action_rate_l2"].weight = ACTION_RATE_WEIGHT

    # 2. spawn mix 80% on the back, flat from step 0.
    cfg.events["set_ground_state"].params.update(BACK3_MIX)
    cfg.curriculum["ground_state_mix"].params["param_stages"] = [
        {"step": 0, "params": dict(BACK3_MIX)},
    ]
    return cfg


BackGetup3RlCfg = dataclasses.replace(BackGetup2RlCfg)

register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_standup_backgetup3_env_cfg(),
    play_env_cfg=make_witcheer_standup_backgetup3_env_cfg(play=True),
    rl_cfg=BackGetup3RlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
