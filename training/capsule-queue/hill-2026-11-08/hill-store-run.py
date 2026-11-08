#!/usr/bin/env python3
"""hill-store-run.py <onnx> <event> <user> <name> <store> <replay_seed|-> [--vx V]: write ONE run into a LOCAL Arena store (never the Space) whose replay lane is the chosen seed's trace.
`arena score --store` replays the lower-median finishing seed of the 5 official seeds; this does the same with any chosen seed (1..25), so a fresh start the board never scores
can be filmed by the Arena's own recorder (arena clip). Prints `recorded <run id>` like `arena score`. CPU only, nothing is entered."""
import dataclasses
import sys
from datetime import datetime, UTC
from pathlib import Path

from arena.course import compile_course
from arena.evaluate import evaluate, pick_trace_seed, trace_file
from arena.manifest import load_event
from arena.policy import load_policy
from arena.runner import run_once
from arena.store import LocalStore, RunRecord, lone_cast, new_id

onnx, event, user, name, store, seed = sys.argv[1:7]
ev = load_event(event)
pol = load_policy(Path(onnx))
model = compile_course(ev)
res = evaluate(ev, pol)
seed = pick_trace_seed(res.per_seed) if seed == "-" else int(seed)     # "-" = the Arena's own replay choice (the lower-median finishing seed)
vx = float(sys.argv[sys.argv.index("--vx") + 1]) if "--vx" in sys.argv else res.command_vx
o = run_once(ev, pol, seed, model, command=ev.command_at(vx))
print(f"seed {seed} at {vx} m/s: {o.status} {o.time_s}")
import json
print("META " + json.dumps({"seed": seed, "vx": vx, "status": o.status, "time_s": o.time_s, "frames": int(len(o.trace)), "dur": round(len(o.trace) * 0.02, 3), "score": res.score}))
res2 = dataclasses.replace(res, trace=o.trace, settle=o.settle, trace_seed=seed)
rec = RunRecord(run_id=new_id(), event_id=ev.id, submitted_at=datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"), user=user, policy_name=name,
                source={"kind": "local", "path": str(Path(onnx).resolve())}, model_sha256=pol.sha256, score=res.score, command_vx=vx, model_stored=True,
                seeds_finished=res.seeds_finished, per_seed=res.per_seed, trace_seed=seed, runner_version=res.runner_version, livery=None, cast=lone_cast())
LocalStore(Path(store)).append(rec, trace_file(res2), Path(onnx).read_bytes())
print(f"recorded {rec.run_id}")
