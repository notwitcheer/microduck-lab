#!/bin/bash
# sweep 2 (CPU only, n=12 per cell, 8 in parallel): walk-flat v2 gale peaks 3.0/3.5/4.0 + moon/mars/earth; stairs and mixslope gale 3.0 + moon.
cd $HOME/Pollen/microduck_rl
L=logs/rsl_rl
declare -A CK=( [flat]=$(ls $L/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt) [mixslope]=$(ls $L/duckvelmixslope/2026-10-22_14-18-58_duckvelmixslope/model_16000.pt) [stairs]=$(ls $L/duckvelstairs/2026-10-24_00-10-26_duckvelstairs/model_19000.pt) )
GALE=Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck; MOON=Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck
for pk in 3.0 3.5 4.0; do echo "--- $(date -u +%T) gale flat $pk"; MICRODUCK_GALE_PEAK=$pk bash $HOME/Pollen/gm-takes-2026-10-28.sh sweep2 g-flat-$pk ${CK[flat]} $GALE 14 0.25 12 8; done
for g in 1.62 3.71 9.81; do echo "--- $(date -u +%T) moon flat $g"; MICRODUCK_MOON_G=$g bash $HOME/Pollen/gm-takes-2026-10-28.sh sweep2 m-flat-$g ${CK[flat]} $MOON 10 0.25 12 8; done
for s in stairs mixslope; do
  echo "--- $(date -u +%T) gale $s 3.0"; MICRODUCK_GALE_PEAK=3.0 bash $HOME/Pollen/gm-takes-2026-10-28.sh sweep2 g-$s-3.0 ${CK[$s]} $GALE 14 0.25 12 8
  echo "--- $(date -u +%T) moon $s 1.62"; MICRODUCK_MOON_G=1.62 bash $HOME/Pollen/gm-takes-2026-10-28.sh sweep2 m-$s-1.62 ${CK[$s]} $MOON 10 0.25 12 8
done
echo "SWEEP2_END $(date -u +%T)"
