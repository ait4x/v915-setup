@echo off
:: ---------------------------------------------------------------------------
::  setup.bat -- V915 tutorial machine setup.
::
::  Download this one file and double-click it. Nothing else is required: no
::  git, no PowerShell prompt, no execution-policy change.
::
::    Sitting next to setup.ps1  ->  runs it directly.
::    On its own                 ->  fetches bootstrap.ps1, which downloads the
::                                   repository to Documents\v915-setup and runs
::                                   the installer from there.
::
::  Arguments are forwarded either way:   setup.bat -Profile web
::
::  The logic deliberately lives in bootstrap.ps1 rather than being inlined
::  here. A CMD-escaped PowerShell block is unreadable and unreviewable, and
::  this file is handed to students.
:: ---------------------------------------------------------------------------

setlocal EnableExtensions

set "BOOTSTRAP_URL=https://raw.githubusercontent.com/ait4x/v915-setup/main/bootstrap.ps1"
set "BOOTSTRAP_PS1=%TEMP%\v915-bootstrap.ps1"

if not exist "%~dp0setup.ps1" goto :bootstrap

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set "EC=%ERRORLEVEL%"
goto :done

:bootstrap
echo.
echo V915 setup
echo ==========
echo setup.ps1 is not next to this file, so this is a standalone run.
echo Fetching the installer...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest '%BOOTSTRAP_URL%' -OutFile '%BOOTSTRAP_PS1%' -UseBasicParsing"

if exist "%BOOTSTRAP_PS1%" goto :run

echo.
echo ERROR: could not download the installer from
echo   %BOOTSTRAP_URL%
echo.
echo Check the network connection and try again. If this machine blocks GitHub,
echo download the repository as a zip instead, extract it, and run setup.bat
echo from inside the extracted folder.
set "EC=2"
goto :done

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%BOOTSTRAP_PS1%" %*
set "EC=%ERRORLEVEL%"
del "%BOOTSTRAP_PS1%" >nul 2>nul

:done
echo.
pause
exit /b %EC%
