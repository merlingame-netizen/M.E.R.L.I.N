# debug_loop.ps1 — Recursive Automated Debug Loop for M.E.R.L.I.N. orchestrator_v2
# Spawned when a bug is detected. Assigns to expert agent, validates, loops until convergence.
# Usage: .\debug_loop.ps1 -IssueType "parse_error" -IssueDescription "..." [-AffectedFile "..."] [-ErrorLog "..."] [-MaxIterations 10] [-DryRun]

param(
    [string]$IssueType        = "parse_error",
    [string]$IssueDescription = "",
    [string]$AffectedFile     = "",
    [string]$ErrorLog         = "",
    [int]$MaxIterations       = 10,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# BOOTSTRAP
# ---------------------------------------------------------------------------

$autodevRoot = $PSScriptRoot | Split-Path -Parent          # loops → autodev
$projectRoot = $autodevRoot  | Split-Path -Parent | Split-Path -Parent  # autodev → tools → project root

# Dot-source agent bridge
$bridgePath = Join-Path $autodevRoot "agent_bridge.ps1"
if (-not (Test-Path $bridgePath)) {
    Write-Error "[DebugLoop] agent_bridge.ps1 not found at $bridgePath"
    exit 1
}
. $bridgePath

$statusDir = Join-Path $autodevRoot "status"
$memoryDir = Join-Path $autodevRoot "memory"
$historyPath = Join-Path $statusDir "debug_history.json"
$memoryPath  = Join-Path $memoryDir "debugger_memory.json"

@($statusDir, $memoryDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# ---------------------------------------------------------------------------
# ROUTING TABLE
# ---------------------------------------------------------------------------

$ROUTE_TABLE = @{
    "parse_error"     = @("godot_expert")
    "runtime_crash"   = @("godot_expert", "debug_qa")
    "validation_fail" = @("godot_expert")
    "test_fail"       = @("debug_qa")
    "logic_bug"       = @("godot_expert", "narrative_writer")
}
$AGENT_ROTATION = @("godot_expert", "debug_qa", "narrative_writer", "godot_expert")

# ---------------------------------------------------------------------------
# HELPER: Invoke-Validation
# ---------------------------------------------------------------------------

function Invoke-Validation {
    try {
        $output = & cmd /c "cd /d `"$projectRoot`" && .\validate.bat 2>&1"
    } catch {
        $output = @("[Invoke-Validation] Exception: $_")
    }
    $joined  = $output -join "`n"
    $success = ($LASTEXITCODE -eq 0) -and ($joined -notmatch "\bERROR\b")
    $errors  = ($output | Select-String "ERROR:"   | Measure-Object).Count
    $warns   = ($output | Select-String "WARNING:" | Measure-Object).Count
    return @{
        Success      = $success
        ErrorCount   = $errors
        WarningCount = $warns
        ErrorText    = $joined
        RawOutput    = $output
    }
}

# ---------------------------------------------------------------------------
# HELPER: Build-FixPrompt
# ---------------------------------------------------------------------------

function Build-FixPrompt {
    param([string]$IssueType, [string]$ErrorLog, [string]$AffectedFile, [int]$Iteration)

    $base = "Fix the following $IssueType in $AffectedFile.`n`nError:`n$ErrorLog"
    if ($Iteration -ge 3) {
        $histSummary = Get-DebugHistorySummary
        return "Previous $($Iteration - 1) fix attempts failed. Try a COMPLETELY DIFFERENT approach.`n$base`n`nAttempt history:`n$histSummary"
    }
    return $base
}

# ---------------------------------------------------------------------------
# HELPER: Get-AlternativeAgent
# ---------------------------------------------------------------------------

function Get-AlternativeAgent {
    param([string]$CurrentAgent)
    $idx = [Array]::IndexOf($AGENT_ROTATION, $CurrentAgent)
    $next = ($idx + 1) % $AGENT_ROTATION.Count
    return $AGENT_ROTATION[$next]
}

# ---------------------------------------------------------------------------
# HELPER: Invoke-ClaudeAgent
# ---------------------------------------------------------------------------

function Invoke-ClaudeAgent {
    param([string]$AgentName, [string]$Prompt)

    if ($DryRun) {
        Write-Host "[DebugLoop] [DRY-RUN] Would invoke $AgentName`: $($Prompt.Substring(0, [Math]::Min(120, $Prompt.Length)))..."
        return
    }

    $claudeAvailable = Get-Command "claude" -ErrorAction SilentlyContinue
    if ($claudeAvailable) {
        Write-Host "[DebugLoop] Invoking claude agent: $AgentName"
        $Prompt | & claude --agent $AgentName 2>&1 | Write-Host
    } else {
        Write-Warning "[DebugLoop] claude CLI not found — skipping agent call for $AgentName"
    }
}

# ---------------------------------------------------------------------------
# HELPER: Add-DebugHistoryEntry
# ---------------------------------------------------------------------------

function Add-DebugHistoryEntry {
    param([int]$Iteration, [string]$Agent, [string]$ErrorBefore, [string]$ErrorAfter, [bool]$Success)

    try {
        $history = if (Test-Path $historyPath) {
            Get-Content $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } else { $null }

        $entries = if ($history -and $history.entries) { [System.Collections.ArrayList]@($history.entries) } else { [System.Collections.ArrayList]@() }

        [void]$entries.Add(@{
            iteration   = $Iteration
            agent       = $Agent
            error_before = $ErrorBefore.Substring(0, [Math]::Min(500, $ErrorBefore.Length))
            error_after  = $ErrorAfter.Substring(0,  [Math]::Min(500, $ErrorAfter.Length))
            success     = $Success
            timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        })

        @{ session_id = $script:sessionId; entries = @($entries) } |
            ConvertTo-Json -Depth 10 |
            Set-Content -Path $historyPath -Encoding UTF8
    } catch {
        Write-Warning "[DebugLoop] Could not write debug history: $_"
    }
}

# ---------------------------------------------------------------------------
# HELPER: Get-DebugHistorySummary
# ---------------------------------------------------------------------------

function Get-DebugHistorySummary {
    try {
        if (-not (Test-Path $historyPath)) { return "(no history yet)" }
        $h = Get-Content $historyPath -Raw | ConvertFrom-Json
        return ($h.entries | ForEach-Object { "  Iter $($_.iteration) [$($_.agent)]: $(($_.error_after ?? '') -replace '\n',' ' | Select-Object -First 1 | ForEach-Object { $_.Substring(0, [Math]::Min(100, $_.Length)) })" }) -join "`n"
    } catch { return "(history unreadable)" }
}

# ---------------------------------------------------------------------------
# HELPER: Update-DebuggerMemory
# ---------------------------------------------------------------------------

function Update-DebuggerMemory {
    param([string]$IssueSignature, [string]$Outcome, [int]$Iterations)

    try {
        $mem = if (Test-Path $memoryPath) {
            Get-Content $memoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } else { $null }

        if (-not $mem) {
            $mem = @{
                agent        = "debugger"
                version      = "2.0"
                created_at   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                last_updated = $null
                patterns     = @()
                confidence_weights = @{
                    decay_factor        = 0.8
                    success_boost       = 0.2
                    failure_penalty     = 0.3
                    new_pattern_baseline = 0.5
                }
            }
        }

        $patterns = [System.Collections.ArrayList]@(if ($mem.patterns) { @($mem.patterns) } else { @() })
        $found = $false
        $isSuccess = ($Outcome -eq "success")

        for ($i = 0; $i -lt $patterns.Count; $i++) {
            $p = $patterns[$i]
            if ($p.issue_signature -eq $IssueSignature) {
                $oldConf = [double]($p.confidence ?? 0.5)
                $boost   = if ($isSuccess) { 0.2 } else { -0.3 }
                $newConf = [Math]::Round([Math]::Max(0.0, [Math]::Min(1.0, 0.8 * $oldConf + $boost)), 3)
                $patterns[$i] = @{
                    issue_signature = $IssueSignature
                    confidence      = $newConf
                    last_outcome    = $Outcome
                    last_iterations = $Iterations
                    last_seen       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                }
                $found = $true
                break
            }
        }

        if (-not $found) {
            [void]$patterns.Add(@{
                issue_signature = $IssueSignature
                confidence      = 0.5
                last_outcome    = $Outcome
                last_iterations = $Iterations
                last_seen       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            })
        }

        $memHt = @{
            agent        = "debugger"
            version      = "2.0"
            created_at   = ($mem.created_at ?? (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))
            last_updated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            patterns     = @($patterns)
            confidence_weights = @{
                decay_factor        = 0.8
                success_boost       = 0.2
                failure_penalty     = 0.3
                new_pattern_baseline = 0.5
            }
        }
        $memHt | ConvertTo-Json -Depth 10 | Set-Content -Path $memoryPath -Encoding UTF8

    } catch {
        Write-Warning "[DebugLoop] Could not update debugger memory: $_"
    }
}

# ---------------------------------------------------------------------------
# STEP 0: Initialize
# ---------------------------------------------------------------------------

$script:sessionId    = "dbg_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$issueSignature      = "$IssueType`:$AffectedFile"

Write-Host "[DebugLoop] START: $IssueType — $AffectedFile" -ForegroundColor Cyan

Update-AgentStatus -AgentName "debugger" -State "running" -AdditionalFields @{
    iteration       = 0
    max_iterations  = $MaxIterations
    issue_signature = $issueSignature
    session_id      = $script:sessionId
}

# Initialize debug_history.json
@{ session_id = $script:sessionId; started_at = (Get-Date -Format "o"); entries = @() } |
    ConvertTo-Json -Depth 5 |
    Set-Content -Path $historyPath -Encoding UTF8

# ---------------------------------------------------------------------------
# STEP 1: Route to expert agent + check memory confidence
# ---------------------------------------------------------------------------

$expertAgents = $ROUTE_TABLE[$IssueType]
if (-not $expertAgents) { $expertAgents = @("godot_expert") }
$expertAgent = $expertAgents[0]

# Check memory for high-confidence prior fix
$memCheck = if (Test-Path $memoryPath) { Get-Content $memoryPath -Raw | ConvertFrom-Json } else { $null }
if ($memCheck -and $memCheck.patterns) {
    $prior = @($memCheck.patterns) | Where-Object { $_.issue_signature -eq $issueSignature } | Select-Object -First 1
    if ($prior -and [double]$prior.confidence -gt 0.85) {
        Write-Host "[DebugLoop] High confidence fix available (conf=$($prior.confidence)): last outcome=$($prior.last_outcome) in $($prior.last_iterations) iter(s)" -ForegroundColor Green
    }
}

Write-Host "[DebugLoop] Routed to: $expertAgent (issue_type=$IssueType)" -ForegroundColor Yellow

# ---------------------------------------------------------------------------
# STEP 2: Main Loop
# ---------------------------------------------------------------------------

$iteration            = 0
$converged            = $false
$consecutiveSameError = 0
$lastErrorText        = ""

while ($iteration -lt $MaxIterations) {
    $iteration++

    Update-AgentStatus -AgentName "debugger" -State "running" -AdditionalFields @{ iteration = $iteration }

    Write-Host "[DebugLoop] Iteration $iteration/$MaxIterations — $IssueType in $AffectedFile (agent: $expertAgent)"

    # Convergence-failure guard: same error 3x in a row → switch agent
    if ($consecutiveSameError -ge 3) {
        Write-Warning "[DebugLoop] Same error 3x consecutive — switching approach"
        $expertAgent          = Get-AlternativeAgent -CurrentAgent $expertAgent
        $consecutiveSameError = 0
        Write-Host "[DebugLoop] Switched to: $expertAgent" -ForegroundColor Magenta
    }

    # Invoke expert agent
    $fixPrompt = Build-FixPrompt -IssueType $IssueType -ErrorLog $ErrorLog -AffectedFile $AffectedFile -Iteration $iteration
    Invoke-ClaudeAgent -AgentName $expertAgent -Prompt $fixPrompt

    # Validate
    $result = Invoke-Validation

    if ($result.Success) {
        $converged = $true
        Add-DebugHistoryEntry -Iteration $iteration -Agent $expertAgent -ErrorBefore $ErrorLog -ErrorAfter "" -Success $true
        break
    }

    # Record failed attempt
    Add-DebugHistoryEntry -Iteration $iteration -Agent $expertAgent -ErrorBefore $ErrorLog -ErrorAfter $result.ErrorText -Success $false

    # Track consecutive same-error
    if ($result.ErrorText -eq $lastErrorText) { $consecutiveSameError++ }
    else { $consecutiveSameError = 0 }

    $lastErrorText = $result.ErrorText
    $ErrorLog      = $result.ErrorText   # update for next iteration's prompt
}

# ---------------------------------------------------------------------------
# STEP 3: Post-Loop Actions
# ---------------------------------------------------------------------------

if ($converged) {
    Write-Host "[DebugLoop] CONVERGED after $iteration iteration(s)" -ForegroundColor Green

    Send-AgentMessage -FromAgent "debugger" -ToAgent "orchestrator" -Type "debug_result" -Priority "HIGH" -Payload @{
        success          = $true
        iterations       = $iteration
        fixed_file       = $AffectedFile
        solution_summary = "Fixed $IssueType in $AffectedFile after $iteration iteration(s)"
        session_id       = $script:sessionId
    }

    Update-DebuggerMemory -IssueSignature $issueSignature -Outcome "success" -Iterations $iteration

    Send-AgentMessage -FromAgent "debugger" -ToAgent "orchestrator" -Type "kb_entry" -Priority "MEDIUM" -Payload @{
        type    = "fix_recipe"
        title   = "Fixed $IssueType in $AffectedFile"
        pattern = $IssueDescription
        outcome = "Resolved in $iteration iteration(s)"
        tags    = @($IssueType, $AffectedFile)
    }

    Update-AgentStatus -AgentName "debugger" -State "done" -AdditionalFields @{ session_id = $script:sessionId }
    exit 0

} else {
    Write-Host "[DebugLoop] ESCALATING after $MaxIterations iteration(s) — no convergence" -ForegroundColor Red

    $histSummary      = Get-DebugHistorySummary
    $escalationQ      = "Je suis bloque sur '$IssueType' dans '$AffectedFile' apres $MaxIterations tentatives.`nHistorique:`n$histSummary`nQuelle approche suggeres-tu ?"

    Send-AgentMessage -FromAgent "debugger" -ToAgent "orchestrator" -Type "question_for_user" -Priority "CRITICAL" -Payload @{
        question           = $escalationQ
        debug_history_path = "status/debug_history.json"
        attempts           = $MaxIterations
        issue_type         = $IssueType
        affected_file      = $AffectedFile
        session_id         = $script:sessionId
    }

    Send-AgentMessage -FromAgent "debugger" -ToAgent "orchestrator" -Type "kb_entry" -Priority "LOW" -Payload @{
        type    = "anti_pattern"
        title   = "Non-convergent: $IssueType in $AffectedFile"
        pattern = $IssueDescription
        outcome = "Ce qui n'a pas fonctionne apres $MaxIterations essais"
        tags    = @($IssueType, $AffectedFile, "anti_pattern")
    }

    Update-DebuggerMemory -IssueSignature $issueSignature -Outcome "failure" -Iterations $MaxIterations

    Update-AgentStatus -AgentName "debugger" -State "blocked" -AdditionalFields @{
        blocked_reason = "max_iterations_reached"
        session_id     = $script:sessionId
    }
    exit 1
}
