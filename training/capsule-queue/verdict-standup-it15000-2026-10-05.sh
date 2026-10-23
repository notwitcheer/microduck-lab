OUT=/home/witcheer/Pollen/clips/verdict-standup-it15000-2026-10-05
TASK=Mjlab-StandUp-Flat-MicroDuck
. /home/witcheer/Pollen/proof-common.sh
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
for ck in /home/witcheer/Pollen/microduck_rl/logs/rsl_rl/duckstandup/2026-09-17_14-10-19_duckstandup/model_15000.pt; do
  for i in 1 2 3 4 5; do play it15000-face_up-t$i $TASK $ck 600 $C --spawn face_up; done
done
echo "=== END ==="
python3 /home/witcheer/Pollen/proof-verdicts.py $OUT --end 11.9 --rise
