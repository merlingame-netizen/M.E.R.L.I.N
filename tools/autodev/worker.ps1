# worker.ps1 -- AUTODEV Worker: launches a Claude CLI session in an isolated worktree
# Usage: .\worker.ps1 -Domain "ui-ux" [-Mode build] [-DryRun]
# Modes: build (default), fix (targeted fixes from feedback)

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,

    [ValidateSet("build", "fix")]
    [string]$Mode = "build",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
# Support both v1 and v2 config
$configV2Path = Join-Path $scriptDir "config/work_units_v2.json"
$configV1Path = Join-Path $scriptDir "config/work_units.json"
$configPath = if (Test-Path $configV2Path) { $configV2Path } else { $configV1Path }
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"

# --- Load configuration ---
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$domainConfig = $config.domains | Where-Object { $_.name -eq $Domain }

if (-not $domainConfig) {
    Write-Error "Domain '$Domain' not found in work_units.json"
    exit 1
}

$branch = $domainConfig.branch
$worktreeBase = $config.worktree_base
$worktreePath = Join-Path $worktreeBase $Domain
$claudeExe = $config.claude_exe
$model = $config.claude_model
$allowedTools = $config.claude_allowed_tools

Write-Host "[========================================]" -ForegroundColor Cyan
Write-Host "  AUTODEV Worker: $Domain" -ForegroundColor Cyan
Write-Host "  Branch: $branch" -ForegroundColor Cyan
Write-Host "  Worktree: $worktreePath" -ForegroundColor Cyan
Write-Host "[========================================]" -ForegroundColor Cyan

# --- Write status helper ---
function Write-Status {
    param(
        [string]$Status,
        [string]$CurrentTask = "",
        [array]$Completed = @(),
        [array]$Remaining = @(),
        [array]$Blockers = @(),
        [hashtable]$ErrorContext = @{},
        # A2A Protocol extensions
        [string]$TaskId = "",
        [string]$AgentId = "",
        [int]$ProgressPct = -1,
        [array]$Artifacts = @()
    )

    # Map legacy status to A2A lifecycle
    $a2aStatus = switch ($Status) {
        "starting"    { "accepted" }
        "in_progress" { "working" }
        "done"        { "completed" }
        "error"       { "failed" }
        "retrying"    { "working" }
        "dry_run"     { "accepted" }
        default       { $Status }
    }

    $statusObj = @{
        domain          = $Domain
        status          = $Status
        current_task    = $CurrentTask
        tasks_completed = $Completed
        tasks_remaining = $Remaining
        files_modified  = @()
        blockers        = $Blockers
        timestamp       = (Get-Date -Format "o")
        # A2A Protocol extensions
        a2a_status      = $a2aStatus
        agent_id        = if ($AgentId) { $AgentId } else { $Domain }
    }

    if ($TaskId) { $statusObj.task_id = $TaskId }
    if ($ProgressPct -ge 0) { $statusObj.progress_pct = $ProgressPct }
    if ($Artifacts.Count -gt 0) { $statusObj.artifacts = $Artifacts }
    if ($ErrorContext.Count -gt 0) { $statusObj.error_context = $ErrorContext }

    # Atomic write: temp file + rename to prevent race conditions with merge/dashboard
    $targetFile = Join-Path $statusDir "$Domain.json"
    $tmpFile = "$targetFile.tmp"
    $statusObj | ConvertTo-Json -Depth 4 | Set-Content $tmpFile -Encoding UTF8
    Move-Item -Path $tmpFile -Destination $targetFile -Force
}

