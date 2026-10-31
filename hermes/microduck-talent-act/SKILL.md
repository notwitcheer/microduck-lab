---
name: microduck-talent-act
description: "Use when asked to choreograph a MicroDuck Got a Talent act. Turns one plain sentence into a valid 20 s timeline.json, checks it and plays it on the Arena stage."
version: 0.1.0
author: witcheer
license: MIT
metadata:
  hermes:
    tags: [robotics, microduck, pollen-robotics, arena, choreography]
---

# MicroDuck Got a Talent: sentence in, performance out

You choreograph a robot duck. The user gives ONE plain sentence ("do a dramatic opera death scene"). You write a
`timeline.json`: a 20 second performance that the Microduck Arena's talent stage plays with a trained policy. The act has to
be funny or striking ON SCREEN, so design it as a show with a beginning, a turn and an ending, not a list of moves.
Simulation only: no real robot is involved.

## What the duck can do (and nothing else)

The duck stays on its spot. It cannot walk, turn its body, flap or move its legs. Per keyframe you control:

| field | meaning |
| --- | --- |
| `twist[0]` | the SIT FLAG: `1` sits, `0` stands. Only exactly 0 or 1 were seen in training. `twist[1]`, `twist[2]` and `body` do nothing: leave them out |
| `head` | `[neck_pitch, head_pitch, head_yaw, head_roll]` in radians from the default pose |
| `triggers` | `[rt, lt]`, each 0 to 1. RT quacks ONCE when it rises past 0.3 (release it below 0.3 in a later keyframe to quack again). LT goes "wheee" for as long as it stays at 0.3 or more (repeat LT in every keyframe to keep it going). The beak opens as far as the harder-pulled trigger |
| `song` | a melody beside the keyframes: `{"t": s, "note": "C5", "for": s, "dynamic": "ppp..ff", "vowel": "ah|eh|ee|oh|oo|mm"}`, `note` from C2 to C7, one voice, a note starts at or after the end of the one before, the last ends by `duration_s`. The vowel sets how far the beak opens (`mm` is a closed-beak hum). Leave a gap between notes for a rest |
| `voice` | five knobs 0 to 1 for the quack, the wheee and the song: `pitch` (low duck 110 Hz to high 620 Hz, never the song's notes), `brightness`, `buzz`, `vibrato`, `breath`. Omit a knob to keep the duck's own |

Head directions (computed from the Arena's robot model): positive `head_pitch` looks DOWN, negative looks UP; positive
`neck_pitch` pulls the head BACK, negative thrusts it FORWARD and down (a bow, a peck); positive `head_yaw` turns the head to
the duck's left (the audience's right), negative to its right; `head_roll` tilts the head sideways.

What each joint really reaches (measured on the stage with Pollen's reference policy; a command beyond it saturates):
`neck_pitch` about -1.3 to +0.7, `head_pitch` about -1.6 to +1.2, `head_yaw` about +-1.6 (follows 1:1 up to 1.2),
`head_roll` +-0.44 (the joint stop). Training itself only covered +-1.10, +-1.10, +-1.40, +-0.31: inside that is safest.

Timing, measured on the same policy: a sit takes about 0.7 to 0.8 s and a stand about 0.3 to 0.4 s. Posture flips 1.0 s apart still
land, 0.5 s apart the duck never sits. The head follows a new target in well under 0.5 s (yaw swings of 0.3 s still show).
The stage settles the duck for 0.5 s at the start, so hold the first keyframe at least 1 s. A fall is part of a performance,
but none of the commands above made this policy fall, so do not plan on one.

## The file

Single duck (version 1):

```json
{"timeline_version": 1, "duration_s": 20.0,
 "voice": {"pitch": 0.3, "vibrato": 0.8},
 "song": [{"t": 2.0, "note": "C5", "for": 0.5, "vowel": "oo"}],
 "keyframes": [
   {"t": 0.0},
   {"t": 2.0, "twist": [1, 0, 0], "head": [0, 0.4, 0.5, 0], "triggers": [1, 0]},
   {"t": 2.3, "twist": [1, 0, 0], "head": [0, 0.4, 0.5, 0]}
 ]}
```

Hard rules (the Arena refuses the file otherwise): first keyframe at `t` 0, times strictly increasing and below `duration_s`,
`duration_s` at most 20, at most 1000 keyframes, every command number within +-10. **A keyframe holds until the next one, and
a group it leaves out is ZERO, not the previous value**: to stay seated or keep the head turned you must repeat `twist` and
`head` in every keyframe. A keyframe that leaves `triggers` out releases both triggers.

A troupe (version 2, up to 8 ducks, `"ducks": [{"policy": "self", "start": {"x": 0, "y": 0, "yaw": 0}, "keyframes": [...]}]`)
is only for a sentence that asks for several ducks. `x` points to the audience (within +-1.0 m), `y` to the audience's right
(within +-1.6 m), `yaw` in degrees (0 faces the audience), starts at least 0.3 m apart. Every duck here must be `"self"`. Ducks
bump each other. When two or more ducks sing they sing a chord and vibrato, buzz and breath are heard much less.

## The camera is not yours (plan around it)

The Arena films every performance with one fixed cycle of cameras (`app/src/talent-stage.js` in `pollen-robotics/microduck-arena`),
the same on the voting page and in the social clips. In performance seconds: **0 to 3.5 s front close-up, 3.5 to 7.5 s
three-quarter close-up, 7.5 to 10.5 s side view from 3.5 m, 10.5 to 14.5 s low front close-up, then a wide crane shot from 14.5 s
to the end (6 to 8 m back, the duck is a few pixels tall)**. So the acting that has to be SEEN (sits, stands, head acting) belongs in
0 to 7.5 s and 10.5 to 14.5 s; the side view (7.5 to 10.5 s) is medium, good for a held note or a silent beat. Put the biggest
visual beat at 11 to 14 s. **`duration_s` does not have to be 20 (it is "at most 20"): an act that ends at about 14.4 s stays in
the close shots to its last frame, which is usually better than 5 s of a speck in the crane shot.** Only run past 14.5 s when the
extra seconds are carried by sound (a quack, a held note, a wheee) and not by a sit or a head move. A troupe is framed as a whole, so keep the ducks close together
(0.35 to 0.6 m apart) or they shrink to specks.
`talent_tool.py check` tags every sound with its shot and warns about a posture flip in the crane shot.

## Craft (what makes it read on screen)

- Sound is half the joke: one quack is punctuation, a wheee is joy or a fall, a sung line is the big moment. While a note
  sounds, RT and LT still open the beak but make no sound.
- Sit and stand are your only body language: a sit is a collapse, a bow, hiding or giving up; a stand is a comeback. Keep
  flips at least 1.5 s apart unless the speed IS the joke (1.0 s works).
- Head moves are acting: a slow turn then a snap, a double take (yaw one way, hold, yaw the other), a look up for the heavens,
  a bow for thanks. A hold of 0.5 s is a beat; silence for 1 to 2 s makes the next sound land.
- Repeat a move twice then break the pattern. Build to one big moment around 12 to 16 s, then a short, deadpan ending.
- Use the whole 20 s (set `duration_s` to 20) and end on a clear final pose, e.g. the bow or the collapse.

## Workflow (always)

1. Say in two lines what the act is: the premise and the beats with times. Do not ask the user questions.
2. The tools ship with this skill, in its `scripts/` folder: `${HERMES_HOME:-$HOME/.hermes}/skills/robotics/microduck-talent-act/scripts/talent_tool.py`
   (call it `TOOL` below). Write each act to `${TMPDIR:-/tmp}/talent-acts/<short-name>.json` (create the folder).
3. Run `python3 TOOL check <file>`. It prints the Arena's refusals, policy-limit warnings and an act sheet (when the duck sits,
   quacks, wheees, sings). Fix every REFUSED and every WARNING you did not choose on purpose.
4. Run `python3 TOOL stage <file>`. It plays the file on the Arena's real stage with the policy and prints, per posture and
   head hold, whether the duck got there and held it. Fix anything it marks as NOT REACHED, slow, off, or a fall (a "slow"
   sit or a head error over 0.25 rad means your timing asks too much).
5. At most 4 rounds. Then reply with: the file path, the title of the act, and 3 to 5 short lines saying what the audience
   sees and hears with timestamps, and anything the stage tool still flags. Never claim a moment works that the stage tool
   did not confirm.
