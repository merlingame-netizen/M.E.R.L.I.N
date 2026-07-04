# M.E.R.L.I.N. — CAHIER DES CHARGES V1.0 (consolidé)

> **Date** : 2026-07-04 · **Statut** : CDC V1.0 gelé — source contractuelle du dev jusqu'à la release.
> **Méthode** : 200 questions tous métiers (`docs/cdc_v1_questionnaire.md`, panel 3 agents ancré canon
> R1-R137 + mesures soak V3). **12 questions structurantes tranchées en session interactive le 2026-07-04**
> (11 conformes à leur reco ; **NAR-04 tranchée B contre sa reco A**, pour cohérence avec GD-01-A).
> **Les 188 autres adoptent leur RECO** (mécanisme « non annotée = reco »).
> **Traçabilité** : chaque règle `CDC-XXX-NN` cite sa question source et l'option retenue
> (`GD-01-A` = question GD-01, option A). Le questionnaire reste la référence des alternatives écartées.
> **Arbitrages inter-questions tranchés ici** : NAR-29↔TEC-19 (mesurer le miss PUIS N+2 si >10 %),
> DA-19↔UX-15 (paliers Z3 d'abord, global si audit passe), NAR-27↔TEC-15 (strip export + flag `--console`
> éditeur/debug), NAR-03↔GD-09 (jalons fondus au seuil), GD-11↔NAR-20 (codex plancher 20 / plafond 40),
> GD-38↔NAR-30 (1/run base + 1 bonus Favorable), UX-16↔GD-35 (5 hints au total), UX-23↔NAR-15
> (FR seul + chaînes UI extraites), NAR-17↔PRO-18 (banques ~40 greffes = authoring sur types gelés).

---

## 1. RÈGLES PAR MÉTIER (200 règles)

### 1.1 GAME DESIGN — CDC-GD (40 règles)

