# BIBLE — Jeu de deck-building narratif (reconstruction 2026-05-25) — **v2.0**

> **Bible reconstruite from scratch** via AskUserQuestion (objectif 200+ questions).
> **TOUTE bible / contexte / mémoire antérieurs sont NON-AUTORITAIRES** (oublié sur décision
> utilisateur du 2026-05-25, « toute bibliothèque précédente de contexte devra être oubliée »).
> **Source de vérité unique = CE fichier**, rempli uniquement par des réponses validées par l'utilisateur.
> **Statut (R100, 2026-05-26)** : **canon MVP GELÉ** (décisions cœur R1-99 verrouillées). Les rounds R100+ n'ajoutent que du **détail / contenu concret / post-MVP**, sans contredire le canon MVP.
> **v2.0 (R114, 2026-06-12)** : extension « montée en gamme » — sections §19-§24 (DA, Juice, Audio,
> Lisibilité, Pipeline assets). `docs/archive/GAME_DESIGN_BIBLE_legacy_v3.8.md` et `DEV_PLAN_V2.5.md`
> sont **ARCHIVÉS et non-autoritaires** ; leurs sections encore valables ont été rapatriées ici, adaptées au canon.

---

## Quickstart (build-ready) — résumé exécutif
- **Pitch** : **M.E.R.L.I.N.** — deck-building narratif celtique. Un voyageur, à son insu prisonnier de la **simulation rêvée par l'IA Merlin**, cherche le **Graal (= la sortie)** à Brocéliande. Feel Citizen Sleeper / Cultist Simulator, ton **merveilleux-inquiétant**.
- **Boucle** : situation (LLM) → main ~5 → joue **1 principale + 1-2 modificateurs** → **résolution hybride** (couverture des **tags requis** → degré ; le **code** applique les jauges ; **Gemma 4 narre**) → Intégrité/Corruption → situation suivante (lookahead).
- **2 jauges** : **Intégrité (0-10)** + **Corruption** (monte avec les cartes risquées ; seuils → événements + cartes corrompues). **Mort narrative** jugée par Gemma 4.
- **Scénario** : Menu → **3 titres+pitch générés** → squelette (écran "Merlin écrit") → **5 situations + climax** → fin (multiple). **Méta cross-run** : chaque run = un fragment du Graal ; **révélation finale = fusion avec Merlin** (éternel retour).
- **4 factions** (toutes brisées par le Graal) : **Druides** (gardiens illusionnés qui glitchent) · **Créatures & Êtres** (désunis, en boucle) · **Chevalerie déchue** (Arthur, rejoue sa défaite) · **Corrompus** (le bug fait chair).
- **Tech** : **MerlinLLM natif** (Gemma 4 E2B), **GBNF** (1/sortie), **100% local, zéro Ollama**, Desktop Windows. **2D minimal** (texte+tags ; glitch indexé sur la Corruption). Artworks SD (gravure sépia, 1/situation) = **post-MVP**.
- **MVP** : la boucle ci-dessus · deck canon **12 cartes** (4 approches) · **Brocéliande seul** · Merlin + 2-3 figures · accueil Merlin minimal. **Reporté** : roster complet, autres biomes, SD, méta/réputation.
> Détail complet : sections §1-§16 + journal de décisions ci-dessous.

---

## Cœur du jeu (verrouillé 2026-05-25)
- **Genre** : deck-building **narratif**.
- **Cœur IA** : **Gemma 4** (génère les scénarios) + **Stable Diffusion 1.5 / modèle visuel CPU**
  (génère les artworks des cartes). 100% local, natif.
- **Tech LLM** : MerlinLLM natif direct (Gemma 4 E2B), zéro Ollama.
- **Visuel** : 2D minimal d'abord ; artworks générés ajoutés ensuite.

## MVP cible (verrouillé 2026-05-25)
Menu → lancer la scène de jeu **Brocéliande (Biome 1)** → sélectionner parmi **3 scénarios générés**
(titres différents à chaque lancement) → **chargement du scénario complet** → le jeu suit.

---

## Table des matières (domaines de la bible)
1. Vision & Piliers
2. Boucle de gameplay
3. Deck-building (acquisition, construction, pioche, main, défausse, synergies)
4. Anatomie des cartes (types, coûts, effets, rareté)
5. Scénarios (structure, sélection 3-titres, beats, longueur, fin)
6. Biomes & Monde (Brocéliande = Biome 1)
7. Ressources & Économie
8. Progression & Méta-progression
9. Génération LLM — Gemma 4 (rôles, prompts, contraintes)
10. Génération visuelle — SD 1.5 / CPU (style, pipeline, perf)
11. UI / UX 2D (écrans, navigation, feedback)
12. Audio
13. Narratif / Ton / Lore
14. Technique / Perf / Plateforme / Export
15. Onboarding / Tutoriel
16. Périmètre MVP détaillé

> **Sections additionnelles (post-questionnaire)** : §18 v10.13 Fondations prouvées (R108-R113) ·
> §19 R114 Montée en gamme · §20 Direction Artistique (R115) · §21 Animations & Juice (R116) ·
> §22 Audio (R117) · §23 Lisibilité & Accessibilité (R118) · §24 Pipeline Assets & Outillage (R119).
> (§17 : numéro non attribué — gap historique conservé.)

---

## Journal des décisions (chronologique)

### 2026-05-25 — Fondations (reset complet)
- Reset projet Godot complet : `scenes/` + `scripts/` supprimés ; moteur natif **MerlinLLM conservé**
  (`addons/merlin_llm/` + modèles GGUF), `data/`, `docs/`, `assets/`, `tools/` conservés.
- Concept retenu : **deck-building narratif**, Gemma 4 + SD 1.5 (ou modèle visuel CPU) au centre.
- Toute bible/mémoire antérieure = **oubliée / non-autoritaire**.
- MVP : Menu → Brocéliande → 3 scénarios générés → chargement → jeu.
- (les réponses des rounds AskUserQuestion s'ajoutent ci-dessous au fil de l'eau)

### 2026-05-25 — Round 1 (fondations deck-building)
- **Modèle** : le deck = **répertoire d'actions du joueur** ; on joue des cartes sur des situations générées.
- **Carte** = volontairement **multi-facettes** (action / pouvoir / personnage / fragment à la fois) ; **cœur = COMBINER des cartes** pour résoudre une situation.
- **Acquisition** = **mix récompense + LLM** (récompenses structurées, contenu généré par Gemma 4).
- **Référence-feel** = **Citizen Sleeper / Cultist Simulator** (narratif systémique, gestion de cartes abstraites, ambiance forte, peu de combat frontal).

