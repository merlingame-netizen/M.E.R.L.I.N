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
    param([string]$Status, [string]$CurrentTask = "", [array]$Completed = @(), [array]$Remaining = @(), [array]$Blockers = @())
    $statusObj = @{
        domain          = $Domain
        status          = $Status
        current_task    = $CurrentTask
        tasks_completed = $Completed
        tasks_remaining = $Remaining
        files_modified  = @()
        blockers        = $Blockers
        timestamp       = (Get-Date -Format "o")
    }
    $statusObj | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "$Domain.json") -Encoding UTF8
}

$taskIds = @($domainConfig.tasks | ForEach-Object { $_.id })
Write-Status -Status "starting" -Remaining $taskIds

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

    $lines = @(
        "Tu es un worker autonome du systeme AUTODEV pour le projet M.E.R.L.I.N. (Godot 4)."
        ""
        "MODE: NON-INTERACTIF (claude -p). Tu NE PEUX PAS poser de questions."
        "BYPASS TOTAL du questioning protocol. Agis directement, sans demander confirmation."
        "NE JAMAIS utiliser AskUserQuestion. NE JAMAIS attendre de reponse."
        "Si une information manque, fais un choix raisonnable et documente-le."
        ""
        "IDENTITE: Domaine $Domain -- $($domainConfig.description)"
        "BRANCH: $branch"
        "WORKING DIRECTORY: $worktreePath"
        ""
        "PROJET: JDR Parlant roguelite Godot 4. Systeme Triade (3 aspects x 3 etats),"
        "LLM local (Qwen 2.5-1.5B via Ollama), 18 Oghams, Bestiole compagnon."
        ""
        "SCOPE STRICT -- NE MODIFIE QUE CES FICHIERS:"
        $fileScope
        ""
        "REGLE ABSOLUE: Si tu as besoin de modifier un fichier hors de cette liste,"
        "NE LE FAIS PAS. Ecris un patch request JSON dans tools/autodev/status/patches/$Domain.json"
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

    $lines += ""
    $lines += "IMPORTANT: Tu es AUTONOME. Commence IMMEDIATEMENT. Pas de questions."
    $lines += "Traite les taches dans l'ordre de priorite (high puis medium puis low)."

    $dummy = $lines  # Force array evaluation

    return ($lines -join "`n")
}

# --- Execute ---
try {
    if (-not $DryRun) {
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

    Write-Status -Status "in_progress" -CurrentTask $taskIds[0] -Remaining $taskIds

    # Launch Claude CLI in non-interactive mode
    Write-Host "[WORKER] Launching Claude CLI..." -ForegroundColor Green
    $env:CLAUDECODE = ""

    $logFile = Join-Path $logDir "$Domain-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

    # Write prompt to temp file to avoid CLI argument truncation
    $promptFile = Join-Path $env:TEMP "autodev_prompt_$Domain.txt"
    $prompt | Out-File -FilePath $promptFile -Encoding UTF8 -NoNewline
    Write-Host "[WORKER] Prompt written to $promptFile ($($prompt.Length) chars)" -ForegroundColor Gray

    # Pipe prompt via stdin to claude -p (avoids argument length limits)
    # Note: no .NET calls -- Constrained Language Mode safe
    # IMPORTANT: Temporarily lower ErrorActionPreference to Continue so stderr
    # from Claude CLI (OneDrive profile corruption, banners) doesn't throw
    $savedEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = Get-Content $promptFile -Raw | & $claudeExe -p --allowed-tools $allowedTools --model $model --output-format text --permission-mode bypassPermissions 2>&1 | Tee-Object -FilePath $logFile
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedEAP

    # Update status based on exit code
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
            # Lower ErrorActionPreference so stderr from child PS doesn't throw
            $savedEAP2 = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $validateOutput = & powershell -ExecutionPolicy Bypass -File $validateScript -OutputFile $testResultsFile 2>&1
            $validateExitCode = $LASTEXITCODE
            $ErrorActionPreference = $savedEAP2
            Pop-Location

            if ($validateExitCode -ne 0) {
                # Validation failed - set status to error
                Write-Host "[WORKER] Validation FAILED - setting status to 'error'" -ForegroundColor Red
                Write-Status -Status "error" -Remaining $taskIds -Blockers @("Validation failed: $($validateExitCode) errors found")
                & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Validation failed - worker cannot complete" -Details ($validateOutput | Select-Object -Last 20 | Out-String)
            } else {
                # Validation passed - mark as done
                Write-Host "[WORKER] Validation PASSED" -ForegroundColor Green
                Write-Status -Status "done" -Completed $taskIds -Remaining @()
                & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_done" -Domain $Domain -Message "Termine: $($modifiedFiles.Count + $stagedFiles.Count) fichiers modifies, validation OK"
            }
        } else {
            # Validation script not found - proceed without validation
            Write-Host "[WORKER] Validation script not found, skipping validation" -ForegroundColor Yellow
            Write-Status -Status "done" -Completed $taskIds -Remaining @()
            & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_done" -Domain $Domain -Message "Termine: $($modifiedFiles.Count + $stagedFiles.Count) fichiers modifies (no validation)"
        }
    } else {
        Write-Status -Status "error" -Remaining $taskIds -Blockers @("Exit code: $exitCode")
        $lastLines = ($output | Select-Object -Last 10) -join "`n"
        & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Erreur exit code $exitCode" -Details $lastLines
    }

} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "[WORKER] FATAL: $errorMsg" -ForegroundColor Red
    Write-Status -Status "error" -Blockers @($errorMsg)
    & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Exception: $errorMsg"
    exit 1
}

Write-Host "[WORKER] $Domain complete." -ForegroundColor Green
