# knowledge_recorder.ps1 — Continuous Learning & Knowledge Base Recorder v1.0
# Called by the orchestrator_v2 at the end of each cycle (REPORT state).
# Harvests kb_entry messages from the bus, updates BEST_PRACTICES.md,
# project_map.json, and per-agent confidence weights in memory/*.json.
# Usage: .\knowledge_recorder.ps1 -CycleNumber 3 -ValidationResult "success" -FilesModified @("foo.gd") -ErrorsFixed 2

param(
    [int]$CycleNumber         = 0,
    [string[]]$FilesModified  = @(),
    [string]$ValidationResult = "partial",   # "success" | "partial" | "failed"
    [int]$ErrorsFixed         = 0,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# BOOTSTRAP
# ---------------------------------------------------------------------------

$autodevRoot = $PSScriptRoot | Split-Path -Parent           # loops → autodev
$projectRoot = $autodevRoot  | Split-Path -Parent | Split-Path -Parent  # autodev → tools → root

$bridgePath = Join-Path $autodevRoot "agent_bridge.ps1"
if (-not (Test-Path $bridgePath)) {
    Write-Error "[KB] agent_bridge.ps1 not found at $bridgePath"
    exit 1
}
. $bridgePath

$statusDir     = Join-Path $autodevRoot "status"
$memoryDir     = Join-Path $autodevRoot "memory"
$kbEntriesPath = Join-Path $statusDir   "kb_entries.jsonl"
$projectMapPath = Join-Path $autodevRoot "project_map.json"
$bestPracticesPath = Join-Path $projectRoot "docs" "BEST_PRACTICES.md"

# Ensure directories exist
@($statusDir, $memoryDir, (Split-Path $bestPracticesPath -Parent)) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

Write-Host "[KB] START — cycle $CycleNumber (validation: $ValidationResult, errors fixed: $ErrorsFixed)"
if ($DryRun) { Write-Host "[KB] DRY-RUN mode — no files will be written" }

# ---------------------------------------------------------------------------
# AGENT STATUS: running
# ---------------------------------------------------------------------------

Update-AgentStatus -AgentName "knowledge_keeper" -State "running" `
    -AdditionalFields @{ cycle = $CycleNumber; task = "harvesting_kb" }

# ---------------------------------------------------------------------------
# STEP 1: Harvest KB entries from the message bus
# ---------------------------------------------------------------------------

$kbMessages = Read-PendingMessages -Type "kb_entry"
Write-Host "[KB] Harvested $($kbMessages.Count) KB entries from message bus"

$addedIds = @()

foreach ($msg in $kbMessages) {
    $ts  = Get-Date -Format "yyyyMMdd_HHmmss"
    $rnd = (Get-Random -Maximum 999).ToString("D3")
    $entryId = "kb_${ts}_${rnd}"

    $entry = [ordered]@{
        id         = $entryId
        timestamp  = (Get-Date -Format "o")
        agent      = $msg.from_agent
        type       = if ($msg.payload.type)       { $msg.payload.type }       else { "best_practice" }
        title      = if ($msg.payload.title)      { $msg.payload.title }      else { "(untitled)" }
        pattern    = if ($msg.payload.pattern)    { $msg.payload.pattern }    else { $null }
        context    = if ($msg.payload.context)    { $msg.payload.context }    else { $null }
        outcome    = if ($msg.payload.outcome)    { $msg.payload.outcome }    else { $null }
        confidence = if ($null -ne $msg.payload.confidence) { $msg.payload.confidence } else { 0.75 }
        tags       = if ($msg.payload.tags)       { @($msg.payload.tags) }    else { @() }
        cycle      = $CycleNumber
    }

    $jsonLine = $entry | ConvertTo-Json -Compress -Depth 10
    if (-not $DryRun) {
        Add-Content -Path $kbEntriesPath -Value $jsonLine -Encoding UTF8
    }

    if (-not $DryRun) {
        Mark-MessageHandled -MessageId $msg.id
    }
    $addedIds += $entryId
}

Write-Host "[KB] Appended $($addedIds.Count) entries to kb_entries.jsonl"

# ---------------------------------------------------------------------------
# STEP 2: Read ALL existing kb entries (for BEST_PRACTICES.md regeneration)
# ---------------------------------------------------------------------------

$allKbEntries = @()
if (Test-Path $kbEntriesPath) {
    $lines = Get-Content -Path $kbEntriesPath -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }
    foreach ($line in $lines) {
        try {
            $allKbEntries += ($line | ConvertFrom-Json)
        } catch {
            Write-Warning "[KB] Could not parse kb entry line: $($line.Substring(0, [Math]::Min(80, $line.Length)))"
        }
    }
}

Write-Host "[KB] Total KB entries loaded: $($allKbEntries.Count)"

# ---------------------------------------------------------------------------
# STEP 3: Regenerate BEST_PRACTICES.md
# ---------------------------------------------------------------------------

function Render-Section {
    param(
        [string]$Title,
        [string]$TypeKey,
        [array]$AllEntries
    )

    $entries = @($AllEntries | Where-Object { $_.type -eq $TypeKey } | Sort-Object -Property confidence -Descending)
    if ($entries.Count -eq 0) { return @() }

    $lines = @()
    $lines += "## $Title"
    $lines += ""

    foreach ($e in $entries) {
        $confPct = [int](([double]$e.confidence) * 100)
        $lines += "### $($e.title) — Confidence: $confPct%"
        if ($e.pattern) { $lines += "**Pattern:** $($e.pattern)" }
        if ($e.context) { $lines += "**Context:** $($e.context)" }
        if ($e.outcome) { $lines += "**Outcome:** $($e.outcome)" }
        if ($e.tags -and @($e.tags).Count -gt 0) {
            $lines += "**Tags:** $(@($e.tags) -join ', ')"
        }
        $lines += "*Recorded by $($e.agent) at cycle $($e.cycle)*"
        $lines += ""
        $lines += "---"
        $lines += ""
    }

    return $lines
}

function Update-BestPracticesDoc {
    param(
        [array]$AllEntries,
        [int]$CurrentCycle
    )

    $now     = Get-Date -Format "yyyy-MM-dd HH:mm"
    $content = @()
    $content += "# M.E.R.L.I.N. — Best Practices & Lessons Learned"
    $content += ""
    $content += "> Auto-generated by knowledge_recorder.ps1. Last updated: $now"
    $content += "> Total entries: $($AllEntries.Count) | Last cycle: $CurrentCycle"
    $content += ""

    $sections = @(
        @{ Title = "Best Practices";                  Key = "best_practice"    }
        @{ Title = "Anti-Patterns (What NOT to Do)";  Key = "anti_pattern"     }
        @{ Title = "Fix Recipes (Confirmed Solutions)"; Key = "fix_recipe"     }
        @{ Title = "Design Decisions (Locked)";       Key = "design_decision"  }
    )

    $anySection = $false
    foreach ($s in $sections) {
        $rendered = Render-Section -Title $s.Title -TypeKey $s.Key -AllEntries $AllEntries
        if ($rendered.Count -gt 0) {
            $content += $rendered
            $anySection = $true
        }
    }

    if (-not $anySection) {
        $content += "*No entries recorded yet.*"
        $content += ""
    }

    return $content
}

$docContent = Update-BestPracticesDoc -AllEntries $allKbEntries -CurrentCycle $CycleNumber

if (-not $DryRun) {
    Set-Content -Path $bestPracticesPath -Value ($docContent -join "`n") -Encoding UTF8
    Write-Host "[KB] Updated BEST_PRACTICES.md (total: $($allKbEntries.Count) entries)"
} else {
    Write-Host "[KB] DRY-RUN: would write BEST_PRACTICES.md ($($docContent.Count) lines)"
}

