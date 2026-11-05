#!/usr/bin/env python3
# hop2-score-2026-10-29.py: STRICT whole-body flight scorer for the MicroDuck hop (diagnostic 2026-10-29, then the pre-registered hop2 verdict).
# input: take logs from strict_play.py --hop-log --strict-log: per 20 ms policy step one `[strict] k= t= n= z= tilt= zl= zr= on=` line (n = number of robot bodies
#   in floor contact in ANY physics substep of the step: trunk, hips, leg shells, ankles (= soles), jaw/head shells ...; on = their names) plus the old `[hop]` line (peak torque tq).
# DEFINITIONS (frozen before any hop2 training; the diagnostic on the 3,000-it takes and the lever checkpoints was run with exactly these):
#   Z_STAND  = 116.1 mm  standing trunk height in the hop env (median over 15 seed takes of the per-take median trunk z over 0.5-1.5 s, CPU strict logger, hop2-dev/diag-seed; the 2026-10-27 GPU seed takes give 115.7 mm).
#   STRICT FLIGHT = a run of >= 4 consecutive steps (80 ms), after the 12-step settle window, in which NO robot body touches the floor (n == 0) AND the trunk z >= Z_STAND + 10 mm
#                   on EVERY step of the run. (a sole in the air with the jaw or a leg shell on the floor is not a flight.)
#   fall     = a RESET line before t = 5.9 s, or trunk tilt > 60 deg on any step.
#   upright at the end = last 0.5 s: tilt < 30 deg on every step.   tall at the end = median trunk z over the last 0.5 s >= 0.9 x Z_STAND (104.5 mm).
#   SUCCESS  = >= 3 strict flights AND no fall AND upright at the end AND tall at the end.
#   reported: apex trunk height (mm, max z over the take after the settle), apex lift over Z_STAND, longest strict flight (ms), peak torque, share of success takes <= 0.60 N m (XL330-M288 datasheet stall at 6 V),
#             share of steps with any NON-sole body on the floor, loose flights (>= 4 no-contact steps with the apex of the run >= Z_STAND + 10, sensitivity only).
# usage: python3 hop2-score-2026-10-29.py --dir <dir> <prefix> [<prefix> ...]     per-take table + summary for each prefix
#        python3 hop2-score-2026-10-29.py --ab <dirA> <prefixA> <dirB> <prefixB>   verdict (pre-registered one-sided exact Fisher on the success counts)
#        python3 hop2-score-2026-10-29.py --zstand <dir> <prefix>                  measure Z_STAND from a (seed) batch
import glob, math, os, re, statistics, sys
from math import comb

Z_STAND = float(os.environ.get('HOP2_ZSTAND', '116.1'))
LIFT = float(os.environ.get('HOP2_LIFT_MM', '10'))
MIN_STEPS = int(os.environ.get('HOP2_MIN_STEPS', '4'))
MIN_FLIGHTS = int(os.environ.get('HOP2_MIN_FLIGHTS', '3'))
SETTLE = 12
TQ_REAL = 0.60
SOLES = ('ankle_left', 'ankle_right')
S = re.compile(r'\[strict\] k=\s*(\d+) t=\s*([\d.]+) n=(\d+) z=\s*([-\d.]+) tilt=\s*([\d.]+) zl=\s*([-\d.]+) zr=\s*([-\d.]+) on=(\S+)')
HQ = re.compile(r'\[hop\] k=\s*(\d+) t=\s*[\d.]+ air=\d z=\s*[-\d.]+ fz=\s*[-\d.]+ tilt=\s*[\d.]+ zl=\s*[-\d.]+ zr=\s*[-\d.]+ tq=([\d.]+)')
R = re.compile(r'RESET at t=\s*([\d.]+)')


def runs_of(rows, pred):
    out, cur = [], []
    for r in rows:
        if r['k'] >= SETTLE and pred(r):
            cur.append(r)
        else:
            if cur:
                out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    return out


def take(f, zstand=None):
    zs = Z_STAND if zstand is None else zstand
    t = open(f, errors='replace').read()
    rows = [dict(k=int(m[1]), t=float(m[2]), n=int(m[3]), z=float(m[4]), tilt=float(m[5]), zl=float(m[6]), zr=float(m[7]), on=m[8]) for m in S.finditer(t)]
    rows = [r for r in rows if r['t'] <= 5.94]   # the 6 s episode wraps at k=299: later rows are the next episode's spawn drop
    if len(rows) < 100:
        return None
    tq = {int(m[1]): float(m[2]) for m in HQ.finditer(t)}
    resets = [float(x) for x in R.findall(t) if float(x) < 5.9]
    body = [r for r in rows if r['k'] >= SETTLE]
    strict = [x for x in runs_of(rows, lambda r: r['n'] == 0 and r['z'] >= zs + LIFT) if len(x) >= MIN_STEPS]
    air = runs_of(rows, lambda r: r['n'] == 0)
    loose = [x for x in air if len(x) >= MIN_STEPS and max(y['z'] for y in x) >= zs + LIFT]
    tail = [r for r in rows if r['t'] >= rows[-1]['t'] - 0.5]
    fell = bool(resets) or any(r['tilt'] > 60.0 for r in body)
    upright = bool(tail) and all(r['tilt'] < 30.0 for r in tail)
    tall = bool(tail) and statistics.median(r['z'] for r in tail) >= 0.9 * zs
    nonsole = sum(1 for r in body if r['on'] != '-' and any(b not in SOLES for b in r['on'].split('+')))
    tqs = [tq[k] for k in tq if k >= SETTLE]
    return dict(n_strict=len(strict), n_loose=len(loose), fell=fell, upright=upright, tall=tall, resets=len(resets),
                success=len(strict) >= MIN_FLIGHTS and not fell and upright and tall,
                flight_ms=max([len(x) for x in strict] or [0]) * 20, loose_ms=max([len(x) for x in loose] or [0]) * 20,
                apex=max(r['z'] for r in body), apex_lift=max(r['z'] for r in body) - zs,
                zmed=statistics.median(r['z'] for r in body),
                tq=max(tqs or [0.0]), nonsole_share=nonsole / len(body),
                none_share=sum(1 for r in body if r['n'] == 0) / len(body),
                zmed_first=statistics.median([r['z'] for r in rows if 0.5 <= r['t'] <= 1.5] or [float('nan')]))


