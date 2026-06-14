# Fly.io node — small containerized service (scale-to-zero ≈ free)

Fly.io no longer has a guaranteed always-free allowance; it bills by usage and
**requires a card**. We keep it ~free with **scale-to-zero**: the machine stops when
idle and cold-starts on the next request, so a tiny service costs ≈ €0.

## Prereqs (you)
1. `curl -L https://fly.io/install.sh | sh` (or the Windows installer)
2. `fly auth signup` / `fly auth login` (card verification may apply)

## Deploy
```bash
cd infra/fleet/flyio
fly launch --no-deploy --copy-config --name merlin-svc-<unique>   # if name taken
fly deploy
fly status
```
Endpoint: `https://<app>.fly.dev/health`

## Wire into the fleet
Set `fly-service.url = https://<app>.fly.dev/health` in `infra/fleet/fleet.yaml`.

## Stay (near) free
- `auto_stop_machines=true` + `min_machines_running=0` → stops when idle.
- Watch usage in the Fly dashboard; set a spend alert if you want a hard guard.
- The fleet dashboard's HTTP check will cold-start it briefly each poll — if you want
  to avoid even that, increase the dashboard poll interval for this target.
