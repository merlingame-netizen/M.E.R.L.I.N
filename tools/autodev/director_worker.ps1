# director_worker.ps1 -- AUTODEV v3: Launches Game Director agent via Claude CLI
# Usage: .\director_worker.ps1 -Cycle 1 [-DryRun]
#
# The Director receives:
#   - All review outputs (testing, game-design, lore)
#   - Test results (parse errors, smoke tests, flow order)
#   - Stats summary (if available)
#   - Domain build statuses (5 domains)
#   - Previous director decisions (if any)
#
# The Director writes:
#   - status/director_decision.json   (ALWAYS)
#   - status/director_directives.json (ALWAYS)
#   - status/director_questions.json  (only if ESCALATE)

param(
    [Parameter(Mandatory=$true)]
    [int]$Cycle,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir "../..")).Path
$configPath = Join-Path $scriptDir "config/work_units_v2.json"
$statusDir = Join-Path $scriptDir "status"
$logDir = Join-Path $scriptDir "logs"

# Ensure directories
@($statusDir, $logDir) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$directorConfig = $config.domains | Where-Object { $_.type -eq "director" }

if (-not $directorConfig) {
    Write-Host "[DIRECTOR] No director domain in config --aborting" -ForegroundColor Red
    exit 1
}

$claudeExe = $config.claude_exe
$model = if ($config.director_model) { $config.director_model } else { $config.claude_model }
$directorTools = if ($config.director_tools) { $config.director_tools } else { $config.claude_review_tools }

Write-Host "[DIRECTOR] ========================================" -ForegroundColor Magenta
Write-Host "  AUTODEV v3 Game Director Worker" -ForegroundColor Magenta
Write-Host "  Cycle: $Cycle | Model: $model" -ForegroundColor Magenta
Write-Host "[DIRECTOR] ========================================" -ForegroundColor Magenta

# ── Collect all inputs for the Director ───────────────────────────────

function Get-DirectorContext {
    $context = ""

    # 1. Review Outputs
    $context += "`n=== SECTION 1: REVIEW OUTPUTS ===`n"
    foreach ($inputFile in $directorConfig.inputs) {
        $inputPath = Join-Path $statusDir $inputFile
        if (Test-Path $inputPath) {
            $content = Get-Content $inputPath -Raw -ErrorAction SilentlyContinue
            if ($content.Length -gt 3000) {
                $content = (-join $content[0..2999]) + "`n... (truncated)"
            }
            $context += "`n--- $inputFile ---`n$content`n"
            Write-Host "[DIRECTOR]   Input loaded: $inputFile" -ForegroundColor Gray
        } else {
            $context += "`n--- $inputFile --- (NOT FOUND)`n"
            Write-Host "[DIRECTOR]   Input missing: $inputFile" -ForegroundColor Yellow
        }
    }

    # 2. Test Results (from TEST wave)
    $context += "`n=== SECTION 2: TEST RESULTS ===`n"
    $testFiles = @("test_results.json", "smoke_test_results.json", "flow_order_results.json")
    foreach ($tf in $testFiles) {
        $tfPath = Join-Path $statusDir $tf
        if (Test-Path $tfPath) {
            $content = Get-Content $tfPath -Raw -ErrorAction SilentlyContinue
            $context += "`n--- $tf ---`n$content`n"
        }
    }

    # 3. Stats
    $context += "`n=== SECTION 3: STATS ===`n"
    $statsPath = Join-Path $statusDir "stats_summary.json"
    if (Test-Path $statsPath) {
        $context += (Get-Content $statsPath -Raw -ErrorAction SilentlyContinue)
    } else {
        $context += "(no stats available this cycle)`n"
    }

    # 4. Domain Build Status
    $context += "`n=== SECTION 4: DOMAIN BUILD STATUS ===`n"
    $buildDomains = @($config.domains | Where-Object { $_.type -eq "build" })
    foreach ($d in $buildDomains) {
        $dsPath = Join-Path $statusDir "$($d.name).json"
        if (Test-Path $dsPath) {
            $ds = Get-Content $dsPath -Raw -ErrorAction SilentlyContinue
            $context += "`n--- $($d.name) ---`n$ds`n"
        } else {
            $context += "`n--- $($d.name) --- (no status file)`n"
        }
    }

    # 5. Previous Director Decision
    $context += "`n=== SECTION 5: PREVIOUS DIRECTOR DECISION ===`n"
    $prevDecision = Join-Path $statusDir "director_decision.json"
    if (Test-Path $prevDecision) {
        $context += (Get-Content $prevDecision -Raw -ErrorAction SilentlyContinue)
    } else {
        $context += "(no previous decision --first cycle)`n"
    }

    return $context
}

