"""terrain_demote_arms_patch.py (2026-09-29): split the tracking curriculum's demote_rate by arm (logging only).

`terrain_levels_tracking` demotes when tracking < down_ratio x ref OR the episode ended before half its length.
after the ground-z fix the demote rate stayed ~0.6 in the first 200 iterations (probe-groundz), so the next run logs
which arm fires: demote_short_rate (ended before half its length) and demote_track_rate (ran >= half, tracked poorly).
no behaviour change. idempotent; backup mdp.py.bak-demotearms-2026-09-29.
"""
import os
import pathlib
import shutil

mdp = pathlib.Path(os.environ.get("MICRODUCK_RL", ".")) / "src/mjlab_microduck/tasks/mdp.py"
bak = mdp.with_name("mdp.py.bak-demotearms-2026-09-29")
s = mdp.read_text()
if '"demote_short_rate"' in s:
    print("already patched")
    raise SystemExit(0)
if not bak.exists():
    shutil.copy2(mdp, bak)
old = '''        "demote_rate": move_down.float().sum() / n,
        "episode_track": (track * valid).sum() / n,'''
new = '''        "demote_rate": move_down.float().sum() / n,
        "demote_short_rate": (move_down & (survival < 0.5)).float().sum() / n,
        "demote_track_rate": (move_down & (survival >= 0.5)).float().sum() / n,
        "episode_track": (track * valid).sum() / n,'''
assert s.count(old) == 1, s.count(old)
mdp.write_text(s.replace(old, new))
print("patched: demote_short_rate + demote_track_rate")
