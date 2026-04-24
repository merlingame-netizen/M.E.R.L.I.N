@echo off
REM M.E.R.L.I.N. Local Dev Launcher
REM Starts Mission Control + optionally Godot Editor

setlocal

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "MC_DIR=%SCRIPT_DIR%mission-control"

echo ======================================
echo    M.E.R.L.I.N. -- Local Dev Setup
echo ======================================
echo.

REM Start Mission Control
echo [MC] Starting Mission Control...
cd /d "%MC_DIR%"
if not exist "node_modules" (
    echo [MC] Installing dependencies...
    call npm install
)
start "MissionControl" cmd /c "npm run dev"
echo [MC] Dashboard: http://localhost:4200
echo.

REM Optionally launch Godot
if "%1"=="--godot" (
    echo [GODOT] Launching Godot Editor...
    cd /d "%PROJECT_ROOT%"
    start "GodotEditor" godot --editor --path .
    echo [GODOT] Editor started.
    echo.
)
if "%1"=="-g" (
    echo [GODOT] Launching Godot Editor...
    cd /d "%PROJECT_ROOT%"
    start "GodotEditor" godot --editor --path .
    echo [GODOT] Editor started.
    echo.
)

echo [MERLIN] All systems online.
echo [MERLIN] Mission Control: http://localhost:4200
echo [MERLIN] Close this window to stop.
echo.
pause
