@echo off
rem ============================================================
rem  dsh-todo-tray  v1-a  -  headless self test
rem  Runs in a temp folder, does not touch any real todos.json.
rem  Exit code 0 = all checks passed.
rem ============================================================
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\src\todo-tray.ps1" -SelfTest
set RC=%errorlevel%
echo.
echo [selftest] exit code = %RC%   (0 = all passed)
pause
