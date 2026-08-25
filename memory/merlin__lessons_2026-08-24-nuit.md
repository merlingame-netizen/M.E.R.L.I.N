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

## 2026-08-25 00:30 — le canal vers la VM s'est tu, et la fuite trouvée en le cherchant

**Le silence.** Dernier autosync outillage prouvé bon : **20:37 UTC** (job-065, commité 20:22 UTC,
joué 20:39 UTC). Mes push de v46 : 21:04 et 21:08 UTC. À 22:21 UTC, **aucun canari066** sur ntfy —
or job-066 en émet un avant toute autre chose. Le job n'a donc jamais démarré : cinq créneaux
d'autosync (:07 :22 :37 :52) et ~38 réveils du Courrier manqués.

Hypothèse la plus économique, **non vérifiée** : la VM a manqué de mémoire. Elle explique les deux
faits d'un coup — le jeu de p65 mort ~10 s après le VNC, en pleine charge d'un modèle de 4,79 Gio,
puis plus aucun signe de vie. À vérifier par Run Command (voir ci-dessous), pas à décréter.

**La fuite (réelle, corrigée).** En cherchant un moyen d'atteindre la VM j'ai regardé la liaison
montante du Courrier : elle expédie **tout** ce qui traîne dans `courrier/resultats/<job>/` vers un
sujet ntfy **public** dont l'adresse est commitée en clair. `job-062` y a déposé un `lien.txt`
contenant le lien magique du Studio — lisible par quiconque pendant ~3 h (l'attachement a expiré
depuis : 404 vérifié). La règle « le lien du Studio ne circule que par canal privé » ne peut pas
dépendre de la vigilance de l'auteur de chaque job : elle tient désormais **au dernier goulot**
(`a_courrier.sh`), sur le nom ET sur des formes qui n'existent pas en prose de jeu. Vérifié sur
neuf fichiers témoins : `lien.txt`, `.env`, `Bearer`, `ocid1.` retenus ; `journal.json` contenant
« secret » et « clé » en prose, `passe66.txt`, `verdict`, `gestes`, `course` expédiés.

**Leçon.** Un canal de commande qui échoue en silence n'est pas un canal. `a_tools_autosync.sh`
renonçait sans rien dire (trois portes de sortie), et son `pull … | tail -2` avalait le code de
retour — un pull refusé s'annonçait « mis à jour » avec le sha précédent. Les quatre cas sonnent
maintenant sur le téléphone, et un pull sans effet est un échec déclaré.

## 2026-08-25 02:30 — l'animation v46 a enfin TOURNÉ (v46.1)

v46 avait été livrée sans que sa séquence n'ait jamais tourné : le parse check ne dit rien d'une
animation, et la partie témoin exige le moteur natif (absent hors ARM) plus une demi-heure de VM —
qui est muette. Entre les deux, **rien**. C'est le trou qui a permis à v42 de partir avec un
contexte débordé et à v46 de partir sur ma seule parole.

**Piège trouvé** : `godot --headless --script res://…` **n'enregistre PAS les autoloads**
(`MerlinAudio` vaut `null`). La coroutine de `MerlinFx` meurt en silence sur le premier appel et
l'attente ne rend jamais la main — 2 min de blocage sans un message. Il faut une **vraie scène**
(`.tscn`), d'où le couple `probe_fx_geste.gd` + `.tscn`.

Mesures réelles (headless, `motion()` = 1.0) :

| cas | phrase visible | phrase pleine | séquence complète |
|-----|----------------|---------------|-------------------|
| avec dé (OBSERVER + Pressentiment, diff 3) | t+0,75 s | t+2,35 s | **4,3 s** |
| sans jet (COMBATTRE + Main de Fer, talent 2) | t+0,90 s | t+2,50 s | **3,7 s** |

Soit ~1,9 s de plus qu'avant v46 (l'ancien surcoût de fusion était de 2,1-2,4 s) — et ces 1,9 s
sont données à l'écriture de l'issue qui court en fond.

**Contre-épreuve faite** : frappe bridée à 30 % → la sonde rend `rc=1` avec le motif exact
(« la phrase n'a jamais fini de s'écrire (ratio max 0.30) »). Une sonde qu'on n'a pas vue échouer
ne prouve rien.

Bruit connu et sans effet : `Tween … started with no Tweeners` — la sonde passe `card_views` vide,
donc la phase 2 (vol des cartes) crée un tween sans tweener. En partie réelle la vue du trait est
toujours là. Préexistant à v46.
