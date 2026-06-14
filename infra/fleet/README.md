# M.E.R.L.I.N. — Multi-cloud free fleet + local admin console

A fleet of **free, 24/7** machines/services across providers, plus a **local web
dashboard** on your PC showing the state of everything. Designed to stay **free**.

## The fleet

| Node | Provider | What it's for | Card? |
|------|----------|---------------|-------|
| `oracle-a1` | Oracle A1 4/24 | Heavy VPS: dev, Ollama, docker stack | verif (refundable) |
| `gcp-micro` | Google e2-micro (1 GB) | Light always-on VPS: SQLite, cron, jobs | verif (refundable) |
| `cf-worker` | Cloudflare Worker + **D1 (SQLite)** | APIs / SQLite services, edge 24/7 | **none** |
| `cf-pages` | Cloudflare Pages | Static/dynamic web | **none** |
| `fly-service` | Fly.io (scale-to-zero) | Small containerized service | yes |

Per-node setup lives in each subfolder's README: `oracle/` (../oracle), `gcp/`,
`cloudflare/`, `flyio/`.

## The local admin console

```bash
pip install pyyaml flask          # one-time (flask is also in tools/data_explorer/requirements.txt)
python tools/cli.py fleet status  # JSON health of all nodes (also writes status/fleet.json)
python tools/cli.py fleet serve   # opens http://127.0.0.1:8765  (live dashboard)
python tools/cli.py fleet check --target cf-worker
```

The dashboard (`tools/fleet_dashboard/`) shows one tile per node — up/down, CPU/RAM/disk
(for SSH nodes), HTTP latency (for serverless), role, last check. **100 % local**: it
SSHes / HTTP-checks from your PC; nothing is exposed.

## How it fits together

```
PC: python tools/cli.py fleet serve ──> Flask dashboard :8765
        │ reads infra/fleet/fleet.yaml (inventory)
        │ FleetAdapter probes each node (SSH one-liner / HTTP)
        ▼
  oracle-a1 · gcp-micro · cf-worker · cf-pages · fly-service
```

## Bring nodes online (recommended order)

1. **Cloudflare** (fastest, no card) → `cloudflare/README.md`. Fill `cf-worker`/`cf-pages` URLs.
2. **Google e2-micro** (free, available now) → `gcp/` (`terraform apply`). Fill `gcp-micro.host`.
3. **Oracle A1** → already built (`../oracle`); deploys when capacity frees (PC watcher).
4. **Fly.io** → `flyio/README.md`. Fill `fly-service.url`.

After each node is up, paste its `host`/`url` into `infra/fleet/fleet.yaml` and it appears
live in the dashboard.

## Hosted monitoring — Uptime Kuma (on the GCP VM)

A full monitoring dashboard (HTTP/TCP/DB/ping checks, history, alerts, status page) runs as
a Docker container on the GCP e2-micro. It's bound to **127.0.0.1 only** — reached via SSH
tunnel (not exposed to the internet).

```bash
# from your PC (key + IP are in your fleet.local.yaml / RESTORE bundle):
ssh -i %USERPROFILE%\.ssh\merlin_oracle_ed25519 -L 3001:localhost:3001 merlin@<gcp-ip>
# then open:
http://localhost:3001        # first visit: create the admin account
```

Add monitors (≈2 min): **+ Add New Monitor** for each —
- `cf-worker` — HTTP(s) — `https://merlin-svc.maxbab38.workers.dev/health`
- `cf-pages`  — HTTP(s) — `https://merlin-pages.pages.dev`
- `oracle-a1` — TCP Port — `<oracle-ip>:22` (once the Oracle VM is up)

Uptime Kuma can also publish a shareable **status page** (Settings → Status Pages) if you
want a public read-only view later.

## Staying free (guards)

- **Oracle**: `freetier-guard.py` (provisioning) + budget alert (already applied).
- **GCP**: Terraform pins `e2-micro` + 30 GB standard PD (variable validations reject anything
  else); optional `google_billing_budget` (set `billing_account`).
- **Cloudflare**: free plan, no card → no charge possible.
- **Fly.io**: scale-to-zero; watch usage (card required).
