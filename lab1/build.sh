#!/bin/sh

# build COM module
nasm LAB1.S -fbin -o LAB1.COM
# build EXE module
nasm -fobj LAB1EXE.S -o LAB1.OBJ

# copy everything to DOSBOX mounted directory
rm -f ../workdir/LAB1.COM || true
rm -f ../workdir/LAB1.OBJ || true
rm -f ../workdir/LAB1.EXE || true
cp LAB1.COM ../workdir/
cp LAB1.OBJ ../workdir/
