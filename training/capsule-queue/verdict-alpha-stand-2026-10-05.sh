OUT=/home/witcheer/Pollen/clips/verdict-alpha-stand-2026-10-05
TASK=Mjlab-StandUp-Flat-MicroDuck
. /home/witcheer/Pollen/proof-common.sh
C="--episode-s 12 --log-every 5 --cam-world auto --cam-world-z 0.10 --cam-distance 0.8 --cam-elevation -8"
ck=/home/witcheer/Pollen/pollen-policies/alpha_stand_rebuilt.pt
for i in 1 2 3 4 5; do play as-face_up-t$i $TASK $ck 600 $C --spawn face_up; done
for sp in face_down sitting; do play as-$sp-t1 $TASK $ck 600 $C --spawn $sp; done
echo "=== END ==="
python3 /home/witcheer/Pollen/proof-verdicts.py $OUT --end 11.9 --rise
