# asset_generation_loop.ps1 — Automated Asset Generation Pipeline for M.E.R.L.I.N. orchestrator v2
# Spawned when a visual/graphical issue is detected (missing asset, poor quality, scene needs content).
# Usage: .\asset_generation_loop.ps1 -AssetType "3d_model" -AssetName "dolmen_menhir" -AssetDescription "..." [-TargetScene "..."] [-DryRun]

param(
    [string]$AssetType        = "3d_model",     # "3d_model", "sprite", "texture", "ui_element"
    [string]$AssetName        = "",             # Identifier e.g. "dolmen_menhir"
    [string]$AssetDescription = "",             # Full description for generation prompt
    [string]$TargetScene      = "",             # Scene that needs this asset (optional)
    [string]$StyleGuide       = "broceliande 3d",  # "low-poly celtic", "pixel-art crt", "broceliande 3d"
    [string]$OutputDir        = "",             # Override default output dir
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# BOOTSTRAP
# ---------------------------------------------------------------------------

$autodevRoot = $PSScriptRoot | Split-Path -Parent          # loops → autodev
$projectRoot = $autodevRoot  | Split-Path -Parent | Split-Path -Parent  # autodev → tools → project root

$bridgePath = Join-Path $autodevRoot "agent_bridge.ps1"
if (-not (Test-Path $bridgePath)) {
    Write-Error "[AssetGen] agent_bridge.ps1 not found at $bridgePath"
    exit 1
}
. $bridgePath

$memoryDir = Join-Path $autodevRoot "memory"
if (-not (Test-Path $memoryDir)) { New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null }

$memoryPath = Join-Path $memoryDir "asset_generator_memory.json"

# Validate required params
if (-not $AssetName) {
    Write-Error "[AssetGen] -AssetName is required"
    exit 1
}
if (-not $AssetDescription) {
    Write-Error "[AssetGen] -AssetDescription is required"
    exit 1
}

# Resolve default output dirs
# Level 1 (3D): assets/3d_models/broceliande/{category}/ (computed dynamically per asset)
# Level 2 (sprite): assets/sprites/generated/
if (-not $OutputDir) {
    $OutputDir = if ($AssetType -eq "3d_model") { "assets/3d_models/broceliande" } else { "assets/sprites/generated" }
}
$outputDirFull = Join-Path $projectRoot ($OutputDir.Replace("/", "\"))

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

function Test-StrategyLevel {
    $trellisAvailable = Test-Path (Join-Path $projectRoot "server-trellis\dist\index.js")
    $kaggleConfigured = Test-Path (Join-Path $projectRoot ".merlin_remote\kaggle\config.json")
    $nanoBananaAvailable = $true  # Assume available (Claude Code session has it)

    if ($trellisAvailable -and $kaggleConfigured) { return 1 }
    elseif ($nanoBananaAvailable) { return 2 }
    else { return 3 }
}

function Test-TrellisImageSuitability {
    param([string]$ImagePath)
    if (-not (Test-Path $ImagePath)) { return $false }
    $size = (Get-Item $ImagePath).Length
    return ($size -gt 10240)  # > 10 KB
}

function Find-BestMatchingAsset {
    param([System.IO.FileInfo[]]$Assets, [string]$Description)
    if (-not $Assets -or $Assets.Count -eq 0) { return $null }

    $descWords = $Description.ToLower() -split '\W+' | Where-Object { $_.Length -gt 2 }
    $bestScore = 0
    $bestAsset = $null

    foreach ($asset in $Assets) {
        $nameLower = $asset.BaseName.ToLower()
        $score = ($descWords | Where-Object { $nameLower -match $_ }).Count
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestAsset = $asset
        }
    }

    return $bestAsset
}

function Get-AssetGeneratorMemory {
    try {
        if (-not (Test-Path $memoryPath)) { return $null }
        return Get-Content $memoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "[AssetGen] Could not read memory: $_"
        return $null
    }
}

function Update-AssetGeneratorMemory {
    param([string]$AssetKey, [int]$StrategyLevel, [string]$Outcome, [int]$DurationSeconds, [string]$Prompt)

    try {
        $mem = Get-AssetGeneratorMemory
        if (-not $mem) {
            $mem = @{
                agent        = "asset_generator"
                version      = "1.0"
                created_at   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                last_updated = $null
                history      = @()
            }
        }

        $history = [System.Collections.ArrayList]@(if ($mem.history) { @($mem.history) } else { @() })
        [void]$history.Add(@{
            asset_key       = $AssetKey
            strategy_level  = $StrategyLevel
            outcome         = $Outcome
            duration_seconds = $DurationSeconds
            prompt_used     = $Prompt.Substring(0, [Math]::Min(300, $Prompt.Length))
            timestamp       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        })

        $updated = @{
            agent        = "asset_generator"
            version      = "1.0"
            created_at   = if ($mem.created_at) { $mem.created_at } else { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") }
            last_updated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            history      = @($history)
        }
        $updated | ConvertTo-Json -Depth 10 | Set-Content -Path $memoryPath -Encoding UTF8
    } catch {
        Write-Warning "[AssetGen] Could not update memory: $_"
    }
}

function Get-LastStrategyForAsset {
    param([string]$AssetKey)
    $mem = Get-AssetGeneratorMemory
    if (-not $mem -or -not $mem.history) { return 0 }

    $lastEntry = @($mem.history) | Where-Object { $_.asset_key -eq $AssetKey } |
        Sort-Object { $_.timestamp } | Select-Object -Last 1

    if ($lastEntry -and $lastEntry.outcome -eq "failure") {
        return [int]$lastEntry.strategy_level
    }
    return 0
}

function Invoke-ClaudeAgent {
    param([string]$AgentName, [string]$Prompt)

    if ($DryRun) {
        Write-Host "[AssetGen] [DRY-RUN] Would invoke $AgentName`: $($Prompt.Substring(0, [Math]::Min(120, $Prompt.Length)))..."
        return
    }

    $claudeAvailable = Get-Command "claude" -ErrorAction SilentlyContinue
    if ($claudeAvailable) {
        Write-Host "[AssetGen] Invoking claude agent: $AgentName"
        $Prompt | & claude --agent $AgentName 2>&1 | Write-Host
    } else {
        Write-Warning "[AssetGen] claude CLI not found — skipping agent call for $AgentName"
    }
}

function Update-AssetPlanDoc {
    param([string]$AssetKey, [string]$AssetTypeVal, [string]$Format, [string]$Description)

    $planPath = Join-Path $projectRoot "docs\70_graphic\BROCELIANDE_3D_ASSET_PLAN.md"
    if (-not (Test-Path $planPath)) {
        Write-Warning "[AssetGen] Asset plan not found at $planPath — skipping doc update"
        return
    }

    $entry = "| $AssetKey | $AssetTypeVal | $Format | Generated $(Get-Date -Format 'yyyy-MM-dd') | $Description |"
    try {
        Add-Content -Path $planPath -Value $entry -Encoding UTF8
        Write-Host "[AssetGen] Asset plan updated: $planPath"
    } catch {
        Write-Warning "[AssetGen] Could not update asset plan: $_"
    }
}

# ---------------------------------------------------------------------------
# STEP 0: Initialize
# ---------------------------------------------------------------------------

$startTime = Get-Date
$assetKey  = "$AssetType`:$AssetName"

Write-Host "[AssetGen] ============================================" -ForegroundColor Cyan
Write-Host "[AssetGen] START — $AssetName ($AssetType)" -ForegroundColor Cyan

Update-AgentStatus -AgentName "asset_generator" -State "running" -AdditionalFields @{
    current_asset = $AssetName
    asset_type    = $AssetType
    target_scene  = $TargetScene
    started_at    = $startTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

# ---------------------------------------------------------------------------
# STEP 1: Strategy Detection
# ---------------------------------------------------------------------------

$strategyLevel = Test-StrategyLevel

# Memory override: if last attempt at detected level failed, bump up
$lastFailedLevel = Get-LastStrategyForAsset -AssetKey $assetKey
if ($lastFailedLevel -gt 0 -and $lastFailedLevel -le $strategyLevel) {
    $bumpedLevel = $lastFailedLevel + 1
    if ($bumpedLevel -le 3) {
        Write-Host "[AssetGen] Memory: level $lastFailedLevel failed last time — starting at level $bumpedLevel" -ForegroundColor Yellow
        $strategyLevel = $bumpedLevel
    }
}

Write-Host "[AssetGen] START — $AssetName ($AssetType) via strategy level $strategyLevel"

$assetPath   = ""
$assetFormat = "placeholder"

# ---------------------------------------------------------------------------
# STEP 2: Image Generation (Levels 1 and 2)
# ---------------------------------------------------------------------------

# nano-banana saves to ~/Documents/nano-banana-images/ (not $env:TEMP)
$nanoBananaOutputDir = Join-Path $HOME "Documents\nano-banana-images"
$tempImagePath = Join-Path $nanoBananaOutputDir "generated-${AssetName}-$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
$imageGenerated = $false
$imagePrompt    = ""

# asset-forge base prefix (from .claude/skills/asset-forge/SKILL.md)
$assetForgeBasePrefix = "low-poly 3D game asset, faceted flat-shading, celtic druidic style, dark forest green and moss brown palette, isolated on pure white background, game-ready prop, no textures, solid color faces, single object centered"

if ($strategyLevel -le 2) {
    $imagePrompt = "$assetForgeBasePrefix, $AssetDescription"

    if ($AssetType -eq "sprite") {
        $imagePrompt += ", pixel art, 32x32 or 64x64, limited color palette, CRT aesthetic"
    }

    Write-Host "[AssetGen] Level $strategyLevel`: Generating image via nano-banana..."

    # Use asset-forge skill pipeline (cascade 4 tiers: Gemini → Pollinations → HuggingFace → Kaggle SDXL)
    # See .claude/skills/asset-forge/SKILL.md for full spec
    $agentPrompt = @"
Use the Skill 'asset-forge' to generate a game asset for M.E.R.L.I.N. Broceliande.

Asset name: $AssetName
Asset type: $AssetType
Full image prompt: "$imagePrompt"

Follow the asset-forge pipeline:
1. generate_image (nano-banana MCP) with the prompt above
2. get_last_image_info to confirm the PNG path (~/Documents/nano-banana-images/)
3. If background is not white: edit_image to fix it
4. Run QA checks (file > 10KB, white background, not blank)
5. Report the confirmed PNG path

DO NOT generate Trellis 3D — this script handles that separately.
"@

    if (-not $DryRun) {
        Invoke-ClaudeAgent -AgentName "asset_generator" -Prompt $agentPrompt
    } else {
        Write-Host "[AssetGen] [DRY-RUN] Image prompt: $imagePrompt"
    }

    # nano-banana names files autonomously — scan dir for most recently written generated-*.png
    if (-not $DryRun -and (Test-Path $nanoBananaOutputDir)) {
        $latestPng = Get-ChildItem -Path $nanoBananaOutputDir -Filter "generated-*.png" -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestPng -and ($latestPng.LastWriteTime -gt $startTime)) {
            $tempImagePath = $latestPng.FullName
            Write-Host "[AssetGen] Detected nano-banana output: $tempImagePath"
        }
    }

    $imageGenerated = (Test-Path $tempImagePath) -or $DryRun
    if ($imageGenerated) {
        Write-Host "[AssetGen] Image generation: OK — $tempImagePath"
    } else {
        Write-Warning "[AssetGen] Image generation: file not found in $nanoBananaOutputDir"
    }
}

# ---------------------------------------------------------------------------
# STEP 3a: Level 1 — Trellis 3D Generation
# ---------------------------------------------------------------------------

if ($strategyLevel -eq 1) {
    Write-Host "[AssetGen] Level 1: Sending to Trellis for 3D generation..."

    $imageValid = Test-TrellisImageSuitability -ImagePath $tempImagePath

    if (-not $imageValid -and -not $DryRun) {
        Write-Warning "[AssetGen] FALLBACK — Image not suitable for Trellis (too small or missing). Moving to level 2."
        $strategyLevel = 2
    } else {
        # Deploy path follows asset-forge convention: assets/3d_models/broceliande/{category}/
        # Category auto-detected from AssetName (megaliths/structures/poi/creatures/decor)
        # Category derived from asset name — matches asset-forge catalog naming convention
        $broceliandeCategory = if ($AssetName -match "dolmen|menhir|stone_circle") { "megaliths" }
                               elseif ($AssetName -match "bridge_wood|root_arch|fairy_lantern|druid_altar") { "structures" }
                               elseif ($AssetName -match "fountain_barenton|merlin_tomb|merlin_oak") { "poi" }
                               elseif ($AssetName -match "korrigan|white_doe|mist_wolf|giant_raven") { "creatures" }
                               else { "decor" }  # fallen_trunk, giant_mushroom, root_network, spider_web, giant_stump
        $broceliandeDir = Join-Path $projectRoot "assets\3d_models\broceliande\$broceliandeCategory"
        $glbOutputPath = Join-Path $broceliandeDir "${AssetName}.glb"
        if (-not (Test-Path $broceliandeDir)) { New-Item -ItemType Directory -Path $broceliandeDir -Force | Out-Null }

        $trellisAgentPrompt = @"
Use the trellis_generate_3d MCP tool to convert this image to a 3D GLB model.
Image path: $tempImagePath
Resolution: 512
Asset name: $AssetName
Deploy GLB to: $glbOutputPath

Steps:
1. trellis_generate_3d(image_path=..., resolution="512", name="$AssetName")
2. Poll trellis_job_status every 30s until status=complete
3. Copy output GLB to: $glbOutputPath
4. Confirm glbValid=true and glbSize > 50KB
"@

        if (-not $DryRun) {
            Invoke-ClaudeAgent -AgentName "asset_generator_trellis" -Prompt $trellisAgentPrompt
        } else {
            Write-Host "[AssetGen] [DRY-RUN] Trellis prompt sent for: $glbOutputPath"
        }

        $glbExists = (Test-Path $glbOutputPath) -or $DryRun
        if ($glbExists) {
            $assetPath   = "assets/3d_models/broceliande/$broceliandeCategory/${AssetName}.glb"
            $assetFormat = "glb"
            Write-Host "[AssetGen] Level 1: GLB generated — $assetPath"
        } else {
            Write-Warning "[AssetGen] FALLBACK — Trellis GLB not found. Moving to level 2."
            $strategyLevel = 2
        }
    }
}

# ---------------------------------------------------------------------------
# STEP 3b: Level 2 — PNG Sprite Import
# ---------------------------------------------------------------------------

if ($strategyLevel -eq 2) {
    Write-Host "[AssetGen] Level 2: Using generated image as 2D sprite..."

    $spriteDir = Join-Path $projectRoot "assets\sprites\generated"
    if (-not (Test-Path $spriteDir)) { New-Item -ItemType Directory -Path $spriteDir -Force | Out-Null }

    $spritePath = Join-Path $spriteDir "${AssetName}.png"

    if ($imageGenerated -and (Test-Path $tempImagePath)) {
        try {
            Copy-Item -Path $tempImagePath -Destination $spritePath -Force
            $assetPath   = "assets/sprites/generated/${AssetName}.png"
            $assetFormat = "png_sprite"
            Write-Host "[AssetGen] Level 2: Sprite imported — $assetPath"
        } catch {
            Write-Warning "[AssetGen] FALLBACK — Could not copy sprite: $_. Moving to level 3."
            $strategyLevel = 3
        }
    } elseif ($DryRun) {
        $assetPath   = "assets/sprites/generated/${AssetName}.png"
        $assetFormat = "png_sprite"
        Write-Host "[AssetGen] [DRY-RUN] Level 2: Would import sprite to $assetPath"
    } else {
        Write-Warning "[AssetGen] FALLBACK — No image available for sprite import. Moving to level 3."
        $strategyLevel = 3
    }
}

# ---------------------------------------------------------------------------
# STEP 3c: Level 3 — Existing Asset Library Fallback
# ---------------------------------------------------------------------------

if ($strategyLevel -eq 3 -or (-not $assetPath)) {
    Write-Host "[AssetGen] Level 3: Searching existing asset library..."
    $strategyLevel = 3  # normalize

    $searchRoot = Join-Path $projectRoot "assets"
    $existingAssets = @()
    if (Test-Path $searchRoot) {
        $existingAssets = @(Get-ChildItem -Path $searchRoot -Recurse -Include "*.glb", "*.png", "*.tres" -ErrorAction SilentlyContinue)
    }

    $bestMatch = Find-BestMatchingAsset -Assets $existingAssets -Description $AssetDescription

    if ($bestMatch) {
        $assetPath   = $bestMatch.FullName.Replace($projectRoot, "").TrimStart("\").Replace("\", "/")
        $assetFormat = "existing_library"
        Write-Host "[AssetGen] Level 3: Using existing asset — $assetPath"
    } else {
        # Search for any existing placeholder GLB in the 3D models tree
        $placeholderPath = Get-ChildItem -Path (Join-Path $projectRoot "assets\3d_models") -Recurse -Filter "placeholder*.glb" -ErrorAction SilentlyContinue |
                           Select-Object -First 1 -ExpandProperty FullName
        if (-not $placeholderPath -and -not $DryRun) {
            Write-Warning "[AssetGen] No placeholder GLB found in assets/3d_models/ — asset_path will be null"
        }
        $assetPath   = if ($placeholderPath) { $placeholderPath.Replace($projectRoot, "").TrimStart("\").Replace("\", "/") } else { "" }
        $assetFormat = "placeholder"
        Write-Warning "[AssetGen] Level 3: No match found — using placeholder"
    }
}

# ---------------------------------------------------------------------------
# STEP 4: Update Asset Plan
# ---------------------------------------------------------------------------

Update-AssetPlanDoc -AssetKey $AssetName -AssetTypeVal $AssetType -Format $assetFormat -Description $AssetDescription

# ---------------------------------------------------------------------------
# STEP 5: Visual Validation
# ---------------------------------------------------------------------------

$visualDiffPath = Join-Path $autodevRoot "visual_diff.ps1"
if (Test-Path $visualDiffPath) {
    Write-Host "[AssetGen] Running visual diff..."
    try {
        & $visualDiffPath -AfterAsset $assetPath
    } catch {
        Write-Warning "[AssetGen] visual_diff.ps1 error: $_"
    }
}

# ---------------------------------------------------------------------------
# STEP 6: Completion
# ---------------------------------------------------------------------------

$elapsed = [int]((Get-Date) - $startTime).TotalSeconds
$outcome = if ($assetFormat -eq "placeholder") { "failure" } else { "success" }

Write-Host "[AssetGen] COMPLETE — $assetPath ($assetFormat)" -ForegroundColor $(if ($outcome -eq "success") { "Green" } else { "Yellow" })

Send-AgentMessage -FromAgent "asset_generator" -ToAgent "orchestrator" -Type "asset_ready" -Priority "HIGH" -Payload @{
    asset_name                = $AssetName
    asset_path                = $assetPath
    asset_format              = $assetFormat
    strategy_level            = $strategyLevel
    target_scene              = $TargetScene
    generation_duration_seconds = $elapsed
}

Update-AssetGeneratorMemory -AssetKey $assetKey -StrategyLevel $strategyLevel -Outcome $outcome -DurationSeconds $elapsed -Prompt $imagePrompt

Send-AgentMessage -FromAgent "asset_generator" -ToAgent "orchestrator" -Type "kb_entry" -Priority "MEDIUM" -Payload @{
    type    = "best_practice"
    title   = "Asset gen: $AssetName"
    pattern = $imagePrompt
    outcome = "$assetFormat via level $strategyLevel"
    tags    = @($AssetType, $AssetName, "level_$strategyLevel")
}

Update-AgentStatus -AgentName "asset_generator" -State "done" -AdditionalFields @{
    last_asset   = $AssetName
    last_format  = $assetFormat
    last_level   = $strategyLevel
    last_elapsed = $elapsed
}

exit $(if ($outcome -eq "success") { 0 } else { 1 })
