# my own training conditions

five task forks of Pollen's `Mjlab-Velocity-Flat-Backlash-MicroDuck` (the walk with ±1° of gear play per servo, walk-flat v2 on the Hub). each one changes the conditions the walk trains under and nothing else. everything here ran in **simulation only**; none of it has met a real Microduck.

| file | task id | what changes against the maker's task | policy |
|---|---|---|---|
| `witcheer_velocity_step_env_cfg.py` | `Mjlab-Velocity-Flat-Backlash-Step-MicroDuck` | the plane becomes a floor with one 1.5 m platform per 4 m tile, 10 to 25 mm high, so every edge is a single step | [walk-step](https://huggingface.co/witcheer/microduck-walk-step) |
| `witcheer_velocity_slip_env_cfg.py` | `Mjlab-Velocity-Flat-Backlash-Slip-MicroDuck` | foot friction randomised over 0.2 to 1.3 instead of 0.7 to 1.3 (a slippery floor) | [walk-slip](https://huggingface.co/witcheer/microduck-walk-slip) |
| `witcheer_velocity_push_env_cfg.py` | `Mjlab-Velocity-Flat-Backlash-Push-MicroDuck` | training shoves doubled to ±0.6 m/s, same 3 to 6 s interval | trained, not on the Hub yet |
| `witcheer_velocity_slope_env_cfg.py` | `Mjlab-Velocity-Flat-Backlash-Slope-MicroDuck` | the plane becomes gentle pyramid hills, gradient 0.05 to 0.15 rise per run | [walk-slope](https://huggingface.co/witcheer/microduck-walk-slope) |
| `witcheer_velocity_mix_env_cfg.py` | `Mjlab-Velocity-Flat-Backlash-Mix-MicroDuck` | step floor + slippery feet + doubled shoves at once; imports the step, slip and push modules | [walk-mix](https://huggingface.co/witcheer/microduck-walk-mix) |

each module's docstring says exactly what it changes, why, and which height reads it depends on. the proof takes, scores and reward curves behind every policy are in the [run log dataset](https://huggingface.co/datasets/witcheer/microduck-skill-tree) (levels 1d, 1e, 1g and 1h), and each model card carries its own numbers and limits.

## register them in a microduck_rl checkout

nothing in Pollen's tree is edited except one appended import line per fork in `tasks/__init__.py`. from the root of your [microduck_rl](https://github.com/pollen-robotics/microduck_rl) checkout, with its `uv` environment:

```
T=src/mjlab_microduck/tasks
cp <this repo>/conditions/witcheer_velocity_step_env_cfg.py $T/
# import test BEFORE the line goes into __init__.py: a broken module there would break every task load
uv run python -c "import mjlab_microduck.tasks.witcheer_velocity_step_env_cfg" && echo "module import ok"
# only if that printed "module import ok":
grep -q witcheer_velocity_step_env_cfg $T/__init__.py || { cp $T/__init__.py $T/__init__.py.bak-step; printf '\nfrom . import witcheer_velocity_step_env_cfg  # noqa: E402,F401\n' >> $T/__init__.py; }
uv run python -c "import mjlab_microduck.tasks; from mjlab.tasks.registry import list_tasks; print('Mjlab-Velocity-Flat-Backlash-Step-MicroDuck' in list_tasks())"
```

repeat with `slip`, `push`, `slope` and `mix` in place of `step` (module `witcheer_velocity_<name>_env_cfg`, task id from the table). install `step`, `slip` and `push` before `mix`, because the mix module imports them. the grep makes a second run a no-op; to undo, copy the `.bak` back and delete the module file.

a quick check that a fork changed only what it says: dump the base task's resolved config before and after registering and compare.

```
uv run python - <<'EOF'
import hashlib, re
import mjlab_microduck.tasks
from mjlab.tasks.registry import load_env_cfg
r = re.sub(r" at 0x[0-9a-f]+", "", repr(load_env_cfg("Mjlab-Velocity-Flat-Backlash-MicroDuck")))
print(hashlib.md5(r.encode()).hexdigest())
EOF
```

use md5 of the address-stripped repr, not python's `hash()`, which is salted per process.

## height reads on generated floors (step, slope, mix)

the step, slope and mix forks swap the maker's plane for a generated floor. on generated terrain the env origin sits on a platform or hill top, so any `root_z - env_origin_z` height read is off by the platform height once the duck walks down. I trained these three with `patches/ground_height_patch.py` applied (see the top README, section 3): it makes those reads use the ground under the feet. it runs on its own, it does not need the rest of the patch chain. slip and push keep the plane and do not need it.

## train

same commands as `training/README.md`, with the fork's task id. step, slip, push and slope were warm-started from my walk-flat v2 checkpoint (`model_7000`) with 3,000 more iterations; mix from walk-step (`model_10000`), also 3,000 more. 4096 envs on one GPU.

## play overrides for proof takes

each fork reads one or two environment variables at process start, so a proof take can force the hardest case (or a flat control on the same layout) for the fork and for the policy it is compared against. unset, the training values apply.

| variable | fork | example |
|---|---|---|
| `MICRODUCK_STEP_HEIGHT=lo,hi` (metres) | step, mix | `0.025,0.025` = tallest step, `0.001,0.001` = flat on the same layout |
| `MICRODUCK_FOOT_FRICTION=lo,hi` | slip, mix | `0.2,0.2` = slipperiest |
| `MICRODUCK_PUSH_SCALE=s` | push, mix | `1.0` = the maker's ±0.3 m/s |
| `MICRODUCK_PUSH_INTERVAL=lo,hi` (seconds) | push, mix | `3,6` = the training cadence in play |
| `MICRODUCK_SLOPE=lo,hi` (rise per run) | slope | `0.15,0.15` = steepest hill |

my step, push, slope and mix takes ran `tools/headless_play.py` with `--cmd-vx 0.3` (straight ahead, so the duck actually reaches the step or the slope); the slope and mix takes also ran with `--no-bounds`. a generated floor brings mjlab's `out_of_terrain_bounds` termination with it, and a 1-env take spawns in an edge tile, so an upright duck can be reset after a metre or two and score as a fall. I added the flag after the step takes, where it cost a few of them; the walk-step card counts those conservatively.
