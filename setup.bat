@echo off
:: Double-click entry point. Runs setup.ps1 with the default 'base' profile.
:: Any arguments are forwarded, so `setup.bat -Profile web` works too.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set "EC=%ERRORLEVEL%"
echo.
pause
exit /b %EC%
