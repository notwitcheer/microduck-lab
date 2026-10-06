"""ground_height_patch.py (2026-09-29): measure the trunk against the ground UNDER the duck on rough terrain.

bug (found 2026-09-29, log.md): every height read in mdp.py is `root_z - env_origins[:, 2]`. pyramid stairs and
slopes put the env origin on the TOP platform, so an upright duck ~40 mm down the steps counts as fallen
(`_fallen_mask`, VelStand gate 0.08 m) and `fallen_too_long` resets it 8 s later (RESET at 8.08 / 16.18 s with
grav_b z -1.00 in the forced-terrain takes); the height-shaped rewards are skewed the same way.

fix: `_ground_z(env)` = mean hit height of the existing `foot_height_scan` rays (2 feet x 2 rays, straight down,
terrain geoms only) on generator terrain; env-origin z everywhere else (plane terrain has `terrain_origins is None`,
and tasks without the sensor), so flat tasks compute exactly what they did before. every
`root_link_pos_w[:, 2] - env.scene.terrain.env_origins[:, 2]` read in a function body is rewritten to use it.
the SitStand command term's `_alpha_from_height` (self._env_ref form) is left alone: SitStand-Rough has no foot
sensor in its cfg and holds still on its platform.

idempotent; writes mdp.py.bak-groundz-2026-09-29 on first run.
"""
import os
import pathlib
import shutil

mdp = pathlib.Path(os.environ.get("MICRODUCK_RL", ".")) / "src/mjlab_microduck/tasks/mdp.py"
bak = mdp.with_name("mdp.py.bak-groundz-2026-09-29")
s = mdp.read_text()
if "def _ground_z(" in s:
    print("already patched")
    raise SystemExit(0)
if not bak.exists():
    shutil.copy2(mdp, bak)

OLD = "asset.data.root_link_pos_w[:, 2] - env.scene.terrain.env_origins[:, 2]"
NEW = "asset.data.root_link_pos_w[:, 2] - _ground_z(env)"
n = s.count(OLD)

helper = '''def _ground_z(env: ManagerBasedRlEnv) -> torch.Tensor:
    """Ground height under the robot, per env.

    Generator (rough) terrain with the per-foot `foot_height_scan` ray sensor: the mean
    height of the rays' terrain hits under both feet. Anything else (plane terrain, where
    `terrain_origins` is None, or a task without the sensor): the env origin's z, which is
    what every height read used before 2026-09-29, so flat tasks are unchanged. On pyramid
    stairs/slopes the origin sits on the top platform, and origin-relative heights read an
    upright duck a few steps down as fallen (see ground_height_patch.py).
    """
    terrain = env.scene.terrain
    origin_z = terrain.env_origins[:, 2]
    if getattr(terrain, "terrain_origins", None) is None or "foot_height_scan" not in env.scene.sensors:
        return origin_z
    d = env.scene.sensors["foot_height_scan"].data
    hit_z = d.hit_pos_w[..., 2]
    ok = (d.distances >= 0) & (d.normals_w[..., 2] > 0)
    cnt = ok.sum(dim=-1)
    mean = torch.where(ok, hit_z, torch.zeros_like(hit_z)).sum(dim=-1) / cnt.clamp(min=1)
    return torch.where(cnt > 0, mean, origin_z)


'''
i = s.index("def _fallen_mask(")
s = s[:i] + helper + s[i:]
s = s.replace(OLD, NEW)
mdp.write_text(s)
print(f"patched: helper added, {n} height reads rewritten")
