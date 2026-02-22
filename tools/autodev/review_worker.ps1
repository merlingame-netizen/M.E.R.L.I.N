# review_worker.ps1 -- AUTODEV v2: Launches a review-pass Claude worker
# Usage: .\review_worker.ps1 -Domain "game-design" [-DryRun]
#
# Unlike regular workers, review workers:
# - Do NOT create worktrees (work in main tree, read-mostly)
# - Get test/stats data as context in their prompt
# - Use limited tools (Read, Glob, Grep, Write, TodoWrite -- no Edit, no Bash)
# - Output goes to status/reviews/{domain}/

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$configPath = Join-Path $scriptDir "config/work_units_v2.json"
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"
$reviewsDir = Join-Path $statusDir "reviews/$Domain"

# Ensure output directories exist
@($reviewsDir, $logDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# Load configuration
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$domainConfig = $config.domains | Where-Object { $_.name -eq $Domain }

if (-not $domainConfig) {
    Write-Error "Domain '$Domain' not found in work_units_v2.json"
    exit 1
}

if ($domainConfig.type -ne "review") {
    Write-Error "Domain '$Domain' is type '$($domainConfig.type)', not 'review'"
    exit 1
}

$claudeExe = $config.claude_exe
$model = $config.claude_model
$reviewTools = $config.claude_review_tools

Write-Host "[REVIEW] ========================================" -ForegroundColor Magenta
Write-Host "  AUTODEV Review Worker: $Domain" -ForegroundColor Magenta
Write-Host "  Type: $($domainConfig.type)" -ForegroundColor Magenta
Write-Host "  Output: $reviewsDir" -ForegroundColor Magenta
Write-Host "[REVIEW] ========================================" -ForegroundColor Magenta

# ── Collect input data for the review ─────────────────────────────────

function Get-InputContext {
    $context = ""

    foreach ($inputFile in $domainConfig.inputs) {
        $inputPath = Join-Path $statusDir $inputFile
        if (Test-Path $inputPath) {
            $content = Get-Content $inputPath -Raw
            # Truncate large files to 5000 chars
            if ($content.Length -gt 5000) {
                $content = $content.Substring(0, 5000) + "`n... (truncated, $($content.Length) chars total)"
            }
            $context += "`n=== INPUT: $inputFile ===`n$content`n"
            Write-Host "[REVIEW]   Input loaded: $inputFile ($($content.Length) chars)" -ForegroundColor Gray
        } else {
            $context += "`n=== INPUT: $inputFile === (NOT FOUND)`n"
            Write-Host "[REVIEW]   Input missing: $inputFile" -ForegroundColor Yellow
        }
    }

    return $context
}

# ── Build review prompt ───────────────────────────────────────────────

function Build-ReviewPrompt {
    $inputContext = Get-InputContext
    $fileScope = ($domainConfig.file_scope | ForEach-Object { "- $_" }) -join "`n"
    $tasksJson = ($domainConfig.tasks | ConvertTo-Json -Depth 3)
    $agentFiles = ($domainConfig.agents | ForEach-Object { "- $_" }) -join "`n"

    $lines = @(
        "Tu es un worker REVIEW autonome du systeme AUTODEV pour le projet M.E.R.L.I.N. (Godot 4)."
        ""
        "MODE: NON-INTERACTIF (claude -p). Tu NE PEUX PAS poser de questions."
        "BYPASS TOTAL du questioning protocol. Agis directement."
        "NE JAMAIS utiliser AskUserQuestion. NE JAMAIS attendre de reponse."
        ""
        "IDENTITE: Reviewer $Domain -- $($domainConfig.description)"
        "WORKING DIRECTORY: $projectRoot"
        "OUTPUT DIRECTORY: $reviewsDir"
        ""
        "ROLE: Tu analyses les resultats de tests et stats, et produis des rapports."
        "Tu NE MODIFIES PAS de code GDScript directement."
        "Tu ECRIS des rapports et fichiers JSON dans le output directory."
        ""
        "PROJET: JDR Parlant roguelite Godot 4. Systeme Triade (3 aspects x 3 etats),"
        "LLM local (Qwen 2.5-1.5B via Ollama), 18 Oghams, Bestiole compagnon."
        "Le jeu doit etre QUIRKY & MYSTERIEUX -- un druide parlant, humour decale,"
        "secrets caches partout, narration a double fond."
        ""
        "SCOPE D'ECRITURE (output uniquement dans):"
        $fileScope
        "ET: $reviewsDir"
        ""
        "DONNEES A ANALYSER:"
        $inputContext
        ""
        "TACHES A REALISER (JSON):"
        $tasksJson
        ""
        "AGENTS A CONSULTER (lis ces fichiers pour les instructions):"
        $agentFiles
        ""
        "FORMAT DE SORTIE:"
        "- Rapports .md dans $reviewsDir"
        "- Fichiers JSON structures dans $reviewsDir"
        "- Chaque rapport doit etre actionnable (pas juste descriptif)"
        ""
        "IMPORTANT: Tu es AUTONOME. Commence IMMEDIATEMENT."
        "Traite les taches dans l'ordre de priorite (high puis medium puis low)."
    )

    return ($lines -join "`n")
}

# ── Write status helper ───────────────────────────────────────────────

function Write-Status {
    param([string]$Status, [string]$CurrentTask = "", [array]$Completed = @(), [array]$Remaining = @())
    $statusObj = @{
        domain          = $Domain
        status          = $Status
        type            = "review"
        current_task    = $CurrentTask
        tasks_completed = $Completed
        tasks_remaining = $Remaining
        timestamp       = (Get-Date -Format "o")
    }
    $statusObj | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "$Domain.json") -Encoding UTF8
}

