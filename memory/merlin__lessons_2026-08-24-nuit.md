# MERLIN — leçons du 24/08 (nuit, heure de Paris)

| Date | Erreur | Correction | Source |
|------|--------|------------|--------|
| 2026-08-24 | p65 « journal absent rc=1 » **non expliquée** : le harnais ne renvoyait que 12 lignes de `llama_model_loader`. Ma première hypothèse (un fantôme de la phase sélection vu par `pgrep`) était FAUSSE — `$GS start` ne rend la main qu'une fois le VNC ouvert, donc le jeu était bien vivant à t=0 et il est réellement mort ~10 s plus tard, en pleine charge des modèles. | `a_partie_journal.sh` : l'échec dit désormais la mémoire, le verdict du noyau (OOM ?), `inner.log` et un `godot.log` débruité. Plus drain avant lancement et deux `pgrep` manqués avant de conclure. La cause reste à établir — c'est p66 qui la dira. | job-065, partie.log |
| 2026-08-24 | Diagnostic annoncé avant d'être établi (le « fantôme »). | Un échec dont le journal ne dit pas la cause se répare d'abord en rendant l'échec lisible, pas en devinant le coupable. | revue de p65 |
| 2026-08-24 | Le geste inventé par le modèle (« OBSERVER + Le Pressentiment » → « en poussant vos mains sur leur pierre de basalte ») a résisté à v36 (règle du verbe) puis v45 (règle du trait). Une règle de prompt ne tient pas un invariant. | v46 : la phrase du geste est COMPOSÉE PAR LE CODE (socle du verbe + manière du trait, 25 concepts couverts). Le modèle n'écrit plus que la suite. Ce qui doit être vrai à 100 % ne se demande pas à un LLM. | Maxime, 2026-08-24 |
| 2026-08-24 | La ligne mécanique annonçait « 2d6 7 +N » sur un geste sûr (die=0, face de repli) — un dé qui n'a jamais roulé. Latent depuis v34, invisible tant que le geste sûr était rare. | v46 : la ligne dit la MISE quand `geste_sur`. Leçon : toute valeur de repli affichée à l'écran est un mensonge en attente de fréquence. | revue v46 |

## Décision — le dé se dispense (v46)

- Maîtrise du verbe (`skill_mod >= 2`) → +2 de marge sur le jet minimal ; rareté du trait → +1/+2/+3 (Rare/Épique/Mythique).
- **Jamais au Climax** : l'éclatante n'existe que par le risque, et le pic de quête doit garder le dé.
- Talent 0 + trait Commune → marge 0 → comportement v34 **strictement** inchangé (vérifié : 80 combos, parse check avant/après identiques).

## Protocole de vérification locale (rétabli le 2026-08-24)

Bash fonctionne de nouveau dans cette session : les clones locaux ont été resynchronisés sur origin
(jeu v45, outillage v45) et le patch v46 a été **appliqué et mesuré localement** avant push —
`godot --headless --editor --quit` avant/après (jeux d'erreurs identiques), `--check-only` par
fichier, et une sonde de logique sur les 80 fusions (5 verbes × 16 traits, 0 phrase vide).
`tools/cli.py godot` reste inutilisable ici (chemin Godot codé pour la machine Windows).
