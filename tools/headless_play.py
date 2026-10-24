"""headless_play.py: record a play clip of a trained mjlab policy with no viewer.

`uv run play ... --viewer viser` fails headless on StandUp (viser slider assertion in
command_manager.create_gui) and `--viewer native` needs an X11 DISPLAY. This wrapper
swaps the viewer class for a plain step loop; the VideoRecorder that `play` already
wraps around the env writes `<ckpt dir>/videos/play/rl-video-step-0.mp4`.

usage (from your microduck_rl checkout, MUJOCO_GL=egl):
  uv run python headless_play.py <task> --checkpoint-file <model_N.pt> --num-envs 1 \
      --video True --video-length 600 [--video-width 1280 --video-height 720] [--steps N]
`--steps` (default video-length + 10), `--cam-world x,y,z|auto` (fixed camera looking at that world point instead of tracking the trunk,
so a stand-up reads as a height change; `auto` aims at the post-reset root x,y at z 0.07, since prone spawns are offset from the origin), `--spawn standing|sitting|face_down|face_up` (forces the set_ground_state reset mix, StandUp-family
tasks; play applies no curriculum so face_up never spawns otherwise), `--episode-s` (override cfg.episode_length_s; StandUp trains on 6 s episodes and a
longer clip would contain a reset that looks like a stand-up), `--cam-distance` (default 0.35 m), `--cam-elevation`
(default -10 deg) and `--cam-azimuth` (default 135 deg) are consumed here and override the
env cfg viewer camera (play exposes no camera flags; the maker default distance 5.0 leaves
the duck at ~10% of frame height). Every other flag goes to mjlab play.
"""
import os
import sys

os.environ.setdefault("MUJOCO_GL", "egl")

argv = sys.argv[1:]


def take(flag, default, cast):
    if flag in argv:
        i = argv.index(flag)
        val = cast(argv[i + 1])
        del argv[i : i + 2]
        return val
    return default


steps = take("--steps", None, int)
cam_distance = take("--cam-distance", 0.35, float)
cam_elevation = take("--cam-elevation", -10.0, float)
cam_azimuth = take("--cam-azimuth", 135.0, float)
episode_s = take("--episode-s", None, float)
cam_world = take("--cam-world", None, str)
cam_world_z = take("--cam-world-z", 0.09, float)  # lookat height for --cam-world auto  # "x,y,z" lookat: fixed world camera instead of trunk tracking
spawn = take("--spawn", None, str)
track_entity = take("--track-entity", None, str)  # scene entity to follow (e.g. ball) instead of the robot trunk  # standing|sitting|face_down|face_up (StandUp-family tasks); standing|midroll (Roulade)
log_every = take("--log-every", 25, int)  # steps between trunk_z/grav_b lines (25 = 0.5 s; a 5 s roll needs 5 = 0.1 s)
log_site = take("--log-site", None, str)  # robot site to log height for (GroundPick: mouth_tip), added 2026-09-23
# rough tasks only (added 2026-09-29): play builds a 5x5 RANDOM terrain (curriculum off), so a 1-env take lands on
# whatever patch; force the training layout (curriculum on, one column per sub-terrain, rows = difficulty levels)
# and put the env on row --terrain-level of column --terrain-type. difficulty of row L = (L + U(0,1)) / rows.
terrain_level = take("--terrain-level", None, int)
terrain_type = take("--terrain-type", None, str)  # flat|pyramid_stairs|random_grid|pyramid_slope (Microduck rough cfg)
terrain_rows = take("--terrain-rows", 10, int)  # training value in MICRODUCK_ROUGH_TERRAINS_CFG
_terrain_names = []
# play shortens the velocity push interval to 0.5-1.0 s "for visibility" (microduck_velocity_env_cfg.py), so every
# play take is also a push test; --no-push drops the push_robot event to isolate terrain (added 2026-09-29).
no_push = "--no-push" in argv
# the rough patches spawn on a flat centre platform (stairs 2.0 m, random grid 1.5 m wide) and a VelStand take barely
# leaves it (found 2026-09-29 by frame check): --spawn-offset D moves the reset x range to (D, D) m from the origin,
# onto the rough part. every sample line also prints r= (planar distance from the env origin) so it can be verified.
spawn_offset = take("--spawn-offset", None, float)
# velocity takes play random twist commands (+-0.4 m/s, turns, standing envs), so a step/terrain verdict can spend a whole
# take near the spawn (found 2026-10-14: v2 control take on the 09z3 step env stayed within r 0.73 m before a reset,
# platform edge at 0.75 m). --cmd-vx V fixes the twist command to straight ahead at V m/s (lin_vel_y 0, ang_vel_z 0).
cmd_vx = take("--cmd-vx", None, float)
# generator-floor velocity forks inherit mjlab's out_of_terrain_bounds (a no-op on the maker's plane): it truncates once the
# root leaves the num_rows x num_cols tile footprint minus 0.3 m, the 20 m border not counted. a 1-env play take lands in
# an EDGE column (found 2026-10-14 on the 09z5 slope env: root y -18.5 on a 40 m grid, so ~1.7 m of walking in -y ends
# the episode with the duck upright; the 09z3 step takes had the same spawn). it prints as a RESET line and scores as a
# fall. --no-bounds drops that termination for the take (the duck walks on onto the flat border).
no_bounds = "--no-bounds" in argv
if no_push:
    argv.remove("--no-push")
