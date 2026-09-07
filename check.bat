@echo off
:: Reports what is installed. Changes nothing. Use this to survey V915
:: before a class.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Check %*
echo.
pause
