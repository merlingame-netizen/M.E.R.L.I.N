# Installe et verifie jev-router sur le poste Windows.
#   powershell -ExecutionPolicy Bypass -File tools\jev_router\install.ps1
$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path "$PSScriptRoot\..\..")

Write-Host "== 1/4 git pull" -ForegroundColor Cyan
git pull origin main

Write-Host "== 2/4 Ollama" -ForegroundColor Cyan
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) { throw "Ollama introuvable dans le PATH (https://ollama.com/download)" }
try { Invoke-RestMethod http://127.0.0.1:11434/api/tags -TimeoutSec 3 | Out-Null }
catch { Start-Process ollama -ArgumentList "serve" -WindowStyle Hidden; Start-Sleep 4 }
$model = (Get-Content tools\jev_router\lanes.json -Raw | ConvertFrom-Json).decider.model
ollama pull $model

Write-Host "== 3/4 Python" -ForegroundColor Cyan
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "'python' introuvable dans le PATH (requis par le hook et les MCP)" }
python -m unittest discover -s tools/jev_router/tests
if ($LASTEXITCODE -ne 0) { throw "tests unitaires KO" }

Write-Host "== 4/4 Verification reelle" -ForegroundColor Cyan
python tools/cli.py jev health
$eval = python tools/jev_router/jev.py eval | ConvertFrom-Json
Write-Host ("eval : {0}/{1} lanes exactes" -f $eval.exact, $eval.total)
if ($eval.exact -lt 7) { Write-Host "Moins de 7/8 : relancer (modele froid) ou verifier decider.model dans lanes.json" -ForegroundColor Yellow }
'{"prompt":"Ajoute un bouton pause au HUD du jeu"}' | python tools/jev_router/jev.py hook

Write-Host "OK. Redemarrer Claude Code et VS Code pour charger le hook et les serveurs MCP." -ForegroundColor Green