# --- Swarm integration: write results to .swarm/results/ ---
function Write-SwarmResult {
    param(
        [array]$TaskIds,
        [string]$Status,
        [array]$FilesModified = @()
    )
    $swarmResultsDir = Join-Path $projectRoot ".swarm" "results"
    if (-not (Test-Path $swarmResultsDir)) { return }
    $result = @{
        task_id = "$Domain"
        tool = "claude"
        status = $Status
        completed_at = (Get-Date -Format "o")
        domain = $Domain
        tasks_completed = $TaskIds
        files_modified = $FilesModified
        summary = "AUTODEV worker $Domain completed $($TaskIds.Count) tasks"
        errors = @()
        learnings = @()
    }
    $resultPath = Join-Path $swarmResultsDir "$Domain.json"
    $tmpPath = "$resultPath.tmp"
    $result | ConvertTo-Json -Depth 5 | Set-Content $tmpPath -Encoding UTF8
    Move-Item $tmpPath $resultPath -Force
    Write-Host "[WORKER] Swarm result written: $resultPath" -ForegroundColor Gray
}

# --- A2A Protocol: Message helpers ---
function Send-A2AMessage {
    param(
        [string]$ToAgent,
        [string]$Type = "delegation",
        [string]$TaskId = "",
        [hashtable]$Payload = @{},
        [string]$ReplyTo = "",
        [int]$TtlMinutes = 30
    )
    $messagesDir = Join-Path $statusDir "messages"
    if (-not (Test-Path $messagesDir)) {
        New-Item -ItemType Directory -Path $messagesDir -Force | Out-Null
    }
    $msgId = "msg_$(Get-Date -Format 'yyyyMMdd_HHmmss')_${Domain}_${ToAgent}"
    $message = @{
        message_id = $msgId
        type       = $Type
        from_agent = $Domain
        to_agent   = $ToAgent
        task_id    = $TaskId
        timestamp  = (Get-Date -Format "o")
        payload    = $Payload
        reply_to   = $ReplyTo
        ttl_minutes = $TtlMinutes
    }
    $inboxFile = Join-Path $messagesDir "inbox_$ToAgent.jsonl"
    $line = ($message | ConvertTo-Json -Depth 5 -Compress)
    Add-Content -Path $inboxFile -Value $line -Encoding UTF8
    Write-Host "[A2A] Message sent: $msgId -> $ToAgent ($Type)" -ForegroundColor Magenta
    return $msgId
}

function Read-A2AInbox {
    $messagesDir = Join-Path $statusDir "messages"
    $inboxFile = Join-Path $messagesDir "inbox_$Domain.jsonl"
    if (-not (Test-Path $inboxFile)) { return @() }
    $messages = @()
    $lines = Get-Content $inboxFile -Encoding UTF8
    foreach ($line in $lines) {
        if ($line.Trim()) {
            try {
                $msg = $line | ConvertFrom-Json
                $messages += $msg
            } catch {}
        }
    }
    return $messages
}

function Reply-A2AMessage {
    param(
        [string]$OriginalMessageId,
        [string]$OriginalSender,
        [hashtable]$Payload = @{}
    )
    Send-A2AMessage -ToAgent $OriginalSender -Type "task_response" -Payload $Payload -ReplyTo $OriginalMessageId
}

# --- Pre-flight health check ---
function Test-PreFlight {
    $issues = @()
    $claudeConfig = Join-Path $env:USERPROFILE ".claude.json"
    if (-not (Test-Path $claudeConfig)) {
        $issues += "MISSING: $claudeConfig"
    } else {
        try { Get-Content $claudeConfig -Raw -ErrorAction Stop | Out-Null }
        catch { $issues += "UNREADABLE: $claudeConfig — $($_.Exception.Message)" }
    }
    if (-not (Test-Path $claudeExe)) {
        $issues += "MISSING: Claude CLI at $claudeExe"
    }
    if ($issues.Count -gt 0) {
        Write-Host "[WORKER] PRE-FLIGHT FAILED:" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        Write-Status -Status "error" -Blockers $issues -ErrorContext @{
            stage = "pre-flight"
            checks_failed = $issues
        }
        exit 1
    }
    Write-Host "[WORKER] Pre-flight OK" -ForegroundColor Green
}

