@echo off
set "LOCAL_VERSION=2.0.0"
set "SERVICE=winws2"
set "SERVICE_DISPLAY=zapret2 YouTube Discord"
set "PROFILE_VALUE=Profile"

if /i "%~1"=="admin" goto elevated
if /i "%~1"=="status_zapret" goto status_external

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
call :get_strategy_name
cls
echo.
echo   ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%
if defined CurrentStrategy echo   !CurrentStrategy!
echo   ----------------------------------------
echo.
echo   :: SERVICE
echo      1. Install Service
echo      2. Remove Service
echo      3. Start Service
echo      4. Stop Service
echo      5. Check Status
echo.
echo   :: TOOLS
echo      6. Run Diagnostics
echo      7. Run Strategy Tests
echo      8. Stop manual winws2.exe
echo.
echo   ----------------------------------------
echo      0. Exit
echo.
set "menu_choice="
set /p "menu_choice=   Select option (0-8): "
if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_start
if "%menu_choice%"=="4" goto service_stop
if "%menu_choice%"=="5" goto service_status
if "%menu_choice%"=="6" goto service_diagnostics
if "%menu_choice%"=="7" goto run_tests
if "%menu_choice%"=="8" goto stop_manual
if "%menu_choice%"=="0" exit /b 0
goto menu

