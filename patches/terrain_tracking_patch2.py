import os
import pathlib
mdp = pathlib.Path(os.environ.get("MICRODUCK_RL", ".")) / "src/mjlab_microduck/tasks/mdp.py"
s = mdp.read_text()
if "level0_ref" in s or "def _ground_z(" in s or '"demote_short_rate"' in s:
    print("already patched (this patch rewrites mdp.py from terrain_levels_tracking to the end; restore with git checkout and re-run the chain in order)")
    raise SystemExit(0)
i = s.index("def terrain_levels_tracking(")
new_fn = '''def terrain_levels_tracking(
    env: ManagerBasedRlEnv,
    env_ids: torch.Tensor,
    command_name: str = "twist",
    reward_name: str = "track_linear_velocity",
    up_ratio: float = 0.95,
    down_ratio: float = 0.7,
    min_survival: float = 0.9,
    ref_alpha: float = 0.02,
) -> dict[str, torch.Tensor]:
    """Thresholds are RELATIVE to how well the policy tracks on level 0 (flat in
    practice), kept as an EMA over level-0 resets: promote when an episode ran to
    >= min_survival of its length and tracked >= up_ratio of the level-0 reference
    ("as good as on flat, go harder"); demote when it tracked < down_ratio of it or
    ended before half its length. Absolute thresholds (0.8/0.5) failed on the first
    probe 2026-09-28: VelStand's own flat-ground tracking kernel averages ~0.5-0.6
    (it spends time standing and recovering), so half of every batch was demoted."""
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
    lvl0 = valid & (terrain.terrain_levels[env_ids] == 0) & (survival >= min_survival)
    ref = getattr(env, "_microduck_terrcur_ref", None)
    if bool(lvl0.any()):
        batch = track[lvl0].mean()
        ref = batch if ref is None else (1 - ref_alpha) * ref + ref_alpha * batch
        env._microduck_terrcur_ref = ref
    if ref is None:
        ref = (track * valid).sum() / max(int(valid.sum()), 1)
    move_up, move_down = tracking_level_moves(track, survival, up_ratio * ref, down_ratio * ref, min_survival, valid)
    terrain.update_env_origins(env_ids, move_up, move_down)
    levels = terrain.terrain_levels.float()
    n = max(int(valid.sum()), 1)
    return {
        "mean": torch.mean(levels),
        "max": torch.max(levels),
        "promote_rate": move_up.float().sum() / n,
        "demote_rate": move_down.float().sum() / n,
        "episode_track": (track * valid).sum() / n,
        "level0_ref": torch.as_tensor(ref, dtype=torch.float),
    }
'''
mdp.write_text(s[:i] + new_fn)
print("patched v2")
