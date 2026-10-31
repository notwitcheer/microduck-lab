# arena-talent: Hermes Agent choreographs a MicroDuck Got a Talent act (simulation only)

Pollen Robotics' [MicroDuck Arena](https://huggingface.co/spaces/pollen-robotics/microduck-arena) has an event called Got a Talent:
a 20 second performance on an open stage, judged by public vote. A performance is a `timeline.json` (when the duck sits or
stands, where its head looks, when it quacks, wheees or sings) played by a policy. This folder is the part that turns one plain
sentence into that file with Hermes Agent, and checks it on the Arena's own stage.

Everything here is simulation. Nothing was tested on a real Microduck.

## what is in here

- `../microduck-talent-act/`: the Hermes skill (`SKILL.md`) and its tool (`scripts/talent_tool.py`).
  - `talent_tool.py check FILE` is the Arena's `timeline.json` rules (version 1 and the 8-duck version 2) in stdlib Python, plus
    warnings for what the policy was trained on, plus an act sheet (what is heard when). It was tested against the Arena's own
    loader (`arena/timeline.py` of `pollen-robotics/microduck-arena` at `bbddfe5`) on 45 files, valid and broken: no disagreement.
  - `talent_tool.py stage FILE` copies the file to a box that has the Arena installed and plays it there with a policy, then prints
    per posture and head hold whether the duck got there (`TALENT_STAGE_HOST` = ssh host, `TALENT_STAGE_DIR` = its folder).
- `talent_stage_report.py`: the box-side half of `stage` (uses `arena.evaluate`, the same call an entry is scored with).
- `talent_probe.py`, `talent_reach.py`, `talent_axes2.py`: the measurements behind the numbers in the skill (how fast the duck can flip,
  how far each head joint really goes, which way positive `head_pitch` looks).
- `talent_pick.py`: picks the checkpoint to enter, with a rule written before any of our checkpoints was judged.
- `acts/take1/`, `acts/take2/`, `acts/take3/`: the acts Hermes Agent wrote from seven plain sentences (timelines verbatim), see below.
- `talent-render.sh`, `talent-edit.py`, `w09zt3-render.sh`, `setup-arena-talent.sh`, `talent_trace_head.py`: clip rendering, the caption edit, the box setup and a head-motion measure.
- `../../training/capsule-queue/09zt3-duck-talent.sh`: the training item (Pollen's recipe as is, 4096 envs, 3000 iterations, seed 1), with `talent-probe-2026-10-27.sh` (pace probe) and `e2e-talent-2026-10-27.sh` (short end to end run of the same item).

## set up the stage box (once)

```bash
mkdir -p ~/arena-talent && cd ~/arena-talent
git clone https://github.com/pollen-robotics/microduck-challenges.git && git -C microduck-challenges checkout 4b675eb
cd microduck-challenges && uv sync --group workshop          # Python 3.12, installs the Arena 0.6.0 wheel
uv run hf download pollen-robotics/microduck-got-a-talent-reference policy.onnx timeline.json --local-dir logs/reference/got-a-talent
cp /path/to/talent_stage_report.py ..                        # next to microduck-challenges
```

Clips use the Arena's own recorder: `uv run arena score <onnx> --event got-a-talent --timeline <file> --user <you> --name <act> --store <dir>`
then `uv run arena clip <run id> --store <dir>` (headless Chromium + ffmpeg; `CHROME=` names the browser, `ffmpeg` must be on PATH).

## run it with Hermes Agent

```bash
cp -r hermes/microduck-talent-act ~/.hermes/skills/robotics/
TALENT_STAGE_HOST=<ssh host> hermes chat -q "do a dramatic opera death scene" -s microduck-talent-act -t terminal,file
```

The only thing typed is the sentence. The skill carries the schema, the duck's limits (measured) and the workflow:
write the file, `check`, `stage`, fix what the stage flags, answer with a title and a few timed lines.

## the acts Hermes wrote (Pollen's reference policy, one start)

Seven sentences, 17 runs, all kept (transcripts and per-run files: dataset `witcheer/microduck-hermes-runs`). The first five sentences ran
three times because the skill grew between takes: take 1 had the schema, the limits and the workflow; take 2 added the Arena's fixed
camera cycle (the stage films the duck close up only in performance seconds 0 to 7.5 and 10.5 to 14.5, from the side at 7.5 to 10.5
and from far away after 14.5 s, read from `app/src/talent-stage.js` and checked on the clip's own timer); take 3 added that a
performance does not have to run the full 20 seconds, so an act can end inside the close shots. Sentences 6 and 7 only ran as take 3.
`acts/take1/`, `acts/take2/`, `acts/take3/` hold the final timelines, verbatim.

| sentence | take 3 file | what the act does (Hermes's own summary) | stage, reference policy |
| --- | --- | --- | --- |
| do a dramatic opera death scene | `opera-death` | sings an ascending aria, collapses into a sit, a false recovery with a held fortissimo note, a second collapse, one quack and a closed-beak hum | all moves landed |
| a stand-up comedy set where the duck heckles itself | `self-heckle` | the head turns between two directions to play comedian and heckler, with quacks as laughter | all moves landed |
| a nervous job interview where the duck desperately wants the job | `interview` | sits, glances at the panel, pops up too keen, trembles in the side view, stands to sing a rising plea, collapses | all moves landed |
| an overenthusiastic aerobics instructor leading a class of one | `aerobics` | a sung count (five, six, seven, eight), two squats with a wheee on the way up, a double take at the missing student | all moves landed |
| eight ducks do a mexican wave, and one of them keeps missing its turn | `wobbly-wave` (`gen.py` wrote it) | eight ducks stand in turn, duck 5 is late | all 8 ducks landed |
| a death metal concert where the duck headbangs through the whole set | `death-metal-headbang` (`gen_metal.py` wrote it) | four quacks as a count-in, a headbang every 0.5 s over a low riff, a sit-down breakdown, a head windmill with a long wheee, a last quack | all moves landed |
| a wedding proposal that goes terribly wrong | `proposal` | kneels (sits), sings a rising love song, a voice crack, a hopeful silence, a double take, a wail, a slump, a deadpan quack | all moves landed |

The stage tool checks postures and head holds, not sound: Hermes cannot hear its acts and says so in every final message. Whether an act is
funny is a judgement call, not a measurement. Hermes wrote these with `anthropic/claude-sonnet-5.5` through Nous Portal
(`hermes chat ... -s microduck-talent-act --ignore-rules --yolo`, Hermes Agent v0.22.5); the only edits to the timelines are the
ones Hermes made itself after a `check` or `stage` report.

## render a clip (the Arena's own path) and our edit

`talent-render.sh POLICY.onnx TAG act.json...` runs `arena score` and `arena clip` per act (CPU, SwiftShader, 5 to 10 minutes each
under load; `ARENA_CLIP_GPU=1` for the GPU) and then `talent-edit.py`, which keeps every pixel of the Arena's clip and adds a caption
band (the sentence, "Hermes Agent wrote this act", "simulation only: not tested on a real robot"); `DUR=<seconds>` makes a cut that
starts on the close shot and ends 1.5 s after the act. `w09zt3-render.sh` waits for the training item and renders every act on our own
policy. `setup-arena-talent.sh` is the one-off box setup (`ffmpeg` comes from `imageio-ffmpeg`, `libasound` from a local lib dir).
