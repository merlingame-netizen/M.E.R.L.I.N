# Audit de game design strict — 2026-09-07

> Six lentilles de designer (décision, risque, progression, économie, rythme, ressenti), chacune contredite par un sceptique : 64 constats, 55 survivants, 9 réfutés. Synthèse ci-dessous, telle que rendue, vérifiée par sondage (geste sûr, plafonds, redraw, répit, p74). Aucune règle n a été changée : ce document est une proposition, les décisions sont dans memory/.

# M.E.R.L.I.N. : synthèse de game design (R166)

## 1. Le jeu tel qu'il est

Une scène, cinq tuiles, quatre runes tirées au sort. Un geste, +3 par tag couvert, 2d6 contre 6/9/12. La marge donne le degré ; santé et corruption découlent de la scène. Réussir arme un draft et un point de talent. Vingt fois, puis un climax à DC 12.

La promesse : la maîtrise se sent, la mort est rare mais réelle. La moitié est tenue : le moteur est lisible. Mais deux régimes coexistent. Qui couvre et répète un verbe ne lance plus le dé après le beat 7 (p74 : 16 beats sur 20 « Sans jet », climax compris, 0 éclatante, intégrité 10 → 10). Qui ne couvre pas meurt à 14 beats une fois sur cinq. Pas de milieu. Or c'est là que vit un jeu de dés.

## 2. À continuer

1. **Le 2d6 contre DC, planchers 2/12, mise avant le dé** (merlin_resolution.gd:336-344). Une addition, une marge qui se lit. Ne pas toucher aux bandes.
2. **Nature × degré** (merlin_resolution.gd:25-30). Le prix découle de la scène, jamais d'une case à cocher.
3. **La conversion à prix croissant, offerte seulement quand la main ne couvre pas** (merlin_run.gd:260-315). Le seul vrai échange risque contre prix. p74 : 2 acceptées, 2 refusées.
4. **La corruption dans la main** : un Murmure injecté tous les 5 points (merlin_run.gd:1150-1163). Juger sur « mains polluées par traversée » (p74 : 2/20, cible 4-6), pas sur la jauge.
5. **L'appareil de mesure** : preview = résolution, journal par beat, rendre.py.

## 3. À améliorer

### 3.1 Le plafond des atouts (la mort redevient possible)

Aujourd'hui : talent ≤ 5 (merlin_run.gd:33), maîtrise {3:+1, 6:+2} (:916), greffes roll sans plafond (:793-805), +3 par tag. `geste_sur = (2 + mods + m_sure) >= dc` (merlin_resolution.gd:111). Au Climax seul m_sure tombe à 0 (:110) : p74 beat 22, +16 contre DC 12, sans jet.

Défaut : le DC maximal (12) est sous les atouts atteignables (16). Simulation du moteur, archétype attentif, 22 beats : skill 0 → 26 % de morts ; cap +1 → 6,5 % ; cap +2 → 0,9 % ; code → 0 %. La mortalité se règle sur ce seul nombre.

Règle : talent + maîtrise ≤ +1 ; greffes roll ≤ +2 par verbe ; sur Épreuve et Climax, atouts ≤ DC − 4. Geste sûr gardé (v34/v46) mais borné : difficulté 1, ou couverture pleine en difficulté 2 ; jamais au Climax. Ensuite seulement, ECLAT_MARGIN 8 → 7 (merlin_resolution.gd:48).

Mesure : simulation à cap 0/1/2, retenir celui qui donne 8-12 %. Nuit du bot : « Sans jet » ≤ 25 %, Climax au dé 10 nuits sur 10, ≥ 1 éclatante par 20 beats.

### 3.2 La boucle de récompense (le perdant reçoit quelque chose)

Aujourd'hui : draft armé après chaque réussite (merlin_game.gd:920) ; talent +1 sur réussite, 0 sur partiel (merlin_run.gd:983-987). p74 : 8 greffes en 13 beats. BIBLE_DES_REGLES.md:163 l'interdit. Bifurcation au beat 5.

Règle : le draft appartient au monde (une Rencontre sur deux, ou après un revers), cap 5 greffes. Un point de talent par beat joué, 2 sur éclatante, cap in-run 3.

Mesure : zéro draft consécutif à un degré ; greffes ≤ 5 ; points gagnés sur partiels > 0.

### 3.3 Cinq tuiles pour de vrai (le verbe redevient une question de sens)

Aujourd'hui : en difficulté 2 les deux requis sont hors-base (merlin_scenario.gd:109) : la tuile ne couvre jamais. Le nœud de talent vise le verbe le plus joué (merlin_run.gd:1012). Les greffés passent en tête des requis (merlin_scenario.gd:228) : p74, {Franchise, Équilibre} cinq beats de suite, +1 corruption par réussite jamais annoncé (merlin_resolution.gd:29). OBSERVER 17 fois sur 20.

Règle : REQ_GAP {1:1, 2:1, 3:2}, le tag de base pris dans le biais du type (Rencontre → PARLER, Épreuve → AGIR ou COMBATTRE). Greffés au même poids que le biais. Un requis ne revient pas au beat suivant, une paire jamais deux fois. Maîtrise par diversité (+1 à quatre verbes distincts). Corruption sur réussite seulement si l'issue nomme ce qui est cédé.

