_mem = {}


def reflex(env, t, duck_x, duck_y, duck_vx, duck_vy, heading, ball_x, ball_y, ball_vx, ball_r):
    yaw = max(-0.6, min(0.6, -1.5 * heading))
    m = _mem.setdefault(env, {})
    if t < 0.05:
        m.clear()
    gap = duck_x - ball_x  # >0 while ball is behind
    if "side" not in m:
        d = duck_y - ball_y
        m["side"] = 1.0 if d >= 0 else -1.0
    sep = abs(duck_y - ball_y)
    if gap > -(ball_r + 0.3) and sep < ball_r + 0.6:
        # strafe away at full speed while still walking forward
        return 0.4, 0.3 * m["side"], yaw
    return 0.4, 0.0, yaw
