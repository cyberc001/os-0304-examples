#!/bin/sh

# build COM module
nasm LAB2.S -fbin -o LAB2.COM

# copy everything to DOSBOX mounted directory
rm -f ../workdir/LAB2.COM || true
cp LAB2.COM ../workdir/
cp LAB6.S ../workdir
