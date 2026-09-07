@echo off
:: Clears the cached GitHub sign-in. Run before leaving a shared lab machine,
:: or the next person pushes to your account.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -SignOut
echo.
pause