# ── Build Director prompt ─────────────────────────────────────────────

function Build-DirectorPrompt {
    $inputContext = Get-DirectorContext
    $agentFile = $directorConfig.agents[0]

    $lines = @(
        "Tu es le GAME DIRECTOR du pipeline AUTODEV v3 pour le projet M.E.R.L.I.N. (Godot 4)."
        ""
        "MODE: NON-INTERACTIF (claude -p). Tu NE PEUX PAS poser de questions a l'humain."
        "BYPASS TOTAL du questioning protocol. Agis directement."
        "NE JAMAIS utiliser AskUserQuestion. NE JAMAIS attendre de reponse."
        ""
        "CYCLE: $Cycle"
        "WORKING DIRECTORY: $projectRoot"
        "OUTPUT DIRECTORY: $statusDir"
        ""
        "INSTRUCTIONS COMPLETES: Lis le fichier $agentFile pour tes instructions detaillees."
        "Ce fichier contient: ta decision matrix, tes inputs obligatoires, ton format de sortie."
        ""
        "RESUME DE TON ROLE:"
        "- Tu es le proxy du directeur humain dans le pipeline autonome"
        "- Tu analyses TOUTES les donnees ci-dessous (reviews, tests, stats, domain status)"
        "- Tu calcules un quality_score (0-100) et un confidence_score (0-100)"
        "- Tu prends une decision: PROCEED, ROLLBACK, ESCALATE, ou OVERRIDE"
        "- Si confidence < 70 -> ESCALATE (meme si quality est OK)"
        ""
        "DONNEES DU CYCLE $Cycle :"
        $inputContext
        ""
        "FICHIERS A ECRIRE (OBLIGATOIRE):"
        "1. $statusDir/director_decision.json --ta decision avec metriques"
        "2. $statusDir/director_directives.json --directives pour le prochain cycle"
        "3. $statusDir/director_questions.json --SEULEMENT si tu decides ESCALATE"
        ""
        "IMPORTANT: Ecris ces fichiers JSON avec le Write tool."
        "IMPORTANT: Tes fichiers doivent etre du JSON valide."
        "IMPORTANT: Le champ 'rationale' doit citer des metriques specifiques."
        "IMPORTANT: Commence IMMEDIATEMENT."
    )

    return ($lines -join "`n")
}

# ── Write status helper ───────────────────────────────────────────────

function Write-DirectorStatus {
    param([string]$Status, [string]$Detail = "")
    $statusObj = @{
        domain     = "game-director"
        status     = $Status
        type       = "director"
        detail     = $Detail
        cycle      = $Cycle
        timestamp  = (Get-Date -Format "o")
    }
    $statusObj | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $statusDir "game-director.json") -Encoding UTF8
}

# ── Execute ───────────────────────────────────────────────────────────

Write-DirectorStatus -Status "starting" -Detail "Building prompt"

