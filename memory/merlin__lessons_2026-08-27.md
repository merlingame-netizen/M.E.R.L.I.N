# MERLIN — leçons du 27/08 (heure de Paris)

| Date | Erreur | Correction | Source |
|------|--------|------------|--------|
| 2026-08-27 | Une garde de job attendait un commentaire de code (`FANTOME DE LA PHASE PRECEDENTE`) renommé trois jours plus tôt en `DRAIN AVANT LANCEMENT`. La garde n'a plus JAMAIS été satisfaite : job-066 a répondu « p66 ko » à chaque tick depuis le 24/08, et **aucune partie complète n'a validé v44, v45, v46 ni v48**. | job-068 n'attend plus qu'un vrai marqueur fonctionnel (`phrase_du_geste` dans `merlin_resolution.gd`). Leçon : une garde ne doit jamais s'ancrer sur du texte de commentaire — seulement sur un symbole que le code utilise vraiment. | job-066/068, 27/08 |
| 2026-08-27 | J'ai lu « 80 s/beat » comme un problème de lenteur du modèle. C'était un problème de **place** : `prompt_tokens=2045` contre `n_ctx=2048` — le prompt d'issue mange le contexte entier, il ne reste que 2 à 3 tokens pour écrire. Les issues « Vous calez » (2 tokens) et le secours du beat 4 sont des arrêts de contexte, pas des lenteurs. | Mesurer le budget avant d'accuser la vitesse. Un `tokens_ecrits` qui vaut exactement `n_ctx − prompt_tokens` est la signature d'un contexte saturé. | journal p68, beats 3-4 |
| 2026-08-27 | v48 a été poussé à 22:04 le 25/08 ; la partie témoin p66 avait rejoué à 21:56 — **8 minutes avant**. J'ai failli lire son verdict comme celui de v48. | Toute partie témoin doit imprimer le `sha` du jeu au départ (job-068 le fait : `dire "depart" "... sha=$(git rev-parse --short HEAD)"`). Un verdict sans sha ne vaut rien. | p66 vs v48 |
| 2026-08-27 | Le canon v48 (588 tokens) a bien pris l'empreinte — lieux nommés et figures propres dans la prose, 0 violation des interdits — mais il a mangé le budget d'écriture. Une empreinte qui tient et une issue qui s'écrit étaient en concurrence pour le même contexte. | v48.1 : le canon se paie une fois (tête stable + cache de préfixe) et se réduit à ce qui PRODUIT de l'empreinte ; ce qui n'a fait que l'INTERDIRE et n'a jamais été violé sort du prompt. | verdict v48 |

## Décret — les trois cibles dures (Maxime, 27/08)

> « Il faut pas de secours et de la réussite complete à chaque fois plus une durée de max 20s/beat »

Critères d'acceptation de toute partie témoin à partir de maintenant :

1. **SECOURS = 0** — aucun filet en dur servi.
2. **Réussite complète à chaque geste** — précisé par Maxime : cela vise **la partie témoin
   seulement**. Le bot de la chronique doit jouer des combinaisons couvrantes ; le jeu réel
   garde ses dés, ses partiels et son équilibrage. R158/R166 et la Bible ne bougent pas.
3. **≤ 20 s par beat.**

Chaque cible manquée doit être annoncée avec son compte exact, jamais arrondie ni tue.

## La partie témoin p68 — « Le Seuil de la Mousse » (première partie complète depuis le 24/08)

Empreinte v48 : lieux `[Pas de Nuit, Chêne Creux]` ✅ · figures `[korrigan, Chevalier]` ✅ ·
interdits 3/3 tenus ✅ · **loi de la boucle absente** ❌ (0 occurrence dans 5 beats + intro).

Les trois cibles : SECOURS **1** ❌ · **2 réussites / 3 partiels** ❌ · **80 s de moyenne**
(29 · 67 · 91 · 147 · 64) ❌.

Chronique publiée avec les 3 captures réelles (1280×720) prises par la sonde pendant la partie.