# --- Error classification (TRANSIENT = auto-retry, PERMANENT = fail) ---
function Get-ErrorClass {
    param([int]$ExitCode, $Output)

    $text = ($Output | Select-Object -Last 30) -join "`n"

    # TRANSIENT patterns (auto-retry candidates)
    $transientPatterns = @(
        "n'est plus valide car le volume",
        "fichier ouvert n'est plus valide",
        "ENOENT.*\.claude",
        "ETIMEDOUT",
        "ECONNRESET",
        "ECONNREFUSED",
        "rate limit",
        "Too Many Requests",
        "503 Service",
        "429",
        "socket hang up",
        "getaddrinfo ENOTFOUND"
    )

    foreach ($pattern in $transientPatterns) {
        if ($text -match $pattern) { return "TRANSIENT" }
    }

    return "PERMANENT"
}

# --- Repair .claude.json if corrupted (OneDrive sync issue) ---
function Repair-ClaudeConfig {
    $configPath = Join-Path $env:USERPROFILE ".claude.json"
    $backupPath = Join-Path $scriptDir "config/.claude.json.backup"

    # Check if config is valid JSON
    if (Test-Path $configPath) {
        try {
            $content = Get-Content $configPath -Raw -ErrorAction Stop
            $null = $content | ConvertFrom-Json -ErrorAction Stop
            # Config is valid — save as backup for future recovery
            $content | Set-Content $backupPath -Encoding UTF8
            return $true
        } catch {
            Write-Host "[WORKER] .claude.json corrupted, attempting repair..." -ForegroundColor Yellow
        }
    }

    # Restore from backup
    if (Test-Path $backupPath) {
        Write-Host "[WORKER] Restoring .claude.json from backup" -ForegroundColor Yellow
        Copy-Item $backupPath $configPath -Force
        return $true
    }

    Write-Host "[WORKER] No .claude.json backup available" -ForegroundColor Red
    return $false
}

$taskIds = @($domainConfig.tasks | ForEach-Object { $_.id })
Write-Status -Status "starting" -Remaining $taskIds -AgentId $Domain

# --- Create or reset worktree ---
function Setup-Worktree {
    Push-Location $projectRoot

    # Check if branch exists
    $branchExists = git branch --list $branch 2>$null
    if (-not $branchExists) {
        Write-Host "[WORKER] Creating branch $branch from main" -ForegroundColor Yellow
        git branch $branch main
    }

    # Check if worktree already exists
    if (Test-Path $worktreePath) {
        Write-Host "[WORKER] Worktree exists, resetting..." -ForegroundColor Yellow
        git worktree remove $worktreePath --force 2>$null
    }

    # Create worktree directory parent
    $parentDir = Split-Path $worktreePath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Add worktree
    Write-Host "[WORKER] Creating worktree at $worktreePath" -ForegroundColor Green
    git worktree add $worktreePath $branch

    # Prevent workers from accidentally committing status/log files
    $autodevDir = Join-Path $worktreePath "tools/autodev"
    if (Test-Path $autodevDir) {
        $ignoreFile = Join-Path $autodevDir ".gitignore"
        $ignoreContent = "# Auto-generated by AUTODEV pipeline — prevent status/log merge conflicts`nstatus/`nlogs/`n*.tmp`n"
        $ignoreContent | Set-Content $ignoreFile -Encoding UTF8
        Write-Host "[WORKER] Added .gitignore for status/logs in worktree" -ForegroundColor Gray
    }

    Pop-Location
}