if no_bounds:
    argv.remove("--no-bounds")
if steps is None:
    steps = 610
    if "--video-length" in argv:
        steps = int(argv[argv.index("--video-length") + 1]) + 10

import mjlab.scripts.play as play  # noqa: E402


class HeadlessViewer:
    def __init__(self, env, policy, checkpoint_manager=None):
        self.env = env
        self.policy = policy

    def run(self, num_steps=None, catch_sigint=True):
        import torch

        # play's initial state is the env init keyframe (the duck sits at ~66 mm and stands in
        # 0.5 s); a real reset runs the set_ground_state event, so reset once before recording.
        if terrain_level is not None:
            t = self.env.unwrapped.scene.terrain
            col = _terrain_names.index(terrain_type) if terrain_type else 0
            t.terrain_levels[:] = terrain_level
            t.terrain_types[:] = col
            t.env_origins[:] = t.terrain_origins[terrain_level, col]
            o = [float(v) for v in t.env_origins[0]]
            print(f"[headless_play] terrain forced: level {terrain_level}/{terrain_rows - 1} type {_terrain_names[col]} "
                  f"(col {col}) origin=({o[0]:+.2f},{o[1]:+.2f},{o[2]:+.3f})", flush=True)
        obs, _ = self.env.reset()
        base = self.env.unwrapped
        robot = base.scene["robot"]
        dt = base.step_dt
        z0 = float(robot.data.root_link_pos_w[0, 2] - base.scene.terrain.env_origins[0, 2])
        g0 = robot.data.projected_gravity_b[0]
        p0 = [float(v) for v in robot.data.root_link_pos_w[0]]
        ball = base.scene.entities.get("ball") if hasattr(base.scene, "entities") else None
        def ball_xy():
            if ball is None:
                return ""
            b = ball.data.root_link_pos_w[0]
            o = base.scene.terrain.env_origins[0]
            return f" ball=({float(b[0]-o[0]):+.3f},{float(b[1]-o[1]):+.3f},{float(b[2]-o[2]):+.3f})"
        site_id = None
        if log_site:
            try:
                ids, _ = robot.find_sites([log_site])
                site_id = ids[0]
            except Exception as e:  # noqa: BLE001
                print(f"[headless_play] --log-site {log_site}: not found ({e})", flush=True)
        def site_z():
            if site_id is None:
                return ""
            sz = float(robot.data.site_pos_w[0, site_id, 2] - base.scene.terrain.env_origins[0, 2])
            return f" {log_site}_z={sz * 1000:6.1f}mm"
        print(f"[headless_play] after reset: trunk_z={z0 * 1000:6.1f}mm "
              f"grav_b=({float(g0[0]):+.2f},{float(g0[1]):+.2f},{float(g0[2]):+.2f}) "
              f"root_w=({p0[0]:+.3f},{p0[1]:+.3f},{p0[2]:+.3f}){ball_xy()}{site_z()}", flush=True)
        if cam_world == "auto":
            # prone spawns carry an x/y offset from the env origin; a lookat at (0,0,z) films an
            # empty floor (found 2026-09-19). aim the free camera at the post-reset root instead.
            # z 0.09 = midway between a sitting trunk (~0.06) and a standing one (~0.117); at
            # 0.07 with distance 0.5 a standing duck's head touched the frame top (2026-09-19).
            cam = base._offline_renderer._cam
            cam.lookat[:] = (p0[0], p0[1], cam_world_z)
            print(f"[headless_play] cam-world auto: lookat=({p0[0]:+.3f},{p0[1]:+.3f},{cam_world_z:.3f})", flush=True)
        with torch.inference_mode():
            for k in range(steps):
                actions = self.policy(obs)
                out = self.env.step(actions)
                obs = out[0]
                # a termination (e.g. fallen_too_long after 8 s down on VelStand) resets the env mid-clip and reads as a
                # get-up on the frames; print every reset so the verdict can exclude it (found 2026-09-20, level 5 takes).
                if len(out) > 2 and hasattr(out[2], "any") and bool(out[2].any()):
                    print(f"[headless_play] RESET at t={k * dt:6.2f}s step={k:4d} (env termination, not a recovery)", flush=True)
                if k % log_every == 0:
                    z = float(robot.data.root_link_pos_w[0, 2] - base.scene.terrain.env_origins[0, 2])
                    g = robot.data.projected_gravity_b[0]
                    # upright: gravity in body frame points -z (gz ~ -1). face down / on back: |gx| ~ 1.
                    o = base.scene.terrain.env_origins[0]
                    rr = float(((robot.data.root_link_pos_w[0, 0] - o[0]) ** 2 + (robot.data.root_link_pos_w[0, 1] - o[1]) ** 2) ** 0.5)
                    print(f"[headless_play] t={k * dt:6.2f}s step={k:4d} trunk_z={z * 1000:6.1f}mm "
                          f"grav_b=({float(g[0]):+.2f},{float(g[1]):+.2f},{float(g[2]):+.2f}){ball_xy()}{site_z()} r={rr:.2f}m", flush=True)
        print("[headless_play] done", flush=True)


