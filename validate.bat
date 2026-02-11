@echo off
cd /d "%~dp0"

REM Step 1-3: Static analysis + logs + GDExtension check
powershell -ExecutionPolicy Bypass -File "tools/validate_godot_errors.ps1" %*

REM Step 4: Run affected scenes (auto-detects modified .gd via git)
echo.
echo Running affected scene validation...
powershell -ExecutionPolicy Bypass -File "tools/validate_affected_scenes.ps1"

REM Optional: --smoke flag runs ALL scenes
if "%1"=="--smoke" (
    echo.
    echo Running FULL smoke test on all scenes...
    powershell -ExecutionPolicy Bypass -File "tools/smoke_test_scenes.ps1"
)
pause
