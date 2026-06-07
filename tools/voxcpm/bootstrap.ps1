# bootstrap.ps1 — Merlin TTS : tout-en-un (clone + install + lance + ouvre la page)
#
# Pensé pour un PC où `.bat` est bloqué et où `python` n'est pas dans le PATH
# (on utilise le lanceur `py`). À COLLER dans PowerShell (pas besoin d'exécuter
# le fichier) — voir docs/VOXCPM_DEPLOYMENT.md.
#
# Paramètres : -Port 8810  -Dir "C:\chemin\repo"  -Branch <branche>
param(
    [int]$Port = 8810,
    [string]$Dir = (Join-Path $env:USERPROFILE "M.E.R.L.I.N"),
    [string]$Branch = "claude/voxcpm-local-deploy-V118n",
    [string]$RepoUrl = "https://github.com/merlingame-netizen/M.E.R.L.I.N.git"
)

$ErrorActionPreference = "Stop"

# 1) Trouver Python (py, sinon python/python3)
$py = $null
foreach ($c in @("py", "python", "python3")) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { $py = $cmd.Source; break }
}
if (-not $py) {
    Write-Host "[X] Python introuvable. Installe-le : https://www.python.org/downloads/ (coche 'Add python.exe to PATH')." -ForegroundColor Red
    return
}
Write-Host "[OK] Python : $py" -ForegroundColor Green

# 2) Git présent ?
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[X] git introuvable. Installe-le : https://git-scm.com/download/win" -ForegroundColor Red
    return
}

# 3) Cloner ou mettre à jour
if (Test-Path (Join-Path $Dir ".git")) {
    Write-Host "[..] Repo present, mise a jour ($Branch)..." -ForegroundColor Cyan
    git -C $Dir fetch origin $Branch
    git -C $Dir checkout $Branch
    git -C $Dir pull origin $Branch
} else {
    Write-Host "[..] Clonage dans $Dir ..." -ForegroundColor Cyan
    git clone --branch $Branch $RepoUrl $Dir
}

# 4) Lancer le serveur (installe deps + voix + ouvre le navigateur)
$serve = Join-Path $Dir "tools\voxcpm\serve.py"
Write-Host "[..] Lancement du serveur TTS sur le port $Port ..." -ForegroundColor Cyan
Write-Host "     (Laisse cette fenetre ouverte. Ctrl+C pour arreter.)" -ForegroundColor Yellow
& $py $serve --port $Port
