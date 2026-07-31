# Installe l'extension "MERLIN Studio" dans VS Code, sans npm, sans .vsix a manipuler.
#
#   PS> cd C:\Users\PGNK2128\Godot-MCP        # ton depot MERLIN
#   PS> git pull
#   PS> powershell -ExecutionPolicy Bypass -File tools\vscode-merlin-studio\install.ps1
#
# Ce que ca fait :
#   1. copie l'extension dans %USERPROFILE%\.vscode\extensions\  (VS Code la charge au demarrage)
#   2. (optionnel) ecrit l'URL du studio dans tes reglages utilisateur
#   3. verifie l'installation
# Le TOKEN n'est pas ecrit ici : il va dans le coffre chiffre de VS Code, via
# "MERLIN: Configurer la connexion" au premier lancement.
param(
  [string]$Url = "",              # ex. https://xxxx.trycloudflare.com
  [switch]$SkipSettings,
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"
$ext = "merlin-local.merlin-studio-1.0.0"
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$dstRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
$dst = Join-Path $dstRoot $ext

if ($Uninstall) {
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst; Write-Host "Desinstalle : $dst" -ForegroundColor Yellow }
  else { Write-Host "Rien a desinstaller." }
  Write-Host "Redemarre VS Code pour finaliser."
  exit 0
}

Write-Host "==> Installation de MERLIN Studio" -ForegroundColor Cyan
Write-Host "    source : $src"
Write-Host "    cible  : $dst"

if (-not (Test-Path (Join-Path $src "extension.js"))) {
  throw "extension.js introuvable — lance ce script depuis le depot MERLIN (tools\vscode-merlin-studio\install.ps1)."
}
if (-not (Test-Path $dstRoot)) {
  throw "Dossier d'extensions VS Code introuvable ($dstRoot). VS Code est-il installe pour cet utilisateur ?"
}

# 1. copie (remplace proprement une version precedente)
if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item (Join-Path $src "extension.js")  $dst
Copy-Item (Join-Path $src "package.json")  $dst
Copy-Item (Join-Path $src "README.md")     $dst -ErrorAction SilentlyContinue
$media = Join-Path $src "media"
if (Test-Path $media) { Copy-Item $media $dst -Recurse }
Write-Host "    [ok] fichiers copies" -ForegroundColor Green

# 2. URL dans les reglages utilisateur (le token reste dans le coffre VS Code)
if (-not $SkipSettings) {
  if (-not $Url) {
    $Url = Read-Host "URL du studio sur la VM (Entree pour passer, ex. https://xxxx.trycloudflare.com)"
  }
  if ($Url) {
    $settings = Join-Path $env:APPDATA "Code\User\settings.json"
    # Prudence : settings.json est du JSONC (commentaires autorises). Si on n'arrive pas a
    # le relire de facon SURE, on ne le reecrit PAS — hors de question d'ecraser tes reglages.
    $obj = $null
    if (Test-Path $settings) {
      $raw = Get-Content $settings -Raw
      if ($raw.Trim()) {
        try { $obj = $raw | ConvertFrom-Json } catch { $obj = $null }
      } else { $obj = New-Object PSObject }
    } else {
      $obj = New-Object PSObject
    }
    if ($null -eq $obj) {
      Write-Host "    [!] settings.json contient des commentaires ou n'est pas lisible :" -ForegroundColor Yellow
      Write-Host "        reglages LAISSES INTACTS. Saisis l'URL via 'MERLIN: Configurer la connexion'." -ForegroundColor Yellow
    } else {
      try {
        $obj | Add-Member -NotePropertyName "merlinStudio.url" -NotePropertyValue $Url.TrimEnd('/') -Force
        if (Test-Path $settings) { Copy-Item $settings "$settings.bak-merlin" -Force }
        $obj | ConvertTo-Json -Depth 32 | Set-Content $settings -Encoding UTF8
        Write-Host "    [ok] merlinStudio.url ecrit (sauvegarde : settings.json.bak-merlin)" -ForegroundColor Green
      } catch {
        Write-Host "    [!] reglages non modifies ($($_.Exception.Message))." -ForegroundColor Yellow
      }
    }
  }
}

# 3. verification
$okFiles = (Test-Path (Join-Path $dst "extension.js")) -and (Test-Path (Join-Path $dst "package.json"))
Write-Host ""
if ($okFiles) {
  Write-Host "Installation terminee." -ForegroundColor Green
  Write-Host "  1) REDEMARRE VS Code (Ctrl+Shift+P > 'Developer: Reload Window' suffit)"
  Write-Host "  2) Ctrl+Shift+P > 'MERLIN: Configurer la connexion'  (colle le token du studio)"
  Write-Host "  3) L'icone MERLIN apparait dans la barre laterale gauche."
} else {
  throw "La copie a echoue — verifie les droits sur $dstRoot"
}
