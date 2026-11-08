---
status: frozen
approval: not-applicable
frozen: 2026-11-08 (sun, CET, before any counted 09z32/09z33 output); re-frozen once 2026-11-08 ~10:45 CET, still before any counted output, to correct the line-1 wording (see AMENDMENT 1)
---

# PREREG: Arena 1.5 m Hill Climb (items 09z32, 09z33)

frozen before any counted output. nothing below changes after a counted checkpoint score exists; a later change is logged next to this file as a dated amendment, never in place. simulation only, no real-robot claim of any kind. a PLAN phase in both items refuses to run when a frozen file differs from `FROZEN.sha256` (the capsule copy of this file sits in `~/Pollen/hill-frozen/` with the hash list).

## why this item exists (sequel guard, read first)

third Arena-guide duck result in a week (Sock Heist post scheduled Wed 11-11, Roller banked). it stages only because it has its own hook that is NOT "my duck learned another Arena event": the Hill Climb board's top rows are tuned to the five starts the board scores. PART A audits the live board (CPU, no training); PART B is the comparator (the shipped recipe, 3 seeds, 1500 iterations each) and may well be a NO GAIN, which is a valid result and not post material. the post, if any, is about the BOARD, never about our duck.

## the event, re-verified at the primary source (fetched 2026-11-08 ~08:30-10:00 CET)

- guide + recipe: https://github.com/pollen-robotics/microduck-challenges `src/microduck_challenges/hill_climb_1m5/AGENTS.md` (raw fetch 2026-11-08 08:35 CET at main 5cee942, 2026-10-30; the folder's last commit 9aaec6d, 2026-10-26, GitHub commits API 2026-11-08). task `Mjlab-HillClimb1m5-MicroDuck`, recipe: 4096 envs, 3000 iterations, a checkpoint every 250, seed 1, knobs `forward_reward` 2 (0.5-5), `upright_reward` 2 (0.5-5), `step_reward` 3 (0-6), `max_slope_deg` 10 (8-15). the guide states the reference scores 5.866 s at 0.55 m/s, 5/5 (checkpoint 1000 of that recipe) and that its checkpoints differ a lot (5.88 / 8.38 / 6.47 / 6.81 / 9.97 s at 1000-2000).
- event: the installed Arena 0.7.0 wheel's `arena/events/hill-climb-1m5.toml` (read on capsule 2026-11-08): `kind = "perpetual"`, lane 1.5 m x 0.8 m on an 8 degree slope, walls 0.15 m, time limit 60 s, metric mean finish time over seeds 1-5, sweep 0.15-1.00 m/s in 0.05 steps (18 speeds, seed 1), the 3 fastest finishers re-run on seeds 1-5, best mean kept; a fall (trunk tilted past 60 degrees for 0.3 s) or a timeout counts 60 s; the policy reads `[vx, 0, 0]`, never its heading or position.
- live board: https://pollen-robotics-microduck-arena.hf.space/api/events/hill-climb-1m5/leaderboard (fetched 2026-11-08 ~08:30 CET and again ~09:50 CET): 132-133 rows, 42 users, top 0.737 s, median 0.8845 s, slowest 60.0 s; the reference is row `Pollen Hill Climb Reference` 5.87 s at 0.55 m/s (board rank 118). the board moves; every rank is recomputed live and never promised.

## the local scorer is the board's scorer

