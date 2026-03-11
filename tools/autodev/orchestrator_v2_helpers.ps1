# orchestrator_v2_helpers.ps1 — Helper functions for orchestrator_v2.ps1
# Dot-sourced by orchestrator_v2.ps1. Not intended to be run standalone.
# Requires: $scriptDir, $projectRoot, $logsDir, $statusDir, $queuePath, $sessionPath,
#           $metricsLatest, $claudeExe, $claudeModel, $permMode, $DryRun (all from parent)

# ---------------------------------------------------------------------------
# SECTION A: QUEUE HELPERS
# ---------------------------------------------------------------------------

function Get-PendingTasks {
    if (-not (Test-Path $queuePath)) { return @() }
    try {
        $q = Get-Content $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($q.tasks | Where-Object { $_.status -eq "pending" } | Sort-Object priority)
    } catch {
        Write-Warning "[Orchestrator] Could not read queue: $_"
        return @()
    }
}

function Select-NextTasks {
    param([int]$MaxTasks = 2)
    return @(Get-PendingTasks | Select-Object -First $MaxTasks)
}

function Set-TaskStatus {
    param([string]$TaskId, [string]$Status)
    _Invoke-WithFileLock -MutexName "Queue" -Action {
        try {
            $q = Get-Content $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $dataHt = _ConvertTo-Hashtable $q
            $tasks = [System.Collections.ArrayList]@($dataHt["tasks"])
            for ($i = 0; $i -lt $tasks.Count; $i++) {
                $t = _ConvertTo-Hashtable $tasks[$i]
                if ($t["id"] -eq $TaskId) {
                    $t["status"] = $Status
                    if ($Status -eq "completed" -or $Status -eq "failed") {
                        $t["completed_at"] = (Get-Date -Format "o")
                    }
                    $tasks[$i] = $t
                    break
                }
            }
            $dataHt["tasks"] = @($tasks)
            $dataHt["updated"] = (Get-Date -Format "o")
            _Write-JsonAtomic -Path $queuePath -Data $dataHt
        } catch {
            Write-Warning "[Orchestrator] Set-TaskStatus failed for $TaskId`: $_"
        }
    }
}

# ---------------------------------------------------------------------------
# SECTION B: STATE & SESSION HELPERS
# ---------------------------------------------------------------------------

function Update-SessionState {
    param([string]$State, [int]$Cycle = 0, [string]$Objective = "")
    $obj = if ($Objective) { $Objective } else { "Orchestrator — $State (cycle $Cycle)" }
    $s = @{
        state      = $State.ToLower()
        objective  = $obj
        cycle      = $Cycle
        updated_at = (Get-Date -Format "o")
        checkpoint = "orchestrator_v2"
        workers    = @(@{ name = "orchestrator"; wave = 1; status = $State.ToLower() })
    }
    $tmp = "$sessionPath.tmp"
    $s | ConvertTo-Json -Depth 5 | Set-Content $tmp -Encoding UTF8
    Move-Item $tmp $sessionPath -Force
}

function Get-FilesModifiedThisCycle {
    try {
        $changed = & git -C $projectRoot diff --name-only HEAD~1 HEAD 2>$null
        return @($changed | Where-Object { $_ })
    } catch { return @() }
}

# ---------------------------------------------------------------------------
# SECTION C: BUILD HELPERS
# ---------------------------------------------------------------------------

function Build-TaskPrompt {
    param([object]$Task)
    $filesContext = ($Task.files | ForEach-Object { "  - $projectRoot\$_" }) -join "`n"
    return @"
Tu es un agent de developpement autonome pour M.E.R.L.I.N. (Godot 4.x, GDScript).
Orchestrator v2 — tache assignee par l'orchestrateur.

## Tache : $($Task.id) — $($Task.title)

$($Task.description)

## Fichiers concernes :
$filesContext

## Regles ABSOLUES :
- GDScript : snake_case vars/funcs, PascalCase classes, type hints obligatoires
- JAMAIS := avec CONST[index] (type explicite : var c: Color = ...)
- JAMAIS yield(), utiliser await
- Triade (Corps/Ame/Monde) est SUPPRIMEE — ne jamais recreer ces concepts
- Apres modification : .\validate.bat pour verifier 0 erreurs
- Marquer la tache completed dans tools/autodev/status/feature_queue.json

## Contexte :
- Mecaniques conservees : Reputation (5 factions), 18 Oghams, Calendrier celtique
- Jeu Godot 4.5
"@
}

