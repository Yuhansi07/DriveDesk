@echo off
setlocal
cd /d "%~dp0"
title DriveDesk Pro - Launcher
where node >nul 2>&1
if errorlevel 1 (
  echo Node.js not found. Install Node.js 22.13 or newer.
  pause
  exit /b 1
)
where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter SDK not found in PATH. Install Flutter and reopen this window.
  echo https://docs.flutter.dev/install
  pause
  exit /b 1
)
powershell -NoProfile -Command "$p=Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object {$_.LocalPort -in @(3000,8080)}; if($p){$p | Select-Object LocalPort,OwningProcess | Format-Table; exit 1} else {exit 0}"
if errorlevel 1 (
  echo A port is already in use. Close your old DriveDesk terminals first.
  echo Run CHECK_PORTS_WINDOWS.bat to see which process owns the port.
  pause
  exit /b 1
)
echo Starting DriveDesk Node API (port 3000) and Flutter Web (port 8080)...
echo If either port is already in use, close the older DriveDesk terminal first.
start "DriveDesk Pro API" /D "%~dp0" cmd /k "set ENABLE_DEMO_PAYMENTS=1&&npm start"
timeout /t 3 /nobreak >nul
start "DriveDesk Flutter Frontend" /D "%~dp0" cmd /k "call RUN_FLUTTER_WINDOWS.bat"
echo Two console windows launched. Keep them open while using the application.
echo Once Flutter finishes compiling: http://localhost:8080
echo Customer portal demo payment is SIMULATED only; no funds transferred.
echo Demo account selector contains 7 roles. Full details: docs\USER_ROLES_AND_DEMO_LOGINS.md
pause
