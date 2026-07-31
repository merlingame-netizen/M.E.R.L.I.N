# Installe l'extension "MERLIN Studio" dans VS Code, sans npm et sans .vsix.
#
#   powershell -ExecutionPolicy Bypass -File tools\vscode-merlin-studio\install.ps1
#
# IMPORTANT - ce fichier est volontairement en ASCII PUR (aucun accent, aucun tiret
# cadratin, aucun guillemet typographique). Windows PowerShell 5.1 lit un .ps1 sans BOM
# en CP1252 : un caractere UTF-8 comme "-" long (E2 80 94) y devient trois octets dont
# 0x94, que PowerShell interprete comme un GUILLEMET fermant. Resultat : chaines et
# accolades desequilibrees, et le script ne parse plus. Ne pas reintroduire d'accents ici.
param(
  [string]$Url = "",
  [switch]$SkipSettings,
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"

function Say([string]$m, [string]$c = "Gray") { Write-Host $m -ForegroundColor $c }

Say ""
Say "=========================================" "Cyan"
Say " MERLIN Studio : installation VS Code" "Cyan"
Say "=========================================" "Cyan"

# 0. Se localiser (fonctionne quel que soit le dossier courant)
$src = $PSScriptRoot
if (-not $src) { $src = Split-Path -Parent $MyInvocation.MyCommand.Path }
Say "Source     : $src"

if (-not (Test-Path (Join-Path $src "extension.js"))) {
  Say "[ECHEC] extension.js introuvable dans ce dossier." "Red"
  Say "        Fais d'abord : git -C <ton-depot-MERLIN> pull" "Yellow"
  exit 1
}

# 1. Trouver l'installation VS Code (Code, Insiders, VSCodium)
$vsList = @(
  @{ Name = "VS Code";          Dir = ".vscode";          App = "Code" },
  @{ Name = "VS Code Insiders"; Dir = ".vscode-insiders"; App = "Code - Insiders" },
  @{ Name = "VSCodium";         Dir = ".vscode-oss";      App = "VSCodium" }
)
$target = $null
foreach ($v in $vsList) {
  $ext = Join-Path (Join-Path $env:USERPROFILE $v.Dir) "extensions"
  if (Test-Path $ext) {
    $target = @{ Name = $v.Name; Ext = $ext; Set = (Join-Path (Join-Path (Join-Path $env:APPDATA $v.App) "User") "settings.json") }
    break
  }
}
if (-not $target) {
  $ext = Join-Path (Join-Path $env:USERPROFILE ".vscode") "extensions"
  Say "Aucun dossier d'extensions trouve, creation : $ext" "Yellow"
  New-Item -ItemType Directory -Force -Path $ext | Out-Null
  $target = @{ Name = "VS Code"; Ext = $ext; Set = (Join-Path (Join-Path (Join-Path $env:APPDATA "Code") "User") "settings.json") }
}
Say "VS Code    : $($target.Name)"

$dst = Join-Path $target.Ext "merlin-local.merlin-studio-1.0.0"
Say "Cible      : $dst"

# Desinstallation
if ($Uninstall) {
  if (Test-Path $dst) {
    Remove-Item -Recurse -Force $dst
    Say "[ok] Desinstalle." "Green"
  } else {
    Say "Rien a desinstaller."
  }
  Say "Redemarre VS Code pour finaliser."
  exit 0
}

# 2. Copier l'extension
try {
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item (Join-Path $src "extension.js") $dst -Force
  Copy-Item (Join-Path $src "package.json") $dst -Force
  $readme = Join-Path $src "README.md"
  if (Test-Path $readme) { Copy-Item $readme $dst -Force }
  $media = Join-Path $src "media"
  if (Test-Path $media) { Copy-Item $media $dst -Recurse -Force }
  Say "[ok] Fichiers copies" "Green"
} catch {
  Say "[ECHEC] copie impossible : $($_.Exception.Message)" "Red"
  Say "        Si VS Code est ouvert, ferme-le et relance." "Yellow"
  exit 1
}

# 3. URL du studio dans les reglages (jamais destructif)
if (-not $SkipSettings) {
  if (-not $Url) {
    Say ""
    $Url = Read-Host "URL du studio sur la VM (Entree = passer)"
  }
  if ($Url) {
    $settings = $target.Set
    $obj = $null
    if (Test-Path $settings) {
      $raw = Get-Content $settings -Raw
      # settings.json de VS Code est du JSONC. PowerShell 7 sait lire les commentaires
      # mais ConvertTo-Json les PERD a la reecriture : on refuse donc de toucher au
      # fichier des qu'il en contient. (PowerShell 5.1, lui, echoue au parse : meme
      # resultat, fichier intact.) Detection explicite, sans dependre du parseur.
      $hasComments = ($raw -match '(?m)^\s*//') -or ($raw -match '/\*')
      if ($hasComments) {
        $obj = $null
      } elseif ($raw.Trim()) {
        try { $obj = $raw | ConvertFrom-Json } catch { $obj = $null }
      } else {
        $obj = New-Object PSObject
      }
    } else {
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $settings) | Out-Null
      $obj = New-Object PSObject
    }
    if ($null -eq $obj) {
      Say "[!] settings.json contient des commentaires : LAISSE INTACT (rien n'est perdu)." "Yellow"
      Say "    Tu saisiras l'URL via 'MERLIN: Configurer la connexion'." "Yellow"
    } else {
      try {
        $obj | Add-Member -NotePropertyName "merlinStudio.url" -NotePropertyValue $Url.TrimEnd('/') -Force
        if (Test-Path $settings) { Copy-Item $settings ($settings + ".bak-merlin") -Force }
        $obj | ConvertTo-Json -Depth 32 | Set-Content $settings -Encoding UTF8
        Say "[ok] merlinStudio.url enregistre" "Green"
      } catch {
        Say "[!] Reglages non modifies : $($_.Exception.Message)" "Yellow"
      }
    }
  } else {
    Say "URL non renseignee, tu la saisiras dans VS Code." "Yellow"
  }
}

# 4. Verification finale
Say ""
$okJs = Test-Path (Join-Path $dst "extension.js")
$okPkg = Test-Path (Join-Path $dst "package.json")
if ($okJs -and $okPkg) {
  Say "INSTALLATION REUSSIE" "Green"
  Say "  1) VS Code : Ctrl+Shift+P puis 'Developer: Reload Window'"
  Say "  2) Ctrl+Shift+P puis 'MERLIN: Configurer la connexion' (colle le token)"
  Say "  3) L icone MERLIN apparait dans la barre laterale gauche"
  exit 0
} else {
  Say "[ECHEC] fichiers absents dans $dst" "Red"
  exit 1
}
