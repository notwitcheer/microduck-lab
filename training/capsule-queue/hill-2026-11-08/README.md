# 1.5 m Hill Climb (items 09z32, 09z33): board audit + shipped-recipe comparator

simulation only, local scores with the Arena's own evaluator, nothing entered. the frozen pre-registration is `PREREG.md` (hashes in `FROZEN.sha256`); the queue items that ran are `../09z32-duck-hill.sh` (train) and `../09z33-duck-proof-hill.sh` (proof). they differ from the capsule copies in header comments only; code lines are identical.

## result (run Sun 2026-11-08: training 13:21-16:12 CET, proof 16:12-16:31 CET)

part A, board audit: **AUDIT HOLDS** (pre-registered).
- live board read 2026-11-08 15:18 UTC: 133 rows, 42 users, top 0.737 s, median 0.887 s.
- 129 of 133 public policy files re-scored with the Arena's evaluator (4 not fetchable); **129 of 129 match their board row**.
- each re-scored on 25 starts (the board scores 5): of the top 30 rows, **25 finish fewer than half of the 20 unscored starts, 23 finish none**. all 30 tip past 60 degrees in a scored start. Pollen's reference finishes 20 of 20.
- the best row that holds up on 25 starts (>= 24 finish, >= 24 upright) is board rank 72, 0.926 s mean of 25.

part B, shipped recipe from scratch (3 seeds x 1500 iterations, half the shipped 3000): **GAIN, 2 of 3 seeds**.
- pick hc2 it1000: 4.931 s (5 of 5, upright) vs the reference 5.870 s re-scored here; 25-start check 25 of 25 finished and upright, unscored starts 6-25 mean 4.960 s.
- hc3 it1000 5.622 s, 25 of 25, unscored mean 5.617 s (meets the bar). hc1 fails the unscored-start rule (23 of 25, mean 11.0 s).
- on the board this is rank 111 of 134 by the scored starts; ranked by the mean of 25 starts across the audited rows it would sit 22nd of 130.

limits: simulation only; the board moves (the audit is a read at one time); entrants' files may be tuned to the scored starts on purpose, which this does not judge. run summaries in `run/` (paths made relative).
