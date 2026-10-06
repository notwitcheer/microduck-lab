# training commands

all commands run inside a checkout of Pollen's [microduck_rl](https://github.com/pollen-robotics/microduck_rl) with its `uv` environment. one skill = one task id; list them with `mjlab.tasks.registry.list_tasks()` after `import mjlab_microduck.tasks`.

## train, with checkpoints and free clips

```
MUJOCO_GL=egl uv run train Mjlab-VelStand-Flat-MicroDuck \
  --env.scene.num-envs 4096 --agent.max-iterations 3000 --agent.save-interval 100 \
  --agent.logger tensorboard --agent.experiment-name duckvelstand --agent.run-name duckvelstand \
  --video True --video-interval 500 --video-length 300
```

`--video True` needs the explicit `True`, and `MUJOCO_GL=egl` lets it render with no display. clips land in `logs/rsl_rl/<experiment>/<run>/videos/train/`.

## resume or warm-start from another skill's checkpoint

`--agent.load-run` is resolved inside `logs/rsl_rl/<experiment-name>/`, so copy the seed checkpoint there first:

```
mkdir -p logs/rsl_rl/duckvelstandbl/seed-it20000
cp <path>/model_20000.pt logs/rsl_rl/duckvelstandbl/seed-it20000/
uv run train Mjlab-VelStand-Flat-Backlash-MicroDuck --env.scene.num-envs 4096 \
  --agent.max-iterations 3001 --agent.experiment-name duckvelstandbl --agent.run-name duckvelstandbl \
  --agent.resume True --agent.load-run seed-it20000 --agent.load-checkpoint model_20000.pt
```

a resumed run counts the loaded iteration as its first one, so 3,000 new iterations need `--agent.max-iterations 3001`. the `-Backlash-` twins add ±1° of gear play per servo, so a trained policy's checkpoint loads into its twin as-is.

I cap each new run at 3,000 iterations and extend only while the mean reward is still climbing: on my runs the curves went flat between 1,000 and 2,000 iterations on several skills.

## export

use Pollen's exporter, `scripts/export.py`:

```
uv run scripts/export.py Mjlab-VelStand-Flat-MicroDuck \
  --checkpoint-file logs/rsl_rl/duckvelstand/<run>/model_3000.pt --onnx-file walk-recover.onnx
```

## publish to Hugging Face

Pollen's own publish command writes the model card, the manifest and the ONNX in the shape `robotctl policy add` installs. always dry-run first:

```
uv run publish --onnx walk-recover.onnx --repo <you>/microduck-walk-recover --kind perpetual --slot walk \
  --description "... trained in simulation only. Not yet tested on a real Microduck." --tag v1 --dry-run
```

`--dry-run` writes the folder locally (`policy.onnx`, `manifest.json`, `README.md`) and uploads nothing. `--kind perpetual --slot walk` for gaits, `--kind episodic --duration-s <s>` for one-shot skills (stand-up, roll, kick). add `--no-private` for a public repo.

## proof takes

```
MUJOCO_GL=egl uv run python headless_play.py Mjlab-StandUp-Flat-MicroDuck \
  --checkpoint-file <model_N.pt> --num-envs 1 --video True --video-length 600 \
  --spawn face_up --episode-s 12 --log-every 5
python3 proof-verdicts.py <folder of take logs> --rise --end 11.9
```

record at least three takes per spawn state. for rough terrain add `--terrain-type`, `--terrain-level` and `--no-push`, or every take starts on a flat platform.