Mesure, sur un bot sans préférence « fidele » (probe_partie_journal.gd:56-59 fabrique la monoculture) : tuile dominante ≤ 40 %, couverture 2/2 ≥ 25 %, répétition consécutive ≤ 2, corruption sur réussite ≤ 2.

### 3.4 Une économie avec une source et un prix (acheter est un renoncement)

Aujourd'hui : bourse à 0 toute la traversée (merlin_run.gd:1266). L'étal s'ouvre quand même, à chaque Rencontre (merlin_game.gd:1550-1556). Le Coup de Pouce est grisé à 9 gw (merlin_game.gd:2006-2020) alors qu'il se paie en Promesse (merlin_run.gd:1366-1367). La Promesse est gratuite à bourse 0 (:1449). L'Information n'affiche rien (:1298-1300).

Règle : bourse de départ tirée 8-31 (corpus, médiane 17). Butin 2-6 gw sur un beat ordinaire sur cinq, réussite seule. Un étal par quête, jamais sans article payable. Coup de Pouce hors du filtre gwenneg : pacte d'une figure en Rencontre. La dette se règle sans dé : une rune de la main, ou 2 d'intégrité, ou refus (+2 corruption, trace lue par la figure). Information supprimée.

Mesure : achats par étal ≥ 0,5 ; bourse finale ≤ 1/3 du départ ; `coup_de_pouce_exercised` ≥ 1 ; jamais `paid: 0` ; étals par quête ≤ 1.

### 3.5 Une main qu'on tient (la couverture devient une gestion)

Aujourd'hui : redraw complet à chaque beat (merlin_run.gd:484), deck remis à neuf à chaque run (:399), contre BIBLE_DES_REGLES.md:53 et :56. Le biais par type (merlin_scenario.gd:84-93) n'est pas dit au joueur.

Règle : seule la rune posée est remplacée. Le type du beat suivant est annoncé gratuitement sur la carte de sentier. La main persiste entre traversées ; la mort y laisse Le Deuil.

Mesure : taux de tenue ≥ 30 % pour un bot qui tient la rune du biais annoncé ; couverture ≥ 1 à 85 % contre 73 % aveugle ; main du beat 1 = main finale de la veille.

### 3.6 Des temps forts qui changent la règle (la quête a une forme)

Aujourd'hui : cinq types résolus au même dé (merlin_scenario.gd:35), cycle de six (:1349), DC 9 du beat 2 au 21. Neuf mécaniques « décidées, non construites » (BIBLE_DES_REGLES.md:101) ; le corpus en joue 19 sur 89 beats. Le Climax ressert arc[dernier] (:1750) ; le duel R166 (BIBLE.md:2285) n'existe pas.

Règle : d'abord « le choix », 2-4 options à coût nommé, sans dé, floor(N/5) par quête, jamais beat 1, jamais deux de suite, options d'une banque écrite à la main (latence zéro). Puis le climax en deux temps : approche au dé en n−1, dont le degré donne avantage ou handicap (mécanique Coup de Pouce existante) ; décisif en n, DC 12, jamais sûr.

Mesure : ≥ 2 spéciaux sur 10-14 beats, attente moteur du spécial = 0 s ; dé ≠ 0 au décisif 10 nuits sur 10, ≥ 2 partiels ou échecs sur 10 climax.

### 3.7 Lisibilité avant le clic

La mise chiffrée n'apparaît qu'après l'engagement (merlin_fx.gd:289). Règle : un mot d'échelle sur le bouton (sûr, probable, risqué, périlleux), calculé sur la distribution 2d6, jamais sur le dé pré-tiré. Mesure : épreuve UX à 5 joueurs, « ça passe ? » en < 2 s, < 1 erreur sur 5.

## 4. À arrêter

- **Le répit automatique** (merlin_run.gd:1191). Ni le réparer, ni le remplacer par un répit par Rencontre : dé rendu + répit = 0,0 % de morts. Le soin se paie.
- **La dispense du dé par le talent hors routine, et le Climax sans jet.** Le code annonce « jamais au Climax » (merlin_resolution.gd:107-109) et ne le fait pas.
- **Le draft armé par le degré** (merlin_game.gd:920) et **les greffés en tête des requis** (merlin_scenario.gd:228).
- **La ligne « Fragment du Graal n/12 »** (merlin_end.gd:368) : toujours 0, le chapitre passé est vide (merlin_game.gd:2964).
- **Le draft d'ouverture au beat 0** (merlin_game.gd:3305-3316) : une décision avant une ligne lue.
- **Ne pas construire** : trois tags requis sur les temps forts (le +3 de DC est remboursé par le tag) ; une rampe à DC 10 avant mesure (le corpus ne joue que 9 et 12 ; dé rendu, 78-95 % des morts tombent déjà dans le dernier tiers) ; d'autres amortisseurs avant d'avoir compté conversions et coups de pouce par nuit.

## 5. La première chose à faire

Le plafond des atouts, et rien d'autre avant. Simulation gd-run, archétype attentif (80 % un tag, 20 % deux), 22 beats, cap 0 / +1 / +2, Climax au dé : retenir le cap qui donne 8-12 % de morts. Puis une nuit du bot couvrant : « Sans jet » ≤ 25 %, climax avec dé, ≥ 1 éclatante, intégrité sous 7 au moins une fois. Sans ce nombre, l'économie n'a pas de demande, l'éclatante n'a pas de fenêtre, le rythme n'a rien à faire monter.