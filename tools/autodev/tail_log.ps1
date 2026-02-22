# tail_log.ps1 -- Log tailer for aggregated view panes
# Usage: .\tail_log.ps1 -LogFile "path.log" -Title "ui-ux BUILD" [-TailLines 80]

param(
    [Parameter(Mandatory=$true)]
    [string]$LogFile,
    [string]$Title = "Worker",
    [int]$TailLines = 80,
    [string]$StatusFile = ""
)

$host.UI.RawUI.WindowTitle = $Title

# Header
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "  $Title" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""

# Wait for log file to appear
$waited = 0
while (-not (Test-Path $LogFile)) {
    if ($waited -eq 0) {
        Write-Host "[TAIL] Waiting for: $LogFile" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1
    $waited++

    # Show status file progress while waiting
    if ($StatusFile -and (Test-Path $StatusFile)) {
        $status = Get-Content $StatusFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($status -and $status.status) {
            Write-Host "`r[TAIL] Status: $($status.status) ($waited`s)" -NoNewline -ForegroundColor DarkYellow
        }
    }

    if ($waited -gt 600) {
        Write-Host "`n[TAIL] Timeout (10min) waiting for log file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "[TAIL] Streaming: $LogFile" -ForegroundColor Green
Write-Host ("-" * 50) -ForegroundColor DarkGray

# Stream the log
Get-Content $LogFile -Wait -Tail $TailLines
