# MERLIN Control — dev cockpit 24/7 (PC + mobile)

A complete control interface, hosted permanently on the GCP e2-micro and reached over HTTPS
via Cloudflare Tunnel. From your phone or PC you can **see** MERLIN dev and **initiate** dev:
Kaggle / Colab / local models / fleet jobs, plus **autonomous iterative loops** that run 24/7.
Plan: Add-on 6. Pattern reused from `infra/fleet/atelier/deploy/`.

> **Why on the VM, not the PC**: the cockpit is the always-on control plane (light Flask app,
> fits 1 GB), up even when your PC is off. Heavy multi-agent work (Octogent / Claude Code
> agents) runs **off** this VM — on Oracle A1 (24 GB free) or the PC — and is linked/mirrored
> in the Agents pane. The autonomous loops launched here are the **free** ones.

## Panes (responsive, mobile-first)

| Pane | What |
|------|------|
| **Dev** | MERLIN dev state: autodev session/objective/cycle, recent git commits, events feed, agent-message counts, LoRA/health. |
| **Fleet** | Node tiles (up/down, CPU/RAM/disk) + free-tier quota gauges; one-tap `Run` per fleet job. |
| **Modèles** | Launch form (Kaggle train, Colab notebook, gen-cycle, validate, retrain cadence, fleet job, local Ollama gen) → tracked launches with live status + log tails + Stop. **Boucles autonomes** = the 24/7 loop metrics + systemd timer schedule. |
| **Agents** | Octogent dashboard (iframe/link via `OCTOGENT_URL`) + a mirror of the agent message bus. |

## Deploy (on the VM, via GCP Console SSH)

```bash
cd ~/merlin && git pull
bash infra/fleet/cockpit/deploy-cockpit.sh        # venv + token + systemd service + loop timers
TUNNEL_PORT=8765 bash infra/fleet/atelier/deploy/tunnel.sh named cockpit   # stable HTTPS URL
```

`deploy-cockpit.sh` prints a **Basic-auth token** (stored 0600 in `/etc/merlin-cockpit.env`).
Open the tunnel URL → log in as user **`merlin`**, password = the token. The whole cockpit
(page + every `/api/*`, especially the launch `POST`s) is gated. Pass `--no-loops` to skip the
autonomous timers.

## Autonomous loops (24/7, free)

Installed as systemd timers by the deploy script (`infra/fleet/cockpit/timers/`):

| Timer | Cadence | Runs |
|-------|---------|------|
| `merlin-loop-gen` | 30 min | generate cards → `scenario_validator` filter → grow `auto_corpus.jsonl` |
| `merlin-loop-validate` | 2 h | headless parse check + telemetry |
| `merlin-loop-train` | 6 h | cadence gate → trigger Kaggle once the corpus grew past threshold |

The **gen** loop uses a canon-grounded **template** backend that always works on the bare VM
(no LLM). Point it at a real model for quality:

```ini
# add to /etc/merlin-cockpit.env (gitignored, 0600)
OLLAMA_URL=https://<your-pc-ollama-tunnel>         # local-model backend
WORKERS_AI_URL=https://merlin-svc.<acct>.workers.dev/ai/generate   # free serverless backend
WORKERS_AI_TOKEN=<the GEN_TOKEN you set on the worker>
OCTOGENT_URL=https://<octogent-on-oracle-or-pc>    # embed the Agents pane
KAGGLE_USERNAME=<you>                              # Kaggle training (also ~/.kaggle/kaggle.json)
```

Manual run / inspect:
```bash
/opt/merlin-cockpit-venv/bin/python tools/cockpit/control_loops.py gen --count 12 --backend template
/opt/merlin-cockpit-venv/bin/python tools/cockpit/control_loops.py status
systemctl list-timers 'merlin-*'
```

## Workers AI (free serverless generation)

`infra/fleet/cloudflare/` — Worker now has `POST /ai/generate {biome}` (binding `[ai]`,
`@cf/meta/llama-3.1-8b-instruct`). Deploy + protect it:

```bash
cd infra/fleet/cloudflare
wrangler secret put GEN_TOKEN     # the WORKERS_AI_TOKEN above
wrangler deploy
```

Then set `WORKERS_AI_URL`/`WORKERS_AI_TOKEN` on the VM → the gen loop produces quality cards
within the free Neuron allocation. Cards still pass `scenario_validator` before corpus append.

## Operate

```bash
systemctl status merlin-cockpit
journalctl -u merlin-cockpit -f
curl -u merlin:$TOKEN http://127.0.0.1:8765/healthz
journalctl -u 'merlin-loop@*' -n 50      # loop runs
```

## Security / free

- Loopback bind + auth token + no inbound port (tunnel only). 0 € (e2-micro + tunnel + Kaggle
  + Workers-AI free tiers). Loops self-gate on quotas; cadences are conservative.
- Launch kinds are an allow-list (no arbitrary shell; args shlex-quoted).
- Secrets live in `/etc/merlin-cockpit.env`, `~/.kaggle/`, `fleet.local.yaml` — never committed.
- Claude-Code agents (paid) are **never** run in an autonomous loop here; on-demand only.
