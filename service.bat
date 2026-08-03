@echo off
set "LOCAL_VERSION="
if exist "%~dp0version.txt" (
    for /f "usebackq delims=" %%v in ("%~dp0version.txt") do set "LOCAL_VERSION=%%v"
)
if not defined LOCAL_VERSION set "LOCAL_VERSION=unknown"
set "SERVICE_CONTROL=%~dp0tools\service-control.ps1"
set "POWERSHELL=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
set "COMSPEC_TRUSTED=C:\Windows\System32\cmd.exe"

if /i "%~1"=="admin" goto elevated

call :check_extracted
if errorlevel 1 exit /b 1
if not exist "%POWERSHELL%" (
    echo [ERROR] powershell.exe not found in PATH.
    pause
    exit /b 1
)

"%POWERSHELL%" -NoProfile -Command "if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 1 }"
if errorlevel 1 (
    echo Requesting administrator rights...
    set "ZAPRET_SERVICE_SCRIPT=%~f0"
    "%POWERSHELL%" -NoProfile -Command "$command = 'Start-Process -FilePath $env:COMSPEC_TRUSTED -ArgumentList @(''/d'',''/c'',(''""{0}"" admin'' -f $env:ZAPRET_SERVICE_SCRIPT)) -WorkingDirectory (Split-Path -LiteralPath $env:ZAPRET_SERVICE_SCRIPT) -Verb RunAs'; $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command)); & $env:POWERSHELL -NoProfile -EncodedCommand $encoded"
    exit /b
)

:elevated
setlocal EnableExtensions DisableDelayedExpansion
"%POWERSHELL%" -NoProfile -Command "if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 1 }"
if errorlevel 1 (
    echo Administrator rights are required.
    pause
    exit /b 1
)
chcp 65001 >nul
cd /d "%~dp0"
title ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%

:menu
cls
echo.
echo   ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%
echo   ----------------------------------------
echo.
echo      1. Install profile as service
echo      2. Remove service
echo      3. Start service
echo      4. Stop service
echo      5. Check status
echo      6. Stop manual winws2.exe from this bundle
echo      7. Run strategy tests
echo      0. Exit
echo.
echo    Select option (0-7):
choice.exe /C 12345670 /N
if errorlevel 8 exit /b 0
if errorlevel 7 goto run_tests
if errorlevel 6 goto stop_manual
if errorlevel 5 goto service_status
if errorlevel 4 goto service_stop
if errorlevel 3 goto service_start
if errorlevel 2 goto service_remove
if errorlevel 1 goto service_install
goto menu

:service_install
cls
set "PROFILE_REL="
echo Select a Zapret2 profile:
echo   1. General
echo   2. General ALT
echo   3. YouTube
echo   4. Discord
echo   5. Simple Fake
echo   6. Multisplit
echo   7. Fake + Multisplit
echo   8. HostFakeSplit
echo   9. Fake TLS Auto
echo   0. Back
echo Profile:
choice.exe /C 1234567890 /N
if errorlevel 10 goto menu
if errorlevel 9 goto profile_9
if errorlevel 8 goto profile_8
if errorlevel 7 goto profile_7
if errorlevel 6 goto profile_6
if errorlevel 5 goto profile_5
if errorlevel 4 goto profile_4
if errorlevel 3 goto profile_3
if errorlevel 2 goto profile_2
if errorlevel 1 goto profile_1
goto menu

:profile_1
set "PROFILE_REL=profiles\general.txt"
goto profile_selected
:profile_2
set "PROFILE_REL=profiles\general-alt.txt"
goto profile_selected
:profile_3
set "PROFILE_REL=profiles\youtube.txt"
goto profile_selected
:profile_4
set "PROFILE_REL=profiles\discord.txt"
goto profile_selected
:profile_5
set "PROFILE_REL=profiles\general-simple-fake.txt"
goto profile_selected
:profile_6
set "PROFILE_REL=profiles\general-multisplit.txt"
goto profile_selected
:profile_7
set "PROFILE_REL=profiles\general-fake-multisplit.txt"
goto profile_selected
:profile_8
set "PROFILE_REL=profiles\general-hostfakesplit.txt"
goto profile_selected
:profile_9
set "PROFILE_REL=profiles\general-fake-tls-auto.txt"

:profile_selected
if not defined PROFILE_REL (
    echo Invalid profile selection.
    pause
    goto menu
)
set "PROFILE_PATH=%~dp0%PROFILE_REL%"
if not exist "%PROFILE_PATH%" (
    echo Profile not found.
    pause
    goto menu
)
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%SERVICE_CONTROL%" -Action Install -ProfilePath "%PROFILE_PATH%" -ProfileRelative "%PROFILE_REL%"
if errorlevel 1 echo Service installation failed. The previous working configuration was preserved when possible.
pause
goto menu

:service_remove
cls
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%SERVICE_CONTROL%" -Action Remove
pause
goto menu

:service_start
cls
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%SERVICE_CONTROL%" -Action Start
pause
goto menu

:service_stop
cls
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%SERVICE_CONTROL%" -Action Stop
pause
goto menu

:service_status
cls
"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%SERVICE_CONTROL%" -Action Status
pause
goto menu

:stop_manual
cls
set "STOPPED_MANUAL=0"
for /f "delims=" %%N in ('"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\stop-manual-winws2.ps1" 2^>nul') do set "STOPPED_MANUAL=%%N"
if "%STOPPED_MANUAL%"=="0" (echo No manual winws2.exe from this bundle is running.) else (echo Stopped %STOPPED_MANUAL% manual winws2.exe processes.)
pause
goto menu

:run_tests
cls
if not exist "%~dp0tools\test-strategies.ps1" (
    echo [ERROR] tools\test-strategies.ps1 not found.
    pause
    goto menu
)
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] curl.exe is required for strategy tests.
    pause
    goto menu
)
echo Starting Zapret2 strategy tests in a separate PowerShell window...
start "Zapret2 strategy tests" "%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\test-strategies.ps1"
pause
goto menu

:check_extracted
if not exist "%~dp0bin\winws2.exe" (
    echo Zapret2 must be extracted first: bin\winws2.exe not found.
    pause
    exit /b 1
)
if not exist "%~dp0profiles\" (
    echo profiles folder not found.
    pause
    exit /b 1
)
if not exist "%~dp0tools\service-control.ps1" (
    echo tools\service-control.ps1 not found.
    pause
    exit /b 1
)
if not exist "%~dp0tools\test-strategies.ps1" (
    echo tools\test-strategies.ps1 not found.
    pause
    exit /b 1
)
exit /b 0