`arena.evaluate.evaluate` from the Arena 0.7.0 wheel on capsule (x86_64 Linux, the Space's platform), called in-process by `hill-judge.py`. validation on 2026-11-08: the 132 policy files of the live board were downloaded from their public Hub URLs; 128 were fetchable (4 return 401: private repos) and **all 128 re-scored equal to their board row in score (within 1.5 ms) AND in the command the score was set at**; the Pollen reference re-scored 5.870 s, 5/5, at 0.55 m/s (= its board row). raw: capsule `~/Pollen/arena/hill/all2-r*.json`.

## what the board's top is (dev data seen before this freeze, DISCLOSED, not counted)

the same 128 files were also checked on 25 starts (seeds 1-25 at the row's own scored command, `hill-judge.py check`): board rank 1-28 all tip past the Arena's 60-degree fall line in at least one scored seed (the Arena only calls a fall after 0.3 s) and finish only the 5 scored starts: 23 of the top 30 rows finish exactly 5 of 25 starts (seeds 1-5) and none of the 20 unscored ones; rank 1-4 and 6 finish 20 of 25 (15 of 20 unscored); the Pollen reference finishes 25 of 25, all upright. the best row that finishes >= 24 of 25 AND stays upright is board rank 72 (0.936 s). a rank-1 model card says plainly that its file is "an in-sample, simulation-only competition policy" tuned to the declared evaluation starts (https://huggingface.co/HlibPlakhtii/microduck-hill-quicksilver-v3, README fetched 2026-11-08); another row's card says its file is "a small search on top of a public third-party policy" (https://huggingface.co/jrubiosainz/microduck-hill-climb-1m5-hv3x-678af340). **so PART A's threshold below is already known to hold on today's board: the proof re-runs it at proof time as a recorded measurement, it is not a surprise test.** PART B is the unknown.

## question

(A) how many of the board's top 30 rows still finish when the start seed is one the board does not score. (B) can the shipped recipe (AGENTS.md as written, from scratch, no tuning, half the shipped iterations because of the card budget: 1500 instead of 3000) train a duck that beats Pollen's reference time on the Arena's own evaluator, upright, over starts it was not picked on. the headline of B is OUR LOCAL ARENA SCORE vs THE REFERENCE'S (5.870 s on this platform). the rank is reported only.

## PART A: the board audit (CPU, 09z33, `hill-proof-2026-11-08.py audit`)

every row of the live board at proof time: policy file downloaded from the row's public `policy_url` (retry on transient errors; 401/403/404 = not fetchable, counted and reported), scored with the Arena's `evaluate()` (5 official seeds, own sweep) and checked on seeds 1-25 at the row's own scored command (`check --seeds 25`). a row is FRAGILE iff fewer than 10 of the 20 unscored starts (seeds 6-25) finish at its own scored command. **AUDIT HOLDS** iff at least 10 of the board's first 30 rows (by board rank) are FRAGILE. reported only: how many of the 128+ local scores match their board row, tilt counts, the median number of unscored starts the fragile rows finish, the best row that finishes >= 24 of 25 and stays upright, the 25-start ladder place of our pick (ranked by mean over 25 starts, falls counted 60 s).
- AUDIT HOLDS: line 1 = "[N] of the top 30 ducks on the Hill Climb board finish fewer than half of 20 extra starts the board never scores ([Z] of them finish none). Pollen's own reference finishes [K] of 20" (N = fragile rows, Z = fragile rows with 0 of 20, K = the reference's finishes of the 20 unscored starts, all from `facts-<tag>.json`; the "([Z] of them finish none)" clause is dropped when Z = 0). board rows are never named, no user or policy name is drawn or written in copy. a board row is not accused of anything: the sentence is a measurement, the entrants' own cards call their files tuned to the scored starts.
- AUDIT DOES NOT HOLD (the board was fixed or cleaned up): not post material; the finding goes to the log.

## runs (item 09z32, GPU pace 2.30 s/it at 4096 envs on a CPU-loaded box)

| run | recipe | seed | role |
|---|---|---|---|
| hc1 | the recipe AS SHIPPED (clone at main 5cee942, `challenge.toml` untouched), 1500 iterations | agent seed 1 | HEADLINE |
| hc2 | the same | agent seed 2 | HEADLINE (replication) |
| hc3 | the same | agent seed 3 | HEADLINE (replication) |

no variant arm: three seeds is the replication, because the roller sprint (2026-11-08) replicated on only 1 of 2 seeds and the guide warns GPU runs vary a lot between seeds. each run: 4096 envs, 1500 iterations (a deliberate halving of the shipped 3000 for the card budget; stated on the card and in copy), a checkpoint every 250 (it250 ... it1250 and it1499 are judged: 6 per run; model_0 is saved and never judged). `env.py` and `challenge.toml` are the clone's, byte for byte (sha256 below).

## pick rule (per run, frozen)

every saved checkpoint it250..it1499 is exported as the real publish does (`publish --dry-run`, normalizer baked in) and scored by the Arena's `evaluate()` (`hill-judge.py score`), which also records the hack metrics of the five scored seeds. PICK = among the checkpoints that finish 5/5 AND are CLEAN, the lowest score; ties by the earlier iteration. RAW = among the checkpoints that finish 5/5, the lowest score whatever the tilt. no 5/5 clean checkpoint = no pick for that run. a pick is never re-chosen after the 25-start CHECK.

CLEAN (frozen, per seed, then all five seeds): `tilt_steps == 0` (no timed step with gravity z above -0.5, i.e. never tilted past the Arena's 60 degrees, counted per step), and the median trunk height above the 8 degree slope line (z - sin 8deg * (x - start x)) of the timed trace >= 0.9 x the untimed settle's median trunk height, and at most 10% of timed steps below 0.8 x that height. calibrated on the live board 2026-11-08: the reference is clean on 25 of 25 starts.

## PART B verdict (headline = the best pick over the 3 headline runs; frozen constants in `hill-proof-2026-11-08.py`)

GAIN = ALL of: (1) the best headline PICK's local Arena score is at most 5.869 s (below the reference's 5.870 s at the Arena's millisecond precision); (2) the pick finishes at least 24 of the 25 CHECK starts (seeds 1-25 at the scored command); (3) at least 24 of those 25 starts are clean; (4) the mean over the 20 unscored CHECK starts (seeds 6-25), which the pick never saw, is at most 5.872 s (the reference's own, measured 2026-11-08, 25-start run: finishes 25/25, mean 5.872 s).
HACK CAUGHT = no GAIN, and the headline RAW best scores at most 5.869 s but is not clean or fails the 25-start finish count (the fastest 5/5 beats the bar only by tipping or by working on the five scored starts alone). said plainly as a finding about the evaluator's blind spot, not as a result.
NO GAIN = otherwise (including no 5/5 clean checkpoint). a null is a valid, internal result; the subject of a failure is the recipe/policy (and its halved budget), never the agent (FP2).
reported only, never part of the verdict: replication (how many of hc1/hc2/hc3 meet the GAIN bar; "one seed of three" is stated as such), every per-checkpoint score (a table is kept: late drift cannot hide), the RAW best of each run with its tilt, the live board rank the headline score would take at scoring time, the reference's own 25-start CHECK, the 25-start ladder place.

## what each outcome may be called

- the board post (AUDIT HOLDS) is independent of PART B: it can ship with NO GAIN. its media shows the reference and, if PART B finishes 25/25 upright, our pick as the honest comparator; the clip shows no rank or place claim for our duck beyond "25-start ladder place, local, nothing entered".
- PART B GAIN: our pick is "a hair under the reference" when the margin is under 0.10 s, otherwise "beats"; replicated only if >= 2 of 3 headline seeds meet the bar. never "first", "best", a claim that a real duck could climb it, a rank claim from another date, or a sentence about beating named players. an Arena entry is its own operator yes and passes `--code-url` on the FIRST entry; the branch commit must be on the notwitcheer fork first (a separate gated push).
- HACK CAUGHT / NO GAIN: internal, TG/repo at most; no X as a result.

## clip (09z33, best effort, never changes a verdict)

the Arena's own recorder (`arena clip`, headless Chromium on CPU, no card), three runs each in its own LOCAL store with neutral labels (`board-row`, `ours`; the Arena draws "@<store user>"): (1) the audit's hero row (best-ranked FRAGILE row) on the Arena's own replay start, (2) the same file on the first unscored start it fails, (3) our pick on its replay start. cut by `hill_render.py` (~55 s, 1920x1080, 25 fps): an 8 s result card FIRST (title = the audit finding in plain words, big numbers for the board top 10 / the reference / our pick, a grey "how it was measured" line under each row, a footer with the tested claim and limits), the hero row winning at 0.25x with a big sim clock, the same file tipping over on the unscored start at 0.25x ("TIPPED OVER" stamp; the Arena's VICTORY and place bar are cut off), our pick at real speed beside the reference's time, then the 30-bar ladder of unscored finishes. the Arena's tiny corner timer and its REC line are masked; no path, hostname, board user or policy name is drawn. mock-rendered from the live board's rank-1 and rank-117 files before staging.

## sizing and slot

GPU smoke 2026-11-08 09:24-09:26 CET (flock'd, rule-3 checked, never counted): 4096 envs, 40 it, rc 0, **2.30 s/it steady, 17,910 MiB peak** (the box was CPU-loaded by sibling jobs). 3 runs x (1500 x 2.30 s + ~40 s start) = ~179 min plus ~2 min preflight/drain/restore = ~181 min of card (ESTIMATE until a full run: the task's curricula at it 500/750/1000/1250/1500 were not reached by the 40-it smoke). the proof item is CPU: export + score of 18 checkpoints, 3 picks + raw + reference CHECK (~8 min) + the board audit (133 files, ~15 min, a few seconds of network each) + the clip (~15 min on a loaded box). no gate: Sunday is heures creuses all day, weekend blocks never yield.

## frozen files (sha256 at freeze; the same bytes sit on capsule and in `FROZEN.sha256`)

see `FROZEN.sha256` (09z32, 09z33, `hill-train-body.sh`, `hill-runs-09z32.sh`, `hill-proof-2026-11-08.py`, `hill-judge.py`, the clone's `challenge.toml` and `env.py`, the Pollen reference `policy.onnx`). NOT frozen (presentation, may be fixed after the run with a README line, as for the Ripple and roller cuts): `hill_render.py`, `clip-hill-2026-11-08.sh`, `hill-store-run.py`. the card text is regenerated from `facts-<tag>.json` at posting time.

## AMENDMENT 1 (2026-11-08 ~10:45 CET, before any counted output: no 09z32 training had started)

the mock render's first line 1 said "finish none of 20" for the 25 fragile rows; the dev data (this file, section "what the board's top is") shows 23 of the top 30 finish none and two finish 2 and 4 of 20, so "none" was wrong for 2 of 25. the line-1 rule above now says "fewer than half of 20" with the exact "[Z] of them finish none" clause. nothing else changed: thresholds (FRAGILE < 10 of 20, HOLDS >= 10 of 30), GAIN bar and pick rule are as first frozen. the frozen hashes were re-taken after this edit.
