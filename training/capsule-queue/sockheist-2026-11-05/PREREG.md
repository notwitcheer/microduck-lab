---
status: frozen
approval: not-applicable
frozen: 2026-11-05 (thu, ~20:05 CET, before any counted 09z28/09z29 output)
---

# PREREG: Arena 6 m Sock Heist (items 09z28, 09z29)

frozen before any counted output. nothing below changes after a counted checkpoint score exists; a later change is logged next to this file as a dated amendment, never in place. simulation only, no real-robot claim of any kind.

## the event, re-verified at the primary source (fetched 2026-11-05 ~19:00-20:00 CET)

- event + rules: https://github.com/pollen-robotics/microduck-arena `arena/events/sock-heist-6m.toml` (raw fetch 2026-11-05) and the Space API https://pollen-robotics-microduck-arena.hf.space/api/events (fetched 2026-11-05): id `sock-heist-6m`, `kind = "perpetual"` (an ongoing board, no cup, no entry deadline found in the toml, the guide or the API), 6.0 m lane, 0.8 m wide, time limit 40 s, metric mean finish time, seeds 1-5, sweep 0.20-1.20 m/s in 0.05 steps with the 3 fastest re-run on seeds 1-5, a fall, a catch or a timeout counts 40 s.
- the giant: first look 0.6-1.0 s after the start, red 1.4-2.4 s, green 1.6-3.0 s, 0.4 s head turn, a trunk more than 3 cm from its mark is caught (motors off). the policy sees only its command (twist zero from the first step of the turn until the head looks away); the lane's heading hold steers the yaw rate.
- guide: https://github.com/pollen-robotics/microduck-arena `docs/guides/challenges/sock-heist-6m.md` (fetched 2026-11-05).
- recipe + known results: https://github.com/pollen-robotics/microduck-challenges `src/microduck_challenges/sock_heist_6m/AGENTS.md` (fetched 2026-11-05 at main 5cee942, 2026-10-30; the folder's last commit 0b4ace4, 2026-10-28): mjlab task `Mjlab-SockHeist6m-MicroDuck`, warm start from the Arena's reference walker, 4096 envs, 1000 iterations, a checkpoint every 100, judge every checkpoint on the Arena evaluator. the maker's own reference run (heist5 checkpoint 300, the shipped recipe) scored 16.98 s on a Mac; the reference walker scores 24.159 s on x86 (maker's number) and 24.159 s on our box (re-run 2026-11-05: identical to the millisecond).
- live board: https://pollen-robotics-microduck-arena.hf.space/api/events/sock-heist-6m/leaderboard (fetched 2026-11-05 17:50 UTC): 70 rows (69 at the first read the same day), 16 users, top 4.885 s, median 8.516 s, slowest 22.380 s. the reference walker's 24.159 s would sit below the slowest row (rank 71 of 71). the board moves; the rank is recomputed live by the proof and is never a promise.
- the guide tells an agent never to publish, enter or push without the user's explicit yes. this PREREG and both queue items obey that: nothing here enters, publishes or pushes.

## the local scorer is the board's scorer

`arena score` from the installed Arena 0.7.0 wheel on capsule (x86_64 Linux, the Space's platform). reproduced on 2026-11-05: the reference walker 24.159 s (the repo's own x86 number 24.159), and three live board policies pulled from their public Hub files scored 22.380 s (board rank 70), 9.479 s (rank 46), 8.058 s (rank 31): all three equal their board rows to the millisecond. the 25-seed CHECK (`python -m microduck_challenges.sock_heist_6m.check`) reproduces the maker's walker tally (24/25, one catch on seed 23 at 1.56 s).

## question

can a Hermes-run, shipped-recipe training (AGENTS.md as written, 1000 iterations) turn the reference walker into a duck that beats it on the Arena's own evaluator by a margin that is not noise, and what rank would that score take on the live board at the time. the headline is OUR LOCAL ARENA SCORE vs THE REFERENCE WALKER'S (24.159 s). the rank is reported only.

## runs (item 09z28, CPU-checked, GPU pace 0.86 s/it)

| run | recipe | seed | role |
|---|---|---|---|
| hs1 | the recipe AS SHIPPED (clone at main 5cee942, `challenge.toml` untouched, sha256 below) | agent seed 1 | HEADLINE, seed A |
| hs2 | the same | agent seed 2 | HEADLINE, seed B (replication) |
| hsf4 | ONE knob: `freeze_reward` 2.0 -> 4.0 (within its 0-6 range; the AGENTS.md worked example), local branch `heist-freeze4` commit cd37b36, worktree `wt-freeze4`, agent seed 1 | agent seed 1 | VARIANT: reported, never compared to hs1 as a verdict (one seed each, the maker warns GPU runs vary a lot between seeds) |

each run: 4096 envs, 1000 iterations, a checkpoint every 100 (files it100 ... it900 and it999 exist; there is no model_0 save, so 10 per run). the knob choice was fixed before any 09z28 training: it is not a Hermes-written reward and not tuned on any output. the shipped `lights.py`, `walker.onnx`, `rewards.py` and tests are untouched (37 repo tests pass on the clone, 2026-11-05).

## pick rule (per run, frozen)

every saved checkpoint it100..it999 is exported as the real publish does (`publish --dry-run`, normalizer baked in) and scored with `arena score`. PICK = among the checkpoints that finish 5/5 seeds, the lowest local score; ties by the earlier iteration. no checkpoint finishing 5/5 = no pick for that run. a pick is never re-chosen after the 25-seed CHECK.

## verdict (headline = the better of hs1 and hs2 by pick score; frozen constants in `heist-proof-2026-11-05.py`)

