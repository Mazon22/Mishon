@echo off
setlocal
title Mishon Go Backend

for %%I in ("%~dp0..") do set "ROOT_DIR=%%~fI"
set "BACKEND_DIR=%ROOT_DIR%\mishon-go-api"

if not defined PORT set "PORT=8081"
if not defined DATABASE_URL set "DATABASE_URL=postgres://postgres:Mznz3rOoO@localhost:5432/mishon?sslmode=disable"
if not defined JWT_KEY set "JWT_KEY=replace-with-a-long-random-secret-at-least-32-characters"
if not defined JWT_ISSUER set "JWT_ISSUER=Mishon"
if not defined JWT_AUDIENCE set "JWT_AUDIENCE=MishonUsers"
if not defined JWT_EXPIRE_MINUTES set "JWT_EXPIRE_MINUTES=120"
if not defined JWT_REFRESH_DAYS set "JWT_REFRESH_DAYS=30"
if not defined CORS_ORIGINS set "CORS_ORIGINS=http://localhost:*,http://127.0.0.1:*,https://localhost:*,https://127.0.0.1:*"

echo.
echo [Mishon] Starting Go backend...
echo [Mishon] Folder: %BACKEND_DIR%
echo [Mishon] Port:   %PORT%
echo [Mishon] URL:    http://localhost:%PORT%
echo.

if "%DATABASE_URL%"=="postgres://postgres:CHANGE_ME@localhost:5432/mishon?sslmode=disable" (
  echo [WARN] DATABASE_URL still uses CHANGE_ME.
  echo [WARN] If your local PostgreSQL password is different, edit this .bat or set DATABASE_URL before launch.
  echo.
)

pushd "%BACKEND_DIR%" || (
  echo [ERROR] Could not open backend folder.
  pause
  exit /b 1
)

go run .\cmd\mishon-go-api\
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] Go backend stopped with exit code %EXIT_CODE%.
  echo [INFO] Check PostgreSQL, DATABASE_URL and JWT_KEY.
  pause
)

exit /b %EXIT_CODE%
