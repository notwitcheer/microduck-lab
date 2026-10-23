#!/bin/bash
# 09z-duck-velpay.sh: duck skill tree, "our own conditions" track (skill-tree.md side branch: "a payload on the back"), first fork
# of a walking task. task Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck = the maker's Velocity-Flat-Backlash (walk-flat v2 on the
# Hub) with ONE parameter changed: the maker's startup trunk mass DR (pseudo_inertia on trunk_base, 0.95-1.05x) widened to
# 0.95-1.30x, i.e. up to ~+60 g on a 199.2 g trunk / 737.2 g robot. module witcheer_velocity_payload_env_cfg.py (vault
# 99-personal/benchmark-rig/scripts/), registered by one appended import line (backup ~/tasks-init.py.bak-payload-2026-10-11);
# resolved-cfg repr vs the base task differs in exactly that alpha_range (install check 2026-10-11).
# WARM START: logs/rsl_rl/duckvelpay/2026-10-11_00-00-00_seed-velbl-it7000/model_7000.pt = walk-flat v2 (duckvelbl model_7000,
# md5 d16ed76e both copies), true resume (curricula on their last stage), 7000 -> 10000 (3k rule).
# why: 09x (VelStand-Rough-Backlash) and 09y (Velocity-Rough-Backlash) are the last maker twins worth training; the ladder's next
# step is conditions the maker does not train. a payload is the first a real owner hits (a camera or battery on the back).
# verdict plan: walk-flat v2 vs this policy in this env with MICRODUCK_PAYLOAD_SCALE=1.30,1.30 (heaviest) and 1.0,1.0 (none), 20 s
# takes, falls = mid RESET lines (fell_over) + tilt events, same takes per policy.
# probe 2026-10-11 (~/Pollen/probe-duck-warmstart.sh velpay, 512 envs, card shared with bench 66 + proof takes): see log.md.
# pace UNVERIFIED at 4096: estimate = walk-flat v2's 1.16-1.17 s/it (same task, same robot) -> ~59 min + export, one duck block.
SKILL=velpay
# MANIFEST duplicated from the body so the drain grep fills idleq-active.json for the sentinel
MANIFEST=/home/witcheer/duckvelpay-status.json
TASK=Mjlab-Velocity-Flat-Backlash-Payload-MicroDuck
TARGET_IT=${TARGET_IT:-10000}
. /home/witcheer/Pollen/duck-train-body.sh
