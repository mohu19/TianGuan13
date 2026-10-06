@echo off
title TianGuan13 Add Admin
setlocal
set "ROOT=%~dp0"
set "ADMINS=%ROOT%config\admins.txt"

echo ============================================================
echo   Give a player full admin (Host rank) on this server
echo   Your BYOND account name = login name at www.byond.com
echo   (all lowercase, no spaces).
echo ============================================================
echo.

set "NAME="
set /p "NAME=BYOND account name: "
if "%NAME%"=="" echo No input, aborting. & pause & exit /b 1

findstr /C:"= Host" "%ADMINS%" >nul 2>&1
if not errorlevel 1 (
  echo.
  echo An admin line already exists in config\admins.txt.
  echo Edit that file manually if you want to change it.
  pause
  exit /b 0
)

echo.>> "%ADMINS%"
echo %NAME% = Host>> "%ADMINS%"

echo.
echo Added: %NAME% = Host
echo Restart the server (or reload admins in-game) to apply.
pause
