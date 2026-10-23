#!/bin/bash
# 09w-duck-carpetbl.sh: duck skill tree level 11c (2026-10-06 ~07:45 CEST, mercury, operator "ok let's fill the gap").
# -Backlash- twin of level 11 (09u carpet VelStand on Pollen's soft_carpet branch, worktree ~/Pollen/microduck_rl-carpet):
# Mjlab-VelStand-Flat-Backlash-MicroDuck (robot_allcollisions_backlash.xml, 2 deg total gear play per servo, same 61/14 dims),
# same recipe as 09u: PPO + BC from the stand expert on fallen frames + walk anchor on upright frames.
# why: sim2real hardening of the first policy of ours that gets up from its back; the maker's own production VelStand
# recipe runs on a -Backlash- task (velstand cfg docstring, "Prod recipe = THIS file on Mjlab-VelStand-Rough-Backlash-MicroDuck").
# seed: 09u final model_6000.pt copied to logs/rsl_rl/duckcarpetbl/2026-10-06_00-00-00_seed-carpet-it6000/ (md5 in log.md).
# true twin warm start: MICRODUCK_WARM_START NOT set, curricula resume on their last stage (step counter from the seed).
# carpet DR at the maker's values (MICRODUCK_CARPET_DEEP not set). if the 09v verdict (tue ~16:00) beats 09u, re-seed from
# 09v's model_9000 (TARGET_IT 12000, export MICRODUCK_CARPET_DEEP=1) before this item's first block.
# 3k rule: 6000 -> 9000. probe numbers: see log.md 2026-10-06.
# enters ~/idle-queue only after 59's last leg has the card (watcher ~/Pollen/w09w-enqueue.sh), so it cannot take the
# tue 14:10 block's 59 slot (the wed maths post needs that cell); it then trains the block's tail (ld == B, same duck block).
SKILL=carpetbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckcarpetbl-status.json
TASK=Mjlab-VelStand-Flat-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-9000}
RL=/home/witcheer/Pollen/microduck_rl-carpet
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
ls $RL/logs/rsl_rl/duckcarpetbl/*/model_[1-9]*.pt >/dev/null 2>&1 || { echo "09w: no seed checkpoint, refusing"; exit 2; }
. /home/witcheer/Pollen/duck-train-body.sh
