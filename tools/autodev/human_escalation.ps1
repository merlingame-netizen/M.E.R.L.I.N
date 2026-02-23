# human_escalation.ps1 -- AUTODEV v3: Human escalation handler
# Usage:
#   .\human_escalation.ps1 -Action Wait -Cycle 1 [-TimeoutHours 24]  # Wait for human response
#   .\human_escalation.ps1 -Action Respond -Decision "proceed"       # Human responds
#   .\human_escalation.ps1 -Action Respond -Decision "rollback"      # Human responds
#   .\human_escalation.ps1 -Action Respond -Decision "custom" -Details "fix gameplay only"
#   .\human_escalation.ps1 -Action Status                            # Show escalation state

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Wait", "Respond", "Status")]
    [string]$Action,

    [int]$Cycle = 0,
    [string]$Decision = "",
    [string]$Details = "",
    [int]$TimeoutHours = 24
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"

# Escalation files
$questionsFile = Join-Path $statusDir "director_questions.json"
$responseFile = Join-Path $statusDir "human_response.json"
$controlFile = Join-Path $statusDir "control_state.json"

# Ensure directories
@($statusDir, $logDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# ── Helpers ────────────────────────────────────────────────────────────

function Write-EscalationLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$ts] [$Level] $Message"
    $logFile = Join-Path $logDir "escalation.log"
    Add-Content -Path $logFile -Value $logLine -Encoding UTF8
    $color = switch ($Level) {
        "INFO"    { "Gray" }
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "HUMAN"   { "Cyan" }
        default   { "White" }
    }
    Write-Host "[ESCALATION] $Message" -ForegroundColor $color
}

function Update-ControlState {
    param([string]$State, [string]$Detail = "")
    if (Test-Path $controlFile) {
        $control = Get-Content $controlFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($control) {
            $control.state = $State
            $control.detail = $Detail
            $control.timestamp = (Get-Date -Format "o")
            $control | ConvertTo-Json -Depth 3 | Set-Content $controlFile -Encoding UTF8
        }
    }
}

# ── ACTION: Wait ───────────────────────────────────────────────────────
# Blocks the pipeline until human responds or timeout expires

function Invoke-WaitForHuman {
    param([int]$CycleNum, [int]$MaxHours)

    # Verify director_questions.json exists (Director must have escalated)
    if (-not (Test-Path $questionsFile)) {
        Write-EscalationLog "No director_questions.json found --nothing to escalate" "WARN"
        return @{ decision = "proceed"; reason = "no_escalation" }
    }

    $questions = Get-Content $questionsFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $questions) {
        Write-EscalationLog "Failed to parse director_questions.json" "ERROR"
        return @{ decision = "proceed"; reason = "parse_error" }
    }

    # Display escalation to dashboard
    Write-EscalationLog "=== DIRECTOR ESCALATION (Cycle $CycleNum) ===" "HUMAN"
    Write-EscalationLog "Reason: $($questions.escalation_reason)" "HUMAN"
    Write-EscalationLog "Confidence: $($questions.confidence)%" "HUMAN"

    if ($questions.questions) {
        Write-EscalationLog "Questions:" "HUMAN"
        $i = 1
        foreach ($q in $questions.questions) {
            Write-EscalationLog "  $i. $q" "HUMAN"
            $i++
        }
    }

    if ($questions.suggested_options) {
        Write-EscalationLog "Suggested options:" "HUMAN"
        foreach ($opt in $questions.suggested_options) {
            Write-EscalationLog "  - $opt" "HUMAN"
        }
    }

    Write-EscalationLog "" "INFO"
    Write-EscalationLog "Waiting for response via Claude Code (human_response.json)" "HUMAN"
    Write-EscalationLog "Timeout: ${MaxHours}h (auto-rollback after timeout)" "WARN"

    # Update control state to waiting_human
    Update-ControlState -State "waiting_human" -Detail "Escalation cycle $CycleNum --awaiting human decision"

    # Notify (suppress output to avoid polluting function return)
    & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") `
        -Event "escalation" -Message "Director ESCALATED (cycle $CycleNum)" `
        -Details $questions.escalation_reason | Out-Null

    # Remove stale response file
    if (Test-Path $responseFile) {
        Remove-Item $responseFile -Force
    }

    # Poll loop
    $pollIntervalSeconds = 30
    $maxSeconds = $MaxHours * 3600
    $elapsed = 0

    while ($elapsed -lt $maxSeconds) {
        # Check for VETO (emergency stop)
        if (Test-Path (Join-Path $scriptDir "VETO")) {
            Write-EscalationLog "VETO detected during escalation wait" "WARN"
            return @{ decision = "veto"; reason = "veto_file" }
        }

        # Check for human response
        if (Test-Path $responseFile) {
            $response = Get-Content $responseFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($response -and $response.decision) {
                Write-EscalationLog "Human responded: $($response.decision)" "OK"

                # Validate decision
                $validDecisions = @("proceed", "rollback", "custom", "override")
                if ($response.decision -notin $validDecisions) {
                    Write-EscalationLog "Invalid decision '$($response.decision)', treating as 'proceed'" "WARN"
                    $response.decision = "proceed"
                }

                # Update control state back to running
                Update-ControlState -State "running" -Detail "Human responded: $($response.decision)"

                return @{
                    decision = $response.decision
                    details  = if ($response.details) { $response.details } else { "" }
                    reason   = "human_response"
                }
            }
        }

        # Status display every 5 minutes
        if ($elapsed % 300 -eq 0 -and $elapsed -gt 0) {
            $secsLeft = $maxSeconds - $elapsed
            $hrsLeft = [int]($secsLeft / 3600)
            $minsLeft = [int](($secsLeft % 3600) / 60)
            Write-EscalationLog "Still waiting... (${hrsLeft}h ${minsLeft}m remaining)" "INFO"
        }

        Start-Sleep -Seconds $pollIntervalSeconds
        $elapsed += $pollIntervalSeconds
    }

    # Timeout reached --auto-rollback
    Write-EscalationLog "TIMEOUT (${MaxHours}h) --triggering auto-rollback" "ERROR"

    & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") `
        -Event "escalation_timeout" -Message "Escalation timeout after ${MaxHours}h --auto-rollback" | Out-Null

    return @{ decision = "rollback"; reason = "timeout" }
}

