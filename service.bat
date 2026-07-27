@echo off
set "LOCAL_VERSION=2.0.1"
set "SERVICE=winws2"
set "LEGACY_SERVICE=zapret2-youtube-discord"
set "SERVICE_DISPLAY=zapret2 YouTube Discord"
set "PROFILE_VALUE=Profile"

if /i "%~1"=="admin" goto elevated

call :check_extracted
if errorlevel 1 exit /b 1
where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] powershell.exe not found in PATH.
    pause
    exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator rights...
    powershell.exe -NoProfile -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/d /c ""%~f0" admin"' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b
)

:elevated
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%

:menu
call :get_profile_name
cls
echo.
echo   ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%
if defined CurrentProfile echo   !CurrentProfile!
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
call :check_service_owner
if errorlevel 1 (
    echo Refusing to replace a winws2 service owned by another installation.
    pause
    goto menu
)
set "PROFILE_PATH="
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
set "PROFILE_PATH=%~dp0!PROFILE_REL!"
if not exist "!PROFILE_PATH!" (
    echo Profile not found: !PROFILE_PATH!
    pause
    goto menu
)
for %%F in ("!PROFILE_PATH!") do set "PROFILE_NAME=%%~nxF"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\prepare-service-profile.ps1" -ProfilePath "!PROFILE_PATH!" -OutputPath "%~dp0tools\service-next.txt" >nul
if errorlevel 1 (
    echo Failed to prepare the Zapret2 service profile.
    pause
    goto menu
)

call :remove_legacy_quiet
call :remove_quiet
if errorlevel 1 (
    if exist "%~dp0tools\service-next.txt" del /f /q "%~dp0tools\service-next.txt" >nul 2>&1
    echo Failed to remove the existing service. The old configuration was preserved.
    pause
    goto menu
)
move /y "%~dp0tools\service-next.txt" "%~dp0tools\service-active.txt" >nul
if errorlevel 1 (
    echo Failed to activate the prepared service profile.
    pause
    goto menu
)

set "SERVICE_BIN=\"%~dp0bin\winws2.exe\" @\"%~dp0tools\service-active.txt\""
sc create "%SERVICE%" binPath= "!SERVICE_BIN!" DisplayName= "%SERVICE_DISPLAY%" start= auto
if errorlevel 1 (
    echo Failed to create service.
    pause
    goto menu
)
sc description "%SERVICE%" "Zapret2 DPI bypass with a selectable Lua profile" >nul
reg add "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v "%PROFILE_VALUE%" /t REG_SZ /d "!PROFILE_REL!" /f >nul
sc start "%SERVICE%"
if errorlevel 1 (
    echo Service was created but failed to start.
    sc query "%SERVICE%"
) else (
    echo Service installed and started with !PROFILE_NAME!.
)
pause
goto menu

:service_remove
cls
call :remove_quiet
if errorlevel 1 (
    echo Failed to remove service. Runtime profile was preserved.
    pause
    goto menu
)
if exist "%~dp0tools\service-active.txt" del /f /q "%~dp0tools\service-active.txt" >nul 2>&1
echo Service removed.
pause
goto menu

:remove_quiet
sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 0
call :check_service_owner
if errorlevel 1 exit /b 1
sc stop "%SERVICE%" >nul 2>&1
for /l %%N in (1,1,20) do (
    sc query "%SERVICE%" 2>nul | findstr /I "STOP_PENDING" >nul || goto remove_delete
    timeout.exe /t 1 /nobreak >nul
)
exit /b 1
:remove_delete
sc delete "%SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 1
for /l %%N in (1,1,20) do (
    sc query "%SERVICE%" >nul 2>&1
    if errorlevel 1 exit /b 0
    timeout.exe /t 1 /nobreak >nul
)
exit /b 1

:remove_legacy_quiet
sc query "%LEGACY_SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 0
sc stop "%LEGACY_SERVICE%" >nul 2>&1
sc delete "%LEGACY_SERVICE%" >nul 2>&1
exit /b 0

:check_service_owner
sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 0
set "SERVICE_IMAGE="
for /f "tokens=2,*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v ImagePath 2^>nul ^| %SystemRoot%\System32\findstr.exe /L /I /C:"ImagePath"') do set "SERVICE_IMAGE=%%B"
if not defined SERVICE_IMAGE exit /b 1
echo(!SERVICE_IMAGE!| %SystemRoot%\System32\findstr.exe /L /I /C:"%~dp0bin\winws2.exe" >nul
if errorlevel 1 exit /b 1
exit /b 0

:service_start
cls
sc start "%SERVICE%"
pause
goto menu

:service_stop
cls
sc stop "%SERVICE%"
pause
goto menu

:service_status
cls
sc query "%SERVICE%"
echo.
for /f "tokens=2,*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v "%PROFILE_VALUE%" 2^>nul ^| %SystemRoot%\System32\findstr.exe /L /I /C:"%PROFILE_VALUE%"') do echo Active profile: %%B
echo.
tasklist /FI "IMAGENAME eq winws2.exe"
pause
goto menu

:stop_manual
cls
set "STOPPED_MANUAL=0"
for /f "delims=" %%N in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\stop-manual-winws2.ps1" 2^>nul') do set "STOPPED_MANUAL=%%N"
if "!STOPPED_MANUAL!"=="0" (echo No manual winws2.exe from this bundle is running.) else (echo Stopped !STOPPED_MANUAL! manual winws2.exe process(es).)
pause
goto menu

:get_profile_name
set "CurrentProfile="
for /f "tokens=2,*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v "%PROFILE_VALUE%" 2^>nul') do set "CurrentProfile=Profile: %%B"
exit /b

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
exit /b 0
