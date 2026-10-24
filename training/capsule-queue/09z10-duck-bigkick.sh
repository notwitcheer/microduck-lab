#!/bin/bash
# 09z10-duck-bigkick.sh: duck skill tree, "something visual" item (operator, GPU thread, Sat 2026-10-24 ~21:35 CEST: "let's queue a duck please. let's try to do something that is
# more visual, that would hook people"). level 7 kick, again, with a GIANT ball: 300 mm across (r 0.15 m), 0.275 kg, bigger than the 250 mm duck, in a goal 1.4 m ahead for the clip.
# task Mjlab-BallKick-Flat-Backlash-Big-MicroDuck (module witcheer_ballkick_big_env_cfg.py, installed 2026-10-24 by install-bigkick-fork-2026-10-24.sh, backup ~/tasks-init.py.bak-bigkick-2026-10-24;
# train + play cfg reprs of BallKick flat/backlash, Velocity backlash, Stairs, Roulade md5-identical before/after, 10 of 10). ONE change against the backlash kick task: the ball (radius 0.15,
# mass 0.275 = 15 g x (r/35 mm)^2, blue) and its reset offset x 0.205 (nominal rear surface unchanged at 0.055). target kick speed 1.0 m/s, rewards, curricula, DR, 5 s episodes are the backlash
# kick's. no clone patches involved (ball task, flat plane). the goal exists only in the PLAY cfg behind MICRODUCK_BIGKICK_GOAL=1 (clip/verdict), never in training.
# WHY it trains something: a seed-only sweep (2026-10-24, no training) showed the 09l kickbl policy already MOVES balls up to r 0.18 m and puts the ball in a wide goal, but weaker the bigger the ball:
# median ball travel at 1 s / 2 s 0.80 / 1.25 m on the maker's 70 mm ball (32 takes) vs 0.35 / 0.74 m on this one (6 takes, max 0.86 at 2 s): the forward-velocity term pays ~5 of its 12. 3k iterations
# should close that, or show it cannot. the seed alone already makes a usable giant-ball clip; this item makes the kick strong.
# WARM START: logs/rsl_rl/duckbigkick/2026-10-24_00-00-00_seed-kickbl-it13000/model_13000.pt = duckkickbl 2026-09-28_14-10-20 model_13000 (md5 7265ed9e, both copies), true resume,
# 13000 -> 16000 (3k rule). obs/action dims identical (61/14), checkpoint loads with no size mismatch.
# probes 2026-10-24 (shared card: the sub10 llama-server held 10.3 GB at 97% util, so every pace below is CONTENDED and UNVERIFIED as a free-card pace): see the log.md entry for the final probes on the
# giant-ball cfg. FREE-CARD ESTIMATE: 1.21 s/it (09l kickbl, same task cost) -> 3000 it ~61 min + export, one block. UNVERIFIED until it runs.
# verdict: item 09z11-duck-proof-bigkick (right behind this one), batches proof-bk-{a,b,c}, scorer bk-score-2026-10-24.py, new vs the seed (kickbl model_13000). pre-registered: a = giant ball + goal, no
# shoves, 15 takes per policy, success = held AND ball >= 1.25 m from its start by t = 2 s (the seed's own median on the 70 mm ball; its median on the giant ball is 0.74 m), one-sided Fisher p < 0.05 =
# GAIN; c = stock small ball, no-loss two-sided; b (play shoves) reported only. then clip-bigkick-2026-10-24.sh cuts the X clips from batch a.
# body: ~/Pollen/duck-train-body.sh (shared with every duck item; e2e-proven once on 09z8's clone; NOT re-e2e'd for this task id: the card is held by the running sub10 bench leg and the body's own
# Donald stop/drain must not run beside it; the exact-argv probes cover the train + resume + export commands).
# operator ask 2026-10-24 ~21:35 CEST (GPU thread). sim only, nothing public.
SKILL=bigkick
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckbigkick-status.json
TASK=Mjlab-BallKick-Flat-Backlash-Big-MicroDuck
TARGET_IT=${TARGET_IT:-16000}
. /home/witcheer/Pollen/duck-train-body.sh
