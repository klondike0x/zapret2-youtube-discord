@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
set "SERVICE=zapret2-youtube-discord"

net session >nul 2>&1
if errorlevel 1 (
  echo Требуются права администратора. Запрашиваю UAC...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs"
  exit /b
)

:menu
cls
echo ========================================
echo       ZAPRET2 SERVICE MANAGER
echo ========================================
echo  1. Установить профиль как службу
echo  2. Удалить службу
echo  3. Запустить службу
echo  4. Остановить службу
echo  5. Проверить статус
echo  6. Остановить ручной winws2.exe
echo  0. Выход
echo.
set /p "CHOICE=Выберите действие: "
if "%CHOICE%"=="1" goto install
if "%CHOICE%"=="2" goto remove
if "%CHOICE%"=="3" goto start_service
if "%CHOICE%"=="4" goto stop_service
if "%CHOICE%"=="5" goto status
if "%CHOICE%"=="6" goto stop_manual
if "%CHOICE%"=="0" exit /b
goto menu

:install
cls
set "PROFILE="
set "PROFILE_PATH="
echo Выберите профиль:
echo  1. General
echo  2. General ALT (Flowseal port)
echo  3. YouTube
echo  4. Discord
echo  5. Simple Fake
echo  6. Multisplit
echo  7. Fake + Multisplit
echo  8. HostFakeSplit
echo  9. Fake TLS Auto
echo  0. Назад
set /p "PROFILE_CHOICE=Профиль: "
if "%PROFILE_CHOICE%"=="1" set "PROFILE=profiles\general.txt"
if "%PROFILE_CHOICE%"=="2" set "PROFILE=profiles\general-alt.txt"
if "%PROFILE_CHOICE%"=="3" set "PROFILE=profiles\youtube.txt"
if "%PROFILE_CHOICE%"=="4" set "PROFILE=profiles\discord.txt"
if "%PROFILE_CHOICE%"=="5" set "PROFILE=profiles\general-simple-fake.txt"
if "%PROFILE_CHOICE%"=="6" set "PROFILE=profiles\general-multisplit.txt"
if "%PROFILE_CHOICE%"=="7" set "PROFILE=profiles\general-fake-multisplit.txt"
if "%PROFILE_CHOICE%"=="8" set "PROFILE=profiles\general-hostfakesplit.txt"
if "%PROFILE_CHOICE%"=="9" set "PROFILE=profiles\general-fake-tls-auto.txt"

if "%PROFILE_CHOICE%"=="0" goto menu
if not defined PROFILE (
  echo Неверный выбор.
  pause
  goto menu
)
set "PROFILE_PATH=%~dp0%PROFILE%"
if not exist "%PROFILE_PATH%" (
  echo Профиль не найден: %PROFILE_PATH%
  pause
  goto menu
)

for %%F in ("%PROFILE_PATH%") do set "PROFILE_NAME=%%~nxF"
set "SERVICE_PS1=%~dp0tools\run-service.ps1"
call :remove_quiet
sc create "%SERVICE%" binPath= "\"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe\" -NoProfile -ExecutionPolicy Bypass -File \"%SERVICE_PS1%\" -ProfilePath \"%PROFILE_PATH%\"" DisplayName= "zapret2 YouTube Discord" start= auto
if errorlevel 1 (
  echo Не удалось создать службу.
  pause
  goto menu
)
sc description "%SERVICE%" "Zapret2 DPI bypass with selectable Lua profiles"
reg add "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v Profile /t REG_SZ /d "%PROFILE%" /f >nul
sc start "%SERVICE%"
echo Служба установлена с профилем %PROFILE%.
pause
goto menu

:remove
call :remove_quiet
echo Служба удалена.
pause
goto menu

:remove_quiet
sc stop "%SERVICE%" >nul 2>&1
sc delete "%SERVICE%" >nul 2>&1
exit /b

:start_service
sc start "%SERVICE%"
pause
goto menu

:stop_service
sc stop "%SERVICE%"
pause
goto menu

:stop_manual
taskkill /IM winws2.exe /F >nul 2>&1
if errorlevel 1 (echo winws2.exe не запущен.) else (echo winws2.exe остановлен.)
pause
goto menu

:status
sc query "%SERVICE%"
echo.
tasklist /FI "IMAGENAME eq winws2.exe"
echo.
for /f "tokens=2,*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\%SERVICE%" /v Profile 2^>nul ^| find /I "Profile"') do echo Активный профиль: %%B
pause
goto menu

