@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "INDEX=0"
for %%F in ("%~dp0..\profiles\general*.txt") do (
  set /a INDEX+=1
  echo  !INDEX!. %%~nF
  set "PROFILE_!INDEX!=%%~fF"
)
if "!INDEX!"=="0" exit /b 1
set /p "PROFILE_CHOICE=Профиль: "
for /f "delims=0123456789" %%A in ("!PROFILE_CHOICE!") do exit /b 2
if !PROFILE_CHOICE! LSS 1 exit /b 2
if !PROFILE_CHOICE! GTR !INDEX! exit /b 2
for %%N in (!PROFILE_CHOICE!) do endlocal & set "SELECTED_PROFILE=%PROFILE_%%N%"
exit /b 0
