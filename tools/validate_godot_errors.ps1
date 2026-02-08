<#
.SYNOPSIS
    Automated Godot error detection from logs + GDScript validation
.DESCRIPTION
    Checks Godot runtime logs and performs GDScript static analysis
.EXAMPLE
    .\validate_godot_errors.ps1
    .\validate_godot_errors.ps1 -Verbose
#>

param(
    [string]$Path = "scripts",
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$script:TotalErrors = 0
$script:TotalWarnings = 0

# Colors
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Err { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }

# Get project name
function Get-ProjectName {
    if (Test-Path "project.godot") {
        $content = Get-Content "project.godot" -Raw
        if ($content -match 'config/name="([^"]+)"') {
            return $matches[1]
        }
    }
    return "Unknown"
}

# Get Godot log path
function Get-GodotLogPath {
    $projectName = Get-ProjectName
    $logPath = Join-Path $env:APPDATA "Godot\app_userdata\$projectName\logs"
    if (Test-Path $logPath) { return $logPath }
    return $null
}

# Parse Godot logs for errors
function Get-GodotLogErrors {
    param([string]$LogFolder)

    $errors = @()
    $logFiles = Get-ChildItem -Path $LogFolder -Filter "*.log" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

    foreach ($logFile in $logFiles) {
        $lines = Get-Content $logFile.FullName -ErrorAction SilentlyContinue
        $currentError = $null

        foreach ($line in $lines) {
            # SCRIPT ERROR
            if ($line -match '^SCRIPT ERROR: (.+)$') {
                $currentError = @{
                    Type = "SCRIPT"
                    Message = $matches[1]
                    Location = ""
                }
            }
            # ERROR: prefix
            elseif ($line -match '^ERROR: (.+)$') {
                $msg = $matches[1]
                if ($msg -notmatch '^$') {
                    $errors += @{
                        Type = "ERROR"
                        Message = $msg
                        Location = ""
                    }
                }
            }
            # Location line
            elseif ($line -match '^\s+at: (.+)$' -and $currentError) {
                $currentError.Location = $matches[1]
                $errors += $currentError
                $currentError = $null
            }
            # Parse Error
            elseif ($line -match 'Parse Error: (.+)') {
                $errors += @{
                    Type = "PARSE"
                    Message = $matches[1]
                    Location = ""
                }
            }
        }
    }

    return $errors
}

# Check GDScript file for critical issues only
function Test-GDScriptFile {
    param([string]$FilePath)

    $issues = @()
    $lines = Get-Content $FilePath -ErrorAction SilentlyContinue
    if (-not $lines) { return $issues }

    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++

        # 1. Reserved keywords as loop variables
        if ($line -match '\bfor\s+(trait|class|signal|extends|class_name|var|func|const|enum|static)\s+in\b') {
            $issues += "L$lineNum [ERROR] Reserved keyword '$($matches[1])' as loop variable"
            $script:TotalErrors++
        }

        # 2. Type inference from const indexing (strict pattern, case-sensitive)
        # Match: var x := CONST_NAME[index]  (ALL CAPS constant names only)
        if ($line -cmatch '^\s*var\s+\w+\s*:=\s*[A-Z][A-Z_0-9]+\s*\[') {
            $issues += "L$lineNum [ERROR] Type inference from const indexing"
            $script:TotalErrors++
        }

        # 3. Deprecated yield
        if ($line -match '\byield\s*\(') {
            $issues += "L$lineNum [ERROR] Deprecated yield() - use await"
            $script:TotalErrors++
        }

        # 4. Python integer division
        if ($line -match '\s//\s*\d') {
            $issues += "L$lineNum [ERROR] Python-style // - use int(x/y)"
            $script:TotalErrors++
        }

        # 5. Signal shadowing in function params
        if ($line -match '\bfunc\s+_on_\w+\s*\(\s*(ready|process|physics_process)\s*:') {
            $issues += "L$lineNum [WARN] Parameter shadows base signal"
            $script:TotalWarnings++
        }
    }

    return $issues
}

