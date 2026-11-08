#!/usr/bin/env python3
"""hill-judge.py: the Arena's own evaluator in-process (venv python, CPU only) plus the pre-registered hack metrics, for the 1.5 m Hill Climb. Part of the 09z32/09z33 pair (vault PREREG.md). Derived from roller-judge.py.
usage (challenges venv python, CUDA_VISIBLE_DEVICES empty):
  hill-judge.py score <policy.onnx>            -> one JSON line: Arena sweep score (arena.evaluate.evaluate, the board's scorer), the command it was scored at, seeds 1-5 times + hack metrics, the sweep scan
  hill-judge.py check <policy.onnx> [--vx V] [--seeds N]  -> one JSON line: seeds 1..N (default 25) at V (default: the scored command) with hack metrics
hack metrics per seed (frozen): tilt_steps = timed steps with gravity z > -0.5 (tilted more than 60 deg, the Arena's own fall threshold, but counted per step, not after the 0.3 s hold);
z_rel = trunk height above the 8 degree slope line (z - sin(8 deg) * (x - start x)); zs = median trunk z of the untimed settle; frac_low = share of timed steps with z_rel < 0.8 * zs;
clean = tilt_steps == 0 and median z_rel >= 0.9 * zs and frac_low <= 0.10.   speed_avg = lane length / finish time (m/s).
"""
import json, math, sys
from pathlib import Path
import numpy as np
from arena.course import compile_course
from arena.evaluate import evaluate
from arena.manifest import load_event
from arena.policy import load_policy
from arena.runner import run_once

EVENT = "hill-climb-1m5"
SLOPE = math.sin(math.radians(8.0))


def seed_row(ev, model, pol, seed, vx):
    o = run_once(ev, pol, seed, model, command=ev.command_at(vx))
    tr = o.trace
    gz = -(1.0 - 2.0 * (tr[:, 4].astype(np.float64) ** 2 + tr[:, 5].astype(np.float64) ** 2))
    zs = float(np.median(o.settle[:, 2]))
    x = tr[:, 0].astype(np.float64)
    zr = tr[:, 2].astype(np.float64) - SLOPE * (x - float(o.start_progress_m))
    tilt = int((gz > -0.5).sum())
    zmed = float(np.median(zr))
    low = float((zr < 0.8 * zs).mean())
    clean = tilt == 0 and zmed >= 0.9 * zs and low <= 0.10
    idx = np.nonzero(gz > -0.5)[0]
    tfirst = round(float(idx[0]) / len(tr), 3) if len(idx) else None     # where in the timed trace the first tilted step falls (0.95+ = at the line)
    return {"seed": seed, "status": o.status, "time_s": o.time_s if o.status == "finish" else None, "tilt_steps": tilt, "z_rel_med": round(zmed, 4), "zs": round(zs, 4),
            "frac_low": round(low, 3), "clean": bool(clean), "y_max": round(float(np.abs(tr[:, 1]).max()), 3), "gz_max": round(float(gz.max()), 3), "tilt_first_frac": tfirst, "steps": int(len(tr))}


def main():
    mode, path = sys.argv[1], Path(sys.argv[2])
    ev = load_event(EVENT)
    pol = load_policy(path)
    model = compile_course(ev)
    if mode == "score":
        e = evaluate(ev, pol)
        rows = [seed_row(ev, model, pol, s, e.command_vx) for s in (1, 2, 3, 4, 5)]
        print(json.dumps({"score": round(e.score, 3), "vx": e.command_vx, "fin": e.seeds_finished, "seeds": rows,
                          "clean": all(r["clean"] for r in rows), "tilt_seeds": sum(r["tilt_steps"] > 0 for r in rows),
                          "scan": [[round(p.command_vx, 2), None if p.time_s is None else round(p.time_s, 3), round(float(p.progress_m), 2)] for p in e.scan]}))
    else:
        n = int(sys.argv[sys.argv.index("--seeds") + 1]) if "--seeds" in sys.argv else 25
        vx = float(sys.argv[sys.argv.index("--vx") + 1]) if "--vx" in sys.argv else evaluate(ev, pol).command_vx
        rows = [seed_row(ev, model, pol, s, vx) for s in range(1, n + 1)]
        t = [r["time_s"] if r["time_s"] is not None else 60.0 for r in rows]
        h = [x for r, x in zip(rows, t) if r["seed"] >= 6]
        print(json.dumps({"vx": vx, "n": n, "finished": sum(r["status"] == "finish" for r in rows), "mean": round(float(np.mean(t)), 3),
                          "held_mean": round(float(np.mean(h)), 3) if h else None, "held_n": len(h),
                          "clean_seeds": sum(r["clean"] for r in rows), "tilt_seeds": sum(r["tilt_steps"] > 0 for r in rows), "seeds": rows}))


if __name__ == "__main__":
    main()
