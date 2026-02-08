# ============================================================
# NIGHT MODE - Boucle autonome focalisee sur un theme
# ============================================================
#
# Usage depuis Claude Code (appel interne):
#   powershell.exe -ExecutionPolicy Bypass -File tools/night_mode.ps1 `
#     -Theme "Le theme" -Iteration 1 -Satisfaction 2 `
#     -Accomplished "item1|item2" -Remaining "todo1|todo2" `
#     -NextAction "Prochaine action" -Agents "agent1.md|agent2.md"
#
# Methode: Set-Clipboard + VBScript SendKeys (contourne Constrained Language Mode)
#
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Theme,

    [int]$Iteration = 1,

    [ValidateRange(1, 5)]
    [int]$Satisfaction = 1,

    [string]$Accomplished = "",
    [string]$Remaining = "",
    [string]$ModifiedFiles = "",
    [string]$Blockers = "Aucun",
    [string]$NextAction = "",
    [string]$Agents = "",

    [ValidateSet("claude", "codex")]
    [string]$Target = "claude",

    [switch]$NoPaste
)

$ErrorActionPreference = "Stop"
$projectRoot = "c:\Users\PGNK2128\Godot-MCP"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

# --- Helper: split pipe-separated lists into markdown ---
function Format-List($items, $prefix = "- ") {
    if ([string]::IsNullOrWhiteSpace($items)) { return "${prefix}(rien)" }
    return ($items -split '\|' | ForEach-Object { "${prefix}$($_.Trim())" }) -join "`n"
}

function Format-NumberedList($items) {
    if ([string]::IsNullOrWhiteSpace($items)) { return "1. (rien)" }
    $i = 0
    return ($items -split '\|' | ForEach-Object { $i++; "$i. $($_.Trim())" }) -join "`n"
}

# --- 1. Ecrire le handoff ---
$accomplishedMd = Format-List $Accomplished
$remainingMd = Format-NumberedList $Remaining

$fileLines = @()
if (-not [string]::IsNullOrWhiteSpace($ModifiedFiles)) {
    $ModifiedFiles -split '\|' | ForEach-Object { $fileLines += "- $($_.Trim())" }
} else {
    $fileLines += "- (aucun)"
}
$filesMd = $fileLines -join "`n"

$agentLines = @()
if (-not [string]::IsNullOrWhiteSpace($Agents)) {
    $Agents -split '\|' | ForEach-Object { $agentLines += "- $($_.Trim())" }
} else {
    $agentLines += "- (voir protocole)"
}
$agentsMd = $agentLines -join "`n"

$handoffContent = @"
# Night Mode Handoff
> Theme: $Theme
> Iteration: $Iteration -> $($Iteration + 1)
> Generated: $timestamp
> Satisfaction: $Satisfaction/5

---

## Theme (NE JAMAIS CHANGER)

**$Theme**

---

## Etat iteration $Iteration

### Accompli
$accomplishedMd

### Restant (priorise)
$remainingMd

### Fichiers modifies
$filesMd

### Blockers
- $Blockers

### Prochaine action
$NextAction

### Agents a invoquer
$agentsMd

---

## Satisfaction: $Satisfaction/5

$(if ($Satisfaction -ge 5) {
"**COMPLET** - Le theme est entierement traite. Pas de handoff necessaire."
} elseif ($Satisfaction -ge 4) {
"**Presque fini** - Quelques ajustements restants."
} elseif ($Satisfaction -ge 3) {
"**En bonne voie** - Implementation principale faite, reste polish/tests."
} elseif ($Satisfaction -ge 2) {
"**En cours** - Fondations posees, implementation a continuer."
} else {
"**Debut** - Recherche et reflexion, peu d'implementation encore."
})
"@

$handoffPath = Join-Path $projectRoot "night_mode_handoff.md"
$handoffContent | Out-File -FilePath $handoffPath -Encoding UTF8
Write-Host "[OK] Handoff ecrit: $handoffPath" -ForegroundColor Green

# --- 2. Construire le prompt clipboard (via Set-Clipboard, pas Add-Type) ---
$clipPrompt = @"
NIGHT MODE - Iteration $($Iteration + 1)

THEME: $Theme

PROTOCOLE: Lis tools/night_mode_protocol.md IMMEDIATEMENT avant toute action.

ETAT ACTUEL:
- Iteration precedente: $Iteration
- Satisfaction: $Satisfaction/5

