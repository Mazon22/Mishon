@echo off
setlocal
title Mishon Web Site

for %%I in ("%~dp0..") do set "ROOT_DIR=%%~fI"
set "WEB_DIR=%ROOT_DIR%\mishon-web"

if not defined VITE_API_URL set "VITE_API_URL=http://localhost:8081/api/v1"
if not defined WEB_SITE_PORT set "WEB_SITE_PORT=5173"

echo.
echo [Mishon] Starting web site...
echo [Mishon] Folder: %WEB_DIR%
echo [Mishon] API:    %VITE_API_URL%
echo [Mishon] Port:   %WEB_SITE_PORT% (Vite dev server expected)
echo.

pushd "%WEB_DIR%" || (
  echo [ERROR] Could not open web folder.
  pause
  exit /b 1
)

call npm run dev
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] Web site dev server stopped with exit code %EXIT_CODE%.
  echo [INFO] Check Node.js, npm install, and VITE_API_URL.
  pause
)

exit /b %EXIT_CODE%