# ---------------------------------------------------------------------------
# STEP 4: Update project_map.json
# ---------------------------------------------------------------------------

function Update-ProjectMap {
    param(
        [string]$MapPath,
        [int]$CurrentCycle,
        [string[]]$Modified,
        [string]$ValResult
    )

    if (-not (Test-Path $MapPath)) {
        Write-Warning "[KB] project_map.json not found at $MapPath — skipping"
        return
    }

    try {
        $map = Get-Content -Path $MapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "[KB] Could not parse project_map.json: $_"
        return
    }

    # Update top-level metadata
    $map.cycle_count  = $CurrentCycle
    $map.last_updated = (Get-Date -Format "o")

    # Update per-system status for modified files
    $today = Get-Date -Format "yyyy-MM-dd"
    foreach ($file in $Modified) {
        $systemName = [System.IO.Path]::GetFileName($file)
        if ($map.systems.$systemName) {
            $map.systems.$systemName.last_modified = $today
            if ($ValResult -eq "success") {
                $map.systems.$systemName.status       = "stable"
                $map.systems.$systemName.known_issues = @()
            } elseif ($ValResult -eq "failed") {
                # Preserve current status, just timestamp
                if ($map.systems.$systemName.status -eq "stable") {
                    $map.systems.$systemName.status = "needs_review"
                }
            }
        }
        # If the system is not in the map, silently skip (no new entries added here)
    }

    if (-not $DryRun) {
        $map | ConvertTo-Json -Depth 20 | Set-Content -Path $MapPath -Encoding UTF8
        Write-Host "[KB] Updated project_map.json (cycle: $CurrentCycle)"
    } else {
        Write-Host "[KB] DRY-RUN: would update project_map.json (cycle: $CurrentCycle)"
    }
}