def f1(a, n1, b, n2):
    K = a + b; N = n1 + n2
    return sum(comb(n1, x) * comb(n2, K - x) for x in range(a, min(n1, K) + 1)) / comb(N, K)


def med(v):
    v = [x for x in v if x == x]
    return statistics.median(v) if v else float('nan')


def load(d, pre):
    out = []
    fs = [g for g in glob.glob(f'{os.path.expanduser(d)}/{pre}-t*.log') if not g.endswith('.full.log')]
    for f in sorted(fs, key=lambda p: int(re.search(r'-t(\d+)\.log$', p)[1])):
        x = take(f)
        if x:
            x['name'] = os.path.basename(f)[:-4]
            out.append(x)
    return out


def row(x):
    return (f'  {x["name"]:>12} strict={x["n_strict"]} loose={x["n_loose"]} flight={x["flight_ms"]:3d}ms apex={x["apex"]:6.1f}mm ({x["apex_lift"]:+5.1f}) zmed={x["zmed"]:5.1f} '
            f'nonsole={x["nonsole_share"]*100:3.0f}% tq={x["tq"]:.3f} fell={int(x["fell"])} upright={int(x["upright"])} tall={int(x["tall"])} success={int(x["success"])}')


def summary(nm, xs):
    s = [x for x in xs if x['success']]
    return (f'{nm}: n={len(xs)} success {len(s)}/{len(xs)} | takes with >=1 strict flight {sum(x["n_strict"] >= 1 for x in xs)} | total strict flights {sum(x["n_strict"] for x in xs)} | '
            f'longest strict flight max {max(x["flight_ms"] for x in xs)} ms (median {med([x["flight_ms"] for x in xs]):.0f}) | apex trunk median {med([x["apex"] for x in xs]):.1f} mm, max {max(x["apex"] for x in xs):.1f} mm '
            f'(Z_STAND {Z_STAND}) | median trunk {med([x["zmed"] for x in xs]):.1f} mm | non-sole floor contact share median {med([x["nonsole_share"] for x in xs])*100:.0f}% | '
            f'loose flights (sensitivity) {sum(x["n_loose"] for x in xs)} in {sum(x["n_loose"] >= 1 for x in xs)} takes | fell {sum(x["fell"] for x in xs)} | peak torque median {med([x["tq"] for x in xs]):.3f} N m, '
            f'success takes <= {TQ_REAL}: {sum(x["tq"] <= TQ_REAL for x in s)}/{len(s)}')


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == '--dir':
    d = sys.argv[2]
    for pre in sys.argv[3:]:
        xs = load(d, pre)
        for x in xs: print(row(x))
        print(summary(pre, xs) if xs else f'{pre}: no takes')
elif __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == '--zstand':
    zs = []
    for f in glob.glob(f'{os.path.expanduser(sys.argv[2])}/{sys.argv[3]}-t*.log'):
        if f.endswith('.full.log'): continue
        x = take(f, 0.0)
        if x: zs.append(x['zmed_first'])
    print(f'Z_STAND measure: {len(zs)} takes, per-take median trunk z over 0.5-1.5 s: min {min(zs):.1f} max {max(zs):.1f} median {statistics.median(zs):.2f} mm')
elif __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == '--ab':
    A = load(sys.argv[2], sys.argv[3]); B = load(sys.argv[4], sys.argv[5])
    a, n1, b, n2 = sum(x['success'] for x in A), len(A), sum(x['success'] for x in B), len(B)
    print(f'n new {n1} ref {n2}')
    if not A or not B:
        print('VERDICT: incomplete (no takes yet)'); sys.exit(0)
    p1 = f1(a, n1, b, n2)
    print(f'   A success: new {a}/{n1} vs ref {b}/{n2}  one-sided exact Fisher p={p1:.4f}')
    print('  ', summary('new', A)); print('  ', summary('ref', B))
    for x in A: print(row(x))
    NT = int(os.environ.get('PROOF_N', '15'))
    print('VERDICT:', ('GAIN' if p1 < 0.05 else 'NO GAIN') if (n1 == NT and n2 == NT) else 'incomplete (not every take of the pre-registered n is in yet)')
