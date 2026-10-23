#!/bin/bash
# 09x-duck-vsroughbl.sh: duck skill tree level 11d (2026-10-06 ~18:30 CEST, mercury, operator "yeah following what you think works best").
# rough terrain + gear play + the distilled get-up in one policy: Mjlab-VelStand-Rough-Backlash-MicroDuck on Pollen's soft_carpet
# branch (worktree ~/Pollen/microduck_rl-carpet), same recipe as 09u/09w (PPO + BC from alpha_stand on fallen frames + walk anchor).
# why: the maker's production VelStand recipe is exactly this task ("Prod recipe = THIS file on Mjlab-VelStand-Rough-Backlash-MicroDuck",
# velstand cfg docstring); it is the version a real owner would install.
# worktree patches (ported 2026-10-06 from 60-robotics/microduck/patches/, same order as 09m6 vsrough3): terrain_tracking(2),
# ground_height, terrain_demote_arms, terrain_prone_neutral, terrain_curriculum_mode. checked: flat VelStand(-Backlash) cfgs identical
# before/after (repr, addresses stripped); rough-backlash diff = curriculum True, rows 10 / cols 20, terrain_levels_tracking with
# neutral_prone_starts; 6 curriculum unit tests pass. backups *.bak-* in the worktree tasks dir.
# seed: 09w's FINAL model_9000.pt, copied at runtime (09w sorts first and finishes in the same block); until it exists this item
# exits 3 (resumable). true resume, MICRODUCK_WARM_START not set. 3k rule: 9000 -> 12000. probe numbers: log.md 2026-10-06.
SKILL=vsroughbl
# MANIFEST duplicated from the body so the drain's grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvsroughbl-status.json
TASK=Mjlab-VelStand-Rough-Backlash-MicroDuck
TARGET_IT=${TARGET_IT:-12000}
RL=/home/witcheer/Pollen/microduck_rl-carpet
export MICRODUCK_BC_EXPERT=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
export MICRODUCK_BC_ANCHOR=/home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckvel/2026-09-15_14-10-10_duckvel/model_4000.pt
if ! ls $RL/logs/rsl_rl/duckvsroughbl/*/model_[1-9]*.pt >/dev/null 2>&1; then
  SRC=$(ls $RL/logs/rsl_rl/duckcarpetbl/*/model_9000.pt 2>/dev/null | tail -n 1)
  if [ -z "$SRC" ]; then
    [ "${DRYRUN:-0}" = "1" ] && { echo "09x: seed pending (09w model_9000 not written yet), DRYRUN ok"; exit 0; }
    echo "09x: 09w model_9000 not written yet, waiting (exit 3, resumable)"; exit 3
  fi
  if [ "${DRYRUN:-0}" != "1" ]; then
    D=$RL/logs/rsl_rl/duckvsroughbl/$(date +%F)_00-00-00_seed-carpetbl-it9000
    mkdir -p $D && cp "$SRC" $D/model_9000.pt && echo "09x: seeded from $SRC ($(md5sum < "$SRC" | cut -c1-8))"
  fi
fi
. /home/witcheer/Pollen/duck-train-body.sh
