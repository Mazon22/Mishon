@echo off
setlocal
title Mishon Run All

set "SCRIPT_DIR=%~dp0"

echo.
echo [Mishon] Starting all local services...
echo [Mishon] Backend:      http://localhost:8081
echo [Mishon] Web site:     http://localhost:5173
echo [Mishon] Flutter Web:  http://localhost:3000
echo.

start "Mishon Go Backend" cmd /k call "%SCRIPT_DIR%run-backend-go.bat"
timeout /t 1 /nobreak >nul
start "Mishon Web Site" cmd /k call "%SCRIPT_DIR%run-web-site.bat"
timeout /t 1 /nobreak >nul
start "Mishon Flutter Web" cmd /k call "%SCRIPT_DIR%run-flutter-web.bat"

echo [Mishon] All start commands were sent in separate windows.
echo [Mishon] Close this window or press any key to continue.
pause >nul
