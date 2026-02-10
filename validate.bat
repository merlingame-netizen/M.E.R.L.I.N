@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "tools/validate_godot_errors.ps1" %*
if "%1"=="--smoke" (
    echo.
    echo Running smoke test on all scenes...
    powershell -ExecutionPolicy Bypass -File "tools/smoke_test_scenes.ps1"
)
pause
