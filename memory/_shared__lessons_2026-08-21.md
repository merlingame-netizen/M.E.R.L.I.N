# Annexe leçons — 2026-08-21 (à fusionner dans _shared__lessons.md)

| Date | Erreur | Correction | Source |
|------|--------|------------|--------|
| 2026-08-21 | 24 h de silence VM attribuées d'abord au quota ntfy, puis à un gel mémoire — en réalité l'INSTANCE Oracle n'existait plus (résiliée, boot volume préservé) | La console fait foi avant toute inférence réseau : Explorateur de ressources qui ne montre QUE « (Boot Volume) » au statut « Disponible » = instance disparue (attaché à une instance vivante il dirait « En cours d'utilisation ») | Console OCI 2026-08-21 |
| 2026-08-21 | Un 502 Bad Gateway trycloudflare interprété comme « cloudflared vivant donc VM vivante » | Faux : un 502 Cloudflare ne prouve pas que le connecteur tourne. Ne jamais conclure « machine vivante » d'une page d'erreur CDN ; vérifier l'état de l'instance à la source | Diagnostic p42 |
| 2026-08-21 | Récupération : envisager de recréer/reprovisionner à neuf | Recréation 0 € SANS reprovisionner : Block Storage → Volumes d'initialisation → « Créer une instance » depuis le boot volume (A1.Flex 4 OCPU/24 GB, Always Free même en PAYG : 3000 h OCPU + 18000 h GB/mois = 4/24 en 24/7). Disque intact : modèles, clones, cron @reboot, keepalive, file Courrier — tout repart seul au boot | Console OCI 2026-08-21 |
| 2026-08-21 | Jobs de rapport conçus pour un Courrier vivant (ntfy/tuyau) alors que la machine n'existait plus | Quand TOUS les canaux se taisent d'un coup — y compris les chemins d'échec qui parlent toujours — suspecter d'abord la disparition de l'exécutant, pas celle du canal | p42, jobs 043-046 |