try {
    $prompt = Build-DirectorPrompt

    if ($DryRun) {
        Write-Host "`n[DRY RUN] Would launch Claude CLI with Director prompt:" -ForegroundColor Magenta
        $preview = if ($prompt.Length -gt 500) { $prompt[0..499] -join '' } else { $prompt }
        Write-Host $preview -ForegroundColor Gray
        Write-Host "... ($($prompt.Length) chars total)" -ForegroundColor Gray
        Write-Host "`n[DRY RUN] claude -p [prompt] --allowed-tools $directorTools --model $model" -ForegroundColor Magenta

        # Write mock decision for DryRun testing
        $mockDecision = @{
            cycle           = $Cycle
            timestamp       = (Get-Date -Format "o")
            decision        = "PROCEED"
            rationale       = "[DRY RUN] Mock decision --no actual analysis performed"
            confidence      = 80
            quality_score   = 75
            metrics         = @{
                domains_done    = 5
                domains_error   = 0
                high_fixes      = 0
                medium_fixes    = 0
                low_fixes       = 0
                parse_errors    = 0
            }
        }
        $mockDecision | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $statusDir "director_decision.json") -Encoding UTF8

        $mockDirectives = @{
            cycle                = $Cycle
            fix_targets          = @()
            priority_overrides   = @{}
            next_cycle_priorities = @("Continue development")
            notes                = "[DRY RUN] Mock directives"
        }
        $mockDirectives | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $statusDir "director_directives.json") -Encoding UTF8

        Write-DirectorStatus -Status "dry_run"
        exit 0
    }

    Write-DirectorStatus -Status "in_progress" -Detail "Launching Claude CLI"

    # Write prompt to temp file
    $promptFile = Join-Path $env:TEMP "autodev_director_prompt_c${Cycle}.txt"
    $prompt | Out-File -FilePath $promptFile -Encoding UTF8 -NoNewline
    Write-Host "[DIRECTOR] Prompt written ($($prompt.Length) chars)" -ForegroundColor Gray

    $logFile = Join-Path $logDir "director_cycle${Cycle}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    # Launch Claude CLI
    Write-Host "[DIRECTOR] Launching Claude CLI (model: $model)..." -ForegroundColor Green
    $env:CLAUDECODE = ""

    $output = Get-Content $promptFile -Raw |
        & $claudeExe -p --allowed-tools $directorTools --model $model --output-format text --permission-mode bypassPermissions 2>&1 |
        Tee-Object -FilePath $logFile

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host "[DIRECTOR] Claude CLI exited with code $exitCode" -ForegroundColor Red
        Write-DirectorStatus -Status "error" -Detail "Exit code: $exitCode"
        exit 1
    }

    # Verify Director wrote its output files
    $decisionFile = Join-Path $statusDir "director_decision.json"
    if (-not (Test-Path $decisionFile)) {
        Write-Host "[DIRECTOR] WARNING: director_decision.json not created by agent" -ForegroundColor Red
        Write-DirectorStatus -Status "error" -Detail "No decision file produced"
        exit 1
    }

    # Parse the decision
    $decision = Get-Content $decisionFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $decision) {
        Write-Host "[DIRECTOR] WARNING: Could not parse director_decision.json" -ForegroundColor Red
        Write-DirectorStatus -Status "error" -Detail "Invalid decision JSON"
        exit 1
    }

    Write-Host "[DIRECTOR] Decision: $($decision.decision) (quality=$($decision.quality_score), confidence=$($decision.confidence))" -ForegroundColor Cyan
    Write-DirectorStatus -Status "done" -Detail "Decision: $($decision.decision)"

    & powershell -NoProfile -File (Join-Path $scriptDir "notify.ps1") `
        -Event "director_decision" `
        -Message "Director: $($decision.decision) (Q=$($decision.quality_score) C=$($decision.confidence))" `
        -Details $decision.rationale

} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "[DIRECTOR] FATAL: $errorMsg" -ForegroundColor Red
    Write-DirectorStatus -Status "error" -Detail $errorMsg
    exit 1
}

Write-Host "[DIRECTOR] Game Director cycle $Cycle complete." -ForegroundColor Green
