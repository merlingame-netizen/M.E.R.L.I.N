# M.E.R.L.I.N. — Oracle VM watcher (Windows). Runs 24/7, deploys the instant a
# free A1 host opens. Built-in free-tier guard: refuses to apply anything outside
# the Always Free quota. Run: powershell -ExecutionPolicy Bypass -File merlin-watch.ps1
param([int]$IntervalSeconds = 180)
$ErrorActionPreference = "Stop"
$tfdir = Resolve-Path (Join-Path $PSScriptRoot "..\terraform")

function Assert-FreeTier {
  $tf = Get-Content (Join-Path $tfdir "terraform.tfvars") -Raw
  $shape = [regex]::Match($tf, 'instance_shape\s*=\s*"([^"]+)"').Groups[1].Value
  $ocpus = [int][regex]::Match($tf, 'ocpus\s*=\s*(\d+)').Groups[1].Value
  $mem   = [int][regex]::Match($tf, 'memory_in_gbs\s*=\s*(\d+)').Groups[1].Value
  $boot  = [int]([regex]::Match($tf, 'boot_volume_size_in_gbs\s*=\s*(\d+)').Groups[1].Value)
  $okShapes = @("VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro")
  if ($okShapes -notcontains $shape) { throw "FREE-TIER GUARD: shape '$shape' is not Always-Free. Aborting." }
  if ($shape -eq "VM.Standard.A1.Flex" -and ($ocpus -gt 4 -or $mem -gt 24)) {
    throw "FREE-TIER GUARD: $ocpus OCPU / $mem GB exceeds 4/24. Aborting."
  }
  if ($boot -gt 200) { throw "FREE-TIER GUARD: boot volume $boot GB exceeds 200. Aborting." }
  return "$shape ${ocpus}c/${mem}GB"
}

$cfg = Assert-FreeTier
Write-Host "Free-tier guard OK ($cfg). Watching for capacity every $IntervalSeconds s. Ctrl-C to stop." -ForegroundColor Cyan

while ($true) {
  $ts = Get-Date -Format "HH:mm:ss"
  Assert-FreeTier | Out-Null     # re-check every cycle
  Push-Location $tfdir
  $out = (terraform apply -auto-approve -input=false 2>&1) | Out-String
  Pop-Location

  if ($out -match "Apply complete") {
    Push-Location $tfdir
    $ip = (terraform output -raw public_ip 2>$null)
    Pop-Location
    Write-Host "`n$ts  SUCCESS — VM deployed! Public IP: $ip" -ForegroundColor Green
    [console]::beep(880,300); [console]::beep(1175,300)

    # Write the 'merlin-vm' SSH alias (with all service tunnels)
    $sshCfg = Join-Path $env:USERPROFILE ".ssh\config"
    $key    = Join-Path $env:USERPROFILE ".ssh\merlin_oracle_ed25519"
    $block  = @"

# >>> merlin-vm (managed by merlin) >>>
Host merlin-vm
    HostName $ip
    User ubuntu
    IdentityFile $key
    LocalForward 11434 localhost:11434
    LocalForward 3000 localhost:3000
    LocalForward 8443 localhost:8443
    LocalForward 8081 localhost:8081
    LocalForward 5432 localhost:5432
    ServerAliveInterval 60
    StrictHostKeyChecking accept-new
# <<< merlin-vm (managed by merlin) <<<
"@
    Add-Content -Path $sshCfg -Value $block
    Write-Host "Added 'merlin-vm' to $sshCfg"
    Write-Host "Connect:  ssh merlin-vm   (then on localhost: :3000 Open WebUI, :8443 VS Code, :8081 files, :11434 Ollama)"
    Write-Host "First boot installs the stack (~10 min). Passwords: ssh merlin-vm then 'cat /opt/merlin/stack/.env'"
    break
  }
  elseif ($out -match "Out of host capacity") {
    Write-Host "$ts  capacity miss — retry in $IntervalSeconds s"
  }
  else {
    Write-Host "$ts  Unexpected output:`n$out" -ForegroundColor Red
    Write-Host "Stopping so you can review. Re-run after fixing." -ForegroundColor Yellow
    break
  }
  Start-Sleep -Seconds $IntervalSeconds
}