GAIN = ALL of: (1) the headline pick's local Arena score is at most 21.0 s (3.159 s better than the walker's 24.159 s, roughly the spread between the walker's own seeds 21.4-26.6 s); (2) the pick finishes at least 24 of the 25 CHECK seeds (the walker itself finishes 24/25, one catch); (3) the mean over the 20 CHECK seeds 6-25, which the pick never saw, is at most 22.5 s (the walker's is 24.03 s over its 19 finishers).
BEATS WALKER, BAR NOT MET = the pick's score is below 24.159 s, it finishes at least 24/25, and its held-out mean is below 24.0 s, but the GAIN bar is missed.
NO GAIN = otherwise (including no 5/5 checkpoint).

reported only, never part of the verdict: replication (how many of hs1/hs2 meet the GAIN bar; "one seed of two" is stated as such), the variant hsf4's pick and score, every per-checkpoint score (a table is kept: late drift cannot hide), the live board rank the headline pick would take at scoring time (rank among the board's rows then, with the board's size, top, median and slowest), the reasons seeds end (caught early/late, fell, out of time).

## what each outcome may be called

- GAIN and replicated: "a Hermes-run training of the shipped recipe beats the reference walker on the Arena's own scorer: N s against 24.159 s in sim, rank R of M on the live board at <date>". sim only on every caption. no rank promise; no sentence about beating named players.
- GAIN, not replicated: "one seed of two". no post claim beyond the log.
- BEATS WALKER, BAR NOT MET or NO GAIN: a plain finding; the duck stays unentered, no clip beyond the log.
- never: "first", "best", any statement that a real duck could do this, or a ranking claim from a different date than the one it was computed on. an Arena entry is its own operator yes and passes `--code-url` on the FIRST entry (the Arena dedupes on user + ONNX sha256); the branch commit must be on the notwitcheer fork first (a separate gated push).

## clip (09z29, best effort, never changes the verdict)

the Arena's own recorder (`arena score --store` into a LOCAL store, `arena clip`, headless Chromium on CPU, no card) for the headline pick. cut: 10 s starting 0.1 s after the tape begins (the duck already on its feet, no title/aerial intro), 1920x1080 16:9, audio kept (crowd, horn, the giant's quack), a black caption strip under the frame: line 1 "simulation only, not yet on a real robot", line 2 from the pick's own score file and its replay seed's CHECK line (local score, seeds finished, reds met, worst drift in cm against the 3 cm ring). every caption number comes from those files. the format was proven on the reference walker on 2026-11-05 (783 s render, cut 10.04 s, 1920x1080, caption fits one line, no path or host text visible; vault `60-robotics/microduck/content/clips/heist-format-test-walker-2026-11-05.mp4`, not a counted take). a clip is only shown when the verdict is GAIN.

## sizing and slot

0.86 s/it steady at 4096 envs (40-iteration GPU smoke on a free card, rule-3 checked in-script and by hand, 35 s wall, 5.6 GB peak; the 2-env CPU smoke 2.1 s/it). 3 runs x (1000 x 0.86 s + ~40 s start) = ~46 min plus ~2 min preflight/drain/restore = ~48 min of card (ESTIMATE until the full run). the proof item is CPU: export + score of 30 checkpoints (~10 min), 3 picks x CHECK (~4 min), the clip (~15 min): ~30 min, no card. gate: `NOT_BEFORE` = Sat 2026-11-07 00:00 CET (epoch 1794006000). first weekend block: the runner's Sat 00:10 fire.

## dev data seen before this freeze (disclosure, not counted)

- reference walker 24.159 s 5/5 (sweep: finishes 0.60-1.00 m/s, falls from 1.05); three board policies scored 22.380 / 9.479 / 8.058 s.
- a 2-env CPU smoke and a 3-6 iteration CPU e2e (16 envs): the e2e pick scored 31.7 s (not 5/5 on most checkpoints), a plumbing test of the proof item, never a training result. a 40-iteration 4096-env GPU smoke was not scored.
- no 09z28 counted checkpoint exists at the time of this freeze.

## frozen files (sha256, at freeze; the same bytes sit on capsule in ~/Pollen/queue-staging and ~/Pollen)

| file | role | sha256 |
|---|---|---|
| `09z28-duck-sockheist.sh` | train item (NOT_BEFORE gate) | `588964b3c913e80a70893cc78b01885dd3f9c92e247ed54d90b0c09dbef72b59` |
| `09z29-duck-proof-sockheist.sh` | proof item | `382bcceb1d794e5859053dca3f3e18f00d52a4c61a011b4aa508e6f7f7fc0302` |
| `heist-train-body.sh` | shared train body | `9c162f4176ef0e92e83ed725da40c363bfdaf6507e3b0efd86c03248bf9057b7` |
| `heist-runs-09z28.sh` | run matrix | `7ff7224414b908c703634ce0aae906428ab5f94ca955b2f1285300448fe1d301` |
| `heist-proof-2026-11-05.py` | export, score, pick, check, verdict, live rank | `209295b99d3db0bc88c74695ae2f4f9c07b052ef10534b369b1d3ccf7835faad` |
| `clip-heist-2026-11-05.sh` | clip cut | `e0fb2bdbe0afac5f48b362dbb90bef23be23c791b68678f9eafd3f19eea5a09d` |
| clone `challenge.toml` (main 5cee942) | the shipped recipe | `099e0ed7bbbbf1deff57ffab2889350bbaea389f1558a50697b6f304fde17e68` |
| `wt-freeze4` `challenge.toml` (cd37b36) | the one-knob variant | `e3858f35538fe72a32493265547dc69ad2ace920ac662c81528cb8526ecdf260` |

the sha256 of this PREREG.md is recorded in the vault log entry 2026-11-05 (staged: 09z28/09z29 sock heist).
