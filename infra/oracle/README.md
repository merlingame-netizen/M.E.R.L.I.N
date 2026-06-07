# Oracle Cloud ARM A1 — M.E.R.L.I.N. host (Always Free)

Provision and configure a free Oracle Cloud **Ampere A1** VM
(**4 OCPU / 24 GB RAM**, region `eu-paris-1`) to host your Claude/dev/Godot
workloads. Infrastructure is **Terraform + cloud-init** so it is reproducible
and survives ephemeral CI sessions.

> **Why not just drive the web console with a browser?**
> Logging into `cloud.oracle.com` requires your password + MFA, which can't be
> automated safely from a headless container. The supported, secure path is the
> **OCI API (Terraform)**: you never share your password — only an API *public*
> key you paste in the console and public OCIDs. That's what this folder does.

## What gets installed on the VM (via cloud-init)

| Workload | Detail |
|----------|--------|
| **Ollama + Gemma** | systemd service on `127.0.0.1:11434`; pulls `gemma3:4b` + `gemma3:12b` (CPU inference, async generation). Configurable via `ollama_models`. |
| **Godot headless** | `4.4.1` arm64 → `/usr/local/bin/godot` for `validate` / `smoke` / `export` CI. |
| **Node 20 + Claude Code** | `@anthropic-ai/claude-code` global install; Node for the MERLIN `server/` build. |
| **Dev base** | git, python3, build-essential, tmux, ufw, 8 GB swap. |
| **Repo mirror** | optional auto-clone of `git_repos` into `~/workspace`. |

> ⚠️ ARM A1 has **no GPU**. A 12B model quantized (Q4) loads in ~8 GB and runs,
> but CPU inference is slow — good for **async** card/scenario generation, not
> real-time interactive narration.

---

## Prerequisites

- An **active** Oracle Cloud account (Always Free or Pay As You Go).
- On your machine: `terraform` (>= 1.5), `openssl`, `ssh`. (Optional: the `oci` CLI.)

---

## Step 1 — Generate keys (your machine)

```bash
cd infra/oracle/scripts
./generate-keys.sh
```

This creates:
- OCI API signing key → `~/.oci/oci_api_key.pem` (+ public)
- SSH key → `~/.ssh/merlin_oracle_ed25519` (+ public)

and prints the **public API key**, the **fingerprint**, and the exact
`terraform.tfvars` snippet to use.

## Step 2 — Register the API key + collect OCIDs (Oracle Console, browser)

1. **Console → Profile (top-right) → My profile → API keys → Add API key →
   Paste a public key** → paste the public key printed in Step 1 → **Add**.
2. Confirm the **fingerprint** matches the one printed in Step 1.
3. Copy OCIDs:
   - **user_ocid** — Profile → My profile → *Copy OCID*
   - **tenancy_ocid** — Profile → Tenancy → *Copy OCID*

> No password, no MFA token, nothing secret leaves your machine — only the
> *public* key is uploaded.

## Step 3 — Configure Terraform

```bash
cd infra/oracle/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with the values from Step 1-2
```

Recommended: lock SSH to your IP — set `allowed_ssh_cidr = "$(curl -s ifconfig.me)/32"`.

## Step 4 — Deploy

```bash
# from infra/oracle/
./scripts/deploy.sh          # init + plan + (confirm) apply
# or manually:
cd terraform && terraform init && terraform apply
```

Outputs give you `public_ip`, the `ssh_command`, and the `ollama_tunnel_command`.

## Step 5 — Verify

```bash
ssh ubuntu@<public_ip>
cloud-init status --wait                 # wait for provisioning to finish
cat /opt/merlin/README.txt
godot --headless --version
ollama list                              # gemma models (may still be pulling)
tail -f /var/log/merlin-models.log       # model pull progress
```

Use the remote Ollama from your laptop via SSH tunnel (port stays private):

```bash
ssh -N -L 11434:localhost:11434 ubuntu@<public_ip>
# now http://localhost:11434 on your machine talks to the VM's Ollama
```

---

## The connection "bridge" (easy access)

After `apply`, install a one-word SSH alias on your machine:

```bash
./scripts/install-ssh-alias.sh        # writes a 'merlin-vm' block into ~/.ssh/config
```

Then connecting is trivial — the Ollama tunnel is wired in automatically:

```bash
ssh merlin-vm                          # shell on the VM + localhost:11434 -> remote Ollama
scp file merlin-vm:~/                  # copy files
code --remote ssh-remote+merlin-vm /home/ubuntu/workspace   # VS Code Remote-SSH
```

No-config one-shots (read IP straight from terraform outputs):

```bash
./scripts/connect.sh                   # ssh in
./scripts/connect.sh merlin-status     # run a command remotely
./scripts/tunnel.sh                    # just the Ollama tunnel (foreground)
```

On the VM you also get shortcuts: `merlin` (status), `ws` (cd workspace),
`gv` (godot version), `ol` (ollama list).

### Desktop shortcut

Want a one-click icon on your Desktop? (Requires the `merlin-vm` alias above.)

- **Windows**: double-click `desktop/Install Desktop Shortcut.cmd` → creates a
  **"M.E.R.L.I.N VM"** icon on your Desktop that opens an SSH session.
- **macOS / Linux**: `bash desktop/install-desktop-shortcut.sh` → creates a
  `.command` (mac) / `.desktop` (linux) launcher on your Desktop.

## Claude Code runner (systemd, on the VM)

`enable_claude_runner = true` (default) installs a `merlin-runner` service.
It stays **idle** until you configure it (so it never crash-loops):

```bash
ssh merlin-vm
sudo cp /etc/merlin/runner.env.example /etc/merlin/runner.env
sudo nano /etc/merlin/runner.env        # set ANTHROPIC_API_KEY, RUNNER_WORKDIR, RUNNER_CMD
sudo systemctl restart merlin-runner
journalctl -u merlin-runner -f
```

`RUNNER_CMD` is whatever you want to run headless at boot, e.g.
`claude -p "run validate + smoke and summarize"` or `bash tools/autodev/run.sh`.

---

## "Out of host capacity" (the classic A1 problem)

A1 free capacity is scarce in popular regions. If `apply` fails with
`Out of host capacity`:

1. Re-run `terraform apply` (capacity frees up intermittently — retry in a loop).
2. Try another availability domain: set `availability_domain_number = 2` (or 3)
   in `terraform.tfvars`, then re-apply. *(Paris currently has 1 AD, so this
   mainly helps in multi-AD regions.)*
3. Reduce the ask temporarily (`ocpus = 1`, `memory_in_gbs = 6`) to grab a
   foothold, then scale up later.
4. Upgrade the account to **Pay As You Go** — gives provisioning priority while
   keeping the Always Free quota (you're only billed if you exceed it).

A simple retry loop:

```bash
cd terraform
until terraform apply -auto-approve; do echo "retrying in 120s..."; sleep 120; done
```

---

## Cost & quota notes (staying free)

- A1 free quota = **4 OCPU + 24 GB RAM total** across all A1 VMs. This config
  uses all of it in one VM. Don't run a second A1 VM concurrently.
- Block storage free quota = **200 GB total**; boot volume defaults to 100 GB.
- Always Free **idle** compute can be reclaimed on a free account after ~7 days
  idle. Keeping it lightly busy (or upgrading to PAYG) avoids this.

## Tear down

```bash
cd terraform && terraform destroy
```

---

## Files

```
infra/oracle/
├── README.md                      # this runbook
├── terraform/
│   ├── versions.tf  providers.tf  variables.tf
│   ├── main.tf                    # VCN, subnet, IGW, security list, A1 instance
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── cloud-init/
│   └── cloud-init.yaml.tftpl      # VM provisioning (Ollama/Gemma, Godot, Claude Code)
└── scripts/
    ├── generate-keys.sh           # API + SSH keys, prints tfvars snippet
    ├── deploy.sh                  # init/plan/apply wrapper
    ├── install-ssh-alias.sh       # adds 'merlin-vm' to ~/.ssh/config (+ Ollama tunnel)
    ├── connect.sh                 # one-shot SSH using terraform outputs
    └── tunnel.sh                  # Ollama tunnel only
└── desktop/
    ├── Install Desktop Shortcut.cmd   # Windows: double-click to create the icon
    ├── install-desktop-shortcut.ps1   # Windows: the shortcut creator
    └── install-desktop-shortcut.sh    # macOS/Linux: desktop launcher
```