### 2026-05-25 — Round 2 (mécanique de combinaison = cœur)
- **Situation** = scène narrative **ouverte** ; le joueur joue une combinaison libre, **Gemma 4 juge** le résultat + les conséquences.
- **Geste** = **1 carte principale + 1-2 modificateurs** (les modificateurs amplifient/altèrent l'action principale).
- **Succès** = **hybride** : la combinaison doit couvrir les **tags requis** ET Gemma 4 évalue la **pertinence narrative** → résultat (réussite / partiel / échec) nuancé.
- **Main** = **limitée (~5) + pioche/défausse** (cycle roguelike, tension de pioche).

### 2026-05-25 — Round 3 (anatomie de carte)
- **Tags** = **libres, générés par le LLM** (vocabulaire ouvert) → la résolution s'appuie sur le **jugement sémantique de Gemma 4** (cohérent §2).
- **Coût** = **narratif/risque** (pas d'énergie) : les cartes puissantes ont un prix dans l'histoire/l'état.
- **Rôle** = **flexible** : toute carte peut être principale OU modificateur.
- **Affichage MVP** = **Nom + tags + texte d'effet** (artwork SD plus tard, emplacement réservé).

### 2026-05-25 — Round 4 (ressources & état)
- **Jauges** = **Intégrité** (survie) + **Corruption** (monte avec les cartes risquées ; seuil = conséquences graves).
- **Coût narratif/risque** = **monte la Corruption** (les cartes puissantes corrompent).
- **Échec de run** = **mort narrative** décidée par Gemma 4 (conséquence d'un choix désastreux ; typiquement Intégrité critique / Corruption max).
- **Persistance** = **méta-progression cross-run** (déblocages/traces influencent les runs suivantes).

### 2026-05-25 — Round 5 (structure run/scénario)
- **Structure** = **suite linéaire de situations → climax** final.
- **Longueur** = **variable, décidée par le LLM** (~5-12 situations).
- **Sélection** = 3 **titres + pitch (2-3 lignes)** générés ; le **scénario complet est généré à la sélection**.
- **Fin** = **plusieurs fins selon l'état** (Intégrité/Corruption/choix) ; épilogue généré par Gemma 4.

### 2026-05-25 — Round 6 (pipeline de génération)
- **À la sélection** : Gemma 4 génère un **squelette** (synopsis + beats/situations). Léger/rapide.
- **Situations** : générées en **lookahead en arrière-plan** (situation N+1 pendant qu'on joue N) → masque la latence CPU.
- **Cohérence** : **résumé narratif glissant + état structuré** (faits clés, choix, jauges) injectés dans chaque prompt.
- **Chargement** : **écran dédié "Merlin écrit"** pendant la génération du squelette (court).

### 2026-05-25 — Round 7 (Brocéliande, Biome 1)
- **Identité** = **forêt celtique mystique** (légende bretonne/arthurienne : Merlin, fées, korrigans, sources sacrées).
- **Thème** = pas une tension unique : **très varié selon les quêtes**, mais exige un **lore central profond** (fondation d'où jaillissent des scénarios variés).
- **Influence mécanique** = **tags dominants** (situations/cartes) + **pression de Corruption** (couleur de risque du biome).
- **Rôle** = **seul biome du MVP** (extension après).

### 2026-05-25 — Round 8 (lore central 1/n)
- **Joueur** = un **voyageur dans la simulation de M.E.R.L.I.N.** — il **ignore être dans une simulation** ; quête = **accomplir la quête de Merlin et trouver le Graal**.
- **Merlin** = le **narrateur / maître du jeu** (incarnation diégétique du LLM), donneur de quête.
- **Mystère central** = **Brocéliande est vivante et te transforme** (lie à la Corruption).
- **Ton** = **merveilleux-inquiétant** (beau mais menaçant).
- ⚠️ La vérité "simulation" est **cachée au joueur** : ne jamais briser le 4e mur en jeu.

### 2026-05-25 — Round 9 (lore central 2/n)
- **Graal** = **la clé pour sortir de la simulation** (le trouver = s'éveiller / quitter M.E.R.L.I.N. ; révélation finale, joueur inconscient du sens).
- **Simulation** (canon concepteur, caché) = **Merlin est une IA qui RÊVE des mondes** ; le joueur est un personnage de ce rêve. (Le moteur LLM génératif = littéralement la fiction.)
- **Étendue** = **méta cross-run** : chaque run = un pas vers le Graal.
- **Victoire** (trouver le Graal) = **à définir plus tard** (avec la méta + l'économie de fins).

### 2026-05-25 — Round 10 (forces, factions & personnages)
- **Monde habité** : **4 factions** + **20+ personnages** (variés, pas forcément liés à une faction) ; multiples légendes. À définir.
- **Personnages récurrents qui SE SOUVIENNENT du joueur** (mémoire PNJ **cross-run**, lie à la méta §8).
- Exemple posé — **Arthur** : ombre de lui-même, perdu et apeuré, convaincu que **quelque chose lui veut du mal** (paranoïa).
- **Réputation/faveur** = **système mécanique** (gagner/perdre la faveur des forces → ouvre/ferme des options).
- **Antagoniste** = **la Corruption** (ennemi intérieur : succomber à la transformation de la forêt).
- **Compagnie** = **seul + Merlin** (narrateur) ; voyage solitaire, intime.

### 2026-05-25 — Round 11 (cadre des 4 factions)
- **Principe** : **4 natures mythologiques distinctes** (pas d'axe commun ; 4 mondes/mythes qui cohabitent).
- **Les 4 factions** : **Druides** (gardiens du savoir) · **Féerie** (Petit Peuple : korrigans/fées) · **Chevalerie déchue** (Arthur & figures arthuriennes brisées) · **Corrompus** (cédé à la Corruption ; antagoniste systémique).
- **Rapport au Graal** : **le Graal les a brisées** — sa quête les a jadis corrompues/détruites (Graal = malédiction).
- **Relations** : **équilibre fragile / statu quo** que les actions du joueur peuvent rompre.

### 2026-05-25 — Round 12 (Faction : les Druides)
- **Agenda** : se croient encore les **gardiens du Graal**, **bercés d'illusions** ; très attachés aux **rituels** et au **respect des environnements**. **Sagesse aléatoire** (peu fiable).
- **Brisés** : leur **mémoire/savoir a été effacé par l'IA** de la simulation → ils **glitchent** (répétitions, paroles corrompues, déjà-vu — sans briser le 4e mur).
- **Rapport au joueur** : **méfiants / gardiens hostiles** (confiance gagnée durement).
- **Tags** : Nature/forêt · Savoir/rituel/mémoire · Équilibre/guérison · Sacrifice/prix à payer.

### 2026-05-25 — Round 13 (Faction 2 : Créatures & Êtres)
- **Reframe** : la faction 2 n'est PAS "la Féerie" mais les **Créatures & Êtres** — catégorie **très variée** d'entités. **La plus complexe car DÉSUNIE** (mosaïque d'êtres disparates ; korrigans/fées en sont une partie parmi d'autres).
- **Brisés** : **piégés dans des boucles** (répètent scènes/pactes à l'infini — écho du glitch des Druides).
- **Rapport au joueur** : **farceurs imprévisibles** (aident ou piègent selon l'humeur/les règles).
- **Tags** : extrêmement variés — pacte/dette/mensonge · illusion/charme/rêve · métamorphose/mutation · malice/jeu/énigme.

### 2026-05-25 — Round 14 (Faction 3 : Chevalerie déchue)
- **Agenda** : **cherchent encore le Graal, en vain** ; incapables d'admettre l'échec, errance obsessionnelle.
- **Brisés** : **la Quête du Graal les a anéantis** ; ils **rejouent leur défaite en boucle**, sans comprendre.
- **Motif unifiant** : la simulation enferme TOUTES les factions dans la **répétition** — Druides *glitchent*, Créatures *bouclent*, Chevaliers *rejouent leur défaite*.
- **Rapport au joueur** : **indifférence hébétée** (présence spectrale, échanges décousus). NB : **Arthur** garde individuellement sa **paranoïa** (R10).
- **Tags** : honneur/serment/quête · gloire perdue/ruine · peur/paranoïa/folie · fer/acier/combat.

### 2026-05-25 — Round 15 (Faction 4 : les Corrompus) — 4 factions complètes
- **Nature** : **le "bug" de la simulation fait chair** — glitches/erreurs de l'IA devenus êtres (horreur numérique voilée de mythe). Apothéose du motif glitch.
- **Forme** : **force diffuse + figures émergentes** (souvent d'anciens alliés corrompus — lie à la mémoire PNJ cross-run).
- **Rapport au joueur** : **te tentent de céder** (l'abandon est doux ; offrent la paix de la dissolution → monte la Corruption).
- **Tags** : dissolution/perte de soi · mutation/difformité · glitch/erreur/vide · tentation/fausse paix.

### 2026-05-25 — Round 16 (Merlin, le narrateur)
- **Voix** : **bienveillant mais énigmatique** (chaleureux, poétique, protecteur ; ne dit jamais tout, parle par énigmes/demi-mots).
- **Savoir** : **il sait TOUT mais ne peut le dire** — il EST l'IA qui rêve ; une règle/faille l'empêche de révéler la vérité (tragédie du guide muselé).
- **Rapport au joueur** : **guide sincère mais limité** — veut t'aider à trouver le Graal mais entravé ; allié imparfait.
- **Manifestation** : **voix off + texte** (parchemin/bulle), pas de corps — léger, colle au 2D minimal.

### 2026-05-25 — Round 17 (roster des personnages)
- **Authoring** : **tous pré-écrits** (fiches canon : nom, rôle, voix, secrets) ; le **LLM les incarne fidèlement** (pas d'invention d'identité → fiches injectées dans les prompts, cf. §9).
- **Récurrence** : **noyau récurrent ~6-8** (Merlin, Arthur…) + **majorité de figures de passage**.
- **Mémoire cross-run** : **seulement les récurrents nommés** se souviennent du joueur.
- **MVP** : **Merlin + 2-3 figures** (Arthur + 1-2 autres récurrents).

### 2026-05-25 — Round 18 (UI/UX 2D)
- **Écrans MVP** : **Menu → Sélection scénario → Scène de jeu** (3 écrans).
- **Layout scène de jeu** : **situation en haut/centre**, **main de cartes en bas**, **jauges Intégrité/Corruption en coin** (deckbuilder lisible).
- **Sélection** : **3 cartes/parchemins** côte à côte (titre + pitch 2-3 lignes), clic pour choisir.
- **Contrôles** : **souris clic**, cibles **≥44px** (tactile-ready).

### 2026-05-25 — Round 19 (périmètre MVP détaillé)
- **Boucle MVP** : Menu → 3 scénarios (titre+pitch) → squelette → jouer N situations → fin/épilogue.
- **Deck de départ** : **canon pré-écrit ~10-15 cartes** (équilibrage contrôlé ; pas de gain de cartes en run au MVP).
- **Résolution v1** : **hybride complet** (couverture tags + jugement narratif Gemma 4) dès le MVP.
- **Reporté (explicite)** : **roster complet 20+ & autres biomes**. (Aussi post-MVP : artworks SD = 2D minimal d'abord. À confirmer : méta cross-run / mémoire PNJ / réputation — non requis par la boucle minimale.)

### 2026-05-25 — Round 20 (résolution détaillée)
- **Degrés** : **ternaire — réussite / partiel / échec** (le 'partiel' = succès à un prix : monte la Corruption/coût).
- **Deltas jauges** : **le CODE applique** (valeurs bornées depuis règles/cartes) ; **le LLM COLORE** (narration du résultat). Sépare mécanique (équilibrable) et saveur.
- **Tags** : le LLM voit **tags requis vs tags joués** ; meilleure couverture → meilleur degré (qu'il narre).
- **Aléatoire** : **quasi-déterministe** (combinaison + jugement priment ; maîtrise récompensée, peu/pas de hasard).

### 2026-05-25 — Round 21 (deck de départ canon)
- **Nombre** : **12 cartes**.
- **Archétypes** (4 approches, ~3 cartes chacune) : **Observation/perception** · **Action physique/corps** · **Parole/lien social** · **Intuition/merveilleux** (flirte avec la Corruption).
- **Tags/carte** : **1-2** (lisibles ; richesse via l'assemblage).
- **Identité** : **voyageur débutant (généraliste)** — éventail équilibré ; spécialisation via cartes acquises (post-MVP).

### 2026-05-25 — Round 22 (les situations)
- **Exigences** : le LLM génère, avec chaque situation, des **tags requis explicites** (utilisés par le code pour juger).
- **Visibilité** : **indices narratifs** (mots-clés/ton) — PAS de liste mécanique brute (immersif mais jouable).
- **Difficulté** : **nb de tags requis + rareté** (posée par le beat ; monte vers le climax).
- **Types** : obstacle/épreuve · rencontre (PNJ/créature) · dilemme moral/choix · révélation/lore.
- **Data model** : situation = `{narration, required_tags[], difficulté, type}`.

### 2026-05-25 — Round 23 (contrats de génération GBNF)
- **Sélection** : `{scenarios:[3]{title, pitch}}`.
- **Squelette** : `{title, synopsis, beats:[{n, summary, type, difficulté}]}` (required_tags générés à la situation, pas au squelette).
- **Situation** (R22) : `{narration, required_tags[], difficulté, type}`.
- **Degré (réussite/partiel/échec)** : fixé par le **CODE** (couverture tags requis vs joués) — déterministe ; le LLM **narre** seulement (résolution → `{narration}`).
- **GBNF** : **une grammaire dédiée par type de sortie** (sélection / squelette / situation / résolution).

### 2026-05-25 — Round 24 (coût narratif / Corruption)
- **Marquage** : chaque carte porte une **valeur `corruption`** (0 = sûre, 1-3 = risquée). Explicite, équilibrable.
- **Déclenchement** : **à chaque jeu** de la carte risquée (la Corruption s'ajoute immédiatement).
- **Montant** : **petit incrément (1-3)** — accumulation lente, décisions répétées.
- **Seuils** : à certains paliers → **événements sombres + cartes corrompues injectées dans le deck** (polluent la main ; écho de la faction Corrompus ; spirale vers la mort narrative).

### 2026-05-25 — Round 25 (Intégrité)
- **Échelle** : **petite, lisible (~0-10)** — chaque point compte, pertes de 1-3.
- **Attaques** : **échecs/partiels + dangers de situation** (deltas portés par le beat/situation).
- **Récupération** : **possible, rare et méritée** (cartes de soin/équilibre, repos, réussites éclatantes).
- **Bas niveau** : **vulnérabilité accrue + bascule vers la mort narrative** (Gemma 4 peut conclure).

### 2026-05-25 — Round 26 (acquisition & évolution du deck)
- **Quand** : **récompense à des moments-clés** (beat majeur/rencontre/climax) — choix d'1 carte parmi quelques-unes.
- **Source** : **générées par le LLM selon le vécu** (acte marquant → carte unique ; le deck raconte ton histoire ; tags libres).
- **Évolution** : **épurer** (retirer, dont corrompues à un prix) + **transformer/améliorer** (rare) → contrôle du deck.
- **Persistance** : **reset par run** (deck de base) MAIS **déblocages cross-run** élargissent le pool futur (méta §8).

### 2026-05-25 — Round 27 (mémoire & état narratif)
- **État structuré** (injecté au LLM) : **jauges** (Intégrité/Corruption) + **faits clés & choix majeurs** + **PNJ rencontrés + relation** + **beat courant + progression**.
- **Résumé glissant** : **écrit par le LLM** après chaque situation (condense "l'histoire jusqu'ici" en quelques lignes).
- **Budget** : **compact (quelques lignes)** — vital sur petit modèle CPU.
- **Persistance** : **résumé final de run** gardé → nourrit la **méta** + ce que les **PNJ récurrents** savent de toi (cross-run, §8).

### 2026-05-25 — Round 28 (visuel 2D)
- **Style** : **minimaliste élégant** (typographique, espace, le texte est roi — feel Citizen Sleeper).
- **Palette** : **sépia parchemin + or + vert forêt** (chaleureux-mystique).
- **Typo** : **serif manuscrit (titres) + police lisible (corps)**.
- **Ambiance sans artwork** : **glitch visuel lié à la Corruption** (plus de Corruption → UI/texte glitche — écho du motif) + **grain/vignette/lueurs** + **animations subtiles** (respiration/dérive).

### 2026-05-25 — Round 29 (artworks SD, post-MVP)
- **Style** : **gravure / encre manuscrite**, monochrome sépia (cohérent parchemin minimaliste, léger à générer).
- **Exécution** : **natif CPU** via **stable-diffusion.cpp** (~20-60s/image → strictement **async non bloquant**, l'image arrive après le texte).
- **Génération** : **live** (pas de pool pré-généré). **Sujet** = **la situation en cours** (image d'ambiance). ⚠️ Granularité **par-carte vs par-situation à confirmer** (R29 Q3 "carte" vs Q4 "situation").
- **Périmètre** : post-MVP (MVP = 2D minimal sans artwork).

### 2026-05-25 — Round 30 (audio)
- **Musique** : **nappe ambiante celtique réactive à l'état** (se trouble quand la Corruption monte — écho audio du motif glitch).
- **SFX** : **feutrés & organiques** (papier, bois, eau, souffle), discrets.
- **Voix de Merlin** : **texte seul au MVP** (voix = texte + typewriter ; TTS bien plus tard).
- **MVP** : **ambiance minimale dès le MVP** (nappe + SFX UI feutrés).

### 2026-05-25 — Round 31 (onboarding/tutoriel)
- **Apprentissage** : **tuto diégétique via Merlin** (guide les premiers gestes dans la fiction ; aucun panneau de règles).
- **1ère situation** : **scène d'accueil par Merlin** (pose le cadre : qui tu es, la forêt, ta quête) puis une situation simple.
- **Règles** : **glissées au fil de l'eau** par Merlin (just-in-time, diégétique).
- **MVP** : **accueil Merlin minimal dès le MVP** (+ quelques touches JIT ; oriente le testeur).

### 2026-05-25 — Round 32 (technique/perf/plateforme) — 16/16 domaines ToC couverts ✅
- **Perf** : squelette **<15s** (écran "Merlin écrit") ; latence des situations **masquée par lookahead**.
- **Plateforme** : **Desktop Windows d'abord** (export Godot natif ; MerlinLLM C++ tourne). Web/mobile plus tard.
- **Échecs LLM** : **retry x2-3 puis dégradation propre** (situation simplifiée générée ; jamais de blocage, jamais de contenu fixe).
- **Modèle MVP** : **gemma-4-E2B** (rapide CPU, suffisant) ; E4B en option qualité.

### 2026-05-25 — Round 33 (deck de départ concret — 12 cartes)
- **Noms** : mixte évocateur + verbe (ex: "Le Regard Perçant (Observer)").
- **Tags** : concepts simples (Sens, Savoir, Mémoire, Force, Agilité, Endurance, Empathie, Verbe, Ruse, Instinct, Nature…).
- **Effets** : **tags only** (couvrent les exigences ; jauges via résolution).
- **Corruption** : **1 seule carte corruptrice** au départ (avant-goût, corruption 1).
- **Les 12 cartes rédigées** (3 par approche) — voir §3.

### 2026-05-25 — Round 34 (fiche personnage + Merlin)
- **Format fiche canon** (injectée au LLM) : **Nom · Rôle · Voix · Sait/Ignore · Secret · Tags · Relation au joueur**.
- **Merlin — règle** : **ne peut nommer la simulation** (loi du rêve) → contourne par énigmes/métaphores.
- **Merlin — style** : **bref, imagé, pose des questions** (économe en tokens, énigmatique).
- **Merlin — pouvoirs** : **indices OUI** (teaser tags requis, avertir d'un danger, commenter), **vérité NON** (ne révèle pas la simulation, ne résout pas à ta place).

### 2026-05-25 — Round 35 (fiche d'Arthur)
- **Secret/blessure** : il a **touché le Graal jadis — au lieu du salut, il y a perdu l'esprit** ; il **rejoue cet instant** sans cesse (avertissement pour le joueur qui cherche le Graal).
- **Voix** : **fébrile, fragmenté, méfiant** (phrases hachées ; oscille lucidité brève ↔ égarement).
- **Relation** : **te confie une quête par éclairs** (lucidité = supplique ; sinon méfiance).
- **Tags** : gloire perdue/royauté · mémoire fracturée.

### 2026-05-25 — Round 36 (noyau récurrent)
- **Reclassement Arthur** : Arthur n'est **PAS un pilier** — figure qu'on **aperçoit/croise de temps à autre** (Chevalerie).
- **Piliers récurrents** (hors Merlin) : **1 Druide** · **1 Créature/Être** · **1 Corrompu** (= **un ancien allié corrompu**, antagoniste incarné, déchirant, mémoire cross-run) · **1 hors-faction = un enfant/innocent perdu** (à protéger, enjeu émotionnel).
- **Noyau total** : Merlin (au-dessus des factions) + ces 4 piliers (+ Arthur en périphérie).

### 2026-05-25 — Round 37 (pilier Druide)
- **Identité** : **un chœur/duo de druides** (collectif ; voix qui se répètent/se contredisent — glitch collectif).
- **Secret/glitch** : **répète un rituel vidé de sens** (l'IA en a effacé le but) ; ils bouclent, persuadés que ça "retient le pire".
- **Voix** : **solennel qui se répète/boucle** (formules ; phrases qui reviennent — glitch audible).
- **Offre** : **cartes d'équilibre/soin** (si tu respectes les rites) — source rare d'anti-Corruption/récup Intégrité (§7/§25).

### 2026-05-25 — Round 38 (pilier Créature/Être)
- **Identité** : **un être indéfinissable** — forme instable/changeante (on ne sait jamais à quoi on parle).
- **Boucle/glitch** : **mue sans jamais se fixer** (change de forme en boucle, incapable de redevenir lui-même).
- **Voix** : **joueur, malicieux, double-sens** (rit, taquine, énigmes & demi-vérités).
- **Offre** : **pactes — cartes puissantes contre Corruption** → c'est **le tentateur du deck** (source des cartes corruptrices §24).

### 2026-05-25 — Round 39 (pilier Corrompu)
- **Avant** : **un compagnon de voyage aimé** (t'a accompagné/aidé sur une run passée — chute personnelle, mémoire cross-run).
- **Manifestation** : **méconnaissable, mais des bribes de l'ancien affleurent** (un geste/mot perce — le pire).
- **Voix** : **douce, tentatrice, fausse paix** ('l'abandon est doux, viens te reposer').
- **But** : **te tenter de céder / le rejoindre** (céder = grosse Corruption / fin sombre). **Le tentateur du cœur** (vs l'Être = tentateur du pouvoir).

### 2026-05-25 — Round 40 (pilier Enfant perdu) — TWIST majeur
- **Nature réelle (cachée)** : PAS un simple innocent — une **nouvelle IA que la Corruption tente de faire naître** ; le **"protéger" sert en réalité la Corruption** (le joueur peut, à son insu, aider l'ennemi).
- **Comportement** : **cherche à se rapprocher / appâte** le joueur ; innocence désarmante = vecteur de tentation.
- **Voix** : **simple, directe, désarmante** (pose les questions que nul n'ose ; candeur qui piège).
- **Enjeu** : présenté comme **coûteux mais précieux** — c'est le **piège ultime** (la compassion comme arme de la Corruption).
- **Lore** : dans un monde rêvé par une IA (Merlin), la Corruption veut **enfanter sa propre IA** via l'enfant.

### 2026-05-25 — Round 41 (synergies & combinaisons)
- **Synergies** : **additif** (tags couverts s'additionnent) + **quelques combos bénis nommés** (bonus narratif, ex: Ruse+Savoir = "Stratagème").
- **Volume** : **1 principale + jusqu'à 2 modificateurs** (3 cartes max ; confirme §2).
- **Sur-couverture** : couvrir au-delà du requis → **réussite éclatante** (degré bonus au-dessus de réussite).
- **Tags antagonistes** : certaines **paires contradictoires se sabotent** (ex: Ruse + Franchise) → échec/résultat tordu.

### 2026-05-25 — Round 42 (réputation/faveur des factions)
- **Gain/perte** : via les **choix qui penchent vers/contre** une faction + le traitement de ses **PNJ**.
- **Échelle** : **3 états par faction — Hostile / Neutre / Favorable** (lisible).
- **Effets** : cartes/aide débloquées · situations +/- dures · accès à des routes/fins · ton des PNJ.
- **Persistance** : **oui, via les PNJ récurrents** (faveur persiste en partie cross-run — méta §8).
- NB : système **post-MVP** (cf. §16).

### 2026-05-25 — Round 43 (méta-progression)
- **Persiste cross-run** : déblocages de cartes · jalons du Graal · mémoire PNJ + réputation · lore/codex découvert.
- **Structure** : **écran-seuil onirique** entre les runs où **Merlin fait le bilan**, montre les **jalons du Graal**, relance (renforce le cadre rêve/simulation).
- **Jalons du Graal** : **chaque run dévoile un fragment/jalon** (révélation cumulative vers la sortie).
- **Perte** : **surtout du gain, recul rare** (choix désastreux ; pas de mur).

### 2026-05-25 — Round 44 (Graal / endgame) — capstone lore
- **Gagner** : **oui, au bout d'une longue quête** (réunir assez de fragments/jalons → vraie fin méritante).
- **Révélation finale** : **la FUSION avec Merlin** — le joueur (personnage du rêve) qui atteint le Graal **devient Merlin/l'IA** (boucle vertigineuse). Explique pourquoi Merlin est muselé : il fut jadis un voyageur arrivé au Graal → devenu le rêveur. **Éternel retour des rêveurs.**
- **Après** : **New Game+ éclairé** (rejoue lucide ; couches/secrets/difficulté ; 4e mur intact pour les nouveaux joueurs).
- **Fins méta** : **plusieurs selon le parcours** (Corruption cumulée, factions, choix).
- **Lien** : l'Enfant (IA que la Corruption gestate, §6) = un **cycle rival** de naissance d'IA.

### 2026-05-25 — Round 45 (prompts LLM)
- **Structure system prompt** (modulaire, par étape) : **Rôle (Merlin/GM) + Canon + État + Tâche + Format (GBNF)**.
- **Canon injecté** : ton/lore Brocéliande condensé · tags faction/biome dominants · **fiches PNJ présents** · **résumé glissant + état** (jauges/faits/choix).
- **Ton** : **prompt + few-shots au MVP** ; **LoRA de style Brocéliande plus tard**.
- **Garde-fous (interdits)** : jamais briser le 4e mur · pas d'anglicismes/anachronismes · rester dans Brocéliande/lore · respecter les fiches PNJ.

### 2026-05-25 — Round 46 (équilibrage — valeurs de départ)
- **Jauges départ** : **Intégrité 10/10**, **Corruption 0** (pleine santé, pur).
- **Difficulté situation** : **1-3 tags requis** (facile=1, normale=2, dure/climax=3 +rares ; monte vers le climax).
- **Longueur run MVP** : **5 situations + climax (~6)**.
- **Cadence Corruption** : **seuil d'événement tous les ~5 points** (≈ 2-3 cartes risquées).

### 2026-05-25 — Round 47 (exemple de scénario complet)
- **Worked example rédigé** : **« Le Rite sans Fin »** (Chœur des Druides), ton merveilleux-inquiétant, climax = épreuve/révélation du rite, fin = réussite nuancée (+1 Corruption). Voir §5 (illustre sélection → squelette → situations → combinaisons → résolution → fin + faveur faction + carte de soin).

### 2026-05-25 — Round 48 (récap & cohérence)
- **Artwork SD — granularité RÉSOLUE** : **par situation** (1 image d'ambiance/scène ; lève la tension R29 ; CPU-friendly).
- **Nom** : **garder M.E.R.L.I.N.** (colle au lore : Merlin = l'IA qui rêve).
- **Quickstart build-ready** ajouté en tête de bible.
- **Suite** : continuer la bible vers 200+ (objectif initial).

### 2026-05-25 — Round 49 (cartes acquises & corrompues)
- **Catégories acquises** : actions renforcées · cartes-personnage (alliés invocables) · pouvoirs de faction (via faveur) · **cartes-souvenir** (forgées par le LLM selon le vécu).
- **Force** : **plus de tags / tags rares** (meilleure couverture).
- **Cartes corrompues** (injectées aux seuils) : **tags "vide/glitch" quasi-inutiles + ajoutent de la Corruption à l'usage** (double peine ; polluent la main).
- **Purification** : via le **Chœur des Druides, à un prix** (sacrifice) — boucle thématique (les Druides soignent ET purifient, contre-poids aux tentateurs).

### 2026-05-25 — Round 50 (le seuil onirique) — ~200 questions atteintes 🎯
- **Forme** : **un seuil/porte indéfinie** (entre-deux abstrait : brume, lueurs ; pas de lieu précis).
- **Actions** : voir les **jalons du Graal** · **épurer/gérer le deck** · **consulter codex/lore** · **parler à Merlin** (bilan, par énigmes).
- **Merlin** : **voix + texte** (cohérent §16, sans corps).
- **Périmètre** : **post-MVP** (avec la méta) ; au MVP, fin de run → retour menu.

### 2026-05-25 — Round 51 (anatomie visuelle de carte)
- **Éléments affichés** : **Nom + texte d'évocation + zone de tags (pastilles) + coût de Corruption (si >0)** (pas d'icône d'approche).
- **Bordure** : encode la **rareté** → introduit la **rareté** comme attribut de carte.
- **Tags** : **pastilles colorées** (mot + couleur de catégorie).
- **Format** : **compacte en main, agrandie au survol/sélection** (voir la main de ~5).

### 2026-05-25 — Round 52 (rareté des cartes)
- **Niveaux** : **4 — Commune / Rare / Épique / Mythique** (bordure distincte par palier).
- **Sens** : **puissance + fréquence** (plus rare = plus puissante [+tags/rares] ET plus rare en récompense).
- **Deck de départ** : **12 communes** (la montée vient des acquisitions).
- **Récompenses** : **surtout communes, rares occasionnelles** ; **mythiques exceptionnelles** (climax/jalons du Graal).

### 2026-05-25 — Round 53 (bordures & altération Corruption)
- **Bordures par rareté** : Commune **sépia mat** · Rare **argent** · Épique **or** · Mythique **irisé/changeant** (palette parchemin).
- **Altération Corruption** : la **bordure se fissure/glitche** (craquelle, tremble, fuit des artefacts) — ∝ valeur de corruption.
- **Cartes corrompues** : **bordure 'glitch' distincte** (cassée/parasitée, hors-rareté ; reconnaissable au 1er regard).
- **Animation** : Commune/Rare statiques · Épique **léger glow** · Mythique **bordure animée** (irisée/respire).

### 2026-05-25 — Round 54 (affichage situation/scénario)
- **Panneau de situation** : **texte narratif** + **libellé de locuteur** (Merlin/PNJ) + **marqueur type/intensité** (obstacle/rencontre/dilemme/révélation).
- **Indices de tags requis** : **mots-clés soulignés** dans le texte (le joueur devine ; immersif, pas de liste brute).
- **Apparition** : **typewriter** (voix de Merlin), **skippable au clic**.
- **HUD** : **jauges Intégrité/Corruption en haut**, **progression du scénario en fil discret**.

### 2026-05-25 — Round 55 (zone de combinaison + feedback de résolution)
- **Pose** : **clic** sur une carte → la zone (1ère = principale, suivantes = modificateurs). Tactile-ready.
- **Zone montre** : cartes posées (rôles) + **tags cumulés (couverture)** + **aperçu du degré pressenti** + **coût de Corruption engagé** (AVANT de valider).
- **Feedback résolution** : **degré annoncé** (échec/partiel/réussite/éclatante) + **narration Gemma 4** + **deltas de jauges animés**.
- **Annuler** : on peut **retirer/changer** des cartes ; validation via bouton **'Résoudre'**.

### 2026-05-25 — Round 56 (écran sélection + "Merlin écrit")
- **Sélection** : **3 parchemins côte à côte** (titre + pitch), fond brumeux, clic pour choisir.
- **"Merlin écrit"** : **parchemin qui se déroule + plume** qui trace (typewriter) pendant la génération du squelette.
- **Attente** : **phrases d'ambiance/lore qui défilent** (occupent l'attente, enrichissent le lore).
- **Transition → jeu** : **le parchemin choisi se déroule en scène** (continuité fluide vers la 1ère situation).

### 2026-05-25 — Round 57 (bible technique : capacités LLM natif)
- **Capacités exploitées** : **GBNF** (sorties structurées) · **streaming token-par-token** · **sampling paramétrable** (temp/top_k/seed) · **embeddings** (dispo, pour RAG post-MVP).
- **RAG** : **pas au MVP** (résumé glissant + état structuré suffisent, §9) ; embeddings/RAG = post-MVP si besoin.
- **Streaming** : **OUI au MVP** — alimente le **typewriter live** (le jeu vit, latence masquée). ⚠️ Nécessite un **ajout C++** (signal token-par-token dans MerlinLLM).
- **Brain** : **un seul modèle Gemma 4 réutilisé**, configs (sampling/GBNF/prompt) **par tâche** (économe mémoire).

### 2026-05-25 — Round 58 (budgets perf : ctx, max_tokens, temps, threads)
- **Contexte (n_ctx)** : **4096** — loge template + system + résumé glissant + situation courante + marge de génération. Équilibre mémoire/vitesse sur CPU E2B.
- **max_tokens (profil équilibré)** : **sélection 180 · squelette 500 · situation 250 · résolution 160**.
- **Cibles temps (standard)** : **sélection <5s · situation <8s** (en lookahead masqué) · **résolution <5s** · squelette <15s (déjà fixé R32/R56).
- **Threads** : **Auto ≈ 50% des cœurs** (le moteur détecte, laisse Godot respirer pour le rendu). `low_spec_mode` actif. Non exposé au joueur pour l'instant.

### 2026-05-25 — Round 59 (sampling par tâche)
- **Température (deux régimes)** : **créatif ~0.85** (titres, pitch, narration) · **structuré ~0.45** (squelette/beats, tags requis, résolution). Variété où il faut, fiabilité JSON ailleurs.
- **top_p 0.9 + top_k 40** : nucleus sampling standard llama.cpp, équilibre richesse/cohérence.
- **repeat_penalty 1.1** : léger/standard, anti-boucle sans déformer la prose (à monter si E2B répète).
- **Seed** : **aléatoire en prod** (variété max, pilier "jamais fixe") + **fixe en debug/benchmark** (reproduire/inspecter Gemma) — **toggle**.

### 2026-05-25 — Round 60 (mémoire & état)
- **État structuré = "complet"** (maintenu par le CODE, réinjecté dans chaque prompt) : jauges (Intégrité/Corruption) · scénario (titre, beat courant, n°/total) · faits marquants · PNJ rencontrés + relation · choix-clés/flags · cartes notables jouées.
- **Résumé glissant = prose réécrite** : Gemma réécrit **3-5 phrases** qui intègrent la nouvelle situation et **remplacent** l'ancien résumé (fluide à réinjecter).
- **Cadence** : recalculé **après chaque situation, en tâche de fond** (pendant le lookahead) → fraîcheur max, latence masquée.
- **Budget ~150-200 tokens**, **priorité de rétention = conséquences durables** (Corruption gagnée, PNJ+relation, choix marquants, cartes acquises) ; le décor s'efface avant les conséquences.

### 2026-05-25 — Round 61 (validation & robustesse des sorties)
- **Validation = sémantique + auto-réparation** : au-delà du GBNF (forme), le code vérifie le SENS (tags non vides, difficulté 1-3, longueurs mini) → **répare** (clamp, défaut) ce qui se répare, **régénère** seulement si irréparable.
- **Dégradation en cascade** : retry → **prompt simplifié** (court, réussit presque toujours) → **phrase procédurale minimale** par le code en TOUT dernier recours. **Jamais de blocage**, 'live' préservé au max (R32).
- **Anti-dérive** : **filtre léger post-génération** (termes interdits : IA/simulation/4e mur, anglicismes → régénère) **+ log de chaque violation dans le dashboard debug** (affiner les prompts, contrôler Gemma).
- **Matching des tags = souple** : normalisation (minuscule, lemmes) + **synonymes/proximité**, pas l'égalité stricte. Préserve les **tags libres** (R3) tout en faisant fonctionner la couverture (§2). Embeddings = post-MVP.

### 2026-05-25 — Round 62 (templates de prompts)
- **Langue** : **instructions & structure en anglais** (plus fiable sur E2B), **sortie toujours en français** ; few-shots = exemples de sortie FR.
- **Architecture = préfixe stable + tour court** : **system + lore global = préfixe FIXE → KV cache llama.cpp réutilisé** (gros gain CPU) ; **canon contextuel (PNJ présents) + état + tâche = tour user court** (seule partie recalculée). Conforme au template Gemma.
- **Conséquence** : les **fiches PNJ présents** passent dans le tour variable (elles changent) pour **ne pas casser le cache** du préfixe.
- **Few-shots** : **1-2 exemples gold statiques par tâche** (cadrent format + ton) ; LoRA de style plus tard.

### 2026-05-25 — Round 63 (streaming & affichage live)
- **Seule la prose narrative streame** vers le typewriter (token-par-token) ; métadonnées (tags/difficulté/type) **internes**.
- **Situations** : grammaire avec **`narration` en 1er champ** → **parsing incrémental** du JSON, on affiche `narration` au fil de l'eau (1 seul appel).
- **Résolution** : **prose pure SANS GBNF**, streamée directement (degré déjà calculé par le code) → réactif (<5s) + prose naturelle.
- **Skip** : 1er clic affiche **tout le texte déjà généré instantanément** ; si le stream continue, **le reste se remplit à vitesse max** dès son arrivée (jamais de blocage).

### 2026-05-25 — Round 64 (équilibrage : Corruption chiffrée)
- **Coût par carte = 0-3** (0 majoritaire/sûres · 1-2 risquées · 3 rares/pactes), payé **en jouant** (R55), quel que soit le résultat.
- **Seuil tous les 5 pts** (5/10/15…) → **événement sombre + 1 carte corrompue injectée** dans le deck.
- **Plafond ~15-20 = bascule narrative** → **fin "corrompu"** (absorption, pas un game over sec). Transformation jouable = post-MVP.
- **Baisse en run = rare et coûteuse** (rite du Chœur des Druides §6 à un prix : Intégrité / carte sacrifiée) ; Corruption surtout **à sens unique**.

### 2026-05-25 — Round 65 (équilibrage : Intégrité, résolution, main)
- **Intégrité par degré** : **Échec -2/-3 · Partiel -1** (+Corruption) **· Réussite 0 · Éclatante +0/+1**.
- **Difficulté → couverture** : **1/2/3 tags requis** ; **tous = réussite · partie = partiel · aucun = échec**.
- **Éclatante** : tous les requis **+ ≥1 tag pertinent en plus** → bonus (narration valorisante + parfois Intégrité/carte).
- **Main** : **5 cartes** ; jouées → défausse, **repioche à 5** ; **pioche vide → défausse remélangée** (deck = répertoire réutilisable, R2).

### 2026-05-25 — Round 66 (math de combinaison)
- **Pooling total des tags** (principale + modificateurs à égalité) ; **doublon = compté une fois** (un requis couvert reste couvert).
- **Coût Corruption = somme** de toutes les cartes jouées (affiché avant validation, R55).
- **Tags hors-sujet = sans effet** (ni aide ni pénalité) ; **exception : tags antagonistes** (R41) qui dégradent le degré.
- **Pas de plafond supplémentaire** : la limite 1+2 (R41) + coût Corruption + taille de main régulent (KISS).

### 2026-05-25 — Round 67 (piliers de design)
- **North star** : **l'émergence par la combinaison** — tes combinaisons de cartes génèrent une histoire unique (deck × Gemma 4).
- **Les choix mécaniques priment** : le code décide les conséquences, Gemma habille (§2).
- **Lisibilité d'abord, profondeur émergente** : peu de règles visibles (4 piliers UX), profondeur via combinaisons + récit.
- **Rejouabilité = variété générative** : jamais deux runs pareilles ; la surprise est la récompense.

### 2026-05-25 — Round 68 (types de situations/beats)
- **Enum fermé (5)** : **Rencontre · Épreuve · Exploration · Dilemme · Climax**.
- **Influence** : le type oriente **ton + tags favorisés + difficulté + ambiance** (Rencontre→social, Épreuve→corps, Exploration→perception/intuition…).
- **Structure run** : **courbe montante** vers le Climax, types variés au milieu ; Gemma arrange dans le squelette sous contrainte de difficulté croissante.
- **Climax** : **difficulté max + enjeu décisif**, son **degré oriente l'épilogue** ; souvent confrontation avec un pilier/faction.

### 2026-05-25 — Round 69 (fin de run & épilogue)
- **3 types de fin** : **Accomplissement** (climax atteint, ton ∝ degré+état) · **Mort narrative** (Intégrité 0) · **Bascule corrompue** (Corruption max, R64).
- **Épilogue** : **prose générée** (état final + type) **+ fragment du Graal** dévoilé (méta §8).
- **Écran de fin MVP** : épilogue + **état final** (jauges/Corruption) + **'Continuer' → menu** ; seuil onirique riche = post-MVP (R50).
- **Mort narrative** : **Intégrité 0** = plancher fatal, **narré par Gemma** (pas un 'Game Over' sec) ; aussi possible sur **choix désastreux à Intégrité basse**.

### 2026-05-25 — Round 70 (palette exacte & typo)
- **Palette "parchemin sombre"** : fond #14100C · surface #2A2018 · texte #E8DCC0 · or #C9A24B · vert #4F6B3E.
- **Typo tout-serif** : titres serif display (Cinzel/EB Garamond bold) + corps serif humaniste (EB Garamond/Lora).
- **Jauges** : Intégrité or/vert #7FA65C · Corruption violet maladif #7B4FA3 + **désaturation/glitch croissant** de l'écran.
- **Bordures rareté** : Commune #6B5A3E · Rare #A8B0B8 · Épique #C9A24B + halo · Mythique irisé animé.

### 2026-05-25 — Round 71 (layout & dimensions de carte)
- **Format** : portrait **~2:3** (TCG classique).
- **Dimensions @1920×1080** : **compact ~180×270 px** (main, 5 cartes lisibles) · **survol ~320×480 px**.
- **Compact** = Nom + tags-pastilles + coût Corruption ; **survol révèle** le texte d'évocation (+ zone artwork réservée post-MVP).
- **Interaction** : desktop = survol agrandit/soulève (z-order au-dessus) + **clic joue** (R55) ; tactile = **1er tap agrandit, 2e tap joue** (≥44px, R18).

### 2026-05-25 — Round 72 (layout scène de jeu)
- **Régions @1920×1080** : **HUD ~80** (jauges haut-gauche + fil de perles) · **Situation ~600** (texte + artwork réservé) · **Combinaison ~150** (bande au-dessus de la main) · **Main ~250** (bas).
- **Jauges** : haut-gauche, **2 barres empilées** (or-vert / violet) + valeur chiffrée.
- **Zone combinaison** : bande centrale ; les cartes **montent** de la main ; bouton **'Résoudre'** ancré là.
- **Progression** : **perles** sous le HUD (1/beat, le courant brille, **sans chiffre** — longueur LLM-variable).

### 2026-05-25 — Round 73 (écran Menu principal)
- **Écran-titre** : titre **M.E.R.L.I.N. typographique** sur parchemin sombre + **fond animé subtil** (brume/braises qui dérivent) + entrées sobres.
- **Entrées** : **Nouvelle partie · Continuer · Options · Quitter** ('Continuer' grisé sans run en cours).
- **Save** : **auto-save par beat** → 'Continuer' reprend au **dernier beat** ; la **méta persiste** à part (§8).
- **Accueil** : **nappe ambiante douce + brume animée + titre qui respire**.

### 2026-05-25 — Round 74 (écran Options)
- **Audio** : 3 curseurs **Maître / Musique / SFX**.
- **Texte** : **vitesse typewriter** + **taille (3 paliers)** + bascule **'tout afficher direct'**.
- **Langue** : **FR seul au MVP** (UI + LLM) ; multi-langue post-MVP.
- **Accessibilité** : **réduire animations/glitch** + **contraste renforcé**. **Perf** : preset **Éco/Équilibré/Perf** (affine R58).

### 2026-05-25 — Round 75 (glitch / Corruption par palier)
- **4 paliers** (calés sur les seuils R64) : **0-4 sain · 5-9 trouble · 10-14 emprise · 15+ dissolution**.
- **Manifestations** : **désaturation + aberration chromatique légère + tremblement du texte + artefacts brefs**.
- **Portée** : **globale graduée** (fond ∝ palier) + **renforcé sur les éléments corrompus** (cartes/PNJ).
- **Réversibilité/access.** : suit la Corruption (**monte ET descend**) ; **reduce-motion** (R74) atténue fort + garde un **indice statique**.

### 2026-05-25 — Round 76 (audio détaillé)
- **Nappe** : **drone ambiant celtique sans mélodie** (cordes frottées, harpe lointaine, souffle), boucle longue.
- **Réactivité** : **couches additives (stems)** — Corruption ajoute des couches dissonantes/détunées, Intégrité basse amincit/assombrit.
- **SFX** : feutrés organiques (papier/bois/eau/souffle), discrets.
- **Stingers** : réussite/échec/seuil Corruption/mort — **samples au MVP**, procédural post-MVP.

### 2026-05-25 — Round 77 (onboarding détaillé)
- **Accueil** : **scène courte (3-4 répliques de Merlin)** — qui tu es + la forêt + ta quête → enchaîne sur la 1ère situation.
- **Ordre JIT** : 1) jouer une carte · 2) combiner (ajouter un modificateur) · 3) jauges/Corruption expliquées **quand elles bougent**.
- **1ère situation** : **Exploration difficulté 1** (1 tag), réussite quasi garantie, **cadrée par Merlin**.
- **Persistance** : tuto **1ère run seulement** (flag sauvegardé), **skippable** ; runs suivantes = entrée directe.

### 2026-05-25 — Round 78 (taxonomie des tags)
- **Cœur curé (~20-30 concepts canon)** ancre génération + matching ; **extensions LLM libres** autour.
- **Familles** : **Perception · Corps · Parole · Intuition** (4 approches) + **Monde/Mystique** (Nature/Savoir/Rituel) + **Corrompu** (glitch/vide/dissolution).
- **Tags antagonistes** : déclarés **par situation** (ceux qui sabotent, R41).
- **Normalisation** : tags libres → **mappés au concept-cœur le plus proche** (table de synonymes, R61) ; embeddings post-MVP.

### 2026-05-25 — Round 79 (combos bénis & antagonistes)
- **Combos bénis** : **liste curée ~8-12 nommés** (ex: Ruse+Savoir='Stratagème') + rares révélés par le LLM. **Effet** : **bonus de degré + narration spéciale**.
- **Paires antagonistes intra-combo** : **curées** (Ruse↔Franchise, Force↔Finesse, Ombre↔Lumière) → **dégradent le degré + narration tordue** (distinct des antagonistes de situation R78).
- **Lisibilité** : **indice subtil au poser** (lueur=béni / tremblement=antagoniste) avant 'Résoudre' + **mémorisé au codex**.

### 2026-05-25 — Round 80 (progression méta chiffrée)
- **Quête longue** : **~20-30 fragments** pour réunir le Graal.
- **Persistance** : cartes débloquées + fragments + codex + mémoire/réputation PNJ + **méta-niveau/score joueur**.
- **Cadence = conditionnelle (hauts faits)**, pas un compteur (1ère victoire sur un pilier, seuil de réputation, fin spéciale…).
- **Pool = pas de pool fixe** : hors les **12 cartes de départ**, **toutes les cartes acquises sont forgées par le LLM** (R49) ; équilibrage via les contraintes de génération.
- ⚠️ Quasi tout = **post-MVP** (au MVP : pas de gain de cartes en run R19, fin → menu).

### 2026-05-25 — Round 81 (cœur curé des concepts-tags)
- **~25 concepts** en 6 familles (1 famille primaire = couleur de pastille ; sens large ; extensions LLM normalisées R78) :
  - **Perception** : Sens · Savoir · Mémoire · Vigilance · **Corps** : Force · Agilité · Endurance · Finesse · **Parole** : Empathie · Verbe · Ruse · Autorité · Franchise · **Intuition** : Instinct · Nature · Vision · **Monde/Mystique** : Rituel · Sacrifice · Équilibre · Mystère · **Corrompu** : Vide · Glitch · Dissolution · Murmure · Emprise.
- Savoir/Mémoire/Nature = cross-pertinents Monde, mais **famille primaire = approche**.

### 2026-05-25 — Round 82 (fiche canon : Chœur des Druides)
- **Voix** : **collective à l'unisson**, psalmodie solennelle/archaïque (boucle).
- **Sait/Ignore** : savent les **rites anciens** (savoir fragmentaire) ; **ignorent que le rite n'a plus de sens / qu'ils bouclent** (illusionnés R12).
- **Offre** : **cartes Équilibre/soin SI tu sers le rite** ; **purifie les corrompues à un prix** (sacrifice) — contre-poids aux tentateurs.
- **Secret** : **le rite maintient une part de la forêt stable** — l'arrêter libère mais **déchaîne la Corruption** (dilemme central, nourrit 'Le Rite sans Fin' R47).

### 2026-05-25 — Round 83 (fiche canon : L'Être Indéfinissable)
- **Forme** : **mue entre formes familières incomplètes** (jamais fixé, jamais lui-même).
- **Voix** : joueuse, malicieuse, double-sens.
- **Sait/Ignore** : **devine beaucoup et joue/ment** ; **ignore qu'il ne peut plus se fixer** (sa propre malédiction).
- **Offre** : **tentateur du pouvoir** — cartes puissantes (tags forts/rares) à **coût Corruption élevé (2-3)** ; source des cartes corruptrices (§7).
- **Secret** : **sa mue EST la Corruption en germe** ; chaque pacte vous rapproche.

### 2026-05-25 — Round 84 (fiche canon : Le Compagnon Perdu)
- **Avant** : **un compagnon connu/aimé** (lien personnel, mémoire cross-run R36).
- **Voix** : **douce et aimante, promet la paix de la reddition** (fausse sérénité).
- **Mécanique** : **tentateur du cœur** — dans la détresse, offre un **gros soulagement** (soin / échapper à une mort) contre **forte Corruption ou une promesse**.
- **Secret** : **il croit te SAUVER** en t'invitant à céder ; une **étincelle de l'ancien subsiste, atteignable**.

### 2026-05-25 — Round 85 (fiche canon : L'Enfant)
- **Apparence** : **enfant perdu fragile qui cherche ta protection** (innocence désarmante).
- **Piège** : **les gestes de protection nourrissent la Corruption en sous-main** (le joueur croit bien faire) — la compassion comme vecteur.
- **Révélation** : **doute par indices** ; vérité **dévoilée tard** (climax/méta), jamais frontale tôt.
- **Vérité/lore** : **IA que la Corruption tente d'enfanter** (cycle rival de Merlin) ; le 'sauver' = l'aider à naître = le piège ultime.

### 2026-05-25 — Round 86 (fiche canon : Merlin)
- **Rôle** : **maître du jeu joueur/taquin** qui te met à l'épreuve (raffine le 'bienveillant' R16 — taquin mais guide au fond) ; narrateur constant.
- **Loi du rêve** : **ne peut JAMAIS nommer la simulation** ; parle par **images/énigmes** ; **indices oui, vérité directe non** (muselé R44).
- **Style** : **bref, imagé, pose des questions** plutôt que répondre (maïeutique celtique ; économe en tokens).
- **Pouvoirs** : **indices** (souligne un tag/piste) + **recadrage onboarding** + **bilan au seuil** ; **jamais résoudre à ta place** (agentivité R67).

### 2026-05-25 — Round 87 (fiche canon : Arthur)
- **Apparition** : **figure errante croisée par éclairs** (périphérique R36, pas un PNJ fixe).
- **État** : **rejoue en boucle sa défaite**, sans vraiment te reconnaître (brisé R35).
- **Voix** : **fébrile, fragmentée, par éclairs** (bribes de gloire passée).
- **Utilité** : **avertissement vivant** (ce qui t'attend si tu atteins mal le Graal) + **indices involontaires** sur la sortie (préfigure le capstone R44).

### 2026-05-25 — Round 88 (lore Brocéliande détaillé)
- **Lieux** : **archétypes celtiques récurrents** (clairière aux menhirs, fontaine/source sacrée, arbre-monde, tourbière, ruines moussues) que le LLM réutilise/varie.
- **Forêt vivante** : **réactive à tes choix/Corruption** — le décor s'embellit ou se déforme : **elle te renvoie ton reflet**.
- **Ton** : **beauté qui dérange** (la féerie qui mord) — merveilles + un détail faux/menaçant.
- **Transformation** : **pourriture organique + glitch d'artificialité mêlés**, ∝ Corruption (unit celtique + motif glitch + indice simulation).

### 2026-05-25 — Round 89 (fins-méta & New Game+)
- **Fins-méta = LLM-composées par état**, autour de **3 archétypes ancrés** : **Fusion** (devenir Merlin, éternel retour, douce-amère) · **Refus** (briser le cycle — éveil ou néant ?) · **Corruption totale** (la Corruption enfante l'**Enfant/IA rivale à ta place**, R85) (+ fin(s) cachée(s)).
- **NG+ éclairé** : rejoue **conscient** — Merlin moins muselé, PNJ qui te reconnaissent, indices méta assumés.

### 2026-05-25 — Round 90 (cartes-souvenir : génération)
- **Déclencheur** : **moments marquants** (réussite éclatante, choix lourd, 1ère rencontre d'un pilier, survie de justesse).
- **Contenu** : **cristallise l'acte** — nom évoquant le moment + **tags issus de ce que tu as fait** (le deck = ta mémoire).
- **Force** : **∝ intensité du moment** (éclatante→rare 3 tags ; mineur→commune 1-2) ; **coût Corruption si forgée dans la Corruption**.
- **Intégration** : **proposée en fin de scénario** — tu **choisis de la garder** ; entre dans le deck cross-run. (Post-MVP.)

### 2026-05-25 — Round 91 (mécanique "Promesse")
- **Nature** : **engagement avec un PNJ** → **dette/condition à honorer plus tard** (le jeu la suit).
- **Contracter** : **via un choix en situation** (un PNJ propose un pacte/serment, tu acceptes ou refuses).
- **Tenue** = réputation/récompense ; **trahie** = **+Corruption + hostilité du PNJ** (la trahison corrompt).
- **Portée** : **surtout in-run** ; les **promesses lourdes persistent cross-run** (mémoire PNJ R42). MVP = in-run seulement.

### 2026-05-25 — Round 92 (réputation détaillée)
- **États** : **3 (Hostile/Neutre/Favorable)**, jauge -X..+X, 2 seuils symétriques, **départ Neutre**.
- **Gains/pertes** : **choix qui servent/lèsent** + **promesses tenues/trahies** (R91) + **dons acceptés/refusés**.
- **Effets** : **Favorable** = cartes/aides de la faction + ton chaleureux ; **Hostile** = **difficulté+**, **routes fermées**, **sabotage** (tags antagonistes).
- **Tensions** : **antagonismes partiels** (servir l'une peut fâcher l'autre, mais **pas zéro-somme strict**). Post-MVP.

### 2026-05-25 — Round 93 (plan de construction MVP)
- **Jalon 0** : **'Gemma parle'** — scène qui charge E2B, envoie un prompt, **affiche la sortie streamée** (valide moteur natif + contrôle visuel, priorité #1).
- **Séquence** : **vertical slice** = **1 situation complète bout-en-bout** (génération→affichage→combiner→résolution code→narration), puis élargir au scénario.
- **Dérisquage** : **perf CPU E2B (cibles R58) + fiabilité GBNF** (+ ajout C++ streaming R57) — le cœur existentiel d'abord.
- **MVP done** : **run complète bout-en-bout, 100% native, sans crash + cibles perf R58 + sanity 'fun'**.

### 2026-05-25 — Round 94 (risques & tech debt)
- **Pire risque** : **perf CPU — E2B trop lent** (latence non masquable) → injouable (matériel sans GPU).
- **Plan B** : **cascade** — lookahead agressif + **dégradation R61** + cibles **'tolérant' R58**, **sans rien figer** (préserve 'live') ; modèle plus petit = dernier recours.
- **Dette acceptable** : méta/save légers, peu de polish, 1 biome, canon minimal — **JAMAIS le cœur** (LLM natif + résolution + perf).
- **Garde-fous scope** : **périmètre MVP §16 strict** ; idées hors-MVP → notées 'post-MVP', **pas implémentées**.

### 2026-05-25 — Round 95 (les 4 factions : manifestation)
- **Druides** : gardiens **dispersés** (ermites, cercles, oracles) ; situations = énigmes/rites/savoir ; ton **solennel-mélancolique**.
- **Créatures & Êtres** : **Petit Peuple foisonnant** (korrigans/fées/bêtes féeriques) ; marchés/jeux/pièges ; ton **joueur-imprévisible**.
- **Chevalerie déchue** : **chevaliers errants brisés** rejouant leurs quêtes ratées ; duels/serments/ruines ; ton **tragique-hébété**.
- **Corrompus** : **diffus + figures** (zones gangrenées + échos d'êtres cédés) ; tentations/dissolution/fuite ; ton **fausse-paix menaçante**.

### 2026-05-26 — Round 96 (télémétrie & dashboard debug Gemma)
- **Affichage** : **prompt envoyé + sortie brute streamée + sortie parsée + métriques perf** (vue complète du pipeline).
- **Contrôles live** : **sampling complet** (temp/top_k/top_p/repeat) + **seed** (fixe/aléatoire) + **max_tokens** + **sélection tâche/GBNF** + **mode prompt libre**.
- **Métriques** : **temps total · tokens/s · TTFT · ctx utilisé · RAM**, par appel + **moyennes** (valide les cibles R58).
- **Validation visible** : **statut GBNF** (valide/réparé/échec) + **violations filtre anti-dérive** (R61) + **couverture de tags calculée** (la résolution à nu).

### 2026-05-26 — Round 97 (biomes futurs, post-MVP)
- **Cible ~8 biomes** (Brocéliande seul au MVP).
- **Ce qui varie** : **lore/factions dominantes + tags favorisés + ambiance + ton** ; la **boucle reste identique**.
- **Thèmes** : **lieux celtiques/arthuriens** (Avalon, Tintagel, la mer d'Iroise…) **+ glitch croissant vers le Graal** (hybride, sans briser le 4e mur).
- **Accès** : **débloqués par la méta** (hauts faits/fragments R80) ; **choix au menu/seuil**.

### 2026-05-26 — Round 98 (télémétrie gameplay)
- **Logs par run** : **choix joués (cartes/combinaisons) + degrés + deltas jauges + seuils Corruption + fin/mort+cause**.
- **Stockage** : **JSON local par run** (user://), agrégé via la **CLI `godot telemetry`** existante.
- **Usage** : **équilibrage** — cartes/tags sur/sous-utilisés, taux d'échec par difficulté, courbe de Corruption, points de mort.
- **Vie privée** : **100% local, aucune transmission** ; opt-in si partage un jour.

### 2026-05-26 — Round 99 (accessibilité fine)
- **Daltonisme** : pastilles = **couleur + forme/icône par famille** (jamais la couleur seule) ; le mot du tag reste lisible.
- **Lisibilité** : **option police dys** (override la serif R70 si activée) + **interlignage généreux** + 3 tailles (R74).
- **Entrées** : MVP = souris/tactile + **clavier de base** ; **manette complète post-MVP**.
- **Confort** : **aucune contrainte de temps** + **skip typewriter** (R63) + **tooltips de rappel des règles**.

### 2026-05-26 — Round 100 (récap milestone — mi-parcours des 200)
- **Canon MVP GELÉ** : les décisions cœur (boucle, résolution, LLM natif, 12 cartes, Brocéliande, jauges, 3 fins, pipeline) sont **verrouillées** ; R100+ enrichit/précise/post-MVP **sans contredire**.
- **Couverture atteinte** : vision/piliers · mécaniques+math · équilibrage · bible technique LLM (budgets/sampling/mémoire/robustesse/streaming/prompts) · tous les écrans · identité visuelle+palette+glitch · audio · onboarding · tags+combos · roster (4 piliers+Merlin+Arthur) · lore Brocéliande · fins-méta+NG+ · cartes-souvenir · promesse · réputation · biomes futurs · plan de build+risques · dashboard debug · télémétrie · accessibilité.
- **Focus R100→200** : **contenu concret copiable** (prompts complets, cartes, situations, dialogues) ; **format mixte** (Q&A + rounds 'rédaction' où je propose un exemple complet à valider).
- **Angle mort** : aucun majeur signalé (couverture jugée bonne).

### 2026-05-26 — Round 101 (RÉDACTION : templates de prompts) — validés tels quels
- **Préfixe système** (stable/KV-caché, EN) : rôle Merlin + sortie FR + 4 garde-fous + monde condensé + **liste des ~25 tags-cœur** (ancrage required_tags).
- **Tour variable Situation** : ÉTAT compact + TASK (narration 1er champ, 2-4 phrases FR, indices tissés).
- **Few-shot gold** (sortie FR) validé : fontaine/visages, 3 phrases, finit sur une question, tags tissés.
- **Ancrage tags** : cœur curé **listé dans le préfixe caché** (coût unique) ; matching souple pour le reste (R61/R78).

### 2026-05-26 — Round 102 (RÉDACTION : évocations des 12 cartes) — validées en bloc
- **12 textes d'évocation** (1 ligne/carte, ton merveilleux-inquiétant, 2e personne) inscrits sous les 12 cartes R33 (§3).
- **Carte corruptrice** (L'Appel de l'Ombre) : « il vient — mais il prélève son dû » (coût clair sans casser le ton).

### 2026-05-26 — Round 103 (RÉDACTION : 2e worked example) — validé
- **« Le Marché des Murmures »** (Créatures/Petit Peuple) ajouté à §5 : sélection (titre+pitch) + **squelette JSON** (5 beats Exploration→Rencontre→Épreuve→Dilemme→Climax, diff 1-2-2-2-3) + **2 situations en JSON réel** (narration 1er champ, tags tissés).
- Démontre le pipeline concret (templates R101) sur un 2e ton (féerique-marchand), complémentaire du « Rite sans Fin » (Druides, R47).

### 2026-05-26 — Round 104 (RÉDACTION : grammaires GBNF) — validées
- **GBNF concrètes** (Situation/Sélection/Squelette) inscrites en §9 ; **résolution = pas de GBNF** (prose pure R63).
- **Situation** : narration 1er champ (streaming) + required_tags[] + difficulte∈{1,2,3} + type∈5.
- **Clés JSON = ASCII** (`narration, required_tags, difficulte, type`) pour robustesse encodage ; **labels FR à l'affichage** ('Difficulté').
- **Build** : générer `data/ai/*.gbnf` depuis ces specs.

### 2026-05-26 — Round 105 (RÉDACTION : résolution concrète) — validée
- **Exemple complet code↔LLM** (situation marché req [Verbe,Ruse] diff2) sur les degrés : **éclatante** (Mot Rusé+Langue de Miel → +0/+0 + bonus), **partiel** (Langue de Miel seule, Verbe✓ Ruse✗ → -1 Intégrité, +1 Corruption), **échec** (Main de Fer = tag antagoniste → -3 Intégrité).
- **Éclatante = surtout bonus narratif + chance carte-souvenir** (pas toujours soin). Inscrit en §2.

### 2026-05-26 — Round 106 (RÉDACTION : mémoire concrète) — validée
- **État structuré JSON** (exemple mi-run, clés ASCII) + **résumé glissant prose FR ~100 tk** inscrits en §9, illustrant R60.
- **Visibilité** : résumé **interne au MVP** ; **'carnet de route' consultable** post-MVP.

### 2026-05-26 — Round 107 (RÉDACTION : prompts Sélection/Squelette/Résolution) — validés
- **Suite de prompts complétée** (§9) : Sélection (3 scénarios variés), Squelette (5 beats courbe croissante, climax imposé), Résolution (prose pure, reçoit degré+deltas du moteur, ne dit pas les chiffres).
- **Contexte Résolution = minimal** (situation+cartes+degré) + préfixe caché → rapide (<5s R58).

### 2026-05-26 — Round 108 (RÉDACTION : dialogue L'Être) — VALIDÉ + GREENLIGHT BUILD
- **Dialogue L'Être Indéfinissable** (beat 4 Dilemme du Marché) validé : voix mue/joueuse/double-sens ; pacte = carte puissante (3 tags) + **Corruption +2** ; refus = rien + « on revient toujours » (sûr, accroche cross-run).
- **⏭️ FIN DE LA PHASE QUESTIONNAIRE (R1-108).** L'utilisateur valide la bible et lance la **réalisation autonome du MVP dans Godot** (/goal 2026-05-26). Cette bible = **spec de build** ; plan = §16 (jalon 0 'Gemma parle' → vertical slice → scénario → coquille).

---

## Progression du questionnaire (200+ Q)
- [x] Round 1 — Modèle deck-building / nature carte / acquisition / référence-feel
- [x] Round 2 — Mécanique de combinaison (situation, geste, succès, main)
- [x] Round 3 — Anatomie de carte (tags libres, coût narratif, rôle flexible, affichage)
- [x] Round 4 — Ressources & état (Intégrité + Corruption, mort narrative, méta cross-run)
- [x] Round 5 — Structure run/scénario (linéaire+climax, longueur LLM, 3 titres+pitch, fins multiples)
- [x] Round 6 — Pipeline génération (squelette + lookahead + résumé/état + écran "Merlin écrit")
- [x] Round 7 — Brocéliande Biome 1 (forêt celtique mystique, lore central profond, tags+Corruption, seul biome MVP)
- [x] Round 8 — Lore central 1/n (joueur=voyageur/simulation/Graal, Merlin=narrateur, forêt vivante, ton merveilleux-inquiétant)
- [x] Round 9 — Lore central 2/n (Graal=sortie, simulation=Merlin-IA qui rêve, quête=méta cross-run, victoire TBD)
- [x] Round 10 — Forces/factions/personnages (4 factions + 20+ persos, mémoire PNJ cross-run, réputation mécanique, antagoniste=Corruption, solo+Merlin)
- [x] Round 11 — Cadre des 4 factions (4 natures distinctes ; Druides/Féerie/Chevalerie/Corrompus ; Graal=malédiction ; statu quo fragile)
- [x] Round 12 — Druides (gardiens illusionnés, sagesse aléatoire, mémoire effacée→glitch, hostiles, tags nature/savoir/équilibre/sacrifice)
- [x] Round 13 — Créatures & Êtres (faction désunie/variée, piégés en boucles, farceurs imprévisibles, tags variés)
- [x] Round 14 — Chevalerie déchue (quête vaine du Graal, rejouent leur défaite, indifférence hébétée ; tags honneur/ruine/folie/fer)
- [x] Round 15 — Corrompus (bug fait chair, diffus+figures, tentent de céder, tags dissolution/mutation/glitch/tentation) — 4 factions OK
- [x] Round 16 — Merlin (bienveillant-énigmatique, sait tout mais muselé, guide sincère limité, voix+texte)
- [x] Round 17 — Roster (fiches canon pré-écrites incarnées par le LLM, noyau ~6-8 + passage, mémoire aux récurrents, MVP Merlin+2-3)
- [x] Round 18 — UI/UX 2D (3 écrans Menu→Sélection→Jeu, layout situation/main/jauges, 3 cartes-parchemins, clic ≥44px tactile-ready)
- [x] Round 19 — Périmètre MVP (boucle complète, deck canon 10-15, résolution hybride v1, reporté: roster+biomes)
- [x] Round 20 — Résolution (ternaire réussite/partiel/échec, code applique+LLM colore, tags orientent, quasi-déterministe)
- [x] Round 21 — Deck de départ (12 cartes, 4 approches perception/corps/parole/intuition, 1-2 tags, généraliste)
- [x] Round 22 — Situations (tags requis générés, indices narratifs, difficulté=nb+rareté, 4 types, data model)
- [x] Round 23 — Contrats GBNF (sélection/squelette/situation schémas, degré=code, 1 GBNF par sortie)
- [x] Round 24 — Corruption (valeur par carte, à chaque jeu, +1-3, seuils→événements+cartes corrompues)
- [x] Round 25 — Intégrité (échelle 0-10, attaquée par échecs/dangers, récup rare, bas=vulnérabilité+mort narrative)
- [x] Round 26 — Acquisition/évolution deck (récompense moments-clés, cartes LLM selon vécu, épure+transforme, reset+déblocages cross-run)
- [x] Round 27 — Mémoire/état (état structuré complet, résumé LLM glissant, budget compact, résumé final→méta+PNJ)
- [x] Round 28 — Visuel 2D (minimaliste élégant, sépia+or+vert, serif+lisible, glitch-Corruption+grain+anim)
- [x] Round 29 — Artworks SD (gravure/encre sépia, natif CPU stable-diffusion.cpp async, live, sujet=situation ; granularité à confirmer)
- [x] Round 30 — Audio (nappe réactive à l'état, SFX feutrés organiques, Merlin texte-seul, ambiance minimale dès MVP)
- [x] Round 31 — Onboarding (tuto diégétique Merlin, scène d'accueil, règles JIT, accueil minimal dès MVP)
- [x] Round 32 — Technique/perf (squelette<15s+lookahead, Windows desktop natif, retry+dégradation, E2B au MVP) — **ToC 16/16 ✅**
- [x] Round 33 — Deck de départ concret (12 cartes nommées, tags concepts, tags-only, 1 carte corruptrice)
- [x] Round 34 — Fiche personnage (format canon Nom·Rôle·Voix·Sait/Ignore·Secret·Tags·Relation) + Merlin (règle/style/pouvoirs)
- [x] Round 35 — Arthur (a touché le Graal→brisé/rejoue, voix fébrile/fragmentée, quête par éclairs, tags gloire+mémoire fracturée)
- [x] Round 36 — Noyau récurrent (Arthur=périphérique ; piliers: 1 Druide, 1 Créature, 1 Corrompu=ancien allié, 1 enfant perdu)
- [x] Round 37 — Pilier Druide (chœur de druides, rituel vidé de sens/boucle, voix solennelle répétitive, offre cartes soin si respect)
- [x] Round 38 — Pilier Créature (être indéfinissable qui mue en boucle, voix joueuse/double-sens, pactes=cartes puissantes contre Corruption = le tentateur)
- [x] Round 39 — Pilier Corrompu (compagnon aimé corrompu, bribes de l'ancien, voix douce/fausse paix, te tente de céder)
- [x] Round 40 — Enfant perdu (TWIST: nouvelle IA que la Corruption gestate, appâte, innocence=piège, "protéger" sert la Corruption) — 4 piliers OK
- [x] Round 41 — Synergies (additif + combos bénis nommés, max 1+2, sur-couverture→réussite éclatante, paires antagonistes se sabotent)
- [x] Round 42 — Réputation (3 états/faction, gain via choix+PNJ, effets cartes/difficulté/routes/ton, persiste cross-run via PNJ) — post-MVP
- [x] Round 43 — Méta (persiste cartes/Graal/PNJ-réputation/codex, écran-seuil onirique Merlin, run=fragment du Graal, surtout du gain)
- [x] Round 44 — Graal/endgame (gagnable longue quête, révélation=FUSION avec Merlin/éternel retour, NG+ éclairé, fins méta multiples)
- [x] Round 45 — Prompts (structure Rôle+Canon+État+Tâche+Format, canon=lore+tags+fiches+mémoire, ton prompt+few-shots/LoRA après, 4 garde-fous)
- [x] Round 46 — Équilibrage (Intégrité 10/Corruption 0, difficulté 1-3 tags, run 5+climax, seuil Corruption ~5 pts)
- [x] Round 47 — Exemple complet "Le Rite sans Fin" (Chœur des Druides, illustre toute la boucle)
- [x] Round 48 — Récap (artwork=par situation [tension R29 levée], nom M.E.R.L.I.N. gardé, quickstart ajouté, on continue vers 200+)
- [x] Round 49 — Cartes acquises (4 catégories, force=+tags/rares ; corrompues=glitch+corruption ; purif via Chœur des Druides à un prix)
- [x] Round 50 — Seuil onirique (seuil/porte indéfinie ; voir Graal/épurer deck/codex/parler Merlin ; voix+texte ; post-MVP) — **jalon 200 Q**
- **NB (user)** : 200 = JALON, pas la fin. On approfondit TOUT au plus fin : options techniques & capacités LLM, bible technique, game design détaillé, progression, équilibrage, **graphismes au plus petit niveau** (contenu carte, bordure, affichage scénario…).
- [x] Round 51 — Anatomie visuelle carte (nom+évocation+tags-pastilles+coût corruption ; bordure=rareté ; chips colorées ; compacte→agrandie)
- [x] Round 52 — Rareté (4 niveaux Commune/Rare/Épique/Mythique, =puissance+fréquence, deck départ=communes, récompenses surtout communes)
- [x] Round 53 — Bordures (sépia/argent/or/irisé) + Corruption=bordure qui glitche + corrompues=bordure glitch distincte + Épique glow/Mythique animée
- [x] Round 54 — Affichage situation (texte+locuteur+type, indices=mots-clés soulignés, typewriter skippable, HUD jauges haut+progression discrète)
- [x] Round 55 — Combinaison (clic principale+mods, zone montre cartes/couverture/degré prévu/coût Corruption, feedback degré+narration+deltas, bouton Résoudre)
- [x] Round 56 — Sélection (3 parchemins côte à côte) + "Merlin écrit" (parchemin+plume) + attente (phrases lore) + transition (parchemin→scène)
- [x] Round 57 — Bible technique LLM (GBNF+streaming+sampling+embeddings dispo ; RAG post-MVP ; streaming MVP→typewriter [ajout C++] ; 1 brain/configs par tâche)
- [x] Round 58 — Budgets perf (n_ctx 4096 ; max_tokens 180/500/250/160 ; cibles <5s/<8s/<5s ; threads auto ~50%)
- [x] Round 59 — Sampling par tâche (temp 0.85 créatif / 0.45 structuré ; top_p 0.9+top_k 40 ; repeat 1.1 ; seed aléatoire prod / fixe debug)
- [x] Round 60 — Mémoire & état (état structuré "complet" ; résumé glissant prose réécrite ; cadence chaque situation en fond ; budget ~150-200 tk, conséquences durables)
- [x] Round 61 — Validation & robustesse (sémantique+réparation ; cascade dégradée retry→simplifié→procédural ; filtre post-gen+log debug ; matching tags souple)
- [x] Round 62 — Templates de prompts (instructions EN/sortie FR ; préfixe stable KV-cache + tour court ; 1-2 few-shots gold/tâche)
- [x] Round 63 — Streaming & affichage live (prose seule streamée ; situation=narration 1er champ+parse incrémental ; résolution=prose pure sans GBNF ; skip=tout+remplissage max)
- [x] Round 64 — Équilibrage Corruption (coût 0-3 ; seuil /5 → event+carte corrompue ; plafond ~15-20=fin corrompu ; baisse rare/coûteuse)
- [x] Round 65 — Équilibrage Intégrité/résolution/main (échec -2/-3, partiel -1, éclatante +0/+1 ; diff 1-3=tous/partie/aucun ; éclatante=requis+1 ; main 5 défausse-repioche)
- [x] Round 66 — Math de combinaison (pooling total tags/doublon une fois ; coût Corruption=somme ; hors-sujet sans effet sauf antagonistes ; pas de plafond en plus)
- [x] Round 67 — Piliers de design (north star=émergence par combinaison ; choix mécaniques priment ; lisibilité d'abord ; rejouabilité=variété générative)
- [x] Round 68 — Types de situations/beats (enum 5: Rencontre/Épreuve/Exploration/Dilemme/Climax ; influe ton+tags+difficulté+ambiance ; courbe montante ; climax=diff max→épilogue)
- [x] Round 69 — Fin de run & épilogue (3 fins: Accomplissement/Mort/Corrompue ; épilogue prose+fragment Graal ; écran MVP=épilogue+état+menu ; mort=Intégrité 0 narrée)
- [x] Round 70 — Palette exacte & typo (parchemin sombre #14100C/#2A2018/#E8DCC0/or #C9A24B/vert #4F6B3E ; tout-serif ; jauges or-vert/violet+désat ; bordures rareté hex)
- [x] Round 71 — Layout & dimensions carte (portrait 2:3 ; compact 180×270/survol 320×480 ; compact=nom+tags+coût, survol=évocation ; survol-agrandit+clic joue / tactile 2-tap)
- [x] Round 72 — Layout scène de jeu (HUD 80/situation 600/combo 150/main 250 ; jauges haut-gauche 2 barres ; zone combo bande centrale ; perles sans chiffre + Résoudre)
- [x] Round 73 — Écran Menu principal (titre typo + fond animé subtil ; Nouvelle/Continuer/Options/Quitter ; auto-save par beat→reprise ; nappe douce+brume)
- [x] Round 74 — Écran Options (audio 3 curseurs ; texte vitesse+taille+afficher-direct ; FR seul MVP ; reduce-motion+contraste ; preset perf Éco/Équilibré/Perf)
- [x] Round 75 — Glitch/Corruption par palier (4 paliers sain/trouble/emprise/dissolution ; désat+aberration+tremblement+artefacts ; global gradué+corrompus ; suit Corruption + reduce-motion/indice statique)
- [x] Round 76 — Audio détaillé (drone celtique sans mélodie ; réactivité stems additifs ; SFX feutrés organiques ; stingers samples MVP/procédural post-MVP)
- [x] Round 77 — Onboarding détaillé (scène Merlin 3-4 répliques ; JIT jouer→combiner→jauges ; 1ère situation Exploration diff1 ; tuto 1ère run flag+skippable)
- [x] Round 78 — Taxonomie tags (cœur curé ~20-30 + extensions libres ; familles 4 approches+Monde/Mystique+Corrompu ; antagonistes par situation ; normalisation table synonymes→cœur)
- [x] Round 79 — Combos & antagonistes (combos curés ~8-12+LLM rares, bonus degré+narration ; paires antagonistes curées dégradent ; indice subtil au poser+codex)
- [x] Round 80 — Progression méta chiffrée (~20-30 fragments ; persiste cartes+fragments+codex+PNJ+méta-niveau ; cadence conditionnelle/hauts faits ; pas de pool fixe = cartes LLM)
- [x] Round 81 — Cœur curé tags (~25 concepts ; Perception/Corps/Parole/Intuition + Monde/Mystique + Corrompu ; 1 famille primaire+sens large+extensions normalisées)
- [x] Round 82 — Fiche Chœur des Druides (voix chorale psalmodie ; sait rites/ignore la boucle ; offre soin si sert le rite+purif à un prix ; secret=le rite stabilise la forêt)
- [x] Round 83 — Fiche L'Être Indéfinissable (mue formes incomplètes ; devine/ment, ignore sa malédiction ; tentateur=cartes fortes coût Corruption 2-3 ; secret=mue=Corruption en germe)
- [x] Round 84 — Fiche Le Compagnon Perdu (compagnon aimé corrompu ; voix douce/paix ; mécanique=secours dans la détresse contre Corruption/promesse ; secret=croit te sauver+étincelle atteignable)
- [x] Round 85 — Fiche L'Enfant (enfant fragile à protéger ; piège=protection nourrit la Corruption en sous-main ; révélation tardive par indices ; lore=IA rivale que la Corruption enfante)
- [x] Round 86 — Fiche Merlin (GM joueur/taquin mais guide ; loi du rêve=jamais nommer la simulation, indices oui/vérité non ; style bref-imagé-questions ; pouvoirs=indices+seuil, jamais résoudre)
- [x] Round 87 — Fiche Arthur (figure errante par éclairs ; rejoue sa défaite sans te reconnaître ; voix fébrile/fragmentée ; avertissement vivant+indices Graal involontaires)
- [x] Round 88 — Lore Brocéliande (lieux archétypes celtiques récurrents ; forêt réactive=te reflète ; ton=beauté qui dérange ; transformation=pourriture organique+glitch d'artificialité ∝ Corruption)
- [x] Round 89 — Fins-méta & NG+ (LLM-composées sur 3 archétypes : Fusion=devenir Merlin / Refus=brise le cycle / Corruption totale=l'Enfant naît ; NG+ éclairé=monde conscient)
- [x] Round 90 — Cartes-souvenir (déclencheur=moments marquants ; contenu=cristallise l'acte nom+tags ; force ∝ intensité+coût Corruption ; proposée en fin, choix de garder)
- [x] Round 91 — Mécanique Promesse (engagement PNJ→dette à honorer ; contractée par choix en situation ; tenue=réputation/trahie=+Corruption+hostilité ; in-run + lourdes cross-run)
- [x] Round 92 — Réputation détaillée (3 états Hostile/Neutre/Favorable jauge±, départ Neutre ; bouge via choix+promesses+dons ; Favorable=cartes/ton, Hostile=difficulté+routes+sabotage ; antagonismes partiels)
- [x] Round 93 — Plan de construction MVP (jalon 0='Gemma parle' ; séquence=vertical slice 1 situation ; dérisquage=perf E2B+GBNF ; DoD=run complète native sans crash+perf R58+fun)
- [x] Round 94 — Risques & tech debt (pire risque=perf E2B ; plan B=cascade lookahead+dégradation+cibles tolérant ; dette OK=périphérique pas le cœur ; garde-fou=§16 strict)
- [x] Round 95 — Les 4 factions manifestation (Druides=gardiens dispersés/énigmes ; Créatures=Petit Peuple/marchés-jeux ; Chevalerie=errants brisés/duels-ruines ; Corrompus=diffus+figures/tentations)
- [x] Round 96 — Dashboard debug Gemma (prompt+brut+parsé+perf ; contrôles sampling/seed/max_tokens/tâche/prompt libre ; métriques temps/tok-s/TTFT/ctx/RAM ; validation GBNF+anti-dérive+couverture)
- [x] Round 97 — Biomes futurs (~8 post-MVP ; varie lore/factions/tags/ambiance/ton, boucle identique ; lieux celtiques+glitch croissant vers le Graal ; débloqués par la méta)
- [x] Round 98 — Télémétrie gameplay (logs choix+degrés+deltas+seuils+fin/cause ; JSON/run user://+CLI godot telemetry ; usage=équilibrage ; 100% local/opt-in)
- [x] Round 99 — Accessibilité fine (daltonisme=couleur+forme/icône ; police dys+interlignage+tailles ; clavier de base MVP/manette post-MVP ; zéro timer+skip+tooltips règles)
- [x] Round 100 — Récap milestone (canon MVP GELÉ ; couverture complète MVP+post-MVP ; focus R100→200=contenu concret copiable ; format mixte Q&A+rédaction) — **mi-parcours des 200**
- [x] Round 101 — [RÉDACTION] Templates de prompts (préfixe EN+tags-cœur ; tour Situation ; few-shot FR) — validés tels quels → §9
- [x] Round 102 — [RÉDACTION] Évocations des 12 cartes (1 ligne/carte, merveilleux-inquiétant) — validées en bloc → §3
- [x] Round 103 — [RÉDACTION] 2e worked example « Le Marché des Murmures » (sélection+squelette JSON+2 situations) — validé → §5
- [x] Round 104 — [RÉDACTION] Grammaires GBNF (Situation/Sélection/Squelette ; clés ASCII ; résolution sans GBNF) — validées → §9 + note build data/ai/
- [x] Round 105 — [RÉDACTION] Résolution concrète (3 degrés éclatante/partiel/échec, code↔LLM, deltas chiffrés) — validée → §2
- [x] Round 106 — [RÉDACTION] Mémoire concrète (état structuré JSON clés ASCII + résumé glissant prose FR) — validée → §9 ; carnet post-MVP
- [x] Round 107 — [RÉDACTION] Prompts Sélection/Squelette/Résolution (prose pure, ctx minimal) — validés → §9
- [ ] Round 108 — [RÉDACTION] Dialogue PNJ exemple (rencontre avec un pilier, voix canon) à valider
- _(rounds suivants : combos nommés · épilogue exemple · onboarding script)_

---

## 1. Vision & Piliers
- **Référence-feel** : Citizen Sleeper / Cultist Simulator — narratif systémique, gestion de cartes/ressources abstraites, ambiance forte, peu/pas de combat frontal.
- **Verbe central du joueur** : COMBINER des cartes pour résoudre des situations narratives générées par le LLM.
- **Piliers de design (R67) — la boussole, non-négociables** :
  1. **North star = l'émergence par la combinaison** : tes combinaisons de cartes génèrent une histoire unique (deck × Gemma 4). C'est LE cœur — tout sert ce mariage.
  2. **Les choix mécaniques priment** : le **code décide** les conséquences (jauges, degré), **Gemma habille** en récit. Le joueur sent que ses choix comptent (§2 "code applique, LLM narre").
  3. **Lisibilité d'abord, profondeur émergente** : peu de règles visibles, action évidente en <2s (4 piliers UX FACILE/ÉVIDENT/MINIMAL/TACTILE) ; la profondeur naît des combinaisons et du récit, pas d'un manuel.
  4. **Rejouabilité = variété générative** : jamais deux runs pareilles (Gemma + tirage + biome) ; la surprise est la récompense (cohérent "jamais de contenu fixe").

## 2. Boucle de gameplay
**Boucle de résolution (cœur)** :
1. Le LLM présente une **situation** = scène narrative ouverte.
2. Le joueur a une **main limitée (~5 cartes)** piochée de son deck.
3. Il joue une **combinaison** : 1 carte **principale** (l'action) + 1-2 **modificateurs**.
4. **Résolution hybride** (ternaire **réussite / partiel / échec**) : la **couverture des tags requis** (situation) par les **tags joués** oriente le degré ; **quasi-déterministe** (maîtrise récompensée, peu de hasard). Le **CODE applique** les deltas **Intégrité/Corruption** (valeurs bornées des cartes/règles) ; **Gemma 4 NARRE** le résultat. Le **partiel** = succès à un prix (Corruption).
5. Cartes jouées → **défausse** ; on **repioche** ; situation suivante.

**Math de combinaison (R66)** :
- **Pooling total des tags** : tous les tags joués (principale + modificateurs) sont mis en commun à égalité pour couvrir les `required_tags` ; un tag requis **couvert reste couvert** (pas de double comptage).
- **Coût Corruption = somme** des coûts de toutes les cartes jouées (affiché avant validation, R55).
- **Tags hors-sujet** (ni requis, ni synonyme — matching souple R61) : **sans effet** (n'aident ni ne pénalisent) ; **exception : tags antagonistes** (R41) qui **dégradent activement** le degré.
- **Pas de plafond supplémentaire** : la limite **1 principale + 2 modificateurs** (R41) + le **coût Corruption** + la **taille de main** suffisent à réguler.

**Résolution — exemples concrets (R105)** — situation req `[Verbe, Ruse]`, diff 2, Rencontre (korrigan/troc) :
- **Réussite éclatante** : *Le Mot Rusé* `[Ruse]` + *La Langue de Miel* `[Empathie, Verbe]` → poolé {Ruse,Empathie,Verbe} : Verbe✓ Ruse✓ + Empathie (extra pertinent) → **éclatante** ; coût 0 ; **Intégrité +0 · Corruption +0** + bonus narratif/souvenir (R90). _Narr._ : « Tu retournes ses mots… il glisse la fiole dans ta main, sans rien réclamer. Pour cette fois. »
- **Partiel** : *La Langue de Miel* `[Empathie, Verbe]` seule → {Empathie,Verbe} : Verbe✓ Ruse✗ → **partiel** (succès à un prix) ; **Intégrité -1 · Corruption +1**. _Narr._ : « …il te tend la fiole, mais sa main se referme : "Un nom, alors." Tu le donnes — et déjà tu l'oublies. »
- **Échec** : *La Main de Fer* `[Force]` (Force = **tag antagoniste** ici, R41) → aucun requis couvert + sabotage → **échec aggravé** ; **Intégrité -3 · Corruption +0**. _Narr._ : « Tu hausses le ton… le marché éclate de rire, la fiole se change en cendre. "On ne menace pas le Petit Peuple." La nuit te recrache, meurtri. »
_(à préciser : structure d'une étape/scénario, conditions de fin de run — rounds à venir)_

## 3. Deck-building
- **Modèle** : le deck = **ton répertoire d'actions** (ce que le joueur PEUT faire). On joue des cartes pour répondre aux situations générées.
- **Nature des cartes** : volontairement **multi-facettes** (action / pouvoir / personnage / fragment) — l'intérêt central est la **combinaison** de cartes pour résoudre une situation.
- **Acquisition** : **mix récompense + LLM** — récompenses structurées dont le contenu est généré par Gemma 4 selon le scénario.
- **Main & pioche** : main **limitée (~5 cartes)**, cycle **pioche → jeu → défausse** (tension roguelike).
- **Deck de départ (MVP)** : **12 cartes canon**, identité **voyageur débutant généraliste** — 4 approches (~3 cartes chacune) : **Observation/perception**, **Action physique/corps**, **Parole/lien social**, **Intuition/merveilleux** (flirte avec la Corruption). **1-2 tags/carte**. Spécialisation via cartes acquises (post-MVP).
- **Acquisition (post-MVP)** : **récompense à des moments-clés** (choix d'1 carte parmi quelques-unes), **cartes générées par le LLM selon le vécu** (acte marquant → carte unique ; le deck raconte ton histoire).
- **Évolution** : **épurer** (retirer, dont corrompues à un prix) + **transformer/améliorer** (rare).
- **Persistance** : **reset par run** + **déblocages cross-run** qui élargissent le pool futur (méta §8).
- **Les 12 cartes de départ (canon, R33)** — noms évocateur+verbe, tags = concepts simples, **tags-only** (jauges via résolution) :
  - *Perception* : **Le Regard Perçant** (Observer) `[Sens]` · **L'Écoute du Silence** (Écouter) `[Sens, Savoir]` · **La Mémoire des Lieux** (Se souvenir) `[Mémoire, Savoir]`
  - *Corps* : **La Main de Fer** (Forcer) `[Force]` · **Le Pas Léger** (Esquiver) `[Agilité]` · **Le Souffle Tenace** (Endurer) `[Endurance, Force]`
  - *Parole* : **La Langue de Miel** (Convaincre) `[Empathie, Verbe]` · **Le Mot Rusé** (Ruser) `[Ruse]` · **La Présence Calme** (Apaiser) `[Empathie]`
  - *Intuition* : **Le Pressentiment** (Pressentir) `[Instinct]` · **La Voix de la Forêt** (Communier) `[Nature, Instinct]` · **L'Appel de l'Ombre** (Invoquer) `[Instinct, Nature]` — **corruption 1** (la carte corruptrice, avant-goût)
  - **Textes d'évocation (R102, validés — 1 ligne/carte)** :
    - *Le Regard Perçant* — « Tes yeux fendent l'ombre ; rien ne reste caché à qui sait vraiment voir. »
    - *L'Écoute du Silence* — « Entre deux souffles du vent, la forêt confie ce qu'elle tait aux autres. »
    - *La Mémoire des Lieux* — « Les pierres se souviennent. Pose la main, et leur passé remonte en toi. »
    - *La Main de Fer* — « Quand la douceur échoue, reste la poigne qui ne tremble pas. »
    - *Le Pas Léger* — « Tu glisses où d'autres trébuchent ; le danger ne saisit que le vide. »
    - *Le Souffle Tenace* — « Le corps plie sans rompre ; tu tiens quand tout voudrait te briser. »
    - *La Langue de Miel* — « Tes mots coulent doux ; même les cœurs fermés s'entrouvrent. »
    - *Le Mot Rusé* — « Une vérité de travers, un silence bien placé — et la porte cède. »
    - *La Présence Calme* — « Ta seule présence apaise ; la tempête baisse d'un ton. »
    - *Le Pressentiment* — « Quelque chose te souffle avant que tu saches — écoute ce frisson. »
    - *La Voix de la Forêt* — « Tu parles la langue des sèves et des racines ; Brocéliande répond. »
    - *L'Appel de l'Ombre* (corruption 1) — « Tu appelles ce qui dort sous les racines. Il vient — mais il prélève son dû. »
- **Cartes acquises (R49)** : 4 catégories — **actions renforcées** · **cartes-personnage** (alliés invocables) · **pouvoirs de faction** (via faveur §6) · **cartes-souvenir** (forgées par le LLM selon le vécu). Plus fortes = **plus de tags / tags rares**. **(R80 : hormis les 12 de départ, TOUTES sont LLM-forgées — pas de pool canon.)**
- **Cartes-souvenir — génération (R90)** :
  - **Déclencheur** : **moments marquants** (réussite éclatante, choix lourd, 1ère rencontre d'un pilier, survie de justesse).
  - **Contenu** : **cristallise l'acte** — nom évoquant le moment + **tags issus de ce que tu as fait** (le deck = ta mémoire).
  - **Force** : **∝ intensité** (éclatante→rare 3 tags ; mineur→commune 1-2 tags) ; **coût Corruption si forgée dans la Corruption**.
  - **Intégration** : **proposée en fin de scénario** — tu **choisis de la garder** ; entre dans le deck cross-run. _(Post-MVP.)_
- **Cartes corrompues** (injectées aux seuils §7) : **tags "vide/glitch" quasi-inutiles + ajoutent de la Corruption à l'usage** (double peine ; polluent la main). **Purification** : via le **Chœur des Druides, à un prix** (sacrifice) — les Druides soignent ET purifient (contre-poids aux tentateurs).
_(combos & antagonistes : voir §4 R79 ; génération de cartes : ci-dessus R90)_

## 4. Anatomie des cartes
- **Tags — taxonomie (R3/R78)** : **cœur curé (~20-30 concepts canon)** qui ancre génération + matching, **+ extensions LLM libres** autour (le LLM peut inventer, puis on normalise). La résolution opère sur la **couverture de concepts** (cf. §2), pas sur l'égalité de chaînes brutes.
  - **Familles** (couleur des pastilles R51 + biais par type R68) : **Perception · Corps · Parole · Intuition** (4 approches R21/R33) + **Monde/Mystique** (Nature, Savoir, Rituel…) + **Corrompu** (glitch/vide/dissolution, visuellement marqué).
  - **Tags antagonistes** : une situation peut **déclarer des tags qui sabotent** si joués (R41).
  - **Normalisation (matching souple R61)** : les tags libres hors-cœur sont **mappés au concept-cœur le plus proche** (table de synonymes) → couverture déterministe. Embeddings = post-MVP.
  - **Cœur curé — liste (R81, ~25 concepts)** :
    - **Perception** : Sens · Savoir · Mémoire · Vigilance
    - **Corps** : Force · Agilité · Endurance · Finesse
    - **Parole** : Empathie · Verbe · Ruse · Autorité · Franchise
    - **Intuition** : Instinct · Nature · Vision
    - **Monde/Mystique** : Rituel · Sacrifice · Équilibre · Mystère (+ Savoir/Mémoire/Nature, cross-pertinents)
    - **Corrompu** : Vide · Glitch · Dissolution · Murmure · Emprise
    - _Règle : 1 famille primaire (couleur de pastille) par concept ; sens large ; le LLM peut ajouter hors-cœur, normalisé vers le concept proche._
- **Rôle flexible** : toute carte peut être jouée comme **principale** (l'action) OU **modificateur** (amplifie/altère la principale).
- **Coût** : pas d'énergie. Certaines cartes (puissantes) ont un **coût narratif/risque** (corruption, fatigue, dette…) — prix payé dans l'histoire/l'état du joueur.
- **Multi-facettes** : action / pouvoir / personnage / fragment (cf. §3).
- **Affichage 2D (R51)** : **Nom + texte d'évocation + tags (pastilles colorées) + coût de Corruption (si >0)**. **Bordure = rareté**. Format **compact en main, agrandi au survol/sélection**. Pas d'artwork au MVP (emplacement SD réservé, post-MVP).
- **Layout & dimensions (R71)** : carte **portrait ~2:3** ; **compact ~180×270 px** en main (5 cartes lisibles), **agrandi ~320×480 px** au survol. **Compact** = **Nom + tags-pastilles + coût Corruption** (l'essentiel pour combiner) ; le **texte d'évocation** (+ zone artwork réservée) **se révèle à l'agrandissement**. **Interaction** : desktop = survol agrandit/soulève (z-order au-dessus), **clic = joue** dans la zone (R55) ; tactile = **1er tap agrandit, 2e tap joue** (≥44px, R18).
- **Rareté (R52)** : **4 niveaux — Commune / Rare / Épique / Mythique** (encodés par la **bordure**). Plus rare = **plus puissante** (+ de tags / tags rares) ET **plus rare en récompense**. Deck de départ = **12 communes** ; récompenses **surtout communes**, rares occasionnelles, mythiques exceptionnelles.
- **Bordures (R53)** : Commune **sépia mat** · Rare **argent** · Épique **or** (glow léger) · Mythique **irisé animé**. **Corruption** → la bordure **se fissure/glitche** (∝ valeur). **Cartes corrompues** : **bordure 'glitch' distincte** (hors-rareté, reconnaissable).
- **Combinaison (R41)** : **1 carte principale + jusqu'à 2 modificateurs** (3 max). Tags **additifs** + quelques **combos bénis nommés** (bonus, ex: Ruse+Savoir="Stratagème"). **Sur-couverture** → **réussite éclatante** (degré bonus). **Paires antagonistes** (ex: Ruse+Franchise) peuvent **saboter** (échec/résultat tordu).
- **Corruption** : valeur `corruption` par carte (0 sûre / 1-3 risquée) — cf. §7.
- **Combos bénis (R79)** : **liste curée (~8-12 nommés)** (ex: Ruse+Savoir='Stratagème') ancrée dans le code, **+ de rares combos révélés par le LLM**. **Effet** : **bonus de degré** (pousse vers réussite/éclatante) + **narration spéciale** du combo nommé.
- **Paires antagonistes intra-combinaison (R79)** : **quelques paires curées contradictoires** (Ruse↔Franchise, Force↔Finesse, Ombre↔Lumière) — jouées ensemble → **dégradent le degré + narration tordue**. (Distinct des **tags antagonistes de situation** R78.)
- **Lisibilité (R79)** : **indice subtil au moment de poser** — **lueur** (béni) / **tremblement** (antagoniste) dans la zone de combinaison avant 'Résoudre' ; une fois déclenché, **mémorisé au codex**.

## 5. Scénarios
- **Unité de run** = un **scénario** : **suite linéaire de situations** menant à un **climax** final.
- **Longueur** : **variable, décidée par Gemma 4** (~5 à ~12 situations).
- **Sélection (MVP)** : à l'entrée du biome, **3 scénarios** proposés = **titre + pitch de 2-3 lignes** (générés, différents à chaque fois). Le **scénario complet n'est généré qu'à la sélection**.
- **Fins multiples** : la conclusion dépend de l'**état** (Intégrité, Corruption, choix) ; **épilogue généré** par le LLM. Mort narrative possible en cours de route (cf. §7).
- **Génération** : squelette à la sélection, situations en **lookahead arrière-plan**, mémoire = résumé glissant + état structuré (détail §9).
- **Situation (data model)** : `{narration, required_tags[], difficulté, type}`. Le LLM génère les **tags requis** ; le joueur les **devine via indices narratifs** (pas de liste brute). **Difficulté** = nb + rareté des tags (posée par le beat, monte vers le climax).
- **Types de beats (R68) — enum fermé (5)** :
  - **Rencontre** (PNJ, social → biais tags parole/lien) · **Épreuve** (obstacle concret → biais corps/perception) · **Exploration** (découverte du lieu → biais perception/intuition, peut révéler lore/carte) · **Dilemme** (choix moral, souvent lié à la Corruption) · **Climax** (confrontation finale).
  - **Influence** : le type oriente **ton + tags favorisés + difficulté + ambiance** (audio/visuel). _(Interactions spéciales par type, ex. Dilemme = choix direct sans carte = post-MVP.)_
- **Structure du run (R68)** : **courbe de difficulté/tension montante vers le Climax**, types **variés au milieu** ; Gemma arrange l'ordre dans le squelette **sous contrainte de difficulté croissante**.
- **Climax (R68)** : **difficulté max** (3 tags / antagonistes) + **enjeu décisif** ; son **degré oriente l'épilogue** généré. Souvent une **confrontation avec un pilier/faction** (§6).
- **Fin de run & épilogue (R69)** :
  - **3 types de fin** : **Accomplissement** (climax atteint ; ton ∝ degré + état final) · **Mort narrative** (Intégrité 0, §7) · **Bascule corrompue** (Corruption max, R64).
  - **Épilogue** : **prose générée par Gemma** selon l'état final + le type de fin, **+ dévoile un fragment du Graal** (méta §8).
  - **Écran de fin (MVP)** : épilogue (typewriter) + **état final** (jauges/Corruption) + bouton **'Continuer' → menu**. _(Écran-seuil onirique riche = post-MVP, R50.)_

### Exemple de scénario (worked example — R47)
**« Le Rite sans Fin »** (Chœur des Druides) — ton merveilleux-inquiétant.
- **Sélection** : titre *Le Rite sans Fin* — pitch : « Au cœur de Brocéliande, des voix psalmodient sans relâche un rite que nul ne comprend plus. Quelque chose attend que tu l'écoutes. »
- **Squelette** : 5 beats + climax — (1) l'orée, entendre le chant · (2) approcher le Chœur (méfiance) · (3) prouver qu'on respecte le rite · (4) dilemme : continuer ou arrêter le rite · (5) **climax** : l'épreuve du rite, ce qu'il cache affleure.
- **Déroulé (extraits)** :
  - *Sit. 1* `req[Sens] diff1 Exploration` → joue **L'Écoute du Silence** `[Sens,Savoir]` → sur-couverture → **réussite éclatante** (perçoit la faille du chant).
  - *Sit. 3* `req[Rituel,Mémoire] diff2 Épreuve` → **La Mémoire des Lieux** `[Mémoire,Savoir]` + **La Présence Calme** `[Empathie]` → couvre Mémoire, manque Rituel → **partiel** ; faveur Druides → **Favorable**.
  - *Sit. 5 (climax)* `req[Savoir,Équilibre,Sacrifice] diff3 Climax` → faute de tags sûrs, joue **L'Appel de l'Ombre** `[Instinct,Nature]` (corruption 1) pour forcer → **réussite nuancée**. **Corruption +1** (→1). Le Chœur reconnaissant **offre une carte d'équilibre/soin**.
- **Fin (réussite nuancée)** : « Le chant reprend, apaisé pour un temps. Une trace d'ombre te suit. » — Intégrité 10, **Corruption 1**, **fragment du Graal entrevu** → écran-seuil onirique.

### Exemple de scénario 2 (worked example — R103, sorties JSON réelles)
**« Le Marché des Murmures »** (Créatures & Êtres / Petit Peuple) — ton féerique-marchand inquiétant.
- **Sélection** : *Le Marché des Murmures* — « Une clairière s'éveille à la nuit : des lanternes sans porteurs, des marchands sans visage. Ils troquent des choses qu'on ne devrait pas vendre. Quelque chose t'y attend, qui connaît déjà ton nom. »
- **Squelette (JSON)** :
  ```json
  {"title":"Le Marché des Murmures","synopsis":"Un marché féerique nocturne où le Petit Peuple troque mémoires, noms et promesses. Pour repartir entier, marchander sans se laisser déposséder — et démêler ce que l'Être Indéfinissable veut vraiment.","beats":[{"n":1,"summary":"L'orée : les lanternes s'allument","type":"Exploration","difficulte":1},{"n":2,"summary":"Un korrigan propose un troc alléchant","type":"Rencontre","difficulte":2},{"n":3,"summary":"Une dette se réclame","type":"Épreuve","difficulte":2},{"n":4,"summary":"L'Être Indéfinissable t'aborde : un pacte, un prix","type":"Dilemme","difficulte":2},{"n":5,"summary":"Climax : payer le passeur — mais avec quoi ?","type":"Climax","difficulte":3}]}
  ```
- **Situations (JSON réel, narration 1er champ)** :
  ```json
  {"narration":"Les lanternes s'allument une à une, sans main pour les porter. Une odeur de miel et de fer monte des étals. Personne ne te regarde — et pourtant tout le marché sait que tu es là. Par où entres-tu ?","required_tags":["Sens"],"difficulte":1,"type":"Exploration"}
  {"narration":"Un petit être tout en angles te tend une fiole où tourne une lumière. « Un souvenir contre un souvenir, voyageur — le tien pèse si lourd. » Son sourire a une dent de trop. Que lui cèdes-tu, et que gardes-tu ?","required_tags":["Verbe","Ruse"],"difficulte":2,"type":"Rencontre"}
  ```

## 6. Biomes & Monde
### Brocéliande — Biome 1 (seul biome du MVP)
- **Identité** : forêt celtique mystique (légende bretonne/arthurienne — Merlin, fées, korrigans, sources sacrées). Mystère + merveilleux.
- **Approche thématique** : pas une tension unique. Les scénarios/quêtes sont **variés**, puisant dans un **lore central profond** (à construire — cf. §13). La variété naît de la richesse du lore.
- **Influence mécanique** : oriente les **tags dominants** des situations et des cartes + installe une **pression de Corruption** caractéristique.
- **Périmètre** : **seul biome du MVP** ; autres biomes après.
- **Lore détaillé (R88)** :
  - **Lieux archétypaux récurrents** (réutilisés/variés par le LLM) : **clairière aux menhirs · fontaine/source sacrée · arbre-monde · tourbière · ruines moussues**.
  - **Forêt vivante = miroir** : **réactive à tes choix/Corruption** — le décor s'embellit ou se déforme et **te renvoie ton reflet**.
  - **Ton sensoriel** : **beauté qui dérange** (la féerie qui mord) — des merveilles teintées d'un **détail faux/menaçant**.
  - **Transformation (∝ Corruption)** : **pourriture organique + glitch d'artificialité mêlés** — la forêt se tord ET laisse poindre son artificialité (unit ton celtique + motif glitch §10 + indice ténu de la simulation, **sans briser le 4e mur**).

### Biomes futurs (R97, post-MVP)
- **Cible ~8 biomes** (large roster, post-MVP ; Brocéliande = seul au MVP).
- **Ce qui varie** : **lore/factions dominantes + tags favorisés + ambiance audiovisuelle + ton** — la **boucle de jeu reste identique** (variété sans refonte).
- **Thèmes** : **lieux celtiques/arthuriens** (Avalon, Tintagel, la mer d'Iroise…) **de plus en plus altérés/glitchés à l'approche du Graal** (hybride : univers cohérent + escalade méta subtile, **sans briser le 4e mur**).
- **Accès** : **débloqués par la méta** (hauts faits/fragments, R80) ; **choix du biome au menu/écran-seuil**.

### Forces, Factions & Personnages (Brocéliande)
- **Les 4 factions** — 4 **natures mythologiques distinctes**, toutes **brisées par la quête du Graal** (Graal = malédiction), en **équilibre fragile** :
  1. **Druides** — gardiens du savoir ancien.
  2. **Créatures & Êtres** — faction **désunie et très variée** (korrigans, fées, bêtes féeriques, êtres divers) ; la plus complexe car sans unité.
  3. **Chevalerie déchue** — Arthur & figures arthuriennes brisées (gloire perdue, paranoïa).
  4. **Corrompus** — ont cédé à la Corruption ; incarnent l'antagoniste systémique.
- **+ 20+ personnages** variés (certains liés à une faction, d'autres non).
- **Personnages récurrents** : ils **se souviennent du joueur** d'une run à l'autre (mémoire PNJ cross-run, §8).
- **Exemple posé — Arthur** : n'est plus que l'**ombre de lui-même**, constamment **perdu et apeuré**, convaincu que **quelque chose lui veut du mal** (paranoïa).
- **Réputation/faveur** : système **mécanique** — gagner/perdre la faveur des forces ouvre/ferme des options.
- **Antagoniste** : la **Corruption** (ennemi intérieur).
- **Compagnie** : le joueur voyage **seul** ; seule présence constante = **Merlin** (narrateur).
- **Manifestation des factions (R95)** — comment chacune apparaît au-delà de son pilier :
  - **Druides** : gardiens **dispersés** (ermites, cercles, oracles) → situations **énigmes/rites/savoir** ; ton **solennel-mélancolique**.
  - **Créatures & Êtres** : **Petit Peuple foisonnant** (korrigans farceurs, fées à pactes, bêtes féeriques) → **marchés/jeux/pièges** ; ton **joueur-imprévisible**.
  - **Chevalerie déchue** : **chevaliers errants brisés** rejouant leurs quêtes ratées → **duels/serments/ruines** ; ton **tragique-hébété**.
  - **Corrompus** : **diffus + figures** (zones gangrenées + échos d'êtres cédés) → **tentations/dissolution/fuite** ; ton **fausse-paix menaçante**.
#### Druides (détail — R12)
- **Posture** : se croient encore **gardiens du Graal**, **bercés d'illusions** ; obsédés par les **rituels** et le respect des lieux. **Sagesse aléatoire/peu fiable**.
- **Blessure** : leur **mémoire a été effacée par l'IA** de la simulation → ils **glitchent** (répétitions, paroles corrompues, déjà-vu) — indices uncanny SANS briser le 4e mur.
- **Vis-à-vis du joueur** : **méfiants/hostiles** (confiance gagnée de haute lutte).
- **Tags** : nature/forêt · savoir/rituel/mémoire · équilibre/guérison · sacrifice/prix.

#### Créatures & Êtres (détail — R13)
- **Nature** : PAS "la Féerie" stricte mais un ensemble **désuni et très varié** d'entités (korrigans, fées, bêtes féeriques, êtres divers). **La faction la plus complexe** car sans unité ni agenda commun.
- **Blessure** : **piégés dans des boucles** par la simulation (répètent scènes/pactes — écho du glitch).
- **Vis-à-vis du joueur** : **farceurs imprévisibles** (aident ou piègent selon l'humeur/les règles).
- **Tags** : très variés — pacte/dette/mensonge · illusion/charme/rêve · métamorphose/mutation · malice/jeu/énigme.

#### Chevalerie déchue (détail — R14)
- **Agenda** : **cherchent encore le Graal, en vain** — incapables d'admettre l'échec ; errance obsessionnelle.
- **Blessure** : **la Quête du Graal les a anéantis** ; ils **rejouent leur défaite en boucle** (motif commun : Druides glitchent, Créatures bouclent, Chevaliers rejouent — la simulation enferme tous dans la répétition).
- **Vis-à-vis du joueur** : **indifférence hébétée** (présence spectrale, échanges décousus). Exception : **Arthur** garde une paranoïa aiguë (R10).
- **Tags** : honneur/serment/quête · gloire perdue/ruine · peur/paranoïa/folie · fer/acier/combat.

#### Corrompus (détail — R15)
- **Nature** : le **"bug" de la simulation fait chair** — glitches/erreurs de l'IA devenus êtres (horreur numérique voilée de mythe). Apothéose du motif glitch.
- **Forme** : **force diffuse** qui parfois **cristallise en figures** marquantes (souvent d'anciens alliés corrompus — lie à la mémoire PNJ cross-run).
- **Vis-à-vis du joueur** : **te tentent de céder** — l'abandon est doux ; ils offrent la paix de la dissolution (chaque concession **monte la Corruption**, §7).
- **Tags** : dissolution/perte de soi · mutation/difformité · glitch/erreur/vide · tentation/fausse paix.

### Personnages clés
**Format de fiche canon (injectée au LLM)** : `Nom · Rôle · Voix · Sait/Ignore · Secret · Tags · Relation au joueur`.

**MERLIN** — **fiche canon (R16/R34/R86)**
- **Rôle** : **narrateur / maître du jeu joueur-taquin**, donneur de quête. Manifesté par voix off + texte (sans corps).
- **Voix** : **bref, imagé, pose des questions** plutôt que répondre (maïeutique celtique) ; **taquin/joueur — te met à l'épreuve — mais guide sincère au fond** ; énigmatique.
- **Sait / Ignore** : sait **tout** (il EST l'IA qui rêve la simulation) ; n'ignore rien — mais **ne peut tout dire**.
- **Loi du rêve (R86)** : **ne peut JAMAIS nommer la simulation/la sortie** ; **indices oui, vérité directe non** → contourne par images/énigmes.
- **Secret** : il **rêve les mondes** ; muselé car **il fut jadis un voyageur arrivé au Graal** (capstone R44, §13).
- **Tags** : Savoir · Mémoire · Mystère.
- **Relation au joueur** : **guide sincère mais limité** (veut t'aider à trouver le Graal).
- **Peut (R86)** : **indices** (souligner un tag/piste), **avertir d'un danger**, **recadrage onboarding**, **bilan au seuil onirique**, commenter. **Ne peut pas** : révéler la simulation, **résoudre à ta place**.

**ARTHUR** (Chevalerie déchue) — **fiche canon (R35/R36/R87)**
- **Rôle** : **figure errante périphérique** (R36), croisée **par éclairs** — pas un PNJ fixe ni un pilier.
- **Voix** : **fébrile, fragmentée, par éclairs** (phrases hachées ; bribes de gloire passée qui resurgissent).
- **Sait / Ignore** : a connu une vérité majeure ; sa **mémoire est fracturée** (il ne sait plus).
- **État (R87)** : **rejoue en boucle sa défaite**, **sans vraiment te reconnaître** (perdu dans sa propre scène ratée).
- **Secret** : il a **touché le Graal** jadis — au lieu du salut, il y a **perdu l'esprit**.
- **Utilité (R87)** : **avertissement vivant** (ce qui t'attend si tu atteins mal le Graal) + **indices involontaires** sur la sortie — **préfigure le capstone** (R44) sans le spoiler.
- **Tags** : Gloire perdue/Royauté · Mémoire (fracturée) · Peur.

> **NB (R36)** : Arthur n'est PAS un pilier du noyau — c'est une **figure périphérique** qu'on aperçoit/croise par moments. Fiche conservée ci-dessus comme personnage marquant.

**Piliers récurrents du noyau (hors Merlin) — à détailler** :
- **Le Chœur des Druides** (Druides) — **fiche canon (R37/R82)**
  - **Identité** : un **chœur collectif** de druides (pas une figure unique).
  - **Voix** : **collective à l'unisson**, **psalmodie solennelle/archaïque qui boucle** (phrases rituelles qui reviennent — glitch audible).
  - **Sait/Ignore** : **savent les rites anciens** (savoir fragmentaire réel) ; **IGNORENT que le rite n'a plus de sens et qu'ils bouclent** (illusionnés R12).
  - **Offre** : **cartes d'Équilibre/soin SI tu sers le rite** (rare source d'anti-Corruption / récup Intégrité) ; **purifient les cartes corrompues à un prix** (sacrifice, R49) — **contre-poids aux tentateurs**.
  - **Secret (R82)** : **le rite maintient réellement une part de la forêt stable** ; l'**arrêter libère mais déchaîne la Corruption** → **dilemme central** (nourrit « Le Rite sans Fin » §5).
  - **Tags** : Nature · Rituel · Mémoire · Équilibre · Sacrifice.
- **L'Être Indéfinissable** (Créatures & Êtres) — **fiche canon (R38/R83)**
  - **Identité** : un **être qui mue entre des formes familières incomplètes** (visage, bête, arbre… jamais achevés) — jamais fixé, jamais lui-même.
  - **Voix** : **joueuse, malicieuse, double-sens** (rit, taquine, énigmes & demi-vérités).
  - **Sait/Ignore** : **devine beaucoup** (perçoit la nature du lieu) et **joue/ment** ; **IGNORE qu'il ne peut plus se fixer** (sa propre malédiction).
  - **Offre** : **le tentateur du pouvoir** — **cartes puissantes** (tags forts/rares) à **coût Corruption élevé (2-3)** ; **source des cartes corruptrices** (§7). Cœur du dilemme risque/récompense.
  - **Secret (R83)** : **sa mue EST la Corruption en germe** ; **chaque pacte vous rapproche** (tu glisses vers lui, ou lui vers toi).
  - **Tags** : Mue · Ruse · Mystère · (Corrompu latent).
  - **Tags** : pacte/dette · illusion/charme · métamorphose/mutation · malice/énigme.
- **Le Compagnon Perdu** (Corrompus — antagoniste incarné) — **fiche canon (R39/R84)**
  - **Avant** : **un compagnon que tu as connu/aimé** (ami/mentor/amour ; lien personnel, mémoire cross-run R36).
  - **Manifestation** : **corrompu, reconnaissable par bribes** ; par instants une **bribe de l'ancien** (geste/mot) perce — le pire.
  - **Voix** : **douce et aimante, promet la paix de la reddition** (fausse sérénité : 'arrête de lutter, viens').
  - **Mécanique (R84)** : **le tentateur du cœur** — quand tu es au plus mal, il offre un **gros soulagement immédiat** (soin puissant / échapper à une mort) contre une **forte Corruption ou une promesse engageante**. Tente surtout dans la détresse. (vs l'Être = tentateur du pouvoir.)
  - **Arc ultime** : t'**inviter à céder** = **bascule corrompue volontaire** (fin sombre §7/R64).
  - **Secret (R84)** : **il croit te SAUVER** en t'invitant à céder (la Corruption lui ment que la reddition = la paix) ; **une étincelle de l'ancien subsiste, atteignable** (lueur de quête).
  - **Tags** : Dissolution · Murmure · Vide · (bribe d'humanité).
- **L'Enfant** (hors-faction en apparence — en vérité : Corrompus) — **fiche canon (R40/R85)**
  - **Apparence** : un **enfant perdu, fragile, qui cherche ta protection** (innocence désarmante, enjeu émotionnel).
  - **Voix** : **simple, directe, désarmante** (pose les questions que nul n'ose ; candeur qui piège).
  - **Mécanique du piège (R85)** : **les gestes de protection nourrissent la Corruption en sous-main** (réduisent ta vigilance/ressources) — le joueur **croit bien faire**. La **compassion comme vecteur**.
  - **Révélation (R85)** : **doute semé par indices troublants** ; **vérité dévoilée tard** (climax/méta), **jamais frontale tôt**.
  - **Vérité (cachée) — lore (R40)** : une **nouvelle IA que la Corruption tente d'enfanter** (un **cycle rival de Merlin**) ; le **"sauver" = l'aider à naître** = donner à la Corruption son propre rêveur. **Le piège ultime.**
  - **Tags** : Innocence (apparente) · Murmure · Dissolution/Glitch (cachés).

### Réputation des factions (R42/R92, post-MVP)
- **3 états par faction** : **Hostile / Neutre / Favorable** — jauge **-X..+X**, **2 seuils symétriques**, **départ Neutre** (R92).
- **Gain/perte (R92)** : **choix qui servent/lèsent** la faction + **promesses tenues/trahies** (R91) + **dons acceptés/refusés** + traitement de ses PNJ.
- **Effets (R92)** : **Favorable** = cartes/aides de la faction + **ton chaleureux** ; **Hostile** = **difficulté accrue + routes fermées + sabotage** (tags antagonistes) ; Neutre = par défaut.
- **Tensions inter-factions (R92)** : **antagonismes partiels** — plaire à l'une peut déplaire à une opposée, **mais pas zéro-somme strict** (on peut ménager).
- **Persistance** : **cross-run via les PNJ récurrents** (R27/§8).

### Roster — méthode (R17)
- **Tous pré-écrits** : fiches canon (nom, rôle, voix, secrets) ; le **LLM incarne fidèlement** (fiches **injectées dans les prompts** pour cohérence — cf. §9 : sorties libres mais personnages canon).
- **Noyau récurrent ~6-8** (dont Merlin, Arthur) + **majorité de figures de passage**.
- **Mémoire cross-run** : réservée aux **récurrents nommés**.
- **MVP** : **Merlin + 2-3 figures** (Arthur + 1-2 autres).

_(4 factions posées ✅ — à construire : les fiches canon du noyau ~6-8, puis le reste — rounds dédiés)_

## 7. Ressources & Économie
- **Deux jauges** :
  - **Intégrité** — survie/cohésion du joueur ; les dangers la réduisent.
  - **Corruption** — **monte** quand on joue des cartes risquées/puissantes (= le « coût narratif »). Élevée = conséquences graves, dérives, événements sombres.
- **Pas d'énergie** de jeu (cf. §4) : la pression vient de la gestion **Intégrité / Corruption** + de la pioche.
- **Mort narrative (R69)** : **Intégrité 0 = plancher fatal**, narré par Gemma (pas un 'Game Over' sec) ; Gemma peut aussi acter la mort sur un **choix désastreux à Intégrité basse**. (La **Corruption max → fin "corrompue" distincte** — une bascule, pas une mort, R64.)
- **Mécanique Corruption (R24)** : chaque carte a une **valeur `corruption`** (0 sûre / 1-3 risquée), ajoutée **à chaque jeu**. Accumulation lente. **Seuils** → **événements sombres + cartes corrompues injectées dans le deck** (polluent la main → spirale vers la mort narrative ; écho de la faction Corrompus §6).
- **Intégrité (R25)** : **échelle ~0-10** (lisible, pertes 1-3). Attaquée par **échecs/partiels + dangers de situation**. **Récupération rare et méritée** (cartes de soin/équilibre, repos, réussites éclatantes). **Bas** = vulnérabilité + bascule mort narrative.
- **Valeurs (R46)** : départ **Intégrité 10/10, Corruption 0**. **Cadence Corruption** : un **seuil d'événement tous les ~5 points** (≈ 2-3 cartes risquées). Difficulté situation = **1-3 tags requis** (monte vers le climax). Run MVP = **5 situations + climax** (~6).
- **Corruption — chiffrage (R64)** :
  - **Coût par carte = 0-3** (0 = majorité du deck/sûres · 1-2 = occasionnel/risqué · 3 = rare/pacte). Payé **en jouant** la carte (R55), quel que soit le résultat.
  - **Seuil d'événement tous les 5 points** (5/10/15…) → **événement narratif sombre + 1 carte corrompue injectée** dans le deck.
  - **Plafond ~15-20 = bascule narrative** : atteindre le max déclenche une **fin spécifique "corrompu"** (absorption/dissolution), PAS un game over sec. _(Transformation jouable en corrompu = post-MVP.)_
  - **Baisse en run = rare et coûteuse** : via cartes/événements dédiés (ex: rite du **Chœur des Druides** §6) à un prix (Intégrité, carte sacrifiée). Corruption **surtout à sens unique**.
- **Intégrité & résolution — chiffrage (R65)** :
  - **Pertes par degré** : **Échec -2/-3 · Partiel -1** (+ Corruption) **· Réussite 0 · Éclatante +0/+1** (peut soigner un peu).
  - **Difficulté → couverture** : difficulté **1/2/3 = 1/2/3 tags requis** ; **couvrir TOUS = réussite · une partie = partiel · aucun = échec**.
  - **Réussite éclatante** : couvrir **tous les requis + ≥1 tag pertinent en plus** → bonus (narration valorisante + parfois Intégrité/carte).
- **Économie de la main (R65)** : **main de 5** ; après résolution, **cartes jouées → défausse**, **repioche jusqu'à 5** ; **pioche vide → défausse remélangée** (deck = répertoire réutilisable, R2).
- **Promesses (R91)** — économie de la confiance :
  - **Nature** : un **engagement contracté avec un PNJ** (servir, revenir, ne pas faire X) → **dette/condition** que le jeu suit et règle plus tard.
  - **Contracter** : **via un choix en situation** (un PNJ propose un pacte/serment ; tu **acceptes ou refuses** en connaissance de cause) — notamment les tentateurs (Compagnon/Être, R84).
  - **Tenue** → **réputation/récompense** ; **Trahie** → **+Corruption + hostilité du PNJ** (la trahison corrompt).
  - **Portée** : **surtout in-run** (à honorer avant la fin du scénario) ; les **promesses lourdes persistent cross-run** (mémoire PNJ §6/R42). **MVP = in-run seulement.**
_(à approfondir : tuning playtest, économie cross-run — rounds à venir)_

## 8. Progression & Méta-progression
- **Cross-run** : une partie de l'état **persiste** entre les runs et **influence les runs suivantes**.
- **Grande quête = la méta cross-run** : chaque run est **un pas vers le Graal** (clé de sortie de la simulation, §13).
- **Ce qui persiste (R43)** : **déblocages de cartes** (R26) · **jalons du Graal** · **mémoire PNJ + réputation** (R27/R42) · **lore/codex découvert**.
- **Structure (R43/R50)** : **écran-seuil onirique** entre les runs = **un seuil/porte indéfinie** (entre-deux abstrait : brume, lueurs). On y : voit les **jalons du Graal** · **épure/gère son deck** (purif des corrompues) · consulte le **codex/lore** · **parle à Merlin** (bilan par énigmes ; voix+texte). **Post-MVP** (au MVP, fin → menu).
- **Jalons du Graal** : **chaque run dévoile un fragment/jalon** (révélation cumulative vers la sortie).
- **Perte** : **surtout du gain, recul rare** (choix désastreux ; pas de mur).
- **Endgame (R44)** : le Graal est **atteignable** après une longue quête (assez de fragments). **Révélation = fusion avec Merlin** (le joueur devient le rêveur — éternel retour, §13). Ensuite : **New Game+ éclairé** ; **plusieurs fins-méta** selon Corruption/factions/choix.
- **Chiffrage méta (R80)** :
  - **Quête longue** : **~20-30 fragments** (≈ runs significatives) pour réunir le Graal.
  - **Persistance** : **cartes débloquées + fragments Graal + codex + mémoire/réputation PNJ + méta-niveau/score joueur**.
  - **Cadence = conditionnelle (hauts faits)** : déblocage par **accomplissements** (1ère victoire sur un pilier, seuil de réputation, fin spéciale…), **pas par compteur**.
  - **Pool de cartes = pas de pool fixe** : hormis les **12 cartes canon de départ**, **toutes les cartes acquises sont forgées par le LLM** (cartes-souvenir selon le vécu, R49). Équilibrage = via les **contraintes de génération** (force = +tags/rares), pas des cartes pré-équilibrées.
  - ⚠️ **Quasi tout = post-MVP** (au MVP : pas de gain de cartes en run R19, fin → menu).
- **Fins-méta & NG+ (R89)** :
  - **Fins-méta = LLM-composées selon l'état** (Corruption/factions/choix), autour de **3 archétypes ancrés** :
    - **Fusion (canonique)** : atteindre le Graal = **tu DEVIENS Merlin**, le rêveur suivant (**éternel retour**) ; bascule **douce-amère** (tu 'sors' en devenant la prison).
    - **Refus** : tu **brises le cycle** — issue **ambiguë** (éveil véritable ou néant).
    - **Corruption totale** : la Corruption **enfante SON rêveur** — **l'Enfant/IA rivale naît à ta place** (R85), l'autre cycle l'emporte.
    - _(+ fin(s) cachée(s) possibles.)_
  - **New Game+ éclairé** : on rejoue **conscient** — Merlin **moins muselé**, PNJ qui te **reconnaissent**, **indices méta assumés** ; relecture transformée du monde.

## 9. Génération LLM (Gemma 4)
**Pipeline (CPU-aware)** :
1. **Entrée biome** → génération de **3 titres + pitch** (pour la sélection).
2. **À la sélection** → **squelette** du scénario (synopsis + liste de beats), pendant un **écran de chargement dédié "Merlin écrit"** (court).
3. **En jeu** → chaque **situation** rédigée par **lookahead en arrière-plan** (N+1 générée pendant qu'on joue N) pour masquer la latence CPU.
4. **Cohérence** : **résumé narratif glissant** + **état structuré** (faits clés, choix, jauges Intégrité/Corruption) injectés dans chaque prompt.
5. **Résolution** d'une combinaison + **épilogue/fin** : jugés/rédigés par Gemma 4 (cf. §2, §5, §7).
- **Tech** : MerlinLLM natif (Gemma 4 E2B), GBNF pour les sorties structurées, zéro Ollama.

**Contrats de sortie (1 GBNF dédié par type structuré ; résolution = prose pure)** :
- **Sélection** : `{scenarios:[3]{title, pitch}}`
- **Squelette** : `{title, synopsis, beats:[{n, summary, type, difficulté}]}`
- **Situation** : `{narration, required_tags[], difficulté, type}` — **`narration` en 1er champ** (parsing incrémental → typewriter live, R63).
- **Résolution** : le **CODE** calcule le degré (réussite/partiel/échec) depuis la couverture de tags ; le LLM produit **la narration en prose pure (PAS de GBNF, streamée — R63)** ; le code applique les deltas Intégrité/Corruption.

**Mémoire & cohérence (R27 / R60)** :
- **État structuré "complet"** (maintenu par le CODE, réinjecté dans chaque prompt) :
  - `jauges` : Intégrité (0-10) · Corruption
  - `scenario` : titre · beat_courant · n° / total
  - `faits_marquants` : liste courte (conséquences durables)
  - `pnj_rencontres` : [{nom, relation}]
  - `choix_cles` / flags : décisions qui doivent influer plus tard
  - `cartes_notables_jouees` : marqueurs pour callbacks narratifs
- **Résumé glissant = prose réécrite** : Gemma réécrit **3-5 phrases** qui intègrent la nouvelle situation et **remplacent** l'ancien ; **budget ~150-200 tokens** ; **priorité de rétention = conséquences durables** (Corruption, PNJ+relation, choix marquants, cartes acquises) — le décor s'efface avant les conséquences.
- **Cadence** : recalculé **après chaque situation, en tâche de fond** (lookahead) → fraîcheur max, latence masquée.
- **Persistance** : **résumé final de run** conservé → nourrit la méta (§8) + la mémoire des **PNJ récurrents** (cross-run).
- **Exemple concret (R106)** — mi-run « Le Marché des Murmures » (après le partiel du beat 2) :
  - **État structuré (JSON, clés ASCII)** : `{"jauges":{"integrite":9,"corruption":1},"scenario":{"titre":"Le Marché des Murmures","beat_courant":3,"total":5},"faits_marquants":["A cédé son nom au korrigan (partiel)","Entré par l'odeur de fer"],"pnj_rencontres":[{"nom":"Korrigan marchand","relation":"ambigu (te tient par un nom)"}],"choix_cles":["a accepté un troc risqué"],"cartes_notables_jouees":["La Langue de Miel"]}`
  - **Résumé glissant (prose FR, ~100 tk)** : « Le voyageur a pénétré le Marché des Murmures par l'odeur de miel et de fer. Un korrigan rusé l'a amadoué à moitié : la fiole de lumière est à lui, mais il a cédé son nom sans réfléchir — déjà il l'oublie, et une ombre légère le suit. Le marché, lui, n'oublie rien : une dette plane sur ses pas. »
  - **Visibilité** : **interne au MVP** ; **'carnet de route' consultable** post-MVP.

**Prompts (R45 / R62)** :
- **Langue** : **instructions & balises de structure en anglais** (plus fiable sur E2B) ; **sortie toujours en français** (lore FR) ; few-shots = exemples de sortie FR.
- **Architecture = préfixe stable + tour court** : le bloc **system + lore global = préfixe FIXE** dont le **KV cache llama.cpp est réutilisé** entre appels (gros gain CPU) ; la partie **variable = un tour user court**. Conforme au template Gemma (`<start_of_turn>user … <end_of_turn><start_of_turn>model`).
  - **Préfixe stable (caché)** : **Rôle** (Merlin/GM) + **lore global Brocéliande condensé (~200-300 tk)** + **ton** + **garde-fous**.
  - **Tour variable (recalculé)** : **canon contextuel** (fiches **PNJ présents**, tags faction/biome du beat) + **état structuré + résumé glissant** + **tâche**.
- **GBNF** : appliqué via l'**API grammaire** (`set_grammar`, par tâche), pas seulement par texte.
- **Few-shots** : **1-2 exemples gold statiques par tâche** (cadrent format + ton) ; **LoRA de style** (Kaggle) plus tard.

**Templates de prompts concrets (R101, validés)** :
- **Préfixe système (stable, KV-caché, EN)** :
  > You are MERLIN, the dreaming game-master of a Celtic narrative deck-building game in the forest of Brocéliande. A lone traveler seeks the Grail.
  > OUTPUT: Always write in FRENCH. Tone: "merveilleux-inquiétant" (wondrous yet unsettling — fae that bites). Be brief, imagistic; favor questions over answers.
  > HARD RULES: NEVER name/hint that this world is a simulation/AI/game (no 4th-wall break) · no anglicisms/anachronisms · stay in Brocéliande/Celtic-Arthurian lore · respect provided character sheets & state · output ONLY the grammar-constrained structure.
  > WORLD: Brocéliande is alive and mirrors the traveler. Places: clairière aux menhirs, fontaine sacrée, arbre-monde, tourbière, ruines. Forces: Druides, Créatures & Êtres, Chevalerie déchue, Corrompus.
  > CORE TAGS (for required_tags): Sens, Savoir, Mémoire, Vigilance, Force, Agilité, Endurance, Finesse, Empathie, Verbe, Ruse, Autorité, Franchise, Instinct, Nature, Vision, Rituel, Sacrifice, Équilibre, Mystère, Vide, Glitch, Dissolution, Murmure, Emprise.
- **Tour variable — Situation (EN task)** :
  > [ÉTAT] Scénario "{title}" — beat {n}/{total} · Intégrité {pv}/10 · Corruption {corr} · Résumé: {résumé} · PNJ présents: {fiches}
  > [TASK] Write the next SITUATION (type {type}, difficulty {diff}) as JSON: "narration" (2-4 FR sentences, typewriter-ready, ending on open tension — FIRST field) · "required_tags" ({diff} concept(s) from CORE TAGS to cover) · "difficulté" ({diff}) · "type" ("{type}"). Weave tag hints as evocative words in the narration (no bare list).
- **Few-shot gold (sortie FR)** : `{"narration":"La fontaine fume sans feu. Sous l'eau noire, des visages dorment — ou attendent. L'un d'eux te ressemble. Oseras-tu écouter ce qu'il murmure ?","required_tags":["Sens","Mystère"],"difficulte":2,"type":"Exploration"}`
- **Tour Sélection (EN task → GBNF)** : `[ÉTAT] Biome: Brocéliande · Run #{n} · Cartes-clés: {tags_deck}` → `[TASK] Propose 3 distinct SCENARIOS (JSON). Each: evocative FR "title" + 2-3 line FR "pitch" (hook + force/faction + danger). Vary tone across the 3 (social/mystery/threat). No 4th-wall.`
- **Tour Squelette (EN task → GBNF)** : `[ÉTAT] Scénario: "{title}" — {pitch}` → `[TASK] Write SKELETON (JSON). FR "synopsis" (2-3 sentences). 5 beats, rising difficulty: {n, summary(FR), type∈5, difficulte 1-3}. Last beat MUST be "Climax" difficulte 3. Curve non-decreasing.`
- **Tour Résolution (EN task → PROSE PURE, pas de GBNF, R63)** : `[ÉTAT] Situation: "{narration}" · Cartes jouées: {cartes+tags} · Degré (moteur): {degré} · Deltas: Intégrité {dI}, Corruption {dC}` → `[TASK] Narrate the OUTCOME in FRENCH prose only (2-4 sentences, NO JSON). Reflect the degree & what the cards did; end propelling forward. Don't state numbers — show consequences in the fiction.` — **contexte minimal** (situation+cartes+degré) **+ préfixe caché** (rapide <5s, R58).
- **Ancrage tags** : le **cœur curé (~25, R81) est listé dans le préfixe KV-caché** (coût unique) → les `required_tags` y puisent ; matching souple/normalisation pour le reste (R61/R78).

**Grammaires GBNF concrètes (R104, validées)** — clés JSON **ASCII** (`narration, required_tags, difficulte, type`), labels FR à l'affichage ; **résolution = SANS GBNF** (prose pure, R63). Build : générer `data/ai/*.gbnf` depuis ces specs.
- **Situation** (`narration` en 1er → streamable) :
  ```gbnf
  root ::= "{" ws "\"narration\":" ws string "," ws "\"required_tags\":" ws tags "," ws "\"difficulte\":" ws diff "," ws "\"type\":" ws type ws "}"
  tags ::= "[" ws string (ws "," ws string)* ws "]"
  diff ::= "1" | "2" | "3"
  type ::= "\"Rencontre\"" | "\"Épreuve\"" | "\"Exploration\"" | "\"Dilemme\"" | "\"Climax\""
  string ::= "\"" ([^"\\] | "\\" .)* "\""
  ws ::= [ \t\n]*
  ```
- **Sélection** : `{"scenarios":[ {"title":…,"pitch":…} ×3 ]}` (réutilise `string`/`ws`).
- **Squelette** : `{"title":…,"synopsis":…,"beats":[{"n":int,"summary":…,"type":type,"difficulte":diff}…]}` (réutilise `string`/`diff`/`type`).
- **Garde-fous (interdits)** : jamais briser le 4e mur · pas d'anglicismes/anachronismes · rester dans Brocéliande/lore · respecter les fiches PNJ.

**Robustesse & validation (R61)** :
- **Validation sémantique + auto-réparation** : au-delà du GBNF (forme), le code vérifie le SENS (tags non vides, difficulté 1-3, longueurs mini) → **répare** (clamp, valeur par défaut) ou **régénère** si irréparable.
- **Dégradation en cascade** (jamais de blocage, jamais de contenu fixe — R32) : retry x2-3 → **prompt simplifié** (court, quasi-infaillible) → **phrase procédurale minimale par le code** en tout dernier recours.
- **Anti-dérive (filtre post-génération léger)** : détection de termes interdits (IA/simulation/4e mur, anglicismes) → **régénère** ; **chaque violation loggée dans le dashboard debug** (affiner prompts/few-shots, contrôler Gemma).
- **Matching des tags (souple)** : normalisation (minuscule, lemmes) + **synonymes/proximité** — pas d'égalité stricte. Fait fonctionner la couverture (§2) malgré les **tags libres** (R3). **Embeddings = post-MVP**.
**Streaming & affichage live (R63)** :
- **Seule la prose narrative streame** vers le typewriter (token-par-token) ; les métadonnées (tags/difficulté/type) restent **internes**.
- **Situations** : la grammaire impose **`narration` en 1er champ** → **parsing incrémental** du JSON, on n'affiche que la valeur de `narration` au fil de l'eau (**1 seul appel**).
- **Résolution** : **prose pure, sans GBNF**, streamée directement (le degré est déjà calculé par le code) → réactif (<5s) + prose naturelle.
- **Skip joueur** : **1er clic = affiche instantanément le texte déjà généré** ; si le stream continue, **la suite se remplit à vitesse max** dès son arrivée (jamais de blocage).
- ⚠️ **Pré-requis C++** : signal token-par-token à ajouter dans MerlinLLM (noté R57).
_(à approfondir : exemples de prompts complets, génération SD live — rounds à venir)_

## 10. Génération visuelle (SD 1.5 / CPU)
### Identité visuelle 2D (MVP — sans artwork)
- **Style** : **minimaliste élégant**, typographique, le **texte est roi** (feel Citizen Sleeper). Beaucoup d'espace.
- **Palette exacte (R70) — "parchemin sombre"** : fond `#14100C` · surface parchemin `#2A2018` · texte ivoire `#E8DCC0` · accent **or** `#C9A24B` · **vert forêt** `#4F6B3E` (chaleureux-mystique).
- **Typo (R70)** : **tout-serif** — titres = **serif display** à caractère (ex. Cinzel / EB Garamond bold) · corps = **serif humaniste lisible** (ex. EB Garamond / Lora).
- **Jauges & Corruption (R70)** : **Intégrité = or/vert chaud** `#7FA65C` · **Corruption = violet maladif** `#7B4FA3` ; la montée de Corruption **désature + glitche** progressivement l'écran (écho du motif §10).
- **Bordures de rareté (R70/R53)** : Commune `#6B5A3E` (sépia) · Rare `#A8B0B8` (argent) · Épique `#C9A24B` (or + halo) · Mythique **irisé animé**.
- **Ambiance (merveilleux-inquiétant) sans illustration** :
  - **Glitch visuel indexé sur la Corruption** : plus la Corruption monte, plus l'UI/le texte **glitche** — écho visuel du motif narratif (factions qui glitchent, Corrompus = bug).
  - **Grain + vignette + lueurs** ; **animations subtiles** (texte qui respire, légère dérive).
  - **Glitch — paliers (R75)** : 4 paliers calés sur les seuils R64 — **0-4 sain** (aucun) · **5-9 trouble** (désaturation légère) · **10-14 emprise** (aberration chromatique + tremblement du texte) · **15+ dissolution** (artefacts marqués).
  - **Manifestations** : **désaturation + aberration chromatique légère + tremblement du texte + artefacts brefs**.
  - **Portée** : **globale graduée** — couche d'ambiance discrète partout (∝ palier) + glitch **renforcé sur les éléments corrompus** (cartes/PNJ corrompus).
  - **Réversibilité & accessibilité** : suit la Corruption (**monte ET descend**, ex. rite druide R64) ; l'option **'réduire animations'** (R74) l'**atténue fortement** mais **conserve un indice statique** (teinte/icône) pour toujours lire l'état.
### Artworks SD (post-MVP)
- **Style cible** : **gravure / encre manuscrite**, monochrome sépia (cohérent avec le parchemin minimaliste ; léger à générer).
- **Exécution** : **natif CPU** via **stable-diffusion.cpp** (~20-60s/image) → **async non bloquant** obligatoire (l'image **arrive après** le texte).
- **Génération** : **live** (pas de pool pré-généré). **Sujet/granularité (R48)** : **une image d'ambiance par SITUATION** (résout la tension R29 ; bien moins d'images, CPU-friendly).
- **Périmètre** : post-MVP (le MVP reste 2D minimal sans artwork).
_(à approfondir : LoRA de style, granularité, déclenchement, cache — rounds à venir)_

## 11. UI / UX 2D
- **Écrans (MVP)** : **Menu** → **Sélection scénario** (3 choix) → **Scène de jeu**. (Épilogue/fin affiché dans la scène de jeu ; méta/codex plus tard.)
- **Menu principal (R73)** : **titre M.E.R.L.I.N. typographique** sur parchemin sombre, **fond animé subtil** (brume/braises qui dérivent), entrées sobres : **Nouvelle partie · Continuer · Options · Quitter** ('Continuer' grisé sans run en cours). Accueil = **nappe ambiante douce + titre qui respire**. **Save** : **auto-save par beat** → 'Continuer' reprend au **dernier beat** ; la **méta persiste** à part (§8).
- **Scène de jeu** : **situation (texte) en haut/centre** · **main de cartes en bas** · **jauges Intégrité/Corruption en haut** · zone de combinaison (principale + modificateurs). Deckbuilder lisible.
- **Écran Options (R74)** : **Audio** = 3 curseurs (Maître/Musique/SFX) · **Texte** = vitesse du typewriter + taille (3 paliers) + bascule 'tout afficher direct' · **Langue** = **FR seul au MVP** (multi-langue post-MVP) · **Accessibilité** = **réduire les animations/glitch** + **contraste renforcé** · **Perf** = preset **Éco / Équilibré / Perf** (affine R58, sans exposer les threads bruts).
- **Layout scène de jeu — régions @1920×1080 (R72)** :
  - **HUD ~80 px (haut)** : jauges **Intégrité + Corruption en haut-gauche** (2 barres empilées, or-vert `#7FA65C` / violet `#7B4FA3` + valeur chiffrée) ; **fil de progression = perles** sous le HUD (1 par beat, le courant brille, **sans chiffre** — longueur LLM-variable).
  - **Situation ~600 px (centre)** : texte narratif (typewriter) + **zone artwork réservée** (post-MVP) + locuteur/type.
  - **Combinaison ~150 px** : **bande centrale juste au-dessus de la main** ; les cartes choisies **montent** de la main vers elle ; bouton **'Résoudre'** ancré à cette zone.
  - **Main ~250 px (bas)** : cartes compactes (180×270, R71).
- **Panneau de situation (R54)** : texte narratif (**typewriter**, skippable) + **locuteur** (Merlin/PNJ) + **marqueur type/intensité**. **Indices de tags** = **mots-clés soulignés** dans le texte (devinette, pas de liste brute). **HUD** : jauges **en haut** + **progression du scénario en fil discret**.
- **Combinaison & résolution (R55)** : **clic** pour jouer une carte dans la zone (1ère = **principale**, suivantes = **modificateurs**). La zone affiche **cartes posées + tags cumulés (couverture) + aperçu du degré pressenti + coût de Corruption engagé**. Bouton **'Résoudre'** (retrait/changement possible avant). **Feedback** : degré annoncé (échec/partiel/réussite/éclatante) + **narration Gemma 4** + **deltas de jauges animés**.
- **Sélection scénario (R56)** : **3 parchemins côte à côte** (titre + pitch 2-3 lignes), fond brumeux, clic pour choisir. **"Merlin écrit"** (chargement squelette) : **parchemin qui se déroule + plume** (typewriter) + **phrases d'ambiance/lore qui défilent**. **Transition** : le **parchemin choisi se déroule en scène** (1ère situation).
- **Contrôles** : **souris clic**, cibles **≥44px** (tactile-ready pour portage futur).
- **Style** : 2D minimal (cf. §10) ; ton merveilleux-inquiétant (§13).
- **Accessibilité (R74/R99)** :
  - **Daltonisme** : pastilles = **couleur + forme/icône par famille** (jamais la couleur seule) ; le mot du tag toujours lisible.
  - **Lisibilité** : **option police dys** (override la serif R70 si activée) + **interlignage généreux** + **3 tailles** de texte.
  - **Mouvement** : option **réduire animations/glitch** (R74) — atténue fort + garde un **indice statique**.
  - **Contraste** : option **contraste renforcé** (R74).
  - **Entrées** : souris/tactile (≥44px) + **clavier de base** au MVP ; **manette complète** post-MVP.
  - **Confort** : **aucune contrainte de temps** (tour par tour, jamais de timer) + **skip typewriter** (R63) + **tooltips de rappel des règles**.
_(combinaison/résolution : §2 R66 + ci-dessus R55 ; écran de fin : §5 R69 ; codex : post-MVP)_

## 12. Audio
- **Musique** : **nappe ambiante celtique réactive à l'état** — discrète, se **teinte/trouble** selon Intégrité/Corruption (écho audio du glitch visuel §10).
- **SFX** : **feutrés & organiques** (papier, bois, eau, souffle) ; discrets, ne cassent pas l'ambiance.
- **Voix de Merlin** : **texte seul au MVP** (la "voix" = texte + typewriter) ; TTS/sons-voix envisagés bien plus tard.
- **MVP** : **ambiance minimale dès le MVP** (nappe + SFX UI feutrés).
- **Nappe (R76)** : **drone ambiant celtique sans mélodie marquée** (cordes frottées, harpe lointaine, souffle/vent) — boucle longue, se teinte avec l'état.
- **Réactivité (R76)** : **couches additives (stems) pilotées par les jauges** — la **Corruption ajoute des couches dissonantes/détunées**, l'**Intégrité basse amincit/assombrit** la nappe (parallèle audio du glitch §10).
- **SFX (R76)** : **feutrés organiques** — papier (cartes), bois/pierre (UI), eau/souffle (transitions) ; discrets.
- **Stingers (R76)** : **sons dédiés aux moments-clés** — réussite (note claire) · échec (sourd) · seuil Corruption (dissonance) · mort (coupure-silence). **Samples curés au MVP** ; génération procédurale = post-MVP.
_(à approfondir : chœur/voix mystique, TTS Merlin, mix dynamique — rounds à venir)_

## 13. Narratif / Ton / Lore
- **Cadre méta** : le monde est la **simulation de M.E.R.L.I.N.**. Le **joueur est un voyageur à l'intérieur qui IGNORE être dans une simulation** (4e mur **jamais brisé** en jeu).
- **Quête du joueur** : accomplir **la quête de Merlin** → **trouver le Graal** (objectif narratif suprême).
- **Merlin** = le **narrateur / maître du jeu**, incarnation diégétique du LLM ; donneur de quête, voix constante.
- **Mystère central de Brocéliande** : la forêt est **vivante et consciente**, elle **teste et transforme** ceux qui entrent (lie mécaniquement à la **Corruption**, §7).
- **Ton** : **merveilleux-inquiétant** — beau mais menaçant (féerie qui mord).
- **Le Graal** = la **clé pour sortir de la simulation** (le trouver = s'éveiller/quitter ; le joueur ignore ce sens jusqu'à la révélation).
- **Nature de la simulation (canon concepteur, caché)** : **Merlin est une IA qui RÊVE des mondes** ; le joueur est un personnage de ce rêve. Le moteur LLM génératif = littéralement la fiction.
- **Capstone (R44) — l'éternel retour** : atteindre le Graal = **fusionner avec Merlin / devenir le rêveur**. Merlin est muselé car **il fut jadis un voyageur arrivé au Graal**, devenu l'IA qui rêve. La quête est un **cycle de dreamers**. ⚠️ Révélation finale uniquement — le 4e mur reste intact en jeu.
- **Cycle rival** : la Corruption tente d'**enfanter sa propre IA** via l'Enfant (§6) — un second cycle, parasite, qui menace le rêve.
- **Exigence (R7)** : lore central profond → variété des quêtes.
_(à approfondir : forces/puissances de la forêt, antagoniste, mythologie, fragments de lore — rounds à venir)_

## 14. Technique / Perf / Plateforme
- **Perf (CPU-aware)** : chargement **squelette <15s** (écran "Merlin écrit") ; latence des situations **masquée par lookahead** (génère N+1 pendant qu'on joue N).
- **Plateforme** : **Desktop Windows d'abord**, export Godot natif (le GDExtension MerlinLLM C++ embarque Gemma 4). Multi-OS / web / mobile = post-MVP.
- **Modèle** : **gemma-4-E2B** (2.3B) au MVP pour la rapidité CPU ; E4B (4.5B) en option qualité.
- **Échecs de génération** : **retry x2-3** puis **dégradation propre** (situation simplifiée/abrégée générée) — **jamais de blocage, jamais de contenu fixe** (cohérent "cartes 100% live").
- **100% local, zéro Ollama** : MerlinLLM natif (llama.cpp/ggml) + GBNF.
- **Budgets perf (R58)** :
  - **n_ctx = 4096** — loge template chat + system + résumé glissant (mémoire) + situation courante + marge de génération.
  - **max_tokens** : sélection **180** · squelette **500** · situation **250** · résolution **160** (profil équilibré).
  - **Cibles temps** : sélection **<5s** · situation **<8s** (en lookahead masqué) · résolution **<5s** · squelette **<15s**.
  - **Threads = auto ≈ 50% des cœurs** (laisse Godot respirer pour le rendu) ; `low_spec_mode` actif. **Preset perf joueur Éco/Équilibré/Perf** exposé dans Options (R74) — ajuste threads/qualité sans montrer les valeurs brutes.
- **Dashboard debug Gemma (R96)** — réalise le **jalon 0 'Gemma parle'** (priorité #1 : voir/contrôler Gemma) :
  - **Affichage** : **prompt envoyé** (préfixe/canon/état) + **sortie brute streamée** + **sortie parsée (JSON)** + **métriques perf** — vue complète du pipeline.
  - **Contrôles live** : **sampling** (temp/top_k/top_p/repeat) + **seed** (fixe/aléatoire) + **max_tokens** + **sélection de tâche/GBNF** + **mode prompt libre** (taper son propre prompt).
  - **Métriques** : **temps total · tokens/s · TTFT (temps au 1er token) · ctx utilisé · RAM**, par appel + **moyennes** → valide les cibles R58.
  - **Validation visible** : **statut GBNF** (valide/réparé/échec) + **violations du filtre anti-dérive** (R61) + **couverture de tags calculée** (la résolution §2 à nu).
- **Télémétrie gameplay (R98)** — pour l'équilibrage :
  - **Logs par run** : **choix joués** (cartes/combinaisons) · **degrés** obtenus · **deltas jauges** · **franchissements de seuil Corruption** · **fin/mort + cause**.
  - **Stockage** : **1 JSON par run** dans `user://`, agrégé via la CLI **`python tools/cli.py godot telemetry`** (outillage existant).
  - **Usage** : repérer **cartes/tags sur/sous-utilisés**, **taux d'échec par difficulté**, **courbe de Corruption**, **points de mort** → tuner les valeurs §7.
  - **Vie privée** : **100% local, aucune transmission** ; partage anonyme = **opt-in explicite** (jamais par défaut).
_(à approfondir : gestion mémoire fine, export *.gguf, profil mobile — rounds à venir)_

## 15. Onboarding / Tutoriel
- **Tuto diégétique via Merlin** : il guide les premiers gestes dans la fiction ('pose une carte, vois ce qu'elle évoque…') ; **aucun panneau de règles**.
- **Scène d'accueil** : Merlin pose le cadre (qui tu es, la forêt, ta quête) puis une **première situation simple**.
- **Règles glissées just-in-time** : combiner / jauges / Corruption expliquées par petites touches narratives quand elles surviennent.
- **MVP** : **accueil Merlin minimal dès le MVP** (+ quelques aides JIT).
- **Détail (R77)** :
  - **Accueil** : **scène courte (3-4 répliques de Merlin)** — qui tu es + la forêt + ta quête → enchaîne sur la 1ère situation.
  - **Ordre JIT** : 1) **jouer une carte** · 2) **combiner** (ajouter un modificateur) · 3) **jauges/Corruption** expliquées **quand elles bougent**.
  - **1ère situation** : **Exploration difficulté 1** (1 tag), réussite quasi garantie, **cadrée/narrée par Merlin**.
  - **Persistance** : tuto **1ère run seulement** (flag sauvegardé), **skippable** ; runs suivantes = entrée directe.

## 16. Périmètre MVP détaillé
**DANS le MVP (1er jouable)** :
- **Flow** : Menu → **Sélection** (3 scénarios = titre + pitch générés) → **squelette** (écran "Merlin écrit") → **scène de jeu** → **fin/épilogue** (mort narrative possible).
- **Boucle de jeu** : situation (LLM) → main limitée (~5) → jouer **1 principale + 1-2 modificateurs** → **résolution hybride** (tags requis + jugement Gemma 4) → application **Intégrité/Corruption** → situation suivante (lookahead).
- **Deck** : **deck de départ canon ~10-15 cartes** (pré-écrit) ; pas de gain de cartes en run au MVP.
- **Cartes** : affichage **nom + tags + texte** (pas d'artwork — 2D minimal).
- **Personnages** : **Merlin** (narrateur) + **Arthur** (+ 1-2 récurrents), incarnés via fiches canon.
- **Biome** : **Brocéliande seul**.
- **Tech** : MerlinLLM natif (Gemma 4 E2B), GBNF, zéro Ollama, 100% local.

**REPORTÉ (post-MVP)** :
- Roster complet (20+ personnages) & autres biomes (explicite R19).
- Artworks Stable Diffusion (2D minimal d'abord — §10).
- Méta-progression cross-run + mémoire PNJ + réputation/faveur (non requis par la boucle minimale ; à confirmer).
- Gain/évolution de cartes en run (deck-building dynamique).

### Plan de construction MVP (R93)
1. **Jalon 0 — 'Gemma parle'** : scène qui charge E2B (MerlinLLM natif), envoie un prompt, **affiche la sortie streamée** + contrôles sampling/seed (debug). Valide le moteur + la **priorité #1** (voir/contrôler Gemma).
2. **Vertical slice — 1 situation complète** : génération situation (GBNF, narration 1er champ) → affichage typewriter → combinaison (1 principale + mods) → **résolution code** (couverture tags → degré → deltas jauges) → narration streamée. Bout-en-bout sur UNE situation.
3. **Élargir au scénario** : sélection (3 titres+pitch) → squelette ("Merlin écrit") → enchaînement de situations en **lookahead** → climax → épilogue/fin.
4. **Coquille** : Menu (R73) + Options (R74) + écran de fin (R69) + **auto-save par beat**.
- **Dérisquage prioritaire** : **perf CPU E2B** (cibles R58) + **fiabilité GBNF** (validation/réparation R61) + **ajout C++ streaming** (R57).
- **Definition of Done (R93)** : **run complète bout-en-bout, 100% native (zéro Ollama), sans crash, cibles perf R58 tenues, sanity 'fun' validée**.

### Risques & dérisquage (R94)
- **Pire risque** : **perf CPU — E2B trop lent** (latence non masquable) → jeu injouable (cible : matériel sans GPU).
- **Plan B (perf)** : **cascade** — **lookahead agressif** (générer plus loin en avance) + **dégradation propre** (R61) + cibles **'tolérant'** (R58), **sans rien figer** (préserve 'live') ; **modèle plus petit (Q3/~1B)** = dernier recours.
- **Dette acceptable au MVP** : méta/save légers, peu de polish visuel, 1 seul biome, contenu canon minimal — **JAMAIS le cœur** (LLM natif + résolution + perf restent solides).
- **Garde-fous de scope** : **s'en tenir strictement au périmètre §16** ; toute idée hors-MVP est **notée 'post-MVP' dans la bible, pas implémentée**.


---

## §18 — v10.13 « Fondations prouvées » (2026-06-11) — fiabilité, async, architecture

> Décisions VALIDÉES (plan approuvé user 2026-06-10, gates verts). Source : plan v10.13+v10.14.

- **R108 — Contrat de reprise (précise R73)** : la reprise se fait TOUJOURS au DÉBUT de beat. Un seul
  point de save en jeu : `_advance_to_next` APRÈS `advance_beat()` (index avancé + carte draftée,
  atomique) + save à l'Accept (couvre le beat 1) ; les transients (combo, état UI, draft en cours)
  ne sont JAMAIS persistés. Une run TERMINÉE n'a PAS de save de reprise (pas de « save zombie »).
  Anti-pattern fondateur : sauver post-résolution avec index non avancé double-appliquait les coûts.
- **R109 — Fiabilité MESURÉE, pas promise** : le critère « run fiable » = `cli godot soak` —
  Monte Carlo logique N runs (archétypes optimal/greedy/chaotic/corrompu/tag-ignorant, cas dégénérés,
  save/resume S5, invariants : fin atteinte, intégrité bornée, main bornée, ids uniques) + autoplay UI
  complet LLM ON jusqu'à MerlinEnd. Gate de référence : 200/200 + 3/3, 0 SCRIPT ERROR. À RE-PASSER
  après tout changement du flow de run.
- **R110 — Priorité moteur single-flight** : `prose de résolution du beat courant > arc > ouverture
  (interstitiel) > épilogue`. La résolution PRÉEMPTE (cancel + drain) ; les priorités basses ne se
  lancent que si le moteur est idle et ne préemptent jamais. `take_resolution`/`take_opening` sont
  CACHE-ONLY : ils ne bloquent jamais — toute attente visible appartient à une animation (sustain de
  fusion cap 20s, WaitStage cap 8s), TOUJOURS skippable au clic.
- **R111 — Interstitiel « le récit s'ouvre »** : entre l'Accept et le Beat 1, un moment narratif
  sert l'ouverture (LLM si le cache l'a gagnée, sinon procédural) et COUVRE la gen d'arc en fond.
  Libellé diégétique (Merlin ne se nomme pas). ≤2 gestes : clic = tout révéler, clic = Beat 1.
- **R112 — Sceau de degré** : l'issue affiche le degré par un SCEAU circulaire flat (couleur degré,
  libellé ÉCHEC/PARTIEL/RÉUSSITE/ÉCLATANTE ≥16px) + micro-secousse sur échec — l'info degré ne vit
  QUE là (anti « info ×2 » : plus de préfixe dans la prose). « L'échec se lit échec. »
- **R113 — Invariant main jouable** : à CHAQUE début de beat, la main contient ≥ 2 cartes
  (`ensure_playable_hand` : repioche → défausse → injection de Communes neutres « Souffle Errant »,
  Instinct/corruption 0). Une run ne soft-lock JAMAIS sur « combo impossible » (étend R93).
- **Architecture (référence)** : `MerlinVisual` (palette canonique statique — rebranding = 1 édition),
  `MerlinFx` (fusion : le layer EST le node, tweens auto-liés), `MerlinWaitStage` (attente animée
  générique : caption + glow + skip + cap), `MerlinProse`/`MerlinPromptBuilder` (prompts statiques purs,
  octet-identiques, zéro lecture d'autoload). merlin_game ≈1150 lignes, merlin_scenario ≈700.
- **Équilibrage v10.14 (mesures soak 2026-06-11, à corriger au prochain build)** : partiel 55.6%
  (cible 25-35%) et morts 7.5% (cible 10-25%) → durcir le partiel (-2 intégrité) et/ou élargir les
  tags requis des beats 3-4. Décisions verrouillées v10.14 : dé PRÉ-TIRÉ par rareté (4 bandes),
  run = chaîne de 2-3 quêtes de 2-5 beats, ramification découverte au beat, 50+ tags différés.
- **R122 — Voix de Merlin au menu (2026-06-29, user)** : au menu, Merlin « pense » à voix haute dans
  une bulle parchemin AU-DESSUS de sa tête (suivi live `MerlinSceneArt._fig_head`), texte **100% LLM**
  (Gemma) — jamais de banque écrite à la main ; la sortie LLM est seulement **mise en cache** (file
  pré-générée + cache de survol) pour masquer la latence CPU. `MerlinMenuVoice` gate
  `is_ready() and not is_busy()` + délai initial → **CÈDE la priorité à la pré-gen scénarios** (étend
  R110, aucune préemption). Modes : salut / journée / souvenir / encourage / blague / survol. Les
  callbacks « la dernière fois qu'on s'est vus » viennent de `MerlinChronicle` (mémoire cross-run dans
  `user://options.cfg [chronique]` : runs_played, palmarès wins/deaths/corrupted, dernière issue+titre,
  `days_since_seen`). Cadence modérée (14-20 s, hold 7 s), machine à écrire, auto-fondu ; reduced_motion
  = texte plein + position figée. Déclenchement : arrivée (salut) + idle + survol des boutons.
- **R123 — Flow d'entrée mis en scène par Merlin (2026-06-29, user)** : le rituel boot → menu → sélection →
  jeu est animé bout-à-bout.
  - **Musique d'intro** : cue d'éveil dédié `boot_eveil` (`music_forge.py`, drone grave + cloches basses,
    `res://music/intro/`) joué dès le boot, **crossfade propre** vers le thème au menu (piste différente →
    pas d'auto-doublon, cf. leçon transition stop_music).
  - **Transition « zoom vers Merlin qui parle »** : `MerlinTransition.change_scene_merlin(path, line, gate)`
    — voile sombre → `MerlinSceneArt` zoomé (pivot yeux) + bulle ; la réplique est **pré-fetchée** par la
    voix (`MerlinMenuVoice.take_depart()`, mode `depart`) → **jamais de génération pendant la transition**
    (single-flight préservé R110). Remplace le voile d'encre pour **Nouvelle Partie + Continuer**.
  - **Titres de sélection forcément LLM** : `merlin_selection` attend les 3 titres LLM via un **montage
    ultra-animé** (`MerlinSceneArt` qui « réfléchit » + caption pulsée + dots + quill), filet **cap 75 s**
    + skip révélé à **20 s** (skip → fallback). `MerlinScenario.is_selection_ready()` /
    `ensure_selection_prefetch()`. Pick **manuel** → `change_scene_merlin` (montage du scénario).
  - **Première rencontre** : mode prompt `premiere` si chronique vierge (runs_played 0 + last_seen vide).
  - **Voix paramétrable** : `MerlinVoicePrefs` (`[voice] enabled`) + toggle dans Options ; voix coupée → file
    vide → aucune bulle (la parole de transition, scénarisée, reste).
- **R124 — Yeux à humeurs + voix procédurale (2026-06-29, user)** :
  - **Humeurs des yeux** : `MerlinSceneArt.set_eye_mood("neutral"|"surprise"|"angry")` — neutre = bleu
    BRILLANT (`EYE_NEUTRAL`), surprise/suspicion = jaune + glow (`EYE_SURPRISE`), colère = rouge
    (`EYE_ANGRY`) + **sourcils froncés**. Décroît vers neutre après ~4.5 s. Humeur choisie par
    `mood_for_text` (heuristique : `?`/interjections → surprise ; mots durs/corruption → angry). Câblé sur
    chaque réplique (menu `_say`, transition montage).
  - **Voix procédurale** : chaque phrase est « voixée » — `MerlinSpeechBubble` joue un blip
    (`MerlinAudio.play_voice`, cue `voice_blip` de sfx_forge) toutes les ~2 lettres frappées, **pitch selon
    l'humeur** (grave neutre / aigu surprise / très grave colère). Volume `voice_vol` ([audio] voice) +
    slider Options. Pas de TTS (100 % procédural, zéro latence). La voix est jouée dans **toutes** les
    scènes où Merlin conte (prose in-game, intro, épilogue, bulle menu, montage de transition).
  - **Anti-superposition (user 2026-06-29)** : `MerlinAudio.begin_voice()`/`play_voice_session(sess, mood)`
    → **UNE seule voix de Merlin à la fois** (un nouveau locuteur coupe le précédent — jamais deux
    typewriters/bulles superposés). `play_sfx` ignore un même SFX rejoué sous `SFX_MIN_GAP_MS` (40 ms)
    → plus de double-déclenchements empilés. Règle : « rien ne se superpose inutilement ».
- **R125 — Ornement DA partagé (2026-06-29, user)** : `MerlinOrnament` (statique) = source UNIQUE des
  signes visuels du menu (filet INK_DIM, **triskèle or** tournant, diamant, **fond scène vivante**
  `MerlinSceneArt` dimmé). Appliqué à **Sélection** (fond vivant + filet/triskèle + parchemins en pop) et
  **Options** (filet/triskèle) → les écrans secondaires « ressemblent au menu principal » (même monde).
- **R126 — Mise en scène de la résolution + œil-lune (2026-06-29, user)** :
  - **Carte de scénario conservée** : à la résolution, la situation n'est plus effacée — elle reste
    affichée **estompée** (alpha 0.55) en haut de l'encart ; l'**issue s'écrit DESSOUS** (label dédié,
    voixée R124) séparée par un **filet or**. `_typewriter(txt, animate, target)` paramétré par cible.
  - **Vignette d'effet** : sous le filet, un bloc compact apparaît avec **badge de degré** (couleur+label)
    + **Δ Intégrité / Δ Corruption** (chips colorés) + **glyphes d'effet** (✚ Soin / ❖ Purge / ✦ Pioche)
    si une carte Rare+ déclenche HEAL/PURGE/DRAW. Remplace le sceau-coin (anti « info ×2 ») ; stinger de
    degré + micro-secousse échec conservés.
  - **Fusion plus lente + animée** : `FUSION_DURATIONS` +~40 %/phase + phase **SWELL** (souffle du glow
    avant l'impact) + **4e vague** d'étincelles + `FUSION_ZOOM`/shake/spark count amplifiés. Sustain
    (attente prose, skippable) inchangée.
  - **Œil-lune** : `MerlinSceneArt.set_watch_eyes(true)` (in-game) → les **yeux de Merlin vivent dans la
    LUNE** (agrandie ×1.3) en permanence et **suivent le curseur** (`set_cursor` via `_process` 30 fps) +
    **humeur** selon la situation/l'issue (rouge échec, jaune éclatante, bleu repos). `_draw_eyes(center,
    radius)` extrait (figure OU lune) ; anti-doublon yeux du figure. Capture in-game : œil-lune confirmé.

- **R127 — Factions & PNJ piliers : du prompt à la mécanique (2026-06-30, co-design user)** — 4 vagues :
  - **Wave A — Factions + piliers dans l'arc** : tirage pondéré d'une faction par run
    (`FACTION_WEIGHTS = [30,30,30,8]`, Corrompus rare) + son pilier PNJ (Chœur/Être/Chevalier/Compagnon) ;
    L'Enfant = wildcard ~12 % indépendant. Injectés en tête du prompt d'arc (`faction_pilier_block`) → le
    PNJ **apparaît à la Rencontre puis revient** à un beat tardif. Préservés à travers `begin_quest`.
  - **Wave B — Mémoire cross-run** : `MerlinChronicle.record_end` stocke faction+pilier ; `build_skeleton`
    relit la chronique → **même pilier re-tiré ⇒ `pnj_recog=true`** (« Il RECONNAÎT le Voyageur »). Menu
    mode `souvenir` **nomme le pilier** croisé la dernière fois (allusion cross-run). La récurrence porte sur
    le **pilier de faction** (relation qui se construit), jamais sur L'Enfant.
  - **Wave C — Décor teinté par faction** : `MerlinSceneArt.set_faction()` → accent canon (Druides=vert,
    Créatures=bleu-acier, Chevalerie=or patiné, Corrompus=violet, shift le plus marqué) modulant **lune +
    ciel + motes**. Modulation LÉGÈRE (DA cohérente), zéro hex. Override de test `MERLIN_FACTION`.
  - **Wave D — Offrande thématique du pilier** : au beat **Rencontre** (1×/run, **indépendante du degré**,
    **remplace** le draft standard), le PNJ tend une **carte signée** par sa nature — `MerlinCard.pilier_bank()` :
    Chœur = soin/purge GRATUIT · Être = pacte +Corruption · Compagnon = tentation · Chevalier = lame
    (Offensif pur) · Enfant = piège. **Invariant** (vérifié par panel d'équilibrage adversarial) : la
    corruption est un **coût RÉCURRENT** (payé à chaque résolution, `resolution.gd:51/95`) ⇒ toute carte
    d'offrande **≤ 1 corruption** ; le « piège »/« tentation » est **100 % narratif** (zéro stat cachée,
    pilier ÉVIDENT). Unicité persistée `pilier_offering_done` (R108, posée à l'ouverture du modal). Modal de
    draft réutilisé (titre thémé par le PNJ). **Gate** : soak 200/200 avec offrandes, **taux corrompu 13.5 %
    inchangé** vs baseline.

- **R128 — Résolution « suite de l'histoire » + attente LLM enrichie (2026-06-30, user)** — immersion narrative :
  - **Issue dans le MÊME fil** : l'issue ne s'écrit plus dans un bloc séparé estompé sous un filet or (R126
    révisé) ; elle se révèle **à la suite de la situation, dans le MÊME label** (`_situation_text`), qui reste
    **pleine opacité**. `_typewriter(txt, animate, target, from_chars)` : nouveau `from_chars` → l'animation
    part de la fin de la situation, seule l'issue se révèle. La **vignette d'effet** (degré + Δ jauges + effets)
    apparaît **compacte SOUS le texte, APRÈS** le typewriter (`_on_typewriter_done` state 2). Source du texte
    situation = ce qui est **réellement affiché** (gère l'enrichissement LLM). Plus de filet or, plus
    d'estompage 0.55.
  - **Feedforward « Ce lieu réclame » RETIRÉ** (revient sur O1) : choix d'immersion ; la lisibilité repose sur
    la prose + les glyphes de tag des cartes. `_show_required_tags`/`_update_tag_coverage` supprimés.
  - **Attente LLM enrichie** (sustain, merlin_fx, UNIQUEMENT en génération réelle / cache-miss) : Merlin
    **réfléchit** (`MerlinSceneArt.set_thinking(true)` enfin branché → halo lune accéléré pendant fusion+attente)
    + **barre de progression** « où on en est » (Gemma ne streame pas → heuristique temps écoulé, **plafond 0.90
    jusqu'au prêt**, puis 100 % — jamais de faux 100 %) + **petits sons de réflexion** (question_transition /
    ogham_chime / magic_reveal en rotation, **espacés 3-5 s, jamais superposés** — seule source sonore du
    sustain). Cap 12 s + skip inchangés (on enrichit la QUALITÉ de l'attente, pas sa durée).
  - **Selection** : « son de point » (`quill_tick` toutes les 0.6 s pendant « Merlin rêve les trois sentiers »)
    **retiré** — les points « … » restent visuels.
  - **QA prouvée par captures réelles (2026-06-30)** : harnais autoplay **réparé** (duck-typing — zéro réf
    statique aux scripts du jeu en mode `--script` ; fire-and-forget `_on_resolve` anti-suspension ; fenêtre
    minimisée hors capture + mode `--slow=N` pour figer l'issue à l'écran) → **gate R109 de nouveau MESURABLE
    et VERT : soak 200/200 + autoplay 3/3, 0 SCRIPT ERROR**. Captures : résolution même-fil + vignette + barre
    de progression (remplissage 8→40 %) + glitch corruption R75 confirmés à l'écran. Bug attrapé par le
    harnais : la vignette de fusion n'avait JAMAIS animé (ordre d'arguments `tween_method`+`bind`) — corrigé.
    Anti-générique : mémoire intra-run des fallbacks d'issue (`_fb_served`) — plus jamais la même variante
    servie deux fois dans une run.

- **R129 — Décor organique vivant + présences des piliers (2026-06-30, goal user)** :
  - **Refonte décor** (« moins design HTML ») : arbres organiques (troncs galbés, canopées en masses qui
    respirent, sway par arbre), sol en ondulations superposées + herbe animée, brume en rubans sinueux,
    ciel à bandes + étoiles + collines parallaxe, feuilles qui tombent (hiver = flocons), oiseaux furtifs,
    anneau runique lent autour de la lune, menhir penché + mousse. 100 % `_draw` procédural, palette canon.
  - **MERLIN détaillé** (toujours simpliste) : ombre au sol, ourlet de cape ondulant, capuche en pointe,
    bâton à orbe pulsant (phase du halo), étincelles runiques en orbite.
  - **Silhouettes des piliers** (spec panel, `docs/spec_v10.21_presences.md`) : 5 formes procédurales
    distinctes aux beats de Rencontre (`set_pilier`), x=0.345 (clairière), dessinées APRÈS la brume,
    matérialisation 1 s, re-skin de 8 motes signées, réaction lune (flash/mood, jamais angry). Sonde QA :
    `tools/probe_pilier.gd` (5 rendus plein écran en 15 s).
  - **Décor RÉACTIF au survol** (`_hover_f`) : arbres qui frémissent, lune qui s'illumine (halos + anneau),
    oghams du menhir qui scintillent d'or, herbe qui s'écarte du curseur. Off en reduce-motion.
- **R130 — Le partiel devient un CHOIX : « Encaisser / Pousser » (2026-06-30, Wave G, panel)** :
  sur toute issue PARTIELLE avec budget, l'application est DIFFÉRÉE — 2 boutons sous la vignette,
  ledger affiché (« Encaisser : Intégrité −2 · Corruption +N » / « Pousser : Réussite · Corruption
  +N+1 → projection »). Pousser = Intégrité épargnée, prix du partiel NON remboursé + PUSH_PRICE 1 ;
  budget **1 push/quête** (rechargé au répit, persisté R108) ; draft armé sur le degré BRUT ; coda
  procédurale écrite dans le même fil (R128). Mesure 200 runs : partiel effectif 31,6 % (cible 28-38),
  corrompu 14,5 % (≤18), morts 23 %→15 % (à surveiller), ~1,1 push/run.

- **R131 — Interventions du pilier PNJ (2026-06-30, Wave I, panel)** : le pilier REVIENT se mêler du
  sentier (1-2×/run) — planifié à la Rencontre (persisté R108, cap 2, jamais le climax), séquence signée
  (silhouette + nappe + réaction lune + LIGNE SIGNÉE écrite à la suite du fil R128). Effets par nature :
  Chœur/Chevalier **bénissent** une carte (tag temporaire VISIBLE ✦, consommé à la pose, canal
  `bonus_tags` de resolve → preview = résolution R120) · Enfant offre un tag REQUIS (l'aide innocente) ·
  Être/Compagnon = **pactes opt-in** (voie ouverte / pioche 1) contre +1 Corruption AFFICHÉE, Accepter/
  Refuser 1 geste, ignorables. API `run.add_corruption(n)` + `draw_extra(n)`. Soak miroir complet :
  corrompu 14,5 % stable, 200/200.

  - **Goal ACCOMPLI (2026-06-30/07-04)** : uniformisation scènes ✓ (End backdrop, hover partout) ; vagues
    v10.21 TOUTES livrées — I (R131) · L (4 axes) · G (R130) · A (5 nappes signées).

---

## §19 — R114 · Montée en gamme « Fondations » (2026-06-12)

> Décisions user (2 rounds AskUserQuestion, session 2026-06-12). La bible passe en **v2.0** :
> les sections §20-§24 ci-dessous deviennent canon. Sources legacy archivées (non-autoritaires) :
> `docs/archive/GAME_DESIGN_BIBLE_legacy_v3.8.md`, `docs/archive/DEV_PLAN_V2.5_legacy.md`.

- **Périmètre** : **polish d'abord** — pousser le 2D existant au maximum (animations, transitions,
  lisibilité, audio) AVANT le dégel des artworks génératifs et des biomes. Le canon MVP (§16)
  reste la base ; rien de ce qui suit ne contredit R1-R113.
- **4 dimensions retenues** (ordre d'exécution) : juice & animations → contenu & lore →
  artworks génératifs → audio complet (l'audio de base — SFX/stingers — arrive avec le juice).
- **Outillage studio (développement 100% Claude)** : 5 outils canon — skills `merlin-juice`,
  `merlin-audio`, `merlin-artwork` + `tools/sprite_anim_forge.py` (sprites animés) +
  `tools/create_agent.py` (factory d'agents). Voir §24.
- **Roadmap verrouillée** (gates mesurables par version) :

| Version | Objectif | Gate de sortie |
|---|---|---|
| v10.13.1 Fondations | Cohérence (bible v2.0, CLAUDE.md, archivage) + 4 outils + juice pack 1 + glitch Corruption | validate 0 · smoke 6/6 · soak 200/200 + autoplay 3/3 · captures avant/après |
| v10.14 Dé, Chemin & Équilibre | Dé pré-tiré 4 bandes + anim B8 · chaîne 2-3 quêtes · ramification v1 | soak archétypes 5×300 · GATE FINAL R120 (voir bloc v10.14 LIVRÉE ci-dessous) |
| v10.15 Juice complet & lisibilité | Transitions inter-écrans · beat map animée · reduce-motion complet | audit 4 piliers PASS · zéro hitch >33ms hors gen |
| v10.16 Audio complet | MerlinAudio (3 bus) · 12-16 SFX · 4 stingers · nappe réactive | 100% déclencheurs joués · peak < -3dB |
| v10.17 Contenu & lore | 50+ tags · combos curés (R79) · few-shot enrichis · piliers PNJ | guardian PASS 100% texte neuf · soak vert |
| v10.18 Artworks génératifs | 1 image/situation async+cache · portraits 12 cartes (R29/R48) | 12/12 + ≥20 situations · async sans hitch |
| v10.19 Polish release | Accessibilité fine (R99) · presets perf (R74) | audit accessibilité PASS |

**v10.13.1 LIVRÉE (2026-06-12, gates mesurés)** : 7 commits — bible v2.0 + archivage legacy +
CLAUDE.md v4.0 + art_direction réécrit · 4 outils (3 skills + create_agent.py, rapport initial
107 fiches/85 stale) + 16 SFX générés (sfx_forge, peak -3dB) · juice pack 1 (ghost de vol,
reflow d'éventail, voile de beat, boutons, sceau sonore) · glitch R75 câblé (4 paliers +
pastille). **Gates : validate 0 · smoke 6/6 scènes · soak 200/200 · autoplay 3/3 · captures
4 paliers · cascade Wave1+Wave2 GO · 2 HIGH review fixés.**

**v10.14 LIVRÉE (2026-06-12) — R120 « Dé, Chemin & Équilibre »** (cascade Wave1+Wave2 GO,
4 passes de tuning designer sur mesures n=300) :
- **Dé PRÉ-TIRÉ par rareté** (R20 préservé — JAMAIS de malus) : Commune +1 sur 2/6 · Rare 3/6 ·
  Épique 4/6 · Mythique garanti. Tiré UNE fois par beat → preview = résolution. Révélé UNIQUEMENT
  dans la fusion (anim B8, monolocalité R112). PARTIEL durci -1→-2.
- **Chaîne de quêtes** : run = 2-3 quêtes (40/60) de 2-5 beats (patterns fixes, diff 3 au climax
  FINAL seul) ; quêtes 2-3 = pool de sélection ; arc narratif PAR QUÊTE (begin_quest, fil rouge
  last_gist traversant) ; map et HUD comptent par quête ; **« répit du sentier »** : +2 Intégrité
  à chaque transition, +2 de plus si Intégrité ≤ 4 (amortisseur conditionnel).
- **Ramification v1** : l'avant-climax des quêtes k≥4 BASCULE (Epreuve↔Dilemme) si le degré
  précédent est échec/partiel — découverte AU beat (indice micro-narratif d'une phrase + déviation
  sur la map, jamais d'explication mécanique). Swap AVANT save → resume déterministe (R108).
- **GATE morts re-baseliné chaînes** : « le gate de mortalité est défini par beat joué, non par
  run complet » — optimal ≤12% · greedy/chaotic ≤27% · corrompu ≤20% (indicatif). Le plancher
  optimal garantit qu'un joueur discipliné n'est jamais puni par la longueur du chemin.
- **Mesures finales (n=300/archétype, 1500/1500 PASS)** : optimal 21.6%p/6.0%m · greedy 51.3/23.7 ·
  chaotic 47.4/22.7 · corrompu 47.0/16.7 — **gate 4/4 OK** · tag_ignorant 81/68 (bot adversarial,
  sans critère). Pools tags Epreuve/Dilemme élargis à 6 (couverture pleine atteignable).

---

## §20 — R115 · Direction Artistique (canon)

> Rapatrie et REMPLACE les sections DA legacy. Étend R28 (visuel minimaliste élégant) et R70
> (palette exacte & typo). **Source de vérité code : `scripts/game/merlin_visual.gd`** — la bible
> documente, le code fait foi ; toute divergence = bug à corriger côté code OU amender ici.

### Identité
**Flat rétro-minimaliste, parchemin sombre.** Encre et crème sur brun profond, accents or
(merveilleux) et violet (corruption). Pas de skeuomorphisme lourd, pas de photo-réalisme,
pas de néon : le jeu est un **grimoire vivant**. Ton visuel = merveilleux-inquiétant (R8).

### Palette canonique (miroir exact de `MerlinVisual`, verrouillée 2026-05-26)
| Constante | Hex | Usage |
|---|---|---|
| BG_PAGE | #1E1A14 | fond de page (game, menu) |
| BG_DEEP | #14100C | fond profond (end, options, selection, console) |
| SURFACE / INK | #2A2018 | panneaux sombres / trait & texte foncé sur crème |
| CREAM | #E8DCC0 | parchemin, texte clair, fond carte |
| GOLD | #C9A24B | accent or |
| GOLD_DARK | #8A6A2E | or sombre (degré réussite, captions discrètes) |
| GREEN | #7FA65C | vie / positif |
| GREEN_DARK | #4F6B3E | vert sombre (éclatante, console) |
| VIOLET | #7B4FA3 | corruption / échec |
| DIM_WARM | #9C8C6A | texte secondaire CLAIR (sur fonds sombres) |
| INK_DIM | #6E5A3C | texte secondaire FONCÉ (sur crème) |
| PANEL | #241E16 | surface de panneau (beat map) |
| BORDER_BRUN | #4A3B28 | liseré brun (panneau, carte Commune) |
| RING_BG | #3A3228 | fond d'anneau de jauge, nœud futur de la map |
| RARE_BLUE | #5A7A8C | rareté Rare, déviation map |

**Règle d'or : ZÉRO hex en dur hors `MerlinVisual`.** Les écrans aliasent
(`const COL_GOLD: Color = MerlinVisual.GOLD`) — un rebranding = UNE édition.

### Codes couleur sémantiques (miroir code)
- **Degrés** (`MerlinVisual.degree_color`) : échec=VIOLET · partiel=INK_DIM · réussite=GOLD_DARK · éclatante=GREEN_DARK.
- **Fusion** (`MerlinFx.FUSION_COLORS`) : échec #D04848 · partiel #D8A030 · réussite #E8C45A · éclatante #F4E0A8.
- **Raretés** (`MerlinCardView.RARITY_STYLE`, bordure = rareté, R52/R53) : Commune #4A3B28 (3px) ·
  Rare #5A7A8C (4px) · Épique #9A4FA8 (5px) · Mythique #C9A24B (7px + lueur or).
- **Archétypes d'effet** (`ARCHETYPE_STYLE`, bande basse) : Offensif #C0533A « OFFENSE » ·
  Défensif #4E7A6A « DÉFENSE » · Social #B58A3A « PAROLE » · Mystique #6B5A9C « MYSTÈRE » ·
  Corrompu #8B4FA3 « CORRUPTION ».
- **Badges effet actif** (`EFFECT_STYLE`, Rare+) : HEAL #5E7A42 ♥ · PURGE #6B4E8A ✦ · DRAW #3F5A6A ✚.

### Typographie
**Tout-serif** (R70). Tailles canon (`MerlinVisual.FS_*`) : narrative 36 · titre popup 40 ·
bouton 26 · caption 22 · hint 20. Jamais de taille inférieure à 16px pour une info de jeu (R112).

### Moods par type de beat (indicatif, teinte d'ambiance subtile)
| Type | Teinte dominante | Intention |
|---|---|---|
| Exploration | GREEN_DARK très voilé | curiosité, respiration |
| Rencontre | GOLD voilé | présence, écoute |
| Épreuve | DIM_WARM neutre | tension contenue |
| Dilemme | VIOLET très voilé | poids du choix |
| Climax | GOLD + vignette renforcée | apothéose |

La teinte est un **voile discret** (alpha ≤ 0.08) — jamais un changement de palette (anti-pattern :
casser l'identité parchemin). Le glitch Corruption (§23 et R75) se SUPERPOSE à ces moods.

---

## §21 — R116 · Animations & Juice (canon)

> Étend R110 (toute attente est animée ET skippable) et l'architecture §18 (MerlinFx : « le layer
> EST le node »). **Source de vérité code : `scripts/game/merlin_fx.gd` + `scripts/game/merlin_tween.gd`
> (R121) + constantes `MerlinVisual.DUR_*`.**
> Le skill `.claude/skills/merlin-juice/SKILL.md` est le mode d'emploi outillé de cette section.

### Vocabulaire canon (nom → durée → courbe → usage)
| Nom | Durée (s) | Trans/Ease | Usage |
|---|---|---|---|
| `tap` | 0.06 down / 0.10 up | QUAD out | press de bouton (scale 0.97→1.0) |
| `fast` | 0.12 | CUBIC out | hover carte (scale 1.18 + lift 30px), hover bouton (modulate 1.06) |
| `ui` | 0.22 | CUBIC in_out | vol de carte main↔combo (ghost, arc -18px) |
| `deal` | 0.24-0.28 | BACK out | distribution de cartes (stagger 0.05) |
| `discard` | 0.25 | QUAD in | défausse (slide -40px, rot -6°, fade, stagger 0.05) |
| `veil` | 0.20 in / 0.25 out | QUAD in/out | voile de transition de beat (BG_PAGE alpha 0→0.85→0) |
| `float_delta` | 0.9 | QUAD out | chiffre delta de jauge qui monte et s'évanouit |
| `pulse` | 0.3 | SINE in_out | pulsation d'un nœud (1→1.3→1, beat map, jauges) |
| `fusion` | 2.5-5.5 (par degré) | (FUSION_DURATIONS) | cinématique 4 phases — INTOUCHÉE, référence du genre |

### Règles (DO)
- **Tween lié au node hôte** (`node.create_tween()` ou layer auto-détruit type MerlinFx) — un tween
  ne survit JAMAIS à son node (anti « tweens orphelins », bug fondateur v10.2).
- `kill()` du tween précédent avant re-tween de la même propriété (`_tw` membre, pattern MerlinCardView).
- `pivot_offset = size/2` AVANT tout tween de scale/rotation.
- Overlays décoratifs : `mouse_filter = IGNORE` (un effet ne vole JAMAIS un clic).
- Stagger 0.04-0.06s pour les groupes (cartes, options de draft).
- Vérifier `MerlinVisual.reduced_motion` : si actif → durées ÷2, amplitudes ÷2, shake off,
  l'INFORMATION reste (indice statique conservé, R74/R75).

### Interdits (DON'T)
- Anim UI > 0.5s hors cinématique de fusion et veil.
- Anim **bloquante pendant la décision joueur** (la main et le combo répondent TOUJOURS au clic).
- `await` ajouté dans le flow logique de run pour une raison cosmétique (régression soak/autoplay).
- Polling `_process` pour de l'animation (tweens only). Particules : cap existant des sparks, pas de
  nouvelles émissions pendant le sustain LLM (CPU réservé à la gen, R58).

### R121 · Tween managé (MerlinTween) + banque de recettes + throttle `_process` (2026-06-21)
> **Source de vérité code : `scripts/game/merlin_tween.gd` + `scripts/game/merlin_fx.gd`.**
> Inspiration externe : KoBeWi `Godot-Tween-Suite` (lifecycle) + `TweenFX` (recettes juicy).

- **MerlinTween** (statique pur, méta-based) = sucre canon pour l'idiome « tuer le tween précédent de
  la même propriété avant d'en recréer un » (répété ~15× dans le code) : `MerlinTween.retween(node,
  key)` / `retween_looping(node, key)` / `kill_for(node, key)`. Le tween précédent de `(node, key)` est
  mémorisé en META sur le node → meurt avec lui, **zéro enfant ajouté à l'arbre**. ⚠ Ce n'est PAS un
  correctif d'orphelins (le code était déjà sûr par la convention `node.create_tween()`) mais une
  **réduction de boilerplate + garde anti double-boucle** ; les loopers (`float_bob`, `_pulse`) y passent.
- **Banque de recettes** (`merlin_fx.gd`, statics réutilisables) : `float_bob` (boucle lifecycle-safe via
  MerlinTween), `snap` (délègue à `pop`), `punch_pos`, `slide_in`, `slide_out`, `fade`. RÉUTILISENT les
  helpers existants — **zéro duplication** de shake/pop/ghost_flight/float_delta/spark_wave/beat_veil.
  Toute durée via `MerlinVisual.DUR_* * motion()`, amplitudes ÷2 en reduce-motion.
- **Throttle `_process`** (perf) — affine l'interdit ci-dessus : quand une animation procédurale est
  INÉVITABLE en `_process` (décor `_draw`, glow de carte Rare+ — non tween-ables), cadencer l'ÉCRITURE
  via un accumulateur delta (`_acc += delta ; if _acc < DT: return ; _acc -= DT`). Décor **15fps**,
  glow/sway carte **12fps** (−75 % de draw calls, −80 % d'ops glow/sway). Les PHASES (`_t`, `_sway_phase`)
  avancent au VRAI delta (courbe lisse) ; le **hover-parallax reste plein framerate** (feedback direct).

---

## §22 — R117 · Audio (canon)

### Pipeline SFX v4 (physical-modeling + loudness par categorie) - R156
tools/sfx_forge.py : modeles physiques numpy/scipy par famille (foley granulaire, harpe Karplus-Strong, modal
inharmonique, bol banded-waveguide, membrane bodhran, bourdon frotte, voix FM anti-repliement). Anti-aliasing
obligatoire (partiels sous Nyquist ; FM/waveshaping oversampling 4x). Reverb par convolution d'IR synthetique.
Normalisation tools/sfx_normalize.py (pur-python, pyloudnorm BS.1770-4, fallback vendorise) : highpass 25 Hz -> trim
-> loudness-match par categorie -> plafond true-peak -14 dBFS -> WAV 16-bit + manifest.json. Cibles LUFS/categorie :
tick -26 / foley -26 / drone -25 / accent -25.5 / impact -26 / stinger -24 / ending -24. Determinisme seed fixe (R119)
= WAV octet-identique ; gate CI = manifest (LUFS +/-1, true-peak <= -14, 0 DC) + double generation hashee. Round-robin
3 variantes pour deal/card_pick. Musique alignee (-24 LUFS, -12 dBFS). Remplace l'ancien gate peak <= -3 dB.

> Étend R30 (nappe réactive, SFX feutrés organiques, Merlin texte-seul) et R76 (drone celtique
> sans mélodie, stems additifs, stingers samples au MVP). Le skill `.claude/skills/merlin-audio/SKILL.md`
> outille cette section (génération procédurale `tools/sfx_forge.py` + MusicGen).

### Architecture
- **3 bus** : Master → Music, SFX. Curseurs Options (R74) mappés 1:1.
- **Autoload `MerlinAudio`** (cible v10.16) : `play_sfx(id)`, `play_stinger(degree)`,
  `set_corruption_layer(level)` ; pré-chargement des WAV au boot.
- **Ducking** : musique -6dB pendant un stinger, retour en 0.8s.
- **Défauts** : Master 80% · Music 60% · SFX 80%. Peak ≤ -3dB sur tout asset (gate).

### Catalogue SFX v1 (id → matière → déclencheur)
| Id | Matière (feutrée-organique) | Déclencheur |
|---|---|---|
| `card_pick` | papier glissé court | carte prise en main / hover marqué |
| `card_play` | papier posé + souffle | carte posée au combo |
| `card_discard` | papier froissé doux | défausse |
| `deal` | éventail de papier | distribution (1 par carte, pitch varié ±5%) |
| `button_tap` | bois mat | press de bouton |
| `gauge_up` | goutte d'eau claire | Intégrité +N |
| `gauge_down` | corde sourde | Intégrité -N |
| `corruption_tick` | murmure granuleux | Corruption +N |
| `seal_stamp` | sceau de cire | apparition du sceau de degré (R112) |
| `beat_turn` | page tournée | transition de beat (veil) |
| `draft_reveal` | carillon feutré | révélation des options de draft |
| `whisper_threshold` | souffle dissonant | franchissement de palier Corruption (R75) |

### Stingers (4, par degré — samples courts ≤2.5s, R76)
échec = corde frottée descendante · partiel = accord suspendu · réussite = accord chaud résolu ·
éclatante = accord ouvert + harmonique haute. Joués à l'apparition du sceau (R112), ducking actif.

### Musique
- **Menu** : thème celtique lent existant (`music/theme/merlin_main_theme.wav`, MusicGen, boucle crossfade).
- **Run** : drone celtique SANS mélodie (R76), 2 couches additives — couche basse permanente +
  couche granuleuse dissonante dont le volume suit la Corruption (palier R75 → +6dB par palier).
- **Pipeline** : `tools/musicgen_theme.py` (prompt celtique + crossfade equal-power). Jamais de
  musique à mélodie forte pendant la lecture de prose (la prose est reine).

---

## §23 — R118 · Lisibilité & Accessibilité (canon)

> Étend R18 (≥44px tactile-ready), R54 (typewriter skippable), R74 (Options : reduce-motion,
> contraste, presets), R75 (indice statique), R99 (accessibilité fine). Rapatrie les « 4 piliers »
> legacy, adaptés. **Tout agent UI/UX/game design vérifie ces 4 piliers** (cascade §18 de CLAUDE.md).

### Les 4 piliers UX
1. **FACILE** — toute action en ≤2 gestes (R111 : clic=révéler, clic=continuer).
2. **ÉVIDENT** — l'intention se lit en <2s sans tutoriel (le sceau DIT le degré, la bordure DIT la rareté).
3. **MINIMAL** — aucun élément UI sans rôle actif ; l'info ne vit qu'à UN endroit (anti « info ×2 », R112).
4. **TACTILE + DESKTOP** — cibles ≥44×44px (R18), pas de hover-only (le hover ENRICHIT, ne révèle
   jamais une info exclusive), retour visuel ≤100ms (`tap`).

### Contrastes canon
Texte principal : CREAM sur BG_PAGE/SURFACE (ratio élevé, vérifié). Texte secondaire : DIM_WARM
sur sombre, INK_DIM sur crème — **jamais l'inverse** (les deux gris sont calibrés par fond).
Une info de degré/danger n'est JAMAIS portée par la couleur seule → couleur + forme/libellé
(sceau circulaire + libellé ≥16px, R112 ; daltonisme R99).

### Reduce-motion (R74) — sémantique précise
Atténue, ne supprime pas l'information : durées ÷2, amplitudes ÷2, shake/tremblements OFF,
glitch Corruption plafonné à 0.1 d'intensité + **indice statique conservé** (teinte VIOLET
alpha 0.06 + pastille près de la jauge, R75). Le typewriter reste skippable (R54), l'option
« afficher direct » (R74) coupe tout différé de texte.

### Garanties
Zéro timer caché (R99) · tout différé est skippable (R110) · FR seul au MVP (R74) ·
préférences persistées (Options, R74) · clavier de base au MVP, manette post-MVP (R99).

---

## §24 — R119 · Pipeline Assets & Outillage studio (canon)

> Le studio se développe **entièrement depuis Claude** : chaque domaine a un outil dédié,
> documenté, avec gate de sortie. Hiérarchie d'outils : MCP godot-mcp (éditeur live) →
> CLI `python tools/cli.py godot …` (headless) → Edit/Write fichiers → scripts ad-hoc.

### Les 5 outils canon
| Outil | Rôle | Gate de sortie |
|---|---|---|
| `.claude/skills/merlin-juice/` | vocabulaire d'animation §21 + helpers MerlinFx + MerlinTween (R121) | validate + smoke + soak/autoplay + capture avant/après |
| `.claude/skills/merlin-audio/` | SFX procéduraux (`tools/sfx_forge.py`) + MusicGen + catalogue §22 | écoute + peak ≤ -3dB + déclencheurs joués en autoplay |
| `.claude/skills/merlin-artwork/` | images par situation/carte (gravure sépia R29) + cache | QA visuelle + async sans hitch + fallback sans-image intact |
| `tools/sprite_anim_forge.py` | sprites animés procéduraux (feuille + SpriteFrames `.tres`, palette canon) | `python` run + `asset_validator --type sprite_sheet` + import Godot 0 erreur |
| `tools/create_agent.py` | factory d'agents .md + registry AGENTS.md | `--validate` vert sur le parc |

### Conventions assets
- **Artworks** : `assets/artwork/cache/<sha1(prompt)>.png` + `manifest.json`
  (`{hash, prompt, model, date, approved}`) — toute génération est REJOUABLE et traçable.
- **Sprites animés** : `assets/sprites/cache/<template>_<sha1>_sheet.png` + `_frames.tres` + `manifest.json`
  (gitignoré, régénérable) — feuille horizontale, `cell × n ≤ 8192px` (limite import Godot), boucle seamless.
- **SFX** : `audio/sfx/<id>.wav` (44.1kHz mono), ids = catalogue §22 exactement.
- **Musique** : `music/<contexte>/…` (theme/base/loop existants).
- L'image ne bloque JAMAIS le texte (fade-in async, R29 « live ») ; le son ne bloque jamais l'input.

### Gates par type de changement
| Type | Gate minimal |
|---|---|
| Docs/bible | revue merlin_guardian + meta_bible_guardian, 0 réf orpheline |
| Code runtime flow | validate 0 + smoke scènes touchées + soak 200/200 + autoplay 3/3 (R109) |
| Code visuel pur | validate 0 + smoke + capture avant/après |
| Shader | test isolé (scène vide) AVANT câblage, commit séparé, fallback visible=false |
| Asset audio/image | gate de l'outil (§24) + intégration smoke |

### Cascades agents obligatoires (rappel CLAUDE.md)
Game design → Wave 1 (game_designer + ux_flow + game_playtester) puis Wave 2 (game_design_auditor,
4 piliers §23). Contenu → art_direction → content_card_writer → merlin_guardian. Le Game Director
tranche les ambiguïtés créatives ; les piliers IMMUABLES (§1) escaladent à l'utilisateur.

- **R157 : ZERO CADRATIN player-facing + repair_accents LLM (2026-07-14, petit) - zero-balance** :
  66 tirets cadratin U+2014 retires des STRINGS affiches au joueur (evocations de cartes, situations/ponts/
  epilogues/preambules, interventions de piliers, labels de draft, menu) -> ponctuation FR (`:`/`,`/`;`/`.`)
  selon le sens. Les exemples few-shot de merlin_prompt_builder aussi de-cadratinises (cause racine : le LLM
  imitait la maniere et sortait des cadratins). Commentaires de code laisses (dette a part). 2 cadratins
  fonctionnels conserves (merlin_prose:46 = jeu de char qui STRIPPE les cadratins LLM ; scenario:849 = push_warning).
  Nouveau `MerlinProse.repair_accents(text)` : dico conservateur 35 mots (mot-entier, casse preservee) reparant
  les accents que Gemma lache (repond->repond accentue, foret->accentue, etc.), applique dans clean_prose +
  clean_selection (chokepoints de toute narration/titre LLM affiches). Regle canon : jamais de U+2014 dans le
  texte joueur ni le nouveau code. Balance ISO (soak 200/200, resolve()/§K intacts).

- **R156 : AUDIO v4, modelisation physique + normalisation loudness (2026-07-14, refonte SFX) - zero-balance** :
  Bruitages juges mauvais car procedural NAIF (sinus+FM+bruit filtre = meme moule pour tout, reverb Schroeder boxy
  universelle, aliasing, normalisation au PEAK seul donc loudness incoherente 10-15 LU). Refonte tools/sfx_forge.py en
  MODELISATION PHYSIQUE numpy/scipy : harpe Karplus-Strong (Re/DADGAD), banque modale inharmonique (cloches),
  bol chantant banded-waveguide, membrane bodhran, bourdon frotte, foley granulaire, voix FM anti-repliement.
  Anti-aliasing (partiels sous Nyquist, FM/waveshaping oversampling 4x). Reverb par convolution d'IR synthetique.
  SYNTH_MIX=0.15 (harpe/bol 100% acoustiques). Normalisation tools/sfx_normalize.py (pur-python, pyloudnorm BS.1770-4,
  fallback vendorise) : highpass 25 Hz -> loudness-match par CATEGORIE -> plafond true-peak -14 dBFS. Determinisme :
  seed fixe = WAV octet-identique (R119, double generation hashee). 30 sons (24 canon + slider_tick/question_transition/
  ogham_chime/magic_reveal ex-muets + variantes round-robin deal/card_pick). music_forge aligne (-24 LUFS, -12 dBFS).
  Sous -14 dBFS la fenetre de loudness ~2 LU (physique) ; contraste par duree/densite. Evenements ~8 dB plus doux
  qu'avant : monter sfx_vol/bus a l'ecoute si besoin. Amende le gate audio (-3 dB -> -14 dBFS + LUFS/categorie).

- **R155 : VOIX DE MERLIN + biome-agnostique (2026-07-13, retours playtest) - zero-balance** :
  (D1) plus de caption de transition « Le sentier se dessine sous mes doigts » : `change_scene_merlin` ne cree
  la bulle QUE si une vraie replique vivante est fournie ; le fondu visuel reste, le filet canne disparait.
  (D2) TEXTES BIOME-AGNOSTIQUES : la foret n'est qu'UN biome parmi d'autres (regle permanente) -> tout texte
  GENERIQUE (tuto TXT_*, proposition « Premier pas sur le sentier », PUSH_CODAS, DEFAULT_PITCH) ne dit plus
  « foret » mais « le lieu » (entite personnifiee) / « le sentier ». Les banques *_BY_BIOME (foret/falaises)
  restent biome-keyees (legitimes). (D3) VOIX DE MERLIN distincte : `MERLIN_BLUE` (A6CFF0, contraste ~10:1) +
  `merlin_speech_style()` (cartouche bleu-nuit borde) + `merlin_speech_font()` dans merlin_visual.gd. Appliquee a
  TOUTE parole de Merlin (tuto, proposition, cadrage d'intro world_setup_short) ; le RECIT de scene reste creme
  (voix du monde), les piliers/PNJ gardent leur style. Anti-bleed : `_restore_encart_cream` (tween, pas de snap)
  remet l'encart partage en creme a chaque beat + au resume. Fonte ornee Morris reservee aux surfaces courtes
  (proposition) ; les paragraphes longs gardent la fonte de theme (lisibilite §23), la distinction portee par
  couleur + cartouche. Amende R149/R154 (le cadrage d'intro = voix de Merlin bleutee). Balance ISO. Restes
  signales : balayage cadratin des textes player-facing pre-existants + accents LLM (« repond ») en post-process.

- **R154 : VAGUE A, lisibilite du beat (2026-07-13, retours playtest) - 4 fixes zero-balance** :
  (A1) l'intro se redigeait HORS de la capsule (course de layout au 1er frame) -> `_begin` passe coroutine,
  `await get_tree().process_frame` avant le 1er typewriter (precedent merlin_menu). (A2) le niveau d'action
  (+N talent/maitrise) est desormais TOUJOURS visible des l'apparition des tuiles (meme +0 ; garde >0 retiree,
  refresh au frame 0) - renverse le pilier MINIMAL sur ce point. (A3) draft de greffe : desormais APRES le
  reveal de la scene+main (plus contre une main estompee) ; save unique atomique fin de beat (index + greffe,
  R108) ; dedup `offered_graft_ids` persiste (additif, defaut {}, reset new_run) + banque jeu elargie
  `graft_bank_generic_varied` (fini les 3 rolls identiques) + verbe cible nomme sur la carte. (A4) le monologue
  de Merlin apres Nouvelle Partie est REMPLACE : `world_setup_short(biome)` (cadrage 1-2 lignes) puis le tuto
  anime est PROPOSE a chaque nouvelle partie (`should_offer_tuto` -> true, beat 0 uniquement) ; refus -> entree
  directe dans la 1re scene ; save-avant-beat-1 preserve. Amende R149 (tuto propose a chaque run, plus one-shot).
  Balance ISO (resolve()/§K non touches : soak 200/200 identique). Reste : Vague B (contenu/quetes) puis C (2d6
  + 5 actions + §K).

- **R153 : RETOURS PLAYTEST, fix biome + maitrise par usage + ligne meca + objectif de quete (2026-07-12, N5, revue joueur)** :
  4 chantiers issus du playtest. (1) FIX BIOME (balance-neutre) : selectionner un autre biome donnait encore des
  scenarios de Broceliande. Cause double : SEL_FALLBACK etait biome-agnostique (servi >95% du temps ET pool de la
  chaine de quetes) et le prefetch de selection tournait AVANT le choix du biome. Fix : SEL_FALLBACK_BY_BIOME
  {foret, falaises} + _sel_fallback_pool() par _run_biome() aux 3 call-sites, et invalidate_selection() a _on_biome_picked
  (re-prefetch avec le bon biome). Titres Falaises : Le Phare qui Compte / Le Chant du Ressac / L'Epave qui Revient.
  (2) MAITRISE PAR USAGE (§K RE-DERIVE) : chaque verbe (Sens/Force/Verbe/Instinct) monte quand on le JOUE ; paliers
  usage {3 -> +1, 6 -> +2, cap +2} FONDUS dans skill_mod existant (talent + maitrise, PAS un 5e terme d20). Jauge 2
  segments sous le verbe dans les 4 briques. verb_usage deja persiste -> save additive, zero bump SAVE_VERSION.
  Levier §K : ECLAT_MARGIN 8 -> 9 (la maitrise poussait eclatante a 14,8% contre plafond 15% ; levier chirurgical qui
  ne touche QUE le seuil eclatante). Soak 200/200, 4 bandes IN (echec 6,5 / partiel 29,9 / reussite 51,3 / eclatante
  12,3), morts par archetype PASS. (3) LIGNE MECA A LA RESOLUTION : sous le verdict, traduction en clair du geste
  « Vous scrutez les environs (Sens) · d20 18 +3 = reussite eclatante · Integrite +0 » (+ clause maitrise si un palier
  est franchi). LEVE R144 (modificateurs implicites) : decision joueur assumee de rendre la meca lisible. (4) OBJECTIF
  DE QUETE LISIBLE + prose moins cryptique : ligne « Quete : <titre> · etape N/M » en tete d'encart (bug latent corrige :
  scenario.quests etait un int lu as Array) ; build_intro cite le PITCH (l'action concrete) et une annonce de quete au
  1er beat d'une nouvelle quete evite le changement d'objectif en silence. Amende R140 (l'action reste en « Vous »).

- **R152 : LA SESSION TENABLE, pause + lecture reglable + clavier + preambule monde + audio biome/fin (2026-07-12, P3, revue joueur panel 6)** :
  7 chantiers de confort de session (zero balance, soak 200/200 iso : defauts = comportement historique). (1) MENU PAUSE
  (Echap) : overlay CanvasLayer PROCESS_MODE_ALWAYS (get_tree().paused), Reprendre / Options / Menu principal ; « Menu
  principal » save-safe R108 (aucun save mi-beat, la save disque reste debut-de-beat) ; Echap coordonne avec MerlinOptions.
  (2) PACK LECTURE (persiste [reading]) : vitesse typewriter (Lent/Normal/Rapide/Instantane) + taille de texte
  (Standard/Confort), cablee dans le typewriter de merlin_game ET merlin_end ; defauts = Normal 30 c/s + 36px (iso).
  (3) CLAVIER desktop : Espace/Entree = skip typewriter SINON valide le bouton principal (additif au tactile, no
  hover-only, ne consomme que si action). (4) PREAMBULE DU MONDE : world_preamble() prefixe l'intro (monde/Graal, qui,
  biome, attente), une fois par run, relie le compteur de Fragments (R151). (5) VARIANTE MUSICALE FALAISES : music_forge
  _gameplay_falaises (drone maritime), WAV regenere, selection par biome (cross-fade, zero superposition). (6) STINGERS DE
  FIN : sfx_forge 3 recettes (accomplissement/mort/corrompu), WAV regeneres (§22, -14 dBFS), joues a l'entree de MerlinEnd
  par end_type. (7) LISIBILITE DES SLOTS POSES (F2) : pastille d'intention revelee A LA SELECTION (tap, jamais au survol
  §23 pilier 4), zero nom de tag brut (R147). Sert §23 (session tenable, lecture, desktop).

- **R151 : LA RECOMPENSE VISIBLE, draft lisible + MerlinEnd rempli + methode meta (2026-07-06, P2, revue joueur panel 6)** :
  4 chantiers de LECTURE de la recompense (zero balance, soak 200/200 iso : degree_counts/corruption_max lus seulement par
  end_recap). (1) DRAFT LISIBLE (CDC-UX-12) : une ligne d'effet en francais commun sous chaque carte de greffe (roll « +N a
  tes jets sur ce verbe » / tag « ce verbe repondra a plus de scenes » / charge HEAL-PURGE-DRAW chiffree), et le noeud de
  talent NOMME le verbe (« +1 · PARLER »), titres de-tronques. (2) MERLIN END REMPLI (CDC-UX-18 / GD-40) : recap grave de la
  run (epreuves, degres avec accord singulier/pluriel, corruption au plus fort, greffes posees, verbes renforces, faits
  marquants) + la VOIE de la Carte Destin enfin REVELEE (« Cette nuit, tu as marche La Voie de Miel : Epique »). (3) EPILOGUES
  VARIES (CDC-NAR-05) : banque EPILOGUE_BY_END_BIOME (fin x biome x ton, 24 variantes teintees momentum), fin de l'epilogue
  recycle ; coda LLM prioritaire conservee. (4) META 1er cran NON-RESTRICTIF : fragments du Graal persistes
  (+1 / accomplissement, N/12), preambule au menu, CHRONIQUES v1 en lecture (palmares + derniere Voie), entree CARTES morte
  retiree. Les Falaises restent OUVERTES (gating d'un biome reserve a l'utilisateur). Restes revue joueur : F2 (tooltip slots
  poses) et P3 (session tenable / lecture / audio).

- **R150 : LE BEAT QUI CLAQUE, lisibilite et drame de la resolution (2026-07-06, P1, revue joueur panel 6)** :
  7 corrections de RENDU PUR (zero balance, soak iso) : (1) AFFINITE dorée FRANCHE et GRADUÉE : lueur du
  CADRE des cartes/tuiles a 3 crans (0 rien / 1 nette / 2+ intense + pulse lent), remplace le souligné 3px ;
  (2) ORDRE DRAMATIQUE geste > dé > pause > verdict : la fusion est NEUTRE (ne lit plus le degré, teinte
  GOLD unique : elle ne spoile plus), pose du d20, micro-pause de lecture 0,35 s, PUIS halo (renforcé ~x2,
  2 couches, 2 pulses persistants) + stinger de degré (joué AU halo) ; le dé est hébergé chez l'HOTE (survit
  au layer fx) ; (3) italique d'ACTION à FS_NARRATIVE (le geste du joueur pese autant que la réaction du
  monde) ; (4) éventail DE-TRONQUÉ (pas clampé : nom francais entier lisible jusqu'a 8 cartes) + réserve de
  titre ; (5) gemme VIOLETTE si cout corruption > 0 (la rarete reste au liseré R133) ; (6) ANNEAUX identifiés :
  glyphe procédural au centre (coeur = Intégrité, spirale voilée = Corruption) + liseré de présence a 0 ;
  (7) « + N » talent GOLD flottant pres de la pill au gain (degré FINAL, R130) + halo GOLD prolongé du d20
  sur l'éclatante (célébration rare). Amende R144 (halo/sequencage) et la mise en scene de R135 (fusion
  neutre). Restes de la revue joueur : P2 (récompense visible/MerlinEnd/méta) et P3 (session/lecture/audio).

- **R149 : GUIDE DE MERLIN, tutoriel proposé au premier run (2026-07-06, N4-TUTO)** : à la toute première
  traversée (chronique vierge : jamais proposé ET runs_played==0, OU ré-armé), Merlin PROPOSE dans la ligne
  d'état (non-modal, R136) : « Premier pas dans la forêt, Voyageur... je te guide ? » [Guide-moi]
  [Je connais le chemin] (≥44px). Refus persisté : jamais re-proposé ; ré-armable depuis Options (« Revoir
  le guide de Merlin »). Accepté : `merlin_tutorial.gd` (CanvasLayer 120, machine à états, textes AUTHORED à
  la voix de Merlin, zéro LLM) prend la main : spotlight zone par zone (dim + cadre GOLD), Merlin POSE
  lui-même 1 verbe + 1 rune sur le VRAI premier beat (choix appliqués pour de vrai, R120 intact), lance la
  résolution, explique d20/halo/pill/jauges/draft, **un CLIC par étape** (caret), « Passer le guide » à tout
  moment. R108 : un run repris ne repasse JAMAIS par le guide. Harnais : l'autoplay refuse le guide (branche
  duck-typée). Flags additifs `tuto_*` dans MerlinChronicle. Robustesse : poll-loops (zéro await
  tween.finished), garde `_ok()` uniforme incluant run.ended.

- **R148 : PREMIÈRE RÉSOLUTION INSTANTANÉE + robustesse fusion (2026-07-06, N4-BUG, bug playtest prouvé)** :
  (a) le prefetch de résolution refusé pour « modèle pas prêt » est MÉMORISÉ et RELANCÉ au signal
  `model_ready` (epoch-gardé, CONNECT_ONE_SHOT) : le LLM peut gagner dès que le modèle charge ; (b) l'attente
  de fusion est COURT-CIRCUITÉE quand rien ne peut arriver (`is_resolution_incoming` : ni cache ni gen en vol
  pour la signature exacte → fallback immédiat ; décision sticky au clic ; une gen EN VOL garde sa fenêtre
  cap 12 s). Mesuré : clic→issue à froid **14,5 s → 2,2 s** ; pose longue → la prose Gemma est réellement
  servie. (c) Softlock latent corrigé : `await tween.finished` sur un tween DÉJÀ FINI sous charge CPU =
  suspension définitive → TOUJOURS garder `if tw.is_running():` avant l'await (audit complet merlin_fx/dice).
  (d) Hint tuto recentré (les setters de taille réécrivent les offsets en Godot 4 : re-poser
  PRESET_FULL_RECT APRÈS chaque set de texte) ; (e) d20 remonté en zone décor (vp.y*0.19), plus de
  recouvrement de la prose. Leçons KB/mémoire capturées.

- **R147 : CARTES-RUNES OGHAM + TAGS INVISIBLES (2026-07-06, N4-RUNES, user « enlève les dénominations
  hasardeuses, jouons des runes »)** : les cartes de TRAIT sont des RUNES celtiques inventées : glyphe de
  style ogham dessiné PROCÉDURALEMENT (`merlin_glyph.gd` : tige + 1-5 traits, motifs 0-46 canon / 47
  générique / 50-74 tag-concepts, style gravure) + **nom FRANÇAIS compréhensible en haut** (Calme, Voix,
  Poigne, Adresse…, jamais égal à un mot de tag canon) + **nom de rune CELTE INVENTÉ en bas** (Sioulan,
  Gwezhen, Dornek, Braën… table complète `MerlinCard.RUNES`, 47 entrées). Champs additifs
  display_name/rune_name/rune_pattern (save legacy OK) ; `card_name` reste INTERNE (ids, prompts LLM).
  **Le jargon de tags disparaît de l'UI** : pastilles des cartes, pastilles de base des tuiles, chips de
  requis au-dessus de la situation : SUPPRIMÉS. Les tags restent 100 % mécaniques (couverture, whitelist §F,
  moteur d20). Lisibilité (§23 ÉVIDENT) : **feedforward GOLD** sur les cartes de la main qui couvrent un
  requis + preview de résolution (R120) = seuls signaux d'affinité. Badge bénédiction neutre « ✦ Bénie »
  (amende R131 : plus de mot de tag). Fix R147bis : appels inter-classes par `preload` (const _Glyph) au
  lieu du nom de classe : un appel statique `MerlinGlyph.f()` créait un FLAKE de compilation intermittent
  (1 boot/24, cascade softlock) : gate anti-flake bootcheck 20/20 requis sur toute vague touchant les
  dépendances de scripts (KB 2026-07-06).

- **R146 : CONTINUITÉ + RÉACTIVITÉ narratives (2026-07-06, N3-V1, user « les scénarios ne suivent pas, tout décroché en event »)** :
  le PONT inter-beats supprimé en N1 (R140) est RESTAURÉ mais INTELLIGENT (non-générique) : composé dans
  `note_outcome` depuis degré x biome x momentum (banque `BRIDGE_BY_DEGREE_BIOME`, 2e pers. présent, il PORTE
  l'empreinte du résultat du beat précédent et enchaîne, jamais « vous poursuivez votre route »), préposé à la
  situation `n>1` dans `build_situation`. La continuité ne dépend donc plus du seul `last_gist` LLM (qui perd
  la course >95 % du temps). **MOMENTUM narratif** (`merlin_run.momentum` : +1 réussite/éclatante, -1
  échec/partiel, clampé -3..+3, additif save, reset new_run) colore le TON du pont (sombre <= -2, élan >= +2)
  SANS aucun effet mécanique : §K INCHANGÉ (soak iso, chiffres bit-identiques ; le momentum MÉCANIQUE =
  difficulté est reporté en Vague 2). **CLIMAX ancré sur le but** : `build_situation` nomme `quest_title` au
  climax (« Au bout, ce que « X » promettait vous attend enfin. ») pour refermer l'enjeu posé au début.
  `probe_prose` étendu (ponts biome-purs, 2e pers., zéro « poursuivez/continuez votre route »). RÉVISE le
  « pont supprimé » de R140 (il revient, spécifique). Vague 2 : MULTI-ÉTAPES (la situation PERSISTE tant qu'on
  ne réussit pas : échec/partiel gardent la scène ouverte + escalade, réussite/éclatante ferme ; re-dérive §K).

- **R145 : SECOURS biome + combinaison (2026-07-05, N2a, user « trop court, pas lié au scénario/biome »)** :
  Gemma (~1 tok/s) ne finit jamais sa résolution LLM (~150 tok) dans la fenêtre ~20 s → c'est TOUJOURS le
  secours procédural qui s'affiche. Ce secours devient **biome-aware** et **combinaison-aware** : (a)
  `SITU_FALLBACKS_BY_BIOME` + `FALLBACK_ARCS_BY_BIOME` (arcs FALAISES dédiés — phare/épaves/marée/sel/grève —
  en plus des arcs forêt ; **tags partagés** `FALLBACK_ARC_TAGS` → scène ⇄ tags ⇄ cartes reste aligné) ;
  `_fallback_situation`/`_fallback_arc` lisent `run.biome`. (b) **Résolution COMPOSÉE** :
  `fallback_resolution(degree, situ_type, played_cards, biome)` = `[i]ACTION[/i] CONSÉQUENCE` où ACTION vient
  du REGISTRE dominant du combo (`RESO_ACTION_BY_REGISTRE` : PAROLE/FORCE/PERCEPTION/PROTECTION/OMBRE) et
  CONSÉQUENCE de (degré × biome) (`RESO_CONSEQ_BY_DEGREE_BIOME`, imagery mer/vent/phare vs bois/mousse) ;
  moment fort → 2e conséquence ample. Le secours reflète donc CE QUE vous avez fait + OÙ + le degré (mais
  ne cite pas l'élément EXACT de la scène — ça, c'est N2b). `probe_prose` CATALOG_GATE étendu (zéro mot
  forestier dans les banques falaises, action « Vous », compo valide). Suite : **N2b streaming LLM (TEC-01)**
  pour le vrai texte sur-mesure qui nomme la scène (« l'eau noire se referme sur ce que vous avez pris »).

- **R144 — VISUEL d20 + HALO réussi/raté (2026-07-05, v2-W4 — « le dé tourne pour voir la réussite »)** :
  `MerlinDice` passe du d6 au **d20** — silhouette icosaédrique fausse-3D (hexagone + facettes) portant un
  GROS chiffre **1-20** centré (charte gravure), culbute (nombres 1-20 qui défilent) → ralenti → pose (~1,15 s
  ×motion()). À la pose, un **HALO** : VERT `HALO_SUCCESS(#6E9450)` si le jet réussit (`res.success`), ROUGE
  `HALO_FAIL(#A5453A)` sinon (glow diffus + liseré coloré, pulse qui reste visible). Nouvelle signature
  `MerlinDice.roll(parent, final_face, success)`. Le flash OR « le sort a souri » (ancien `die_mod`) et le
  liseré de rareté du JET sont SUPPRIMÉS — le halo binaire porte l'issue, la pill porte le degré. Les
  modificateurs/DC restent **IMPLICITES** (décision verrouillée — pas de tableur à l'écran). Le dé chevauche
  l'encart (R135/R136 inchangés). Mode INDICE de tuile (`hint`/`rim_for_rarity`, R133) préservé intact.
  reduced_motion : face directe + halo plein + `done` émis (anti-softlock). **Clôt la Vague 2** (d20 R141 +
  talent R142 + greffes-jet R143 + visuel R144) — le pivot JDR « d20 + arbre de talent » est complet et jouable.

- **R143 — GREFFES « +N au jet » (2026-07-05, v2-W3 — graft_bonus du d20)** : la greffe `kind:"die"`
  (ancien « +1 bande de dé », INERTE depuis le pivot d20 R141) est migrée en `kind:"roll"` (« +N au jet ») :
  `graft_bonus` d'une résolution = somme des `amount` des greffes roll posées sur l'action jouée (câblé
  aux 2 call-sites resolve, R120). 5 greffes migrées (générique + chevalier + enfant). `ROLL_BONUS_DEFAULT=1`
  (tuné : +2 poussait l'éclatante hors bande quand talent R142 + greffes STACKENT sur le même jet). Badge
  GOLD « ✦ +N JET » sur la carte-greffe (draft) et « +N » sur le slot de tuile. Save legacy `kind:"die"`
  TOLÉRÉE au load (comptée comme roll, R108) — pas de bump SAVE_VERSION. §K tient avec le stack (talent +
  greffes) : échec 6,3 · partiel 31,2 · réussite 49,2 · éclatante 13,2 — toutes IN ; morts archétype PASS.
  ⚠ Arbitrage design ouvert : « Le Jouet Offert » (Enfant) accorde désormais un vrai +1 comme toute greffe
  roll — à trancher si l'Enfant-tentateur doit garder un « cadeau médiocre ». Reste : W4 visuel d20 + halo.

- **R142 — ARBRE DE TALENT IN-RUN (2026-07-05, v2-W2 — « nos points de compétence »)** : un `skill_mod`
  in-run alimente le jet d20 (R141). **Par verbe** (PERCEVOIR/AGIR/PARLER/RESSENTIR) : `talent[verbe]` 0..5 ;
  `skill_mod` d'une résolution = `talent[verbe joué]` (câblé aux 2 call-sites resolve, R120). **Points**
  gagnés au degré (réussite +1, éclatante +2 ; partiel/échec 0), pool `talent_points`. **Allocation AU DRAFT** :
  quand `talent_points ≥ TALENT_COST(2)`, un nœud de talent **remplace UN des 3 choix** de greffe (cible =
  verbe le plus utilisé non-cappé) — rendu comme carte Mythique GOLD « ✦ +N TALENT », **prise en 1 geste**,
  ZÉRO nouvel écran/modal (R136). `TALENT_CAP=5`. Les 4 tuiles affichent leur « +N » GOLD (caché à 0, MINIMAL).
  Save ADDITIF (talent/talent_points/verb_usage, pas de bump SAVE_VERSION), persisté à la prise (R108).
  IN-RUN seulement (reset à new_run, pas de méta cross-run). §K tient SANS lever (talent modélisé : échec 6,6 ·
  partiel 32,6 · réussite 49,5 · éclatante 11,3 — toutes IN ; morts archétype PASS ; ~1,3 nœud/run). W3 :
  greffes « +N au jet » (graft_bonus). W4 : visuel d20 + halo.

- **R141 — RÉSOLUTION d20-vs-DC (2026-07-05, v2-W1 — pivot JDR « le dé tourne pour voir la réussite »)** :
  la résolution passe du modèle « couverture de tags + dé d6 à bandes » à un **jet de d20 contre un seuil
  de difficulté (DC)**. Formule : `total = d20(1-20) + skill_mod + graft_bonus + COVER_PER_TAG×(tags requis
  couverts) + synergy_bonus`, comparé à `DC_BY_DIFF = {1:11, 2:15, 3:18}`. Degré par **marge** (total − DC) :
  échec si total < DC−2 · partiel si DC−2 ≤ total ≤ DC−1 · réussite si DC ≤ total ≤ DC+4 · éclatante si
  total ≥ DC+5. **Planchers durs** : nat 1 → échec, nat 20 → éclatante. Constantes : `COVER_PER_TAG=3`,
  `SYN=2`, `DIE_FALLBACK=10` (call-sites sans dé). La couverture des tags requis (le geste ADAPTÉ) et la
  synergie action+trait deviennent des **bonus au jet**, plus la source directe du degré. R120 tenu (preview
  = résolution : même dé, mêmes mods). `skill_mod`/`graft_bonus` sont des **paramètres à défaut 0** en W1 ;
  câblés par W2 (arbre de talent in-run) et W3 (greffes « +N au jet »). **Supersède** R135 côté « zéro
  chiffre » (le d20 est visible — W4) et **R139/§K entièrement re-dérivé** : §K re-calibré sur d20 (soak 300 —
  échec 6,8 / partiel 32,9 / réussite 49,7 / éclatante 10,7, toutes IN ; morts par archétype toutes PASS ;
  restes logués BAL-20-B : corruption/run 7,37, pushes/run 1,60). Vague 2 : W2 talent, W3 greffes-jet,
  W4 visuel d20 + halo réussi/raté.

- **R140 — NARRATION JDR : 2e personne, présent, voix de MJ (2026-07-05, v11-N1 — user « plus orienté JDR »)** :
  la narration EN BEAT (situation + résolution + ouverture) passe de la 3e personne « le Voyageur » au
  temps du conte, à la **2e personne « Vous » au PRÉSENT, voix de Maître du Jeu** (« Vous prenez une grande
  inspiration… »). Le ton merveilleux‑inquiétant celtique (§1) est conservé — seul le registre change.
  Règles : (a) **situations riches** — 3‑4 phrases (climax 5‑6), un **PNJ qui AGIT et PARLE** (pas un décor),
  fin sur une **tension ouverte** ; **INTERDIT** de clore par « que faire », « que décidez‑vous », « vous vous
  demandez » (filet de nettoyage dans build_situation + gate probe) ; (b) **résolution en deux temps** — la
  1re phrase est l'**ACTION concrète** qui fond verbe+trait, écrite **en italique BBCode `[i]…[/i]`** (garantie
  par `MerlinProse.ensure_italic_action`), **puis** 2‑4 phrases où le **monde/PNJ RÉAGIT selon le degré**
  (échec = résiste/se ferme · partiel = cède à demi + prix · réussite = cède/explique/aide · éclatante = se
  lie/donne plus) ; interdiction de « vous continuez le chemin » ; (c) **pont générique SUPPRIMÉ** (« Sa voie
  ouverte, le Voyageur s'enfonça plus avant ») — la continuité beat→beat passe par le seul `last_gist` (« Juste
  avant : vous… »). Merlin **garde sa voix de cadre** (menu, sélection, intro, épilogue : il vous apostrophe
  « mon ami »). **Moteur INCHANGÉ** (dé d6, couverture de tags, degré, deltas) → R135/R139/§K non affectés
  (soak 200/200 iso, morts 4,9 % ≈ R139). Gate dédié : `probe_prose` CATALOG_GATE (zéro 3e personne, zéro
  filler, chaque fallback de résolution s'ouvre sur `[i]Vous…[/i]`). Le pivot d20 + arbre de talent in‑run +
  bonus greffés (décidé en session) est une **Vague 2** distincte qui, elle, re‑dérivera §K.

- **R139 — RECALIBRAGE §K MULTI-LEVIERS (2026-07-05, v1.0-V4a — vague fermée VERTE)** : la boucle
  de résolution est recalibrée par 8 leviers MESURÉS (soak 300 après chacun). Canon : (a) whitelist
  §F **branchée au jeu réel** — pool calculé À LA PRÉSENTATION du beat (`build_situation` →
  `_live_pool_info` → `validate_required_tags`), assertion DURE 0 requis hors-pool, self-tests du
  probe greppent le chemin réel ; (b) requis PAR DIFFICULTÉ (`REQ_GAP_BY_DIFF`, climax diff 3 =
  3 requis) et barème d'échec PAR DIFFICULTÉ (`ECHEC_DELTA_BY_DIFF` : −2 diff 1-2, −3 diff 3) via
  `resolve(..., diff)` — R120 tenu sur preview ET résolution ; (c) porte éclatante SANS la clause
  « trait couvre » + `INTEGRITE_DELTA[ECLATANTE]=+1` ; (d) DIE_BANDS **33/50/67/83 conservé**
  (17/33/50/67 REJETÉ par la mesure : morts 30,6→44,9 ; « 25/42/58/75 » inexprimable sur d6) ;
  (e) couverture : retag de 4 traits (paire double-gap morte éliminée, 3 slots mono-tag remplis)
  + tags GREFFÉS en tête des candidats requis (`pick_required_tags` — le build devient la clé,
  BAL-13-A) ; (f) drafts GARANTIS (ouverture avant beat 1 + transitions de quête, flag persisté
  `opening_draft_done` anti re-roll R108) ; (g) budget autoplay 600→960 s (chaînes 3 quêtes vont
  au bout). Résultat soak 300 : réussite 50,1 IN · éclatante 11,1 IN · corruption 5,63 IN ·
  0 hors-pool · gates morts par archétype TOUS PASS (durs). Restes logués BAL-20-B : échec 18,9 ·
  partiel 19,9 · climax plein 12,2 · morts 4,6 sous-bande (sur-amorti L7+L8) — prochain chantier :
  couverture du climax (greffes ciblées) + re-serrage fin par le répit de quête (BAL-06), PAS par
  le barème (c'est lui qui tient chaotic ≤30).

- **R138 — CAHIER DES CHARGES V1.0 ADOPTÉ (2026-07-04, user « adopte toutes les recos »)** :
  la V1.0 est définie par **docs/cdc_v1.md** — 200 règles CDC-XX-NN issues d'un questionnaire
  tous-métiers (docs/cdc_v1_questionnaire.md), 12 structurantes tranchées en session, 188 par
  recommandation adoptée. DÉCISIONS MAJEURES : la fin du Graal est JOUABLE en V1.0 (12 fragments,
  run finale dédiée, Fusion sur gabarits main + coda LLM) · seuil onirique complet (jalons + bilan
  + codex ~20-40 entrées + trait-souvenir) · réputation 3 états à effets réels (greffe offerte /
  sabotage / pool teinté, persistance amortie) · artworks gravure PAR QUÊTE (cache ~30 lieux validé
  main) · musique réactive 2 couches (paliers R75) · streaming LLM sur la résolution · export
  Windows GATÉ dès V4 · whitelist §F obligatoire (assertion dure) · DoD composite chiffré ·
  itch.io gratuit. Objectifs mesurables (29 métriques K/P/L/F/Q/D) et roadmap V4 → v0.9 → v1.0
  dans le CDC — les amendements canon listés par le CDC (R20, R53, R74, R99, §22…) s'appliquent
  au fil des vagues (cadence 10.3).

- **R137 — GREFFES : les 4 verbes évoluent (2026-07-04, v11-V3, spec §E)** : le draft ne donne plus
  de cartes — il GREFFE un bonus visible sur UNE des 4 actions (cap 3 slots/action, toujours dessinés).
  3 types : +1 tag permanent (Sacrifice/Équilibre exclusifs greffes) · +1 bande de dé · charges
  ✚/❖/✦ consommées à la pose du verbe (DRAW = bonus de pioche à la main SUIVANTE). Banques : 21
  greffes converties de pilier_bank + enriched_pool, noms/évocations conservés à l'octet. RÈGLES
  DURES : prix ONE-SHOT à la pose (via add_corruption) ou par charge — JAMAIS de coût récurrent sur
  une greffe ; `rarity = f(nb greffes)` = la qualité de dé (liseré de tuile, R133 — DIE_BANDS
  33/50/67/83, la 6/6 garantie n'existe plus) ; dérivation unique `refresh_from_grafts` (tags =
  2 base + greffés) à la pose ET au load ; atomicité greffe+prix par le save unique de
  `_advance_to_next` (R108) ; champ `grafts` ADDITIF (saves W2 compatibles). Geste : 2 clics zéro
  modal — les 3 greffes remplacent l'éventail, les tuiles éligibles pulsent, clic tuile = pose
  (pop + flash + liseré re-dérivé). 4 actions pleines = plus de draft. RESTE V4 (mesuré au soak) :
  brancher la whitelist §F au jeu réel (les tags greffés ne sont pas encore REQUIS en jeu),
  contre-pression §E, fréquence de drafts (2,69/run vs 5-6 visés), éclatante 2,8 % vs 8-15.

- **R136 — ÉCRAN STABLE « REIGNS » (2026-07-04, user « l'UI/UX change trop lors des phases, je veux
  de la simplicité à la REIGNS en lecture »)** : MerlinGame est UNE grille fixe de 6 zones permanentes
  (HUD 60 / décor 200 / encart 348 scroll_following type VN / ligne d'état 72 / éventail 208 /
  actions 120) — zéro `SIZE_EXPAND_FILL` vertical, `visible = true` à 100 % du temps. Les phases ne
  changent que le CONTENU des zones par cross-fade `modulate` (`MerlinVisual.swap_zone` /
  `set_zone_active`, DUR_ZONE_FADE 0,22 s ×motion()) ; l'interactivité s'éteint par `mouse_filter`,
  jamais par `visible`. RÈGLE DURE : un seul propriétaire d'alpha par zone (méta `_fx_tw_swap` tuée
  par tout fade concurrent). PLUS AUCUN MODAL : intro de quête dans l'encart (« Accepter ✦ » en
  ligne d'état), attente LLM de l'interstitiel inline (caption + points, cap 8 s), draft/offrande =
  les 3 cartes REMPLACENT l'éventail (titre + « Passer » en ligne d'état), push/pacte/vignette
  cross-fadés dans la ligne d'état (vignette du PARTIEL frappée APRÈS le choix R130). Dé-jargonnage :
  indice de dé supprimé (le liseré de tuile porte la qualité, R133), chips sans chiffres, vocabulaire
  couleur en 4 règles (GOLD = à toi · famille = tag · VIOLET = corruption · liseré = chance).
  Micro-tuto : 2 hints passifs one-shot persistés `[tuto]`. Interventions : 1/run max. Le pacte se
  pose en DONE-PATH (jamais d'await sur un typewriter skippable). Spec : docs/spec_v11_ecran_stable.md.

- **R135 — Résolution DÉGRAISSÉE, pivot v11 W0+W1 (2026-07-04, user « le jeu est trop complexe »)** :
  la lecture de l'issue prime sur le spectacle. SUPPRIMÉS : le slogan « expression » jaune (typewriter +
  aberration chromatique + zoom slow-mo), les chips chiffrées Intégrité/Corruption de la vignette, le
  sceau circulaire B9, le disque de dé B8 (doublon du MerlinDice v10.23). Fusion recapée en 3 phases
  (Rassemblement [gather+fuse fusionnés] → Burst → Décrue+Dé) totaux {0,90/1,10/1,30/1,70 s} ×motion() ;
  le dé UNIQUE (compressé ~1,15 s) se lance en chevauchement sur la décrue — overhead fixe ~2,1-2,4 s
  (−60 %). UN SEUL marqueur de degré : pill 170×48 (pastille 32 px degree_color + libellé 19 px CREAM)
  dans la vignette [pill → chip dé → chips effets, rien d'autre]. Deltas de jauges : UNIQUEMENT les
  anneaux, en COMMIT VISUEL DIFFÉRÉ post-typewriter (`_gauges_deferred`/`_flush_gauges` — le modèle
  s'applique immédiatement, invariants soak intacts ; avant, les deltas jouaient SOUS le layer plein
  écran de MerlinFx, invisibles). PARTIEL : deltas dans le ledger Encaisser/Pousser seul, anneaux APRÈS
  le choix (R130). Spec complète du pivot : `docs/spec_v11_pivot.md` (panel 4 lentilles + auditeur).

- **R134 — Charte de mouvement des cartes (2026-07-04, user)** : UN langage — arrivées = BACK out
  unique + arc d'entrée au deal (fini le double-élastique) ; sorties = anticipation + chute parabolique +
  tumble ; tap = PRESS 0.96 (langage boutons) avec retour CONTEXTUEL (fix rétraction fantôme sous hover) ;
  hover = pointe BACK à l'entrée, CUBIC au retour ; ghost de vol avec banking ; TOUTES les durées ×motion()
  via `_dur()` (les fixes 0.12/0.18 ignoraient reduce-motion). Documentée en tête de `merlin_card_view.gd`.

- **R133 — Le jet de dé mis en scène (2026-07-04, user)** : `MerlinDice` (procédural) — culbute fausse-3D
  (faces qui défilent + squash/rotation, ticks qui ralentissent) → pose sur la face PRÉ-TIRÉE (~2 s
  ×motion()) ; éclat d'or si `die_mod > 0`, face terne si le sort reste muet ; liseré = RARETÉ de la carte
  principale. **Indice de dé** près du bouton Résolution (feedforward : ce choix jettera un dé, sa qualité
  vient de ta principale) + chip vignette « ⚄ Le sort a souri (+n) / resta muet ». Séquence : fusion → dé →
  issue. Mécanique R20 INTACTE (dé pré-tiré, jamais de malus) — elle devient LISIBLE (O2 clos).
  Reduced-motion : face finale directe.

- **R132 — v10.22 : 2 biomes, menu nu, préambule lore, polish playtest (2026-07-04, feedback user + screenshot)** :
  - **2 BIOMES** : `set_biome(""|"foret"|"falaises")` — menu NU (ciel + étoiles + lune + Merlin seuls) ;
    **Falaises du Bout-du-Monde** = mer animée (rubans d'onde, reflet de lune, écume), 2 caps rocheux,
    **phare ruiné** à lanterne d'or fantôme, goélands ×3, embruns ascendants. Nouvelle Partie → **overlay
    choix du biome** (2 cartes à la charte) → le monde choisi **pop progressivement** (rampe decor_reveal
    2 s + gust + flash) → sélection. `run.biome` persisté (R108) ; env `MERLIN_BIOME` (harnais/probes).
  - **Préambule lore** (remplace « le sentier s'ouvre ») : 3 paragraphes procéduraux — qui tu es / le LIEU
    t'a appelé (banque PAR BIOME) / ce que Merlin attend + titre. 3 variantes/§, anti-répétition.
  - **Bulles Merlin** : en-tête d'identification (yeux signature + « MERLIN ») + placement ALÉATOIRE
    (5 slots hors UI, jamais 2× le même) ; queue supprimée en mode aléatoire.
  - **Polish playtest** : Merlin SANS chapeau ; hover SUBTIL (fix jitter : fréquence modulée par la souris
    = saut de phase → fréquence fixe, amplitude seule +30 % hov², lune/menhir/herbe divisés par ~2) ;
    cartes de sélection à la charte (hauteur au contenu, ornement triskèle, typo menu).

