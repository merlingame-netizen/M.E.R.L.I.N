Set-Location "c:/Users/PGNK2128/Godot-MCP"
$r = cmd /c "validate.bat" 2>&1
$logDir = "c:/Users/PGNK2128/Godot-MCP/tools/autodev/logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$r | Out-File "$logDir/validate_latest.log" -Encoding utf8
$errors = ($r | Select-String "ERROR:").Count
$warnings = ($r | Select-String "WARNING:").Count
Write-Host "=== VALIDATE RESULT ==="
Write-Host "Errors: $errors"
Write-Host "Warnings: $warnings"
$r | Select-String "ERROR:|WARNING:" | Select-Object -First 30 | ForEach-Object { Write-Host $_.Line }
