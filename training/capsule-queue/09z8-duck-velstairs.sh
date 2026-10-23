#!/bin/bash
# 09z8-duck-velstairs.sh: duck skill tree, "our own conditions" track, eighth item = STAIRS: short flights of 2-3 steps, up and down, on top of the
# walk-mixslope conditions (single step GAIN 09z3, hills GAIN 09z5, mix GAIN 09z6, mixslope no gain but no loss 09z7; walk-mixslope v1 is public).
# task Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck (module witcheer_velocity_stairs_env_cfg.py, installed 2026-10-23 by
# install-stairs-fork-2026-10-23.sh, backup ~/tasks-init.py.bak-stairs-2026-10-23; train+play cfg reprs of base/step/slip/push/slope/mix/mixslope
# md5-identical before/after). imports the step/slope/slip/push modules: foot friction (0.2, 1.3), shoves x2, backlash robot, 4 m tiles, 10 x 10 grid,
# 20 m border, random mode. TILE MIX (shares): stairs2 0.25 (2 risers, 1 tread of 0.25 m, 2.5 m platform), stairs3 0.25 (3 risers, 2 treads of 0.25 m,
# 2.0 m platform), single_step 0.15 (the 09z3 tile), hill 0.15 (the 09z5 tile, retention), flat 0.20 (walking on the flat is not lost). riser height
# 10-25 mm per tile (the band 09z3 gained on), so a 3-step flight tops out at 30-75 mm; 1.0 m of flat floor between the flights of neighbouring tiles.
# depends on our clone patches: ground_height_patch.py (_ground_z on generator floors), terrain_* chain (velocity family).
# WARM START: logs/rsl_rl/duckvelstairs/2026-10-23_00-00-00_seed-velmixslope-it16000/model_16000.pt = walk-mixslope (duckvelmixslope
# 2026-10-22_14-18-58 model_16000, md5 82e6979d, both copies), true resume, 16000 -> 19000 (3k rule).
# probe (2026-10-23 17:58-18:00 CEST, free card, sanctioned drain, 4096 envs, probe-velstairs-wrap-2026-10-23.sh): checkpoint loaded, 0 size mismatch,
# 2.35 s/it mean of 46 (steady 2.30-2.35), card peak 7,762 MiB, train rc 0 (116 s), export rc 0 (793,780 B), nan_state 0.0000
# -> 3000 it ~118 min + export. heightfield tiles present: same ~2x cost as 09z5/09z7; a weekend block holds it whole.
# verdict: proof-z8-{a,b,c}.sh, 15 takes per policy per condition, 20 s, --cmd-vx 0.3 --no-bounds, scorer z8-score-2026-10-23.py, all vs walk-mixslope.
# pre-registered: a (GAIN, one-sided) Stairs env, flights only (MICRODUCK_STAIRS_MIX=stairs2:0.5,stairs3:0.5), riser 25 mm, friction 0.2, 2x shoves 3-6 s;
#   b (no loss, two-sided) the maker's flat task Mjlab-Velocity-Flat-Backlash-MicroDuck (plane, default DR, maker play shoves);
#   c (no loss, two-sided) the MixSlope condition = proof-z7-a harness (hill 0.15 + step 25 mm + friction 0.2 + 2x shoves 3-6 s).
# operator yes 2026-10-23 ~17:50 CEST (GPU thread): "Stairs: flights of 2-3 steps, warm-started from walk-mixslope".
SKILL=velstairs
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelstairs-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Stairs-MicroDuck
TARGET_IT=${TARGET_IT:-19000}
. /home/witcheer/Pollen/duck-train-body.sh
