<#
.SYNOPSIS
    Launch AI Playtest suite: 4 agents (persona, visual_qa, tunnel, coherence).
    Each cycle runs ALL agents sequentially (game shared via -NoLaunch after first).
.PARAMETER Cycle
    Cycle number (used for persona rotation and report naming).
.PARAMETER Persona
    Override persona (default: rotates based on cycle number).
.PARAMETER AgentOnly
    Run only a specific agent: persona|visual_qa|tunnel|coherence (default: all).
.PARAMETER NoLaunch
    Skip game launch (game already running).
.EXAMPLE
    .\run_playtest.ps1 -Cycle 3
    .\run_playtest.ps1 -Cycle 1 -AgentOnly visual_qa
    .\run_playtest.ps1 -Cycle 2 -Persona optimizer
#>

param(
    [int]$Cycle = 0,
    [string]$Persona = "",
    [string]$AgentOnly = "",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusDir = Join-Path (Split-Path $scriptDir -Parent) "status"
$timeoutSec = 900

# Persona rotation
$personas = @("explorer", "optimizer", "roleplayer", "chaotic", "newbie")
if ($Persona -eq "") {
    $index = $Cycle % $personas.Count
    $Persona = $personas[$index]
}

# Agent definitions: name, script, extra args, needs Ollama
# Order: structural first, then gameplay, then analysis, diagnostician LAST (reads all reports)
$agents = @(
    @{ name = "tunnel";       script = "tunnel_tester.mjs";     args = @("--cycle", $Cycle);                        needsOllama = $false },
    @{ name = "blind_nav";    script = "blind_navigator.mjs";   args = @("--cycle", $Cycle, "--duration", "90");    needsOllama = $false },
    @{ name = "visual_qa";    script = "visual_qa.mjs";         args = @("--cycle", $Cycle);                        needsOllama = $true  },
    @{ name = "ux_critic";    script = "ux_critic.mjs";         args = @("--cycle", $Cycle);                        needsOllama = $true  },
    @{ name = "persona";      script = "playtester.mjs";        args = @("--persona", $Persona, "--cycle", $Cycle); needsOllama = $true  },
    @{ name = "coherence";    script = "coherence_tester.mjs";  args = @("--cycle", $Cycle);                        needsOllama = $true  },
    @{ name = "diagnostician"; script = "dev_diagnostician.mjs"; args = @("--cycle", $Cycle);                        needsOllama = $true  }
)

# Filter to single agent if requested
if ($AgentOnly -ne "") {
    $agents = @($agents | Where-Object { $_.name -eq $AgentOnly })
    if ($agents.Count -eq 0) {
        Write-Host "[PLAYTEST] Unknown agent: $AgentOnly (valid: persona, visual_qa, tunnel, coherence)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "" -ForegroundColor Cyan
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   AI PLAYTEST SUITE — Cycle $($Cycle.ToString().PadRight(9))║" -ForegroundColor Cyan
Write-Host "  ╠══════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  Agents: $($agents.Count) | Persona: $($Persona.PadRight(13))║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$totalPass = 0
$totalFail = 0
$summaryLines = @()
$isFirstAgent = $true

foreach ($agent in $agents) {
    Write-Host "[PLAYTEST] ── $($agent.name) ──" -ForegroundColor Yellow

    $nodeArgs = @((Join-Path $scriptDir $agent.script)) + $agent.args

    # First agent launches the game; subsequent agents reuse it
    if ($NoLaunch -or (-not $isFirstAgent)) {
        $nodeArgs += "--no-launch"
    }
    $isFirstAgent = $false

    $process = Start-Process -FilePath "node" -ArgumentList $nodeArgs -NoNewWindow -PassThru
    $exited = $process.WaitForExit($timeoutSec * 1000)

    if (-not $exited) {
        Write-Host "[PLAYTEST] $($agent.name) TIMEOUT after ${timeoutSec}s" -ForegroundColor Red
        $process.Kill()
        $process.WaitForExit(5000)
        $totalFail++
        $summaryLines += "  X $($agent.name): TIMEOUT"
        continue
    }

    $exitCode = $process.ExitCode
    if ($exitCode -eq 0) {
        Write-Host "[PLAYTEST] $($agent.name) PASS" -ForegroundColor Green
        $totalPass++
        $summaryLines += "  + $($agent.name): PASS"
    } elseif ($exitCode -eq 2) {
        Write-Host "[PLAYTEST] $($agent.name) WARNING (low score)" -ForegroundColor Yellow
        $totalPass++
        $summaryLines += "  ~ $($agent.name): WARNING"
    } else {
        Write-Host "[PLAYTEST] $($agent.name) FAIL (exit $exitCode)" -ForegroundColor Red
        $totalFail++
        $summaryLines += "  X $($agent.name): FAIL ($exitCode)"
    }

    # Brief pause between agents for game state to settle
    Start-Sleep -Seconds 3
}

# Write combined status
$combinedReport = @{
    cycle = $Cycle
    persona = $Persona
    timestamp = (Get-Date -Format "o")
    agents_pass = $totalPass
    agents_fail = $totalFail
    agents_total = $agents.Count
    status = if ($totalFail -eq 0) { "pass" } else { "partial" }
} | ConvertTo-Json
$combinedReport | Out-File -FilePath (Join-Path $statusDir "playtest_suite_report.json") -Encoding utf8 -Force

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })
Write-Host "  ║   PLAYTEST SUITE SUMMARY              ║" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })
Write-Host "  ╠══════════════════════════════════════╣" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })
foreach ($line in $summaryLines) {
    Write-Host "  ║ $($line.PadRight(37))║" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })
}
Write-Host "  ╠══════════════════════════════════════╣" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })
Write-Host "  ║  Result: $totalPass/$($agents.Count) passed                  ║" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Yellow" })

if ($totalFail -gt 0) { exit 1 }
exit 0