:service_install
cls
echo Pick a Zapret2 strategy profile:
call "%~dp0tools\list-profiles.bat"
if errorlevel 1 (
    call :PrintRed "Invalid profile selection."
    pause
    goto menu
)
set "PROFILE_PATH=!SELECTED_PROFILE!"
for %%F in ("!PROFILE_PATH!") do (
    set "PROFILE_NAME=%%~nxF"
    set "PROFILE_REL=profiles\%%~nxF"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\prepare-service-profile.ps1" -ProfilePath "!PROFILE_PATH!" -OutputPath "%~dp0tools\service-next.txt" >nul
if errorlevel 1 (
    call :PrintRed "Failed to prepare the Zapret2 service profile."
    pause
    goto menu
)

call :remove_quiet
if errorlevel 1 (
    if exist "%~dp0tools\service-next.txt" del /f /q "%~dp0tools\service-next.txt" >nul 2>&1
    call :PrintRed "Failed to remove the existing service. The old configuration was preserved."
    pause
    goto menu
)
move /y "%~dp0tools\service-next.txt" "%~dp0tools\service-active.txt" >nul
if errorlevel 1 (
    call :PrintRed "Failed to activate the prepared service profile."
    pause
    goto menu
)
set "SERVICE_BIN=\"%~dp0bin\winws2.exe\" @\"%~dp0tools\service-active.txt\""
sc create "%SERVICE%" binPath= "!SERVICE_BIN!" DisplayName= "%SERVICE_DISPLAY%" start= auto
if errorlevel 1 (
    call :PrintRed "Failed to create service."
    pause
    goto menu
)
sc description "%SERVICE%" "Zapret2 DPI bypass with a selectable Lua profile" >nul
reg add "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v "%PROFILE_VALUE%" /t REG_SZ /d "!PROFILE_REL!" /f >nul
sc start "%SERVICE%"
if errorlevel 1 (
    call :PrintRed "Service was created but failed to start. Run Diagnostics."
) else (
    call :PrintGreen "Service installed and started with !PROFILE_NAME!."
)
pause
goto menu

:service_remove
cls
call :remove_quiet
if errorlevel 1 (
    call :PrintRed "Failed to remove service. Runtime profile was preserved."
    pause
    goto menu
)
if exist "%~dp0tools\service-active.txt" del /f /q "%~dp0tools\service-active.txt" >nul 2>&1
call :PrintGreen "Service removed."
pause
goto menu

:remove_quiet
sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 0
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
call :print_service_status "%SERVICE%"
call :print_service_status "WinDivert"
echo.
if exist "%~dp0bin\WinDivert64.sys" (
    call :PrintGreen "[OK] bin\WinDivert64.sys found"
) else (
    call :PrintRed "[X] bin\WinDivert64.sys not found"
)
tasklist /FI "IMAGENAME eq winws2.exe" 2>nul | find /I "winws2.exe" >nul
if errorlevel 1 (
    call :PrintYellow "[!] winws2.exe is not running"
) else (
    call :PrintGreen "[OK] winws2.exe is running"
)
for /f "tokens=2,*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v "%PROFILE_VALUE%" 2^>nul ^| find /I "%PROFILE_VALUE%"') do echo Active profile: %%B
pause
goto menu

:status_external
setlocal EnableExtensions EnableDelayedExpansion
set "SERVICE=winws2"
call :print_service_status "%SERVICE%"
exit /b

:print_service_status
set "STATUS="
for /f "tokens=3 delims=: " %%A in ('sc query "%~1" 2^>nul ^| findstr /I "STATE"') do set "STATUS=%%A"
if /i "!STATUS!"=="RUNNING" (
    call :PrintGreen "[OK] %~1 service is RUNNING"
) else if /i "!STATUS!"=="STOP_PENDING" (
    call :PrintYellow "[!] %~1 service is STOP_PENDING"
) else if defined STATUS (
    call :PrintYellow "[!] %~1 service is !STATUS!"
) else (
    call :PrintYellow "[!] %~1 service is not installed"
)
exit /b

:stop_manual
cls
set "STOPPED_MANUAL=0"
for /f "delims=" %%N in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\stop-manual-winws2.ps1" 2^>nul') do set "STOPPED_MANUAL=%%N"
if "!STOPPED_MANUAL!"=="0" (call :PrintYellow "No manual winws2.exe from this bundle is running.") else (call :PrintGreen "Stopped !STOPPED_MANUAL! manual winws2.exe process(es).")
pause
goto menu

:service_diagnostics
cls
echo Running Zapret2 diagnostics...
echo.
sc query BFE 2>nul | findstr /I "RUNNING" >nul
if errorlevel 1 (call :PrintRed "[X] Base Filtering Engine is not running") else (call :PrintGreen "[OK] Base Filtering Engine is running")

if exist "%~dp0bin\winws2.exe" (call :PrintGreen "[OK] bin\winws2.exe found") else (call :PrintRed "[X] bin\winws2.exe not found")
if exist "%~dp0bin\cygwin1.dll" (call :PrintGreen "[OK] bin\cygwin1.dll found") else (call :PrintRed "[X] bin\cygwin1.dll not found")
if exist "%~dp0bin\WinDivert.dll" (call :PrintGreen "[OK] bin\WinDivert.dll found") else (call :PrintRed "[X] bin\WinDivert.dll not found")
if exist "%~dp0bin\WinDivert64.sys" (call :PrintGreen "[OK] bin\WinDivert64.sys found") else (call :PrintRed "[X] bin\WinDivert64.sys not found")
if exist "%~dp0lua\zapret-lib.lua" (call :PrintGreen "[OK] Zapret2 Lua library found") else (call :PrintRed "[X] lua\zapret-lib.lua not found")
if exist "%~dp0lua\zapret-antidpi.lua" (call :PrintGreen "[OK] Zapret2 anti-DPI library found") else (call :PrintRed "[X] lua\zapret-antidpi.lua not found")

for %%P in (AdguardSvc.exe Discord.exe DiscordPTB.exe) do (
    tasklist /FI "IMAGENAME eq %%P" 2>nul | find /I "%%P" >nul
    if not errorlevel 1 call :PrintYellow "[?] Process found: %%P"
)
for %%S in (GoodbyeDPI discordfix_zapret winws1 zapret) do (
    sc query "%%S" >nul 2>&1
    if not errorlevel 1 call :PrintYellow "[?] Conflicting bypass service found: %%S"
)
netsh winhttp show proxy | findstr /I "Direct access" >nul
if errorlevel 1 (call :PrintYellow "[?] WinHTTP proxy may be enabled") else (call :PrintGreen "[OK] WinHTTP proxy is direct")

powershell.exe -NoProfile -Command "$v=& '%~dp0bin\winws2.exe' --version 2^>^&1; if(($LASTEXITCODE -eq 0)-and($v -match 'lua_compat_ver')){Write-Host '[OK] Zapret2 engine version check passed' -ForegroundColor Green; exit 0}else{Write-Host '[X] Zapret2 engine version check failed' -ForegroundColor Red; exit 1}"
echo.
echo Diagnostics only identify likely conflicts; they do not prove bypass success.
pause
goto menu

:run_tests
cls
where curl.exe >nul 2>&1
if errorlevel 1 (
    call :PrintRed "curl.exe is required for strategy tests."
    pause
    goto menu
)
echo Starting Zapret2 strategy tests in a separate PowerShell window...
start "Zapret2 strategy tests" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\test-strategies.ps1"
pause
goto menu

:get_strategy_name
set "CurrentStrategy="
for /f "tokens=2,*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v "%PROFILE_VALUE%" 2^>nul') do set "CurrentStrategy=Strategy: %%B"
exit /b

:PrintGreen
powershell.exe -NoProfile -Command "Write-Host '%~1' -ForegroundColor Green"
exit /b

:PrintRed
powershell.exe -NoProfile -Command "Write-Host '%~1' -ForegroundColor Red"
exit /b

:PrintYellow
powershell.exe -NoProfile -Command "Write-Host '%~1' -ForegroundColor Yellow"
exit /b

:check_extracted
if not exist "%~dp0bin\winws2.exe" (
    echo Zapret2 must be extracted from the archive first: bin\winws2.exe not found.
    pause
    exit /b 1
)
if not exist "%~dp0profiles\" (
    echo profiles folder not found.
    pause
    exit /b 1
)
exit /b 0
