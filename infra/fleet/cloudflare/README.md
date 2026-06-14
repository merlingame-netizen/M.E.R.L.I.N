# Cloudflare node — Worker + D1 (SQLite) + Pages (free, 24/7, no card)

The lightest, most reliable free node: serverless, always-on (edge), **no credit card**.
Great for SQLite-backed services/APIs (D1) and web (Pages).

Free limits (Workers Free plan): 100k requests/day; D1 = 5 GB storage, 5M row reads/day,
100k row writes/day. Plenty for small services.

## Prereqs (you, ~5 min)
1. Create a free Cloudflare account (no card).
2. `npm i -g wrangler` then `wrangler login` (browser auth).

## Deploy the Worker + SQLite DB
```bash
cd infra/fleet/cloudflare
wrangler d1 create merlin                 # copy the database_id into wrangler.toml
wrangler d1 execute merlin --remote --file=schema.sql
wrangler deploy                           # prints https://merlin-svc.<account>.workers.dev
```
Test: `curl https://merlin-svc.<account>.workers.dev/health`

## Deploy the Pages site
```bash
wrangler pages deploy pages --project-name merlin-pages
# prints https://merlin-pages.pages.dev
```

## Wire into the fleet dashboard
Put the two URLs into `infra/fleet/fleet.yaml`:
- `cf-worker.url`  = `https://merlin-svc.<account>.workers.dev/health`
- `cf-pages.url`   = `https://merlin-pages.pages.dev`

## Stay free
No card = no possible charge. If you ever approach the daily D1/Workers limits, the
dashboard's HTTP checks still pass; monitor usage in the Cloudflare dashboard.
