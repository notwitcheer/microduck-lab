"""witcheer fork: Microduck leans into a rising wind, v3 (09z48): the upright target follows the wind. Sim only.

Not a Pollen file. Lane: witcheer's robotics lane (simulation only). Registered as
``Mjlab-Velocity-Flat-Backlash-Lean3-MicroDuck`` by one import line appended to the end of
``tasks/__init__.py``; nothing else in the Pollen tree is edited.

Why v3. The lean env (09z42 / 09z45) adds ``lean_into_wind`` on top of the maker's ``upright`` term
(Gaussian on trunk tilt, weight 2.0, std^2 0.05, target 0 deg). The two terms pull against each other, and
the static optimum of their sum is a fixed number, set by the weights alone:

    total(theta) = 2.0 * exp(-sin^2(theta) / 0.05) + LEAN_W * clamp(theta / 12.6, 0, 1)
    LEAN_W 0.5 -> optimum 1.7 deg      LEAN_W 1.5 -> optimum 6.2 deg

The trained policies sat at +2 to +4 deg (0.5) and +7 to +11 deg (1.5), each reached within ~250 iterations
and flat after: an equilibrium, not an iteration shortage. Raising the weight further only moves that
equilibrium slowly. v3 moves the upright term's TARGET instead.

The diff from the lean env is ONE change: ``upright`` keeps its weight and std, but its target pitch is

    target = clamp(atan(F_wind / W_DUCK), 0, LEAN3_CAP_DEG)     (forward lean, + = nose down = into the wind)

F_wind = the current headwind force (the gale ramp x the episode's peak), W_DUCK = 7.8 N (the duck's weight,
gale env docstring). atan(F/W) is the lean at which the weight and the wind add to a force through the feet.
With no wind the target is 0 deg and the term equals the stock upright exactly, so the no-wind gait is
unchanged. LEAN3_CAP_DEG = 15 deg (env ``MICRODUCK_LEAN3_CAP``): 2.4 deg above the pre-registered 12.6 deg bar,
well inside the lean term's 30 deg upright gate and the 70 deg fall termination. at 2.0 N the target is 14.4 deg,
at 3.0 N and 4.0 N it is capped at 15 deg. ``lean_into_wind`` stays at LEAN_W 1.5 (the 09z45 value).

The actor and critic observations are unchanged (61 / 76), so the walk-flat v2 seed resumes with no size
mismatch; the policy does not observe the wind and infers it from its own state, as in the gale.

Verdict: the 09z42 frozen rule, unchanged (vault status note, V3 section).
"""

import math
import os

import torch
from mjlab.managers import RewardTermCfg
from mjlab.tasks.registry import register_mjlab_task

from mjlab_microduck.tasks import MicroduckOnPolicyRunner, MicroduckRlCfg
from mjlab_microduck.tasks.witcheer_velocity_gale_env_cfg import wind_force_now
from mjlab_microduck.tasks.witcheer_velocity_lean_env_cfg import make_witcheer_lean_env_cfg

TASK_ID = "Mjlab-Velocity-Flat-Backlash-Lean3-MicroDuck"

W_DUCK = 7.8  # N, the duck's weight (gale env docstring: "the duck weighs ~7.8 N")
LEAN3_CAP_DEG = float(os.environ.get("MICRODUCK_LEAN3_CAP", "15.0"))


def lean3_target_rad(env):
    """(N,) target forward lean in radians: atan(F / W), clamped to [0, cap]."""
    f = wind_force_now(env)
    t = torch.atan(f / W_DUCK)
    return torch.clamp(t, 0.0, math.radians(LEAN3_CAP_DEG))


def upright_wind_target(env, std: float):
    """the maker's upright Gaussian with the pitch target moved to the wind lean.

    stock: exp(-(gx^2 + gy^2) / std^2), gx, gy = projected gravity in the trunk frame (target 0).
    v3:    exp(-((gx - sin(target))^2 + gy^2) / std^2). lean = asin(gx), + = nose down (same sign as the gm logger
    and ``lean_into_wind``). target 0 (no wind) gives the stock value exactly.
    """
    gb = env.scene["robot"].data.projected_gravity_b
    dx = gb[:, 0] - torch.sin(lean3_target_rad(env))
    return torch.exp(-(dx * dx + gb[:, 1] * gb[:, 1]) / (std * std))


def make_witcheer_lean3_env_cfg(play: bool = False):
    cfg = make_witcheer_lean_env_cfg(play=play)
    old = cfg.rewards["upright"]
    cfg.rewards["upright"] = RewardTermCfg(
        func=upright_wind_target, weight=old.weight, params={"std": old.params["std"]}
    )
    return cfg


register_mjlab_task(
    task_id=TASK_ID,
    env_cfg=make_witcheer_lean3_env_cfg(),
    play_env_cfg=make_witcheer_lean3_env_cfg(play=True),
    rl_cfg=MicroduckRlCfg,
    runner_cls=MicroduckOnPolicyRunner,
)
