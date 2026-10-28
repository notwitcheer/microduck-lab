#!/bin/bash
# seed-through-the-condition sweep (CPU only): 3 candidate walking seeds x gale peaks and x gravities, 6 takes each.
cd $HOME/Pollen/microduck_rl
L=logs/rsl_rl
declare -A CK=( [flat]=$(ls $L/duckvelbl/2026-09-25_14-59-27_duckvelbl/model_7000.pt) [mixslope]=$(ls $L/duckvelmixslope/2026-10-22_14-18-58_duckvelmixslope/model_16000.pt) [stairs]=$(ls $L/duckvelstairs/2026-10-24_00-10-26_duckvelstairs/model_19000.pt) )
GALE=Mjlab-Velocity-Flat-Backlash-Gale-MicroDuck; MOON=Mjlab-Velocity-Flat-Backlash-Moon-MicroDuck
for s in stairs mixslope flat; do
  for pk in 2.0 3.0 4.0; do
    echo "--- $(date -u +%T) gale seed=$s peak=$pk"
    MICRODUCK_GALE_PEAK=$pk bash $HOME/Pollen/gm-takes-2026-10-28.sh sweep1 g-$s-$pk ${CK[$s]} $GALE 14 0.25 6 6
  done
done
for s in stairs mixslope flat; do
  for g in 1.62 3.71 9.81; do
    echo "--- $(date -u +%T) moon seed=$s g=$g"
    MICRODUCK_MOON_G=$g bash $HOME/Pollen/gm-takes-2026-10-28.sh sweep1 m-$s-$g ${CK[$s]} $MOON 10 0.25 6 6
  done
done
echo "SWEEP1_END $(date -u +%T)"
