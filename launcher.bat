@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

if "%~1"=="" (
  echo Не указан профиль Zapret2.
  exit /b 2
)

for %%F in ("%~1") do (
  set "PROFILE=%%~fF"
  set "PROFILE_NAME=%%~nxF"
  set "PROFILE_TITLE=%%~nF"
)
if not exist "%PROFILE%" (
  echo Профиль не найден: %PROFILE%
  exit /b 3
)
if not exist "%~dp0bin\winws2.exe" (
  echo Не найден bin\winws2.exe
  exit /b 4
)

net session >nul 2>&1
if errorlevel 1 (
  echo Требуются права администратора. Запрашиваю UAC...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '""%PROFILE%""' -WorkingDirectory '%~dp0' -Verb RunAs"
  exit /b
)

tasklist /FI "IMAGENAME eq winws2.exe" 2>nul | find /I "winws2.exe" >nul
if not errorlevel 1 (
  echo winws2.exe уже запущен. Закройте его окно перед запуском другого профиля.
  pause
  exit /b 5
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run-profile.ps1" -ProfilePath "%PROFILE%"
if errorlevel 1 (
  echo Не удалось подготовить runtime-профиль Zapret2.
  pause
  exit /b 6
)

cd /d "%~dp0"
start "zapret2: %PROFILE_TITLE%" /min cmd.exe /d /k call tools\run-window.bat
if errorlevel 1 (
  echo Не удалось запустить winws2.exe.
  pause
  exit /b 7
)

exit /b 0
