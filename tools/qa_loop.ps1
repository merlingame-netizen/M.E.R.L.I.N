# ═══════════════════════════════════════════════════════════════════════════════
# QA Loop — Lightweight heartbeat for continuous quality monitoring
# ═══════════════════════════════════════════════════════════════════════════════
# Usage:
#   powershell -ExecutionPolicy Bypass -File "tools/qa_loop.ps1"
#   powershell -ExecutionPolicy Bypass -File "tools/qa_loop.ps1" -Deep
#
# Output: tools/autodev/status/qa_heartbeat.json
# ═══════════════════════════════════════════════════════════════════════════════

param(
    [switch]$Deep = $false
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$GodotExe = "C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe"
$StatusDir = Join-Path $ProjectRoot "tools\autodev\status"
$OutputFile = Join-Path $StatusDir "qa_heartbeat.json"

# Ensure status directory exists
if (-not (Test-Path $StatusDir)) {
    New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null
}

$timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
$verdict = "GO"
$steps = @{}

# ═══════════════════════════════════════════════════════════════════════════════
# Step 1: Parse Check (BLOCKING)
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n[QA] Step 1: Parse check..." -ForegroundColor Cyan

$parseResult = @{ status = "SKIP"; errors = 0; warnings = 0 }

try {
    $parseScript = Join-Path $ProjectRoot "tools\validate_editor_parse.ps1"
    $parseOutput = & powershell -ExecutionPolicy Bypass -File $parseScript 2>&1

    if ($LASTEXITCODE -eq 0) {
        $parseResult.status = "PASS"
        Write-Host "  [PASS] Parse check" -ForegroundColor Green
    } else {
        $parseResult.status = "FAIL"
        $verdict = "NO-GO"
        Write-Host "  [FAIL] Parse check" -ForegroundColor Red
    }
} catch {
    $parseResult.status = "ERROR"
    $verdict = "NO-GO"
    Write-Host "  [ERROR] Parse check: $_" -ForegroundColor Red
}

$steps["parse_check"] = $parseResult

# ═══════════════════════════════════════════════════════════════════════════════
# Step 2: Headless Unit Tests (BLOCKING)
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n[QA] Step 2: Headless unit tests..." -ForegroundColor Cyan

$testResult = @{ status = "SKIP"; total = 0; passed = 0; failed = @() }

try {
    $testScene = "res://tests/headless_runner.tscn"
    $proc = Start-Process -FilePath $GodotExe -ArgumentList "--path", $ProjectRoot, "--headless", "-s", "tests/headless_runner.gd" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\qa_test_out.txt" -RedirectStandardError "$env:TEMP\qa_test_err.txt"
    $proc | Wait-Process -Timeout 90 -ErrorAction SilentlyContinue

    if (-not $proc.HasExited) {
        $proc | Stop-Process -Force
        $testResult.status = "TIMEOUT"
        $verdict = "NO-GO"
        Write-Host "  [TIMEOUT] Tests exceeded 90s" -ForegroundColor Red
    } else {
        $stdout = Get-Content "$env:TEMP\qa_test_out.txt" -Raw -ErrorAction SilentlyContinue
        # Find JSON line in output
        $jsonLine = ($stdout -split "`n" | Where-Object { $_ -match '^\s*\{' -and $_ -match '"total"' }) | Select-Object -Last 1

        if ($jsonLine) {
            $json = $jsonLine | ConvertFrom-Json
            $testResult.total = $json.total
            $testResult.passed = $json.passed
            $testResult.failed = @($json.failed)

            if ($json.failed.Count -eq 0 -and $json.errors.Count -eq 0) {
                $testResult.status = "PASS"
                Write-Host "  [PASS] $($json.passed)/$($json.total) tests passed" -ForegroundColor Green
            } else {
                $testResult.status = "FAIL"
                $verdict = "NO-GO"
                Write-Host "  [FAIL] $($json.failed.Count) failed, $($json.errors.Count) errors" -ForegroundColor Red
                foreach ($f in $json.failed) {
                    Write-Host "    - $f" -ForegroundColor Red
                }
            }
        } else {
            $testResult.status = "NO_OUTPUT"
            Write-Host "  [WARN] No JSON output from test runner" -ForegroundColor Yellow
        }
    }
} catch {
    $testResult.status = "ERROR"
    Write-Host "  [ERROR] Tests: $_" -ForegroundColor Red
}

$steps["unit_tests"] = $testResult

# ═══════════════════════════════════════════════════════════════════════════════
# Step 3: Card Conformity (WARNING — Deep mode only)
# ═══════════════════════════════════════════════════════════════════════════════

$cardResult = @{ status = "SKIP" }

if ($Deep) {
    Write-Host "`n[QA] Step 3: Card conformity..." -ForegroundColor Cyan
    try {
        $cardScript = Join-Path $ProjectRoot "tools\test_card_conformity.py"
        if (Test-Path $cardScript) {
            $cardOutput = & python $cardScript 2>&1
            if ($LASTEXITCODE -eq 0) {
                $cardResult.status = "PASS"
                Write-Host "  [PASS] Card conformity" -ForegroundColor Green
            } else {
                $cardResult.status = "WARN"
                Write-Host "  [WARN] Card conformity issues" -ForegroundColor Yellow
            }
        } else {
            $cardResult.status = "SKIP"
            Write-Host "  [SKIP] test_card_conformity.py not found" -ForegroundColor Yellow
        }
    } catch {
        $cardResult.status = "ERROR"
        Write-Host "  [ERROR] Card conformity: $_" -ForegroundColor Red
    }
}

$steps["card_conformity"] = $cardResult

# ═══════════════════════════════════════════════════════════════════════════════
# Step 4: Git diff check (track untested changes)
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "`n[QA] Step 4: Git diff check..." -ForegroundColor Cyan

$gitResult = @{ status = "INFO"; modified_gd = 0; modified_test = 0 }

try {
    $gitDiff = & git -C $ProjectRoot diff --name-only 2>&1
    $gdFiles = @($gitDiff | Where-Object { $_ -match '\.gd$' })
    $testFiles = @($gdFiles | Where-Object { $_ -match 'test_' })

    $gitResult.modified_gd = $gdFiles.Count
    $gitResult.modified_test = $testFiles.Count

    if ($gdFiles.Count -gt 0) {
        Write-Host "  [INFO] $($gdFiles.Count) .gd files modified ($($testFiles.Count) test files)" -ForegroundColor Cyan
    } else {
        Write-Host "  [INFO] No uncommitted .gd changes" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Git check failed" -ForegroundColor Yellow
}

$steps["git_diff"] = $gitResult

# ═══════════════════════════════════════════════════════════════════════════════
# Report
# ═══════════════════════════════════════════════════════════════════════════════

$report = @{
    timestamp = $timestamp
    verdict = $verdict
    mode = if ($Deep) { "deep" } else { "heartbeat" }
    steps = $steps
}

$reportJson = $report | ConvertTo-Json -Depth 4
$reportJson | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "`n════════════════════════════════════════" -ForegroundColor White
Write-Host "  QA VERDICT: $verdict" -ForegroundColor $(if ($verdict -eq "GO") { "Green" } else { "Red" })
Write-Host "  Report: $OutputFile" -ForegroundColor Gray
Write-Host "════════════════════════════════════════`n" -ForegroundColor White

exit $(if ($verdict -eq "GO") { 0 } else { 1 })
