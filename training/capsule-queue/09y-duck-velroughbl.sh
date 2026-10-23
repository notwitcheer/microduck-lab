#!/bin/bash
# 09y-duck-velroughbl.sh: duck skill tree, sim2real track (level 10): -Backlash- twin of level 4 walk-rough
# (HF witcheer/microduck-walk-rough v1), the one published walking policy with no gear-play twin yet.
# task Mjlab-Velocity-Rough-Backlash-MicroDuck (maker task id, tasks/__init__.py): +-1 deg gear play per servo, obs/action dims unchanged.
# WARM START: logs/rsl_rl/duckvelroughbl/2026-10-08_00-00-00_seed-velrough-it8000/model_8000.pt = level 4 duckvelrough model_8000
# (velrough-2026-09-19-it8000.onnx), so the body resumes at 8000 and TARGET_IT = 8000 + 3000 (3k budget rule).
# why this and not a 09x extension: 09x reward flat at about -17 from 9250 to 11250 and terrain level flat from 10000, so the
# 3k rule says stop at 12000. operator yes 2026-10-08 07:2x CEST (GPU thread, "yes for both").
# probe 2026-10-08 07:29 CEST (~/Pollen/vrbl-probe.sh, free card, concurrent with a CPU carpet-gap run): checkpoint loads with no size
# mismatch, 8000 -> 8041 at 4096 envs, train rc 0 in 140 s, 2.9 to 3.7 s/it, VRAM peak 21,272 MiB, export rc 0 (793,769 bytes).
# 3000 it at ~3.3 s/it = ~165 min + export: thu 14:10 tail after 09x (~140 min), the rest in the next duck block.
SKILL=velroughbl
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelroughbl-status.json
TASK=Mjlab-Velocity-Rough-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-11000}
. /home/witcheer/Pollen/duck-train-body.sh
