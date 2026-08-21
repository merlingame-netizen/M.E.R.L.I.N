# Annexe leçons — 2026-08-21 (à fusionner dans _shared__lessons.md)

> CORRECTION : la première version de cette annexe affirmait « instance résiliée,
> boot volume préservé » — c'était FAUX. La page Compute → Instances montrait
> merlin-arm-a1 RUNNING (créée le 10 août, IP 141.253.124.75). Le widget
> « Explorateur de ressources » de l'accueil OCI était périmé (seul le boot volume
> y figurait, « vu il y a 9 jours »).

| Date | Erreur | Correction | Source |
|------|--------|------------|--------|
| 2026-08-21 | Diagnostic « instance résiliée » fondé sur le widget Explorateur de ressources de la page d'accueil OCI (ne montrait que le boot volume « Disponible ») | Un widget d'accueil n'est PAS la console : la page Compute → Instances fait foi. Toujours la vérifier avant toute conclusion sur l'existence d'une ressource | Console OCI 2026-08-21 |
| 2026-08-21 | Un 502 Bad Gateway trycloudflare interprété comme « cloudflared vivant donc VM vivante », puis comme « VM morte » | Une page d'erreur CDN ne prouve ni la vie ni la mort de l'origine. Le 502 signalait en fait un clone outillage sale → autosync muet → boîte Courrier figée | Diagnostic p42 |
| 2026-08-21 | 25 h de silence attribuées successivement au quota ntfy puis à une résiliation puis à un gel | Cause réelle : clone outillage avec modif locale non commitée → `git pull` de l'autosync échouait EN SILENCE toutes les 15 min → les jobs n'arrivaient plus. Remède : `git reset --hard origin/...`. Le Run Command OCI (module « Exécution de commandes », user ocarun) marche SANS clé API — canal de secours permanent via la console web | Réparation 2026-08-21 |
| 2026-08-21 | 7 parties à zéro lookahead sans savoir pourquoi : les 3 gardes de `prefetch_scene_suivante` jetaient les scènes par des `return` SILENCIEUX | Toute garde qui jette du travail coûteux DOIT le dire (print daté). L'autopsie À CHAUD (grep du log dans le même job que la partie, avant toute rotation) est la seule mesure fiable — le log de p42 avait été vidé avant lecture | course49/course50 |
| 2026-08-21 | Runner de partie sans grâce de démarrage : premier pgrep manqué (lancement à froid post-reboot) → boucle cassée à 0 s → le stop de clôture tuait le jeu en pleine charge des modèles (p48) | Tant que le processus n'a JAMAIS été vu, ne pas conclure à sa mort ; bail franc à 300 s. « Vu puis disparu » reste la condition de fin | p48, fix 75c0409d |
| 2026-08-21 | — | MESURE tête stable (v35.6, p50) : prompt scène 539 tok évalués à froid → 312-315 au 2e appel (le cache de préfixe KV saute la tête commune), éval 68 s → 16-24 s. Scène courte (≤90 tok) + tête stable = 47,9 s → PREMIÈRE lookahead servie (p50 : arc:5, lookahead:1, SECOURS=0, 44 s/beat record) | course50 |
