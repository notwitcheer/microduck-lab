"""terrain_prone_neutral_patch.py (2026-09-29): prone/crouch-start episodes do not move the terrain level.

VelStand resets ~45% of envs on the ground (`prone_init_prob` 0.45 via maybe_set_random_prone_orientation, plus a
crouch slice). a failed get-up ends the episode at `fallen_too_long` (8 s), i.e. before half its length, which is a
demote in `terrain_levels_tracking` whatever the terrain. with the demote arms logged, the demotes were all the
short arm (smoke 2026-09-29). this makes those episodes NEUTRAL for the terrain move (no promote, no demote); walking
episodes that started upright still promote/demote as before.

- maybe_set_random_prone_orientation records env._microduck_prone_start (bool per env: True for the prone and crouch
  slices of this reset, False for the rest of env_ids). mjlab's _reset_idx computes the curriculum BEFORE the reset
  events, so at curriculum time the flag describes the episode that just ended.
- terrain_levels_tracking(neutral_prone_starts=False) masks those envs out of move_up/move_down when True and logs
  prone_start_share. the rough branch of make_microduck_velocity_env_cfg passes True (Velocity-Rough has no prone
  event, so the flag never exists there and nothing changes).

idempotent; backups *.bak-proneneutral-2026-09-29.
"""
import os
import pathlib
import shutil

T = pathlib.Path(os.environ.get("MICRODUCK_RL", ".")) / "src/mjlab_microduck/tasks"
mdp = T / "mdp.py"
cfg = T / "microduck_velocity_env_cfg.py"
s = mdp.read_text()
c = cfg.read_text()
if "_microduck_prone_start" in s:
    print("already patched")
    raise SystemExit(0)
for f in (mdp, cfg):
    b = f.with_name(f.name + ".bak-proneneutral-2026-09-29")
    if not b.exists():
        shutil.copy2(f, b)


def sub(text, old, new, count=1):
    assert text.count(old) == count, (old[:60], text.count(old))
    return text.replace(old, new)


# 1. record prone/crouch starts
s = sub(s, '''    selected = env_ids_t[u < prone_prob]
    crouch_selected = env_ids_t[(u >= prone_prob) & (u < prone_prob + crouch_prob)]
''', '''    selected = env_ids_t[u < prone_prob]
    crouch_selected = env_ids_t[(u >= prone_prob) & (u < prone_prob + crouch_prob)]
    # which envs start this episode on the ground (read by terrain_levels_tracking at the NEXT reset,
    # since the curriculum runs before the reset events). added 2026-09-29.
    if not hasattr(env, "_microduck_prone_start"):
        env._microduck_prone_start = torch.zeros(env.num_envs, dtype=torch.bool, device=env.device)
    env._microduck_prone_start[env_ids_t] = False
    env._microduck_prone_start[selected] = True
    env._microduck_prone_start[crouch_selected] = True
''')

# 2. curriculum param + mask + metric
s = sub(s, '''    min_survival: float = 0.9,
    ref_alpha: float = 0.02,
) -> dict[str, torch.Tensor]:''', '''    min_survival: float = 0.9,
    ref_alpha: float = 0.02,
    neutral_prone_starts: bool = False,
) -> dict[str, torch.Tensor]:''')
s = sub(s, '''    move_up, move_down = tracking_level_moves(track, survival, up_ratio * ref, down_ratio * ref, min_survival, valid)
    terrain.update_env_origins(env_ids, move_up, move_down)''', '''    move_up, move_down = tracking_level_moves(track, survival, up_ratio * ref, down_ratio * ref, min_survival, valid)
    prone = getattr(env, "_microduck_prone_start", None)
    prone = prone[env_ids] if (neutral_prone_starts and prone is not None) else torch.zeros_like(valid)
    move_up = move_up & ~prone
    move_down = move_down & ~prone
    terrain.update_env_origins(env_ids, move_up, move_down)''')
s = sub(s, '''        "demote_track_rate": (move_down & (survival >= 0.5)).float().sum() / n,''', '''        "demote_track_rate": (move_down & (survival >= 0.5)).float().sum() / n,
        "prone_start_share": (prone & valid).float().sum() / n,''')
mdp.write_text(s)

# 3. wire it for the rough branch
c = sub(c, '''            func=microduck_mdp.terrain_levels_tracking,
            params={"command_name": "twist"},''', '''            func=microduck_mdp.terrain_levels_tracking,
            params={"command_name": "twist", "neutral_prone_starts": True},''')
cfg.write_text(c)
print("patched: prone-start flag, neutral_prone_starts=True on the rough branch, prone_start_share metric")