- **CDC-GD-01** *(GD-01-A ⚠ tranché)* — Le Graal est **atteignable** et la fin Fusion est **jouable en V1.0**. Un run = un pas vers le Graal (R43) ; sans fin réelle, V1.0 = démo.
- **CDC-GD-02** *(GD-02-B ⚠ tranché)* — Le total de fragments du Graal est **12** (fin atteignable en ~10-14 runs). 20-30 est réservé à la version ~8 biomes (R97).
- **CDC-GD-03** *(GD-03-C)* — Cadence des fragments : **1 par fin Accomplissement (plancher garanti) + fragments bonus rares sur hauts faits** (1re victoire sur un pilier, seuil de réputation, éclatante au climax). Résout R43↔R80.
- **CDC-GD-04** *(GD-04-C)* — Fragment révélé = **vignette canon courte pré-écrite + coda LLM personnalisée** par l'état de la run. La révélation finale R44 reste 100 % canon (jamais déléguée au LLM).
- **CDC-GD-05** *(GD-05-B)* — La fin corrompue donne un **fragment sombre distinct**, comptant pour la fin Corruption totale (R89 : l'Enfant naît à ta place). Il n'avance pas le compteur des 12 fragments « clairs ».
- **CDC-GD-06** *(GD-06-A)* — À 12 fragments réunis, une **run spéciale « Le Graal »** se débloque au seuil : biome altéré/glitché (R97), chaîne de quêtes unique, climax final dédié. La Fusion se mérite en jeu.
- **CDC-GD-07** *(GD-07-B)* — **4 fins-méta** : Fusion / Refus / Corruption totale + **1 fin cachée** (le Refus véritable, gated par condition secrète type zéro pacte sur la run finale). Les variantes par faction passent par la coda LLM (CDC-GD-04), pas par des fins distinctes.
- **CDC-GD-08** *(GD-08-C)* — Sélection de la fin-méta **hybride** : l'état (Corruption cumulée, factions, choix) DÉBLOQUE les fins remplies ; le joueur **choisit** au climax final parmi les fins ouvertes.
- **CDC-GD-09** *(GD-09-C ⚠ tranché)* — Périmètre du **seuil onirique V1.0** : jalons du Graal + bilan Merlin + **codex consultable** + **décision de fin de run** (garder/refuser le trait-souvenir proposé, CDC-GD-36).
- **CDC-GD-10** *(GD-10-C)* — Persistance cross-run du build : **le POOL de greffes draftables s'élargit cross-run** (déblocages R26) ; verbes + greffes posées reset à chaque run ; aucune greffe de départ.
- **CDC-GD-11** *(GD-11-B)* — Codex : **~40 entrées maximum** (piliers, factions, Arthur/Merlin, ~8 lieux R88 + 1 entrée/fragment, secrets des piliers R82-R85, combos découverts). Plancher V1 : ~20 entrées (CDC-NAR-20).
- **CDC-GD-12** *(GD-12-C)* — Déblocage codex **à 2 niveaux** : rencontre = entrée de base ; éclatante ou haut fait = révélation du SECRET de l'entrée.
- **CDC-GD-13** *(GD-13-B ⚠ tranché)* — Réputation : **3 effets mécaniques** remappés v11 — **Favorable** = 1 greffe de la banque du pilier offerte (prix one-shot annulé) ; **Hostile** = 1 tag antagoniste sur les beats de la faction (sabotage R92 via resolve()) ; routes/quêtes du pool **teintées** par l'état.
- **CDC-GD-14** *(GD-14-C)* — Persistance de la réputation **amortie** : rappel de **1 cran vers Neutre entre chaque run**. L'extrême (Hostile/Favorable) se mérite en continu.
- **CDC-GD-15** *(GD-15-C)* — Mémoire PNJ V1.0 : relation **3 états par pilier** (méfiant/neutre/lié) + **pactes acceptés/refusés et promesses tenues/trahies par pilier** + **résumé final de run** (déjà persistant R27/R60) injecté quand le pilier revient.
- **CDC-GD-16** *(GD-16-A)* — NG+ éclairé = **narratif seul** : préfixe de prompt NG+ (Merlin allusif, PNJ qui reconnaissent, indices méta assumés). **Zéro règle mécanique changée** — pas de passe soak dédiée.
- **CDC-GD-17** *(GD-17-B)* — Roster V1.0 : **10-12 figures** = 7 actuels + 1 figure de passage nommée par faction (format fiche R34), dont 1-2 propres aux Falaises (R132).
- **CDC-GD-18** *(GD-18-C)* — Différenciation des 2 biomes : **pondérations de tags favorisés** dans la génération des requis + **FACTION_WEIGHTS propres** (Chevalerie dominante aux Falaises) + **1 quête signature et 1 figure exclusive par biome**.
- **CDC-GD-19** *(GD-19-B)* — Les Falaises se débloquent au **1er Accomplissement** (R97 « débloqués par la méta ») — premier jalon méta immédiat.
- **CDC-GD-20** *(GD-20-B)* — Longueur de run cible : **10-14 beats, ~20-30 min** (chaîne 2-3 quêtes R120, compatible drafts 5-6/run).
- **CDC-GD-21** *(GD-21-C)* — Ramification v2 : **choix VISIBLE de la quête suivante** — à chaque transition, **2 titres du pool R120** présentés au joueur.
- **CDC-GD-22** *(GD-22-B)* — Draft à cap plein (3 slots/action, 12 global) : **remplacement sec en 2 gestes dans les zones** (R136 zéro modal) ; le prix de la greffe sortante est perdu. Tranche la contradiction spec §E ↔ V3.
- **CDC-GD-23** *(GD-23-A)* — Greffes **non retirables** : permanentes pour la run, seul le remplacement (CDC-GD-22) les écrase. Aucun rite de retrait (la PURGE reste dédiée aux traits corrompus).
- **CDC-GD-24** *(GD-24-A)* — Charges (HEAL 1-2 ×2, PURGE ×2, DRAW ×2) : **épuisement définitif pour la run**, aucune recharge au répit. Tout assouplissement exige une re-mesure préalable.
- **CDC-GD-25** *(GD-25-A)* — Mort narrative : **codex, chronique, réputation et déblocages persistent ; aucun fragment**. Ni consolation, ni recul (conforme R43 avec ~37 % de morts mesurées).
- **CDC-GD-26** *(GD-26-B)* — **Assist opt-in discret** : dé une bande au-dessus + répit +1. Marqué dans la chronique, fins inchangées. Une seule difficulté canon calibrée §K.
- **CDC-GD-27** *(GD-27-C)* — Transition de quête = temps fort : répit (+2/+4) + **draft de greffe GARANTI** + **choix de la quête suivante** (CDC-GD-21).
- **CDC-GD-28** *(GD-28-B)* — Climax : **mise en scène dédiée** (stinger + séquence de dé « héros » merlin-juice + prose rallongée), **zéro règle nouvelle**. Le partiel-choix R130 reste actif au climax.
- **CDC-GD-29** *(GD-29-B)* — Sabotage R66 **réservé à l'état Hostile** de la réputation : le sabotage EST l'effet mécanique d'Hostile (CDC-GD-13). Cause lisible, contournable par le play réputation.
- **CDC-GD-30** *(GD-30-B)* — Payoff de l'Enfant : **quête de révélation dédiée débloquée après 3 croisements** + poids dans la fin Corruption totale (R89). **Zéro compteur caché** (invariant R127-D).
- **CDC-GD-31** *(GD-31-A)* — Pactes : **aucun garde-fou supplémentaire** — prix affiché + choix 1-sur-3 du draft régulent ; le budget corruption/run 5,4 ±1,5 (assertion codée) surveille au soak.
- **CDC-GD-32** *(GD-32-B)* — Contre-pression §E (requis 3 sur tout beat de quête 3 dès total_greffes ≥3) branchée **APRÈS la whitelist §F et la recomposition des requis (CDC-BAL-13/14), avec re-mesure entre les deux**. Ordre impératif.
- **CDC-GD-33** *(GD-33-B)* — Durée cible d'un beat : **60-90 s** (lecture confortable, la prose est reine — 12 beats × ~75 s ≈ 15 min de jeu + transitions ≈ 20-25 min).
- **CDC-GD-34** *(GD-34-C)* — **Mode vétéran persisté**, proposé automatiquement après 5 runs : préambule condensé (1 §), fusion ÷2, typewriter direct.
- **CDC-GD-35** *(GD-35-B)* — Onboarding : **5 hints one-shot persistés**, cap **1/beat**, diégétiques via Merlin (R31/R77) : verbe+trait, dé/liseré, push, greffe, seuil. Aucun tutoriel bloquant.
- **CDC-GD-36** *(GD-36-A)* — **Trait-souvenir** (re-spec R49/R90/R92) : 1 proposé au seuil après une run marquante (éclatante au climax, pacte lourd, survie) ; accepté = **remplace 1 des 16 traits** des runs futures (swap 1-pour-1, CDC-BAL-16).
- **CDC-GD-37** *(GD-37-B)* — Promesses R91 **version légère** : **1 promesse trackée max par run**, contractée aux interventions ; tenue = réputation +1 ; trahie = +1 Corruption + pilier mémorisé (CDC-GD-15). R91 complet en V1.1.
- **CDC-GD-38** *(GD-38-B)* — Interventions de pilier : **1/run + 1 bonus si Favorable** avec la faction du pilier. La 2e intervention se mérite (voir CDC-NAR-30 pour la base).
- **CDC-GD-39** *(GD-39-C)* — Flux de fin de run : **fin → seuil onirique (fragment + bilan + souvenir) → menu**, ET seuil **consultable à tout moment depuis le menu** (relecture jalons/codex sans mourir).
- **CDC-GD-40** *(GD-40-C)* — MerlinEnd enrichi : épilogue + jauges + **fragment révélé en scène** + **récap du build** (greffes posées, faits marquants, palmarès chronique) — l'argument de re-run.

### 1.2 BALANCE — CDC-BAL (25 règles)

- **CDC-BAL-01** *(BAL-01-A)* — Cibles de distribution §K **maintenues** : échec **3-8 %**, partiel **28-38 %**, réussite **45-55 %**, éclatante **8-15 %**. Aucune invalidation avant d'avoir branché la whitelist §F.
- **CDC-BAL-02** *(BAL-02-B)* — Porte de l'éclatante allégée : retrait de la clause « le trait couvre ≥1 requis » (redondante avec §F). Reste : **couverture pleine ET coût 0 ET (synergie +1 OU dé +1)**. Le « coût 0 » = triomphe propre (R65) est conservé.
- **CDC-BAL-03** *(BAL-03-A)* — Levier principal de l'échec : **brancher la whitelist §F au jeu réel** (0 requis hors-pool, assertion codée). Pas de 3e tag de base, pas de relâchement de dé supplémentaire.
- **CDC-BAL-04** *(BAL-04-B)* — Gates de morts **par archétype** : optimal **≤10 %** · greedy **≤30 %** · chaotic **≤30 %** · corrompu **≤25 %** · tag-ignorant **non gaté** (bot adversarial). Pas de plancher pour l'optimal (R120 : un joueur discipliné n'est jamais puni).
- **CDC-BAL-05** *(BAL-05-A)* — INTEGRITE_DELTA **inchangé** : échec −3, partiel −2, réussite 0 (éclatante : +1, voir CDC-BAL-25). La mortalité se corrige par le TAUX d'échec (CDC-BAL-03), pas par le barème.
- **CDC-BAL-06** *(BAL-06-A)* — Répit de quête **inchangé** (+2 Intégrité, +2 bonus si ≤4, recharge du push) jusqu'au re-soak post-whitelist. Pas de PURGE gratuite (rôle canon du Chœur, R49/R82).
- **CDC-BAL-07** *(BAL-07-A)* — Économie du push **inchangée** : PUSH_PRICE 1, budget 1/quête rechargé au répit. Cible 0,5-1,5 push/run (mesuré 1,3 — dans la cible). Guardrail R130 : re-mesurer avant tout changement.
- **CDC-BAL-08** *(BAL-08-A)* — Cible corruption/run : **5,4 ±1,5** maintenue ; re-dérivation **seulement une fois la cadence de drafts 5-6 atteinte et mesurée**. Aucune anticipation.
- **CDC-BAL-09** *(BAL-09-A)* — Seuils de Corruption : pas **/5 (5/10/15)** maintenu — paliers de glitch R75, pré-alerte de jauge et nappes audio y sont indexés.
- **CDC-BAL-10** *(BAL-10-A)* — **CORRUPTION_CAP 18** maintenu (3 seuils + marge 3 ; fins corrompues 14,5 % mesurées dans la cible). Constante TweaksOverlay, ajustable en 1 ligne sur dérive mesurée.
- **CDC-BAL-11** *(BAL-11-B)* — Déclencheurs de draft : **draft garanti à chaque transition de quête + draft d'ouverture au 1er beat**. E[drafts] ≈ 1 + 2 + rencontres ≈ **5-6/run par construction structurelle**.
- **CDC-BAL-12** *(BAL-12-B)* — Table de dé : **revenir vers DIE_BANDS 17/33/50/67 %** une fois whitelist + composition branchées (re-dérivée au soak post-CDC-BAL-13/14). Position de repli : 25/42/58/75 si les morts remontent.
- **CDC-BAL-13** *(BAL-13-A)* — Climax recomposé **« 2+1 »** : 2 requis hors-base + **1 tag de base d'action** — couverture pleine atteignable PAR CONSTRUCTION (verbe pertinent + trait + greffe), visant la bande 45-55.
- **CDC-BAL-14** *(BAL-14-A ⚠ tranché)* — **Whitelist §F OBLIGATOIRE V1.0, gate V4 avec assertion dure** : requis ⊆ base ∪ traits ∪ greffes, fallback même index, **0 requis hors-pool**. Prérequis de TOUTES les autres cibles.
- **CDC-BAL-15** *(BAL-15-B)* — Deadhand (main sans trait couvrant) : seuil **≤45 %**, mesuré en **assertion loguée** (mesuré 34,9 %). Si dépassement : A/B « réserve de trait » (spec §C).
- **CDC-BAL-16** *(BAL-16-A)* — Deck de traits **figé à 16 sains** : tout trait-souvenir **REMPLACE** un trait de base (swap 1-pour-1). Zéro croissance = zéro re-dérivation des cibles ; le souvenir est gratuit en équilibrage, douloureux en choix.
- **CDC-BAL-17** *(BAL-17-A)* — Injection de traits corrompus : **1 par seuil franchi** (5/10/15), max 3 (~16 % du pool au pire). Pas de durcissement avant correction des morts.
- **CDC-BAL-18** *(BAL-18-A)* — **Cap 1 trait corrompu par main**, re-tirage silencieux de l'excédent (R113 : jouabilité garantie prime). Le cap 2 en dissolution = candidat mode difficile futur, pas V1.0.
- **CDC-BAL-19** *(BAL-19-B)* — Méthode de recalibrage : soak **200/200 au gate** + **5×300 de recalibrage par vague** + **soak 5×300 automatisé nightly** avec rapport de dérive des assertions §K. Tuning continu sans re-gate interdit.
- **CDC-BAL-20** *(BAL-20-B)* — Assertions **DURES** (gate rouge) : distribution 4 bandes + morts par archétype + 0 requis hors-pool + corruption/run. Assertions **LOGUÉES** : pushes/run, sabotage, deadhand, fréquence drafts, fins corrompues borne basse.
- **CDC-BAL-21** *(BAL-21-A)* — Valeurs des charges **inchangées** (HEAL 1-2 ×2 · PURGE 1 ×2 · DRAW 1 ×2) ; pick-rate par type mesuré au soak **une fois les drafts à 5-6/run** (à 2,69 aucune donnée n'est significative).
- **CDC-BAL-22** *(BAL-22-A)* — Prix des greffes pactées : **+1 Corruption uniforme** (« pacte = 1 ombre »). Différenciation éventuelle après mesure de pick-rate (CDC-BAL-21).
- **CDC-BAL-23** *(BAL-23-C)* — Fins corrompues : **fourchette 10-18 %** — borne haute gatée, **borne BASSE loguée** (si la Corruption ne menace plus personne, le thème meurt avec).
- **CDC-BAL-24** *(BAL-24-A)* — Fréquence du sabotage (état Hostile, CDC-GD-29) : **≤5 % des beats d'une run** — événement rare, lisible et attribuable, mesuré en assertion loguée.
- **CDC-BAL-25** *(BAL-25-C)* — Récompense de l'éclatante : **+1 Intégrité fixe** (clamp 0-10, lisible dans les anneaux) + **déclencheur privilégié de trait-souvenir** (CDC-GD-36) + **secret de codex** (CDC-GD-12). Impact morts marginal à ≤15 %, compensé au recalibrage CDC-BAL-19.

### 1.3 NARRATIF / LLM — CDC-NAR (30 règles)

- **CDC-NAR-01** *(NAR-01-B)* — Curseur de ton : **merveilleux dominant en début de run, l'inquiétant croît avec la Corruption** ; le palier R75 est injecté au prompt (1 ligne d'ÉTAT). Chaque palier devient lisible dans la prose.
- **CDC-NAR-02** *(NAR-02-B)* — **1 ligne de sous-ton par biome** injectée au préfixe variable (Brocéliande = « féerie qui mord » ; Falaises = « mélancolie du bout du monde ») + banques de préambule alignées. Garde-fous R61 intacts.
- **CDC-NAR-03** *(NAR-03-B, fondu GD-09)* — **Compteur de fragments persisté dans Chronicle** + 1 phrase du préambule R132 rappelant l'avancée (« trois éclats déjà… »). L'UI des jalons vit dans le seuil onirique (CDC-GD-09, per NB).
- **CDC-NAR-04** *(NAR-04-B ⚠ tranché, contre reco A)* — **La Fusion est jouable en V1.0**, atteignable au seuil de **12 fragments** (CDC-GD-02 prime sur le « ~10 » indicatif de l'option). Cohérent GD-01-A ; l'écran-seuil et les fins-méta sont construits (CDC-GD-06/07/08).
- **CDC-NAR-05** *(NAR-05-B)* — Fins de run sécurisées : **gabarit écrit main par type de fin** (accomplissement/mort/corrompu, 2-3 variantes) + **le LLM colore par-dessus** avec l'état final (pattern R20). La chute (fragment, payoff Enfant R85) est garantie même quand E2B faiblit.
- **CDC-NAR-06** *(NAR-06-B)* — Épilogue : **120-180 mots en 2 blocs** (bilan de la run puis fragment du Graal), **max_tokens ~280** — sous ~15 s de gen sans lookahead possible.
- **CDC-NAR-07** *(NAR-07-B)* — Arcs des piliers : **3 stades par pilier** (étranger / reconnu / lié, compteur de rencontres dans Chronicle) sélectionnant **lignes signées et offrandes différentes** dans les banques R131. Zéro appel LLM (R110 intact).
- **CDC-NAR-08** *(NAR-08-B)* — Compagnon Perdu : **micro-arc de rédemption** — après N refus de ses pactes (compteur Chronicle), **1 ligne signée spéciale** où la bribe d'humanité perce (banque, zéro mécanique). Quête complète post-V1.
- **CDC-NAR-09** *(NAR-09-B)* — Révélation de l'Enfant : au climax/épilogue **si complicité élevée (aides acceptées ≥2 cross-run via Chronicle)** — la prose laisse entrevoir ce qu'il est, **sans jamais dire « IA »** (R85 « jamais frontale tôt »).
- **CDC-NAR-10** *(NAR-10-B)* — Arthur : **apparitions procédurales rares** — 1 banque de 4-6 fragments signés (voix fébrile R35) injectés en micro-événement de transition, pattern R131 (zéro appel LLM), **~15 % des runs**.
- **CDC-NAR-11** *(NAR-11-B)* — **2-3 figures nommées** (Viviane, le Passeur…) **en couleur seulement** : citées dans banques de préambule/few-shots, **jamais incarnées** (interdit R17 sans fiche).
- **CDC-NAR-12** *(NAR-12-C)* — Longueur de prose **par type de beat** : Exploration/Rencontre **2-3 phrases**, Dilemme/Climax **4-5 phrases** — max_tokens par type. L'encart Z3 scroll_following absorbe la variance.
- **CDC-NAR-13** *(NAR-13-C)* — Longueur de l'issue **par degré** : échec/éclatante **3-4 phrases** (moments mémorables) ; partiel/réussite **2 phrases** (le partiel enchaîne sur Encaisser/Pousser R130).
- **CDC-NAR-14** *(NAR-14-A)* — Voix narrative **verrouillée : tu + présent** dans le préfixe système + **audit de conformité des banques existantes**. Anti-dérive de personne.
- **CDC-NAR-15** *(NAR-15-B)* — **FR seul en jeu** ; les **chaînes UI (boutons, options, libellés) sont extraites dans un fichier de traductions Godot dès la V1** ; prose LLM et banques restent FR (few-shots gold R62 FR).
- **CDC-NAR-16** *(NAR-16-B)* — Mémoire au retour : **3 souvenirs max injectés au préambule** (pilier croisé, type de fin, 1 choix marquant `choix_cles` persisté Chronicle) — **budget ~40 tokens** (R60).
- **CDC-NAR-17** *(NAR-17-A)* — Greffes écrites **main en banques, étendues à ~40 (10/type, ton R102)**. Aucune forge LLM à chaud (guardrail single-flight R110 : zéro appel ajouté). Le pool pré-généré validé = évolution post-V1.
- **CDC-NAR-18** *(NAR-18-B)* — Lien greffe↔vécu : **sélection procédurale contextuelle** du pool de draft (faction de la quête, degré du beat précédent, saison) + **sous-titre du lieu** sur le nom (« — forgée aux Falaises »). 80 % de R90 sans toucher au moteur.
- **CDC-NAR-19** *(NAR-19-C)* — Codex : **canon écrit main + 1 ligne de chronique par run appendue automatiquement** (« Run 7 — le Chœur t'a reconnu », source Chronicle). Le LLM n'écrit **rien de persistant non auditable**.
- **CDC-NAR-20** *(NAR-20-A, NB GD-11)* — Codex V1 : **~20 entrées courtes (80-120 mots) = plancher** (4 factions, 5 piliers, 5 lieux R88, ~6 lore) ; **plafond ~40** (CDC-GD-11). L'Enfant garde une entrée « masquée » évolutive (R85).
- **CDC-NAR-21** *(NAR-21-B)* — Anti-répétition LLM : **liste des 3-5 motifs déjà servis dans la run injectée au tour variable** (« AVOID reusing: fontaine, brume… »), maintenue par le code depuis les narrations passées. Pas de post-filtre retry.
- **CDC-NAR-22** *(NAR-22-B)* — Banques procédurales : **doubler les points chauds** — 6-8 lignes signées/pilier et 6 variantes/paragraphe de préambule ; codas de push inchangées (~6).
- **CDC-NAR-23** *(NAR-23-B)* — Few-shots : **1 exemple gold PAR TYPE de beat (5)** pour la tâche Situation, **sélectionné dynamiquement dans le tour variable** — le préfixe KV-caché ne bouge pas (R62).
- **CDC-NAR-24** *(NAR-24-A)* — Dataset LoRA préparé dès V1 : **logger les sorties « propres » (0 violation R61) avec leur prompt dans un JSONL dédié** via la télémétrie R98. Coût quasi nul, fine-tune post-V1 (R45).
- **CDC-NAR-25** *(NAR-25-B)* — Filtre anti-dérive R61 **étendu** : méta doux (« programme », « joueur », « partie », « niveau », « quête secondaire ») + tics de LLM (« en tant que », « n'hésite pas ») + anachronismes courants — tout loggé au dashboard R96.
- **CDC-NAR-26** *(NAR-26-A)* — **Verrouillé : le LLM ne décide JAMAIS rien de mécanique.** Degré 100 % code, tags pré-pickés, prose écrite AUTOUR (invariant R120 preview = résolution). **R20 amendé à la bible** pour refléter l'état réel.
- **CDC-NAR-27** *(NAR-27-B ∩ TEC-15-A, arbitrage)* — GemmaConsole : **strippée des exports release** (CDC-TEC-15) ; accessible via **flag `--console` en éditeur/builds debug SEULEMENT**. Jamais exposée au joueur (4e mur).
- **CDC-NAR-28** *(NAR-28-A)* — Échec de génération **invisible** : le fallback procédural R61 est indistinguable (banques au ton canon) ; l'événement part en **télémétrie R98 seulement**. Aucun indice, aucun toast.
- **CDC-NAR-29** *(NAR-29-B, arbitrage TEC-19)* — Lookahead : **mesurer le taux de cache-miss D'ABORD (statu quo N+1)** ; **si miss >10 % des beats → brancher N+2 opportuniste** (moteur idle ET N+1 en cache, priorité basse file R110, annulé au swap de ramification R120).
- **CDC-NAR-30** *(NAR-30-A, NB GD-38)* — Interventions : **base 1/run maintenue** (charge cognitive v11) ; la seule extension V1.0 est le **+1 si Favorable** (CDC-GD-38). La fréquence pilotée par stade de relation = évolution post-V1.

### 1.4 DA / VISUEL — CDC-DA (20 règles)

- **CDC-DA-01** *(DA-01-C ⚠ tranché)* — Artworks : **GO partiel — 1 image par QUÊTE (2-3/run)**, sujet = le lieu du préambule, affichée à l'ouverture de quête puis **persistante**. Volume ÷4, cache réutilisable entre runs, zéro hitch garanti plus facilement.
- **CDC-DA-02** *(DA-02-A)* — Style : **duotone strict CREAM/INK** (pipeline actuel, zéro hex hors palette §20). Les rehauts GOLD = passe optionnelle SI le duotone paraît plat en capture.
- **CDC-DA-03** *(DA-03-C)* — Qualité : **100 % pré-généré et validé À LA MAIN (~30 images de lieux), JAMAIS de génération live en V1**. Le live redevient un chantier v-next avec son gate propre (§24).
- **CDC-DA-04** *(DA-04-A)* — Placement : **bandeau haut de l'encart Z3 (96-120 px), fade-in async**, la prose commence dessous. L'image ne bloque jamais le texte (§24) ; pas de filigrane (contraste), pas de fusion Z2 (collision R129).
- **CDC-DA-05** *(DA-05-B)* — Portraits des piliers : **gravure via `merlin-artwork` pour le CODEX seulement** ; in-game, **silhouettes procédurales canon** conservées (mystère).
- **CDC-DA-06** *(DA-06-B)* — Palette : ajouts **uniquement par constantes nommées dans MerlinVisual** (ex. 1-2 accents par nouveau biome) + **entrée miroir dans la table §20** à chaque ajout. Rebranding = 1 édition, bible synchrone.
- **CDC-DA-07** *(DA-07-A)* — Typographie : **embarquer Cinzel + EB Garamond (licences OFL)** + **Theme global** (titres/corps), tailles FS_* inchangées. Corrige l'écart bible/code (§20).
- **CDC-DA-08** *(DA-08-A)* — Glyphes de tags : **6 formes de FAMILLE** (Perception/Corps/Parole/Intuition/Mystique/Corrompu) partout ; **le mot porte le concept**. Pas de set 25 glyphes (illisible à 16 px, contredit ÉVIDENT §23).
- **CDC-DA-09** *(DA-09-A)* — Bordures de rareté : **liserés statiques + glow throttlé, PAS d'irisé animé** — le liseré encode la qualité de dé (R133), l'animer bruiterait un canal décisionnel. **R53 amendé**.
- **CDC-DA-10** *(DA-10-B)* — Falaises, pack de parité : **lieux archétypaux falaises dans les banques de préambule** (écho R88) + **accent couleur dédié** (constante, CDC-DA-06) + **nappe `amb_cotes.wav` câblée** au biome.
- **CDC-DA-11** *(DA-11-A)* — **2 biomes en V1.0, pas de 3e** — profondeur avant largeur (chaque biome coûte préambules + accent + nappe + QA captures).
- **CDC-DA-12** *(DA-12-B)* — Saisons : **cosmétique + 1 mention dans le préambule R132** (« l'hiver tient la lande »). Aucune mécanique saisonnière (règle invisible interdite, R127).
- **CDC-DA-13** *(DA-13-B)* — Glitch corruption : **passe de tuning dédiée** — renforcer le palier 15+ (« dissolution » doit inquiéter physiquement), vérifier le palier 5-9 à peine perceptible, **captures avant/après aux 4 paliers** (gate §24).
- **CDC-DA-14** *(DA-14-B)* — MerlinEnd : **fresque d'état final** — décor du biome joué rendu à l'état de fin (palier corruption, saison) + silhouette du pilier croisé + épilogue par-dessus. 100 % réutilisation MerlinSceneArt.
- **CDC-DA-15** *(DA-15-B)* — Menu : **ciel teinté selon la dernière fin** (Chronicle, alpha ≤0.08) + **entrée « Codex » sobre** (ouvre le seuil onirique, CDC-GD-39). Pas de hub complet au menu.
- **CDC-DA-16** *(DA-16-B)* — Résolutions : **1280×720 minimum via `content_scale` canvas_items** + **validation par captures aux 2 résolutions** (8 cartes, vignette, boutons ≥44 px effectifs) — gate §24. Plancher FS 16 px (R112) vérifié à l'échelle réelle.
- **CDC-DA-17** *(DA-17-B)* — Option **« décor calme » séparée de reduce-motion** : sway/oiseaux/hover off, motes ÷2 — confort de lecture distinct de l'accessibilité vestibulaire.
- **CDC-DA-18** *(DA-18-B)* — **Mode contraste renforcé câblé en V1** : CREAM éclairci, DIM_WARM/INK_DIM remontés d'un cran, voiles de mood désactivés, glitch plafonné — **set de constantes alternatif dans MerlinVisual** (1 table de swap). Clôt la dette « promis R74, absent du code ».
- **CDC-DA-19** *(DA-19-A, arbitrage UX-15)* — Taille de texte : **commencer par 2 paliers Z3+pill (CDC-UX-15)** ; **étendre aux 3 paliers globaux (FS_* × 0.9/1.0/1.15, plancher absolu 16 px R112)** SI le re-audit de grille « zéro changement de zone » passe. L'encart scroll_following absorbe le débord.
- **CDC-DA-20** *(DA-20-A)* — Lisibilité des types de greffe sur tuiles : **langage par canaux existants** — pastille couleur-famille (tag), liseré R133 (bande de dé), chiffre de charges ✚/❖/✦. **Hover enrichit, ne révèle jamais** (§23). Zéro vocabulaire nouveau.

### 1.5 AUDIO — CDC-AUD (20 règles)

- **CDC-AUD-01** *(AUD-01-B ⚠ tranché)* — Musique gameplay : **réactive 2 couches** — base permanente + **couche granuleuse dissonante dont le volume suit le palier R75**. La couche manquante est générée **offline** via `tools/music_forge.py`. C'est le canon §22 mot pour mot.
- **CDC-AUD-02** *(AUD-02-A)* — **2 couches exactement** (base + corruption), seuils = **paliers R75 exacts**. Pas de couche « intégrité basse » (alertes visuelles dédiées suffisent).
- **CDC-AUD-03** *(AUD-03-B)* — MusicGen : **banque pré-générée offline embarquée**, enrichie de **variantes par biome**. Zéro génération live (le CPU appartient à Gemma, R58).
- **CDC-AUD-04** *(AUD-04-B)* — Transitions : **crossfade equal-power 2-4 s au `begin_quest`** + **cue de fin dédié à l'entrée de MerlinEnd**. Le répit du sentier s'entend.
- **CDC-AUD-05** *(AUD-05-B)* — Moments muets : **réutiliser le catalogue** (`ogham_unlock` pose de greffe, `card_reveal` draft, `button_appear` push, `mist_breath` préambule, `biome_reveal` overlay) + **1 seul id neuf `graft_set`** (geste signature v11).
- **CDC-AUD-06** *(AUD-06-A)* — **3 stingers de fin dédiés** via sfx_forge : accomplissement (résolution chaude), mort (coupure + résonance sourde), corrompu (dissonance qui avale la nappe). La bascule corrompue cesse d'être muette.
- **CDC-AUD-07** *(AUD-07-A)* — Voix de Merlin : **procédurale (blips R124) seule en V1** — zéro latence, identité rétro-minimaliste §20. TTS post-V1.
- **CDC-AUD-08** *(AUD-08-B)* — Blips : **1/3 lettres sur la prose longue in-game + micro-variation de pitch ±4 % par blip** ; bulles courtes du menu inchangées (1/2 lettres). Anti-mitraillette.
- **CDC-AUD-09** *(AUD-09-B)* — **1 timbre alternatif « murmure »** (blip grave filtré, nouvelle recette sfx_forge) pour **TOUTE ligne signée d'un pilier**. Un seul asset marque le changement de locuteur.
- **CDC-AUD-10** *(AUD-10-A)* — Ducking étendu : **musique −3 dB pendant tout typewriter actif (retour 0,8 s)**, en plus du duck stinger −6 dB existant. « La prose est reine » appliqué mécaniquement (§22).
- **CDC-AUD-11** *(AUD-11-A)* — Loudness, écart bible/outil tranché : **gate anti-clip peak ≤ −3 dB pour TOUT asset** ; **norme de mix −14 dB pour les SFX** ; **musique autour de −6 dB**. La §22 documente les deux niveaux (l'outil v3 a raison).
- **CDC-AUD-12** *(AUD-12-A)* — **Créer un 4e bus Voice** mappé au slider Voix — ducking et mute propres par bus, isole la voix du mute SFX. Rend CDC-AUD-08/09/10 implémentables proprement.
- **CDC-AUD-13** *(AUD-13-A)* — Nappes piliers : **5 pads, 1/pilier, inchangés**. Pas de variante « reconnaissance » (portée par le texte).
- **CDC-AUD-14** *(AUD-14-B)* — Son du dé : **ticks sonores synchronisés sur le ralentissement des faces** + **accent distinct quand « le sort a souri »** (réutilise `ogham_chime`). Zéro asset neuf ; le dé pré-tiré « se sent » honnête (R133).
- **CDC-AUD-15** *(AUD-15-A)* — Fusion : **resynchroniser les déclencheurs SFX existants sur les 3 phases R135 (0,90-1,70 s totaux)**, aucun asset neuf. La déduplication 40 ms (R124) protège des empilements.
- **CDC-AUD-16** *(AUD-16-B)* — Interventions : **`mist_breath` à t=0 (apparition feutrée) + `biome_dissolve` au fondu**, en plus du pad du pilier. Zéro génération, cadre sonore pour 1,8 s.
- **CDC-AUD-17** *(AUD-17-A)* — Options audio : **4 sliders (Maître/Musique/SFX/Voix)**. Pas de 5e (MINIMAL §23 vaut pour Options).
- **CDC-AUD-18** *(AUD-18-A)* — **Mute global : touche M + icône discrète d'état, persisté**. Le jeu porte 100 % de son information en visuel (R112/§23) : le mute ne fait rien perdre.
- **CDC-AUD-19** *(AUD-19-B)* — **Reduce-motion atténue aussi les SFX décoratifs** (hover, motes, embruns) mais **conserve les SFX d'information** (jauges, seuils, stingers) — miroir exact de la sémantique §23 « atténue, ne supprime jamais l'information ».
- **CDC-AUD-20** *(AUD-20-A)* — Gate audio : **l'autoplay (harnais duck-typing) loggue chaque `play_sfx` et diff-e contre le catalogue §22 + nouveaux ids** — gate de couverture rejouable. Aucun moment nouveau (greffe, push, intervention) ne reste muet.

### 1.6 UX / UI — CDC-UX (25 règles)

- **CDC-UX-01** *(UX-01-B)* — **Clavier minimal V1.0 (6 touches)** : Espace = skip/continuer · Échap = pause · 1-4 = tuiles · A-D = traits · Entrée = Résoudre. Couvre 100 % de la boucle. **R99 amendé** (pas de focus-ring complet).
- **CDC-UX-02** *(UX-02-A)* — **Manette : NO-GO V1.0** (canon R99 inchangé — Windows desktop seul §14, zéro demande).
- **CDC-UX-03** *(UX-03-B)* — Tactile : **1 session de test sur laptop Windows tactile** (les 8 phases + draft) ; **fixes limités aux cibles <44 px** détectées. Transforme la promesse R18 en fait mesuré.
- **CDC-UX-04** *(UX-04-B)* — **Échap = overlay pause système plein écran** (Reprendre / Options / Quitter) — **exception assumée au « zéro modal »**, qui ne vise que les phases de jeu. Pas de sortie sèche, pas de pollution Z4.
- **CDC-UX-05** *(UX-05-B)* — Options in-game : **sous-ensemble in-pause** — 4 volumes + reduce-motion + vitesse texte. Pas de rechargement de la scène Options complète mid-run.
- **CDC-UX-06** *(UX-06-B + DA-18)* — Pack options V1.0 : **pack lecture** (vitesse typewriter + « afficher direct » + 2-3 tailles de texte) **+ contraste renforcé** (CDC-DA-18, quasi gratuit via MerlinVisual) **+ décor calme** (CDC-DA-17). **Police dys et presets perf reportés V1.1** — **R74 amendé au périmètre réel**.
- **CDC-UX-07** *(UX-07-A)* — Typewriter : **3 vitesses (Lent/Normal/Rapide) + bascule « afficher direct », persistées**. Pas d'accélération adaptative invisible (viole ÉVIDENT §23).
- **CDC-UX-08** *(UX-08-A)* — Historique de lecture : **le fil de la QUÊTE entière est conservé dans Z3** — scroll libre vers le haut, follow en bas. Couvre le trou de mémoire à la reprise R108. Pas de carnet séparé (MINIMAL).
- **CDC-UX-09** *(UX-09-B)* — Beat map CHEMIN : **enrichie au survol** (type de beat + « tu es ici ») — le hover ENRICHIT, jamais exclusif (§23). Seul feedforward de rythme post-R136.
- **CDC-UX-10** *(UX-10-A)* — Deltas de jauges (anneaux seuls R135) : **playtest verbal d'abord** — 5 joueurs verbalisent « qu'as-tu perdu ? » après 3 échecs ; **on ne double l'info que si ≥2 échouent** (R112 anti « info ×2 »). Correction prête : écho « −2 » près de la pill sur échec/éclatante uniquement.
- **CDC-UX-11** *(UX-11-B)* — Anti double-clic : **cooldown d'armement 250 ms** — Résoudre inerte pendant 0,25 s après le passage armé. Invisible, tue le clic réflexe, préserve FACILE ≤2 gestes.
- **CDC-UX-12** *(UX-12-C)* — Lisibilité des 3 types de greffe : **micro-libellé d'effet (1 ligne, ≥16 px) sur chaque carte de greffe au draft** + **tooltip de rappel au survol des slots posés**. Le libellé décide, le tooltip rappelle, zéro geste ajouté.
- **CDC-UX-13** *(UX-13-A)* — LLM KO au boot (GGUF manquant/corrompu, RAM insuffisante) : **écran d'erreur diégétique** (« Merlin ne rêve pas… ») + **détail technique repliable** + **Réessayer/Quitter**. Pas de mode sans-LLM (violerait R32).
- **CDC-UX-14** *(UX-14-A)* — Daltonisme : **glyphe/forme de famille systématique PARTOUT où la couleur famille est porteuse** (pastilles de slots, requis, tuiles) — règle canon §11 « couleur + forme, le mot lisible » appliquée sans exception.
- **CDC-UX-15** *(UX-15-B, arbitrage DA-19)* — Taille de police : **2 paliers (100 % / 115 %) limités au texte narratif Z3 + pill** (le scroll VN absorbe tout) ; extension aux 3 paliers globaux conditionnée au re-audit de grille (CDC-DA-19).
- **CDC-UX-16** *(UX-16-B, NB GD-35)* — **+1 hint au premier draft** (« Greffe un pouvoir sur un verbe — 2 gestes ») **+1 hint au premier partiel** — pattern one-shot déjà codé. Ce sont les hints « greffe » et « push » des 5 de CDC-GD-35.
- **CDC-UX-17** *(UX-17-C, via NB + GD-09)* — Le seuil onirique **existe à l'écran comme chantier méta dédié** avec **transition visuelle propre** (le NB de UX-17 bascule sur C dès que GD-09 retient le seuil-hub — c'est le cas).
- **CDC-UX-18** *(UX-18-B)* — MerlinEnd : **panneau sobre de 4 lignes** — beats traversés · degrés (dont éclatantes) · Corruption max · greffes posées. Le palmarès cross-run attendra un écran chronique dédié.
- **CDC-UX-19** *(UX-19-C)* — Saves : **1 slot auto (contrat R108) + confirmation « une run est en cours — l'abandonner ? »** sur Nouvelle partie. Pas de multi-slots.
- **CDC-UX-20** *(UX-20-B)* — Anti skip accidentel : **zone morte 300 ms entre « texte révélé » et « clic = avancer »**. Corrige le double-clic nerveux sans changer le geste appris (R63).
- **CDC-UX-21** *(UX-21-A)* — Contraste chips Z4 : **audit automatisé** — captures 8 phases + **calcul de ratio (seuil 4.5:1) intégré à la fleet QA V4**. Le §23 « contrastes canon » devient vérifiable à chaque vague.
- **CDC-UX-22** *(UX-22-A)* — Vignette Z4 : **compactée ≤72 px** — pill 170×48 + chips sur UNE ligne horizontale. La hauteur fixe est LA règle de R136 ; aucun débord fonctionnel.
- **CDC-UX-23** *(UX-23-A + NAR-15-B)* — **FR seul V1.0 en jeu** ; l'arbitrage fin avec NAR-15 s'applique : **chaînes UI externalisées** (fichier de traductions Godot) **sans traduction**. EN étudié post-V1 sur traction mesurée.
- **CDC-UX-24** *(UX-24-A)* — Pactes : **2 boutons Accepter/Refuser symétriques** (même taille, même hiérarchie), **prix ✦ affiché sur Accepter seulement**. Aucun dark pattern (fausserait la cible fins corrompues 10-18 %).
- **CDC-UX-25** *(UX-25-A)* — Reprise (Continuer) : **le résumé glissant (§9, déjà maintenu) s'écrit en tête du fil Z3** en style DIM (« Là où le rêve t'a laissé… »). Zéro génération LLM, la contrainte R108 devient un moment narratif.

### 1.7 TECH / MOTEUR — CDC-TEC (20 règles)

- **CDC-TEC-01** *(TEC-01-C ⚠ tranché)* — Streaming token-par-token (R57) : **branché sur la RÉSOLUTION seule** (prose pure sans GBNF = zéro parsing incrémental). 80 % du bénéfice perçu (l'attente post-Résoudre de chaque beat) pour le risque GDExtension minimal. Le JSON incrémental attend.
- **CDC-TEC-02** *(TEC-02-A)* — Contrat de latence : **cache-miss ≤12 s ACCEPTÉ SI le taux de cache-miss mesuré (télémétrie) reste <10 % des beats**. Leviers si hors cible : prefetch N+2 (CDC-NAR-29) puis max_tokens 250→180.
- **CDC-TEC-03** *(TEC-03-A)* — Modèle **figé V1.0 : `gemma4-e2b-q4_k_m.gguf` (3,3 GB) seul** — l'unique artefact mesuré par les gates R109. Plan B Q3 ~1B documenté (R94), **non shippé**.
- **CDC-TEC-04** *(TEC-04-C)* — Contexte : **n_ctx 4096 maintenu** + **bloc chronique injecté cappé à ~60 tokens** (résumé de résumé). La méta reste une ALLUSION (R127), pas un historique.
- **CDC-TEC-05** *(TEC-05-A)* — **CPU only V1.0** — une seule config, celle que soak/autoplay mesurent. Offload GPU réévalué en V1.1 sur télémétrie réelle.
- **CDC-TEC-06** *(TEC-06-B)* — Presets perf : **auto-détect silencieux seul** — **R74 amendé** (Éco/Équilibré/Perf non exposés). Le micro-bench (CDC-TEC-20) informe mieux qu'un réglage manuel.
- **CDC-TEC-07** *(TEC-07-A ⚠ tranché)* — **Export Windows IMMÉDIATEMENT en V4** : preset configuré + **gate « le build exporté passe 1 autoplay complet » ajouté à R109**. Risque existentiel (chemins res:// vs pack, GGUF hors éditeur) tué au plus tôt.
- **CDC-TEC-08** *(TEC-08-A)* — Plateformes : **NO-GO intégral Linux/Mac/Web V1.0 — Windows seul** (canon §14). Linux best-effort ne se discute qu'après des chiffres de demande itch réels. Pas de démo Web sans LLM (violerait R32).
- **CDC-TEC-09** *(TEC-09-A)* — Packaging : **zip unique tout-inclus (~4 GB) sur itch** — installer = dézipper, **100 % offline**. Pas de téléchargement au premier lancement, pas d'installeur.
- **CDC-TEC-10** *(TEC-10-A)* — Saves : **checksum + copie `.bak` rotative à chaque save, restaurée automatiquement** si le principal est illisible. Contrat mono-slot R108 intact. ~1 session contre le pire bug de churn.
- **CDC-TEC-11** *(TEC-11-A)* — Méta cross-run : **chronique extraite vers `user://chronicle.cfg` dès la prochaine vague** (lecture legacy conservée 1 version). Préférences ≠ mémoire : cycles de vie séparés avant que la méta Graal grossisse.
- **CDC-TEC-12** *(TEC-12-A)* — Perf canon V1 : **60 fps cible, 0 hitch >33 ms hors génération**, mesuré sur les **captures 8 phases ×2 biomes** (fleet QA V4).
- **CDC-TEC-13** *(TEC-13-A)* — Crash reporting : **handler local `user://crash/*.log`** (stack + version + seed) + mention « joignez ce fichier » sur la page itch. Zéro réseau (~2 h de travail).
- **CDC-TEC-14** *(TEC-14-A)* — Seed : **persistée dans la save + affichée discrètement sur MerlinEnd** — partage, repro de bug, entrée directe pour probe_soak.
- **CDC-TEC-15** *(TEC-15-A, arbitrage NAR-27)* — **GemmaConsole + TweaksOverlay STRIPPÉS des exports** (gardés sous feature editor/debug) ; le smoke 6 scènes reste éditeur. **Arbitrage tranché : TEC-15-A + flag `--console` disponible en éditeur/builds debug seulement** (CDC-NAR-27). Jamais en release.
- **CDC-TEC-16** *(TEC-16-A)* — Sécurité prompts : **au load, sanitisation des champs texte de save** (longueur max + filtre anti-dérive R61) **avant toute réinjection** dans les prompts. Pas de HMAC (punirait les moddeurs pour un gain nul en solo local).
- **CDC-TEC-17** *(TEC-17-A)* — Whitelist required_tags branchée **en V4, AVANT tout playtest externe et AVANT le recalibrage §K** — sinon on calibre un faux système (les greffes +tag sont aujourd'hui des placebos, R137).
- **CDC-TEC-18** *(TEC-18-A)* — Télémétrie locale : **rotation cap 200 runs + agrégat mensuel compacté + purge du détail au-delà**. Garde l'historique des KPI (CDC-PRO-05), invisible pour le joueur.
- **CDC-TEC-19** *(TEC-19-A, arbitrage NAR-29)* — Lookahead : **statu quo N+1, décision pilotée par le taux de cache-miss (CDC-TEC-02)**. **Si miss >10 % → N+2 opportuniste** (CDC-NAR-29). Mesurer avant de complexifier le single-flight R110.
- **CDC-TEC-20** *(TEC-20-B)* — Config minimale : **min specs publiées, mesurées sur 2 machines de référence** (E2B + KV 4096 → ~6-8 GB RAM, 5 GB disque) + **micro-bench au premier boot (~10 s de génération)** — si tokens/s < seuil, avertissement honnête « les rêves de Merlin seront lents ». Réutilise le dashboard R96.

### 1.8 PRODUIT / QA — CDC-PRO (20 règles)

- **CDC-PRO-01** *(PRO-01-A ⚠ tranché)* — **Definition of DONE V1.0 (composite)** : gate R109 vert **ET** build EXPORTÉ passe autoplay **ET** distribution §K dans les cibles **ET** fleet QA PASS (§23 + charte) **ET** 3 playtesteurs externes finissent une run sans aide **ET** 2/3 relancent. Chaque clause ferme un trou connu de l'état réel.
- **CDC-PRO-02** *(PRO-02-A)* — **3 jalons** d'ici la release : **V4** (fleet QA + purge + §K + whitelist + export) → **v0.9 « beta export »** (méta, UX pack, playtests) → **v1.0 RC**. Rythme prouvé : 1 vague = 1 gate = 1 commit.
- **CDC-PRO-03** *(PRO-03-A)* — Fleet QA = **gate de sortie de CHAQUE vague livrée** : captures fraîches 8 phases ×2 biomes + checklist charte/anim/overlap/§23. Les régressions s'attrapent fraîches.
- **CDC-PRO-04** *(PRO-04-A)* — Playtests humains : **3 vagues × 3-5 joueurs (post-V4, post-v0.9, RC)** — think-aloud 30-45 min sans aide, grille d'observation (blocages, relances, verbalisation deltas CDC-UX-10) + questionnaire 10 items. 3 points de mesure = vérifier que les corrections corrigent.
- **CDC-PRO-05** *(PRO-05-A)* — **4 KPI de fun** (télémétrie locale, `cli godot telemetry`) : session médiane **≥25 min** · **≥60 %** des runs commencées finies · **≥40 %** de re-run dans la session · **<50 %** de beats skippés au typewriter. Chaque KPI mappe un pilier (rétention, complétion, rejouabilité, lecture).
- **CDC-PRO-06** *(PRO-06-A)* — Gates visuels : **job séparé post-gate** — captures 8 phases ×2 biomes + **diff screenshot vs baseline (seuil de pixels)**, échec = revue humaine. Ne JAMAIS mesurer le gate perf en mode capture (leçon v10.23).
- **CDC-PRO-07** *(PRO-07-A)* — Télémétrie réseau : **V1 zéro réseau** — tout local + bouton **« exporter mes stats »** (envoi volontaire par le joueur). Pas d'endpoint, pas de RGPD.
- **CDC-PRO-08** *(PRO-08-A)* — Budget : **timebox 8-12 sessions Claude par jalon** ; un chantier qui dépasse **×2 son estimation est découpé ou reporté V1.1**. Seul garde-fou anti-glissement d'un solo dev.
- **CDC-PRO-09** *(PRO-09-A ⚠ tranché)* — Distribution : **itch.io gratuit (dons ouverts)**, page soignée, zip tout-inclus. Steam réévalué si la traction itch le justifie (100 $ + review + AI disclosure).
- **CDC-PRO-10** *(PRO-10-A)* — Nom : **M.E.R.L.I.N. conservé + sous-titre évocateur** (ex. « les rêves de Brocéliande »), **après vérification rapide de collision** (stores, marques FR/EU).
- **CDC-PRO-11** *(PRO-11-A)* — Identité : **pack minimal** — wordmark existant + 4-6 captures canon + **GIF 15 s du jet de dé/fusion** + page itch à la charte parchemin. 1-2 sessions, outils du projet.
- **CDC-PRO-12** *(PRO-12-A)* — Licences : **audit par type d'asset AVANT la beta** ; toute pièce MusicGen douteuse (poids CC-BY-NC) est **regénérée via la forge procédurale maison**. Typos OFL, SFX maison, prose Gemma : OK.
- **CDC-PRO-13** *(PRO-13-A)* — Doc joueur : **page itch + README court** — install, min specs, « tout est généré localement, aucune donnée ne sort », crédits/licences. **Le gameplay reste 100 % in-game** (§15 : aucun panneau de règles).
- **CDC-PRO-14** *(PRO-14-A)* — Versioning **découplé** : interne continue (v11, V4…) ; **public = semver 0.9.0 beta → 1.0.0** ; mapping noté dans task_plan.
- **CDC-PRO-15** *(PRO-15-A)* — **Definition of FAIL — règle des deux échecs** : 2 vagues de tuning sans atteindre la cible chiffrée OU 2 vagues de playtest où **<50 % des joueurs comprennent la mécanique sans aide** → **pivot ou coupe**, décision notée à la bible. (Les greffes sont déjà en zone grise : 2,69 drafts/run vs 5-6, éclatante 2,8 % vs 8-15.)
- **CDC-PRO-16** *(PRO-16-A)* — Ordre d'arbitrage quand une vague déborde : **lisibilité/fun > fiabilité (R109/saves) > contenu (biomes, greffes) > polish (juice, audio)**. R109 n'est jamais négocié.
- **CDC-PRO-17** *(PRO-17-A)* — Recalibrage §K : **chantier V4 dédié multi-leviers** — whitelist §F (CDC-TEC-17) + fréquence de drafts remontée (CDC-BAL-11) + contre-pression §E (CDC-GD-32) + DIE_BANDS (CDC-BAL-12), **mesuré 300 runs ×5 archétypes après CHAQUE levier**. Un levier isolé ne suffit pas (preuve DIE_BANDS V3).
- **CDC-PRO-18** *(PRO-18-A, NB GD-17 + arbitrage NAR-17)* — **Périmètre contenu GELÉ** : 2 biomes, 4 verbes, 16 traits sains, 3 types de greffe, chaînes 2-3 quêtes — V1.0 = profondeur (calibrage, lisibilité, fiabilité, méta), **zéro système de contenu neuf**. Exemptions actées : fiches de figures (CDC-GD-17) et extension des **banques nommées** de greffes vers ~40 (CDC-NAR-17) = authoring sur types existants, pas du contenu mécanique.
- **CDC-PRO-19** *(PRO-19-A)* — Dette : **purge intégrée à V4** (banques legacy du chemin runtime, `addons/merlin_ai` hérité, agents `.claude/agents` périmés) + **`create_agent.py --validate` ajouté à la checklist de fin de jalon**.
- **CDC-PRO-20** *(PRO-20-A ⚠ implicite via PRO-01)* — **Critère beta → release : beta timeboxée 2-3 semaines** — **0 crash bloquant sur ≥20 runs humaines cumulées** + **saves migrées sans perte** + **KPI CDC-PRO-05 atteints sur ≥5 joueurs** + **zéro régression fleet QA**. La release = lecture de tableau de bord, pas un pari.

---

## 2. OBJECTIFS MESURABLES V1.0

| # | Métrique | Cible V1.0 | Dureté | Source CDC |
|---|---|---|---|---|
| K1 | Échec (% beats) | **3-8 %** | Gate DUR | BAL-01 |
| K2 | Partiel | **28-38 %** | Gate DUR | BAL-01 |
| K3 | Réussite | **45-55 %** | Gate DUR | BAL-01 |
| K4 | Éclatante | **8-15 %** | Gate DUR | BAL-01/02/25 |
| K5 | Morts — optimal | **≤10 %** | Gate DUR | BAL-04 |
| K6 | Morts — greedy / chaotic | **≤30 %** chacun | Gate DUR | BAL-04 |
| K7 | Morts — corrompu | **≤25 %** | Gate DUR | BAL-04 |
| K8 | Morts — tag-ignorant | non gaté (bot adversarial) | — | BAL-04 |
| K9 | Fins corrompues | **10-18 %** | ≤18 % DUR · ≥10 % LOGUÉE | BAL-23 |
| K10 | Corruption/run | **5,4 ±1,5** | Gate DUR | BAL-08 |
| K11 | Requis hors-pool | **0** (assertion whitelist §F) | Gate DUR | BAL-14/03 |
| K12 | Drafts/run | **5-6** | LOGUÉE | BAL-11/20 |
| K13 | Couverture pleine au climax | **45-55 %** (bande réussite, via « 2+1 ») | Gate DUR (via K3) | BAL-13 |
| K14 | Deadhand (main sans trait couvrant) | **≤45 %** | LOGUÉE | BAL-15 |
| K15 | Pushes/run | **0,5-1,5** | LOGUÉE | BAL-07/20 |
| K16 | Sabotage (beats sabotables, état Hostile) | **≤5 %** | LOGUÉE | BAL-24/GD-29 |
| P1 | Session médiane | **≥25 min** | KPI produit | PRO-05 |
| P2 | Runs commencées finies | **≥60 %** | KPI produit | PRO-05 |
| P3 | Re-run dans la session | **≥40 %** | KPI produit | PRO-05 |
| P4 | Beats skippés au typewriter | **<50 %** | KPI produit | PRO-05 |
| L1 | Latence cache-hit (R58) | sélection <5 s · situation <8 s · résolution <5 s | Gate R58 | TEC-02 |
| L2 | Cache-miss | **≤12 s**, accepté SI **taux de miss <10 %** des beats | Contrat couplé (sinon leviers N+2 / max_tokens 180) | TEC-02/NAR-29/TEC-19 |
| F1 | Framerate | **60 fps** | Gate DUR | TEC-12 |
| F2 | Hitch hors génération | **0 >33 ms** (captures 8 phases ×2 biomes) | Gate DUR | TEC-12 |
| F3 | Contraste chips Z4 | ratio **≥4.5:1** automatisé | Gate fleet QA | UX-21 |
| Q1 | Couverture SFX | 100 % des `play_sfx` du catalogue §22 joués à l'autoplay | Gate rejouable | AUD-20 |
| Q2 | Loudness | peak **≤−3 dB** tout asset · SFX **−14 dB** · musique **~−6 dB** | Gate asset | AUD-11 |
| D1 | **DoD V1.0 composite** | R109 vert + export passe autoplay + §K en cibles + fleet QA PASS + 3 playtesteurs finissent sans aide, 2/3 relancent | Gate release | PRO-01 |
| D2 | **Beta → release** | 2-3 sem. : 0 crash bloquant ≥20 runs humaines · saves migrées sans perte · KPI P1-P4 sur ≥5 joueurs · 0 régression fleet QA | Gate release | PRO-20 |

---

## 3. ROADMAP (3 jalons — CDC-PRO-02)

> Budget : **8-12 sessions Claude par jalon** (CDC-PRO-08). Arbitrage en cas de débord :
> lisibilité/fun > fiabilité > contenu > polish (CDC-PRO-16). Coupe/pivot : règle des deux échecs (CDC-PRO-15).

### Jalon 1 — **V4 « fondations mesurées »** (interne v11-V4)

**Ordre IMPOSÉ par les dépendances** (whitelist AVANT recalibrage AVANT contre-pression ; export gaté dès l'ouverture) :

1. **Export Windows gaté — dès l'ouverture du jalon** *(CDC-TEC-07)* : preset + gate R109 étendu « build exporté passe 1 autoplay complet ». Risque existentiel tué en premier.
2. **Purge & fondations données** *(CDC-PRO-19, TEC-10, TEC-11, TEC-13, TEC-14, TEC-16, TEC-18)* : dette runtime purgée, checksum+.bak saves, `chronicle.cfg` extrait, crash logs, seed persistée, sanitisation saves, rotation télémétrie. Avant que la méta ne s'y greffe.
3. **Whitelist §F + recomposition des requis** *(CDC-BAL-14, TEC-17, BAL-03, BAL-13, BAL-02)* : assertion dure 0 hors-pool, climax « 2+1 », porte éclatante allégée. **AVANT tout playtest externe et AVANT le recalibrage.** → re-mesure 300 runs ×5 archétypes.
4. **Recalibrage §K multi-leviers** *(CDC-PRO-17, BAL-11, BAL-12, BAL-25, BAL-04, BAL-20, BAL-19)* : drafts 5-6 (garanti transition + ouverture), retour DIE_BANDS 17/33/50/67, éclatante +1, gates morts par archétype, assertions dures/loguées, nightly 5×300. **Mesure après CHAQUE levier.**
5. **Contre-pression §E** *(CDC-GD-32)* : branchée **APRÈS** la re-mesure post-whitelist/recomposition, puis re-mesurée.
6. **Fleet QA opérationnelle** *(CDC-PRO-03, PRO-06, UX-21, UX-22, TEC-12, DA-16)* : captures 8 phases ×2 biomes ×2 résolutions, diff baseline, ratio contraste 4.5:1, gate perf 60 fps/0 hitch, vignette ≤72 px.
7. **Validations diverses** *(CDC-UX-03 tactile, UX-11 cooldown, UX-20 zone morte, AUD-15 resync fusion, AUD-20 gate audio, DA-13 tuning glitch, NAR-14 audit banques, NAR-24 logging LoRA, NAR-25 filtre étendu, TEC-20 min specs + micro-bench)*.
8. **Playtests vague 1** *(CDC-PRO-04)* : 3-5 joueurs post-V4, protocole verbal deltas (CDC-UX-10).

**Gate de sortie V4** : soak 200/200 + autoplay 3/3 (R109) **ET** build exporté passe 1 autoplay **ET** assertion 0 hors-pool verte **ET** distribution §K dans les cibles (K1-K10) **ET** fleet QA PASS **ET** playtests vague 1 réalisés.

### Jalon 2 — **v0.9 « beta » (public 0.9.0)**

**Chantiers** (la méta d'abord, les artworks après validation du cache) :

1. **Méta Graal complète** : fragments 12 + cadence + vignettes/codas *(CDC-GD-01/02/03/04/05, NAR-03)* ; **seuil onirique** (jalons + bilan + codex + décision souvenir, flux fin→seuil→menu) *(CDC-GD-09/39, UX-17, DA-15)* ; **codex** 20→40 entrées, 2 niveaux, chronique auto *(CDC-GD-11/12, NAR-19/20, DA-05)* ; **réputation** 3 effets + amortie + sabotage Hostile ≤5 % *(CDC-GD-13/14/29, BAL-24)* ; **souvenirs** swap 1-pour-1 *(CDC-GD-36, BAL-16, BAL-25)* ; **promesses** légères *(CDC-GD-37)* ; **mémoire PNJ + arcs 3 stades + Arthur + figures** *(CDC-GD-15/17, NAR-07/08/09/10/11/16)* ; **fins-méta 3+1 + sélection hybride + run finale « Le Graal » + Fusion** *(CDC-GD-06/07/08, NAR-04/05/06)* ; **NG+ narratif** *(CDC-GD-16)* ; **gating Falaises + différenciation biomes + quêtes signature** *(CDC-GD-18/19, NAR-02, DA-10/12)* ; **ramification visible + draft garanti + interventions Favorable** *(CDC-GD-21/27/38, NAR-30)* ; **Enfant : quête de révélation** *(CDC-GD-30, NAR-09)* ; remplacement à cap *(CDC-GD-22)*. Re-soak après chaque système (CDC-BAL-19).
2. **Artworks par quête — APRÈS validation du cache** *(CDC-DA-01/02/03/04/05)* : ~30 images de lieux pré-générées, duotone strict, **validées à la main**, puis câblage bandeau Z3 96-120 px + portraits codex. Aucun live.
3. **Musique réactive & audio** *(CDC-AUD-01/02/04/05/06/08/09/10/12/14/16)* : couche corruption (music_forge offline), crossfades, stingers de fin, `graft_set`, blips 1/3, timbre murmure, ducking typewriter, bus Voice, son du dé, SFX interventions.
4. **Streaming résolution** *(CDC-TEC-01)* + politique lookahead mesurée *(CDC-TEC-02/19, NAR-29)*.
5. **Pack UX / accessibilité** *(CDC-UX-01/04/05/06/07/08/09/12/13/16/18/19/24/25, GD-26/34/35, DA-17/18/19, UX-14/15, AUD-17/18/19, NAR-15/UX-23)* : clavier 6 touches, pause + options in-pause, pack lecture, fil VN quête, hints 5, tooltips greffes, écran LLM KO, stats de fin, confirmation abandon, symétrie pactes, reprise contextuelle, assist, mode vétéran, contraste, décor calme, tailles texte, glyphes famille, mute M, chaînes UI extraites.
6. **Produit** *(CDC-PRO-10/11/12/13/14)* : vérif nom, pack identité itch, audit licences (MusicGen regénéré si douteux), README, semver public 0.9.0.
7. **Playtests vague 2** *(CDC-PRO-04)* post-v0.9.

**Gate de sortie v0.9** : R109 vert avec la méta embarquée **ET** export autoplay PASS **ET** fleet QA PASS (visuel + audio + contraste) **ET** dérive §K nightly dans les tolérances **ET** KPI instrumentés **ET** playtests vague 2 réalisés → **beta publique itch 0.9.0**.

### Jalon 3 — **v1.0 RC → release**

1. **Beta publique timeboxée 2-3 semaines** *(CDC-PRO-20)* : collecte crash logs (CDC-TEC-13), stats exportées volontairement (CDC-PRO-07), corrections au fil de l'eau (arbitrage CDC-PRO-16).
2. **Playtests vague 3 (RC)** *(CDC-PRO-04)* + vérification KPI sur ≥5 joueurs.
3. **Verrou de release** *(CDC-PRO-20)* : 0 crash bloquant sur ≥20 runs humaines cumulées · saves migrées sans perte · KPI P1-P4 atteints · zéro régression fleet QA.
4. **DoD composite final** *(CDC-PRO-01)* vérifié clause par clause → **release 1.0.0 itch.io** (CDC-PRO-09).

---

## 4. RENVOIS BIBLE — amendements canon à reporter dans `docs/BIBLE.md`

> Chaque item = 1 amendement R-numéroté ou §-versionné, avec la règle CDC source. À traiter par vagues, per CLAUDE.md §10.3 (update per-feature complète).

1. **R20 — amender** : « le degré et tout effet mécanique sont 100 % code ; **le LLM ne décide jamais rien de mécanique**, il habille » (CDC-NAR-26).
2. **R53 — amender** : liserés de rareté **statiques** + glow throttlé ; l'irisé animé Mythique est abandonné — le liseré encode la qualité de dé (R133) (CDC-DA-09).
3. **R99 — amender** : « clavier de base » précisé en **clavier minimal 6 touches** (Espace/Échap/1-4/A-D/Entrée) ; manette confirmée post-V1 (CDC-UX-01/02).
4. **§22 — amender loudness** : gate anti-clip **peak ≤ −3 dB** pour tout asset · norme de mix **SFX −14 dB** · musique **~−6 dB** (CDC-AUD-11). Compléter : ducking typewriter −3 dB (CDC-AUD-10), 4e bus Voice (CDC-AUD-12), 3 stingers de fin (CDC-AUD-06), musique réactive 2 couches indexée R75 (CDC-AUD-01/02), gate de couverture audio autoplay (CDC-AUD-20).
5. **R74 — amender au périmètre réel V1** : pack lecture (vitesse typewriter, afficher direct, tailles de texte 2 paliers Z3 puis 3 si audit) + contraste renforcé câblé + « décor calme » ; **police dys et presets perf → V1.1** ; presets Éco/Équilibré/Perf remplacés par auto-détect (CDC-UX-06/07/15, DA-17/18/19, TEC-06).
6. **R80 — amender** : **12 fragments** V1.0 (20-30 réservé version ~8 biomes) ; cadence mixte 1/Accomplissement + bonus hauts faits ; fragment sombre distinct en fin corrompue (CDC-GD-02/03/05).
7. **R44/R89 — amender** : Fusion **jouable V1.0** via run finale « Le Graal » ; **3 fins-méta + 1 cachée** ; sélection **hybride** (l'état débloque, le joueur choisit) ; NG+ = relecture narrative pure (CDC-GD-01/06/07/08/16, NAR-04).
8. **R50 — amender** : seuil onirique V1.0 = jalons + bilan + **codex + décision trait-souvenir** ; flux fin → seuil → menu, consultable du menu (CDC-GD-09/39, UX-17).
9. **R42/R92 — amender** : réputation **3 effets remappés v11** (greffe offerte / tag antagoniste / pool teinté) ; persistance **amortie 1 cran vers Neutre/run** ; sabotage = effet d'Hostile, **≤5 % des beats** (CDC-GD-13/14/29, BAL-24).
10. **R49/R90/R92 — re-spec traits-souvenir** : swap 1-pour-1 sur les 16 traits, proposé au seuil après run marquante ; sélection contextuelle du pool de draft + sous-titre de lieu (CDC-GD-36, BAL-16, NAR-18).
11. **R65 — préciser** : éclatante = **+1 Intégrité fixe** (remplace « +0/+1 ») + déclencheur souvenir/secret codex ; porte sans la clause « trait couvre ≥1 requis » (CDC-BAL-25/02).
12. **R58 — compléter** : budget épilogue **120-180 mots / max_tokens ~280** ; max_tokens **par type de beat** ; bloc chronique injecté **cappé ~60 tokens** (CDC-NAR-06/12, TEC-04).
13. **R57 — amender** : streaming V1 **sur la résolution seule** (prose sans GBNF) ; JSON incrémental post-V1 (CDC-TEC-01).
14. **R109 — étendre** : gate **« build exporté passe 1 autoplay complet »** + soak **nightly 5×300** avec rapport de dérive §K (CDC-TEC-07, BAL-19).
15. **R108 — compléter** : confirmation d'abandon sur Nouvelle partie ; **checksum + .bak rotative** ; chronique extraite vers `user://chronicle.cfg` ; résumé glissant en tête de fil Z3 à la reprise (CDC-UX-19/25, TEC-10/11).
16. **R136 — compléter les exceptions** : overlay **pause système** (hors zéro-modal-de-phase) ; **cooldown Résoudre 250 ms** ; **zone morte skip 300 ms** ; vignette **compactée ≤72 px** ; remplacement de greffe à cap en 2 gestes (CDC-UX-04/11/20/22, GD-22).
17. **R70/§20 — trancher fonts** : **Cinzel + EB Garamond embarquées** (OFL), Theme global titres/corps ; ajouts palette **par constantes nommées MerlinVisual + miroir §20** uniquement (CDC-DA-07/06).
18. **§11/§23 — renforcer** : **glyphe de famille partout** où la couleur est porteuse (6 formes) ; reduce-motion **étendu aux SFX décoratifs** (conserve l'information) ; hover des greffes enrichit sans révéler (CDC-UX-14, DA-08/20, AUD-19).
19. **§24 — compléter pipeline artworks** : 1 image/**quête**, duotone strict CREAM/INK, cache **100 % pré-validé main (~30 lieux), zéro live V1**, bandeau Z3 96-120 px, portraits codex ; gate **captures 2 résolutions** (1080p + 720p) ; passe tuning glitch palier 15+ avec captures aux 4 paliers (CDC-DA-01…05/13/16).
20. **§14 — compléter** : **Windows seul** V1.0 ; **E2B Q4_K_M figé** ; **CPU only** ; zip ~4 GB itch 100 % offline ; **min specs publiées + micro-bench 1er boot** (CDC-TEC-03/05/08/09/20, PRO-09).
21. **R61/R96 — étendre** : filtre termes interdits (méta doux + tics LLM + anachronismes) ; **sanitisation des saves au load** avant réinjection ; **GemmaConsole/TweaksOverlay hors export, flag `--console` éditeur/debug seulement** ; fallback toujours invisible (télémétrie seule) (CDC-NAR-25/27/28, TEC-15/16).
22. **R77/R31 — étendre** : **5 hints one-shot** diégétiques, cap 1/beat (verbe+trait, dé/liseré, push, greffe, seuil) (CDC-GD-35, UX-16).
23. **R93 — remplacer** par le **DoD composite V1.0** (CDC-PRO-01) ; ajouter **Definition of FAIL** (règle des deux échecs, CDC-PRO-15) et **ordre d'arbitrage** lisibilité > fiabilité > contenu > polish (CDC-PRO-16).
24. **R97 — préciser** : Falaises **gated par le 1er Accomplissement** ; **2 biomes V1** ; différenciation = pondérations tags + FACTION_WEIGHTS + quête signature + figure exclusive (CDC-GD-18/19, DA-11).
25. **R127/R60 — étendre mémoire** : 3 souvenirs préambule ~40 tokens ; mémoire PNJ 3 états + pactes/promesses + résumé injecté ; **arcs 3 stades par pilier** ; révélation Enfant si complicité ≥2 (CDC-NAR-16, GD-15, NAR-07/09).
26. **R120/R130/R131 — compléter** : **choix visible de la quête suivante (2 titres du pool)** ; **draft garanti** transition + ouverture ; interventions **1/run +1 si Favorable** ; **promesse légère 1/run** ; climax = mise en scène dédiée sans règle neuve ; charges à épuisement définitif (CDC-GD-21/24/27/28/37/38, BAL-11, NAR-30).
27. **R98 — compléter** : rotation télémétrie **cap 200 runs + agrégat mensuel** ; **dataset LoRA JSONL** des sorties propres ; export stats manuel, **zéro réseau V1** (CDC-TEC-18, NAR-24, PRO-07).
28. **R59 — compléter** : **seed persistée dans la save + affichée sur MerlinEnd** (CDC-TEC-14).
29. **R124 — amender blips** : **1/3 lettres** sur prose longue, pitch **±4 %**, **timbre « murmure »** pour les lignes signées de pilier ; mute global touche M (CDC-AUD-08/09/18).
30. **§K (spec v11) — figer les cibles CDC** : tableau §2 ci-dessus = référence unique des assertions dures/loguées (CDC-BAL-01…25) ; nouvelle règle R-numérotée « whitelist §F obligatoire, assertion 0 hors-pool » (CDC-BAL-14).

---

*Fin du CDC V1.0 — 200 règles. Toute modification passe par un amendement tracé (règle CDC + question source) et, si mécanique, par le protocole de re-mesure CDC-BAL-19.*
