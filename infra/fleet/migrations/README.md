# Migrations — Firebase Realtime Database → Cloudflare D1 (SQLite)

One-shot migration of a Firebase RTDB JSON export into a SQLite DB, loadable into
Cloudflare D1.

## 1. Export the data (you, in Firebase Console)
Realtime Database → **⋮ (menu, top-right) → Export JSON** → downloads the whole tree
as a `.json`. Upload that file here.

## 2. Convert (agent, from the container)
```bash
python3 infra/fleet/migrations/rtdb_to_sqlite.py export.json --db atelier.db --sql atelier.sql
```
Flattening: each top-level node `{key: {record}}` → a table (`id` = key, scalar fields
→ typed columns, nested objects/arrays → JSON-text columns); top-level scalars → `_root`.

## 3. Load into a dedicated D1 database
```bash
export CLOUDFLARE_API_TOKEN=...   # Workers + D1 edit
wrangler d1 create atelier-idrac                 # new DB, isolated from merlin
wrangler d1 execute atelier-idrac --remote --file=atelier.sql
wrangler d1 execute atelier-idrac --remote --command "SELECT name FROM sqlite_master WHERE type='table'"
```

The data is then queryable via D1 (a small Worker can expose a read API, like
`infra/fleet/cloudflare/`). Nested values stay as JSON in their columns —
query with SQLite `json_extract(col, '$.field')`.

> Note: D1 free tier = 5 GB / 5M reads-day / 100k writes-day. The converter reports
> row counts so we can confirm it fits before loading.
