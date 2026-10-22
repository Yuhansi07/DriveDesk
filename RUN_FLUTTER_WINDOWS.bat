@echo off
setlocal
cd /d "%~dp0flutter_app"
where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter SDK not found in PATH. Install Flutter and restart terminal.
  echo Guide: https://docs.flutter.dev/install
  pause
  exit /b 1
)
if not exist "web\index.html" (
  echo Generating Flutter platform folders...
  flutter create --project-name drivedesk_pro --platforms=windows,android,web .
  if errorlevel 1 goto failed
)
echo Fetching Flutter dependencies...
flutter pub get
if errorlevel 1 goto failed
echo Starting DriveDesk Flutter frontend at http://localhost:8080
echo Make sure you already started the Node backend using START_DEMO_WINDOWS.bat
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000
if errorlevel 1 goto failed
exit /b 0
:failed
echo Setup or launch failed. Review the error above.
pause
exit /b 1
