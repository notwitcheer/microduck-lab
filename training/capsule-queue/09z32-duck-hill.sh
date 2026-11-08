#!/bin/bash
# 09z32-duck-hill.sh: Pollen MicroDuck Arena "1.5 m Hill Climb" (event hill-climb-1m5, perpetual board, no cup deadline): a Microduck walks 1.5 m up an 8 degree lane. trains on the 5090 with the Arena's own challenge (task Mjlab-HillClimb1m5-MicroDuck), 3 agent seeds of the shipped recipe at 1500 iterations.
# idle-queue item (2026-11-08): Arena 1.5 m Hill Climb board audit + shipped-recipe comparator (simulation only)
# serves: content (the board audit post; Arena entry of our own pick stays its own approval) + the pre-registered verdict 09z33 (right behind this item). PART A of the pair is a CPU audit of the live board (09z33); this item is PART B, the comparator: does the plain shipped recipe (3 seeds) give a duck that holds up on 25 starts, and where does it land on the honest ladder.
# WHAT: the maker's challenge (github.com/pollen-robotics/microduck-challenges @ 5cee942, Arena 0.7.0 wheel, mjlab 1.3.0; folder hill_climb_1m5 last commit 9aaec6d 2026-10-26) in a clone of its own, ~/Pollen/arena/hill/microduck-challenges (the venv is the heist clone's: same pinned commit and wheel). recipe = AGENTS.md as shipped (from scratch, 4096 envs, a checkpoint every 250, knobs forward 2 / upright 2 / step 3 / max slope 10) EXCEPT max_iterations 1500 instead of 3000 (card budget, see hill-runs-09z32.sh).
# RUNS (hill-runs-09z32.sh): hc1, hc2, hc3 = shipped recipe, agent seeds 1, 2, 3 = HEADLINE (replication). PREREG: hill-2026-11-08/PREREG.md (sha256 of every frozen file in FROZEN.sha256, checked by this item's PLAN phase: a differing hash aborts before any card work).
# EVIDENCE (2026-11-08, vault status note): clone at 5cee942, 2-env CPU smoke rc 0 (18 s); 4096-env GPU sizing smoke 40 it rc 0 at 2.30 s/it (steady mean of 37 it, box CPU-loaded by siblings), 17,910 MiB peak on a free card (rule-3 checked, flock'd, 111 s wall, never counted); the Pollen reference re-scored locally 5.870 s (5/5, 25/25 upright) = its board row; 128 of the 132 live board rows downloaded and re-scored: 128 equal their board rows within 1.5 ms (score and command).
# PACE: 2.30 s/it at 4096 envs -> 1500 it ~58 min + ~40 s start per run; three runs ~176 min of card, plus preflight/drain/restore ~2 min (ESTIMATE until a full run: the task has curriculum stages at it 500/750/1000/1250/1500 the 40-it smoke never reached). resumable (exit 3 while iterations remain). the proof 09z33 is CPU only (~35 min: the board audit ~15 min + the picks' checks + the clip) in the same slot.
# GATE: none. Sunday is heures creuses all day (weekend blocks never yield, duck-lane.sh); NOT_BEFORE=0 by default, the gate code of the body stays for hand runs.
# disk: ~0.3 GB (3 runs x 7 checkpoints x 4.9 MB, 18 exported ONNX, 132 board policies ~110 MB, one local Arena store); capsule free >= 140 GB at all times, the runner floor is 100 GB.
# body: ~/Pollen/hill-train-body.sh (roller body shape: resume, Donald drain + EXIT-trap restore, manifest, frozen-hash guard). run matrix: ~/Pollen/hill-runs-09z32.sh.
ITEM=09z32
MANIFEST=/home/witcheer/hill09z32-status.json
NOT_BEFORE=${NOT_BEFORE:-0}
SAVE_EVERY=250
. /home/witcheer/Pollen/hill-runs-09z32.sh
. /home/witcheer/Pollen/hill-train-body.sh