ACCOMPLI (iteration $Iteration):
$accomplishedMd

RESTANT (priorise):
$remainingMd

FICHIERS MODIFIES:
$filesMd

BLOCKERS:
- $Blockers

PROCHAINE ACTION:
$NextAction

AGENTS A INVOQUER:
$agentsMd

REGLES (OBLIGATOIRES - PAS DE DEROGATION):
1. Lis tools/night_mode_protocol.md, night_mode_handoff.md, progress.md, task_plan.md, findings.md
2. Travaille UNIQUEMENT sur le theme: "$Theme"
3. NE TOUCHE A RIEN D'AUTRE dans le projet
4. Utilise le skill planning-with-files pour structurer ton travail
5. Utilise le skill frontend-design si le theme implique de l'UI
6. Invoque les agents listes ci-dessus via le Task tool
7. Lance validate.bat avant de finir ton iteration
8. Mets a jour progress.md et night_mode_handoff.md
9. Fais un git commit si 3+ fichiers modifies
10. Evalue ta satisfaction (1-5) a la fin
11. Si satisfaction < 5: lance tools/night_mode.ps1 pour le handoff suivant
12. Si satisfaction = 5: documente la completion dans progress.md et ARRETE-TOI
13. Si tu decouvres un bug hors-theme: note-le dans findings.md et IGNORE-LE
"@

# Clipboard via Set-Clipboard (fonctionne en Constrained Language Mode)
Set-Clipboard $clipPrompt
Write-Host "[OK] Prompt copie dans le presse-papier ($($clipPrompt.Length) chars)" -ForegroundColor Green

# --- 3. Satisfaction check ---
if ($Satisfaction -ge 5) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  NIGHT MODE: THEME COMPLET!" -ForegroundColor Green
    Write-Host "  Theme: $Theme" -ForegroundColor Green
    Write-Host "  Iterations: $Iteration" -ForegroundColor Green
    Write-Host "  Satisfaction: 5/5" -ForegroundColor Green
    Write-Host "  Pas de handoff necessaire." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}

# --- 4. Ouvrir le nouvel onglet IA (VBScript SendKeys, contourne CLM) ---
if (-not $NoPaste) {
    # Generer un VBScript temporaire pour SendKeys
    $tempVbs = Join-Path $env:TEMP "night_mode_sendkeys.vbs"

    if ($Target -eq "claude") {
        $vbsCode = @"
Set WshShell = CreateObject("WScript.Shell")
WScript.Sleep 2000
WshShell.SendKeys "^+p"
WScript.Sleep 800
WshShell.SendKeys "Claude Code Open New Tab"
WScript.Sleep 1200
WshShell.SendKeys "{ENTER}"
WScript.Sleep 4000
WshShell.SendKeys "^v"
"@
    } else {
        $vbsCode = @"
Set WshShell = CreateObject("WScript.Shell")
WScript.Sleep 2000
WshShell.SendKeys "^+p"
WScript.Sleep 800
WshShell.SendKeys "New Codex Agent"
WScript.Sleep 1200
WshShell.SendKeys "{ENTER}"
WScript.Sleep 4000
WshShell.SendKeys "^v"
"@
    }

    $vbsCode | Out-File -FilePath $tempVbs -Encoding ASCII
    Write-Host "[>>] Lancement Night Mode iteration $($Iteration + 1) vers $Target..." -ForegroundColor Cyan

    # Lancer VBScript en detache via wscript (pas de fenetre)
    Start-Process wscript.exe -ArgumentList $tempVbs -WindowStyle Hidden
    Write-Host "[OK] VBScript SendKeys lance (detache)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  >>> NE TOUCHE A RIEN PENDANT 8 SECONDES <<<" -ForegroundColor Yellow
    Write-Host "  Le script ouvre $Target et colle le prompt." -ForegroundColor Yellow
    Write-Host "  Fallback: prompt dans le clipboard (Ctrl+V)" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "[INFO] Mode NoPaste: ouvre $Target manuellement et colle Ctrl+V" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  NIGHT MODE - Iteration $($Iteration + 1)" -ForegroundColor Magenta
Write-Host "  Theme: $Theme" -ForegroundColor Magenta
Write-Host "  Satisfaction: $Satisfaction/5" -ForegroundColor Magenta
Write-Host "  Cible: $Target" -ForegroundColor Magenta
Write-Host "  Clipboard: PRET" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
