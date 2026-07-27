@echo off
set "LOCAL_VERSION=2.0.2"
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
    "%POWERSHELL%" -NoProfile -Command "Start-Process -FilePath $env:COMSPEC_TRUSTED -ArgumentList @('/d','/c',(('^"{0}^" admin') -f $env:ZAPRET_SERVICE_SCRIPT)) -WorkingDirectory (Split-Path -LiteralPath $env:ZAPRET_SERVICE_SCRIPT) -Verb RunAs"
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
echo      0. Exit
echo.
set "menu_choice="
set /p "menu_choice=   Select option (0-6): "
if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_start
if "%menu_choice%"=="4" goto service_stop
if "%menu_choice%"=="5" goto service_status
if "%menu_choice%"=="6" goto stop_manual
if "%menu_choice%"=="0" exit /b 0
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
set "profile_choice="
set /p "profile_choice=Profile: "
if "%profile_choice%"=="1" set "PROFILE_REL=profiles\general.txt"
if "%profile_choice%"=="2" set "PROFILE_REL=profiles\general-alt.txt"
if "%profile_choice%"=="3" set "PROFILE_REL=profiles\youtube.txt"
if "%profile_choice%"=="4" set "PROFILE_REL=profiles\discord.txt"
if "%profile_choice%"=="5" set "PROFILE_REL=profiles\general-simple-fake.txt"
if "%profile_choice%"=="6" set "PROFILE_REL=profiles\general-multisplit.txt"
if "%profile_choice%"=="7" set "PROFILE_REL=profiles\general-fake-multisplit.txt"
if "%profile_choice%"=="8" set "PROFILE_REL=profiles\general-hostfakesplit.txt"
if "%profile_choice%"=="9" set "PROFILE_REL=profiles\general-fake-tls-auto.txt"
if "%profile_choice%"=="0" goto menu
if not defined PROFILE_REL (
    echo Invalid profile selection.
    pause
    goto menu
)
set "PROFILE_PATH=%~dp0%PROFILE_REL%"
if not exist "%PROFILE_PATH%" (
    echo Profile not found: %PROFILE_PATH%
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
if "%STOPPED_MANUAL%"=="0" (echo No manual winws2.exe from this bundle is running.) else (echo Stopped %STOPPED_MANUAL% manual winws2.exe process(es).)
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
exit /b 0
