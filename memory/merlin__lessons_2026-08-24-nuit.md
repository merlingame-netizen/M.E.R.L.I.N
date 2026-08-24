# MERLIN — leçons du 24/08 (nuit, heure de Paris)

| Date | Erreur | Correction | Source |
|------|--------|------------|--------|
| 2026-08-24 | p65 conclue « journal absent rc=1 » et imputée à v44 : c'était le HARNAIS. `game-stack stop` rend la main avant que Godot ne meure ; la boucle d'attente voyait le mourant de la phase *sélection*, posait `VU=1`, puis concluait 10 s plus tard — et la clôture tuait la vraie partie en pleine charge des modèles (4,79 Gio). | `a_partie_journal.sh` : drain (aucun godot de sonde ne tourne) avant `start`, et deux `pgrep` manqués d'affilée avant de conclure. | job-065, partie.log |
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
