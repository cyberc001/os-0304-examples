#!/bin/sh

cp MLAB3_1.S ../workdir
cp MLAB3_2.S ../workdir
cp MLAB3_3.S ../workdir
cp MLAB3_4.S ../workdir

# build COM module
#nasm LAB3_1.S -fbin -o LAB3_1.COM
#nasm LAB3_2.S -fbin -o LAB3_2.COM
#nasm LAB3_3.S -fbin -o LAB3_3.COM
#nasm LAB3_4.S -fbin -o LAB3_4.COM

# copy everything to DOSBOX mounted directory
#rm -f ../workdir/LAB3_1.COM || true
#rm -f ../workdir/LAB3_2.COM || true
#rm -f ../workdir/LAB3_3.COM || true
#rm -f ../workdir/LAB3_4.COM || true
#cp LAB3_1.COM ../workdir/
#cp LAB3_2.COM ../workdir/
#cp LAB3_3.COM ../workdir/
#cp LAB3_4.COM ../workdir/
