"""witcheer fork: Microduck BallKick with the GIANT ball (300 mm) AND an aim term, gear play, sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck`` by one import line appended to the end of
``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why (2026-10-26): the 09z10 giant-ball kick (``Mjlab-BallKick-Flat-Backlash-Big-MicroDuck``, duckbigkick
model_16000) won on POWER (ball >= 1.25 m by 2 s: 9 of 15 takes vs 0 of 15 for its seed) but aims badly: with the goal
in the scene it put the ball in the goal 1 of 15 times, the seed 15 of 15. The 15 takes of proof-bk-a are not noisy:
the ball leaves at -26 to -34 degrees off the heading in 14 of 15 takes (median -30.5, one take -15.3), i.e. a
systematic 30 degree deflection to the right that the 3,000 power iterations introduced (the seed's median is +0.7).
The policy is blind to ball and goal by design, so "aim" can only mean "kick along the heading you were spawned
with", and the task already has the lever for it: ``ball_lateral_speed`` in witcheer_ballkick_big_env_cfg.py, the
ball's velocity component PERPENDICULAR to the per-env kick direction (the heading at reset), switched off there
(``MICRODUCK_BIGKICK_AIM_W`` = 0). This task is the Big task with that existing term switched ON.

ONE change against ``Mjlab-BallKick-Flat-Backlash-Big-MicroDuck``: reward ``ball_lateral`` with weight -AIM_W
(default 20, override ``MICRODUCK_BIGAIM_W``, read at import). Everything else is the Big task's (ball, reset offset,
forward-velocity reward capped at 1.0 m/s with weight 12, overshoot penalty, curricula, DR, 5 s episodes); the verdict
play env is identical to the Big task's play env (rewards are not used in play; the goal is still a play-only
entity behind ``MICRODUCK_BIGKICK_GOAL=1``, read by the Big module).

Why 20 (pre-queue sweep 2026-10-26, bigaim-sweep-2026-10-26.sh, 200 warm-start iterations at 4096 envs from
duckbigkick model_16000 per weight, 6 goal takes per checkpoint, giant ball, no shoves): the reference model_16000 re-taken:
goal 0/6, median aim -29.7 deg. W=3: aim unchanged (-30.9 at +40, -26.7 at +200 iterations, goal 0/6), the training
lateral term did not move (logged term / W 0.40 -> 0.39). W=8: slow (-25.2 at +40, -23.8 at +200, goal 2/6, logged term / W 0.38 -> 0.28).
W=20: -31.2 at +40 (no change yet) then -3.4 deg at +200, goal 6/6, ball >= 1.25 m by 2 s 6/6, travel at 2 s 1.44 m (the net stops the
ball there), logged term / W 0.40 -> 0.09, forward term 10.99 -> 9.7 of 12 (ball 0.76 m at 1 s against 0.97 m: a slower first second).
So the aim term works only at a high weight, and costs some early ball speed; the 3,000 iterations show whether the power survives.

Scale of the term at 20: 20 per m/s of sideways ball speed. A 1.0 m/s kick at 30 degrees off the heading has 0.5 m/s of
lateral speed, so the term costs 10 per step while the ball rolls, against 12 per m/s of forward speed up to the 1.0 m/s cap.
It is an absolute value (no sign), so it cannot be gamed by pushing the error to the other side.
"""

import os

from mjlab.managers import RewardTermCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.tasks import MicroduckBallKickRlCfg, MicroduckOnPolicyRunner
from mjlab_microduck.tasks.witcheer_ballkick_big_env_cfg import (
    ball_lateral_speed,
    make_witcheer_ballkick_big_env_cfg,
)

TASK_ID = "Mjlab-BallKick-Flat-Backlash-Big-Aim-MicroDuck"

AIM_W = float(os.environ.get("MICRODUCK_BIGAIM_W", "20.0"))


def make_witcheer_ballkick_bigaim_env_cfg(play: bool = False):
    cfg = make_witcheer_ballkick_big_env_cfg(play=play)
    assert "ball_lateral" not in cfg.rewards, "Big task already carries an aim term (MICRODUCK_BIGKICK_AIM_W set?)"
    cfg.rewards["ball_lateral"] = RewardTermCfg(func=ball_lateral_speed, weight=-AIM_W, params={"asset_name": "ball"})
    return cfg


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_ballkick_bigaim_env_cfg(),
    play_env_cfg=make_witcheer_ballkick_bigaim_env_cfg(play=True),
    rl_cfg=MicroduckBallKickRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
