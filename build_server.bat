@echo off
title TianGuan13 Rebuild
setlocal
set "ROOT=%~dp0"
set "DM=%ROOT%byond\bin\dm.exe"

echo ============================================================
echo   TianGuan13 - Recompile server code (after editing .dm)
echo   IMPORTANT: stop the server FIRST (close its window),
echo   otherwise the compile fails on locked .rsc/.dmb files.
echo ============================================================
echo.

choice /C YN /M "Server is stopped - rebuild now (Y/N)"
if errorlevel 2 exit /b 1

cd /d "%ROOT%"
"%DM%" -DCBT tgstation.dme

echo.
echo Build finished. Look for "0 errors" above, then run
echo start_server.bat to launch the new build.
pause
