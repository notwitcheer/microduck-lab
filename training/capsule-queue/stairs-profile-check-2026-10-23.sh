#!/bin/bash
# stairs-profile-check-2026-10-23.sh: builds each stairs tile type on its own with mjlab's own generator function (difficulty 1.0 and 0.0 =
# riser 25 mm and 10 mm), ray-casts the height profile along the tile's x axis from the border to the centre, and prints riser count,
# tread depth, centre height and platform size per tile; also generates the full random grid once and counts the tile mix by origin
# height. CPU only, no GPU. expectation: stairs2 = 2 risers, stairs3 = 3 risers, tread 0.25 m, centre = n risers x h.
exec > >(tee -a /home/witcheer/Pollen/stairs-profile-check-2026-10-23.log) 2>&1
export PATH=/home/witcheer/.local/bin:$PATH
cd /home/witcheer/Pollen/microduck_rl
uv run python - <<'PY' 2>&1 | grep -E "^(PROF|MIX|ERR)"
import traceback
import numpy as np
try:
    import mujoco, mjlab_microduck.tasks  # noqa
    from mjlab.tasks.registry import load_env_cfg
    from mjlab.terrains.terrain_generator import TerrainGenerator
    cfg = load_env_cfg("Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck")
    g = cfg.scene.terrain.terrain_generator
    for name, sub in g.sub_terrains.items():
        sub.size = g.size
        if name == "hill": continue  # heightfield tile, proven in 09z5/09z7
        for diff in (1.0, 0.0):
            spec = mujoco.MjSpec(); spec.worldbody.add_body(name="terrain")
            out = sub.function(diff, spec, np.random.default_rng(0))
            for i, gm in enumerate(spec.body("terrain").geoms): gm.name = f"t{i}"
            m = spec.compile(); d = mujoco.MjData(m); mujoco.mj_forward(m, d)
            # ray down along the tile's centre line y, x from 0 to 4 (tile corner frame), 1 cm resolution
            xs = np.arange(0.005, g.size[0], 0.01); hs = []
            for x in xs:
                gid = np.zeros(1, dtype=np.int32)
                dist = mujoco.mj_ray(m, d, np.array([x, 0.5 * g.size[1], 2.0]), np.array([0, 0, -1.0]), None, 1, -1, gid)
                hs.append(2.0 - dist if dist >= 0 else float("nan"))
            hs = np.array(hs)
            lv = np.round(hs * 1000, 1)
            # distinct plateau heights along the first half of the tile (edge -> centre)
            half = lv[: len(lv) // 2 + 1]
            plateaus = []
            for v in half:
                if not plateaus or abs(v - plateaus[-1][0]) > 0.2: plateaus.append([v, 1])
                else: plateaus[-1][1] += 1
            risers = sum(1 for a, b in zip(plateaus, plateaus[1:]) if b[0] > a[0] + 0.5)
            print("PROF %-11s diff %.1f origin_z %.1f mm | plateaus edge->centre (height mm, length cm): %s | risers %d | centre %.1f mm" % (name, diff, out.origin[2] * 1000, [(a, b) for a, b in plateaus], risers, lv[len(lv) // 2]))
    # full random grid: tile mix by tile origin height + count
    tg = TerrainGenerator(g, device="cpu"); spec = mujoco.MjSpec(); tg.compile(spec)
    o = tg.terrain_origins[..., 2].reshape(-1) * 1000
    print("MIX grid %dx%d tile origin z mm: flat/hill-or-0: %d, >0: %d, max %.1f; geoms %d" % (g.num_rows, g.num_cols, int((o < 0.5).sum()), int((o >= 0.5).sum()), o.max(), len(spec.body("terrain").geoms)))
except Exception:
    print("ERR", traceback.format_exc().replace("\n", " | ")[-1800:])
PY
echo "=== $(date -u +%T) PROFILE_CHECK_END ==="
