@echo off
cd /d "%~dp0"
echo ===============================
echo   DriveDesk Pro - Demo Mode

echo ===============================
node --version
if errorlevel 1 (
  echo Please install Node.js version 22.13 or newer.
  pause
  exit /b 1
)
echo Open http://127.0.0.1:3000/demo/ in your browser.
echo Login: admin@drivedesk.local / Demo@12345
node api\server.js
pause
