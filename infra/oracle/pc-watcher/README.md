# PC Watcher — auto-deploy the Oracle VM the instant capacity opens (stays free)

A 24/7 watcher you run on your **Windows PC**. It polls Oracle and, the moment a
free **A1 host** opens in Paris, deploys the VM 4/24 + full dev stack automatically.
Runs far more reliably than the cloud watcher (your PC is up more than the agent's
ephemeral container). With your account on Pay As You Go, you get **priority** on the
first freed host.

**Stays 100% free:** a built-in guard refuses to apply anything outside the Always
Free quota (shape must be A1.Flex ≤ 4 OCPU/24 GB or E2.1.Micro; boot ≤ 200 GB). The
Oracle budget alert (first-cent email) is your second safety net.

## What you need (one-time)

1. **The project on your PC.** Clone or download:
   `git clone https://github.com/merlingame-netizen/M.E.R.L.I.N.git`
   (or GitHub → Code → Download ZIP, then unzip).
2. **Two files I sent you** — drop them into this folder (`infra/oracle/pc-watcher/`):
   - `terraform.tfvars.win`
   - `terraform.tfstate.bootstrap`
3. **Your keys**, placed here:
   - OCI API key → `C:\Users\<you>\.oci\oci_api_key.pem`
   - SSH private key → `C:\Users\<you>\.ssh\merlin_oracle_ed25519`
   (both are in the RESTORE.txt bundle I sent earlier)

## Run it

```powershell
cd <repo>\infra\oracle\pc-watcher
powershell -ExecutionPolicy Bypass -File setup.ps1        # installs Terraform, wires keys/config/state
powershell -ExecutionPolicy Bypass -File merlin-watch.ps1 # starts the 24/7 watch
```

Leave the watch window open (or set it to run at logon — see below). When a host
frees up, it deploys, beeps, and adds an `ssh merlin-vm` alias. Then:

```powershell
ssh merlin-vm
# on your machine: http://localhost:3000 (Open WebUI), :8443 (VS Code),
#                  :8081 (files), :11434 (Ollama), psql -h localhost -p 5432
```

## Keep it running across reboots (optional)

Task Scheduler → Create Task → Trigger: *At log on* → Action:
`powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\path\to\merlin-watch.ps1`

## Notes

- Don't run this **and** the cloud watcher at the same time (they'd fight over the
  same Terraform state). Tell me to stop the cloud one when you start this.
- It only ever deploys the free 4/24 config; to change anything, edit
  `..\terraform\terraform.tfvars` — the guard still blocks non-free values.
