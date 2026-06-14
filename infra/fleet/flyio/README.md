# Fly.io node — small containerized service (scale-to-zero ≈ free)

Fly.io no longer has a guaranteed always-free allowance; it bills by usage and
**requires a card**. We keep it ~free with **scale-to-zero**: the machine stops when
idle and cold-starts on the next request, so a tiny service costs ≈ €0.

## Prereqs (you)
1. `curl -L https://fly.io/install.sh | sh` (or the Windows installer)
2. `fly auth signup` / `fly auth login` (card verification may apply)

App already created: **merlin-fleet-mxb38** → endpoint `https://merlin-fleet-mxb38.fly.dev/health`.

> Note: Fly's image builder can't be reached from the agent's sandbox (TLS-intercepting
> proxy), so the image must be built somewhere without that proxy. Two ways:

### Option A — GitHub Actions (recommended; the agent can trigger it)
1. GitHub → repo → Settings → Secrets and variables → Actions → New repository secret
   → name `FLY_API_TOKEN`, value = your Fly token.
2. Run the **"Deploy Fly service"** workflow (Actions tab → Run workflow), or push a change
   under `infra/fleet/flyio/`. The agent can also trigger it for you once the secret exists.

### Option B — from your PC
```bash
cd infra/fleet/flyio
fly deploy --remote-only --ha=false
fly status
```

## Wire into the fleet
Set `fly-service.url = https://<app>.fly.dev/health` in `infra/fleet/fleet.yaml`.

## Stay (near) free
- `auto_stop_machines=true` + `min_machines_running=0` → stops when idle.
- Watch usage in the Fly dashboard; set a spend alert if you want a hard guard.
- The fleet dashboard's HTTP check will cold-start it briefly each poll — if you want
  to avoid even that, increase the dashboard poll interval for this target.
