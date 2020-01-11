@ECHO off
CALL build.bat
IF ERRORLEVEL 1 GOTO :error
SET /p deploy= Deploy (y/n)
IF /i %deploy% NEQ y GOTO :done
CALL deploy.bat
IF ERRORLEVEL 1 GOTO :error
GOTO :done

:error
ECHO Build/Deploy failed.
EXIT /B 1
:done
ECHO Done!