function Invoke-ClaudeAgent {
    param([string]$AgentName, [string]$Prompt)
    if ($DryRun) {
        Write-Host "[Orchestrator] [DRY-RUN] Would invoke agent '$AgentName'" -ForegroundColor Yellow
        return $true
    }
    Write-Host "[Orchestrator] Invoking agent: $AgentName" -ForegroundColor Yellow
    $ts = Get-Date -Format "yyyyMMdd_HHmm"
    $logFile    = Join-Path $logsDir "agent_${AgentName}_$ts.log"
    $promptFile = Join-Path $env:TEMP "orch_prompt_$AgentName.txt"
    $Prompt | Set-Content $promptFile -Encoding UTF8
    $claudeArgs = @("-p", (Get-Content $promptFile -Raw), "--model", $claudeModel,
                    "--permission-mode", $permMode, "--output-format", "text")
    & $claudeExe @claudeArgs 2>&1 | Tee-Object -FilePath $logFile
    $ok = ($LASTEXITCODE -eq 0)
    Write-Host "[Orchestrator] Agent $AgentName — $(if($ok){'OK'}else{'FAILED'})" -ForegroundColor $(if($ok){'Green'}else{'Red'})
    Remove-Item $promptFile -ErrorAction SilentlyContinue
    return $ok
}

function Invoke-ParallelWork {
    param([string]$ExcludeDependency = "")
    $tasks = Get-PendingTasks | Where-Object {
        $_.status -eq "pending" -and (-not $ExcludeDependency -or $_.agent -ne $ExcludeDependency)
    } | Select-Object -First 1
    foreach ($t in $tasks) {
        $slot = Register-ParallelAgent -AgentName $t.id
        if ($slot) {
            Write-Host "[Orchestrator] Parallel task: $($t.title)" -ForegroundColor Gray
            Set-TaskStatus -TaskId $t.id -Status "in_progress"
            $prompt = Build-TaskPrompt -Task $t
            Start-Process -FilePath $claudeExe `
                -ArgumentList @("-p", $prompt, "--model", $claudeModel, "--output-format", "text") `
                -NoNewWindow
        }
    }
}

# ---------------------------------------------------------------------------
# SECTION D: VALIDATE & TEST HELPERS
# ---------------------------------------------------------------------------

