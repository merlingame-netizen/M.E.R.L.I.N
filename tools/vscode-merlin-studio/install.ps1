# Installe l'extension "MERLIN Studio" dans VS Code — sans npm, sans .vsix.
#
#   PS> powershell -ExecutionPolicy Bypass -File tools\vscode-merlin-studio\install.ps1
#
# Robuste par construction :
#   * se localise tout seul (peu importe le dossier courant)
#   * detecte VS Code / Insiders / VSCodium, cree le dossier d'extensions au besoin
#   * DIT ce qu'il fait a chaque etape (impossible qu'il "ne fasse rien" en silence)
#   * n'ecrase JAMAIS settings.json s'il n'est pas relisible de facon sure
# Le TOKEN n'est jamais ecrit sur disque : il va dans le coffre chiffre de VS Code via
# la commande "MERLIN: Configurer la connexion".
param(
  [string]$Url = "",
  [switch]$SkipSettings,
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"

function Say($m, $c = "Gray") { Write-Host $m -ForegroundColor $c }
Say ""
Say "=========================================" Cyan
Say " MERLIN Studio — installation VS Code" Cyan
Say "=========================================" Cyan

# ── 0. Se localiser (marche meme si lance depuis n'importe ou) ───────────────
$src = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Say "Source de l'extension : $src"
if (-not (Test-Path (Join-Path $src "extension.js"))) {
  Say "[ECHEC] extension.js introuvable dans $src" Red
  Say "        Tu n'es pas dans le depot MERLIN, ou 'git pull' n'a pas ramene le fichier." Yellow
  Say "        Trouve le depot :" Yellow
  Say '        Get-ChildItem $env:USERPROFILE -Recurse -Depth 3 -Filter project.godot -ErrorAction SilentlyContinue | Select -First 5 FullName' Yellow
  exit 1
}

# ── 1. Trouver l'installation VS Code (Code / Insiders / VSCodium) ──────────
$candidates = @(
  @{ Name = "VS Code";          Ext = (Join-Path $env:USERPROFILE ".vscode\extensions");          Set = (Join-Path $env:APPDATA "Code\User\settings.json") },
  @{ Name = "VS Code Insiders"; Ext = (Join-Path $env:USERPROFILE ".vscode-insiders\extensions"); Set = (Join-Path $env:APPDATA "Code - Insiders\User\settings.json") },
  @{ Name = "VSCodium";         Ext = (Join-Path $env:USERPROFILE ".vscode-oss\extensions");      Set = (Join-Path $env:APPDATA "VSCodium\User\settings.json") }
)
$target = $candidates | Where-Object { Test-Path $_.Ext } | Select-Object -First 1
if (-not $target) {
  # Rien de detecte : VS Code est peut-etre installe mais n'a jamais cree le dossier.
  $target = $candidates[0]
  Say "Aucun dossier d'extensions existant — creation de : $($target.Ext)" Yellow
  New-Item -ItemType Directory -Force -Path $target.Ext | Out-Null
} else {
  Say "VS Code detecte : $($target.Name)"
}
$dst = Join-Path $target.Ext "merlin-local.merlin-studio-1.0.0"
Say "Cible : $dst"

# ── Desinstallation ─────────────────────────────────────────────────────────
if ($Uninstall) {
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst; Say "[ok] Desinstalle." Green }
  else { Say "Rien a desinstaller." }
  Say "Redemarre VS Code pour finaliser."
  exit 0
}

# ── 2. Copier l'extension ───────────────────────────────────────────────────
try {
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item (Join-Path $src "extension.js") $dst -Force
  Copy-Item (Join-Path $src "package.json") $dst -Force
  Copy-Item (Join-Path $src "README.md")    $dst -Force -ErrorAction SilentlyContinue
  $media = Join-Path $src "media"
  if (Test-Path $media) { Copy-Item $media $dst -Recurse -Force }
  Say "[ok] Fichiers copies" Green
} catch {
  Say "[ECHEC] copie impossible : $($_.Exception.Message)" Red
  Say "        VS Code est peut-etre ouvert et verrouille le dossier — ferme-le et relance." Yellow
  exit 1
}

# ── 3. URL dans les reglages (optionnel, jamais destructif) ─────────────────
if (-not $SkipSettings) {
  if (-not $Url) {
    Say ""
    $Url = Read-Host "URL du studio sur la VM (Entree = passer, ex. https://xxxx.trycloudflare.com)"
  }
  if ($Url) {
    $settings = $target.Set
    $obj = $null
    if (Test-Path $settings) {
      $raw = Get-Content $settings -Raw
      if ($raw.Trim()) { try { $obj = $raw | ConvertFrom-Json } catch { $obj = $null } }
      else { $obj = New-Object PSObject }
    } else {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $settings) | Out-Null
      $obj = New-Object PSObject
    }
    if ($null -eq $obj) {
      Say "[!] settings.json contient des commentaires : LAISSE INTACT (rien n'a ete ecrase)." Yellow
      Say "    Tu saisiras l'URL via 'MERLIN: Configurer la connexion'." Yellow
    } else {
      try {
        $obj | Add-Member -NotePropertyName "merlinStudio.url" -NotePropertyValue $Url.TrimEnd('/') -Force
        if (Test-Path $settings) { Copy-Item $settings "$settings.bak-merlin" -Force }
        $obj | ConvertTo-Json -Depth 32 | Set-Content $settings -Encoding UTF8
        Say "[ok] merlinStudio.url = $($Url.TrimEnd('/'))" Green
      } catch {
        Say "[!] Reglages non modifies : $($_.Exception.Message)" Yellow
      }
    }
  } else {
    Say "URL non renseignee — tu la saisiras dans VS Code." Yellow
  }
}

# ── 4. Verification finale ──────────────────────────────────────────────────
Say ""
$okJs  = Test-Path (Join-Path $dst "extension.js")
$okPkg = Test-Path (Join-Path $dst "package.json")
if ($okJs -and $okPkg) {
  Say "INSTALLATION REUSSIE" Green
  Say "  Fichiers en place : $dst"
  Say ""
  Say "  Etapes suivantes :" Cyan
  Say "   1) Dans VS Code : Ctrl+Shift+P > 'Developer: Reload Window'"
  Say "   2) Ctrl+Shift+P > 'MERLIN: Configurer la connexion'  (colle le token du studio)"
  Say "   3) L'icone MERLIN apparait dans la barre laterale gauche"
} else {
  Say "[ECHEC] Les fichiers ne sont pas en place dans $dst" Red
  exit 1
}
Say ""
