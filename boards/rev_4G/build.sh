#!/bin/sh
mkdir -p build

MAJ=1
MIN=14

ALL="MAINLG-DVI MAINLG-RGB"
for V in $ALL
do
   VERSION_MAJOR=${MAJ} VERSION_MINOR=${MIN} VARIANT=${V} make clean all > build/${V}.${MAJ}.${MIN}.log
   cp outflow/vicii.timing.rpt build/${V}.${MAJ}.${MIN}.rpt
done
