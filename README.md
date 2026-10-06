# microduck-lab

my lab bench for the Pollen Robotics Microduck, a small two-legged robot. everything here ran in **simulation only**. my duck is on pre-order and none of this has touched a real robot yet.

three things live here:

1. **a Hermes Agent tool that drives the duck with plain sentences** (`hermes/`)
2. **the training and proof-take tools** I use to train my own policies on Pollen's open training code (`tools/`, `training/`)
3. **six patches to Pollen's rough-terrain training** that fix how height and terrain difficulty are measured (`patches/`)

the trained policies are on Hugging Face, one installable repo per skill, plus a dataset with every run's reward curve and proof takes:

- collection: https://huggingface.co/collections/witcheer/microduck-skill-tree-sim-only-6ab195da0c0b293bdccc6d34
- run log dataset: https://huggingface.co/datasets/witcheer/microduck-skill-tree
- policies: [walk-flat](https://huggingface.co/witcheer/microduck-walk-flat), [walk-rough](https://huggingface.co/witcheer/microduck-walk-rough), [walk-recover](https://huggingface.co/witcheer/microduck-walk-recover), [walk-recover-rough](https://huggingface.co/witcheer/microduck-walk-recover-rough), [standup](https://huggingface.co/witcheer/microduck-standup), [roulade](https://huggingface.co/witcheer/microduck-roulade), [kick-right](https://huggingface.co/witcheer/microduck-kick-right)

each model card carries its own training numbers, proof-take results and limits.

## 1. the Hermes Agent tool

`hermes/duck-intents.py` is a stdlib-only client for the duck's daemon, `robotd`. it talks to the same unix socket a real duck serves (`/run/robotd.sock`) or the simulator's (`~/.cache/duck-sim/duck.sock`), and with `--ssh-host` it reaches a remote socket through an ssh tunnel. it sends **intents only**: it never touches the servo bus, `robotd` and its safety layer decide what the motors do.

```
python3 hermes/duck-intents.py health
python3 hermes/duck-intents.py stand
python3 hermes/duck-intents.py walk --vx 0.3 --seconds 3
python3 hermes/duck-intents.py look --yaw 0.4 --pitch -0.2
python3 hermes/duck-intents.py stop
```

the client refuses speeds outside the range the walking policy was trained on (`--vx` ±0.4 m/s, `--vy` ±0.3 m/s, `--vyaw` ±1.0 rad/s) with exit code 2, because `robotd` itself does not clamp them (see `docs/wire-contract.md`).

`hermes/microduck-sim/SKILL.md` is the matching Hermes Agent skill. Hermes keeps skills in `~/.hermes/skills/` ([docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills)), so copy the folder there and change the command path inside it to where you keep `duck-intents.py`. then a sentence like "stand up, walk forward for three seconds and tell me how far you went" becomes a sequence of these commands.

`docs/wire-contract.md` is the `robotd` JSON-RPC contract as the tool needs it, every line cited to a file and line in `pollen-robotics/microduck` at commit 6507d2e, plus the sim run that proved each command.

## 2. training and proof takes

the policies were trained with Pollen's [microduck_rl](https://github.com/pollen-robotics/microduck_rl) (mjlab + rsl_rl) on one GPU, one Pollen task id per skill. `training/README.md` has the exact resume, export and publish commands.

- `tools/headless_play.py`: records any checkpoint of any task to mp4 over ssh, no display. adds camera flags, forced spawn states (`--spawn face_up|face_down|sitting|standing`, plus Roulade's own spawn event), `--episode-s`, 0.1 s sampling (`--log-every 5`) and a `RESET at t=` line whenever the env resets mid-clip. copy it into your microduck_rl checkout and run it with `uv run python`.
- `tools/proof-verdicts.py`, `tools/take-verdicts.py`: score a folder of take logs from the logged trunk height and body-frame gravity (rise time, falls, resets), not from looking at frames.
- `tools/onnx2ckpt.py`: rebuilds an rsl_rl checkpoint from one of Pollen's shipped ONNX policies, so it can be played in the training env or used as a distillation expert. it prints the max difference against onnxruntime, which should be about 1e-5.

two lessons that cost me the most time, both visible in the take logs on the dataset:

- a skill claim needs a **forced** spawn. a random spawn "on the back" can start up to 90° rolled onto its side, and rolling over from there looks like getting up from the back.
- a termination mid-clip is a teleport. VelStand resets a duck that stays down for 8 s, and in the trunk-height series that reset reads exactly like a recovery. count only rises with intermediate heights and no `RESET` line inside the window.

## 3. patches to the rough-terrain training

Pollen's rough tasks measure every height as `root_z - env_origin_z`. on pyramid stairs and slopes the env origin sits on the top platform, so an upright duck a few steps down counts as fallen and gets reset 8 s later. the rough terrain also runs in random mode (mjlab's default), so its "levels" are not ordered by difficulty.

run them **once, in this order**, on a clean checkout, with `MICRODUCK_RL` pointing at it:

```
export MICRODUCK_RL=$HOME/microduck_rl
python3 patches/terrain_tracking_patch.py
python3 patches/terrain_tracking_patch2.py
python3 patches/ground_height_patch.py
python3 patches/terrain_demote_arms_patch.py
python3 patches/terrain_prone_neutral_patch.py
python3 patches/terrain_curriculum_mode_patch.py
```

- `ground_height_patch.py`: height against the ground under the feet (mean of the foot height-scan ray hits) on generated terrain; flat tasks and tasks without the foot sensor compute exactly what they did before.
- `terrain_tracking_patch.py` + `terrain_tracking_patch2.py`: a terrain curriculum that promotes and demotes on velocity tracking and episode survival instead of distance walked (the stock rule needs 4 m of drift, which a 0.4 m/s robot with commands that change direction every few seconds almost never reaches).
- `terrain_prone_neutral_patch.py`: episodes that start lying down do not move the terrain level (a failed get-up is a short episode and would demote whatever the terrain).
- `terrain_curriculum_mode_patch.py`: an ordered 10 × 20 difficulty ladder for the velocity family's rough tasks, on its own copy of the terrain config.
- `terrain_demote_arms_patch.py`: logging only, splits the demote rate by which rule fired.

each writes a `*.bak-*` backup on first run and refuses to run twice. to start over, `git checkout` `mdp.py` and `microduck_velocity_env_cfg.py` and run the chain again. they trained my walk-recover-rough policy on Pollen's `main` at 53b8971. on their `soft_carpet` branch at 695f3b7 I compared the task configs before and after: the flat VelStand tasks are identical, and the rough one changes only in the terrain curriculum.

## credits and licence

the robot, `robotd`, the simulator and the training code are Pollen Robotics' work ([microduck](https://github.com/pollen-robotics/microduck), [microduck_rl](https://github.com/pollen-robotics/microduck_rl), both Apache-2.0), built on [mjlab](https://github.com/mujocolab/mjlab) (Apache-2.0). the get-up in my newest policies is distilled from Pollen's own stand expert, following their `protective_fall` branch. this repo is Apache-2.0 too.
