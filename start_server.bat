@echo off
title TianGuan13 Server
setlocal
set "ROOT=%~dp0"
set "DD=%ROOT%byond\bin\dreamdaemon.exe"
set "DMB=%ROOT%tgstation.dmb"
set "PORT=1337"

if not exist "%ROOT%data" mkdir "%ROOT%data"

echo ============================================================
echo   TianGuan13 - Chinese SS13 private server (out-of-box)
echo   Connect on THIS machine:  byond://127.0.0.1:%PORT%
echo   Connect from LAN:         byond://^<this PC's LAN IP^>:%PORT%
echo   You get admin automatically when connecting locally
echo   (ENABLE_LOCALHOST_RANK in config\config.txt).
echo   Other players need admin: run setup_admin.bat first.
echo   To stop the server: close this window.
echo ============================================================
echo.

:start
echo [%date% %time%] Starting DreamDaemon (trusted mode)...
"%DD%" "%DMB%" -port %PORT% -trusted -log "%ROOT%data\server.log" -verbose
echo.
echo [%date% %time%] Server stopped (exit code %ERRORLEVEL%).
echo.

choice /C RQ /M "Press R to restart, Q to quit"
if errorlevel 2 goto end
goto start

:end
pause
