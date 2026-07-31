# MERLIN Studio — l'interface de ta VM perso (Oracle ARM A1)

L'équivalent du cockpit de la VM GCP, mais **dédié au jeu MERLIN** : cette VM ne sert quasiment
qu'à ça, donc les panneaux sont orientés dev du jeu, pas flotte/quotas.

| | Cockpit GCP (`infra/fleet/cockpit`) | **Studio Oracle** (ici) |
|---|---|---|
| Rôle | plan de contrôle multi-cloud, quotas, boucles | **dev du jeu** sur cette machine |
| Panneaux | Dev · Fleet · Modèles · Agents | **Run · Contenu · Jobs · LLM · Repo · Hôte** |
| Port | 8765 | **8790** |
| Token | `/etc/merlin-cockpit.env` | `/etc/merlin-studio.env` |

## Déploiement (sur la VM)

```bash
cd ~/workspace/M.E.R.L.I.N && git pull
bash infra/oracle/studio/deploy-studio.sh                       # venv + token + systemd :8790
TUNNEL_PORT=8790 bash infra/fleet/atelier/deploy/tunnel.sh quick # URL HTTPS
```
Ouvre l'URL → login **`merlin`** + le token affiché. Tout est protégé (page + `/api/*` + les POST
de lancement) ; seul `/healthz` reste ouvert pour les sondes.

## Les panneaux

- **Run** — Godot : version, avertissement si le projet cible une version ≠ du binaire, scène
  principale. Boutons *Boot check*, *Tests headless* (`tests/headless_runner.gd`), *Smoke toutes
  scènes*, *Import/parse* (long, avec confirmation). **Matrice des scènes** énumérées au runtime
  (8 réelles — la liste de CLAUDE.md est périmée) avec dernier état + `SCRIPT ERROR` par scène.
- **Contenu** — `lore_canon.json` (5 factions · 27 PNJ · 8 biomes · 9 runes · 16 fins · 30 events),
  **divergences code↔bible**, corpus auto + **jauge MOS** (cartes/25), boucles. Génération de
  cartes, validator, éval modèles.
- **Jobs** — lanceur générique (allow-list), suivi live, logs, Stop, garde de concurrence.
- **LLM** — Ollama local (modèles, chargés, **alerte si la RAM ne suffit pas** au plus gros),
  test de prompt, services voix TTS/ASR (état + démarrage).
- **Repo** — branche, ahead/behind, fichiers modifiés, commits. **Fetch / pull ff-only uniquement**
  (jamais commit/push/reset depuis l'UI).
- **Hôte** — cœurs/RAM/disque/uptime, services systemd, conteneurs `merlin-*`, **carte des ports**
  (11434 ollama · 3000 open-webui · 8443 code-server · 8081 filebrowser · 5432 pg · 8770 asr ·
  8772 tts · 8790 studio), provisioning cloud-init.

## Choix d'implémentation (pièges vérifiés)

- **Godot est appelé directement**, jamais via `tools/cli.py godot` : `godot_adapter.py:19` fixe
  `PROJECT_ROOT = C:\Users\PGNK2128\Godot-MCP` (Windows) → inutilisable sur la VM ARM.
- **Pas d'adapter `studio`** dans `tools/cli.py` : la clé `"studio"` d'`ADAPTER_REGISTRY` pointe
  vers `adapters/studio_adapter.py`, exclu par le `.gitignore` (`*_adapter.py`) → import cassé.
- **Ollama via `$OLLAMA_URL`**, pas `ollama_adapter.py` (BASE_URL localhost en dur, sans override).
- **Validation via `tools/lora/scenario_validator.py`**, pas `control_loops.py validate` (qui
  shelle le chemin Windows cassé).
- **Concurrence** : 1 job Godot à la fois (un 2ᵉ saturerait CPU/RAM) ; refus explicite sinon.
- **Sécurité** : allow-list stricte, scènes validées contre la liste réelle, pas de traversée de
  chemin, pas d'injection shell (args `shlex`-quotés), écritures git interdites.

## Vérifié

Endpoints 200 · auth 401/200 (page, API, POST) · **smoke Godot réel exécuté** (`MenuTest`,
exit 0, 0 SCRIPT ERROR) · garde de concurrence · 4 refus de sécurité (traversée, injection,
hors-périmètre, type inconnu) · suivi des jobs + état par scène.
