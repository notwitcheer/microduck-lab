#!/bin/bash
# 09z47-duck-wipeout.sh: 1,024 Microducks vs ONE kinematic spinning bar per env (wipeout, physics). the stock seed duck
# (duckvelbl model_7000, walk-flat v2, md5 d16ed76e) is NOT trained here. three pre-registered bar speeds, each 1,024 envs,
# 3 full revolutions per arm; survival = trunk z >= 0.90 x Z_STAND after the arm. PREREG.md + FROZEN.sha256 gate the PLAN phase.
# FRAMING: wipeout is physics. the duck did not learn to dodge. the subject of a failure is the policy and the sim, never Hermes Agent.
# EV: private (projected post angle and reach bracket live in the ops vault status note)
# MOJO: 1,024 walking Microducks hit a spinning bar | the one bar sweeping the whole herd | 1,024 Microducks, one spinning bar: [P]% still standing after three turns
# NOT_BEFORE: Sat 2026-11-14 00:10 CET (epoch 1794611400; the brief quoted 1794615000, which is 01:10 CET). weekend blocks never yield.
# GPU: each arm is a counted card run under flock -n /home/witcheer/.gpu-smoke.lock. DRYRUN exits before any card use.
# RESUMABLE: if the block ends mid-run, the finished arms stay on disk; the next run resumes with the missing arms only (exit 3).
set -uo pipefail
NL_TAG=duckwipe
MANIFEST=/home/witcheer/duckwipe-status.json
export MANIFEST
. /home/witcheer/night-lib.sh
export NOT_BEFORE=${NOT_BEFORE:-1794611400}
P=/home/witcheer/Pollen
W=$P/microduck_rl
OUT=$P/wipe-09z47
CKPT=$W/logs/rsl_rl/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt
PRE=$P/queue-staging/09z47-prereg
TASK=Mjlab-Velocity-Flat-Backlash-MicroDuck

nl_say "PLAN phase (DRYRUN=${DRYRUN:-0}) 09z47 duck wipeout"
if [ "${DRYRUN:-0}" = "1" ] || [ ! -f "$MANIFEST" ]; then nl_manifest_init arm-W1.5 arm-W3.0 arm-W4.5 verdict; fi

# ---- pre-registration freeze: refuse to run if any frozen file differs (the frozen set is the copy in $PRE)
if [ -f "$PRE/FROZEN.sha256" ] && (cd "$PRE" && sha256sum -c FROZEN.sha256 --quiet >/dev/null 2>&1); then
  nl_ok "pre-registration frozen (sha256 matches)"
else
  nl_fail "PREREG freeze mismatch or missing: $PRE/FROZEN.sha256"
fi
nl_check_path "$CKPT" "$PRE/wipeout_common.py" "$PRE/wipeout_count.py" "$PRE/wipe_result.py" "$PRE/wipe_card.py" "$PRE/PREREG.md"
nl_check_disk 128
# run the FROZEN copies (drift between the frozen set and what runs is what the hash guards against)
if [ "${DRYRUN:-0}" != "1" ] && [ "$NL_FAIL" = "0" ]; then
  cp "$PRE/wipeout_common.py" "$PRE/wipeout_count.py" "$W/" && cp "$PRE/wipe_result.py" "$PRE/wipe_card.py" "$P/" || nl_fail "copy of frozen files failed"
fi
nl_gate

# ---- NOT_BEFORE gate (real runs only): exit 3 in seconds, before any card use
now=$(date +%s)
if [ "$now" -lt "$NOT_BEFORE" ]; then nl_say "NOT_BEFORE not reached ($(date -d "@$NOT_BEFORE" '+%a %F %H:%M %Z')), exit 3 (resumable)"; exit 3; fi

# ---- the three counted arms (each a resumable step)
ARMS="1.5:W1.5 3.0:W3.0 4.5:W4.5"
mkdir -p "$OUT"
left=$(( $(nl_deadline_epoch) - $(date +%s) - 120 ))
[ "$left" -gt 1500 ] || { nl_say "under 25 min left in the block, not starting (resumable)"; exit 3; }

all_done=1
for arm in $ARMS; do
  speed=${arm%%:*}; tag=${arm##*:}
  JSON=$OUT/counted-$tag.json
  if [ -s "$JSON" ] && grep -q '"envs": 1024' "$JSON"; then nl_say "  $tag already counted, skip"; continue; fi
  all_done=0
  if [ "$(date +%s)" -ge "$(nl_deadline_epoch)" ]; then nl_say "hard stop reached before $tag, exit 3 (resumable)"; exit 3; fi
  t0=$(date +%s)
  nl_say "  running $tag (W=$speed rad/s) 1,024 envs under flock"
  ssh_cmd="cd $W && WIPE_W=$speed MUJOCO_GL=egl .venv/bin/python wipeout_count.py $TASK --checkpoint-file $CKPT --num-envs 1024 --label $tag --json $JSON"
  flock -n /home/witcheer/.gpu-smoke.lock bash -c "$ssh_cmd" > "$OUT/log-$tag.txt" 2>&1
  rc=$?
  nl_judge_artifact "arm-$tag" "$rc" "$JSON" "$t0" "rc=$rc" || nl_say "  $tag FAILED, see $OUT/log-$tag.txt"
done

if [ "$all_done" = 1 ]; then
  nl_say "all three arms already counted"
fi

# ---- verdict + card (CPU, after the card is released)
if [ -s "$OUT/counted-W3.0.json" ] && [ -s "$OUT/counted-W1.5.json" ] && [ -s "$OUT/counted-W4.5.json" ]; then
  python3 "$P/wipe_result.py" "$OUT" "$OUT/result-09z47.txt" && nl_say "result written: $OUT/result-09z47.txt" || { nl_mark verdict failed "result"; exit 1; }
  python3 "$P/wipe_card.py" "$OUT/result-09z47.txt" "$OUT/card-09z47.png" && nl_say "card written: $OUT/card-09z47.png" || { nl_mark verdict failed "card"; exit 1; }
  nl_mark verdict done "result-09z47.txt card-09z47.png"
  exit 0
fi
nl_say "arms incomplete, exit 3 (resumable)"
exit 3
