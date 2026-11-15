@echo off
rem ============================================================
rem  dsh-todo-tray 0.2.0 - NORMAL launcher
rem  wscript + start-todo-tray.vbs => no console window (R1).
rem  Do NOT go back to: start "" powershell.exe -WindowStyle Hidden
rem  On Win11 that console is delegated to Windows Terminal and the
rem  black window stays on the desktop (evidence: internal test notes).
rem  Data: %USERPROFILE%\.dsh\deepseek-todo\  (created on first run)
rem  No autostart, no registry, no network.
rem  Repo layout: launcher lives in scripts\, program in ..\src\
rem ============================================================
setlocal
wscript.exe "%~dp0start-todo-tray.vbs" %*
exit /b 0
