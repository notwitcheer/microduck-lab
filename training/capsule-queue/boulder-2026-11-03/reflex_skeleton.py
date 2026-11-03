"""reflex(**state) -> (vx, vy, vyaw): the Microduck's velocity command, called every 20 ms for each take.

units: metres, seconds, radians, WORLD frame with +x = the direction the duck is walking at the start, positions relative to the take's origin.
state: env (take index 0..N-1: ALL takes share this module, so keep any memory in a dict keyed by env), t (s), duck_x, duck_y, duck_vx, duck_vy (m/s, world), heading (rad, 0 = facing +x, + = turning left), ball_x, ball_y (boulder centre), ball_vx (m/s, the
boulder rolls along +x and speeds up), ball_r (m, boulder radius; the duck is ~0.12 m wide, 0.25 m tall).
return the BODY-frame command: vx (forward, clamped to +-0.4 m/s), vy (sideways, + = to the duck's left, clamped to +-0.3 m/s, its trained range), vyaw
(+ = turn left, clamped to +-1.0 rad/s). the real duck achieves roughly 0.24 m/s forward for vx 0.4 and about 0.1-0.15 m/s sideways for vy 0.3.
the open-loop walk drifts sideways, so keep the heading near 0 with vyaw = -1.5 * heading unless you are steering on purpose.
"""


def reflex(env, t, duck_x, duck_y, duck_vx, duck_vy, heading, ball_x, ball_y, ball_vx, ball_r):
    return 0.4, 0.0, max(-0.6, min(0.6, -1.5 * heading))
