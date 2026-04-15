@echo off
setlocal
title Mishon Flutter Web

for %%I in ("%~dp0..") do set "ROOT_DIR=%%~fI"
set "FLUTTER_DIR=%ROOT_DIR%\mishon_app"

if not defined API_BASE_URL set "API_BASE_URL=http://localhost:8081/api"
if not defined FLUTTER_WEB_PORT set "FLUTTER_WEB_PORT=3000"
if not defined FLUTTER_WEB_DEVICE set "FLUTTER_WEB_DEVICE=chrome"

echo.
echo [Mishon] Starting Flutter Web...
echo [Mishon] Folder: %FLUTTER_DIR%
echo [Mishon] API:    %API_BASE_URL%
echo [Mishon] Port:   %FLUTTER_WEB_PORT%
echo [Mishon] Device: %FLUTTER_WEB_DEVICE%
echo.

pushd "%FLUTTER_DIR%" || (
  echo [ERROR] Could not open Flutter folder.
  pause
  exit /b 1
)

flutter run -d %FLUTTER_WEB_DEVICE% --web-port %FLUTTER_WEB_PORT% --dart-define=API_BASE_URL=%API_BASE_URL%
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] Flutter Web stopped with exit code %EXIT_CODE%.
  echo [INFO] Check Flutter, Chrome device availability, and API_BASE_URL.
  pause
)

exit /b %EXIT_CODE%
