# watch_live_game.ps1 — Surveillance log Godot en temps réel
# Filtre les lignes pertinentes et les écrit dans status/live_log.json
# Usage: powershell -File tools/autodev/watch_live_game.ps1 [-Tail N]
param(
    [int]$Tail = 200,
    [int]$PollSeconds = 2
)

$LogPath = "$env:APPDATA\Godot\app_userdata\DRU\logs\godot.log"
$OutPath = "$PSScriptRoot\status\live_log.json"
$Prefixes = @(
    '[TRIADE]', '[MerlinStore]', '[MerlinUI]', '[MerlinUI]',
    '[MerlinLlmAdapter]', '[LLM-Adapter]', '[AUTOPLAY]',
    '[SCREENSHOT]', '[GameDebugServer]', '[ScenarioManager]',
    '[MCP]', 'ERROR', 'SCRIPT ERROR'
)

$Buffer = @()
$LastSize = 0

Write-Host "MERLIN Live Log Watcher — $LogPath"
Write-Host "Output: $OutPath"
Write-Host "Prefixes: $($Prefixes -join ', ')"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

while ($true) {
    if (Test-Path $LogPath) {
        $CurrentSize = (Get-Item $LogPath).Length

        if ($CurrentSize -gt $LastSize) {
            $Lines = Get-Content $LogPath -Tail $Tail -ErrorAction SilentlyContinue
            $LastSize = $CurrentSize

            $Filtered = $Lines | Where-Object {
                $Line = $_
                $Prefixes | Where-Object { $Line -match [regex]::Escape($_) }
            }

            if ($Filtered) {
                foreach ($Line in $Filtered) {
                    $Entry = "[$(Get-Date -Format 'HH:mm:ss')] $Line"
                    $Buffer += $Entry
                    Write-Host $Entry -ForegroundColor Cyan
                }
                $Buffer = $Buffer | Select-Object -Last 100
                $Buffer | ConvertTo-Json -Compress | Set-Content $OutPath -Encoding UTF8
            }
        }
    } else {
        Write-Host "En attente du log Godot ($LogPath)..." -ForegroundColor DarkGray
    }

    Start-Sleep $PollSeconds
}