# --- Load feedback from previous cycle (if exists) ---
function Get-FeedbackContext {
    $feedbackFile = Join-Path $statusDir "feedback/$Domain.json"
    if (Test-Path $feedbackFile) {
        $fb = Get-Content $feedbackFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($fb) {
            $lines = @()
            $lines += "=== FEEDBACK DU CYCLE PRECEDENT (cycle $($fb.cycle)) ==="

            if ($fb.priority_fixes -and $fb.priority_fixes.Count -gt 0) {
                $lines += "FIXES PRIORITAIRES:"
                foreach ($fix in $fb.priority_fixes) { $lines += "  - $fix" }
            }

            if ($fb.balance_suggestions -and $fb.balance_suggestions.PSObject.Properties.Count -gt 0) {
                $lines += "AJUSTEMENTS BALANCE:"
                foreach ($prop in $fb.balance_suggestions.PSObject.Properties) {
                    $lines += "  - $($prop.Name): $($prop.Value)"
                }
            }

            if ($fb.lore_notes -and $fb.lore_notes.Count -gt 0) {
                $lines += "NOTES LORE:"
                foreach ($note in $fb.lore_notes) { $lines += "  - $note" }
            }

            if ($fb.stats_snapshot) {
                $ss = $fb.stats_snapshot
                $lines += "STATS SNAPSHOT: balance=$($ss.balance_score) fun=$($ss.fun_score) survie=$($ss.survival_rate)"
            }

            $lines += "=== FIN FEEDBACK ==="
            Write-Host "[WORKER] Feedback loaded from cycle $($fb.cycle)" -ForegroundColor Gray
            return ($lines -join "`n")
        }
    }
    return ""
}

