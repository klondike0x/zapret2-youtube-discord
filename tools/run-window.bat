@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-window.ps1"
set "WINWS_EXIT=%ERRORLEVEL%"
if not "%WINWS_EXIT%"=="0" (
  echo.
  echo ОШИБКА: winws2.exe завершился с кодом %WINWS_EXIT%.
  pause
)
exit /b %WINWS_EXIT%
