@echo off
REM Double-click to uninstall the Draw 100 Mod. Close the game first.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1"
echo.
pause
