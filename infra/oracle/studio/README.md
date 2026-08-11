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

## Jeu natif (VNC) — onglet Jouer

Le jeu tourne **en natif Linux** sur la VM (Godot 4.6 arm64, `godot --path .`) dans un
conteneur **podman rootless** (Fedora aarch64 : Xvfb + x11vnc + Mesa llvmpipe), affiché
dans le portail via **noVNC** (vendorisé dans `tools/merlin_studio/static/novnc/`).

- **Provisioning** (une fois, ré-exécutable) :
  `python infra/oracle/scripts/agent_takeover.py --cmd 'bash ~/workspace/M.E.R.L.I.N/infra/oracle/game/provision-game-user.sh'`
  → build de l'image, `pip install flask-sock simple-websocket`, smoke screenshot, restart Studio.
- **Cycle de vie** : lanceurs Studio `game-start` / `game-stop` / `game-restart`
  (→ `infra/oracle/game/game-stack.sh`), résolution allow-listée (1280x720 / 960x540 / 1920x1080).
- **Flux** : navigateur → tunnel → Flask `/websockify` (pont WS↔TCP ~40 lignes, flask-sock)
  → x11vnc `-localhost:5900`. **Un seul port tunnelé (8790), keepalive inchangé.**
- **Sécurité** : x11vnc jamais exposé ; handshake WS accepté sur **Basic auth OU ticket à
  usage unique TTL 60 s** (`POST /api/vnc/ticket`) — jamais le STUDIO_TOKEN en URL.
- **Dégradé propre** : sans flask-sock ou sans podman, le portail tourne normalement,
  PLAY est désactivé avec la raison affichée (`/api/game.reason`).
- **Dépannage** : conteneur mort au boot → logs dans le job `game-start` (onglet Jobs) ou
  `podman logs merlin-game` ; écran noir → vérifier le fix `renderer/rendering_method`
  desktop dans `project.godot` + `--rendering-driver opengl3` (entrypoint) ; perfs faibles
  → passer en 960x540.

## Quel jeu tourne sur la VM ? (architecture deux dossiers)

Le jeu et l'outillage sont **deux dépôts/branches distincts**, dans **deux dossiers
séparés** sur la VM — obligatoire, car la branche du jeu ne contient pas
`infra/oracle/game` : tout mélanger casserait l'outillage à chaque changement de
branche du jeu.

| Dossier VM | Contenu | Branche |
|---|---|---|
| `~/workspace/M.E.R.L.I.N` | Outillage : portail Studio, scripts VNC/provisioning | `claude/oracle-free-tier-access-IN1Wm` |
| `~/workspace/merlin-game` | **Le projet Godot joué** | `feat/practices-docs` (défaut) |

> **Important — deux lignées divergentes dans ce dépôt.** Elles ont divergé le
> 2026-05-17 et n'ont jamais fusionné. `main` a poursuivi l'ancienne direction
> artistique (CRT/Persona : `scenes/MenuTest.tscn`, écran noir + bouton ENTRER).
> Toute la refonte visuelle validée (menu flat brun/or, écran CHRONIQUES, éclats
> du Graal, `scripts/game/merlin_*.gd`, main scene `MerlinBoot.tscn`) vit sur
> **`feat/practices-docs`** et ses sœurs `feat/*`. C'est cette branche que la VM
> joue par défaut.

### Réglages (VM, `~/.config/merlin-game.env`)
```sh
GAME_REF=feat/practices-docs                  # branche du jeu à jouer
GAME_REPO_DIR=/var/lib/ocarun/workspace/merlin-game
GAME_REPO_URL=https://github.com/merlingame-netizen/M.E.R.L.I.N.git
```
Changer de branche de jeu = éditer `GAME_REF` puis cliquer **⟳ Sync**. La version
de Godot suit automatiquement le `config/features` du projet (`godot-install.sh`),
donc une branche sur un autre moteur réinstalle la bonne version toute seule.

### Boucle de travail quotidienne
1. Depuis ton PC (`C:/Users/PGNK2128/Godot-MCP`, qui est ce même dépôt) :
   `git add -A ; git commit -m "..." ; git push origin feat/practices-docs`
2. Dans le portail, onglet **Jouer** → **⟳ Sync** (fetch + pull + réimport si le
   commit a changé — quelques minutes à froid, quasi instantané ensuite).
3. **▶ PLAY** — le readout affiche en permanence `JEU : branche @ commit ·
   GODOT x.y · IMPORT OK`, donc aucun doute sur ce qui tourne.

### Import des assets : trois pièges (déjà gérés par `game-sync.sh`)
Sans `.godot/imported`, Godot affiche des placeholders méconnaissables — d'où le
refus de `PLAY` tant que l'import n'a pas eu lieu. L'import headless se bloque sur :
- **`*.blend`** — sans exécutable Blender, blocage définitif (`editor_settings
  blender/enabled=false` NE suffit PAS) → écartés le temps de l'import, restaurés après ;
- **`*.gdextension`** — bibliothèques natives Windows, aucune section `linux.arm64` ;
- **`[editor_plugins]`** — `godot_mcp` ouvre un serveur TCP et `--import` ne rend
  jamais la main (même recette que la CI `godot-export.yml`).
