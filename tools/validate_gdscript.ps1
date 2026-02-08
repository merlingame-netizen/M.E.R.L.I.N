# GDScript Pre-Delivery Validation Script
# Run before testing in Godot to catch common errors

param(
    [string]$Path = "scripts",
    [switch]$Fix = $false
)

$ErrorCount = 0
$WarningCount = 0

Write-Host "`n=== GDScript Validation ===" -ForegroundColor Cyan

# Get all .gd files
$scripts = Get-ChildItem -Path $Path -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue

if ($scripts.Count -eq 0) {
    Write-Host "No .gd files found in $Path" -ForegroundColor Yellow
    exit 0
}

Write-Host "Scanning $($scripts.Count) files...`n" -ForegroundColor Gray

foreach ($file in $scripts) {
    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName
    $relativePath = $file.FullName.Replace((Get-Location).Path + "\", "")
    $hasErrors = $false

    # Check 1: Reserved keywords as variable names
    $reservedKeywords = @("trait", "class", "signal", "func", "var", "const", "enum", "static", "export", "onready", "tool", "master", "puppet", "slave", "remotesync", "sync", "remote", "puppet", "puppetsync")

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1

        # Check for reserved keyword usage in for loops
        if ($line -match "for\s+(trait|class)\s+in") {
            Write-Host "ERROR [$relativePath`:$lineNum] Reserved keyword in for loop: $($Matches[1])" -ForegroundColor Red
            Write-Host "  $line" -ForegroundColor DarkGray
            $ErrorCount++
            $hasErrors = $true
        }

        # Check for := with const array/dict indexing (UPPERCASE_CONST[index])
        # Uses case-sensitive match to only catch actual constants
        if ($line -cmatch ":=\s+[A-Z][A-Z0-9_]+\[") {
            Write-Host "ERROR [$relativePath`:$lineNum] Type inference from const indexing" -ForegroundColor Red
            Write-Host "  $line" -ForegroundColor DarkGray
            Write-Host "  Fix: Use explicit type annotation instead of :=" -ForegroundColor Yellow
            $ErrorCount++
            $hasErrors = $true
        }

        # Check for var trait = or var class =
        if ($line -match "var\s+(trait|class)\s*[:=]") {
            Write-Host "ERROR [$relativePath`:$lineNum] Reserved keyword as variable: $($Matches[1])" -ForegroundColor Red
            Write-Host "  $line" -ForegroundColor DarkGray
            $ErrorCount++
            $hasErrors = $true
        }

        # Check for empty match statements (common mistake)
        if ($line -match "match\s*$") {
            Write-Host "WARNING [$relativePath`:$lineNum] Empty match statement" -ForegroundColor Yellow
            $WarningCount++
        }

        # Check for incorrect await usage
        if ($line -match "yield\(") {
            Write-Host "WARNING [$relativePath`:$lineNum] 'yield' is deprecated in Godot 4, use 'await'" -ForegroundColor Yellow
            Write-Host "  $line" -ForegroundColor DarkGray
            $WarningCount++
        }

        # Check for missing return type on functions
        if ($line -match "^func\s+\w+\([^)]*\)\s*:" -and $line -notmatch "->") {
            # This is just informational, not an error
        }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Files scanned: $($scripts.Count)"
if ($ErrorCount -gt 0) {
    Write-Host "Errors: $ErrorCount" -ForegroundColor Red
} else {
    Write-Host "Errors: 0" -ForegroundColor Green
}
if ($WarningCount -gt 0) {
    Write-Host "Warnings: $WarningCount" -ForegroundColor Yellow
} else {
    Write-Host "Warnings: 0" -ForegroundColor Green
}

if ($ErrorCount -gt 0) {
    Write-Host "`nFix errors before testing in Godot!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nValidation passed!" -ForegroundColor Green
    exit 0
}
