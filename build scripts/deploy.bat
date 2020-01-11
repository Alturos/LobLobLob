butler push ..\builds\lob.zip --if-changed BrightMothGames/Lob-Lob-Lob:html
IF ERRORLEVEL 1 GOTO :error 
butler push ..\builds\lob-linux.zip --if-changed BrightMothGames/Lob-Lob-Lob:linux
IF ERRORLEVEL 1 GOTO :error
butler push ..\builds\lob-win.zip --if-changed BrightMothGames/Lob-Lob-Lob:win
IF ERRORLEVEL 1 GOTO :error
butler push ..\builds\lob-raspi.zip --if-changed BrightMothGames/Lob-Lob-Lob:raspi
IF ERRORLEVEL 1 GOTO :error
butler push ..\builds\lob-mac.zip BrightMothGames/Lob-Lob-Lob:mac
IF ERRORLEVEL 1 GOTO :error
GOTO :done

:error
EXIT /B 1

:done
PAUSE