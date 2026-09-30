# jev-router — routage local façon Jev (poste Orange, zéro clé API)

Avant chaque demande, un décideur local (Ollama) choisit la **lane la moins chère suffisante** et le modèle correspondant dans chaque outil. Le décideur ne fait que classer : ce sont les seuils, les retries et le kill switch, écrits en dur dans le code, qui tranchent. Aucune donnée ne part vers TypeSafe.

```
demande ─► regex risque (0 token) ─► décideur Ollama (choix typés + probabilités) ─► garde-fous ─► lane
                                                                                     │
                     small / medium / high / escalate ◄──────────────────────────────┘
                     └─► modèle Claude Code / Copilot / ChatGPT / Ollama  (lanes.json)
```

## Installation (poste Windows)

```powershell
ollama pull qwen2.5:3b                      # décideur par défaut (~2 Go)
python tools/cli.py jev health              # le décideur répond ? calibrated=true attendu
python tools/cli.py jev eval                # justesse sur eval_cases.json (7/8 mesuré avec 3b)
```

Si `eval` donne moins de 7/8, passez `decider.model` à `qwen2.5:7b` dans `lanes.json`.

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

- Ce n'est **pas** Jev : ses poids sont fermés. Qwen 2.5 3b fait office de décideur, avec une justesse mesurée de 7/8 sur 8 cas. Les logprobs sont souvent sur-confiants.
- Le choix réel du modèle dans Copilot et ChatGPT reste **manuel**. Seul Claude Code peut l'appliquer, via les sous-agents.
- Tests : `python -m unittest discover -s tools/jev_router/tests -v`
