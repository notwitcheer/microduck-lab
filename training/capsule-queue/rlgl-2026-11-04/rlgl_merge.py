"""rlgl_merge.py: merge the shard trajectories of swarm_rlgl2.py into one field and print the RESULT lines (CPU, 2026-11-04).

usage: python rlgl_merge.py out.npz shard0.npz shard1.npz ...   (shards in order; the field is the concatenation along the duck axis)
RESULT lines: survivors (never above thr after the grace in any red phase, never tilted > 60 deg), per-light eliminations, falls, counter monotone,
stop latency, and the ids of nothing else. prints MERGED_OK when every shard has the same frame count and the counter is monotone.
"""
import sys

import numpy as np

out, parts = sys.argv[1], sys.argv[2:]
D = [np.load(p) for p in parts]
F = {d["qpos"].shape[0] for d in D}
assert len(F) == 1, f"shards differ in frame count: {F}"
cycles = int(D[0]["cycles"])
elim = np.concatenate([d["elim"] for d in D], axis=1)
qpos = np.concatenate([d["qpos"] for d in D], axis=1)
fell = np.concatenate([d["fell"] for d in D])
origins = np.concatenate([d["origins"] for d in D])
react = np.concatenate([d["react"] for d in D])
speed = np.concatenate([d["speed"] for d in D])
n = elim.shape[1]
cyc_elim = sum(d["cyc_elim"] for d in D)
alive_end = sum(d["cyc_alive_end"] for d in D)
alive = (~elim).sum(axis=1)
mono = bool(np.all(np.diff(alive) <= 0))
np.savez_compressed(out, qpos=qpos, elim=elim, red=D[0]["red"], t=D[0]["t"], origins=origins, react=react, speed=speed, fell=fell, cycles=cycles,
                    red_s=D[0]["red_s"], green_s=D[0]["green_s"], lead_in=D[0]["lead_in"], grace=D[0]["grace"], thr=D[0]["thr"], spacing=D[0]["spacing"])
print(f"[rlgl] RESULT field n={n} cycles={cycles} eliminated_total={int(elim[-1].sum())} ({100 * elim[-1].mean():.1f}%) fell_total={int(fell.sum())} survivors={int((~elim[-1]).sum())}")
print(f"[rlgl] RESULT counter_monotone={mono} alive_first={int(alive[0])} alive_last={int(alive[-1])} frames={len(alive)}")
for c in range(cycles):
    sl = np.concatenate([d[f"stop_lat_{c}"] for d in D])
    sl = sl if len(sl) else np.array([np.nan])
    print(f"[rlgl] RESULT cycle {c + 1}: eliminated {int(cyc_elim[c])} alive_at_end_of_red {int(alive_end[c])} stop_latency_med_s={np.nanmedian(sl):.2f} p90={np.nanpercentile(sl, 90):.2f} (ducks that stopped {len(sl)})")
print(f"[rlgl] RESULT reaction median {np.median(react):.2f}s p90 {np.quantile(react, 0.9):.2f}s speed {speed.min():.2f}-{speed.max():.2f}")
print("MERGED_OK" if mono else "MERGED_NOT_MONOTONE")
