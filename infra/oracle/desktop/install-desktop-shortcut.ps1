# Creates a "M.E.R.L.I.N VM" shortcut on your Windows Desktop.
# Double-clicking it opens a console and SSHes into the VM (Ollama tunnel included
# via the 'merlin-vm' alias from scripts/install-ssh-alias.sh).
$ErrorActionPreference = "Stop"

$alias   = "merlin-vm"
$desktop = [Environment]::GetFolderPath("Desktop")
$lnkPath = Join-Path $desktop "M.E.R.L.I.N VM.lnk"

# Sanity: warn if the SSH alias isn't set up yet.
$sshCfg = Join-Path $env:USERPROFILE ".ssh\config"
if (-not (Test-Path $sshCfg) -or -not (Select-String -Path $sshCfg -Pattern "Host $alias" -Quiet)) {
    Write-Warning "SSH alias '$alias' not found in ~/.ssh/config."
    Write-Warning "Run infra/oracle/scripts/install-ssh-alias.sh (Git Bash/WSL) after 'terraform apply'."
}

$shell    = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($lnkPath)
$shortcut.TargetPath       = "$env:WINDIR\System32\cmd.exe"
$shortcut.Arguments        = "/k title M.E.R.L.I.N VM && ssh $alias"
$shortcut.WorkingDirectory = $env:USERPROFILE
$shortcut.IconLocation     = "$env:WINDIR\System32\shell32.dll,18"  # network/computer icon
$shortcut.Description       = "Connect to the M.E.R.L.I.N Oracle VM (SSH + Ollama tunnel)"
$shortcut.Save()

Write-Host "Created desktop shortcut: $lnkPath" -ForegroundColor Green
Write-Host "Double-click 'M.E.R.L.I.N VM' on your Desktop to connect."