# --- Build worker prompt ---
function Build-WorkerPrompt {
    $fileScope = ($domainConfig.file_scope | ForEach-Object { "- $_" }) -join "`n"
    $tasksJson = ($domainConfig.tasks | ConvertTo-Json -Depth 3)
    $agentFiles = ($domainConfig.agents | ForEach-Object { "- $_" }) -join "`n"
    $feedbackContext = Get-FeedbackContext

    # Global objective from config (set by Claude Code launcher)
    $globalObjective = if ($config.global_objective) { $config.global_objective } else { $null }

    $lines = @(
        "Tu es un worker autonome du systeme AUTODEV pour le projet M.E.R.L.I.N. (Godot 4)."
        ""
        "MODE: NON-INTERACTIF (claude -p). Tu NE PEUX PAS poser de questions."
        "BYPASS TOTAL du questioning protocol. Agis directement, sans demander confirmation."
        "NE JAMAIS utiliser AskUserQuestion. NE JAMAIS attendre de reponse."
        "Si une information manque, fais un choix raisonnable et documente-le."
        ""
    )

    # Inject global objective if defined
    if ($globalObjective) {
        $lines += "OBJECTIF GLOBAL DE CETTE SESSION:"
        $lines += $globalObjective
        $lines += ""
        $lines += "Cet objectif prime sur les taches par defaut."
        $lines += "Adapte ton travail dans ton domaine pour contribuer a cet objectif."
        $lines += ""
    }

    $lines += @(
        "IDENTITE: Domaine $Domain -- $($domainConfig.description)"
        "BRANCH: $branch"
        "WORKING DIRECTORY: $worktreePath"
        ""
        "PROJET: JDR Parlant roguelite Godot 4. 5 Factions, 18 Oghams, 1 barre de vie,"
        "LLM local `(Qwen 3.5 Multi-Brain via Ollama`), 8 champs lexicaux, MOS."
        ""
        "SCOPE STRICT -- NE MODIFIE QUE CES FICHIERS:"
        $fileScope
        ""
        "REGLE ABSOLUE: Si tu as besoin de modifier un fichier hors de cette liste,"
        "NE LE FAIS PAS. Ecris un patch request JSON dans tools/autodev/status/patches/$Domain.json"
        ""
        "INTERDIT: Ne committe JAMAIS de fichiers dans tools/autodev/status/ ou tools/autodev/logs/."
        "Ces repertoires sont geres par le pipeline orchestrateur, pas par les workers."
        "Si tu crees un script dans tools/autodev/, c'est OK. Mais status/ et logs/ = INTERDIT."
        ""
        "TACHES A REALISER (JSON):"
        $tasksJson
        ""
        "AGENTS A CONSULTER (lis ces fichiers pour les instructions):"
        $agentFiles
        ""
        "REGLES GDSCRIPT:"
        "- snake_case variables/fonctions, PascalCase classes"
        "- Type hints obligatoires: var x: int = 0"
        "- JAMAIS := avec Dictionary ou Array constants"
        "- JAMAIS yield() (utiliser await), JAMAIS // division (utiliser int(x/y))"
        "- Fonctions moins de 50 lignes, fichiers moins de 800 lignes"
        "- Couleurs: MerlinVisual.PALETTE ou MerlinVisual.GBC"
        "- Fonts: MerlinVisual.get_font()"
        ""
        "WORKFLOW PAR TACHE:"
        "1. Lire le code existant des fichiers de ton scope"
        "2. Lire les agents assignes pour les instructions"
        "3. Implementer en respectant les patterns existants"
        "4. git add + git commit -m feat($Domain): description"
        ""
        "SI BLOQUE: Ecris dans tools/autodev/status/${Domain}_blocked.json pourquoi."
        ""
    )

    # Inject feedback from previous cycle
    if ($feedbackContext) {
        $lines += ""
        $lines += $feedbackContext
        $lines += ""
        $lines += "INSTRUCTION: Prends en compte le feedback ci-dessus."
        $lines += "Les FIXES PRIORITAIRES doivent etre traites AVANT les nouvelles taches."
        $lines += "Les AJUSTEMENTS BALANCE doivent etre integres aux modifications de constantes."
    }

    # Fix mode: override tasks with targeted fixes
    if ($Mode -eq "fix") {
        $lines += ""
        $lines += "MODE FIX: Tu es en mode correction ciblee."
        $lines += "Concentre-toi UNIQUEMENT sur les fixes prioritaires du feedback."
        $lines += "Ne fais PAS de nouvelles fonctionnalites."
    }

    # A2A Protocol: contextual delegation instructions
    $registryPath = Join-Path $projectRoot "tools/autodev/agent_cards/_registry.json"
    $delegationRules = @()
    if (Test-Path $registryPath) {
        try {
            $a2aRegistry = Get-Content $registryPath -Raw | ConvertFrom-Json
            $myCard = $a2aRegistry.agents.PSObject.Properties | Where-Object { $_.Value.id -eq $Domain -or $_.Name -eq $Domain } | Select-Object -First 1
            if ($myCard) {
                $deps = $myCard.Value.dependencies
                if ($deps -and $deps.Count -gt 0) {
                    foreach ($depId in $deps) {
                        $depCard = $a2aRegistry.agents.$depId
                        if ($depCard) {
                            $capList = ($depCard.capabilities | ForEach-Object { $_.task_type }) -join ", "
                            $delegationRules += "  - $depId ($($depCard.name)): $capList"
                        }
                    }
                }
            }
        } catch {}
    }

    $lines += ""
    $lines += "=== A2A PROTOCOL (delegation peer-to-peer) ==="
    $lines += "Tu peux deleguer des sous-taches a d'autres agents via le systeme de messages."
    $lines += ""
    $lines += "QUAND DELEGUER:"
    $lines += "  - Tu trouves un bug de securite → delegue a security_specialist"
    $lines += "  - Tu as besoin d'un code review → delegue a debug_qa"
    $lines += "  - Tu modifies du code UI → delegue la verification a ui_consistency"
    $lines += "  - Tu changes des prompts LLM → delegue la review a llm_expert"
    $lines += ""
    $lines += "COMMENT DELEGUER:"
    $lines += "Ecrire UNE ligne JSON dans tools/autodev/status/messages/inbox_{agent_id}.jsonl"
    $lines += "Format: {`"message_id`":`"msg_001`",`"type`":`"delegation`",`"from_agent`":`"$Domain`",`"to_agent`":`"TARGET`",`"task_id`":`"TASK`",`"timestamp`":`"ISO`",`"payload`":{`"action`":`"review`",`"files`":[`"path`"]},`"reply_to`":null,`"ttl_minutes`":30}"
    $lines += ""
    if ($delegationRules.Count -gt 0) {
        $lines += "TES COLLABORATEURS PREFERES (depuis A2A registry):"
        $delegationRules | ForEach-Object { $lines += $_ }
        $lines += ""
    }
    $lines += "VERIFIER TA BOITE: Lis tools/autodev/status/messages/inbox_$Domain.jsonl pour les reponses."
    $lines += "=== FIN A2A PROTOCOL ==="

    $lines += ""
    $lines += "IMPORTANT: Tu es AUTONOME. Commence IMMEDIATEMENT. Pas de questions."
    $lines += "Traite les taches dans l'ordre de priorite (high puis medium puis low)."

    return ($lines -join "`n")
}

