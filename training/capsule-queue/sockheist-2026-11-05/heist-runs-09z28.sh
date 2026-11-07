#!/bin/bash
# heist-runs-09z28.sh: the run matrix of item 09z28 (sourced by the item header AND by the proof item 09z29, so both read the same names and targets).
# spec = name|worktree|agent seed|target_it|envs   (worktree under ~/Pollen/arena/heist)
#   hs1  = the recipe AS SHIPPED (Pollen's own reference recipe, commit 5cee942, challenge.toml untouched), agent seed 1      HEADLINE arm, seed A
#   hs2  = the recipe AS SHIPPED, agent seed 2                                                                          HEADLINE arm, seed B
#   hsf4 = ONE knob changed, committed on branch heist-freeze4 (cd37b36): freeze_reward 2.0 -> 4.0 (inside the knob's 0-6 range; the AGENTS.md worked example), agent seed 1     VARIANT arm (reported, not the headline)
# 1000 iterations, a checkpoint every 100 (model_0 is not saved; 100..900 and 999): the recipe in AGENTS.md.
RUNS=(
  "hs1|microduck-challenges|1|1000|4096"
  "hs2|microduck-challenges|2|1000|4096"
  "hsf4|wt-freeze4|1|1000|4096"
)
HEADLINE_RUNS="hs1 hs2"
VARIANT_RUNS="hsf4"
