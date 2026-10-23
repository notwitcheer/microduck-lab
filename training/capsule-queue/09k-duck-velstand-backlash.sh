#!/bin/bash
# 09k-duck-velstand-backlash.sh: duck skill tree, sim2real track, second -Backlash- twin (skill-tree.md GPU order step 2).
# task Mjlab-VelStand-Flat-Backlash-MicroDuck = the maker's backlash twin of level 5 (walk + recover in one policy):
# +-1 deg serial gear play per servo, firmware PD closing on the encoder reading THROUGH the play, groundcontact backlash
# robot model, obs/action dims unchanged (tasks/backlash.py, tasks/__init__.py). chosen as the twin where backlash has the
# most to break (recovery is foot contact). operator yes 2026-09-25 16:2x CEST (GPU thread).
# WARM START: logs/rsl_rl/duckvsbl/2026-09-25_00-00-00_seed-velstand-it20000/model_20000.pt = level 5 duckvelstand
# model_20000 (velstand-2026-09-20-it20000.onnx, HF witcheer/microduck-walk-recover v1), so the body resumes at 20000 and
# TARGET_IT = 20000 + 3000 (3k budget rule, operator 2026-09-23).
# probe 2026-09-25 16:30 CEST (~/Pollen/vsbl-probe.sh, 512 envs while a bench leg held the card at 100%): checkpoint loads
# with no size mismatch, 20000 -> 20040, train rc 0, export rc 0 (793,770 bytes). s/it at 4096 envs NOT measured (shared card);
# estimate ~1.3 s/it from level 5's 0.98 x the walk twin's backlash ratio (1.16 / 0.88) = ~65 min + export. UNVERIFIED.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; see 60-robotics/microduck/skill-tree.md).
SKILL=vsbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvsbl-status.json
TASK=Mjlab-VelStand-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-23000}
. /home/witcheer/Pollen/duck-train-body.sh