# ── Execute ───────────────────────────────────────────────────────────

$taskIds = @($domainConfig.tasks | ForEach-Object { $_.id })
Write-Status -Status "starting" -Remaining $taskIds

try {
    $prompt = Build-ReviewPrompt

    if ($DryRun) {
        Write-Host "`n[DRY RUN] Would launch Claude CLI with review prompt:" -ForegroundColor Magenta
        Write-Host $prompt
        Write-Host "`n[DRY RUN] claude -p [prompt] --allowed-tools $reviewTools --model $model" -ForegroundColor Magenta
        Write-Status -Status "dry_run" -Remaining $taskIds
        exit 0
    }

    Write-Status -Status "in_progress" -CurrentTask $taskIds[0] -Remaining $taskIds

    # Write prompt to temp file
    $promptFile = Join-Path $env:TEMP "autodev_review_prompt_$Domain.txt"
    $prompt | Out-File -FilePath $promptFile -Encoding UTF8 -NoNewline
    Write-Host "[REVIEW] Prompt written ($($prompt.Length) chars)" -ForegroundColor Gray

    $logFile = Join-Path $logDir "$Domain-review-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

    # Launch Claude CLI
    Write-Host "[REVIEW] Launching Claude CLI..." -ForegroundColor Green
    $env:CLAUDECODE = ""

    $output = Get-Content $promptFile -Raw |
        & $claudeExe -p --allowed-tools $reviewTools --model $model --output-format text --permission-mode bypassPermissions 2>&1 |
        Tee-Object -FilePath $logFile

    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Status -Status "done" -Completed $taskIds -Remaining @()
        & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "review_done" -Domain $Domain -Message "Review termine"
    } else {
        Write-Status -Status "error" -Remaining $taskIds -Blockers @("Exit code: $exitCode")
        & powershell -File (Join-Path $scriptDir "notify.ps1") -Event "worker_error" -Domain $Domain -Message "Review erreur (exit $exitCode)"
    }

} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "[REVIEW] FATAL: $errorMsg" -ForegroundColor Red
    Write-Status -Status "error" -Blockers @($errorMsg)
    exit 1
}

Write-Host "[REVIEW] $Domain review complete." -ForegroundColor Green
