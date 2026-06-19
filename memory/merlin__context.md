# merlin — Context

## Flotte cloud gratuite — bénéfices pour le dev MERLIN (éval 2026-06-15)

> Règle cadre (CLAUDE.md) : les VM servent le **dev** (build / validation / données / LLM /
> monitoring) — **jamais** à faire tourner le jeu en compute serveur. Seule exception légitime :
> une **démo web export** sur Cloudflare Pages, qui s'exécute dans le navigateur du joueur.
> Détail infra/monitoring : `memory/_shared__context.md`.

### Activables MAINTENANT (gcp-micro 1 Go + Cloudflare, 0 €)

| # | Bénéfice | Comment | Impact |
|---|----------|---------|--------|
| 1 | **Démo web jouable hébergée** | `python tools/cli.py godot export web` → déployer le WASM sur **cf-pages** → lien public partageable. Compute côté joueur ⇒ conforme à « pas faire tourner le jeu sur la VM ». | **Élevé** — playtests à distance, QA UX desktop/mobile réels, partage de builds |
| 2 | **CI de validation headless** | `godot validate_step0` (parse) + `godot test` (runner GDScript) sur **gcp-micro** via cron/webhook à chaque commit ; erreurs loguées + alerte Uptime Kuma. Smoke de scène = plus lourd (xvfb + rendu logiciel, lent sur 1 Go) → réserver aux scènes critiques du flow démo. | **Élevé** — stoppe les régressions parse/runtime entre sessions |
| 3 | **Store de données de jeu (D1)** | Héberger le pool **FastRoute** (500+ cartes), les **resume JSON** de continuité LLM, un **leaderboard/MOS** ; Worker = API CRUD. | **Moyen-élevé** — données gameplay centralisées, requêtables, 24/7 |
| 4 | **Télémétrie & équilibrage** | `godot telemetry` → rollups nocturnes (cron gcp-micro) poussés sur D1 : convergence MOS (8/20-25/50), taux de mort, usage Oghams/factions, scores minigames, caps ±20. | **Moyen** — pilote l'équilibrage par la data |
| 5 | **Monitoring services MERLIN** | Uptime Kuma surveille la démo Pages, l'API Worker, tout endpoint de dev ; status page + alertes. | **Faible-moyen** |
| 6 | **Miroir Git / artefacts** | Stocker/partager builds de dev, exports, assets générés ; point h24. | **Faible-moyen** |

### Fort impact mais BLOQUÉ tant qu'Oracle A1 n'est pas déployé

> gcp-micro (1 Go) est **trop petit pour un LLM utile**. Oracle A1 (24 Go) est le nœud cible
> pour tout ce qui est LLM/heavy — mais « Out of host capacity » à Paris (cf `_shared__context`).

| # | Bénéfice | Détail | État |
|---|----------|--------|------|
| 7 | **Offload génération LLM narrateur** | Ollama + Multi-Brain (Qwen 3.5 / `merlin-narrator-lora`) sur Oracle pour **pré-générer le FastRoute** (variantes par tier de confiance) et libérer le PC. Répond au besoin « héberger des modèles LLM / Ollama ». Job `narrator-gen` déjà câblé (route → oracle-a1). | **PENDING capacité Oracle**. Pont possible : **Cloudflare Workers AI** (allocation gratuite) pour du texte de cartes sans Ollama local — à évaluer. |
| 8 | **Pipeline d'assets (Blender headless)** | Rendu/traitement d'assets hors PC. | PENDING Oracle |

### Prochaines étapes pour activer ces bénéfices
1. Câbler `godot export web` → **cf-pages** (pipeline de déploiement de la démo).
2. Ajouter un job fleet `validate-ci` (needs `[service]`) sur gcp-micro, déclenché sur push.
3. Schéma **D1** cartes/télémétrie + endpoints Worker (réutiliser `backup-d1`/`kv-write`).
4. **Débloquer Oracle** (PAYG ou polling capacity-report) pour activer LLM/heavy (#7, #8).
