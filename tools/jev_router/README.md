# jev-router — routage local façon Jev (poste Orange, zéro clé API)

Avant chaque demande, un décideur local (Ollama) choisit la **lane la moins chère suffisante** et le modèle correspondant dans chaque outil. Le décideur ne fait que classer : ce sont les seuils, les retries et le kill switch, écrits en dur dans le code, qui tranchent.

```
demande ─► regex risque (0 token) ─► décideur Ollama (choix typés + probabilités) ─► garde-fous ─► lane
                                                                                     │
                     small / medium / high / escalate ◄──────────────────────────────┘
                     └─► modèle Claude Code / Copilot / ChatGPT / Ollama  (lanes.json)
```

## Décideur : Qwen local ou Jev (TypeSafe)

Par défaut tout reste local (Qwen via Ollama). Jev, via `POST https://api.typesafe.ai/v1/systemone`, n'est appelé que si **toutes** ces conditions sont réunies :

1. un dossier du chemin du projet figure dans `lanes.json` → `decider_policy.remote_allowed_paths` (par défaut `M.E.R.L.I.N` et `Godot-MCP`, comparaison sur le nom de dossier entier) ;
2. la variable `TYPESAFE_API_KEY` est définie ;
3. la regex n'a pas classé la demande `security` (`remote_blocked_risks`), car elle peut contenir un secret.

Un projet inconnu (pas de `cwd`), hors liste blanche ou sans clé reste sur Qwen. Si l'API échoue (401, 422, 429, 529, réseau), le routeur retombe sur Qwen, puis sur l'heuristique. Le dossier arrive par le champ `cwd` du hook, l'argument `cwd` du MCP (par défaut, le dossier du serveur), le champ `cwd` de `/v1/route` (sans lui, tout reste local) et `--cwd` en CLI (par défaut, le dossier courant). `jev stats` compte les passages par Jev (`typesafe_routes`), et `jev eval --cwd <dossier MERLIN>` mesure Jev sur les cas d'évaluation.

## Installation (poste Windows)

```powershell
ollama pull qwen2.5:7b                      # décideur par défaut (~4,7 Go ; 7/8 mesuré, 3b : 6/8)
python tools/cli.py jev health              # le décideur répond ? calibrated=true attendu
python tools/cli.py jev eval                # justesse sur eval_cases.json (7/8 mesuré avec 7b)
```

Le 3b (`qwen2.5:3b`, ~2 Go) donne 6/8 : il surclasse (questions simples envoyées en `high`). Au premier appel après inactivité, le chargement du 7b peut dépasser `timeout_s` : le hook reste alors muet (fail-open).

## Branchements

| Outil | Branchement | Ce qu'il fait |
|---|---|---|
| **Claude Code** | hook `UserPromptSubmit` (`.claude/settings.json`) + MCP `jev-router` (`.mcp.json`) | Injecte `[JEV-ROUTER] lane=… model=…` : Claude délègue à un sous-agent `haiku`/`sonnet`/`opus`. Outil `report_failure` après un échec. |
| **Copilot (VS Code)** | MCP `.vscode/mcp.json` (mode Agent) | Outils `route_task` / `report_failure`. Le modèle se choisit dans le sélecteur de Copilot, selon la recommandation. |
| **ChatGPT desktop** | ❌ pas de MCP local | `python tools/cli.py jev route --prompt "…"` puis choisir le modèle indiqué. |
| **Tout autre client** | API HTTP `jev.py serve` → `http://127.0.0.1:8790` | `/v1/route`, `/v1/systemone`, `/v1/failure`, `/v1/stats` |

Le hook est **fail-open** : si Ollama est absent, il n'affiche rien et ne bloque jamais la demande. Les préfixes `*`, `/` et `!`, ainsi que les demandes de moins de 20 caractères, ne sont pas routés.

## Garde-fous (`lanes.json` → `gates`)

- Confiance < `0.70` → la lane monte d'un cran, par sécurité.
- Risque `security` ou `data_loss` (regex ou décideur ≥ 0.70) → lane `high` au minimum.
- `max_retries_per_lane` = 3 échecs → lane suivante. `max_escalations_per_task` = 1, puis `stop` (kill switch).
- Journal : `~/.jev_router/decisions.jsonl` (taille du prompt seulement, jamais son contenu). `jev stats` pour la revue.

## API System One locale (façon article Agoratlas)

```json
POST /v1/systemone
{"context": ["tweet 1", "tweet 2"],
 "questions": [
   {"id": "sport", "type": "noul", "text": "Parle de sport ?",
    "criteria": {"true": "match, joueur, score", "false": "tout autre sujet"}},
   {"id": "tox", "type": "score", "text": "Toxicité ?", "min": 0, "max": 10},
   {"id": "lang", "type": "choice", "text": "Langue ?", "options": [{"value": "fr"}, {"value": "en"}]}]}
```

La réponse contient `value`, `confidence`, `probabilities` et `calibrated` pour chaque question. `calibrated=true` signifie que les probabilités viennent des logprobs Ollama ; sinon elles viennent d'un vote sur 5 tirages. Comme le montre l'article, des critères `true`/`false` précis améliorent nettement la qualité.

## Limites

- Ce n'est **pas** Jev : ses poids sont fermés. Qwen 2.5 7b fait office de décideur, avec une justesse mesurée de 7/8 sur 8 cas. Les logprobs sont souvent sur-confiants.
- Le choix réel du modèle dans Copilot et ChatGPT reste **manuel**. Seul Claude Code peut l'appliquer, via les sous-agents.
- Tests : `python -m unittest discover -s tools/jev_router/tests -v`