# --- Execute ---
try {
    if (-not $DryRun) {
        Test-PreFlight
        Setup-Worktree
    }

    $prompt = Build-WorkerPrompt

    if ($DryRun) {
        Write-Host "" -ForegroundColor Magenta
        Write-Host "[DRY RUN] Would launch Claude CLI with prompt:" -ForegroundColor Magenta
        Write-Host $prompt
        Write-Host "" -ForegroundColor Magenta
        Write-Host "[DRY RUN] claude -p [prompt] --allowedTools $allowedTools --model $model" -ForegroundColor Magenta
        Write-Status -Status "dry_run" -Remaining $taskIds
        exit 0
    }

    # Notify start
    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_done" -Domain $Domain -Message "Worker demarre avec $($domainConfig.tasks.Count) taches"

    Write-Status -Status "in_progress" -CurrentTask $taskIds[0] -Remaining $taskIds -AgentId $Domain -ProgressPct 0

    # Clear CLAUDECODE env var to prevent Claude CLI from detecting nested context
    $env:CLAUDECODE = ""

    # Write prompt to temp file to avoid CLI argument truncation
    $promptFile = Join-Path $env:TEMP "autodev_prompt_$Domain.txt"
    $prompt | Out-File -FilePath $promptFile -Encoding UTF8 -NoNewline
    Write-Host "[WORKER] Prompt written to $promptFile ($($prompt.Length) chars)" -ForegroundColor Gray

    # --- Retry loop: auto-retry on transient errors (OneDrive, network, rate limit) ---
    $maxRetries = 2
    $retryDelay = 30
    $exitCode = 1
    $output = $null

    for ($attempt = 1; $attempt -le ($maxRetries + 1); $attempt++) {
        # Verify .claude.json before each attempt
        Repair-ClaudeConfig | Out-Null

        $logFile = Join-Path $logDir "$Domain-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        Write-Host "[WORKER] Claude CLI attempt $attempt/$($maxRetries + 1)..." -ForegroundColor Green

        $savedEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $output = Get-Content $promptFile -Raw | & $claudeExe -p --allowed-tools $allowedTools --model $model --output-format text --permission-mode bypassPermissions 2>&1 | Tee-Object -FilePath $logFile
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedEAP

        if ($exitCode -eq 0) {
            Write-Host "[WORKER] Claude CLI succeeded (attempt $attempt)" -ForegroundColor Green
            break
        }

        # Classify error to decide retry vs fail
        $errorClass = Get-ErrorClass -ExitCode $exitCode -Output $output

        if ($errorClass -eq "TRANSIENT" -and $attempt -le $maxRetries) {
            Write-Host "[WORKER] TRANSIENT error detected (attempt $attempt/$($maxRetries + 1)), retrying in ${retryDelay}s..." -ForegroundColor Yellow
            $lastLines = ($output | Select-Object -Last 5) -join " | "
            Write-Status -Status "retrying" -CurrentTask "Retry $attempt after transient error" -Remaining $taskIds -Blockers @("TRANSIENT (attempt $attempt): $lastLines")

            # Attempt to repair config before retry
            Repair-ClaudeConfig | Out-Null

            Start-Sleep -Seconds $retryDelay
            $retryDelay = $retryDelay * 2
            continue
        }

        # PERMANENT error or max retries exhausted — exit retry loop
        Write-Host "[WORKER] $errorClass error (attempt $attempt), not retrying" -ForegroundColor Red
        break
    }

    # --- Process result ---
    if ($exitCode -eq 0) {
        Push-Location $worktreePath
        $modifiedFiles = @(git diff --name-only HEAD 2>$null)
        $stagedFiles = @(git diff --cached --name-only 2>$null)
        Pop-Location

        # INFRA.2: Run validate.bat Step 0 automatically before marking as done
        Write-Host "[WORKER] Running validation (Step 0)..." -ForegroundColor Cyan
        $validateScript = Join-Path $scriptDir "generate_test_results.ps1"
        $testResultsFile = Join-Path $scriptDir "status\test_results.json"

        if (Test-Path $validateScript) {
            Push-Location $worktreePath
            $savedEAP2 = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $validateOutput = & powershell -ExecutionPolicy Bypass -File $validateScript -OutputFile $testResultsFile 2>&1
            $validateExitCode = $LASTEXITCODE
            $ErrorActionPreference = $savedEAP2
            Pop-Location

            if ($validateExitCode -ne 0) {
                Write-Host "[WORKER] Validation FAILED - setting status to 'error'" -ForegroundColor Red
                $validateSummary = ($validateOutput | Select-Object -Last 5) -join ' | '
                Write-Status -Status "error" -Remaining $taskIds -Blockers @("Validation failed (exit $validateExitCode): $validateSummary") -ErrorContext @{
                    stage = "validation"
                    exit_code = $validateExitCode
                    output_tail = ($validateOutput | Select-Object -Last 10) -join "`n"
                }
                & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Validation failed - worker cannot complete" -Details ($validateOutput | Select-Object -Last 20 | Out-String)
            } else {
                Write-Host "[WORKER] Validation PASSED" -ForegroundColor Green
                Write-Status -Status "done" -Completed $taskIds -Remaining @() -AgentId $Domain -ProgressPct 100
                Write-SwarmResult -TaskIds $taskIds -Status "done" -FilesModified ($modifiedFiles + $stagedFiles)
                & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_done" -Domain $Domain -Message "Termine: $($modifiedFiles.Count + $stagedFiles.Count) fichiers modifies, validation OK"
            }
        } else {
            Write-Host "[WORKER] Validation script not found, skipping validation" -ForegroundColor Yellow
            Write-Status -Status "done" -Completed $taskIds -Remaining @() -AgentId $Domain -ProgressPct 100
            Write-SwarmResult -TaskIds $taskIds -Status "done" -FilesModified ($modifiedFiles + $stagedFiles)
            & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_done" -Domain $Domain -Message "Termine: $($modifiedFiles.Count + $stagedFiles.Count) fichiers modifies (no validation)"
        }
    } else {
        $lastLines = ($output | Select-Object -Last 20) -join "`n"
        $errorClass = Get-ErrorClass -ExitCode $exitCode -Output $output
        Write-Status -Status "error" -Remaining $taskIds -Blockers @("Claude CLI exit code: $exitCode ($errorClass, $($maxRetries + 1) attempts)") -ErrorContext @{
            stage = "claude-execution"
            command = "$claudeExe -p --model $model"
            exit_code = $exitCode
            error_class = $errorClass
            attempts = ($attempt)
            stderr_tail = $lastLines
            log_file = $logFile
        }
        & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Erreur exit code $exitCode ($errorClass, $attempt attempts)" -Details $lastLines
    }

} catch {
    $errorMsg = $_.Exception.Message
    $errorStack = $_.ScriptStackTrace
    $errorLine = $_.InvocationInfo.ScriptLineNumber
    $errorCmd = $_.InvocationInfo.Line.Trim()
    Write-Host "[WORKER] FATAL at line $errorLine : $errorMsg" -ForegroundColor Red
    Write-Host "[WORKER] Command: $errorCmd" -ForegroundColor Red
    Write-Host "[WORKER] Stack: $errorStack" -ForegroundColor DarkRed
    Write-Status -Status "error" -Blockers @("FATAL line $errorLine : $errorMsg") -ErrorContext @{
        stage = "unknown"
        exception = $errorMsg
        line = $errorLine
        command = $errorCmd
        stack_trace = $errorStack
    }
    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Exception line $errorLine : $errorMsg"
    exit 1
}

Write-Host "[WORKER] $Domain complete." -ForegroundColor Green
