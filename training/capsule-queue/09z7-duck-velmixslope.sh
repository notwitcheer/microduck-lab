#!/bin/bash
# 09z7-duck-velmixslope.sh: duck skill tree, "our own conditions" track, seventh item = COMBINATION of walk-mix (09z6: single
# step + foot friction DR 0.2-1.3 + 2x shoves, GAIN 9/15 vs 0/15, p 0.0003) and the 09z5 slope terrain (GAIN, hill pooled
# 23/30 vs 12/30, p 0.0041). task Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck (module witcheer_velocity_mixslope_env_cfg.py,
# vault 99-personal/benchmark-rig/scripts/; imports the step/slope/slip/push modules: 4 m tiles drawn 0.5 step / 0.5 hill,
# friction (0.2, 1.3), shoves x2; every verdict override works unchanged). installed 2026-10-22 (install-mixslope-fork-2026-10-22.sh,
# backup ~/tasks-init.py.bak-mixslope-2026-10-22); train+play cfg reprs of base/step/slip/push/slope/mix md5-identical before/after.
# depends on our clone patches: ground_height_patch.py (_ground_z on generator floors), terrain_* chain (velocity family).
# WARM START: logs/rsl_rl/duckvelmixslope/2026-10-22_00-00-00_seed-velmix-it13000/model_13000.pt = walk-mix (duckvelmix
# 2026-10-18_16-27-19 model_13000, md5 81a588eb), true resume, 13000 -> 16000 (3k rule).
# probe (2026-10-22 10:39-10:41 CEST, free card in a gap between sibling runs, 4096 envs, sanctioned drain): checkpoint loaded,
# 0 size mismatch, 2.51 s/it mean of 46 (steady 2.37-2.44), card peak 7,875 MiB, train rc 0 (119 s), export rc 0 (793,784 B),
# nan_state 0.0000 -> 3000 it ~126 min + export: one block only if it starts the block (heightfield ~2x the step-only mix).
# verdict: proof-z7-{a,b,c}.sh, 15 takes per policy per condition, 20 s, --cmd-vx 0.3 --no-bounds, scorer z7-score-2026-10-22.py,
# pre-registered: a (GAIN, one-sided) MixSlope env, hill 0.15 + step 25 mm + friction 0.2 + 2x shoves at 3-6 s, z7 vs walk-mix (z6);
#   b (no loss, two-sided) Slope env, hill 0.15, no shoves, z7 vs walk-slope (z5) = proof-z5-b harness;
#   c (no loss, two-sided) Mix env, step 25 mm + friction 0.2 + 2x shoves at 3-6 s, z7 vs walk-mix = proof-z6-a harness.
# enqueued by watcher w09z7 (~/Pollen/w09z7-enqueue.sh) only once 66y-voxel-muse has started (09z7 sorts before 66y).
SKILL=velmixslope
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelmixslope-status.json
TASK=Mjlab-Velocity-Flat-Backlash-MixSlope-MicroDuck
TARGET_IT=${TARGET_IT:-16000}
. /home/witcheer/Pollen/duck-train-body.sh
