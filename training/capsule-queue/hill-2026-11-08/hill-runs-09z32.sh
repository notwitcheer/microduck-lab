#!/bin/bash
# hill-runs-09z32.sh: the run matrix of item 09z32 (sourced by the item header AND by the proof item 09z33, so both read the same names and targets).
# spec = name|worktree|agent seed|target_it|envs   (worktree under ~/Pollen/arena/hill; every run trains FROM SCRATCH: that is the hill-climb recipe as shipped)
#   hc1 = the recipe AS SHIPPED (clone main 5cee942, challenge.toml untouched: forward 2, upright 2, step 3, max_slope 10), agent seed 1   HEADLINE
#   hc2 = the recipe AS SHIPPED, agent seed 2                                                                                         HEADLINE
#   hc3 = the recipe AS SHIPPED, agent seed 3                                                                                         HEADLINE
# 1500 iterations per run (half the shipped 3000: the GPU smoke measured 2.3 s/it, so 3 x 3000 it would be 5.8 h of card; the maker's own reference run is best at checkpoint 1000), a checkpoint every 250: it250 ... it1250 and it1499 are judged (6 per run; model_0 is saved and never judged). no variant arm: the three seeds are the replication.
RUNS=(
  "hc1|microduck-challenges|1|1500|4096"
  "hc2|microduck-challenges|2|1500|4096"
  "hc3|microduck-challenges|3|1500|4096"
)
HEADLINE_RUNS="hc1 hc2 hc3"
VARIANT_RUNS=""
