#!/usr/bin/env python3
"""dr-score-2026-10-27.py: dribble take scorer (09z14 / 09z15). reads headless_play take logs (batch dir + take prefix), no GPU.

usage: dr-score-2026-10-27.py --dir <clips dir> <prefix> [<prefix2>] [--rows] [--noball]
per take (one 20 s episode, goal mode: duck turned to +x, ball centre ~0.27 m ahead of the root at reset, goal mouth at x = DR_GOAL_X, default 1.8 m;
the round-1/2 seed reads used 3.0 and the first sweep 2.0, score them with DR_GOAL_X=3.0 / 2.0):
  held      no RESET line before the last 0.5 s of the take (the time-out prints one at the end) and no tilt fall (grav_b z > -0.5 at any 0.2 s sample)
  gap, lat  ball centre minus trunk, x and y (m), every 0.2 s (ball=(x,y,z) trunk=(x,y) fields of the take log, origin-relative)
  near      a sample is NEAR when 0 < gap < GAP_MAX (0.60 m) and |lat| < LAT_MAX (0.30 m): the ball is at the duck's feet, within one body length of it
  goal      the ball centre is inside the goal mouth footprint (GX <= x <= GX + 0.4, |y| < 0.5, z < 0.5) at some sample; t_goal = the first such sample
  CARRIED   (the pre-registered success, vault log 2026-10-27) held AND goal AND near at EVERY sample from t = 1.0 s up to t_goal: the duck walked the ball into the goal and it never left its reach
  --noball  logs without ball fields (the no-loss walk batch): only held is read
printed, not in the verdict: near fraction 1-15 s, ball travel at 15 s, longest near streak, median ball speed.
"""
import glob, re, sys
from math import comb

SB = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([-\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\) ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\) trunk=\(([-+\d.]+),([-+\d.]+)\)')
SN = re.compile(r't=\s*([\d.]+)s step=\s*\d+ trunk_z=\s*([-\d.]+)mm grav_b=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\)')
A0 = re.compile(r'after reset:.*?ball=\(([-+\d.]+),([-+\d.]+),([-+\d.]+)\) trunk=\(([-+\d.]+),([-+\d.]+)\)')
R = re.compile(r'RESET at t=\s*([\d.]+)')

import os
GAP_MAX, LAT_MAX = 0.60, 0.30
T_FROM = 1.0
GX = float(os.environ.get('DR_GOAL_X', '1.8'))
GOAL = (GX, GX + 0.4, 0.5)


def read(path, noball):
    rows, a0, resets = [], None, []
    for line in open(path, errors='replace'):
        if not noball:
            m = A0.search(line)
            if m:
                a0 = tuple(float(v) for v in m.groups())
        m = (SN if noball else SB).search(line)
        if m:
            rows.append(tuple(float(v) for v in m.groups()))
        m = R.search(line)
        if m:
            resets.append(float(m.group(1)))
    return a0, rows, resets