_RealEnv = play.ManagerBasedRlEnv


def _env_with_camera(cfg, **kw):
    cfg.viewer.distance = cam_distance
    cfg.viewer.elevation = cam_elevation
    cfg.viewer.azimuth = cam_azimuth
    if cam_world is not None:
        # a trunk-tracking camera hides the rise (it moves with the trunk); a fixed camera shows it.
        from mjlab.viewer.viewer_config import ViewerConfig
        cfg.viewer.origin_type = ViewerConfig.OriginType.WORLD
        if cam_world != "auto":
            cfg.viewer.lookat = tuple(float(v) for v in cam_world.split(","))
        print(f"[headless_play] fixed world camera, lookat={cfg.viewer.lookat if cam_world != 'auto' else 'auto (post-reset root)'}", flush=True)
    if track_entity is not None:
        from mjlab.viewer.viewer_config import ViewerConfig
        cfg.viewer.origin_type = ViewerConfig.OriginType.ASSET_BODY
        cfg.viewer.entity_name = track_entity
        cfg.viewer.body_name = track_entity
        print(f"[headless_play] camera tracks entity={track_entity}", flush=True)
    if episode_s is not None:
        # StandUp trains on 6 s episodes; a 12 s clip at the default length contains a reset
        # at 6 s that teleports the duck to a new spawn state and reads as a stand-up. one long
        # episode keeps the clip continuous.
        cfg.episode_length_s = episode_s
    print(f"[headless_play] episode_length_s={cfg.episode_length_s}", flush=True)
    if spawn is not None and "set_roulade_state" in cfg.events:
        # Roulade spawns through set_roulade_state (standing_prob / midroll_prob, stage-0 mix 0.5/0.5);
        # force one state for the clip and drop the roulade_spawn_mix curriculum that would merge the mix back.
        ev = cfg.events["set_roulade_state"]
        ev.params["standing_prob"] = 1.0 if spawn == "standing" else 0.0
        ev.params["midroll_prob"] = 1.0 if spawn == "midroll" else 0.0
        if hasattr(cfg.curriculum, "pop"):
            cfg.curriculum.pop("roulade_spawn_mix", None)
        elif hasattr(cfg.curriculum, "roulade_spawn_mix"):
            cfg.curriculum.roulade_spawn_mix = None
        print(f"[headless_play] roulade spawn forced: {spawn}", flush=True)
    elif spawn is not None and "random_prone_init" in cfg.events:
        # VelStand family spawns through random_prone_init (prone_prob / face_down_prob / crouch_prob,
        # ramped by the prone_init_prob curriculum). force one state and drop the curriculum.
        if spawn not in ("standing", "face_down", "face_up"):
            raise SystemExit(f"--spawn {spawn}: VelStand supports standing|face_down|face_up")
        ev = cfg.events["random_prone_init"]
        ev.params["prone_prob"] = 0.0 if spawn == "standing" else 1.0
        ev.params["face_down_prob"] = 1.0 if spawn == "face_down" else 0.0
        ev.params["crouch_prob"] = 0.0
        if hasattr(cfg.curriculum, "pop"):
            cfg.curriculum.pop("prone_init_prob", None)
        elif hasattr(cfg.curriculum, "prone_init_prob"):
            cfg.curriculum.prone_init_prob = None
        print(f"[headless_play] velstand spawn forced: {spawn}", flush=True)
    elif spawn is not None:
        # play applies no curriculum, so set_ground_state keeps its stage-0 mix
        # (standing 0.40, sitting 0.40, face_down 0.20, face_up 0.00): a face-up spawn never
        # happens in play unless forced here.
        ev = cfg.events["set_ground_state"]
        for k in ("standing_prob", "sitting_prob", "face_down_prob", "face_up_prob"):
            ev.params[k] = 0.0
        ev.params[f"{spawn}_prob"] = 1.0
        # the ground_state_mix curriculum would shallow-merge its stage-0 mix back over
        # these params at the reset; drop it for the clip.
        if hasattr(cfg.curriculum, "pop"):
            cfg.curriculum.pop("ground_state_mix", None)
        elif hasattr(cfg.curriculum, "ground_state_mix"):
            cfg.curriculum.ground_state_mix = None
        print(f"[headless_play] spawn forced: {spawn}", flush=True)
    if spawn_offset is not None:
        pr = cfg.events["reset_base"].params["pose_range"]
        pr["x"] = (spawn_offset, spawn_offset)
        pr["y"] = (-0.05, 0.05)
        print(f"[headless_play] spawn offset: x={spawn_offset} m from the env origin", flush=True)
    if cmd_vx is not None:
        tw = cfg.commands["twist"]
        tw.ranges.lin_vel_x = (cmd_vx, cmd_vx)
        tw.ranges.lin_vel_y = (0.0, 0.0)
        tw.ranges.ang_vel_z = (0.0, 0.0)
        for k in ("rel_standing_envs", "rel_turn_in_place_envs", "rel_heading_envs"):
            if hasattr(tw, k):
                setattr(tw, k, 0.0)
        print(f"[headless_play] twist command fixed: vx={cmd_vx} m/s, vy 0, wz 0", flush=True)
    if no_push:
        dropped = cfg.events.pop("push_robot", None) if isinstance(cfg.events, dict) else None
        print(f"[headless_play] no-push: push_robot {'dropped' if dropped is not None else 'not present'}", flush=True)
        # BallKick (and any env with a push-magnitude curriculum) binds a curriculum term to the event by name and raises
        # "Event term 'push_robot' not found" at env build once the event is gone (found 2026-10-24); drop those terms too.
        if isinstance(cfg.curriculum, dict):
            for cname, ct in list(cfg.curriculum.items()):
                if (getattr(ct, "params", None) or {}).get("event_name") == "push_robot":
                    cfg.curriculum.pop(cname)
                    print(f"[headless_play] no-push: curriculum term {cname} dropped (bound to push_robot)", flush=True)
    if no_bounds:
        dropped = cfg.terminations.pop("out_of_terrain_bounds", None) if isinstance(cfg.terminations, dict) else None
        print(f"[headless_play] no-bounds: out_of_terrain_bounds {'dropped' if dropped is not None else 'not present'}", flush=True)
    if terrain_level is not None:
        gen = cfg.scene.terrain.terrain_generator
        if gen is None:
            raise SystemExit("--terrain-level needs a rough task (no terrain generator on this cfg)")
        gen.curriculum = True
        gen.num_rows = terrain_rows
        _terrain_names[:] = list(gen.sub_terrains.keys())
        if terrain_type is not None and terrain_type not in _terrain_names:
            raise SystemExit(f"--terrain-type {terrain_type}: one of {_terrain_names}")
        if not 0 <= terrain_level < terrain_rows:
            raise SystemExit(f"--terrain-level {terrain_level}: 0..{terrain_rows - 1}")
        if isinstance(cfg.curriculum, dict):
            cfg.curriculum.pop("terrain_levels", None)
        elif hasattr(cfg.curriculum, "terrain_levels"):
            cfg.curriculum.terrain_levels = None
        print(f"[headless_play] terrain layout: curriculum grid {terrain_rows} rows x {_terrain_names}", flush=True)
    print(f"[headless_play] camera distance={cam_distance} elevation={cam_elevation} "
          f"azimuth={cam_azimuth} body={cfg.viewer.body_name}", flush=True)
    return _RealEnv(cfg=cfg, **kw)


play.ManagerBasedRlEnv = _env_with_camera
play.ViserPlayViewer = HeadlessViewer
play.NativeMujocoViewer = HeadlessViewer
sys.argv = [sys.argv[0]] + argv + ["--viewer", "viser"]
play.main()
