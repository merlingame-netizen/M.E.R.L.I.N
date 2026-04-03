# validate_incremental.ps1 — Validation ciblée sur les fichiers modifiés uniquement (B3)
# Usage: .\tools\autodev\scripts\validate_incremental.ps1 [-BaseRef HEAD~1] [-Force]
# Impact: 5-10x plus rapide que validate.bat complet sur petits changements

param(
    [string]$BaseRef = "HEAD~1",
    [switch]$Force = $false,
    [switch]$SkipScenes = $false
)

# -- Godot executable (HIGH fix: env var, no hardcoded user path)
$GodotExe = $env:GODOT_EXE
if (-not $GodotExe) {
    # Fallback: search common location relative to LOCALAPPDATA
    $candidate = "$env:USERPROFILE\Godot\Godot_v4.5.1-stable_win64_console.exe"
    if (Test-Path $candidate) { $GodotExe = $candidate }
}
if (-not $GodotExe -or -not (Test-Path $GodotExe)) {
    Write-Error "[validate_incremental] Godot not found. Set GODOT_EXE environment variable."
    exit 1
}

# -- Project root resolution (MEDIUM fix: verify project.godot exists)
$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path
if (-not (Test-Path "$ProjectRoot\project.godot")) {
    Write-Error "[validate_incremental] project.godot not found at '$ProjectRoot'. Check script location."
    exit 1
}

Write-Host "[validate_incremental] Godot: $GodotExe" -ForegroundColor Gray
Write-Host "[validate_incremental] Project: $ProjectRoot" -ForegroundColor Gray
Write-Host "[validate_incremental] Base ref: $BaseRef" -ForegroundColor Cyan

# -- HIGH fix: verify base ref exists before diffing
$refCheck = git rev-parse --verify $BaseRef 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "[validate_incremental] '$BaseRef' not found (shallow clone or initial commit). Running full validate."
    & "$ProjectRoot\validate.bat" "0"
    exit $LASTEXITCODE
}

# -- HIGH fix: separate stdout from stderr to avoid git warnings polluting file list
$changedFiles = git diff --name-only $BaseRef -- "*.gd" "*.tscn" "*.tres"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[validate_incremental] Git diff failed, falling back to full validate" -ForegroundColor Yellow
    & "$ProjectRoot\validate.bat" "0"
    exit $LASTEXITCODE
}

$changedGd   = @($changedFiles | Where-Object { $_ -match '\.gd$' })
$changedTscn = @($changedFiles | Where-Object { $_ -match '\.tscn$' })  # .tres cannot be run as scenes

Write-Host "[validate_incremental] Changed .gd: $($changedGd.Count), .tscn/.tres: $($changedTscn.Count)" -ForegroundColor Cyan

if ($changedGd.Count -eq 0 -and $changedTscn.Count -eq 0 -and -not $Force) {
    Write-Host "[validate_incremental] No GDScript/scene changes detected. Skipping validation." -ForegroundColor Green
    exit 0
}

$errors = 0

# -- Step 0: Editor Parse Check — TOUJOURS si .gd modifiés
# MEDIUM fix: --check-only is not a valid Godot 4 flag; headless --quit triggers parse during project load
if ($changedGd.Count -gt 0 -or $Force) {
    Write-Host "`n[Step 0] Full project parse check (triggered by: $(($changedGd | Split-Path -Leaf) -join ', '))..." -ForegroundColor Yellow

    $parseLog = "$ProjectRoot\tools\autodev\status\parse_check_incremental.log"
    $proc = Start-Process -FilePath $GodotExe `
        -ArgumentList "--headless", "--path", $ProjectRoot, "--quit" `
        -RedirectStandardError $parseLog `
        -NoNewWindow -PassThru -Wait

    # LOW fix: check exit code AND log content
    $parseOutput = Get-Content $parseLog -ErrorAction SilentlyContinue
    $parseErrors = @($parseOutput | Where-Object { $_ -match '\bERROR\b' -and $_ -notmatch 'UserWarning' })

    if ($proc.ExitCode -ne 0 -or $parseErrors.Count -gt 0) {
        Write-Host "[Step 0] FAIL — Parse errors (exit $($proc.ExitCode)):" -ForegroundColor Red
        $parseErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        $errors++
    } else {
        Write-Host "[Step 0] PASS — No parse errors" -ForegroundColor Green
    }
}

# -- Step 4: Scene validation — seulement scènes affectées
# MEDIUM fix: use positional scene path (Godot 4 headless syntax), unique log per scene
if ($changedTscn.Count -gt 0 -and -not $SkipScenes) {
    Write-Host "`n[Step 4] Validating $($changedTscn.Count) affected scene(s)..." -ForegroundColor Yellow

    foreach ($scene in $changedTscn) {
        $sceneRes  = "res://$($scene -replace '\\', '/')"
        # MEDIUM fix: unique log file per scene (no race condition)
        $sceneSlug = ($scene -replace '[\\/:*?"<>|]', '_')
        $sceneLog  = "$ProjectRoot\tools\autodev\status\scene_check_$sceneSlug.log"

        Write-Host "  Checking: $sceneRes" -ForegroundColor Gray

        # MEDIUM fix: positional arg (not --scene-path which is invalid in Godot 4)
        $proc = Start-Process -FilePath $GodotExe `
            -ArgumentList "--headless", "--path", $ProjectRoot, $sceneRes, "--quit" `
            -RedirectStandardError $sceneLog `
            -NoNewWindow -PassThru -Wait

        $sceneErrors = @(Get-Content $sceneLog -ErrorAction SilentlyContinue | Where-Object { $_ -match '\bERROR\b' })

        if ($proc.ExitCode -ne 0 -or $sceneErrors.Count -gt 0) {
            Write-Host "  FAIL: $scene (exit $($proc.ExitCode))" -ForegroundColor Red
            $sceneErrors | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
            $errors++
        } else {
            Write-Host "  PASS: $scene" -ForegroundColor Green
        }
    }
}

# Summary
Write-Host "`n[validate_incremental] $errors error(s)" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })

if ($errors -gt 0) {
    Write-Host "[validate_incremental] FAIL — Fix errors before proceeding" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[validate_incremental] PASS" -ForegroundColor Green
    exit 0
}