function Invoke-Validation {
    if ($DryRun) {
        Write-Host "[Orchestrator] [DRY-RUN] Validation skipped" -ForegroundColor Yellow
        return @{ Success = $true; ErrorCount = 0; WarningCount = 0; ErrorText = "" }
    }
    $output  = @()
    $exitCode = 1
    try {
        $output   = & cmd /c "cd /d `"$projectRoot`" && .\validate.bat 2>&1"
        $exitCode = $LASTEXITCODE   # capture immediately before any other command runs
    } catch {
        $output   = @("[Orchestrator] Invoke-Validation exception: $_")
        $exitCode = 1
    }
    $joined  = $output -join "`n"
    $errors  = ($output | Select-String "ERROR:"   | Measure-Object).Count
    $warns   = ($output | Select-String "WARNING:" | Measure-Object).Count
    $success = ($exitCode -eq 0) -and ($errors -eq 0)
    return @{ Success = $success; ErrorCount = $errors; WarningCount = $warns; ErrorText = $joined }
}

function Invoke-PlaytestSimulator {
    $simScript   = Join-Path $scriptDir "playtest_simulator.ps1"
    $summaryPath = Join-Path $projectRoot "captures/playtest_summary.json"
    if (Test-Path $simScript) {
        Write-Host "[Orchestrator] Running playtest_simulator.ps1..." -ForegroundColor Yellow
        & $simScript -Runs 2 2>&1 | Out-Null
    }
    if (Test-Path $summaryPath) {
        try { return Get-Content $summaryPath -Raw | ConvertFrom-Json } catch {}
    }
    return $null
}

function Detect-Issues {
    param([object]$PlaytestResult)
    $issues = [System.Collections.ArrayList]@()

    if ($PlaytestResult) {
        if ($PlaytestResult.tone_consistency -and [double]$PlaytestResult.tone_consistency -lt 0.85) {
            [void]$issues.Add(@{ type = "llm_performance"; brain = ($PlaytestResult.brain ?? "gamemaster-v2");
                metric = "tone_consistency"; value = $PlaytestResult.tone_consistency; threshold = 0.85;
                description = "Tone consistency below threshold: $($PlaytestResult.tone_consistency)" })
        }
        if ($PlaytestResult.avg_fps -and [double]$PlaytestResult.avg_fps -lt 30) {
            [void]$issues.Add(@{ type = "visual_issue";
                description = "FPS below 30: $($PlaytestResult.avg_fps)";
                asset_name = "rendering"; asset_type = "performance" })
        }
        if ($PlaytestResult.crash_rate -and [double]$PlaytestResult.crash_rate -gt 0.10) {
            [void]$issues.Add(@{ type = "code_bug";
                description = "Crash rate above 10%: $($PlaytestResult.crash_rate)";
                error_log = ($PlaytestResult.last_error ?? ""); affected_file = "" })
        }
    }

    $busIssues = Read-PendingMessages -Type "issue_report" -ToAgent "orchestrator"
    foreach ($msg in $busIssues) {
        [void]$issues.Add(@{
            type          = ($msg.payload.issue_type ?? "code_bug")
            description   = ($msg.payload.description ?? "Bus issue report")
            error_log     = ($msg.payload.error_log ?? "")
            affected_file = ($msg.payload.affected_file ?? "")
        })
        Mark-MessageHandled -MessageId $msg.id
    }

    return @($issues)
}

function Wait-ForMessage {
    param([string]$Type, [int]$TimeoutMinutes = 20, [int]$PollSeconds = 15)
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    Write-Host "[Orchestrator] Waiting for '$Type' (timeout: ${TimeoutMinutes}min)..." -ForegroundColor Gray
    while ((Get-Date) -lt $deadline) {
        $msgs = Read-PendingMessages -Type $Type -ToAgent "orchestrator"
        if ($msgs.Count -gt 0) {
            Mark-MessageHandled -MessageId $msgs[0].id
            return $msgs[0]
        }
        Start-Sleep -Seconds $PollSeconds
    }
    Write-Warning "[Orchestrator] Timeout waiting for '$Type'"
    return $null
}

# ---------------------------------------------------------------------------
# SECTION E: REPORT GENERATOR
# ---------------------------------------------------------------------------

function Generate-CycleReport {
    param([int]$CycleNumber, [object[]]$Tasks, [datetime]$StartTime)
    $ts      = Get-Date -Format "yyyyMMdd_HHmm"
    $elapsed = [Math]::Round(((Get-Date) - $StartTime).TotalMinutes, 1)
    $reportPath = Join-Path $statusDir "cycle_report_v2_$ts.md"

    $metricsSection = "Non collectees ce cycle"
    if (Test-Path $metricsLatest) {
        try { $metricsSection = Get-Content $metricsLatest -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 3 } catch {}
    }

    $agentStatusSection = "N/A"
    try {
        $agStat = Get-AgentStatus
        if ($agStat) { $agentStatusSection = $agStat | ConvertTo-Json -Depth 2 }
    } catch {}

    $userQuestions   = @(Read-PendingMessages -Type "question_for_user" -ToAgent "orchestrator")
    $questionsSection = if ($userQuestions.Count -gt 0) {
        ($userQuestions | ForEach-Object { "- **[$($_.priority)]** $($_.payload.question)" }) -join "`n"
    } else { "Aucune question escaladee." }

    $generatedQ = @(
        "Les mecaniques de Reputation (5 factions) sont-elles correctement integrees dans le flux de cartes ?",
        "Les conditions de victoire/defaite post-Triade sont-elles bien definies dans NEW_MECHANICS_DESIGN.md ?",
        "Quelle est la prochaine mecanique prioritaire apres la Reputation : Calendrier celtique ou Oghams actifs ?"
    )
    $genQSection    = ($generatedQ | ForEach-Object { "- $_" }) -join "`n"
    $pendingRemain  = (Get-PendingTasks).Count

    $content = @"
# Rapport Equipe — Cycle $CycleNumber
*Genere le $(Get-Date -Format 'yyyy-MM-dd HH:mm') — duree: ${elapsed}min*

## Resume
| Indicateur | Valeur |
|---|---|
| Cycle | $CycleNumber |
| Taches traitees | $($Tasks.Count) |
| Queue restante | $pendingRemain taches |
| Duree cycle | ${elapsed} min |

## Taches completees ce cycle
$(
    if ($Tasks.Count -gt 0) {
        ($Tasks | ForEach-Object { "- ``$($_.id)`` — $($_.title)" }) -join "`n"
    } else { "Aucune tache traitee (IDLE ou DryRun)." }
)

## Agents actifs ce cycle
``````json
$agentStatusSection
``````

## Metriques
``````json
$metricsSection
``````

## Questions escaladees (debug/agents)
$questionsSection

## Questions game design pour l'utilisateur
$genQSection

---
*Orchestrator v2.0 — $(Get-Date -Format 'o')*
"@

    $content | Set-Content $reportPath -Encoding UTF8
    return $reportPath
}
