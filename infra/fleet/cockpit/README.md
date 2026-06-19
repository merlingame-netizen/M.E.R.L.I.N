# MERLIN dev cockpit — 24/7 on the free VM

The cockpit (fleet hub) hosted permanently on the GCP e2-micro and reached over HTTPS via
Cloudflare Tunnel. It shows live fleet status / quotas / jobs and runs jobs (Run buttons).
Plan: `~/.claude/plans/…` Add-on 6. Pattern reused from `infra/fleet/atelier/deploy/`.

> **Why on the VM, not the PC**: the cockpit is the always-on control plane (light Flask app,
> fits 1 GB). It stays up even when your PC is off. Heavy multi-agent work (Octogent / Claude
> Code agents) does **not** run here — it belongs on Oracle A1 (24 GB free) or the PC; the
> cockpit will link/mirror it. Autonomous loops launched from here are the **free** ones
> (Kaggle training, Workers AI / Ollama generation, fleet validate/telemetry).

## Deploy (on the VM, via GCP Console SSH)

```bash
cd ~/merlin                                   # a clone of this repo on the VM
git pull
bash infra/fleet/cockpit/deploy-cockpit.sh    # venv + token + systemd service on 127.0.0.1:8765
```

It prints a **Basic-auth token** (also stored in `/etc/merlin-cockpit.env`, mode 0600). The
whole cockpit (page + every `/api/*`, especially the job-launch `POST`s) requires it once the
token is set — the browser caches it after one prompt.

Expose it (stays loopback-only; the tunnel reaches `127.0.0.1:8765`):

```bash
# quick (ephemeral URL, instant):
TUNNEL_PORT=8765 bash infra/fleet/atelier/deploy/tunnel.sh quick
# stable (named tunnel under your Cloudflare account):
TUNNEL_PORT=8765 bash infra/fleet/atelier/deploy/tunnel.sh named cockpit
```

Open the printed `https://…` URL → log in as user **`merlin`**, password = the token.

## Operate

```bash
systemctl status merlin-cockpit
journalctl -u merlin-cockpit -f
curl -u merlin:$TOKEN http://127.0.0.1:8765/healthz     # {"ok":true}
```

## Security / free

- Loopback bind + auth token + no open inbound port (tunnel only). 0 € (e2-micro + tunnel free).
- The token gates the launch endpoints — never share the tunnel URL without it.
- `fleet run` to other nodes uses the SSH keys already on the VM (`~/.ssh`, gitignored).
- Token + IPs live in `/etc/merlin-cockpit.env` and `fleet.local.yaml` — never committed.

## Roadmap (Add-on 6, next phases)

- **Workers AI** binding (`infra/fleet/cloudflare/`) → free serverless generation endpoint.
- **Models / Loops / Octogent** panes + `/api/models/*`, `/api/loops/*` endpoints.
- **systemd timers** (`timers/`) for the autonomous free loops (train cadence, gen, validate).
- **Octogent → Oracle A1** headless runbook (when capacity), linked/mirrored from the cockpit.
