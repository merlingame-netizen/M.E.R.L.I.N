# _shared — Context : Flotte cloud gratuite 24/7 (« fleet »)

> Infra mutualisée multi-cloud, toujours gratuite. Source de vérité : `infra/fleet/`.
> Secrets (IP VM, project-id GCP, host du tunnel, clés) **jamais commités** (repo public) :
> ils vivent dans `infra/fleet/fleet.local.yaml`, `infra/fleet/gcp/terraform.tfvars`,
> `~/.ssh/`, `~/.gcp-merlin/sa.json` (tous gitignorés).

## Nœuds (état 2026-06-15)

| Nœud | Fournisseur | Rôle | Capabilities | Quota free | État |
|------|-------------|------|--------------|------------|------|
| **gcp-micro** | GCP e2-micro (1 Go, us-west1) | VPS léger : SQLite / cron / monitoring / services | cron, service, data, container | 1 Go RAM, 1 vCPU, always-on | **DÉPLOYÉ** |
| **cf-worker** | Cloudflare Worker + **D1** (`atelier-idrac`) | API + SQLite edge | api, data-sqlite, edge, data | 100k req/j, 5 Go D1, 5M lectures/j | **DÉPLOYÉ** |
| **cf-pages** | Cloudflare Pages | Site web statique | edge | illimité (static) | **DÉPLOYÉ** |
| **oracle-a1** | Oracle ARM A1 (4 vCPU / 24 Go) | VPS lourd : LLM / Ollama / Docker | llm, heavy, cron, service, data, container | 24 Go RAM, 4 OCPU, always-on | **BÂTI, NON DÉPLOYÉ** — « Out of host capacity » eu-paris-1 (persistant). Seul nœud capable de LLM. |
| ~~fly-service~~ | Fly.io | — | — | — | **ABANDONNÉ** (carte requise) |

## Charges actuellement hébergées (sur gcp-micro)

- **AtelierIAIdrac off-Firebase** : backend Node REST + WebSocket sur SQLite arbre (type RTDB),
  systemd `atelier-backend` sur `127.0.0.1:8787`. DB : `/var/lib/atelier/atelier-idrac-tree.db`
  (15 root nodes importés). Front (GitHub Pages) parle au backend via un shim Firebase-compat.
- **Cloudflare Tunnel** (`cloudflared`) → HTTPS/WSS public, **0 port ouvert**, pas de cert.
  Quick tunnel = URL éphémère (change à chaque restart) ; named tunnel = URL stable (à faire).
- **Uptime Kuma** (Docker) sur `127.0.0.1:3001`, loopback only.

## Monitoring (3 niveaux)

1. **Uptime Kuma** (hébergé sur gcp-micro) : checks HTTP/TCP/DB/ping, historique, alertes, status
   page. Loopback `:3001` → accès via tunnel SSH ou cloudflared. 1ʳᵉ visite = créer l'admin.
2. **Hub local** : `python tools/cli.py fleet serve` → dashboard Flask `http://localhost:8765`
   (tuiles par nœud + jauges de quota free-tier + panneau Jobs avec boutons Run).
3. **Adapter CLI** : `fleet status | list | check --target X | quota | jobs | plan --job J | run --job J`.
   Sorties JSON dans `infra/fleet/status/` (`fleet.json`, `quota.json`, `jobs.json`).

## Dispatch & garde « gratuit TOUJOURS »

- `fleet run --job NAME` route vers le **meilleur nœud free** dont `capabilities ⊇ needs`
  ET dont le quota a de la marge. Préférences : `llm/heavy → oracle-a1` ;
  `api/data-sqlite → cf-worker` ; `cron/service/container → gcp-micro` (fallback oracle).
- **Garde strict** : refuse/queue tout job qui dépasserait le quota free du nœud. Alertes à 80 %.
- Budgets coût : `oci_budget` (Oracle, actif), `google_billing_budget` (GCP).
- Jobs définis : `ping-self` (cron), `backup-d1` / `kv-write` (Worker D1), `narrator-gen` (llm → oracle).

## Accès / opération

- **SSH GCP** : passer par la **GCP Console → SSH navigateur** (le réseau corporate de l'utilisateur
  bloque le port 22 sortant ; la console le contourne). Liens projet/zone/instance = voir
  `fleet.local.yaml` + `gcp/terraform.tfvars` (gitignorés).
- **Redéploiement backend** : `bash infra/fleet/atelier/deploy/deploy-vm.sh <rtdb-export.json>`
  (idempotent : Node 22 + deps + import DB + systemd). Tunnel : `deploy/tunnel.sh quick|named`.
