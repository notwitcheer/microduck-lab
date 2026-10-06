import os
import re, shutil, pathlib, datetime
root = pathlib.Path(os.environ.get("MICRODUCK_RL", "."))
mdp = root / "src/mjlab_microduck/tasks/mdp.py"
cfg = root / "src/mjlab_microduck/tasks/microduck_velocity_env_cfg.py"
if "def tracking_level_moves(" in mdp.read_text():
    print("already patched (restore mdp.py + microduck_velocity_env_cfg.py with git checkout before re-running the chain)")
    raise SystemExit(0)
for f in (mdp, cfg):
    b = f.with_name(f.name + ".bak-terrain-2026-09-28")
    if not b.exists():
        shutil.copy2(f, b)
code = '''


# ── terrain curriculum scaled to the Microduck (witcheer, 2026-09-28) ─────────
# mjlab's stock terrain_levels_vel is tuned for a ~1 m/s quadruped on 8 m tiles:
# promote only if the robot ends > size/2 = 4 m from its spawn, demote if it ends
# closer than |cmd| * 20 s * 0.5. The Microduck's commands are capped at 0.4 m/s
# and resample every 3-8 s in a random direction, so net displacement almost
# never reaches 4 m and usually misses the demote bar: every rough run collapsed
# to level 0 (terrain_levels/mean ~0.001 on Velocity-Rough 09-19 and
# VelStand-Rough 09-28), and level 0 of MICRODUCK_ROUGH_TERRAINS_CFG is flat in
# practice (difficulty < 0.1: steps < 1.5 mm, grid < 1 mm, slope < 3.7%).
# This rule judges what the policy did instead of how far it drifted: mean
# linear-velocity tracking over the episode (the tracking kernel, 0..1) and
# whether the episode ran to (near) its full length.

def tracking_level_moves(track, survival, up_track=0.8, down_track=0.5, min_survival=0.9, valid=None):
    """Pure mask logic (unit-tested). track: mean tracking kernel over the episode
    (0..1); survival: elapsed / max episode length (0..1). Promote when tracking is
    good AND the episode ran >= min_survival; demote when tracking is poor OR the
    episode ended before half its length (fell and terminated). Envs with
    valid=False (episode length 0, e.g. the very first reset) never move."""
    move_up = (track > up_track) & (survival >= min_survival)
    move_down = ((track < down_track) | (survival < 0.5)) & ~move_up
    if valid is not None:
        move_up = move_up & valid
        move_down = move_down & valid
    return move_up, move_down


def terrain_levels_tracking(
    env: ManagerBasedRlEnv,
    env_ids: torch.Tensor,
    command_name: str = "twist",
    reward_name: str = "track_linear_velocity",
    up_track: float = 0.8,
    down_track: float = 0.5,
    min_survival: float = 0.9,
) -> dict[str, torch.Tensor]:
    terrain = env.scene.terrain
    assert terrain is not None
    steps = env.episode_length_buf[env_ids].float()
    valid = steps > 0
    elapsed = steps * env.step_dt
    survival = elapsed / env.max_episode_length_s
    rm = env.reward_manager
    if reward_name in rm._episode_sums:
        w = rm._term_cfgs[rm._term_names.index(reward_name)].weight
        # _episode_sums accumulate value * weight * dt, so this is the mean kernel value.
        track = rm._episode_sums[reward_name][env_ids] / (w * elapsed.clamp(min=env.step_dt)) if w else torch.ones_like(survival)
    else:
        track = torch.ones_like(survival)
    move_up, move_down = tracking_level_moves(track, survival, up_track, down_track, min_survival, valid)
    terrain.update_env_origins(env_ids, move_up, move_down)
    levels = terrain.terrain_levels.float()
    n = max(int(valid.sum()), 1)
    return {
        "mean": torch.mean(levels),
        "max": torch.max(levels),
        "promote_rate": move_up.float().sum() / n,
        "demote_rate": move_down.float().sum() / n,
        "episode_track": (track * valid).sum() / n,
    }
'''
s = mdp.read_text()
if "def terrain_levels_tracking" not in s:
    mdp.write_text(s.rstrip("\n") + code)
c = cfg.read_text()
old = "        cfg.scene.terrain.terrain_generator = MICRODUCK_ROUGH_TERRAINS_CFG\n\n        # Soften terrain box contacts"
new = ("        cfg.scene.terrain.terrain_generator = MICRODUCK_ROUGH_TERRAINS_CFG\n\n"
       "        # Microduck-scaled terrain curriculum (2026-09-28): the stock distance rule\n"
       "        # (promote at 4 m net drift) parked every rough run on level 0, which is flat in\n"
       "        # practice. See microduck_mdp.terrain_levels_tracking.\n"
       "        cfg.curriculum[\"terrain_levels\"] = CurriculumTermCfg(\n"
       "            func=microduck_mdp.terrain_levels_tracking,\n"
       "            params={\"command_name\": \"twist\"},\n"
       "        )\n\n"
       "        # Soften terrain box contacts")
if "terrain_levels_tracking" not in c:
    assert c.count(old) == 1, "anchor not found"
    cfg.write_text(c.replace(old, new))
t = root / "tests/test_terrain_tracking_curriculum.py"
t.write_text('''import torch
from mjlab_microduck.tasks.mdp import tracking_level_moves


def test_good_tracking_full_episode_promotes():
    up, down = tracking_level_moves(torch.tensor([0.9]), torch.tensor([1.0]))
    assert bool(up[0]) and not bool(down[0])


def test_good_tracking_but_short_episode_does_not_promote():
    up, down = tracking_level_moves(torch.tensor([0.9]), torch.tensor([0.7]))
    assert not bool(up[0]) and not bool(down[0])


def test_fell_early_demotes_even_with_good_tracking():
    up, down = tracking_level_moves(torch.tensor([0.95]), torch.tensor([0.3]))
    assert not bool(up[0]) and bool(down[0])


def test_poor_tracking_demotes():
    up, down = tracking_level_moves(torch.tensor([0.4]), torch.tensor([1.0]))
    assert not bool(up[0]) and bool(down[0])


def test_middle_band_stays():
    up, down = tracking_level_moves(torch.tensor([0.65]), torch.tensor([1.0]))
    assert not bool(up[0]) and not bool(down[0])


def test_first_reset_never_moves():
    up, down = tracking_level_moves(torch.tensor([0.0]), torch.tensor([0.0]), valid=torch.tensor([False]))
    assert not bool(up[0]) and not bool(down[0])
''')
print("patched")
