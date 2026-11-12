# 09z47 duck wipeout: pre-registration (frozen before any counted output)

Question: does a stock walking Microduck stay upright when a kinematic spinning bar sweeps the env?
Subject of a failure: the policy (model_7000 of duckvelbl, walk-flat v2) and the sim, never Hermes Agent.
Framing: wipeout is physics. The duck did not learn to dodge; no policy is trained here.

Arms (one per W, all 1,024 envs, same seed for the spawn grid):
- W1 = 1.5 rad/s, W2 = 3.0 rad/s, W3 = 4.5 rad/s (bar tip 0.45 / 0.90 / 1.35 m/s)
- Policy: duckvelbl model_7000.pt, md5 d16ed76e, no training, no curriculum.
- Terminations off. Forward command forced to 0.25 m/s. Pushes off. Duck spawns at env origin, yaw 0.
- Bar: one kinematic box per env, 0.60 m x 0.04 m x 0.04 m, pivot 0.50 m ahead of the env origin, centre z 0.05 m,
  yaw = W * t + pi/2 (bar across the duck's path at t = 0), mocap-written each policy step.
- Duration: 3 full revolutions per arm = 6pi/W s (arms: 12.6 s, 6.3 s, 4.2 s).

Survival (per env, counted at the end of the arm):
- trunk root z >= 0.90 x Z_STAND, Z_STAND = 0.1197 m (seed walk-flat v2, stock walk).
- Threshold = 0.1077 m.

Verdict words and the rule that builds line 1:
- Let P = the pct standing for the arm that the operator headline is built on = W2 (3.0 rad/s, middle setting).
- Line 1 (exact): "1,024 Microducks, one spinning bar: [P]% still standing after three turns"
  with P = round(100 * standing / 1024, 1) read from the W2 RESULT line.
- Verdict words (all three arms reported, none dropped): a survival >= 90% at W2 is "mostly stood"; 50-90% is
  "partly held"; < 50% is "mostly fell". A null (all arms >= 95%) is a valid result: "the bar did not knock them over".
- If a result line is missing or the count is not 1,024, the arm is reported as failed and the headline is withheld.

Contact (tunnelling check, reported not counted): bar-duck contact steps per arm (contact_envs, contact_steps_med/max).
Tunnelling is a finding if an arm shows z dropping to the floor with zero contact steps (not expected at these speeds).

Pre-counted smoke (NOT counted, slug -smoke, shown only as a sanity check):
- CPU 64 envs at W1.5: 63/64 standing (98.4%), 49/64 envs with contact. Run before this freeze, not evidence.
  Config note: this CPU smoke ran with the default env spacing (ENV_SPACING was added after it). The counted arms use 1.2 m.
- GPU 1,024 envs at W3.0: 1010/1024 standing (98.6%), 704/1024 envs with contact. Run before this freeze, not evidence.
  These smokes ran BEFORE the freeze and the pct counts are now known; the frozen headline stays the W2 count from the counted run.

Disclosure: the W2 headline is one run of 1,024 envs with one seed. Standard error on pct ~ sqrt(p(1-p)/1024) ~ 1.5 pp at p=0.5.
