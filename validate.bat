@echo off
cd /d "%~dp0"

REM Step 0: Editor parse check (forces full project recompilation, detects type/parse errors)
powershell -ExecutionPolicy Bypass -File "tools/validate_editor_parse.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [ABORT] Editor parse check failed. Fix errors above before continuing.
    pause
    exit /b 1
)

REM Step 1-3: Static analysis + logs + GDExtension check
powershell -ExecutionPolicy Bypass -File "tools/validate_godot_errors.ps1" %*

REM Step 4: Run affected scenes (auto-detects modified .gd via git)
echo.
echo Running affected scene validation...
powershell -ExecutionPolicy Bypass -File "tools/validate_affected_scenes.ps1"

REM Step 5: FULL smoke test on ALL scenes (always runs)
echo.
echo Running FULL smoke test on all scenes...
powershell -ExecutionPolicy Bypass -File "tools/smoke_test_scenes.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [WARN] Some scenes failed smoke test. Review errors above.
)

REM Step 6: Game flow order validation (canonical scene sequence)
echo.
echo Running game flow order validation...
powershell -ExecutionPolicy Bypass -File "tools/validate_flow_order.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [WARN] Some flow scenes failed. Review errors above.
)

REM Step 7: LLM connectivity check (non-blocking, informational)
echo.
echo Checking LLM backend (Ollama)...
powershell -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop; if ($r.StatusCode -eq 200) { $data = $r.Content | ConvertFrom-Json; $models = $data.models | ForEach-Object { $_.name }; Write-Host '[OK] Ollama running. Models:' ($models -join ', ') } else { Write-Host '[WARN] Ollama responded with status' $r.StatusCode } } catch { Write-Host '[INFO] Ollama not running (ollama serve). LLM features will be unavailable in-game.' }"
pause
