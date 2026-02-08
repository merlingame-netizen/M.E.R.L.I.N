@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "tools/validate_godot_errors.ps1" %*
pause
