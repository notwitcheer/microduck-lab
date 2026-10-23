#!/bin/bash
# 09u-duck-carpet.sh: duck skill tree, new level (2026-10-05, mercury, operator "can't we do something else about the duck?").
# task Mjlab-VelStand-Flat-MicroDuck on Pollen's branch soft_carpet (695f3b7, 2026-09-26) in a separate worktree
# ~/Pollen/microduck_rl-carpet (our pinned 53b8971 clone untouched). that branch = protective_fall rebuild (one policy that
# walks, falls in a way that spares the XL330 gearboxes, and gets up; all-collisions model, servo/head/trunk impact costs)
# + soft-carpet ground DR with a severity curriculum (their commit: "real robot trips forward and runs away on soft carpet",
# 98% falls in sim at 10 mm pile with the deployed velstand).
# recipe = the maker's own: WARM START from a walk + PPO with behaviour cloning from a frozen stand expert on fallen frames
# and a walk anchor on upright frames (tasks/distill.py). the maker pulls both from their wandb; we have no wandb, so:
#   expert = alpha_stand.onnx (HF pollen-robotics/microduck-policies) rebuilt to an rsl_rl checkpoint by ~/Pollen/onnx2ckpt.py
#            (max |torch - onnx| 2.05e-05 on 256 random obs). in OUR StandUp harness it gets up from flat on its back 5/5
#            (verdict-alpha-stand-2026-10-05), where every policy we trained froze 0/N.
#   warm start + anchor = OUR level 1 walk, duckvel model_4000 (md5 15545df4, HF witcheer/microduck-walk-flat v1), copied as
#            seed-walk-it4000/model_0.pt. MICRODUCK_WARM_START=1 (their mdp.py Patch 5) restarts curricula at 0; it is set
#            ONLY while no trained checkpoint exists, so a resume in a later block keeps the curricula.
# distill.py patched to read MICRODUCK_BC_EXPERT / MICRODUCK_BC_ANCHOR (local paths) before wandb (backup ~/distill.py.bak-localexperts-2026-10-05).
# TARGET_IT 6000 = the branch's own max_iterations for the warm-start schedule.
# probes 2026-10-05 07:55-07:58 CEST: 64 envs x 3 it rc 0 ("expert BC ON ... walk anchor ON", Patch 5 counter 96024 -> 0, auto
# ONNX export written); 4096 envs x 40 it rc 0, 1.09 s/it, VRAM peak 20.4 GB -> ~110 min + export, fits one 180-min block.
# body: ~/Pollen/duck-train-body.sh with RL overridden (2026-10-05 edit: RL=${RL:-...}).
SKILL=carpet
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckcarpet-status.json
TASK=Mjlab-VelStand-Flat-MicroDuck
TARGET_IT=${TARGET_IT:-6000}
RL=/home/witcheer/Pollen/microduck_rl-carpet
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
ls $RL/logs/rsl_rl/duckcarpet/*/model_[1-9]*.pt >/dev/null 2>&1 || export MICRODUCK_WARM_START=1
. /home/witcheer/Pollen/duck-train-body.sh
