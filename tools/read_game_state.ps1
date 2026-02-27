<#
.SYNOPSIS
    Read and display current game state + perf metrics from GameObserver captures.
.DESCRIPTION
    Reads state.json and perf.json from tools/autodev/captures/ and formats a summary.
    Useful for Claude Code to quickly understand current game status.
.PARAMETER Raw
    Output raw JSON instead of formatted summary.
.EXAMPLE
    .\tools\read_game_state.ps1
    .\tools\read_game_state.ps1 -Raw
#>

param(
    [switch]$Raw
)

$CapturesDir = Join-Path "C:\Users\PGNK2128\Godot-MCP" "tools\autodev\captures"
$StatePath = Join-Path $CapturesDir "state.json"
$PerfPath = Join-Path $CapturesDir "perf.json"
$LogPath = Join-Path $CapturesDir "log.json"

# --- Check captures exist ---
if (-not (Test-Path $StatePath)) {
    Write-Host "[WARN] No state.json found — game may not be running" -ForegroundColor Yellow
    Write-Host "  Expected: $StatePath" -ForegroundColor DarkGray
    exit 1
}

# --- Read state ---
$state = Get-Content $StatePath -Raw | ConvertFrom-Json

if ($Raw) {
    Write-Host "=== STATE ===" -ForegroundColor Cyan
    $state | ConvertTo-Json -Depth 5
    if (Test-Path $PerfPath) {
        Write-Host "`n=== PERF ===" -ForegroundColor Cyan
        Get-Content $PerfPath -Raw
    }
    exit 0
}

# --- Formatted summary ---
Write-Host "=== GAME STATE ===" -ForegroundColor Cyan
Write-Host "  Timestamp:  $($state.datetime)" -ForegroundColor DarkGray

$run = $state.run
if ($run) {
    Write-Host "  Phase:      $($run.phase)" -ForegroundColor White
    Write-Host "  Life:       $($run.life)" -ForegroundColor $(if ([int]$run.life -lt 30) { "Red" } elseif ([int]$run.life -lt 60) { "Yellow" } else { "Green" })
    Write-Host "  Souffle:    $($run.souffle)" -ForegroundColor White
    Write-Host "  Cards:      $($run.cards_played)" -ForegroundColor White
    Write-Host "  Biome:      $($run.biome)" -ForegroundColor White
    Write-Host "  Typology:   $($run.typology)" -ForegroundColor White
    Write-Host "  Karma:      $($run.karma)" -ForegroundColor White
    Write-Host "  Tension:    $($run.tension)" -ForegroundColor White
    Write-Host "  Mission:    $($run.mission_type) ($($run.mission_progress)/$($run.mission_total))" -ForegroundColor White

    if ($run.aspects) {
        Write-Host "  Aspects:" -ForegroundColor White
        $run.aspects.PSObject.Properties | ForEach-Object {
            Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "  (No run data — game may be in menu)" -ForegroundColor Yellow
}

# --- Perf metrics ---
if (Test-Path $PerfPath) {
    $perf = Get-Content $PerfPath -Raw | ConvertFrom-Json
    Write-Host "`n=== PERFORMANCE ===" -ForegroundColor Cyan
    Write-Host "  FPS avg:        $([math]::Round($perf.fps_avg, 1))" -ForegroundColor $(if ($perf.fps_avg -lt 30) { "Red" } else { "Green" })
    Write-Host "  FPS min:        $([math]::Round($perf.fps_min, 1))" -ForegroundColor White
    Write-Host "  Cards gen:      $($perf.cards_generated)" -ForegroundColor White
    Write-Host "  LLM count:      $($perf.llm_count)" -ForegroundColor White
    Write-Host "  Fallback count: $($perf.fallback_count)" -ForegroundColor White
    Write-Host "  Fallback rate:  $([math]::Round($perf.fallback_rate * 100, 1))%" -ForegroundColor $(if ($perf.fallback_rate -gt 0.1) { "Red" } else { "Green" })
    if ($perf.card_gen_avg_ms -gt 0) {
        Write-Host "  Card gen avg:   $($perf.card_gen_avg_ms)ms" -ForegroundColor $(if ($perf.card_gen_avg_ms -gt 10000) { "Red" } else { "Green" })
        Write-Host "  Card gen p50:   $($perf.card_gen_p50_ms)ms" -ForegroundColor White
        Write-Host "  Card gen p90:   $($perf.card_gen_p90_ms)ms" -ForegroundColor White
    }
    Write-Host "  Uptime:         $([math]::Round($perf.session_uptime_ms / 1000, 1))s" -ForegroundColor DarkGray
}

# --- Latest log tail ---
if (Test-Path $LogPath) {
    $logs = Get-Content $LogPath -Raw | ConvertFrom-Json
    if ($logs.Count -gt 0) {
        Write-Host "`n=== LOG (last 5) ===" -ForegroundColor Cyan
        $start = [Math]::Max(0, $logs.Count - 5)
        for ($i = $start; $i -lt $logs.Count; $i++) {
            Write-Host "  $($logs[$i])" -ForegroundColor DarkGray
        }
    }
}

# --- Screenshot info ---
$latestPng = Join-Path $CapturesDir "latest.png"
if (Test-Path $latestPng) {
    $fileInfo = Get-Item $latestPng
    $age = (Get-Date) - $fileInfo.LastWriteTime
    Write-Host "`n=== SCREENSHOT ===" -ForegroundColor Cyan
    Write-Host "  File:    $latestPng" -ForegroundColor White
    Write-Host "  Size:    $([math]::Round($fileInfo.Length / 1024, 1)) KB" -ForegroundColor White
    Write-Host "  Age:     $([math]::Round($age.TotalSeconds, 1))s ago" -ForegroundColor $(if ($age.TotalSeconds -gt 5) { "Yellow" } else { "Green" })
} else {
    Write-Host "`n  [WARN] No screenshot yet" -ForegroundColor Yellow
}