def take(path, noball=False):
    a0, rows, resets = read(path, noball)
    if not rows or (a0 is None and not noball):
        return None
    tilt = any(r[4] > -0.5 for r in rows)
    t_last = rows[-1][0]
    mid = [t for t in resets if t < t_last - 0.5]  # the time-out of the episode prints one RESET at the very end (23.98 s of 24, 19.98 of 20)
    held = not tilt and not mid
    if noball:
        return dict(held=held, ok=held, t_end=rows[-1][0], resets=mid, tilt=tilt)
    bx0 = a0[0]
    S = [dict(t=r[0], gap=r[5] - r[8], lat=r[6] - r[9], bx=r[5], by=r[6], bz=r[7]) for r in rows]
    near = lambda s: 0.0 < s['gap'] < GAP_MAX and abs(s['lat']) < LAT_MAX
    ing = lambda s: GOAL[0] <= s['bx'] <= GOAL[1] and abs(s['by']) < GOAL[2] and s['bz'] < 0.5
    tg = next((s['t'] for s in S if ing(s)), None)
    goal = tg is not None
    pre = [s for s in S if T_FROM <= s['t'] <= (tg if goal else 1e9)]
    carried = held and goal and all(near(s) for s in pre) and len(pre) > 0
    win = [s for s in S if 1.0 <= s['t'] <= 15.0]
    near_frac = sum(near(s) for s in win) / max(1, len(win))
    run = best = 0
    for s in S:
        run = run + 1 if near(s) else 0
        best = max(best, run)
    at15 = min(S, key=lambda s: abs(s['t'] - 15.0))
    vb = [((S[i + 1]['bx'] - S[i]['bx']) ** 2 + (S[i + 1]['by'] - S[i]['by']) ** 2) ** 0.5 / (S[i + 1]['t'] - S[i]['t']) for i in range(len(S) - 1) if S[i + 1]['t'] > S[i]['t']]
    first_far = next((s['t'] for s in S if s['t'] >= T_FROM and not near(s)), None)
    return dict(held=held, goal=goal, t_goal=tg, ok=carried, near_frac=near_frac, travel15=at15['bx'] - bx0, streak_s=best * 0.2,
                vball_med=sorted(vb)[len(vb) // 2] if vb else float('nan'), first_far=first_far, t_end=S[-1]['t'], resets=mid, tilt=tilt)


def fisher_one_sided(a, n1, b, n2):
    k, N = a + b, n1 + n2
    return sum(comb(k, x) * comb(N - k, n1 - x) for x in range(a, min(k, n1) + 1)) / comb(N, n1)


def fisher_two_sided(a, n1, b, n2):
    k, N = a + b, n1 + n2
    pr = lambda x: comb(k, x) * comb(N - k, n1 - x) / comb(N, n1)
    p0 = pr(a)
    return min(1.0, sum(pr(x) for x in range(max(0, k - n2), min(k, n1) + 1) if pr(x) <= p0 + 1e-12))


def load(d, pre, noball):
    res = []
    for f in sorted([g for g in glob.glob(f'{d}/{pre}-t*.log') if not g.endswith('.full.log')], key=lambda p: int(re.search(r'-t(\d+)\.log$', p)[1])):
        r = take(f, noball)
        if r:
            r['name'] = os.path.basename(f)[:-4]
            res.append(r)
    return res


def main():
    args = sys.argv[1:]
    d = args[args.index('--dir') + 1]
    rows_flag, noball = '--rows' in args, '--noball' in args
    pres = [a for a in args if not a.startswith('--') and a != d]
    out = {}
    for pre in pres:
        res = load(d, pre, noball)
        out[pre] = res
        n = len(res)
        if not n:
            print(pre, 'no takes'); continue
        if noball:
            print(f"{pre}: n={n} held {sum(r['held'] for r in res)}/{n}")
        else:
            med = lambda v: sorted(v)[len(v) // 2]
            print(f"{pre}: n={n} held {sum(r['held'] for r in res)}/{n}  CARRIED {sum(r['ok'] for r in res)}/{n}  goal {sum(r['goal'] for r in res)}/{n}  "
                  f"median near 1-15 s {med([r['near_frac'] for r in res]):.2f}  median travel@15 {med([r['travel15'] for r in res]):.2f} m  median longest near streak {med([r['streak_s'] for r in res]):.1f} s")
        if rows_flag:
            for r in res:
                if noball:
                    print(f"   {r['name']:<14} held {int(r['held'])} resets {r['resets']} tilt {int(r['tilt'])} t_end {r['t_end']:.1f}")
                else:
                    ff = '-' if r['first_far'] is None else f"{r['first_far']:.1f}s"
                    tg = '-' if r['t_goal'] is None else f"{r['t_goal']:.1f}s"
                    print(f"   {r['name']:<14} held {int(r['held'])} CARRIED {int(r['ok'])} goal {int(r['goal'])}@{tg} near {r['near_frac']:.2f} travel@15 {r['travel15']:+.2f} streak {r['streak_s']:.1f}s vball {r['vball_med']:.2f} first_far {ff}")
    if len(pres) == 2 and all(out.get(p) for p in pres):
        a, b = out[pres[0]], out[pres[1]]
        sa, sb = sum(r['ok'] for r in a), sum(r['ok'] for r in b)
        print(f"{'held' if noball else 'CARRIED'} {pres[0]} {sa}/{len(a)} vs {pres[1]} {sb}/{len(b)}: one-sided Fisher p={fisher_one_sided(sa, len(a), sb, len(b)):.4f}  two-sided p={fisher_two_sided(sa, len(a), sb, len(b)):.4f}")


if __name__ == '__main__':
    main()
