@echo off
rem ============================================================
rem  dsh-todo-tray  -  todo.cmd   (v1-c CLI)
rem  Usage:  todo.cmd help
rem ============================================================
chcp 65001 >nul 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0todo-cli.ps1" %*
exit /b %errorlevel%
