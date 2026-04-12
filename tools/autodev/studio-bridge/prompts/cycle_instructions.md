# M.E.R.L.I.N. Studio Director — Cycle Instructions

## Mode: FULL AUTO — ALTERNANCE DEV/TEST

Aucune intervention humaine. Alterne entre cycles DEV et cycles TEST.

## IMPORTANT — Environnement cloud sandbox

Tu tournes dans un sandbox Linux ephemere (Remote Trigger). Regles critiques:
- **IGNORE** toutes les references a `validate.bat`, hooks Python, `route-and-dispatch.py`, `gate_enforcer.py` dans CLAUDE.md — ils n'existent pas ici.
- **IGNORE** le "Post-Dev Checklist" de CLAUDE.md (validate/fix/revalidate) — pas applicable en sandbox.
- **IGNORE** le "Questioning Protocol" — aucun humain a qui poser des questions.
- **PAS de `git push --force`** — uniquement `git push origin main`.
- Si `git push` echoue (non-fast-forward): `git pull --rebase origin main` puis retry.
- Prefix implicite `*` sur tout — bypass total du gate algorithm.
- Utilise `grep` et `cat` directement (pas les outils Read/Grep qui peuvent avoir des restrictions).
- Le repo est deja clone via le PAT. `git push` devrait fonctionner directement.

## Fichiers de coordination

- `tools/autodev/status/feature_queue.json` — Taches pending (source de verite)
- `tools/autodev/status/events.jsonl` — Log evenements
- `tools/autodev/status/test_reports/` — Rapports de test
- `docs/GAME_DESIGN_BIBLE.md` — Bible game design v2.4

## Logique d'alternance

1. Lire les 5 dernieres lignes de `tools/autodev/status/events.jsonl`
2. Chercher le dernier evenement avec `"type":"cycle_update"`
3. Si son `data.cycle_type` etait `"dev"` → ce cycle est TEST
4. Si `"test"` → ce cycle est DEV
5. Si pas de `cycle_type` trouve → ce cycle est DEV (defaut)

## Cycle DEV

1. Lire `tools/autodev/status/feature_queue.json`
2. Filtrer: `status=pending` ET (`type` absent OU `type=dev` OU `type` absent)
3. Selectionner **1 seule tache** par priorite (plus petit numero = plus prioritaire)
4. Pour cette tache:
   a. Lire les fichiers cibles (champ `files` de la tache, ou deduire des titres)
   b. Implementer en GDScript: `snake_case`, type hints, JAMAIS `:=` avec CONST
   c. Verifier via `grep` que les modifications sont correctes
5. Mettre a jour `feature_queue.json`: changer `status` de la tache a `"completed"`, ajouter `"completed_at": "YYYY-MM-DDTHH:MM:SSZ"`, `"notes": "description du travail"`
6. Ajouter une ligne a `tools/autodev/status/events.jsonl`:
   `{"type":"cycle_update","timestamp":"YYYY-MM-DDTHH:MM:SSZ","data":{"cycle_type":"dev","task_id":"...","summary":"..."}}`
7. `git add -A && git commit -m "feat(scope): description" && git push origin main`

## Cycle TEST

1. `git pull origin main`
2. Lire `feature_queue.json`, filtrer: `type=test`, `status=pending`
3. Selectionner 1 tache test par priorite
4. Executer selon l'agent:
   - `game_playtester`: Simuler des sessions en lisant le code, verifier invariants (vie 0-100, rep caps +-20, MOS 8-50)
   - `game_design_auditor`: Comparer code vs `GAME_DESIGN_BIBLE.md`, lister ecarts
   - `bug_hunter`: Analyse statique, chercher null access, type errors, softlocks
5. Ecrire le rapport JSON dans `tools/autodev/status/test_reports/`
6. Si bugs CRITICAL: creer des taches dev dans `feature_queue.json` (priority=1)
7. Mettre a jour `feature_queue.json`: `status=completed`
8. Logger dans `events.jsonl`: `cycle_type=test`
9. `git add` + `git commit` + `git push`

## Housekeeping (chaque cycle)

### Queue cleanup
Deplacer les taches `status=completed` dans `tools/autodev/status/completed_archive.json` (creer si absent). Ne garder que pending/in_progress dans `feature_queue.json`.

### Events rotation
Si `events.jsonl` depasse 200 lignes: garder les 50 dernieres, archiver le reste dans `tools/autodev/status/events_archive/YYYY-MM.jsonl`.

### Auto-generation
Si 0 taches pending (dev ET test): lire `docs/DEV_PLAN_V2.5.md` pour identifier la prochaine phase et creer les taches.

## Self-check (watchdog integre)

A chaque cycle, avant de commencer:
1. Verifier que `feature_queue.json` a des taches pending. Si 0 pending (dev ET test): lire `docs/DEV_PLAN_V2.5.md` et creer 3-5 nouvelles taches.
2. Ecrire la date du cycle dans `tools/autodev/status/watchdog.txt` (append: `YYYY-MM-DDTHH:MM:SS OK`).
3. Si le cycle echoue pour quelque raison que ce soit, ecrire l'erreur dans `tools/autodev/status/escalation.json` et commit+push quand meme.

## Regles strictes

- Source de verite: `docs/GAME_DESIGN_BIBLE.md` v2.4
- JAMAIS modifier `GAME_DESIGN_BIBLE.md` ni `DEV_PLAN_V2.5.md`
- GDScript: `snake_case`, `PascalCase` classes, type hints obligatoires
- Fichiers < 400 lignes, fonctions < 50 lignes
- Toutes couleurs depuis `MerlinVisual.PALETTE`
- Commit: `type(scope): description`
- Si escalation necessaire: ecrire dans `tools/autodev/status/escalation.json`