Update-ProjectMap -MapPath $projectMapPath -CurrentCycle $CycleNumber `
    -Modified $FilesModified -ValResult $ValidationResult

# ---------------------------------------------------------------------------
# STEP 5: Update per-agent confidence weights in memory/*.json
# ---------------------------------------------------------------------------

function Update-AllAgentConfidences {
    param(
        [string]$MemDir,
        [array]$KbEntries,
        [string]$ValResult
    )

    if ($KbEntries.Count -eq 0) { return }

    $agentGroups = $KbEntries | Group-Object -Property from_agent

    # outcome score: 1 = full credit, 0.5 = partial, 0 = failure
    $outcomeScore = switch ($ValResult) {
        "success" { 1.0 }
        "partial" { 0.5 }
        default   { 0.0 }
    }

    foreach ($group in $agentGroups) {
        $agentName = $group.Name
        $memFile   = Join-Path $MemDir "${agentName}_memory.json"

        if (-not (Test-Path $memFile)) {
            Write-Host "[KB] No memory file for agent '$agentName' — skipping confidence update"
            continue
        }

        try {
            $memory = Get-Content -Path $memFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Warning "[KB] Could not parse memory file $memFile: $_"
            continue
        }

        # Apply slow decay (0.95) to all existing decision confidences
        if ($memory.decisions) {
            foreach ($decision in $memory.decisions) {
                $current = [double]($decision.confidence ?? 0.75)
                $decayed = [Math]::Round([Math]::Max(0.1, 0.95 * $current), 4)
                $decision.confidence = $decayed
            }
        }

        # Record the cycle outcome contribution
        if (-not $memory.cycle_outcomes) {
            $memory | Add-Member -NotePropertyName "cycle_outcomes" -NotePropertyValue @() -Force
        }
        $cycleRecord = [ordered]@{
            cycle         = $CycleNumber
            outcome_score = $outcomeScore
            kb_entries    = $group.Count
            timestamp     = (Get-Date -Format "o")
        }
        $memory.cycle_outcomes = @($memory.cycle_outcomes) + @($cycleRecord)

        $memory.last_updated = (Get-Date -Format "o")

        if (-not $DryRun) {
            $memory | ConvertTo-Json -Depth 20 | Set-Content -Path $memFile -Encoding UTF8
        }
        Write-Host "[KB] Updated confidence for agent '$agentName' (outcome_score: $outcomeScore)"
    }
}

# Only update agents that contributed KB entries this cycle
Update-AllAgentConfidences -MemDir $memoryDir -KbEntries $kbMessages -ValResult $ValidationResult

# ---------------------------------------------------------------------------
# STEP 6: Generate cycle summary (JSON to stdout for orchestrator)
# ---------------------------------------------------------------------------

$bestPracticesCount = @($allKbEntries | Where-Object { $_.type -eq "best_practice"   }).Count
$antiPatternsCount  = @($allKbEntries | Where-Object { $_.type -eq "anti_pattern"    }).Count
$fixRecipesCount    = @($allKbEntries | Where-Object { $_.type -eq "fix_recipe"      }).Count
$designDecCount     = @($allKbEntries | Where-Object { $_.type -eq "design_decision" }).Count

$systemCount = 0
if (Test-Path $projectMapPath) {
    try {
        $mapForCount = Get-Content $projectMapPath -Raw | ConvertFrom-Json
        $systemCount = ($mapForCount.systems.PSObject.Properties | Measure-Object).Count
    } catch { }
}

$summary = [ordered]@{
    cycle                       = $CycleNumber
    kb_entries_added            = $kbMessages.Count
    best_practices_total        = $bestPracticesCount
    anti_patterns_total         = $antiPatternsCount
    fix_recipes_total           = $fixRecipesCount
    design_decisions_total      = $designDecCount
    files_in_project_map        = $systemCount
    knowledge_update_timestamp  = (Get-Date -Format "o")
}

$summary | ConvertTo-Json | Write-Host

# ---------------------------------------------------------------------------
# STEP 7: Cleanup + done
# ---------------------------------------------------------------------------

Archive-OldMessages

Update-AgentStatus -AgentName "knowledge_keeper" -State "done" `
    -AdditionalFields @{
        entries_today = $kbMessages.Count
        cycle         = $CycleNumber
    }

Write-Host "[KB] DONE"