# Main
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GODOT VALIDATION - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Godot Logs
Write-Info "[1/3] GODOT RUNTIME LOGS"
$logPath = Get-GodotLogPath
if ($logPath) {
    $logErrors = Get-GodotLogErrors -LogFolder $logPath
    $uniqueErrors = $logErrors | ForEach-Object { "$($_.Type): $($_.Message)" } | Select-Object -Unique

    if ($uniqueErrors.Count -gt 0) {
        Write-Err "  Found $($uniqueErrors.Count) error(s):"
        foreach ($err in $logErrors | Select-Object -First 10) {
            Write-Host "  - $($err.Message)" -ForegroundColor Red
            if ($err.Location) {
                Write-Host "    at: $($err.Location)" -ForegroundColor DarkRed
            }
        }
        $script:TotalErrors += $uniqueErrors.Count
    } else {
        Write-Success "  No runtime errors in logs"
    }
} else {
    Write-Warn "  Log folder not found"
}

Write-Host ""

# 2. GDScript Static Analysis
Write-Info "[2/3] GDSCRIPT STATIC ANALYSIS"

$scriptPath = $Path
if (-not $scriptPath.Contains(":") -and -not $scriptPath.StartsWith("/")) {
    $scriptPath = Join-Path (Get-Location).Path $Path
}

if (Test-Path $scriptPath) {
    $gdFiles = Get-ChildItem -Path $scriptPath -Filter "*.gd" -Recurse
    Write-Host "  Scanning $($gdFiles.Count) files..." -ForegroundColor Gray

    $filesWithIssues = 0
    foreach ($file in $gdFiles) {
        $issues = Test-GDScriptFile -FilePath $file.FullName
        if ($issues.Count -gt 0) {
            $filesWithIssues++
            $relPath = $file.FullName.Replace((Get-Location).Path, "").TrimStart("\")
            Write-Host ""
            Write-Warn "  $relPath"
            foreach ($issue in $issues) {
                $color = if ($issue -match '\[ERROR\]') { "Red" } else { "Yellow" }
                Write-Host "    $issue" -ForegroundColor $color
            }
        }
    }

    if ($filesWithIssues -eq 0) {
        Write-Success "  No static analysis errors"
    }
} else {
    Write-Warn "  Scripts folder not found: $scriptPath"
}

Write-Host ""

# 3. GDExtension Check
Write-Info "[3/3] GDEXTENSION LIBRARIES"
$gdextFiles = Get-ChildItem -Path "." -Filter "*.gdextension" -Recurse -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -notmatch '\.disabled$' }

$missingLibs = @()
foreach ($ext in $gdextFiles) {
    $content = Get-Content $ext.FullName -Raw
    # Check if [libraries] section exists but has no uncommented entries
    if ($content -match '\[libraries\]') {
        $hasActiveLib = $content -match '\n\s*[^;\s][^\n]*=\s*"res://'
        if (-not $hasActiveLib) {
            $relPath = $ext.FullName.Replace((Get-Location).Path, "").TrimStart("\")
            $missingLibs += $relPath
        }
    }
}

if ($missingLibs.Count -gt 0) {
    Write-Warn "  GDExtensions without active libraries:"
    foreach ($lib in $missingLibs) {
        Write-Host "    - $lib" -ForegroundColor Yellow
    }
    # Don't count as errors - just warnings
} else {
    Write-Success "  All GDExtensions OK"
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
if ($script:TotalErrors -eq 0) {
    Write-Success "  VALIDATION PASSED"
} else {
    Write-Err "  ERRORS: $($script:TotalErrors)"
}
if ($script:TotalWarnings -gt 0) {
    Write-Warn "  WARNINGS: $($script:TotalWarnings)"
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

exit $(if ($script:TotalErrors -eq 0) { 0 } else { 1 })
