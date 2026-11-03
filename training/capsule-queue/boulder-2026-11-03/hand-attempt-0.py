trig = {}


def reflex(env, t, duck_x, duck_y, duck_vx, duck_vy, heading, ball_x, ball_y, ball_vx, ball_r):
    gap = (duck_x - ball_x) - ball_r
    closing = max(ball_vx - duck_vx, 0.05)
    tau = gap / closing
    yaw = max(-0.6, min(0.6, -1.5 * heading))
    if env not in trig and tau < 5.0 and gap > -0.2:
        trig[env] = (t, 1.0 if duck_y - ball_y >= 0 else -1.0)
    if env in trig and t - trig[env][0] < 4.0:
        return 0.0, 0.3 * trig[env][1], yaw
    return 0.4, 0.0, yaw
