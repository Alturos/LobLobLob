PUSHD ..
pico8 "./tank.p8" -export "-w lob.js"
pico8 "./tank.p8" -export "lob.bin"
POPD

7z a ..\builds\lob.zip @web-build.txt
IF ERRORLEVEL 1 GOTO :error
7z a ..\builds\lob-win.zip @win-build.txt
IF ERRORLEVEL 1 GOTO :error
7z a ..\builds\lob-mac.zip @mac-build.txt
IF ERRORLEVEL 1 GOTO :error
7z a ..\builds\lob-linux.zip @linux-build.txt
IF ERRORLEVEL 1 GOTO :error
7z a ..\builds\lob-raspi.zip @raspi-build.txt
IF ERRORLEVEL 1 GOTO :error
GOTO :done

:error
EXIT /B 1

:done
