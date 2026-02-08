# GDScript Pre-Validation Tool
# Run before testing in Godot to catch common type inference errors
# Usage: .\tools\check_scripts.ps1

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "GDScript Type Inference Validator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$scriptsPath = "scripts"
$errors = @()
$warnings = @()

# Pattern 1: CONST[index] with :=
Write-Host "Checking for CONST[index] patterns..." -ForegroundColor Yellow
$pattern1 = Select-String -Path "$scriptsPath\*.gd" -Pattern ':= [A-Z_]+\[' -Recurse
if ($pattern1) {
    foreach ($match in $pattern1) {
        $errors += "ERROR: $($match.Filename):$($match.LineNumber) - Const indexing needs explicit type"
        Write-Host "  $($match.Filename):$($match.LineNumber)" -ForegroundColor Red
    }
}

# Pattern 2: dict/array member access with :=
Write-Host "Checking for member[key] patterns..." -ForegroundColor Yellow
$pattern2 = Select-String -Path "$scriptsPath\*.gd" -Pattern ':= \w+\.\w+\[' -Recurse
if ($pattern2) {
    foreach ($match in $pattern2) {
        $warnings += "WARNING: $($match.Filename):$($match.LineNumber) - Member access may need explicit type"
        Write-Host "  $($match.Filename):$($match.LineNumber)" -ForegroundColor Yellow
    }
}

# Pattern 3: variable[index] with :=
Write-Host "Checking for var[index] patterns..." -ForegroundColor Yellow
$pattern3 = Select-String -Path "$scriptsPath\*.gd" -Pattern 'var \w+ := \w+\[\w+\]$' -Recurse
if ($pattern3) {
    foreach ($match in $pattern3) {
        $warnings += "WARNING: $($match.Filename):$($match.LineNumber) - Array indexing may need explicit type"
        Write-Host "  $($match.Filename):$($match.LineNumber)" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "All scripts passed validation!" -ForegroundColor Green
} else {
    Write-Host "Errors: $($errors.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Run 'godot --headless --script res://tools/validate_scripts.gd' for full validation" -ForegroundColor Gray
