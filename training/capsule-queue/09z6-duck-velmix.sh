#!/bin/bash
# 09z6-duck-velmix.sh: duck skill tree, "our own conditions" track, sixth item = the COMBINATION of the three conditions that
# paid: single step (09z3 GAIN, walk-step), slippery feet (09z2 GAIN, walk-slip), 2x training shoves (09z4, gain at the training
# cadence). task Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck (module witcheer_velocity_mix_env_cfg.py, vault
# 99-personal/benchmark-rig/scripts/; imports the step/slip/push modules, so their verdict env overrides work unchanged).
# installed 2026-10-16 ~21:25 CEST (install-mix-fork-2026-10-16.sh, backup ~/tasks-init.py.bak-mix-2026-10-16); train+play cfg
# reprs of base/step/slip/push/slope md5-identical before/after.
# WARM START: logs/rsl_rl/duckvelmix/2026-10-16_00-00-00_seed-velstep-it10000/model_10000.pt = walk-step v1 (duckvelstep
# model_10000, md5 d97b7567), true resume, 10000 -> 13000 (3k rule).
# probe (free card, 4096 envs, 2026-10-16 21:29 CEST): 1.29 s/it (n=5), card peak 7,526 MiB, train rc 0 (66 s), export rc 0
# (793,774 B), checkpoint loaded with 0 size mismatch, nan_state 0.0000 -> ~65 min + export (log ~/Pollen/probe-velmix.log).
# verdict: proof-z6-{a,b,c,d}.sh, 15 takes per policy per condition, pre-registered:
#   a (GAIN condition) all three at once: 25 mm step + foot friction 0.2 + 2x shoves at the 3-6 s training cadence, mix vs walk-flat v2
#   b (no-loss) 25 mm step, normal grip, no shoves: mix vs walk-step (z3)
#   c (no-loss) 1 mm (flat) + foot friction 0.2 + maker 1x shoves: mix vs walk-slip (z2)
#   d (no-loss) 1 mm + grip 1.0 + 2x shoves at 3-6 s: mix vs 09z4 velpush
# operator 2026-10-16 ~21:10 CEST "following leads, please do for the better" (stage a sixth duck item).
SKILL=velmix
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelmix-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck
TARGET_IT=${TARGET_IT:-13000}
. /home/witcheer/Pollen/duck-train-body.sh
