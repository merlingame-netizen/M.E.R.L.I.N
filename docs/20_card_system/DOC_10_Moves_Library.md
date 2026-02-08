# DOC 10 — Moves Library (v0.6)

## Format
Chaque move est un **outil** utilisable en combat, en route, ou les deux.

- `mode` : `COMBAT` / `ROUTE` / `BOTH`
- `verb` : `FORCE` / `LOGIQUE` / `FINESSE`
- `cost` : ressources run consommées (ex: `Vigueur:1`, `Concentration:1|Materiel:1`)
- `tags` : mots-clés pour synergies (status, posture, loot, etc.)

## Table (80 moves)

| ID | Nom | Type | Mode | Verbe | Coût | Tags | Effet combat (résumé) | Effet route (résumé) |
|---|---|---|---|---|---|---|---|---|
| `MV_001` | Coup Brut | BETE | COMBAT | FORCE | Vigueur:1 | DMG | Dégâts modérés, +Momentum | — |
| `MV_002` | Écrasement | TERRE | COMBAT | FORCE | Vigueur:2 | DMG, SLOW | Gros dégâts, -SPD ennemi 1 tour | — |
| `MV_003` | Morsure Ardente | FEU | BOTH | FORCE | Vigueur:1 | DMG, BRULURE | Dégâts + chance Brûlure | Brûle un obstacle (réduit Risque) |
| `MV_004` | Brise-Armure | METAL | COMBAT | FORCE | Vigueur:1 | DEBUFF_DEF | Baisse DEF ennemi 2 tours | — |
| `MV_005` | Charge Tonnerre | FOUDRE | COMBAT | FORCE | Vigueur:2 | DMG, SURCHARGE | Dégâts élevés, applique Surcharge (auto) | — |
| `MV_006` | Cri d’Intimidation | OMBRE | BOTH | FORCE | Vigueur:1 | PEUR | Applique Peur 2 tours | Fait reculer un PNJ hostile (Chance ↑) |
| `MV_007` | Poigne de Racines | NATURE | BOTH | FORCE | Vigueur:1 | ROOT, SLOW | Réduit SPD + petit DOT | Immobilise une menace (Risque ↓) |
| `MV_008` | Coup de Glace | GLACE | COMBAT | FORCE | Vigueur:1 | GEL | Applique Gel léger (retard) | — |
| `MV_009` | Poussée d’Air | AIR | COMBAT | FORCE | Vigueur:1 | DMG, KNOCK | Dégâts + baisse précision ennemie 1 tour | — |
| `MV_010` | Percussion Arcane | ARCANE | COMBAT | FORCE | Vigueur:1 | DMG | Dégâts + bonus si Momentum>50 | — |
| `MV_011` | Observation | LUMIERE | BOTH | LOGIQUE | Concentration:1 | SCAN | Révèle intention + faible debuff ennemi | Révèle info sur nœud / danger |
| `MV_012` | Planification | ARCANE | BOTH | LOGIQUE | Concentration:1 | PLAN | +Momentum + réduit dégâts reçus prochain tour | Réduit difficulté prochain mini-jeu |
| `MV_013` | Analyse des Runes | ARCANE | ROUTE | LOGIQUE | Concentration:2 | PUZZLE | — | Déverrouille un choix rare / évite piège |
| `MV_014` | Tactique de Garde | METAL | COMBAT | LOGIQUE | Concentration:1 | GUARD | Réduit dégâts reçus 2 tours | — |
| `MV_015` | Calcul de Trajectoire | AIR | BOTH | LOGIQUE | Concentration:1 | AIM_HELP | Bonus critique si FINESSE utilisée ensuite | Bonus sur mini-jeu AIM |
| `MV_016` | Lecture du Vent | AIR | ROUTE | LOGIQUE | Concentration:1 | SCOUT | — | Révèle type du prochain nœud |
| `MV_017` | Déduction | ESPRIT | BOTH | LOGIQUE | Concentration:1 | INSIGHT | Réduit chance d’attaque spéciale ennemie | Augmente chance de bon outcome même en fail |
| `MV_018` | Calme Mental | ESPRIT | BOTH | LOGIQUE | Concentration:1 | CALM | Retire 1 statut négatif léger | Baisse Stress Bestiole |
| `MV_019` | Stabilisation | EAU | BOTH | LOGIQUE | Concentration:1 | HEAL_SMALL | Soin léger + -Stress | Récup énergie/humeur |
| `MV_020` | Diagnostic | POISON | BOTH | LOGIQUE | Concentration:1 | ANTIDOTE | Réduit Venin (1 stack) | Détecte toxines (Risque ↓) |
| `MV_021` | Pas Léger | AIR | BOTH | FINESSE | Materiel:0 | EVADE | Augmente esquive 1 tour | Réduit Risque sur obstacle |
| `MV_022` | Coup Précis | LUMIERE | COMBAT | FINESSE | Concentration:1 | CRIT | Chance crit ↑ + dégâts | — |
| `MV_023` | Désamorçage | METAL | ROUTE | FINESSE | Materiel:1 | DISARM | — | Annule piège (succès) ou réduit coût (fail) |
| `MV_024` | Crochetage | METAL | ROUTE | FINESSE | Materiel:1 | LOCKPICK | — | Ouvre accès bonus (loot) |
| `MV_025` | Venin Subtil | POISON | BOTH | FINESSE | Materiel:1 | VENIN | Applique Venin 1 stack | Affaiblit un obstacle vivant |
| `MV_026` | Ombre Glissée | OMBRE | BOTH | FINESSE | Materiel:1 | STEALTH | Baisse précision ennemie | Permet d’éviter un combat (chance) |
| `MV_027` | Éclat Aveuglant | LUMIERE | BOTH | FINESSE | Concentration:1 | BLIND | Réduit dégâts ennemis 1 tour | Augmente chance de fuite/éviter |
| `MV_028` | Fil d’Eau | EAU | BOTH | FINESSE | Materiel:1 | SLIP | Réduit SPD ennemi | Traverse zone dangereuse |
| `MV_029` | Suture Rapide | NATURE | BOTH | FINESSE | Nourriture:1 | HEAL_SMALL | Soin léger | Soin hors combat |
| `MV_030` | Main Froide | GLACE | BOTH | FINESSE | Concentration:1 | GEL | Gel léger | Ralentit mécanisme (TIMING plus facile) |
| `MV_031` | Élan Sauvage | ESPRIT | BOTH | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_032` | Cartographie | OMBRE | BOTH | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_033` | Danse d’Aiguilles | POISON | COMBAT | FINESSE | Concentration:1 | CRIT | Altération légère / crit / esquive | — |
| `MV_034` | Bélier | FOUDRE | BOTH | FORCE | Vigueur:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_035` | Lecture d’Aura | GLACE | BOTH | LOGIQUE | Concentration:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_036` | Détour | EAU | BOTH | FINESSE | Materiel:1|Concentration:1 | STEALTH | Altération légère / crit / esquive | Augmente Chance sur obstacle discret/diplomatie |
| `MV_037` | Flamme Vive | BETE | BOTH | FORCE | Vigueur:2 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_038` | Économie de Mouvement | METAL | ROUTE | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | — | Révèle info / réduit difficulté mini-jeu |
| `MV_039` | Feinte | FOUDRE | COMBAT | FINESSE | Materiel:1 | CRIT | Altération légère / crit / esquive | — |
| `MV_040` | Onde de Choc | ESPRIT | BOTH | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_041` | Tri des Pistes | EAU | BOTH | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_042` | Filigrane | METAL | ROUTE | FINESSE | Materiel:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_043` | Poing de Fer | FOUDRE | BOTH | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_044` | Prémonition | ARCANE | BOTH | LOGIQUE | Concentration:2 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_045` | Nœud Rapide | NATURE | ROUTE | FINESSE | Materiel:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_046` | Rugissement | LUMIERE | COMBAT | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | — |
| `MV_047` | Focalisation | POISON | ROUTE | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | — | Révèle info / réduit difficulté mini-jeu |
| `MV_048` | Silence | GLACE | ROUTE | FINESSE | Concentration:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_049` | Cisaille | POISON | BOTH | FORCE | Vigueur:2 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_050` | Mesure | FOUDRE | BOTH | LOGIQUE | Concentration:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_051` | Pointe | FEU | COMBAT | FINESSE | Materiel:1|Concentration:1 | CRIT | Altération légère / crit / esquive | — |
| `MV_052` | Fracasse | NATURE | BOTH | FORCE | Vigueur:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_053` | Rappel | GLACE | ROUTE | LOGIQUE | Concentration:2 | SCAN, PLAN | — | Révèle info / réduit difficulté mini-jeu |
| `MV_054` | Caresse | POISON | ROUTE | FINESSE | Materiel:1|Concentration:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_055` | Marteau | EAU | BOTH | FORCE | Vigueur:2 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_056` | Synchronisation | GLACE | ROUTE | LOGIQUE | Concentration:1 | SCAN, PLAN | — | Révèle info / réduit difficulté mini-jeu |
| `MV_057` | Transfert | OMBRE | ROUTE | FINESSE | Concentration:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_058` | Racines Furieuses | TERRE | COMBAT | FORCE | Vigueur:1 | DMG | Dégâts + petit bonus Momentum | — |
| `MV_059` | Convergence | BETE | BOTH | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_060` | Passe-Muraille | FOUDRE | ROUTE | FINESSE | Materiel:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_061` | Élan Sauvage | ESPRIT | COMBAT | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | — |
| `MV_062` | Cartographie | FEU | BOTH | LOGIQUE | Concentration:2 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_063` | Danse d’Aiguilles | FEU | COMBAT | FINESSE | Materiel:1|Concentration:1 | CRIT | Altération légère / crit / esquive | — |
| `MV_064` | Bélier | BETE | BOTH | FORCE | Vigueur:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_065` | Lecture d’Aura | LUMIERE | ROUTE | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | — | Révèle info / réduit difficulté mini-jeu |
| `MV_066` | Détour | ARCANE | ROUTE | FINESSE | Materiel:1 | STEALTH | — | Augmente Chance sur obstacle discret/diplomatie |
| `MV_067` | Flamme Vive | FEU | COMBAT | FORCE | Vigueur:2 | DMG | Dégâts + petit bonus Momentum | — |
| `MV_068` | Économie de Mouvement | FOUDRE | BOTH | LOGIQUE | Concentration:2 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_069` | Feinte | NATURE | BOTH | FINESSE | Materiel:1 | STEALTH | Altération légère / crit / esquive | Augmente Chance sur obstacle discret/diplomatie |
| `MV_070` | Onde de Choc | NATURE | BOTH | FORCE | Vigueur:2 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_071` | Tri des Pistes | BETE | BOTH | LOGIQUE | Concentration:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_072` | Filigrane | NATURE | BOTH | FINESSE | Materiel:1 | STEALTH | Altération légère / crit / esquive | Augmente Chance sur obstacle discret/diplomatie |
| `MV_073` | Poing de Fer | BETE | BOTH | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | Réduit Risque sur obstacle physique |
| `MV_074` | Prémonition | FOUDRE | BOTH | LOGIQUE | Concentration:1|Faveur:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_075` | Nœud Rapide | NATURE | COMBAT | FINESSE | Materiel:1 | CRIT | Altération légère / crit / esquive | — |
| `MV_076` | Rugissement | ARCANE | COMBAT | FORCE | Vigueur:2 | DMG | Dégâts + petit bonus Momentum | — |
| `MV_077` | Focalisation | EAU | BOTH | LOGIQUE | Concentration:2 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
| `MV_078` | Silence | BETE | COMBAT | FINESSE | Materiel:1 | CRIT | Altération légère / crit / esquive | — |
| `MV_079` | Cisaille | FEU | COMBAT | FORCE | Vigueur:1|Materiel:1 | DMG | Dégâts + petit bonus Momentum | — |
| `MV_080` | Mesure | POISON | BOTH | LOGIQUE | Concentration:1 | SCAN, PLAN | Révèle intention / réduit dégâts reçus | Révèle info / réduit difficulté mini-jeu |
