"""backgetup2-cfgcheck.py: print the reward/curriculum values that differ between StandUp, v1 and v2.

Resolves every weight at the RESTORED counter (the warm start's
common_step_counter), i.e. what the policy actually trains under, by applying
each reward_weight curriculum's last stage whose step <= counter.
Run from ~/Pollen/microduck_rl: uv run python backgetup2-cfgcheck.py
"""
import mjlab_microduck.tasks  # noqa: F401  (registers all ids incl. the witcheer forks)
from mjlab.tasks.registry import list_tasks, load_env_cfg

COUNTER = 28000 * 24  # >= the counter restored from model_28000 (672k); every maker stage is <= 4000*24
IDS = ["Mjlab-StandUp-Flat-MicroDuck", "Mjlab-StandUpBack-Flat-MicroDuck", "Mjlab-StandUpBack2-Flat-MicroDuck"]
TERMS = ["arrival_damping", "head_pose_bias", "joint_torque_rate_l2", "body_ang_vel", "action_rate_l2",
         "supine_turnover_progress", "upright_linear", "angular_momentum"]

print("registered:", {i: (i in list_tasks()) for i in IDS})
for tid in IDS:
    cfg = load_env_cfg(tid)
    eff = {}
    for name in TERMS:
        r = cfg.rewards.get(name)
        eff[name] = None if r is None else r.weight
    for cname, c in cfg.curriculum.items():
        p = getattr(c, "params", {}) or {}
        if "reward_name" in p and "weight_stages" in p:
            st = [s for s in p["weight_stages"] if s["step"] <= COUNTER]
            if st and p["reward_name"] in eff:
                eff[p["reward_name"]] = st[-1]["weight"]
    gs = cfg.curriculum["ground_state_mix"].params["param_stages"]
    last = [s for s in gs if s["step"] <= COUNTER][-1]["params"]
    fn = cfg.rewards["supine_turnover_progress"].func.__name__ if "supine_turnover_progress" in cfg.rewards else None
    print(f"\n{tid}")
    for k, v in eff.items():
        print(f"  {k:26s} {v}")
    print(f"  turnover func             {fn}")
    print(f"  spawn mix at counter      {last}")
