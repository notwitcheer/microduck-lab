"""prep-backgetup2-seed.py: build the warm-start seed for back-getup v2.

Copies v1's final checkpoint (duckbackgetup model_28000.pt) into
logs/rsl_rl/duckbackgetup2/<SEED_DIR>/model_28000.pt with the actor's
exploration std (distribution.std_param, std_type scalar = std itself, one per
joint) multiplied by STD_MULT. Every other tensor, the optimizer state and
`iter` are left as they are. Prints before/after std and a check that nothing
else changed. Run from ~/Pollen/microduck_rl with `uv run python`.
Refuses to overwrite an existing seed (idempotent re-run = no-op + check).
"""
import sys
from pathlib import Path

import torch

RL = Path("/home/witcheer/Pollen/microduck_rl")
SRC = RL / "logs/rsl_rl/duckbackgetup/2026-09-24_16-01-44_duckbackgetup/model_28000.pt"
SEED_DIR = RL / "logs/rsl_rl/duckbackgetup2/2026-09-24_00-00-00_seed-backgetup-it28000-std2x"
DST = SEED_DIR / "model_28000.pt"
STD_MULT = 2.0
KEY = "distribution.std_param"

src = torch.load(SRC, map_location="cpu", weights_only=False)
if DST.exists():
    print(f"seed exists: {DST} (not overwritten)")
else:
    ck = torch.load(SRC, map_location="cpu", weights_only=False)
    ck["actor_state_dict"][KEY] = ck["actor_state_dict"][KEY] * STD_MULT
    SEED_DIR.mkdir(parents=True, exist_ok=True)
    torch.save(ck, DST)
    print(f"wrote {DST}")

dst = torch.load(DST, map_location="cpu", weights_only=False)
a, b = src["actor_state_dict"][KEY], dst["actor_state_dict"][KEY]
print(f"iter src={src['iter']} dst={dst['iter']}")
print(f"std before: mean {a.mean():.4f} min {a.min():.4f} max {a.max():.4f}")
print(f"std after : mean {b.mean():.4f} min {b.min():.4f} max {b.max():.4f}  ratio {float((b / a).mean()):.4f}")
diff = []
for part in ("actor_state_dict", "critic_state_dict"):
    for k, v in src[part].items():
        if part == "actor_state_dict" and k == KEY:
            continue
        if not torch.equal(v, dst[part][k]):
            diff.append(f"{part}.{k}")
print("other tensors identical:", "yes" if not diff else f"NO {diff}")
sys.exit(0 if not diff and abs(float((b / a).mean()) - STD_MULT) < 1e-5 else 1)
