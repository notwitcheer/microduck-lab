#!/usr/bin/env python3
"""gm-score-2026-10-28.py: take scoring for the gale (09z18/09z19) and moon (09z20/09z21) items. one [gm] line per 20 ms policy step from gm_play.py --gm-log.
usage: python3 gm-score-2026-10-28.py --dir <dir> <prefix> [--mode gale|moon]     per-take table + summary of one policy's takes
definitions (the settle window is the first 0.5 s; the take runs episode_s + 0.1 s, rows at t >= episode_s are the NEXT episode after the time-out RESET and are dropped):
  fell     = a RESET at t < episode_s - 0.3, OR total trunk tilt > 60 deg at any step (the cond_probe fall definition, so the seed probes stay comparable).
  held     = not fell.
  fwd_end  = mean trunk progress along the heading at reset (m) over the last 0.5 s of the take; fwd_max = its maximum.
  lean     = forward pitch from the projected gravity (deg, + nose down); lean_med = median over the last 4 s of the take, lean_max = the largest 0.5 s moving average over the take.
  wind_held = the largest wind force (N) at which the duck was still upright (== the wind at the take's end for a held take).
  flights  = runs of >= 4 consecutive steps (80 ms) with air=1 (both feet without ground contact), tilt < 35 deg on every step, after the settle window; bound_ms = the longest run.
"""
import glob, math, os, re, statistics, sys
from math import comb

L = re.compile(r'\[gm\] k=\s*(\d+) t=\s*([\d.]+) fwd=\s*([-+\d.]+) lat=\s*([-+\d.]+) z=\s*([-\d.]+) tilt=\s*([\d.]+) lean=\s*([-+\d.]+) air=\s*(-?\d) tq=([\d.]+) wind=\s*([\d.]+)')
R = re.compile(r'RESET at t=\s*([\d.]+)')
SETTLE_S = 0.5; FALL_TILT = 60.0; FLIGHT_STEPS = 4


def take(f, ep):
    t = open(f, errors='replace').read()
    rows = [dict(k=int(m[1]), t=float(m[2]), fwd=float(m[3]), lat=float(m[4]), z=float(m[5]), tilt=float(m[6]), lean=float(m[7]), air=int(m[8]), tq=float(m[9]), wind=float(m[10])) for m in L.finditer(t)]
    rows = [r for r in rows if r['t'] < ep - 1e-6]
    if len(rows) < int(0.9 * ep / 0.02): return None
    resets = [float(x) for x in R.findall(t) if float(x) < ep - 0.3]
    fell = bool(resets) or any(r['tilt'] > FALL_TILT for r in rows)
    end = [r for r in rows if r['t'] >= rows[-1]['t'] - 0.5]
    last4 = [r for r in rows if r['t'] >= rows[-1]['t'] - 4.0]
    w = 25  # 0.5 s moving average of the lean
    leans = [r['lean'] for r in rows]
    ma = [sum(leans[i:i + w]) / w for i in range(0, max(1, len(leans) - w))]
    runs, cur = [], []
    for r in rows:
        if r['t'] < SETTLE_S: continue
        if r['air'] == 1 and r['tilt'] < 35.0: cur.append(r)
        else:
            if cur: runs.append(cur)
            cur = []
    if cur: runs.append(cur)
    fl = [x for x in runs if len(x) >= FLIGHT_STEPS]
    up = [r for r in rows if r['tilt'] <= FALL_TILT]
    return dict(fell=fell, held=not fell, fall_t=(min([r['t'] for r in rows if r['tilt'] > FALL_TILT] + resets) if fell else float('nan')),
                fwd_end=statistics.mean(r['fwd'] for r in end), fwd_max=max(r['fwd'] for r in rows), lat_end=statistics.mean(r['lat'] for r in end),
                lean_med=statistics.median(r['lean'] for r in last4), lean_max=max(ma) if ma else float('nan'),
                wind_held=max([r['wind'] for r in up] or [0.0]), tq=max(r['tq'] for r in rows), n_flights=len(fl),
                bound_ms=max([len(x) for x in fl] or [0]) * 20, air_frac=sum(1 for r in rows if r['air'] == 1 and r['t'] >= SETTLE_S) / max(1, sum(1 for r in rows if r['t'] >= SETTLE_S)))


def f1(a, n1, b, n2):  # one-sided exact Fisher p that arm 1 (a/n1) is higher than arm 2 (b/n2)
    K = a + b; N = n1 + n2
    return sum(comb(n1, x) * comb(n2, K - x) for x in range(a, min(n1, K) + 1)) / comb(N, K)


def f2(a, n1, b, n2):  # two-sided exact Fisher (sum of probabilities <= the observed)
    K = a + b; N = n1 + n2; tot = comb(N, K)
    pobs = comb(n1, a) * comb(n2, b) / tot
    return min(1.0, sum(p for p in (comb(n1, x) * comb(n2, K - x) / tot for x in range(max(0, K - n2), min(n1, K) + 1)) if p <= pobs + 1e-12))


def med(v):
    v = [x for x in v if x == x]
    return statistics.median(v) if v else float('nan')


def load(d, pre, ep):
    out = []
    for f in sorted([g for g in glob.glob(f'{d}/{pre}-t*.log') if not g.endswith('.full.log')], key=lambda p: int(re.search(r'-t(\d+)\.log$', p)[1])):
        x = take(f, ep)
        out.append(dict(x, name=os.path.basename(f)[:-4]) if x else None)
    return out


def row(x):
    return (f'  {x["name"]:>10} held={int(x["held"])} fall_t={x["fall_t"]:5.1f} fwd_end={x["fwd_end"]:+6.2f} fwd_max={x["fwd_max"]:+6.2f} lat_end={x["lat_end"]:+6.2f} lean_med={x["lean_med"]:+5.1f} '
            f'lean_max={x["lean_max"]:+5.1f} wind_held={x["wind_held"]:4.2f}N flights={x["n_flights"]} bound={x["bound_ms"]:3d}ms air={x["air_frac"]:.2f} tq={x["tq"]:.3f}')


def summary(nm, xs):
    return (f'{nm}: held {sum(x["held"] for x in xs)}/{len(xs)} | median fwd_end {med([x["fwd_end"] for x in xs]):+.2f} m, median lean_med {med([x["lean_med"] for x in xs]):+.1f} deg, '
            f'median lean_max {med([x["lean_max"] for x in xs]):+.1f} deg | median wind_held {med([x["wind_held"] for x in xs]):.2f} N | takes with a flight >= 80 ms {sum(x["n_flights"] > 0 for x in xs)}/{len(xs)}, '
            f'median air fraction {med([x["air_frac"] for x in xs]):.3f}, longest {max(x["bound_ms"] for x in xs)} ms')


if __name__ == '__main__':
    a = sys.argv[1:]
    if not a or a[0] != '--dir': sys.exit(__doc__)
    d, pre = os.path.expanduser(a[1]), a[2]; ep = float(os.environ.get('GM_EP', '14'))
    xs = [x for x in load(d, pre, ep) if x]
    for x in xs: print(row(x))
    print(summary(pre, xs) if xs else f'{pre} no takes')