# ── ACTION: Respond ────────────────────────────────────────────────────
# Human writes response file for the waiting pipeline

function Invoke-HumanRespond {
    param([string]$Dec, [string]$Det)

    if (-not $Dec) {
        Write-EscalationLog "Respond requires -Decision" "ERROR"
        return $false
    }

    $validDecisions = @("proceed", "rollback", "custom", "override")
    if ($Dec -notin $validDecisions) {
        Write-EscalationLog "Invalid decision '$Dec'. Valid: $($validDecisions -join ', ')" "ERROR"
        return $false
    }

    # Check if pipeline is actually waiting
    if (Test-Path $controlFile) {
        $control = Get-Content $controlFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($control -and $control.state -ne "waiting_human") {
            Write-EscalationLog "Pipeline state is '$($control.state)', not 'waiting_human'" "WARN"
            Write-EscalationLog "Writing response anyway (pipeline may pick it up)" "INFO"
        }
    }

    $response = @{
        decision    = $Dec
        details     = $Det
        responded_by = "human"
        timestamp   = (Get-Date -Format "o")
    }

    $response | ConvertTo-Json -Depth 3 | Set-Content $responseFile -Encoding UTF8
    Write-EscalationLog "Response written: $Dec" "OK"
    if ($Det) { Write-EscalationLog "Details: $Det" "INFO" }

    # Log response
    $logEntry = @{
        action      = "human_response"
        decision    = $Dec
        details     = $Det
        timestamp   = (Get-Date -Format "o")
    }
    $escLogFile = Join-Path $statusDir "escalation_history.json"
    $history = @()
    if (Test-Path $escLogFile) {
        $history = @(Get-Content $escLogFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue)
    }
    $history += $logEntry
    $history | ConvertTo-Json -Depth 5 | Set-Content $escLogFile -Encoding UTF8

    return $true
}

# ── ACTION: Status ─────────────────────────────────────────────────────

function Show-EscalationStatus {
    Write-Host "`n[ESCALATION] ========== Status ==========" -ForegroundColor Cyan

    # Current control state
    if (Test-Path $controlFile) {
        $control = Get-Content $controlFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($control) {
            $isWaiting = $control.state -eq "waiting_human"
            $color = if ($isWaiting) { "Yellow" } else { "Green" }
            Write-Host "  Pipeline state: $($control.state)" -ForegroundColor $color
            Write-Host "  Detail: $($control.detail)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No pipeline state found" -ForegroundColor Gray
    }

    # Pending questions
    if (Test-Path $questionsFile) {
        $questions = Get-Content $questionsFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($questions) {
            Write-Host "`n  --- Pending Questions ---" -ForegroundColor Yellow
            Write-Host "  Reason: $($questions.escalation_reason)" -ForegroundColor Yellow
            Write-Host "  Confidence: $($questions.confidence)%" -ForegroundColor Yellow
            if ($questions.questions) {
                foreach ($q in $questions.questions) {
                    Write-Host "    ? $q" -ForegroundColor White
                }
            }
        }
    } else {
        Write-Host "`n  No pending escalation" -ForegroundColor Green
    }

    # Response file
    if (Test-Path $responseFile) {
        $response = Get-Content $responseFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($response) {
            Write-Host "`n  --- Last Response ---" -ForegroundColor Cyan
            Write-Host "  Decision: $($response.decision)" -ForegroundColor Green
            if ($response.details) { Write-Host "  Details: $($response.details)" -ForegroundColor Gray }
            Write-Host "  Time: $($response.timestamp)" -ForegroundColor Gray
        }
    }

    # History
    $escLogFile = Join-Path $statusDir "escalation_history.json"
    if (Test-Path $escLogFile) {
        $history = Get-Content $escLogFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($history -and $history.Count -gt 0) {
            Write-Host "`n  --- History ($($history.Count) events) ---" -ForegroundColor Cyan
            $history | Select-Object -Last 5 | ForEach-Object {
                Write-Host "    [$($_.timestamp)] $($_.decision) $(if($_.details){': '+$_.details})" -ForegroundColor Gray
            }
        }
    }

    Write-Host "[ESCALATION] ============================" -ForegroundColor Cyan
}

# ── Main ───────────────────────────────────────────────────────────────

Write-Host "[ESCALATION] ========================================" -ForegroundColor Magenta
Write-Host "  AUTODEV v3 Human Escalation Handler" -ForegroundColor Magenta
Write-Host "  Action: $Action" -ForegroundColor Magenta
Write-Host "[ESCALATION] ========================================" -ForegroundColor Magenta

switch ($Action) {
    "Wait" {
        $result = Invoke-WaitForHuman -CycleNum $Cycle -MaxHours $TimeoutHours
        # Output result as JSON for caller (cycle_runner) to parse
        $result | ConvertTo-Json -Depth 3
    }
    "Respond" {
        $success = Invoke-HumanRespond -Dec $Decision -Det $Details
        if (-not $success) { exit 1 }
    }
    "Status" {
        Show-EscalationStatus
    }
}
