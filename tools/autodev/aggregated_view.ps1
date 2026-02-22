# aggregated_view.ps1 -- AUTODEV v2 Aggregated Terminal View
# Launches a single Windows Terminal window with split panes in a grid layout.
# Each pane tails a worker's log file in real-time.
#
# Usage:
#   .\aggregated_view.ps1 -PaneSpecs '[{"title":"ui-ux","logFile":"path.log"},...]'
#   .\aggregated_view.ps1 -PaneSpecsFile "status/pane_specs.json"
#
# Grid layout adapts to number of panes:
#   1 pane  → 1x1      4 panes → 2x2      7 panes → 2x4
#   2 panes → 1x2      5 panes → 2x3      8 panes → 2x4
#   3 panes → 1x3      6 panes → 2x3      9 panes → 3x3

param(
    [string]$PaneSpecs = "",
    [string]$PaneSpecsFile = "",
    [string]$WindowTitle = "AUTODEV Aggregated View"
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tailScript = Join-Path $scriptDir "tail_log.ps1"

# ── Load pane specs ──────────────────────────────────────────────────
$panes = @()
if ($PaneSpecsFile -and (Test-Path $PaneSpecsFile)) {
    $panes = @(Get-Content $PaneSpecsFile -Raw | ConvertFrom-Json)
} elseif ($PaneSpecs) {
    $panes = @($PaneSpecs | ConvertFrom-Json)
}

if ($panes.Count -eq 0) {
    Write-Host "[AGGR] No panes specified. Nothing to display." -ForegroundColor Yellow
    exit 0
}

Write-Host "[AGGR] Building aggregated view for $($panes.Count) panes..." -ForegroundColor Cyan

# ── Check wt.exe availability ────────────────────────────────────────
$wtExe = Get-Command wt.exe -ErrorAction SilentlyContinue
if (-not $wtExe) {
    # Try common Windows 11 location
    $wtPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\wt.exe"
    if (Test-Path $wtPath) {
        $wtExe = $wtPath
    } else {
        Write-Host "[AGGR] Windows Terminal (wt.exe) not found." -ForegroundColor Red
        Write-Host "[AGGR] Falling back to separate windows." -ForegroundColor Yellow
        # Fallback: launch separate windows for each pane
        foreach ($p in $panes) {
            $statusArg = if ($p.statusFile) { "-StatusFile `"$($p.statusFile)`"" } else { "" }
            Start-Process powershell -ArgumentList @(
                "-ExecutionPolicy", "Bypass", "-NoProfile",
                "-File", $tailScript,
                "-LogFile", $p.logFile,
                "-Title", $p.title,
                $statusArg
            )
        }
        exit 0
    }
}

$wtCmd = if ($wtExe -is [string]) { $wtExe } else { $wtExe.Source }

# ── Calculate grid dimensions ────────────────────────────────────────
$N = $panes.Count

function Get-GridDimensions {
    param([int]$Count)

    # Prefer wider layouts (more columns than rows)
    switch ($Count) {
        1 { return @{ rows = 1; cols = 1 } }
        2 { return @{ rows = 1; cols = 2 } }
        3 { return @{ rows = 1; cols = 3 } }
        4 { return @{ rows = 2; cols = 2 } }
        5 { return @{ rows = 2; cols = 3 } }
        6 { return @{ rows = 2; cols = 3 } }
        7 { return @{ rows = 2; cols = 4 } }
        8 { return @{ rows = 2; cols = 4 } }
        9 { return @{ rows = 3; cols = 3 } }
        default {
            $rows = [math]::Ceiling([math]::Sqrt($Count))
            $cols = [math]::Ceiling($Count / $rows)
            return @{ rows = $rows; cols = $cols }
        }
    }
}

$grid = Get-GridDimensions -Count $N
$rows = $grid.rows
$cols = $grid.cols

Write-Host "[AGGR] Layout: ${rows}x${cols} grid for $N panes" -ForegroundColor Cyan

# ── Build pane command for each slot ─────────────────────────────────
function Get-PaneCommand {
    param([object]$Pane)

    $statusArg = ""
    if ($Pane.statusFile) {
        $statusArg = " -StatusFile \`"$($Pane.statusFile)\`""
    }

    return "powershell -NoProfile -ExecutionPolicy Bypass -File \`"$tailScript\`" -LogFile \`"$($Pane.logFile)\`" -Title \`"$($Pane.title)\`"$statusArg"
}

# ── Build WT command with grid layout ────────────────────────────────
#
# Algorithm:
#   1. Create first pane (new-tab)
#   2. Split horizontally for each additional row (top-to-bottom)
#   3. For each row (bottom-to-top), split vertically for columns
#   4. Navigate between rows with move-focus
#
# Split size formula for N equal parts, split #c (1-indexed):
#   size = (N - c) / (N - c + 1)

$wtArgs = @()

# Pane index mapping: row-major order
# paneIndex(row, col) = row * cols + col

# Step 1: First pane (row 0, col 0)
$cmd0 = Get-PaneCommand -Pane $panes[0]
$wtArgs += "new-tab --title `"$($panes[0].title)`" $cmd0"

# Step 2: Create additional rows by splitting horizontally
for ($r = 1; $r -lt $rows; $r++) {
    $paneIdx = $r * $cols
    if ($paneIdx -lt $N) {
        $size = [math]::Round(($rows - $r) / ($rows - $r + 1), 4)
        $cmd = Get-PaneCommand -Pane $panes[$paneIdx]
        $wtArgs += "split-pane -H -s $size --title `"$($panes[$paneIdx].title)`" $cmd"
    }
}

# Step 3: For each row, add columns (process bottom row first, then move up)
for ($r = $rows - 1; $r -ge 0; $r--) {
    # Move focus up to reach this row (if not already there)
    if ($r -lt $rows - 1) {
        $wtArgs += "move-focus up"
    }

    # Add columns for this row
    for ($c = 1; $c -lt $cols; $c++) {
        $paneIdx = $r * $cols + $c
        if ($paneIdx -lt $N) {
            $size = [math]::Round(($cols - $c) / ($cols - $c + 1), 4)
            $cmd = Get-PaneCommand -Pane $panes[$paneIdx]
            $wtArgs += "split-pane -V -s $size --title `"$($panes[$paneIdx].title)`" $cmd"
        }
    }
}

# ── Launch Windows Terminal ──────────────────────────────────────────
Write-Host "[AGGR] Launching Windows Terminal..." -ForegroundColor Green
Write-Host "[AGGR] Grid: ${rows} rows x ${cols} cols" -ForegroundColor Gray

# Build the complete WT command line as a .cmd batch file
# This avoids all PowerShell escaping issues with WT's `;` separator
$tempCmd = Join-Path $env:TEMP "autodev_wt_launch.cmd"
$cmdLine = "wt.exe --title `"$WindowTitle`" " + ($wtArgs -join " ; ")
$cmdLine | Set-Content $tempCmd -Encoding ASCII

Write-Host "[AGGR] WT command saved to: $tempCmd" -ForegroundColor Gray

# Launch via cmd /c to handle WT's semicolon-separated syntax cleanly
Start-Process cmd -ArgumentList "/c", $tempCmd -WindowStyle Hidden

Write-Host "[AGGR] Aggregated view launched." -ForegroundColor Green
