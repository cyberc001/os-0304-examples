delete %1.obj
delete %1.exe
delete %1.bin
delete %1.com

masm.exe %1.s
link.exe %1.obj
exe2bin.exe %1.exe
rename %1.bin %1.com
