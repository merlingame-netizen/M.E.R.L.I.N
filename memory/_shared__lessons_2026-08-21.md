# Annexe leçons — 2026-08-21 (à fusionner dans _shared__lessons.md)

> CORRECTION : la première version de cette annexe affirmait « instance résiliée,
> boot volume préservé » — c'était FAUX. La page Compute → Instances montrait
> merlin-arm-a1 RUNNING (créée le 10 août, IP 141.253.124.75). Le widget
> « Explorateur de ressources » de l'accueil OCI était périmé (seul le boot volume
> y figurait, « vu il y a 9 jours »).

| Date | Erreur | Correction | Source |
|------|--------|------------|--------|
| 2026-08-21 | Diagnostic « instance résiliée » fondé sur le widget Explorateur de ressources de la page d'accueil OCI (ne montrait que le boot volume « Disponible ») | Un widget d'accueil n'est PAS la console : la page Compute → Instances fait foi. Toujours la vérifier avant toute conclusion sur l'existence d'une ressource | Console OCI 2026-08-21 |
| 2026-08-21 | Un 502 Bad Gateway trycloudflare interprété comme « cloudflared vivant donc VM vivante », puis comme « VM morte » | Une page d'erreur CDN ne prouve ni la vie ni la mort de l'origine. Le 502 signalait en fait un GEL utilisateur : Studio injoignable derrière un tunnel encore enregistré | Diagnostic p42 |
| 2026-08-21 | 25 h de silence attribuées successivement au quota ntfy puis à une résiliation | Signature du GEL utilisateur : instance RUNNING mais processus résidents seuls vivants, tout spawn meurt (cron/keepalive/autosync/Courrier muets, keepalive 1 min incapable de relancer Studio). Remède : reboot console. Cause à chercher aux logs post-boot (suspect : Godot orphelin, deux modèles chargés, mémoire épuisée) | p42, 2026-08-20→21 |
| 2026-08-21 | Jobs de rapport conçus pour un Courrier vivant alors que plus rien ne pouvait s'exécuter | Quand TOUS les canaux se taisent d'un coup — y compris les chemins d'échec qui parlent toujours — suspecter d'abord que l'exécutant ne tourne plus (gel ou disparition), pas le canal | p42, jobs 043-046 |
