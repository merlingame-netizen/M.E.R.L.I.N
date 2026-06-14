# M.E.R.L.I.N. — Oracle VM watcher : first-time setup (Windows PowerShell)
# Run once:  powershell -ExecutionPolicy Bypass -File setup.ps1
# Prereqs you must have placed yourself (from the RESTORE.txt bundle I sent):
#   - OCI API private key  -> %USERPROFILE%\.oci\oci_api_key.pem
#   - SSH private key       -> %USERPROFILE%\.ssh\merlin_oracle_ed25519
$ErrorActionPreference = "Stop"
$here  = $PSScriptRoot
$tfdir = Resolve-Path (Join-Path $here "..\terraform")

Write-Host "== M.E.R.L.I.N. Oracle watcher setup ==" -ForegroundColor Cyan

# 1) Terraform
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Terraform via winget..."
  winget install -e --id Hashicorp.Terraform --accept-source-agreements --accept-package-agreements
  Write-Host "If 'terraform' isn't found after this, open a NEW terminal and re-run setup.ps1."
} else { Write-Host "Terraform: OK" }

# 2) Keys
$ociKey = Join-Path $env:USERPROFILE ".oci\oci_api_key.pem"
$sshKey = Join-Path $env:USERPROFILE ".ssh\merlin_oracle_ed25519"
New-Item -ItemType Directory -Force -Path (Split-Path $ociKey) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $sshKey) | Out-Null
if (-not (Test-Path $ociKey)) { Write-Warning "MISSING: $ociKey  — copy oci_api_key.pem there (from the bundle)." }
else { Write-Host "OCI API key: OK" }
if (-not (Test-Path $sshKey)) { Write-Warning "MISSING: $sshKey  — copy your SSH private key there." }
else { Write-Host "SSH key: OK" }

# 3) terraform.tfvars (from the shipped .win template, with your real key path)
$tfvarsWin = Join-Path $here "terraform.tfvars.win"
$tfvarsOut = Join-Path $tfdir "terraform.tfvars"
if (-not (Test-Path $tfvarsWin)) { throw "Missing $tfvarsWin (I sent it — drop it in this folder)." }
$keyPathFwd = ($ociKey -replace '\\','/')
(Get-Content $tfvarsWin -Raw).Replace("__OCI_KEY_PATH__", $keyPathFwd) | Set-Content -NoNewline $tfvarsOut
Write-Host "Wrote $tfvarsOut (key path: $keyPathFwd)"

# 4) Bootstrap state (network + budget already exist in OCI; avoids recreating them)
$bootstrap = Join-Path $here "terraform.tfstate.bootstrap"
$statePath = Join-Path $tfdir "terraform.tfstate"
if ((Test-Path $bootstrap) -and (-not (Test-Path $statePath))) {
  Copy-Item $bootstrap $statePath
  Write-Host "Installed bootstrap state (existing network/budget)."
}

# 5) Init
Push-Location $tfdir
terraform init -input=false | Out-Null
Pop-Location
Write-Host "Setup complete. Next: powershell -ExecutionPolicy Bypass -File merlin-watch.ps1" -ForegroundColor Green
