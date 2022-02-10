## Инструкция по компиляции
В папке каждой лабораторной работы находятся два bash скрипта.
Скрипт `build.sh` отвечает за сборку лабораторной работы, и копирование получившихся файлов в папку workdir.
Скрипт `run.sh` отвечает за запуск текущей собранной лабораторной работы, которая лежит в папке workdir.

Запуск скрипта сборки генерирует рабочие файлы для .COM-модулей, которые можно запустить в dosbox.

Пример:

**в терминале:**
```bash
./build.sh
./run.sh
```
**в dosbox:**
```bash
C:\>LAB1.COM
```

Запуск скрипта сборки генерирует объектные файлы для .EXE-модулей, которые перед запуском сначала нужно обработать линковщиком.

Пример:

**в терминале:**
```bash
./build.sh
./run.sh
```
**в dosbox:**
```bash
C:\>LINK.EXE

Microsoft (R) Overlay Linker  Version 3.64
Copyright (C) Microsoft Corp 1983-1988.  All rights reserved.

Object Modules [.OBJ]: LAB1
Run File [LAB1.EXE]: LAB1
List File [NUL.MAP]:
Libraries [.LIB]:

C:\>LAB1.EXE
```
