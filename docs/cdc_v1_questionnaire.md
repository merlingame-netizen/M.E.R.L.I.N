# M.E.R.L.I.N. — CAHIER DES CHARGES V1.0 : QUESTIONNAIRE (200 questions, tous métiers)

> Généré le 2026-07-04 par panel 3 agents (game design+balance / narratif+DA+audio / UX+tech+produit),
> ancré sur le canon réel (BIBLE R1-R137, specs v11, mesures soak). Horizon : **V1.0 jouable complète**.

## MODE D'EMPLOI

- Répondez en ÉDITANT ce fichier : sous chaque question, ajoutez une ligne
  `> RÉPONSE : B` (ou `> RÉPONSE : B, mais …` pour nuancer, ou du texte libre).
- **Toute question NON annotée = la RECO est adoptée** (mécanisme anti-enlisement).
- Quand vous avez fini (ou décidé de déléguer le reste aux recos), dites-le en session :
  « questionnaire annoté » — les 200 réponses seront consolidées en cahier des charges
  (`docs/cdc_v1.md`), reportées à la BIBLE en règles R-numérotées, et le dev reprendra par
  vagues gatées R109.

## ⚠ 12 QUESTIONS STRUCTURANTES (à trancher en priorité — elles conditionnent des dizaines d'autres)

| # | Sujet | Conditionne |
|---|---|---|
| GD-01 | La fin du Graal jouable en V1.0 ? | Toute la méta (GD-02→10, NAR-03/04) |
| GD-02 | Nombre de fragments (8/12/20-30) | Durée de vie, cadence méta |
| GD-09 | Périmètre du seuil onirique | Codex, souvenirs, flux de fin |
| GD-13 | Effets mécaniques de la réputation | Sabotage, interventions, banques |
| NAR-04 | La Fusion en V1 ou teasing | Fins-méta, NG+ |
| DA-01 | Artworks générés GO/NO-GO | Pipeline SD, placement Z3, cache |
| AUD-01 | Musique gameplay réactive | Stems, bus, mixage |
| TEC-01 | Streaming LLM token-par-token | Typewriter, latence perçue |
| TEC-07 | Gate d'export Windows dès V4 | Risque existentiel GDExtension/pack |
| BAL-14 | Whitelist §F obligatoire V1 | TOUT l'équilibrage (BAL-01/03/12/13) |
| PRO-01 | Definition of DONE V1.0 | Tous les jalons |
| PRO-09 | Distribution (itch/Steam) | Licences, packaging, identité |

Ces 12 ont été TRANCHÉES en session interactive le 2026-07-04 (réponses inscrites sous chaque
question) — **toutes suivent la RECO**. Les 188 autres suivent le mécanisme « non annotée = reco ».

---

<!-- ============ PARTIE GAME DESIGN + BALANCE (65) ============ -->

**Sommaire des thèmes**
- **Graal & fins (GD-01→08)** : victoire atteignable, fragments (nombre/cadence/contenu), run finale, fins-méta et leur sélection.
- **Méta & seuil onirique (GD-09→10)** : périmètre du seuil, persistance du build cross-run.
- **Codex (GD-11→12)** : taille et déclencheurs de déblocage.
- **Réputation factions (GD-13→14)** : effets mécaniques post-pivot, persistance.
- **PNJ & narration persistante (GD-15→16)** : contenu de la mémoire PNJ, règles du NG+ éclairé.
- **Contenu monde (GD-17→19)** : roster V1.0, différenciation des 2 biomes, gating du biome 2.
- **Structure de run (GD-20→21)** : longueur cible, ramification v2.
- **Greffes & économie (GD-22→24)** : cap/remplacement, retrait, charges.
- **Mort & difficulté (GD-25→26)** : punition exacte, modes/assist.
- **Quêtes & climax (GD-27→28)** : récompense intermédiaire, mécanique du climax.
- **Systèmes dormants (GD-29→32)** : sabotage R66, payoff de l'Enfant, limites des pactes, contre-pression §E.
- **Rythme & confort (GD-33→35)** : durée d'un beat, accélération vétérans, hints d'onboarding.
- **Mémoire du joueur (GD-36→37)** : traits-souvenir (re-spec R49/R90/R92), promesses R91.
- **Interventions & fin de run (GD-38→40)** : cadence des interventions, flux de fin, écran de fin.
- **BAL — Distribution (BAL-01→04)** : cibles finales, levier éclatante, levier échec, morts par archétype.
- **BAL — Barème jauges (BAL-05→10)** : INTEGRITE_DELTA, répit, push, corruption/run, seuils, cap 18.
- **BAL — Drafts & dé (BAL-11→12)** : fréquence de drafts, table de dé finale.
- **BAL — Requis & whitelist (BAL-13→14)** : composition du climax, whitelist obligatoire.
- **BAL — Deck de traits (BAL-15→18)** : deadhand, taille du pool, injection corrompus, cap/main.
- **BAL — Process (BAL-19→20)** : cadence de recalibrage, dureté des assertions.
- **BAL — Récompenses (BAL-21→25)** : charges, prix des pactes, fins corrompues, sabotage, bonus éclatante.

## PARTIE 1 — GAME DESIGN / RÈGLES (40 questions)

### GD-01 — ⚠ Victoire du Graal en V1.0
Le canon (R44/R80) fixe une quête longue de ~20-30 fragments avant la fusion avec Merlin, mais aucune victoire finale n'est aujourd'hui jouable (fin de run → menu). La V1.0 doit-elle contenir la vraie fin ?
- **A.** Oui : le Graal est atteignable et la fin Fusion est jouable en V1.0.
- **B.** Non : V1.0 s'arrête à la boucle méta (fragments + seuil), la fin arrive en V1.1.
- **C.** Hybride : la fin existe mais derrière un mur haut (~25 fragments), assumée comme rarement vue.
- **RECO : A** — un deck-builder narratif sans fin réelle casse la promesse « chaque run = un pas vers le Graal » (R43) ; c'est LE critère qui sépare la V1.0 d'une démo.

> **RÉPONSE : A** *(tranché en session interactive, 2026-07-04)*

### GD-02 — ⚠ Nombre total de fragments
R80 chiffre ~20-30 fragments ; à ~20-30 min/run, cela fait 8-15 h minimum avant la fin. Quel total pour la V1.0 ?
- **A.** 20-30 (canon strict, jeu long).
- **B.** 12 fragments (fin atteignable en ~10-14 runs).
- **C.** 8 fragments à valeur narrative forte (fin en ~8-10 runs, chaque fragment = une révélation majeure).
- **RECO : B** — préserve l'esprit « longue quête » de R80 sans exiger un volume de contenu de révélations que 2 biomes ne peuvent pas porter ; 20-30 se garde pour la version à ~8 biomes (R97).

> **RÉPONSE : B** *(tranché en session interactive, 2026-07-04)*

### GD-03 — Cadence de gain des fragments
R80 fixe une cadence « conditionnelle (hauts faits), pas un compteur », mais R43/R69 disent « chaque run dévoile un fragment ». Quelle règle en V1.0 ?
- **A.** 1 fragment par fin Accomplissement, 0 sinon (simple, lisible).
- **B.** Conditionnel pur R80 : hauts faits (1re victoire sur un pilier, seuil de réputation, fin éclatante au climax).
- **C.** Mixte : 1 par Accomplissement + fragments bonus rares sur hauts faits (accélère les bons runs).
- **RECO : C** — résout la contradiction R43↔R80 en gardant un plancher lisible (l'Accomplissement paie toujours) et une raison de sur-performer.

### GD-04 — Contenu d'un fragment révélé
L'épilogue « dévoile un fragment du Graal » (R69) mais rien n'est spécifié. Que voit concrètement le joueur ?
- **A.** Prose LLM libre contrainte par un thème canon injecté (1 thème pré-écrit par fragment).
- **B.** 8-12 vignettes canon pré-écrites (contrôle total du crescendo vers la révélation Fusion, R44).
- **C.** Mixte : vignette canon courte + coda LLM personnalisée par l'état de la run.
- **RECO : C** — la révélation finale R44 est trop précieuse pour être laissée au LLM (risque 4e mur), mais la coda personnalisée préserve le pilier « jamais deux runs pareilles » (R67).

### GD-05 — Fragments et fin corrompue
La bascule corrompue (R64/R69) est une fin à part entière (mesurée 14,5 % des runs). Donne-t-elle un fragment ?
- **A.** Aucun fragment (seule la « bonne » fin avance la quête).
- **B.** Un fragment sombre distinct, comptant pour la fin Corruption totale (R89 : l'Enfant naît à ta place).
- **C.** Fragment normal (toute fin avance).
- **RECO : B** — donne un sens méta aux runs perdues à la Corruption et matérialise le « cycle rival » (R40/R89) sans récompenser indistinctement l'échec.

### GD-06 — La run finale du Graal
Une fois les fragments réunis, comment se joue la fin ?
- **A.** Run spéciale « Le Graal » débloquée au seuil : biome altéré/glitché (R97), chaîne unique, climax final dédié.
- **B.** La fin se joue au seuil onirique (séquence narrative sans run).
- **C.** Le dernier fragment déclenche directement l'épilogue-méta à la fin de la run courante.
- **RECO : A** — la fusion doit se MÉRITER en jeu (pilier R67 « les choix mécaniques priment ») et la chaîne de quêtes existante (R120) fournit la structure sans nouveau système.

### GD-07 — Nombre de fins-méta V1.0
R89 pose 3 archétypes (Fusion / Refus / Corruption totale) « + fin(s) cachée(s) possibles ». Combien en V1.0 ?
- **A.** 3 exactement (les archétypes canon).
- **B.** 3 + 1 cachée (le Refus véritable, gated par une condition secrète type zéro pacte sur la run finale).
- **C.** 5-6 avec variantes par faction dominante.
- **RECO : B** — la fin cachée alimente le bouche-à-oreille et le NG+ sans multiplier le coût de contenu ; les variantes par faction passent par la coda LLM (GD-04), pas par des fins distinctes.

### GD-08 — Sélection de la fin-méta
Comment la fin-méta est-elle déterminée à la run finale ?
- **A.** État seul (Corruption cumulée, factions, choix) — composition automatique R89.
- **B.** Choix explicite au climax final entre les fins dont les conditions sont remplies.
- **C.** Hybride : l'état DÉBLOQUE les options, le joueur choisit dans ce qui reste ouvert.
- **RECO : C** — l'agentivité au moment le plus important (R67) tout en gardant le poids du parcours ; une fin subie sans choix contredirait « les choix mécaniques priment ».

### GD-09 — ⚠ Périmètre du seuil onirique V1.0
R50 définit le seuil (post-MVP) : jalons du Graal, gestion du deck, codex, bilan Merlin. Que construit-on en V1.0 ?
- **A.** Minimal : jalons du Graal + bilan Merlin (2 panneaux, voix+texte).
- **B.** A + codex consultable.
- **C.** B + décision de fin de run : garder/refuser le trait-souvenir proposé (GD-36).
- **RECO : C** — le seuil est le hub qui donne du sens à la méta ; sans la décision du souvenir il n'est qu'un écran de stats, et R50 liste déjà « épurer/gérer le deck » comme action canon.

> **RÉPONSE : C** *(tranché en session interactive, 2026-07-04)*

### GD-10 — Persistance du build cross-run
Post-pivot, verbes + greffes reset à chaque run (R26 « reset par run »). Qu'est-ce qui persiste en V1.0 ?
- **A.** Reset total (pureté roguelike, seuls fragments/codex/chronique persistent).
- **B.** 1 greffe de départ choisie au seuil parmi les débloquées (hauts faits R80).
- **C.** Le POOL de greffes draftables s'élargit cross-run (déblocages R26), sans greffe de départ.
- **RECO : C** — c'est exactement le modèle canon R26 (« déblocages élargissent le pool futur ») : de la variété sans power-creep, donc sans re-dérivation des cibles soak à chaque déblocage.

### GD-11 — Taille du codex V1.0
R43/R50 promettent un codex, jamais spécifié. Quelle taille pour 2 biomes ?
- **A.** ~20 entrées (5 piliers, 4 factions, Arthur/Merlin, ~8 lieux archétypaux R88).
- **B.** ~40 entrées (A + 1 entrée par fragment, secrets des piliers R82-R85, combos découverts).
- **C.** ~60+ entrées (encyclopédie).
- **RECO : B** — assez pour récompenser la curiosité sur ~10-14 runs (GD-02) sans créer un chantier rédactionnel qui retarde la V1.0.

### GD-12 — Déblocage du codex
Comment les entrées se débloquent-elles ?
- **A.** Automatique à la 1re rencontre (pilier croisé, lieu visité, seuil franchi).
- **B.** Par hauts faits uniquement (R80).
- **C.** Mixte : rencontre = entrée de base ; l'éclatante ou un haut fait révèle le SECRET de l'entrée (2e niveau).
- **RECO : C** — donne à l'éclatante une récompense désirable (nécessaire pour la faire viser, cf. BAL-25) et met le contenu profond (secrets R82-R85) derrière la maîtrise.

### GD-13 — ⚠ Effets mécaniques de la réputation
R42/R92 (3 états Hostile/Neutre/Favorable) est annoncé, non construit. Post-pivot, les « cartes de faction » n'existent plus. Quels effets en V1.0 ?
- **A.** Narratif seul : ton des PNJ + variantes de dialogue (pas d'effet chiffré).
- **B.** 3 effets : Favorable = 1 greffe de la banque du pilier offerte (prix one-shot annulé) ; Hostile = 1 tag antagoniste sur les beats de la faction (sabotage R92) ; routes/quêtes du pool teintées.
- **C.** R92 complet (difficulté modulée, routes fermées, sabotage, dons).
- **RECO : B** — remappe naturellement R92 sur les systèmes v11 réels (banques de greffes §E, sabotage déjà dans resolve(), pool de quêtes R120) sans nouveau moteur.

> **RÉPONSE : B** *(tranché en session interactive, 2026-07-04)*

### GD-14 — Persistance de la réputation
R42 : la faveur « persiste en partie cross-run via les PNJ récurrents ». Quelle règle exacte ?
- **A.** In-run seulement (reset à chaque run).
- **B.** Persistance complète (jauge sauvée dans la chronique).
- **C.** Persistance amortie : rappel de 1 cran vers Neutre entre les runs (l'extrême se mérite en continu).
- **RECO : C** — traduit littéralement le « en partie » canon, évite qu'un état Hostile précoce condamne définitivement une faction sur 10+ runs.

### GD-15 — Contenu de la mémoire PNJ
MerlinChronicle stocke déjà runs_played, palmarès, dernier pilier (`pnj_recog`, R127-B). Que mémorise-t-on de plus en V1.0 (R17/R27) ?
- **A.** Statu quo + relation à 3 états par pilier (méfiant/neutre/lié).
- **B.** A + pactes acceptés/refusés et promesses tenues/trahies par pilier (les tentateurs se souviennent).
- **C.** B + citation d'actes précis : le résumé final de run (R27, déjà spécifié persistant) injecté quand le pilier revient.
- **RECO : C** — le coût est faible (le résumé final est déjà canon-persistant R27/R60) et « il se souvient de ce que J'AI fait » est le payoff émotionnel le plus fort du jeu.

### GD-16 — Règles du NG+ éclairé
R44/R89 : NG+ = rejouer conscient, Merlin moins muselé. Que change-t-il mécaniquement en V1.0 ?
- **A.** Narratif seul : préfixe de prompt NG+ (Merlin allusif, PNJ qui reconnaissent, indices méta assumés), zéro règle changée.
- **B.** A + 4e slot de greffe par action (puissance de relecture).
- **C.** A + difficulté relevée (requis +1 sur les climax).
- **RECO : A** — le NG+ n'est vu qu'après la fusion (audience minime au lancement) ; R89 le définit comme une RELECTURE, et toute variante mécanique imposerait une passe de soak dédiée injustifiable en V1.0.

### GD-17 — Roster V1.0
Le canon vise 20+ personnages (R10) ; le jeu réel a Merlin + 5 piliers + Arthur. Combien de figures pour la V1.0 ?
- **A.** 7 actuels, étoffés (plus de dialogues/interventions par pilier).
- **B.** 10-12 : + 1 figure de passage nommée par faction, dont 1-2 propres aux Falaises (R132).
- **C.** 20+ canon complet.
- **RECO : B** — les fiches canon sont peu coûteuses (format R34) et le biome 2 a besoin d'habitants propres pour exister ; 20+ reste l'horizon post-V1.0.

### GD-18 — Différenciation mécanique des 2 biomes
Les Falaises (R132) sont visuelles ; R7 canon dit qu'un biome oriente « tags dominants + pression de Corruption ». Quelle différenciation en V1.0 ?
- **A.** Cosmétique + préambule lore (statu quo).
- **B.** Pondérations : tags favorisés par biome dans la génération des requis + FACTION_WEIGHTS propres (Chevalerie dominante aux Falaises).
- **C.** B + 1 quête signature et 1 figure exclusive par biome.
- **RECO : C** — B seul est invisible pour un joueur non-analyste ; une quête signature rend le biome mémorable et le surcoût est borné (1 squelette contraint + 1 fiche).

### GD-19 — Gating du biome 2
Aujourd'hui l'overlay propose les 2 biomes librement (R132). En V1.0 avec méta ?
- **A.** Libre dès le début (statu quo).
- **B.** Falaises débloquées par le 1er Accomplissement (R97 : « débloqués par la méta »).
- **C.** Débloquées à N fragments (ex. 3).
- **RECO : B** — canon R97, donne un premier jalon méta immédiat et gratuit, sans frustrer (1 run réussie suffit).

### GD-20 — Longueur de run cible
La chaîne actuelle fait 2-3 quêtes de 2-5 beats (4-15 beats, chaînes de 12-14 mesurées au gate). Quelle cible V1.0 ?
- **A.** Courte : 8-10 beats, ~15-20 min (méta à 12 fragments = ~3-4 h avant la fin).
- **B.** Moyenne : 10-14 beats, ~20-30 min (statu quo cadré).
- **C.** Variable assumée 8-15 beats selon tirage.
- **RECO : B** — la cadence drafts 5-6/run et la chaîne 2-3 quêtes (R120) sont calibrées pour cette longueur ; A affamerait les greffes, C rend les cibles soak par-run incomparables.

### GD-21 — Ramification v2
La v1 bascule Épreuve↔Dilemme avant le climax des quêtes k≥4 (R120), couverture mesurée faible. Quelle profondeur en V1.0 ?
- **A.** Statu quo (bascule réactive seule).
- **B.** Bascule étendue : ~1 beat basculable par quête, dès la quête 1.
- **C.** Choix VISIBLE de la quête suivante : à chaque transition, 2 titres du pool (R120 « pool de sélection ») présentés au joueur.
- **RECO : C** — transforme une ramification invisible en décision réelle avec le pool déjà existant ; c'est le meilleur ratio agentivité/coût du chantier structure.

### GD-22 — Draft à cap atteint (4e greffe)
La spec §E prévoit un modal de REMPLACEMENT à la 4e greffe, mais la V3 livrée coupe le draft à 4 actions pleines (task_plan) — contradiction à trancher.
- **A.** Draft coupé à cap plein (statu quo V3, fin de run sans récompense de draft).
- **B.** Remplacement en 2 gestes dans les zones (R136 zéro modal) : remplacement sec, prix de la greffe sortante perdu.
- **C.** À cap plein, le draft devient récompense alternative (HEAL 2 / PURGE 1 au choix).
- **RECO : B** — avec E[drafts] visé 5-6 et cap 12, le cap plein reste rare mais le remplacement préserve la décision de build en fin de run longue ; C dilue l'identité « le draft = greffe » (R137).

### GD-23 — Greffes retirables
Une greffe posée (dont pactes à +1 Corruption) est-elle retirable en V1.0 ?
- **A.** Non : permanente, seul le remplacement (GD-22) l'écrase.
- **B.** Oui au seuil onirique (entre les runs) — sans objet si le build reset (GD-10).
- **C.** Oui en run via un rite du Chœur à prix (écho purification R49).
- **RECO : A** — le build reset par run rend B vide, et C cannibalise la PURGE (qui cible les traits corrompus) ; la permanence donne du poids au choix de draft.

### GD-24 — Économie des charges
Les charges (HEAL 1-2 ×2, PURGE ×2, DRAW ×2, spec §E) sont consommées à la pose du verbe, sans recharge. Règle V1.0 ?
- **A.** Épuisement définitif pour la run (statu quo) : la charge est un burst, le slot reste rempli.
- **B.** Recharge complète au répit de quête (R120).
- **C.** Recharge de 1 au répit.
- **RECO : A** — la recharge ferait des charges le type dominant du draft (2-3 répits/run = ×2-3 la valeur) et invaliderait le chiffrage corruption/run ; re-mesurer avant tout assouplissement.

### GD-25 — Mort : ce qui survit
La mort narrative (R69) renvoie au menu. En V1.0 avec méta, que garde-t-on ? (canon R43 : « surtout du gain, recul rare »).
- **A.** Tout sauf le fragment : codex, chronique, réputation, déblocages persistent ; pas de fragment.
- **B.** A + fragment de consolation si ≥ quête 2 atteinte.
- **C.** Recul : perte d'un fragment déjà acquis.
- **RECO : A** — conforme à R43 (pas de mur, recul rare) ; avec ~37 % de morts mesurées aujourd'hui, C serait punitif au point de bloquer la méta, B affaiblit la mort.

### GD-26 — Modes de difficulté / assist
La V1.0 doit-elle proposer des modes, sachant que toutes les cibles §K sont calibrées sur UNE difficulté ?
- **A.** Aucun mode : une difficulté canon + accessibilité existante (R74/R99).
- **B.** Assist opt-in discret : dé une bande au-dessus + répit +1 (marqué dans la chronique, fins inchangées).
- **C.** 3 modes complets avec cibles soak distinctes.
- **RECO : B** — un filet pour les joueurs narratifs sans tripler le travail de recalibrage (C = 3 jeux de cibles §K à maintenir) ; cohérent « zéro timer, confort d'abord » (R99).

### GD-27 — Récompense de quête intermédiaire
Finir une quête donne aujourd'hui le répit (+2/+4 Intégrité, recharge push, R120/R130). Faut-il enrichir pour la V1.0 ?
- **A.** Statu quo.
- **B.** + draft de greffe GARANTI à chaque transition de quête (sert la cible 5-6 drafts/run, cf. BAL-11).
- **C.** B + le choix de la quête suivante (lié GD-21-C).
- **RECO : C** — la transition de quête devient le temps fort de respiration/décision de la run (build + route), au lieu d'un simple +2 automatique.

### GD-28 — Mécanique spéciale du climax
Le climax est diff 3, interventions interdites (R131), degré → épilogue (R68). Faut-il plus en V1.0 ?
- **A.** Rien de plus (la difficulté et l'enjeu suffisent).
- **B.** Mise en scène dédiée : stinger + séquence de dé « héros » (passe merlin-juice prévue) + prose rallongée, zéro règle nouvelle.
- **C.** Règle spéciale : pas de partiel au climax (Encaisser/Pousser forcé en réussite/échec).
- **RECO : B** — C casserait R130 (le partiel-choix est le meilleur moment de décision du jeu) ; le climax a un déficit de spectacle, pas de règles.

### GD-29 — Réactivation du sabotage R66
`antagonist_tags` existe dans resolve() (R41/R66) mais n'est plus alimenté par la génération ; la spec §K demande sa fréquence loguée. Statut V1.0 ?
- **A.** Réactivé partout : 1 tag antagoniste possible sur Dilemme/Climax, tiré de la whitelist §F.
- **B.** Réservé à l'état Hostile de la réputation (R92) — le sabotage EST l'effet mécanique d'Hostile (GD-13-B).
- **C.** Coupé en V1.0 (code conservé).
- **RECO : B** — donne au sabotage une cause lisible par le joueur (« ils me haïssent ») au lieu d'un piège aléatoire, et le rend contournable par le play réputation.

### GD-30 — Payoff de l'Enfant
L'Enfant (R40/R85) offre des greffes « piège 100 % narratif corr 0 » (invariant R127-D : zéro stat cachée). Où va son twist en V1.0 ?
- **A.** Narratif seul : indices troublants cumulés, révélation au codex.
- **B.** Quête de révélation dédiée débloquée après 3 croisements + poids dans la fin Corruption totale (R89 : l'Enfant naît).
- **C.** Compteur caché : ses greffes acceptées teintent la fin (contredit l'invariant R127-D).
- **RECO : B** — le twist majeur du canon mérite une scène jouable, et C est explicitement interdit par l'invariant « zéro stat cachée » validé par panel.

### GD-31 — Limites des pactes
Pactes = +1 Corruption one-shot (greffes Être/Compagnon §E, interventions R131). Faut-il un garde-fou V1.0 ?
- **A.** Aucun (le prix affiché + le choix 1-sur-3 du draft régulent) ; surveiller au soak.
- **B.** Prix progressif : +1 puis +2 au 3e pacte de la run.
- **C.** Refus automatique au-delà de Corruption 15 (les tentateurs n'ont plus rien à prendre).
- **RECO : A** — le budget corruption/run 5,4 ±1,5 est déjà une assertion codée ; ajouter une règle avant la mesure violerait la méthode (R130 : re-mesurer avant de toucher).

### GD-32 — Branchement de la contre-pression §E
La spec prévoit requis 3 sur tout beat de quête 3 dès total_greffes ≥ 3 — non branché (R137 « reste V4 »), alors que le climax plein n'est qu'à 1,1 %.
- **A.** Brancher tel quel en V4.
- **B.** Brancher APRÈS la whitelist §F et la recomposition des requis (BAL-13/14), re-mesurer entre les deux.
- **C.** Abandonner (le requis 3 du climax seul suffit).
- **RECO : B** — activer une contre-pression alors que la couverture pleine du climax est déjà 40× sous la cible aggraverait le problème mesuré ; l'ordre des opérations est le vrai choix.

### GD-33 — Durée cible d'un beat
L'overhead fixe post-W1 est ~2,1-2,4 s + prose (cache-hit immédiat / miss cap 12 s) + lecture + décision. Quelle boucle idéale ?
- **A.** 45-60 s (rythme Reigns rapide).
- **B.** 60-90 s (lecture confortable, la prose est reine — R70/§22).
- **C.** 90-120 s (contemplatif).
- **RECO : B** — cohérent avec le feel Citizen Sleeper (R1) et la longueur de run GD-20-B (12 beats × ~75 s ≈ 15 min de jeu + transitions ≈ 20-25 min).

### GD-34 — Accélération pour vétérans
Au 10e run, préambule + interstitiels + fusion pèsent. Quelle offre V1.0 ?
- **A.** Rien de plus (skip au clic R63/R110 suffit).
- **B.** Options existantes étendues : « afficher direct » coupe aussi préambule/interstitiel.
- **C.** Mode vétéran persisté : préambule condensé (1 §), fusion ÷2, typewriter direct — proposé automatiquement après 5 runs.
- **RECO : C** — la méta V1.0 demande 10-14 runs (GD-02) ; sans compression, la répétition des rituels d'entrée devient le premier motif d'abandon.

### GD-35 — Volume d'onboarding
R136 a réduit le tuto à 2 hints passifs one-shot. La V1.0 ajoute réputation, fragments, souvenirs. Combien de hints max ?
- **A.** Garder 2 (le jeu doit être évident, §23).
- **B.** 5 hints one-shot persistés, cap 1/beat, diégétiques via Merlin (R31/R77) : verbe+trait, dé/liseré, push, greffe, seuil.
- **C.** Tuto scripté complet 1re run (R77 étendu).
- **RECO : B** — chaque système nouveau a droit à UN hint à sa première occurrence (JIT canon R77), sans réintroduire un tutoriel bloquant contraire aux 4 piliers.

### GD-36 — Traits-souvenir (re-spec R49/R90/R92)
La re-spec « cartes-souvenir → traits/greffes-souvenir » est due en W4/V4. Quelle forme V1.0 ?
- **A.** Trait-souvenir : 1 proposé au seuil après une run marquante (éclatante au climax, pacte lourd, survie) ; accepté = remplace 1 des 16 traits des runs futures (swap 1-pour-1, cf. BAL-16).
- **B.** Greffe-souvenir : entre au pool de draft futur (fusionne avec GD-10-C).
- **C.** Les deux.
- **RECO : A** — le trait est le réceptacle naturel de la mémoire (la main repiochée fait « revenir » le souvenir) et le swap préserve le chiffrage du pool ; B existe déjà via GD-10-C.

### GD-37 — Promesses R91 en V1.0
La mécanique Promesse (dette PNJ suivie par le jeu) est canon mais absente. Périmètre V1.0 ?
- **A.** Couper (les pactes R131 suffisent).
- **B.** Version légère : 1 promesse trackée max par run (contractée aux interventions), tenue = réputation +1 / trahie = +1 Corruption et pilier mémorisé (GD-15-B).
- **C.** R91 complet avec persistance cross-run des lourdes.
- **RECO : B** — c'est le liant manquant entre interventions, réputation et mémoire PNJ, pour le coût d'un flag dans la run ; C attend la V1.1.

### GD-38 — Cadence des interventions de pilier
R136 a réduit à 1/run (contre cap 2 en R131). Faut-il moduler en V1.0 ?
- **A.** 1/run fixe (statu quo).
- **B.** 1/run + 1 bonus si Favorable avec la faction du pilier (l'amitié se sent).
- **C.** Retour à 2/run pour tous.
- **RECO : B** — donne à la réputation un effet désirable immédiat (GD-13) et réintroduit la 2e intervention seulement là où le joueur l'a méritée.

### GD-39 — Flux de fin de run
Aujourd'hui : fin → MerlinEnd → menu. Avec le seuil onirique (GD-09), quel flux ?
- **A.** Statu quo, seuil accessible depuis le menu.
- **B.** Fin → seuil onirique (fragment + bilan + souvenir) → menu.
- **C.** B + seuil consultable à tout moment depuis le menu (relire jalons/codex).
- **RECO : C** — le passage systématique par le seuil installe le rituel méta (R43 « Merlin fait le bilan »), et l'accès libre évite de devoir mourir pour relire son codex.

### GD-40 — Écran de fin enrichi
MerlinEnd affiche épilogue + jauges. Pour la V1.0 :
- **A.** Statu quo (le seuil GD-39 porte la méta).
- **B.** + fragment révélé en scène (moment signature de la run).
- **C.** B + récap du build : greffes posées, faits marquants, palmarès chronique.
- **RECO : C** — l'écran de fin est l'endroit où le joueur décide de relancer ; montrer le build et le pas méta franchi est le meilleur argument de re-run.

## PARTIE 2 — BALANCE / DONNÉES (25 questions)

### BAL-01 — Cibles de distribution finales
Les cibles §K (échec 3-8 / partiel 28-38 / réussite 45-55 / éclatante 8-15) n'ont jamais été atteintes (mesuré : 25,3 / 28,5 / 43,4 / 2,8). Les garder pour la V1.0 ?
- **A.** Garder §K tel quel (les leviers whitelist/composition n'ont pas encore été essayés).
- **B.** Relever l'échec cible à 8-12 (jeu de tension assumé), le reste inchangé.
- **C.** Réduire l'éclatante à 5-10 (moins de pression sur la porte).
- **RECO : A** — les cibles sortent d'un chiffrage de panel cohérent ; les invalider avant d'avoir branché la whitelist §F (le levier prévu) serait un abandon prématuré.

### BAL-02 — Levier de l'éclatante
La porte actuelle (couverture pleine ET coût 0 ET trait couvre ≥1 requis ET (synergie +1 OU dé +1)) donne 2,8 % pour 8-15 visés. Quel assouplissement ?
- **A.** Retirer « coût 0 » (les traits corrompus/pactes n'excluent plus l'éclatante).
- **B.** Retirer « le trait couvre ≥1 requis » — redondant dès que les requis sont hors-base (§F).
- **C.** Ne rien retirer : compter sur whitelist + composition (BAL-13/14) et re-mesurer.
- **RECO : B** — c'est la clause la moins lisible pour le joueur et la plus corrélée au déficit de couverture ; A affaiblit le sens « pureté » de l'éclatante (R65 : coût 0 = triomphe propre).

### BAL-03 — Levier principal de l'échec
Échec mesuré 25,3 % pour 3-8 visés, climax plein 1,1 % : des requis sortent du pool atteignable. Quel levier prioritaire ?
- **A.** Brancher la whitelist §F au jeu réel (0 requis hors-pool, assertion codée).
- **B.** Passer les actions à 3 tags de base.
- **C.** Relâcher encore la table de dé d'un cran.
- **RECO : A** — B casse le chiffrage fondateur §B (couverture pleine ~67 % dérivée des 2 tags) et C a déjà été consommé en V3 pour un gain marginal ; A est la cause racine identifiée par R137.

### BAL-04 — Cibles de morts par archétype
Morts mixtes 36,6-38 % (cible 10-25) mais optimal 0 % : la moyenne masque tout. Re-poser des gates par archétype ?
- **A.** Garder la cible mixte 10-25 seule.
- **B.** Gates par archétype : optimal ≤10 · greedy/chaotic ≤30 · corrompu ≤25 · tag-ignorant non gaté (bot adversarial).
- **C.** B + plancher optimal ≥2 % (un jeu où le joueur parfait ne meurt jamais).
- **RECO : B** — l'écart 0 %↔37 % prouve que le jeu punit la non-maîtrise, pas le risque ; le plancher C contredit le canon R120 (« un joueur discipliné n'est jamais puni »).

### BAL-05 — Barème INTEGRITE_DELTA
Actuel : échec −3, partiel −2, réussite 0, éclatante 0 (sur 10 PV). Le revoir pour la V1.0 ?
- **A.** Ne pas toucher : la mortalité vient du TAUX d'échec (25 % = 5× la cible), pas du barème.
- **B.** Adoucir : échec −2 partout.
- **C.** Barème par difficulté : −2 en diff 1-2, −3 en diff 3.
- **RECO : A** — adoucir le barème avant de corriger le taux d'échec (BAL-03) fausserait le recalibrage et affaiblirait la valeur du push R130 (qui épargne le −2).

### BAL-06 — Répit de quête
Actuel : +2 Intégrité, +2 bonus si ≤4, recharge du push (mesures v10.14 : +1→40 % morts, +2→31 %). Ajuster ?
- **A.** Garder +2/+4 jusqu'au re-soak post-whitelist.
- **B.** Passer à +3 base (amortit les 37 % de morts).
- **C.** +2/+4 + PURGE gratuite d'1 trait corrompu si Corruption ≥10.
- **RECO : A** — le répit a déjà été tuné sur mesures ; le sur-buffer maintenant compenserait artificiellement le bug de couverture, et C empiète sur le rôle canon du Chœur (R49/R82).

### BAL-07 — Économie du push (R130)
PUSH_PRICE 1, budget 1/quête rechargé au répit, ~1,3 push/run mesuré (cible 0,5-1,5). Modifier ?
- **A.** Statu quo (dans la cible).
- **B.** PRICE 2 (choix plus grave, corruption/run +~1).
- **C.** Budget 2/quête (plus de contrôle du partiel).
- **RECO : A** — c'est le système le plus proche de sa cible de tout le jeu ; le guardrail R130 impose de re-mesurer AVANT tout changement.

### BAL-08 — Cible corruption/run
Assertion actuelle ≈5,4 ±1,5 (mesuré 5,94). Avec drafts visés 5-6/run (pactes +1 one-shot possibles), la garder ?
- **A.** Garder 5,4 ±1,5 et re-dériver seulement une fois la cadence de drafts atteinte.
- **B.** Relever à 6,5 ±1,5 en anticipation.
- **C.** Passer en cible par beat (≈0,45/beat) pour neutraliser la variance de longueur de run.
- **RECO : A** — anticiper une dérive non mesurée viole la méthode « constantes gatées + re-dérivation sur mesure » (guardrails spec v11).

### BAL-09 — Pas des seuils de Corruption
Seuils /5 (5/10/15) → 3 injections avant le cap. Changer le pas ?
- **A.** Garder /5.
- **B.** /6 (2 injections seulement, moins de pollution).
- **C.** Non-linéaire 5/9/13 (accélération de la spirale).
- **RECO : A** — les 4 paliers de glitch visuel (R75), la pré-alerte de jauge et les nappes audio sont tous indexés sur /5 ; changer le pas coûte une passe complète UI/audio pour un gain non démontré.

### BAL-10 — Cap de Corruption
CORRUPTION_CAP 18 (R64 disait « plafond ~15-20 »), fins corrompues 14,5 % mesurées. Ajuster ?
- **A.** Garder 18.
- **B.** 20 (plus de marge aux pactes de la V1.0).
- **C.** 15 (pression maximale).
- **RECO : A** — 18 = 3 seuils + marge de 3, fins corrompues dans la cible ≤18 % ; constante TweaksOverlay, ajustable en une ligne si les pactes V1.0 font dériver la mesure.

### BAL-11 — Fréquence des drafts
2,69 drafts/run mesurés pour 5-6 visés (E[greffes] spec §E). Quels déclencheurs ajouter ?
- **A.** Draft garanti à chaque transition de quête (+2 environ, lié GD-27).
- **B.** A + draft d'ouverture au 1er beat de la run (le build démarre tout de suite).
- **C.** Cadence fixe : draft tous les 3 beats.
- **RECO : B** — porte E[drafts] ≈ 1 + 2 + rencontres ≈ 5-6 par construction structurelle (prévisible pour le joueur), là où C désynchronise récompense et récit.

### BAL-12 — Table de dé finale
DIE_BANDS spec 17/33/50/67 % a été relâchée d'un cran en V3 (33/50/67/83) pour compenser le déficit de couverture. Position V1.0 ?
- **A.** Garder 33/50/67/83.
- **B.** Revenir vers 17/33/50/67 une fois whitelist + composition branchées (le dé redevient un événement, pas une béquille).
- **C.** Intermédiaire 25/42/58/75.
- **RECO : B** — la table a été relâchée pour la mauvaise raison (dé ≠ correctif de génération) ; re-dériver au soak post-BAL-13/14 avec C comme position de repli si les morts remontent.

### BAL-13 — Composition des requis au climax
Diff 3 = 3 requis HORS tags de base (§F) : quasi incouvrable (climax plein 1,1 % pour 45-55 visés). Recomposer ?
- **A.** « 2+1 » : 2 requis hors-base + 1 tag de base d'action (couverture pleine = verbe pertinent + trait + greffe).
- **B.** 3 hors-base mais whitelist main-aware : ≥1 requis garanti couvrable par la main/greffes courantes.
- **C.** Garder 3 hors-base secs.
- **RECO : A** — atteignable PAR CONSTRUCTION sans regarder la main (B rend la génération dépendante d'un état volatil et fragilise le lookahead), et vise mécaniquement la bande 45-55.

### BAL-14 — ⚠ Whitelist §F obligatoire en V1 ?
La whitelist (requis ⊆ base ∪ traits ∪ greffes, fallback même index, assertion 0 hors-pool) est spécifiée mais non branchée au jeu réel (R137).
- **A.** Obligatoire V1.0, gate V4 avec assertion dure.
- **B.** Partielle : climax et quête 3 seulement.
- **C.** Post-V1.0.
- **RECO : A** — c'est le prérequis de TOUTES les autres cibles (BAL-01/03/12/13) ; sans elle, chaque mesure soak reste polluée par des beats structurellement injouables.

> **RÉPONSE : A** *(tranché en session interactive, 2026-07-04)*

### BAL-15 — Seuil de deadhand acceptable
La spec §C prévoit un A/B « réserve de trait » si le deadhand (main sans trait couvrant) dépasse 45 % (mesuré 34,9 %). Quel seuil V1.0 ?
- **A.** ≤35 % (strict).
- **B.** ≤45 % (spec), mesuré en assertion loguée.
- **C.** Pas de métrique (le redraw complet chaque beat suffit à tourner).
- **RECO : B** — le seuil du panel est déjà arbitré ; le loguer (pas le gater) donne la donnée pour décider de la réserve de trait sans bloquer les vagues.

### BAL-16 — Taille du deck de traits
16 traits + corrompus injectés (16→19). Avec les souvenirs (GD-36), quelle politique ?
- **A.** Figer 16 sains : tout trait-souvenir REMPLACE un trait de base (swap 1-pour-1).
- **B.** Croissance bornée 16→20 avec re-dérivation des cibles à chaque ajout.
- **C.** Croissance libre.
- **RECO : A** — le guardrail spec est explicite (« 2 traits ajoutés sans recalcul suffisent à sortir le partiel de la cible ») ; le swap rend le souvenir GRATUIT en équilibrage et douloureux en choix, ce qui est exactement son rôle.

### BAL-17 — Injection des traits corrompus
1 trait corrompu (corr 1 récurrent) injecté au pool par seuil franchi (5/10/15). Ajuster ?
- **A.** Garder 1/seuil (max 3, ~16 % du pool au pire).
- **B.** Progression 1/2/2 (spirale plus dure).
- **C.** 1/seuil, mais le 3e remplace un trait sain (pool constant, pollution pure).
- **RECO : A** — avec main 4 et cycle ~4-5 beats, 3 corrompus se sentent déjà à chaque cycle ; durcir avant d'avoir fixé les morts à 37 % serait contre-productif.

### BAL-18 — Cap corrompu par main
R113 re-spécifié : cap 1 trait corrompu/main, re-tirage silencieux de l'excédent. Garder ?
- **A.** Garder cap 1 silencieux.
- **B.** Cap 1 mais VISIBLE (le re-tirage se voit : la pollution se sent sans punir).
- **C.** Cap 2 au palier dissolution (15+) — la fin de spirale doit s'éprouver.
- **RECO : A** — la jouabilité garantie (R113) prime ; C est un bon candidat pour un futur mode difficile (GD-26), pas pour la difficulté canon.

### BAL-19 — Méthode de recalibrage V1.0
La spec impose 2 passes soak 5×300 + constantes gatées TweaksOverlay. Pour la V1.0 (réputation, souvenirs, biome 2 en plus) :
- **A.** Statu quo : soak 200/200 au gate + 5×300 de recalibrage par vague.
- **B.** A + soak 5×300 automatisé périodique (nightly) avec rapport de dérive des assertions §K.
- **C.** Tuning continu TweaksOverlay sans re-gate.
- **RECO : B** — chaque système V1.0 déplace silencieusement la distribution (leçon R130) ; la dérive détectée entre vagues coûte 10× moins qu'au gate final. C est interdit par les guardrails.

### BAL-20 — Dureté des assertions de gate
Quelles assertions §K sont DURES (gate rouge) vs LOGUÉES en V1.0 ?
- **A.** Toutes dures.
- **B.** Noyau dur : distribution 4 bandes + morts par archétype + 0 requis hors-pool + corruption/run ; loguées : pushes/run, sabotage, deadhand, fréquence drafts, fins corrompues borne basse.
- **C.** Tout logué (revue humaine à chaque gate).
- **RECO : B** — les métriques de flux dépendent des archétypes de bot plus que du jeu ; les gater en dur produit des faux rouges qui érodent la confiance dans le harnais (anti-pattern R109).

### BAL-21 — Valeurs des charges
HEAL 1-2 ×2 · PURGE 1 ×2 · DRAW 1 ×2 (spec §E). Ajuster pour la V1.0 ?
- **A.** Garder telles quelles et mesurer le pick-rate par type au soak une fois les drafts à 5-6/run.
- **B.** Uniformiser HEAL 2 (lisibilité).
- **C.** Passer toutes les charges à ×3 (compenser le one-shot vs greffes permanentes).
- **RECO : A** — à 2,69 drafts/run, aucune donnée de préférence n'est significative ; équilibrer les types de greffe avant d'avoir la cadence cible, c'est équilibrer dans le vide.

### BAL-22 — Prix des greffes pactées
Être/Compagnon = +1 Corruption one-shot à la pose (§E), alors que leurs tags (Mystère/Vision/Sacrifice) débloquent des requis exclusifs. Différencier ?
- **A.** Garder +1 uniforme.
- **B.** +2 pour l'Être (ses tags ouvrent des requis greffe-only, valeur supérieure).
- **C.** +1 mais max 1 greffe pactée par action.
- **RECO : A** — le +1 uniforme est la règle la plus lisible (« pacte = 1 ombre ») et le cumul reste borné par le budget 5,4/run ; différencier attend une mesure de pick-rate (BAL-21).

### BAL-23 — Cible des fins corrompues
Mesuré 14,5 % pour ≤18 %. La borne unique suffit-elle ?
- **A.** Garder ≤18 % seul.
- **B.** Resserrer ≤15 %.
- **C.** Fourchette 10-18 % : une borne BASSE aussi (trop peu = la Corruption ne menace plus personne).
- **RECO : C** — la Corruption est l'antagoniste central (R10) ; si les pactes V1.0 deviennent trop évitables, la fin corrompue disparaît et le thème avec — la borne basse loguée le détecterait.

### BAL-24 — Fréquence cible du sabotage
Si le sabotage est réactivé via l'état Hostile (GD-29-B), quelle fréquence de beats sabotables viser ?
- **A.** ≤5 % des beats d'une run (événement rare et signé).
- **B.** 10-15 % (pression régulière).
- **C.** 0 (si GD-29-C retenu).
- **RECO : A** — le sabotage dégrade le degré, donc alimente échec et morts déjà hors cible ; il doit rester un événement lisible et attribuable, mesuré en assertion loguée.

### BAL-25 — Récompense chiffrée de l'éclatante
INTEGRITE_DELTA donne éclatante = 0 alors que R65 canon dit « +0/+1 » ; pour viser 8-15 %, l'éclatante doit être désirée. Quelle récompense ?
- **A.** +1 Intégrité fixe.
- **B.** Déclencheur privilégié de trait-souvenir (GD-36) + secret de codex (GD-12-C), zéro jauge.
- **C.** A + B.
- **RECO : C** — le +1 (borné par le clamp 0-10) rend l'éclatante lisible dans les anneaux, le souvenir/codex la rend mémorable ; à ≤15 % de fréquence, l'impact sur les morts est marginal et compensé au recalibrage BAL-19.

<!-- ============ PARTIE NARRATIF + DA + AUDIO (70) ============ -->

**Sommaire par thème**
- **NAR — Ton & voix narrative** (NAR-01, 02, 12-15) : curseur merveilleux-inquiétant, longueur de prose, personne/temps, langue.
- **NAR — Graal & fins** (NAR-03 à 06) : manifestation du Graal en V1, fusion, fins main vs LLM, épilogues.
- **NAR — Piliers, Arthur & figures** (NAR-07 à 11) : arcs cross-run, Compagnon, Enfant, Arthur, roster.
- **NAR — Mémoire, souvenirs & codex** (NAR-16 à 20) : Chronicle, greffes-souvenir, codex.
- **NAR — Prompts, anti-répétition & garde-fous** (NAR-21 à 25) : banques, few-shots, LoRA, termes interdits.
- **NAR — Moteur narratif & robustesse** (NAR-26 à 30) : contrôle LLM, console, fallback, lookahead, interventions.
- **DA — Artworks génératifs** (DA-01 à 05) : GO/NO-GO, style, validation, placement, portraits.
- **DA — Identité, palette & typo** (DA-06 à 09) : évolutions palette, fonts, glyphes, bordures.
- **DA — Biomes, saisons & glitch** (DA-10 à 13) : Falaises, 3e biome, saisons, paliers.
- **DA — Écrans & layout** (DA-14 à 16, 20) : End, menu, résolutions, tuiles-greffes.
- **DA — Accessibilité visuelle** (DA-17 à 19) : reduce-motion étendu, contraste, taille de texte.
- **AUD — Musique gameplay & pipeline** (AUD-01 à 04) : réactivité, stems, MusicGen, transitions.
- **AUD — SFX & moments muets** (AUD-05, 06, 14-16) : greffe/draft/push, stingers de fin, dé, fusion, interventions.
- **AUD — Voix de Merlin** (AUD-07 à 09) : procédurale vs TTS, blips, humeurs.
- **AUD — Mixage, bus, nappes & options** (AUD-10 à 13, 17-20) : ducking, loudness, bus Voice, pads piliers, sliders, mute, QA.

## PARTIE 3 — NARRATIF / LLM (30 questions)

### NAR-01 — Curseur de ton V1
Le ton canon est « merveilleux-inquiétant » (R8/§13) et la forêt-miroir réagit déjà à la Corruption (R88, décor R129). Où placer le curseur par défaut d'une run à Corruption 0 ?
- **A.** Équilibre fixe 50/50 sur toute la run, indépendant de l'état.
- **B.** Merveilleux dominant en début de run, l'inquiétant croît avec la Corruption et les paliers R75 (le prompt reçoit le palier).
- **C.** Inquiétant dominant dès l'orée (horreur féerique assumée).
- **RECO : B** — la forêt-miroir R88 fait déjà du curseur une mécanique diégétique ; l'injecter au prompt coûte une ligne d'ÉTAT et rend chaque palier lisible dans la prose.

### NAR-02 — Sous-ton par biome
Deux biomes existent (R132) avec préambules par banque. Chaque biome doit-il déclarer un sous-ton narratif au LLM ?
- **A.** Non — même ton partout, seul le lexique de lieux change.
- **B.** Oui — 1 ligne de ton par biome injectée au préfixe variable (Brocéliande = féerie qui mord, Falaises = mélancolie du bout du monde) + banques de préambule alignées.
- **C.** Le LLM improvise le ton du biome librement.
- **RECO : B** — coût quasi nul (tour variable R62), différencie réellement les biomes au-delà du décor, sans risque de dérive (garde-fous R61 intacts).

### NAR-03 — Le Graal en V1 (manifestation)
L'épilogue dévoile un fragment du Graal (R69) mais la méta 20-30 fragments (R80) n'est pas construite ; `MerlinChronicle` (R122) persiste déjà des données cross-run. Comment manifester le Graal en V1 ?
- **A.** Prose seule — l'épilogue évoque un fragment, rien n'est compté.
- **B.** Compteur de fragments persisté dans Chronicle + 1 phrase du préambule R132 qui rappelle l'avancée au retour (« trois éclats déjà… »).
- **C.** Écran-seuil onirique avec jalons visibles (R50).
- **RECO : B** — donne une colonne vertébrale cross-run à la V1 pour un champ additif ; R50 reste post-V1 comme canon. (NB : si GD-01/GD-09 retiennent le seuil, C se fond dans ce chantier.)

### NAR-04 — ⚠ Révélation finale (fusion avec Merlin)
La fin canonique est la fusion avec Merlin (R44/R89), prévue au bout de 20-30 fragments. La V1 doit-elle la contenir ?
- **A.** Non — V1 = 3 fins de run (R69) + teasing (Arthur R87, indices) ; la Fusion est le chantier méta post-V1.
- **B.** Oui, atteignable avec seuil réduit (~10 fragments via NAR-03 B).
- **C.** Cinématique unique débloquée par un haut fait (1re run parfaite).
- **RECO : A** — la Fusion mérite son écran-seuil et ses fins-méta LLM-composées (R89) ; la bâcler en V1 grillerait la révélation la plus précieuse du canon. (⚠ contradictoire avec GD-01-A : c'est l'arbitrage n°1 à rendre.)

> **RÉPONSE : B** *(tranché en session interactive, 2026-07-04)*

### NAR-05 — Fins de run : main vs LLM
L'épilogue est aujourd'hui 100 % généré (R69). Faut-il sécuriser les 3 types de fin ?
- **A.** LLM pur (état actuel) avec fallback procédural R61.
- **B.** Gabarit écrit main par type de fin (accomplissement/mort/corrompu, 2-3 variantes) + le LLM colore par-dessus avec l'état final (pattern R20 « code applique, LLM habille »).
- **C.** Fins 100 % écrites main.
- **RECO : B** — la fin est le texte le plus relu du jeu ; un squelette main garantit la chute (fragment, payoff Enfant R85) même quand E2B faiblit.

### NAR-06 — Longueur d'épilogue
Les budgets R58 fixent situation 250 / résolution 160 tokens mais pas l'épilogue. Quelle cible ?
- **A.** Court : 60-100 mots (1 bloc).
- **B.** 120-180 mots en 2 blocs — bilan de la run puis fragment du Graal (max_tokens ~280).
- **C.** Long : 250+ mots.
- **RECO : B** — assez long pour le moment cérémoniel de MerlinEnd, assez court pour rester sous ~15 s de gen (cible squelette R58) sans lookahead possible.

### NAR-07 — Arcs des piliers cross-run
La reconnaissance existe en binaire (`pnj_recog`, R127 Wave B). Les 5 piliers doivent-ils avoir un arc à étapes sur la V1 ?
- **A.** Statu quo binaire (reconnu / pas reconnu).
- **B.** 3 stades par pilier (étranger / reconnu / lié, compteur de rencontres dans Chronicle) qui sélectionnent des lignes signées et offrandes différentes dans les banques R131.
- **C.** Arc scripté complet en 5 actes par pilier.
- **RECO : B** — réutilise l'infrastructure banques + Chronicle (zéro appel LLM, R110 intact) et donne la sensation de relation promise par R36 sans authoring lourd.

### NAR-08 — Le Compagnon Perdu : rédemption
Le canon lui donne « une étincelle de l'ancien, atteignable » (R84) mais rien n'est construit. En V1 ?
- **A.** Non — tentateur pur, l'étincelle reste une promesse de prose.
- **B.** Micro-arc : après N refus de ses pactes (compteur Chronicle), 1 ligne signée spéciale où la bribe d'humanité perce (banque, pas de mécanique).
- **C.** Quête de rédemption complète avec fin dédiée.
- **RECO : B** — récompense narrativement le joueur qui résiste (écho R84) pour 3-4 lignes de banque ; la quête complète attend le roster post-V1.

### NAR-09 — Révélation de l'Enfant
Le payoff climax/épilogue de l'Enfant est câblé (spec Wave I). Jusqu'où révéler le twist R85 en V1 sans la méta ?
- **A.** Jamais en V1 — indices troublants seulement dans les lignes signées.
- **B.** Au climax/épilogue si la complicité est élevée (aides acceptées ≥ 2 cross-run via Chronicle) : la prose laisse entrevoir ce qu'il est, sans dire « IA ».
- **C.** Entrée de codex qui vend la mèche après la 1re aide.
- **RECO : B** — le mécanisme R85 exact (« le degré de complicité colore la fin ») est déjà spécifié ; C spoilerait frontalement, contre R85 « jamais frontale tôt ».

### NAR-10 — Arthur en V1
Arthur est périphérique (R36/R87 : croisé « par éclairs ») et absent du build actuel. Comment l'introduire ?
- **A.** Absent de la V1.
- **B.** Apparitions procédurales rares : 1 banque de 4-6 fragments signés (voix fébrile R35) injectés comme micro-événement de transition, pattern R131 (zéro appel LLM), ~15 % des runs.
- **C.** Beat Rencontre dédié généré par le LLM avec sa fiche canon.
- **RECO : B** — l'avertissement vivant R87 est un des meilleurs hooks du lore, et le pattern « banque + slot transition » est déjà éprouvé par les interventions.

### NAR-11 — Figures arthuriennes de passage
Le roster cible 20+ personnages (R17, post-MVP). Pour la V1 :
- **A.** Aucun nouveau nom — les 5 piliers + Merlin (+ Arthur si NAR-10) suffisent.
- **B.** 2-3 figures nommées (Viviane, le Passeur…) seulement en couleur : citées dans les banques de préambule/few-shots, jamais incarnées.
- **C.** 6-8 fiches canon complètes injectables.
- **RECO : B** — densifie le monde à coût nul (le LLM réutilise les noms du préfixe) sans le risque d'incarnation non-fichée interdit par R17.

### NAR-12 — Longueur de prose par situation
Le canon demande 2-4 phrases FR (~40-70 mots, R101) avec max_tokens 250 (R58). Ajuster ?
- **A.** Garder 2-4 phrases uniformes.
- **B.** Allonger partout (4-6 phrases) pour plus d'immersion.
- **C.** Différencier par type de beat : Exploration/Rencontre 2-3 phrases, Dilemme/Climax 4-5 (max_tokens par type).
- **RECO : C** — la courbe de tension R68 mérite une courbe de densité ; l'encart Z3 en scroll_following (R136) absorbe la variance sans casser la grille.

### NAR-13 — Longueur de l'issue (même-fil R128)
L'issue s'écrit à la suite de la situation dans le même fil (R128, 160 tokens R58). Quelle cible ?
- **A.** 2-4 phrases uniformes (état actuel).
- **B.** Cap dur 2 phrases pour le rythme lecture « Reigns » (R136).
- **C.** Par degré : échec/éclatante 3-4 phrases (moments mémorables), partiel/réussite 2 (le partiel enchaîne sur le choix Encaisser/Pousser R130).
- **RECO : C** — met les tokens là où l'émotion est, et raccourcit justement le partiel dont la vignette + les 2 boutons ajoutent déjà de la lecture.

### NAR-14 — Voix narrative (personne, temps)
Tout le canon écrit en 2e personne singulier au présent (« Tes yeux fendent l'ombre » R102). Verrouiller ?
- **A.** Tu + présent, verrouillé dans le préfixe système + toutes les banques (audit des banques existantes pour conformité).
- **B.** Vouvoiement « Voyageur » solennel.
- **C.** Mixte : tu pour la prose, vous pour les lignes signées des piliers.
- **RECO : A** — c'est l'existant de fait ; l'écrire au préfixe et auditer les banques évite la dérive de personne, l'incohérence la plus visible d'un petit modèle.

### NAR-15 — Français seul ou préparation l10n
R74 verrouille FR seul au MVP. Pour la V1 :
- **A.** FR seul assumé, textes UI en dur.
- **B.** FR seul en jeu, mais chaînes UI (boutons, options, libellés) extraites dans un fichier de traductions Godot dès maintenant ; prose LLM/banques restent FR.
- **C.** EN complet (UI + prompt de sortie EN).
- **RECO : B** — extraire l'UI coûte peu aujourd'hui et beaucoup plus tard ; la prose LLM restera FR tant que les few-shots gold R62 sont FR.

### NAR-16 — Mémoire narrative au retour
Le menu « souvenir » nomme le dernier pilier (R127 Wave B) et le préambule R132 pose le lieu. Que raconter de plus au joueur qui revient ?
- **A.** Statu quo (dernier pilier + dernière issue).
- **B.** 3 souvenirs max injectés au préambule : pilier croisé, type de fin, 1 choix marquant (`choix_cles` persisté en Chronicle) — budget ~40 tokens.
- **C.** Résumé complet de la dernière run réinjecté.
- **RECO : B** — respecte le budget mémoire R60 (« les conséquences avant le décor ») tout en donnant la continuité cross-run promise par R43.

### NAR-17 — Qui écrit les greffes (noms/évocations)
R137 a converti 21 greffes, noms conservés à l'octet ; la re-spec R49/R90 en greffes-souvenir reste ouverte. Qui écrit les nouvelles ?
- **A.** Banques écrites main, étendues à ~40 greffes (10/type, ton R102).
- **B.** LLM forge à chaud au moment du draft (esprit R90 original).
- **C.** Hybride : banques main + un pool de variantes LLM pré-générées hors-ligne et validées (cache, pas de live).
- **RECO : A** — le draft est dans le flux de jeu (single-flight R110, zéro appel ajouté est un guardrail explicite) ; C est l'évolution naturelle post-V1.

### NAR-18 — Greffes-souvenir liées au vécu
R90 veut que le souvenir « cristallise l'acte ». Sans LLM live (NAR-17), comment lier la greffe au vécu en V1 ?
- **A.** Pas de lien — greffes tirées par pilier/faction seulement (état R137).
- **B.** Sélection procédurale contextuelle : pool de draft filtré par faction de la quête, degré du beat précédent et saison, et le nom affiché reçoit un sous-titre du lieu (« — forgée aux Falaises »).
- **C.** Génération LLM du nom au moment marquant.
- **RECO : B** — 80 % de la sensation « le deck raconte ton histoire » (R90) pour un filtre de pool et un suffixe, sans toucher au moteur.

### NAR-19 — Codex : qui rédige
Le codex est promis par R43/R50 mais n'existe pas. Qui écrit les entrées ?
- **A.** 100 % canon écrit main (factions, piliers, lieux R88), débloqué à la rencontre.
- **B.** LLM rédige chaque entrée à la découverte.
- **C.** Canon main + 1 ligne de chronique par run appendue automatiquement (« Run 7 — le Chœur t'a reconnu »), source Chronicle.
- **RECO : C** — le canon reste sûr (pas de dérive lore R61) et le codex vit quand même ; le LLM n'écrit rien de persistant qu'on ne puisse auditer.

### NAR-20 — Codex : taille et types d'entrées
Pour cadrer l'authoring du codex V1 :
- **A.** ~20 entrées courtes (80-120 mots) : 4 factions, 5 piliers, 5 lieux archétypaux R88, ~6 lore (Graal, Corruption, Merlin, biomes).
- **B.** ~40 entrées détaillées avec paliers de révélation progressifs.
- **C.** 10 entrées majeures seulement.
- **RECO : A** — couvre tout le canon visible sans spoiler (l'Enfant garde une entrée « masquée » qui évolue, écho R85) ; B est l'extension NG+ naturelle. (NB : à réconcilier avec GD-11 — A ici = plancher, B de GD-11 = plafond.)

### NAR-21 — Anti-répétition des images LLM
`_fb_served` couvre les banques procédurales (R128) mais pas la prose LLM, où E2B ressert fontaines et brumes. Ajouter un contrôle ?
- **A.** Non — repeat_penalty 1.1 (R59) suffit.
- **B.** Liste des 3-5 motifs déjà servis dans la run injectée au tour variable (« AVOID reusing: fontaine, brume… »), maintenue par le code depuis les narrations passées.
- **C.** Post-filtre qui régénère si un motif sur-servi apparaît.
- **RECO : B** — repeat_penalty n'agit qu'intra-génération ; une ligne de prompt négatif règle l'inter-beats sans le coût en retry de C.

### NAR-22 — Taille des banques procédurales
État réel : 3-4 lignes signées/pilier, ~6 codas de push, 3 variantes/paragraphe de préambule. Suffisant ?
- **A.** Oui pour la V1.
- **B.** Doubler les points chauds : 6-8 lignes signées/pilier et 6 variantes/paragraphe de préambule (vus à chaque run), codas inchangées.
- **C.** Tripler tout.
- **RECO : B** — le préambule est lu à 100 % des runs et les lignes signées ~1/run : ce sont elles qui grillent en premier l'anti-répétition `_fb_served`.

### NAR-23 — Few-shots par type de beat
R62 fixe 1-2 exemples gold statiques par tâche. Enrichir ?
- **A.** Garder 1-2 par tâche.
- **B.** 1 few-shot gold PAR TYPE de beat (5) pour la tâche Situation, sélectionné dynamiquement dans le tour variable (le préfixe KV-caché ne bouge pas).
- **C.** 3+ few-shots empilés par tâche.
- **RECO : B** — cible la faiblesse réelle (les Dilemmes sonnent comme des Épreuves) sans gonfler le contexte fixe ni casser le cache R62.

### NAR-24 — Dataset LoRA de style dès V1
La LoRA de style Brocéliande est actée post-MVP (R45). Préparer le terrain ?
- **A.** Oui — logger dès maintenant les sorties « propres » (0 violation filtre R61) avec leur prompt dans un JSONL dédié via la télémétrie R98 (dataset gratuit).
- **B.** Non — attendre le chantier LoRA.
- **RECO : A** — coût quasi nul (le dashboard R96 voit déjà tout passer) et des milliers d'exemples gold seront là le jour du fine-tune.

### NAR-25 — Garde-fous : liste de termes interdits
Le filtre anti-dérive R61 bloque IA/simulation/4e mur/anglicismes. Étendre ?
- **A.** Liste actuelle.
- **B.** Étendre : méta doux (« programme », « joueur », « partie », « niveau », « quête secondaire ») + tics de LLM (« en tant que », « n'hésite pas ») + anachronismes courants, tout loggé au dashboard R96.
- **C.** Assouplir près du Graal (le glitch croissant R97 pourrait laisser filtrer des termes méta).
- **RECO : B** — les tics de modèle sont la fuite la plus fréquente d'E2B ; C est une idée NG+ (R89 « indices méta assumés »), pas V1.

### NAR-26 — Degré de contrôle du LLM sur la mécanique
L'état réel est plus strict que le canon initial : degré 100 % code, tags pré-pickés, prose écrite AUTOUR (invariant R120 preview = résolution). Trancher pour la V1 :
- **A.** Verrouiller : le LLM ne décide JAMAIS rien de mécanique (amender R20 dans la bible pour refléter l'état réel).
- **B.** Réintroduire un bonus de « pertinence narrative » jugé par le LLM, borné à ±0 mécanique (narration seulement).
- **C.** Jugement hybride complet à la résolution.
- **RECO : A** — le soak déterministe (R109), le dé pré-tiré (R120) et la leçon des tags mutés interdisent le jugement à chaud ; la bible doit dire ce que le code fait.

### NAR-27 — GemmaConsole en V1
Le dashboard debug Gemma (R96) existe (scène console). Dans le build V1 ?
- **A.** Retiré de l'export.
- **B.** Gardé derrière un flag (arg `--console` ou touche debug), invisible au joueur.
- **C.** Accessible depuis Options.
- **RECO : B** — c'est l'outil n°1 de diagnostic terrain (violations R61, TTFT R58) ; l'exposer au joueur briserait le 4e mur plus sûrement que n'importe quelle prose. (NB : à réconcilier avec TEC-15 — même décision.)

### NAR-28 — Visibilité de l'échec de génération
La cascade R61 finit sur une phrase procédurale minimale. Le joueur doit-il le savoir ?
- **A.** Invisible — le fallback est indistinguable (banques au ton canon), l'événement part en télémétrie R98 seulement.
- **B.** Micro-indice diégétique (« Merlin marque une pause… ») avant la phrase procédurale.
- **C.** Toast discret « génération simplifiée ».
- **RECO : A** — « jamais de blocage, jamais visible » est l'esprit de R32/R61 ; B attirerait l'attention sur la machinerie, exactement ce que le 4e mur interdit.

### NAR-29 — Profondeur du lookahead
Le lookahead génère N+1 (R6). Avec le typewriter + la lecture qui laissent le CPU idle :
- **A.** N+1 suffit (cibles R58 tenues, mesuré).
- **B.** N+2 opportuniste : si le moteur est idle ET N+1 en cache, générer N+2 en priorité basse (file R110), annulé au swap de ramification R120.
- **C.** Toute la quête générée à `begin_quest`.
- **RECO : B** — supprime les derniers cache-miss (sustain 12 s R128) sans violer le single-flight ; C gaspille des générations à chaque ramification. (NB : TEC-19 recommande A « mesurer d'abord » — arbitrage : mesurer le taux de miss PUIS brancher B si >10 %.)

### NAR-30 — Extension des interventions
R131 en prévoyait 2/run, R136 a cappé à 1/run pour la simplicité. Pour la V1 :
- **A.** Garder 1/run.
- **B.** Remonter à 2/run une fois l'écran stable validé au soak.
- **C.** Fréquence pilotée par le stade de relation (si NAR-07 B).
- **RECO : A** — le pivot v11 (R135/R136) vient de réduire la charge cognitive ; on ne la regonfle qu'après mesure, avec C comme évolution naturelle liée aux arcs. (NB : GD-38-B propose le +1 Favorable — compatible avec C à terme.)

## PARTIE 4 — DA / VISUEL (20 questions)

### DA-01 — ⚠ Artworks par situation : GO/NO-GO V1
Le skill `merlin-artwork` est prêt (cascade `concept_art_generator.mjs`, duotone CREAM/INK, cache sha1 + manifest) mais jamais câblé. Pour la V1 :
- **A.** GO complet : 1 image d'ambiance par situation, async fade-in (R29/R48).
- **B.** NO-GO : aucun artwork de situation en V1.
- **C.** GO partiel : 1 image par QUÊTE (2-3/run), sujet = le lieu du préambule, affichée à l'ouverture de quête puis persistante.
- **RECO : C** — divise le volume par ~4 (cache bien plus réutilisable entre runs), garantit « zéro hitch » plus facilement, et l'image d'un LIEU vieillit mieux que celle d'une situation unique.

> **RÉPONSE : C** *(tranché en session interactive, 2026-07-04)*

### DA-02 — Artworks : style exact
Le style canon est gravure sépia (R29), le skill post-traite en duotone :
- **A.** Duotone strict CREAM/INK (pipeline actuel, zéro hex hors palette §20).
- **B.** Sépia 3 tons (+ rehauts GOLD sur les points de lumière).
- **C.** Gravure hachurée noir pur sur crème.
- **RECO : A** — déjà outillé et par construction conforme à « zéro hex hors MerlinVisual » ; B est une passe optionnelle si le duotone paraît plat en capture.

### DA-03 — Artworks : seuil de qualité et validation
Le manifest porte un champ `approved` :
- **A.** Auto-approbation (tout ce qui sort du pipeline entre en jeu).
- **B.** Cache initial pré-généré (~20-30 images de lieux) validé À LA MAIN, génération live ensuite pour les manques.
- **C.** 100 % pré-généré et validé, jamais de live en V1.
- **RECO : C** — avec DA-01 C le volume est fini (~30 lieux) ; la V1 embarque un cache validé, la génération live redevient un chantier v-next avec son gate propre (§24).

### DA-04 — Artworks : placement dans Z3
L'encart narratif Z3 fait 348 px en scroll_following (R136). Où vit l'image ?
- **A.** Bandeau haut de l'encart (96-120 px, fade-in async, la prose commence dessous).
- **B.** Filigrane en fond d'encart (alpha ≤ 0.12 sous le texte).
- **C.** Dans la zone décor Z2 (200 px), fusionnée au décor procédural.
- **RECO : A** — B menace le contraste CREAM/INK (§23) et C entre en collision avec le décor vivant R129 ; un bandeau respecte « l'image ne bloque jamais le texte » (§24).

### DA-05 — Portraits des piliers
Les 5 silhouettes procédurales existent (R129). Faut-il des portraits ?
- **A.** Les silhouettes suffisent partout en V1.
- **B.** Portraits gravure via `merlin-artwork` pour le CODEX seulement ; in-game, silhouettes canon.
- **C.** Portraits remplaçant les silhouettes in-game.
- **RECO : B** — les silhouettes in-game sont un choix canon (mystère) ; le codex est l'endroit où contempler sans casser la scène.

### DA-06 — Palette : évolutions permises
La palette §20 est verrouillée (zéro hex hors `MerlinVisual`). Règle pour la suite ?
- **A.** Gel total — plus aucune couleur nouvelle.
- **B.** Ajouts uniquement par constantes nommées dans MerlinVisual (ex. 1-2 accents par nouveau biome), avec entrée miroir dans la table §20 à chaque ajout.
- **C.** Accents libres par écran.
- **RECO : B** — c'est déjà la pratique de fait (EYE_*, RARE_BLUE) ; la formaliser garde le rebranding = 1 édition et la bible synchrone.

### DA-07 — Typographie : embarquer les fonts canon
La bible dit Cinzel / EB Garamond (R70) mais `assets/fonts/` ne contient que UncialAntiqua, VT323 et PressStart2P — écart bible/code.
- **A.** Embarquer Cinzel + EB Garamond (licences OFL) et câbler un Theme global (titres/corps), tailles FS_* inchangées.
- **B.** Amender la bible : UncialAntiqua pour les titres, défaut Godot pour le corps.
- **C.** Tout passer en UncialAntiqua.
- **RECO : A** — §20 dit « toute divergence = bug à corriger côté code OU amender la bible » ; le tout-serif R70 est un pilier d'identité et EB Garamond est nettement plus lisible en corps 36 px.

### DA-08 — Glyphes de tags : set complet ?
Le canon daltonisme exige couleur + forme par FAMILLE (R99). Étendre ?
- **A.** 6 formes de famille (Perception/Corps/Parole/Intuition/Mystique/Corrompu) partout, le mot porte le concept.
- **B.** Set complet : 25 glyphes distincts (R81), un par concept-cœur.
- **C.** Statu quo mixte non documenté.
- **RECO : A** — 25 formes lisibles à 16 px est illusoire et contredit ÉVIDENT (§23) ; famille = forme + mot = concept est exactement le contrat R99.

### DA-09 — Bordures de rareté animées
R53 prévoit Épique glow / Mythique irisé animé ; depuis R137 le liseré de tuile encode la qualité de dé.
- **A.** Garder liserés statiques + glow throttlé actuels ; pas d'irisé animé.
- **B.** Ajouter le shift irisé lent sur Mythique seulement (off en reduce-motion).
- **C.** Tout statique.
- **RECO : A** — le liseré est devenu de l'INFORMATION de jeu (chance du dé, R133) : l'animer ajouterait du bruit sur un canal décisionnel ; amender R53 en conséquence.

### DA-10 — Finition du biome Falaises
Falaises a mer animée, phare, goélands, embruns (R132). Pour la parité avec Brocéliande :
- **A.** Parité atteinte, rien à ajouter.
- **B.** Pack de parité : lieux archétypaux falaises dans les banques de préambule (écho R88), accent couleur dédié via constante (DA-06 B), nappe `amb_cotes.wav` déjà générée câblée au biome.
- **C.** Refonte visuelle complète.
- **RECO : B** — le décor est là ; ce qui manque est narratif et sonore, et les assets existent déjà.

### DA-11 — 3e biome en V1 ?
La cible long-terme est ~8 biomes (R97) ; `set_biome` rend l'ajout mécanique.
- **A.** Non — 2 biomes V1, la profondeur avant la largeur.
- **B.** Oui, 1 de plus (Tourbière/Marais — `amb_marais.wav` existe, lieu archétypal R88 déjà canon).
- **C.** 3 de plus.
- **RECO : A** — chaque biome coûte préambules + accent + nappe + QA captures ; mieux vaut 2 biomes parfaitement différenciés qu'un 3e tiède.

### DA-12 — Saisons : cosmétique ou gameplay
Le décor a des saisons (hiver = flocons R129).
- **A.** Cosmétique pur, rotation par run.
- **B.** Cosmétique + 1 mention dans le préambule R132 (« l'hiver tient la lande ») pour ancrer la saison dans la fiction.
- **C.** Mécanique : tags favorisés saisonniers.
- **RECO : B** — une ligne de banque suffit à transformer un effet visuel en monde cohérent ; C ajouterait une règle invisible, contre R127 « zéro stat cachée ».

### DA-13 — Glitch corruption : intensités finales
Les 4 paliers R75 sont câblés depuis v10.13.1. Tuning final V1 ?
- **A.** Valeurs actuelles gelées.
- **B.** Passe de tuning dédiée : renforcer le palier 15+ (« dissolution » doit inquiéter physiquement) et vérifier le palier 5-9 à peine perceptible, avec captures avant/après aux 4 paliers (gate §24).
- **C.** Réduire globalement.
- **RECO : B** — la dissolution est l'antichambre de la fin corrompue (R64) : si elle ne se sent pas, l'alerte « l'Emprise guette » porte seule tout le danger.

### DA-14 — Écran End : fresque de fin
MerlinEnd affiche épilogue + état. L'enrichir ?
- **A.** État actuel.
- **B.** Fresque d'état final : le décor du biome joué rendu à l'état de fin (palier corruption, saison) + silhouette du pilier croisé + épilogue par-dessus — 100 % réutilisation de MerlinSceneArt.
- **C.** Écran-seuil onirique complet (R50).
- **RECO : B** — « la forêt te renvoie ton reflet » (R88) trouve ici sa conclusion visuelle sans un pixel de neuf ; R50 reste le chantier méta selon GD-09.

### DA-15 — Menu : évolutions V1
Le menu est nu (R132) avec Merlin + bulle LLM (R122). Quoi ajouter ?
- **A.** Gel — le menu est fini.
- **B.** Deux touches méta : le ciel se teinte subtilement selon la dernière fin (Chronicle, alpha ≤ 0.08) + entrée « Codex » sobre si NAR-19 est retenu.
- **C.** Hub complet (jalons Graal, deck, codex).
- **RECO : B** — prolonge le principe forêt-miroir jusqu'au menu à coût minime ; C est l'écran-seuil déguisé, hors périmètre.

### DA-16 — Résolutions supportées
La grille fixe R136 est pensée 1920×1080.
- **A.** 1920×1080 seul, letterbox ailleurs.
- **B.** 1280×720 minimum via `content_scale` canvas_items + validation par captures aux 2 résolutions (8 cartes, vignette, boutons ≥44 px effectifs) — gate §24.
- **C.** Redimensionnement libre non validé.
- **RECO : B** — le plancher FS 16 px (R112) et les cibles 44 px (R18) doivent être vérifiés à l'échelle réelle, pas supposés.

### DA-17 — Reduce-motion : périmètre final
R74/§23 définissent durées ÷2, shake off, glitch cap ; mais le décor vivant R129 a beaucoup grossi.
- **A.** Périmètre actuel (le décor suit motion()).
- **B.** Option supplémentaire « décor calme » séparée de reduce-motion : sway/oiseaux/hover off, motes ÷2 — pour qui veut l'anim UI mais pas le fourmillement.
- **C.** Tout-ou-rien actuel.
- **RECO : B** — reduce-motion est une option d'accessibilité vestibulaire, « décor calme » une option de confort de lecture ; les fusionner punit l'un ou l'autre public.

### DA-18 — Contraste renforcé
L'option est promise par R74 mais jamais câblée. En V1 ?
- **A.** Reportée post-V1.
- **B.** Mode contraste : CREAM éclairci, DIM_WARM/INK_DIM remontés d'un cran, voiles de mood désactivés, glitch plafonné — via un set de constantes alternatif dans MerlinVisual.
- **C.** Thème clair complet.
- **RECO : B** — la centralisation MerlinVisual rend ce mode presque gratuit (1 table de swap), et la dette « promis par la bible, absent du code » viole la règle §20.

### DA-19 — Taille de texte réglable
R74 promet 3 paliers de taille, non câblés. En V1 ?
- **A.** Câbler 3 paliers globaux (FS_* × 0.9 / 1.0 / 1.15, plancher absolu 16 px R112) — l'encart scroll_following absorbe le débord.
- **B.** Palier sur la prose narrative seulement.
- **C.** Reporté.
- **RECO : A** — c'est LA feature d'accessibilité au meilleur ratio coût/impact pour un jeu où « le texte est roi » (R28). (NB : UX-15 recommande B — arbitrage : commencer par B, étendre à A si le re-audit de grille passe.)

### DA-20 — Lisibilité des types de greffes sur les tuiles
R137 définit 3 types de greffe sur les 4 tuiles-verbes, slots toujours dessinés. Comment les distinguer d'un regard ?
- **A.** Langage par canal existant : pastille couleur-famille pour le tag, le liseré (R133) pour la bande de dé, chiffre de charges pour ✚/❖/✦ — hover enrichit, ne révèle jamais (§23).
- **B.** Un glyphe or unique pour toute greffe, détail au survol.
- **C.** Texte descriptif permanent sous la tuile.
- **RECO : A** — réutilise trois canaux déjà appris par le joueur : zéro vocabulaire nouveau, conforme au dé-jargonnage R136.

## PARTIE 5 — AUDIO (20 questions)

### AUD-01 — ⚠ Musique gameplay : GO V1 et forme
`music/gameplay/` contient `gameplay_calm.wav` + 5 pads piliers ; le canon §22 spécifie drone + couche dissonante suivant la Corruption. Pour la V1 :
- **A.** Statique : gameplay_calm en boucle + pads aux présences (état actuel).
- **B.** Réactif 2 couches : base permanente + couche granuleuse dissonante dont le volume suit le palier R75 — la couche manquante générée offline via `tools/music_forge.py`.
- **C.** Stems complets 4+ (tension, intégrité, climax…).
- **RECO : B** — c'est le canon §22 mot pour mot, il ne manque qu'UN asset et un mapping volume↔palier déjà spécifié.

> **RÉPONSE : B** *(tranché en session interactive, 2026-07-04)*

### AUD-02 — Nombre de stems et seuils
Si AUD-01 B, jusqu'où empiler ?
- **A.** 2 couches (base + corruption), seuils = paliers R75 exacts.
- **B.** 3 couches (+ « intégrité basse » qui amincit la base, R76).
- **C.** 4+ couches par type de beat.
- **RECO : A** — l'intégrité basse a déjà ses alertes visuelles dédiées ; doubler le signal en audio ajoute du bruit au moment le plus tendu.

### AUD-03 — MusicGen : live ou banque
Le pipeline MusicGen est offline aujourd'hui (WAV embarqués).
- **A.** Génération live in-game (variété infinie).
- **B.** Banque pré-générée offline embarquée (état actuel), enrichie de variantes par biome.
- **C.** Hybride : live en tâche de très basse priorité.
- **RECO : B** — le CPU appartient à Gemma (R58) ; la musique live n'apporte que du risque de hitch pour un gain inaudible.

### AUD-04 — Transitions musicales en run
Le crossfade boot→menu existe (R123). En jeu, aux changements de quête/biome et à l'entrée de MerlinEnd :
- **A.** Cut simple.
- **B.** Crossfade equal-power 2-4 s au `begin_quest` et vers un cue de fin dédié sur MerlinEnd.
- **C.** Silence entre les états.
- **RECO : B** — le répit du sentier (R120) mérite d'être entendu.

### AUD-05 — SFX des moments muets
Moments sans SFX dédié : pose de greffe, draft qui remplace l'éventail, boutons Encaisser/Pousser, préambule lore, overlay choix de biome, hints tuto.
- **A.** Générer 6 ids neufs via `tools/sfx_forge.py` (seed fixe, feutré-organique R30).
- **B.** Réutiliser le catalogue existant (`ogham_unlock` pose de greffe, `card_reveal` draft, `button_appear` push, `mist_breath` préambule, `biome_reveal` overlay) + 1 seul id neuf `graft_set`.
- **C.** Laisser muet.
- **RECO : B** — le catalogue réel couvre presque tout ; seule la greffe, geste signature de v11, mérite son identité sonore propre.

### AUD-06 — Stingers de fin de run
Les 4 stingers de degré existent ; R76 prévoit « mort = coupure-silence », rien pour la fin corrompue.
- **A.** 3 stingers de fin dédiés via sfx_forge : accomplissement (résolution chaude), mort (coupure + résonance sourde), corrompu (dissonance qui avale la nappe).
- **B.** Réutiliser les stingers de degré.
- **C.** Silence + fade de la nappe.
- **RECO : A** — la bascule corrompue est une FIN canon distincte (R64/R69) qui n'a aujourd'hui aucun son ; 3 recettes sfx_forge = une heure de forge rejouable.

### AUD-07 — Voix de Merlin : procédurale ou TTS
La voix procédurale R124 (blips pitch/humeur, zéro latence) couvre toutes les scènes.
- **A.** Procédurale suffit pour la V1 — le TTS reste post-V1.
- **B.** TTS local expérimental derrière un flag Options (opt-in).
- **C.** TTS obligatoire V1.
- **RECO : A** — l'identité « voix-blips » est installée et cohérente avec le rétro-minimalisme §20 ; un TTS CPU concurrencerait Gemma (R58) pour un gain incertain.

### AUD-08 — Blips : fréquence et fatigue
Le blip joue toutes les ~2 lettres (R124) ; avec des proses de 4-6 phrases, la densité fatigue.
- **A.** Garder 1/2 lettres partout.
- **B.** Espacer à 1/3 lettres sur la prose longue in-game + micro-variation de pitch ±4 % par blip ; bulles courtes du menu inchangées.
- **C.** Blips sur les bulles seulement, prose in-game silencieuse.
- **RECO : B** — garde la « voix » sur tout ce que Merlin conte en éliminant l'effet mitraillette.

### AUD-09 — Voix : timbre des lignes non-Merlin
Les lignes signées des piliers (R131) passent par le même typewriter voixé. Distinguer le locuteur ?
- **A.** Non — tout est « conté par Merlin », un seul timbre.
- **B.** 1 timbre alternatif « murmure » (blip grave filtré, nouvelle recette sfx_forge) pour TOUTE ligne signée d'un pilier.
- **C.** 5 blips timbrés, un par pilier.
- **RECO : B** — un seul asset marque le changement de voix ; 5 timbres ne seraient perçus qu'à 1 intervention/run.

### AUD-10 — Ducking sous le typewriter
Le ducking canon est musique -6 dB pendant un stinger (§22).
- **A.** Étendre : duck musique -3 dB pendant tout typewriter actif (retour 0.8 s), en plus du duck stinger.
- **B.** Duck stinger seulement (état actuel).
- **C.** Sidechain fin sur chaque blip.
- **RECO : A** — c'est l'application mécanique du principe « la prose est reine » (§22).

### AUD-11 — Loudness : trancher l'écart bible/outil
La bible §22 gate « peak ≤ -3 dB » ; `sfx_forge.py` v3 normalise les SFX à **-14 dB**. Ambiguïté à trancher :
- **A.** Documenter les deux niveaux à la §22 : gate anti-clip ≤ -3 dB pour TOUT asset, norme de mix -14 dB pour les SFX, musique autour de -6 dB — la bible reflète l'outil.
- **B.** Tout remonter à -3 dB.
- **C.** Tout descendre à -14 dB, musique comprise.
- **RECO : A** — l'outil v3 a raison (SFX feutrés R30 = sous la musique) ; c'est la bible qui confond gate de sécurité et cible de mix.

### AUD-12 — Bus : Voice en vrai bus
3 bus existent (Master→Music, SFX) ; le volume voix R124 est logiciel.
- **A.** Créer un 4e bus Voice mappé au slider — ducking et mute propres par bus.
- **B.** Garder voice en volume logiciel sur le bus SFX.
- **C.** 5 bus (+ Ambiance).
- **RECO : A** — le bus rend AUD-08/09/10 implémentables proprement et isole la voix du mute SFX.

### AUD-13 — Nappes piliers : 5 suffisent ?
Les 5 pads existent, joués aux présences.
- **A.** Oui — 1 pad/pilier, inchangé.
- **B.** +1 variante « reconnaissance » par pilier quand `pnj_recog` (R127) — 10 assets.
- **C.** Pads dynamiques par couches.
- **RECO : A** — la reconnaissance est déjà portée par le texte ; doubler les assets double la maintenance pour une nuance marginale.

### AUD-14 — Son du dé
`dice_shake/roll/land` + `dice_crit_*` existent ; R133 met en scène la culbute avec ticks qui ralentissent.
- **A.** État actuel suffisant.
- **B.** Synchroniser les ticks sonores sur le ralentissement des faces + accent distinct quand « le sort a souri » (réutiliser `ogham_chime`, zéro asset neuf).
- **C.** Refonte complète du son de dé.
- **RECO : B** — l'oreille doit suivre la décélération pour que le dé pré-tiré « se sente » honnête (R133) ; l'accent or récompense sans rien générer.

### AUD-15 — Fusion : resynchroniser après R135
R135 a recapé la fusion en 3 phases (0.90-1.70 s totaux) ; les stamps SFX dataient de la version longue.
- **A.** Resynchroniser les déclencheurs existants sur les 3 nouvelles phases, aucun asset neuf.
- **B.** Forger un SFX de fusion courte dédié une-pièce.
- **C.** Fusion muette + stinger de degré seul.
- **RECO : A** — les assets sont bons, seul le timing a changé ; la déduplication 40 ms (R124) protège déjà des empilements.

### AUD-16 — SFX des interventions
La séquence d'intervention (R131) s'appuie sur le pad du pilier.
- **A.** Pad seul (état actuel).
- **B.** + apparition feutrée (`mist_breath` existant) à t=0 et disparition (`biome_dissolve`) au fondu — zéro génération.
- **C.** Thème musical court par pilier.
- **RECO : B** — deux réutilisations donnent un cadre sonore à la séquence de 1.8 s sans toucher à sfx_forge ni au mix.

### AUD-17 — Options audio : sliders
R74 fixe 3 curseurs, R124 a ajouté Voix — 4 sliders.
- **A.** 4 sliders actuels (Maître/Musique/SFX/Voix).
- **B.** +1 slider Ambiance (nappes/pads séparés de Music).
- **C.** Simplifier à 2 (Maître/Effets).
- **RECO : A** — 4 couvrent tous les usages réels ; MINIMAL (§23) vaut aussi pour l'écran Options.

### AUD-18 — Mute total
Jouable en silence (open-space, accessibilité) :
- **A.** Bouton/raccourci mute global (M) + icône discrète d'état, persisté.
- **B.** Master à 0 dans Options suffit.
- **C.** Mode « silence de Brocéliande » ne gardant que les SFX d'information.
- **RECO : A** — coût trivial, et le jeu porte déjà TOUTE son information en visuel (R112/§23) donc le mute ne fait rien perdre.

### AUD-19 — Audio et reduce-motion
Reduce-motion (R74/§23) ne touche pas l'audio aujourd'hui.
- **A.** Indépendants — reduce-motion reste purement visuel.
- **B.** Reduce-motion atténue aussi les SFX décoratifs (hover, motes, embruns) mais conserve les SFX d'information (jauges, seuils, stingers) — miroir exact de « atténue, ne supprime jamais l'information ».
- **C.** Option « audio calme » séparée.
- **RECO : B** — la cohérence de la sémantique §23 à travers les sens est élégante et gratuite.

### AUD-20 — QA audio : gate de couverture
Le gate v10.16 exigeait « 100 % déclencheurs joués » ; depuis, R130/R131/R136/R137 ont ajouté des moments.
- **A.** Étendre l'autoplay (harnais duck-typing) pour logger chaque `play_sfx` et diff-er contre le catalogue §22 + nouveaux ids — gate rejouable.
- **B.** Écoute manuelle par capture vidéo.
- **C.** Pas de gate audio V1.
- **RECO : A** — c'est le seul moyen de garantir qu'aucun des nouveaux moments (greffe, push, intervention) n'est resté muet, et l'infrastructure existe à 90 %.

<!-- ============ PARTIE UX + TECH + PRODUIT (65) ============ -->

**Sommaire**
- **UX/UI (UX-01…25)** : entrées clavier/manette/tactile, pause et options in-game, lecture (typewriter, fil VN, skip), feedback (anneaux, pill, Z4), draft de greffes, erreurs LLM, accessibilité (daltonisme, police), onboarding, End screen, saves.
- **TECH/MOTEUR (TEC-01…20)** : streaming R57, budgets et lookahead, modèle/quantisation/GPU/RAM, exports et binaire 3,3 GB, saves/méta/migration, perf, crash, seeds, debug en prod, sécurité prompts, whitelist R137, télémétrie.
- **PRODUIT/QA (PRO-01…20)** : DoD V1.0, jalons, fleet QA, playtests humains, KPI de fun, gates enrichis, budget solo dev + Claude, distribution/nom/identité/licences, doc joueur, versioning, definition of fail, arbitrages, recalibrage §K, périmètre, dette, critère de release.

## PARTIE 6 — UX/UI (25 questions)

### UX-01 — Navigation clavier V1
§23 promet « clavier de base au MVP » (R99) mais tout le flow réel est souris seule. Quel clavier pour la V1.0 ?
- **A.** Aucun — souris seule, amender R99 au canon.
- **B.** Clavier minimal : Espace = skip/continuer, Échap = pause, 1-4 = tuiles, A-D = traits, Entrée = Résoudre.
- **C.** Navigation focus complète (Tab + flèches sur toutes les cibles).
- **RECO : B** — 6 touches couvrent 100 % de la boucle REIGNS pour ~1 session de travail, et honore R99 sans le coût du focus-ring complet.

### UX-02 — Manette V1 ?
R99 classe la manette « post-MVP » ; le jeu est un lecteur à 2 gestes donc très mappable. GO/NO-GO V1 ?
- **A.** NO-GO V1.0 — canon R99 inchangé.
- **B.** Mapping XInput minimal (stick = curseur virtuel, A = clic) sans glyphes.
- **C.** Support complet + glyphes de boutons.
- **RECO : A** — zéro demande utilisateur, Windows desktop seul (§14) ; chaque heure va au fun plutôt qu'à une entrée hypothétique.

### UX-03 — Validation tactile réelle
Les cibles ≥44 px sont « tactile-ready » (R18/§23) mais jamais testées sur un vrai écran tactile. Que valide-t-on ?
- **A.** Rien — le tactile reste une dette théorique documentée.
- **B.** 1 session de test sur laptop Windows tactile (les 8 phases + draft), fixes ≤44 px seulement.
- **C.** Portage tablette officiel V1.
- **RECO : B** — coût quasi nul, transforme une promesse canon en fait mesuré, et attrape les hovers Z5 (lift) inaccessibles au doigt.

### UX-04 — Pause / quitter mid-beat
Aucune UI de pause n'existe ; R136 interdit les modals de PHASE, et R108 garantit une reprise propre au début de beat. Comment quitter en cours de beat ?
- **A.** Échap = retour menu direct sans confirmation (la save R108 suffit).
- **B.** Échap = overlay pause système plein écran (Reprendre / Options / Quitter) — exception assumée à « zéro modal », qui ne vise que les phases de jeu.
- **C.** Ligne de confirmation « Quitter ? » cross-fadée dans Z4.
- **RECO : B** — un pause système n'est pas un modal de phase ; A perd le travail du beat en cours sans prévenir, C pollue la ligne d'état narrative.

### UX-05 — Options accessibles in-game
MerlinOptions est une scène séparée, inaccessible depuis MerlinGame. Que règle-t-on mid-run ?
- **A.** L'overlay pause (UX-04) rejoue la scène Options complète puis revient au beat.
- **B.** Sous-ensemble in-pause : 4 volumes + reduce-motion + vitesse texte.
- **C.** Rien in-game V1 (retour menu obligatoire).
- **RECO : B** — les réglages « je lis / j'entends » sont ceux qu'on ajuste en jouant ; recharger la scène Options depuis le jeu risque des états de retour fragiles.

### UX-06 — Quelles options R74 au V1.0 ?
État réel de `merlin_options.gd` : 4 volumes + reduce-motion. R74 promet aussi vitesse typewriter, « tout afficher direct », 3 tailles de texte, police dys, contraste renforcé, presets perf. Quel sous-ensemble V1 ?
- **A.** Pack R74 complet (6 ajouts).
- **B.** Pack lecture : vitesse typewriter + « afficher direct » + 2-3 tailles de texte.
- **C.** Statu quo, R74 amendé « post-V1 ».
- **RECO : B** — le jeu EST de la lecture (feel Citizen Sleeper, R28) ; dys/contraste/presets suivent en V1.1 une fois les paliers de police prouvés dans la grille fixe.

### UX-07 — Vitesse du typewriter
La vitesse est fixe, skippable au clic (R63). Réglable ?
- **A.** 3 vitesses (Lent/Normal/Rapide) + bascule « afficher direct » (R74), persistées.
- **B.** Fixe + skip (statu quo).
- **C.** Adaptative : accélère automatiquement si le joueur skippe 3 beats de suite.
- **RECO : A** — c'est LE réglage de confort d'un jeu de lecture, canon R74 déjà écrit ; C est une magie invisible qui viole ÉVIDENT (§23).

### UX-08 — Historique de lecture (fil VN)
Z3 est déjà `scroll_active` + `scroll_following` (R136), mais le fil est remplacé au beat suivant. Peut-on re-scroller le récit ?
- **A.** Conserver le fil de la QUÊTE entière dans Z3 (scroll libre vers le haut, follow en bas).
- **B.** Carnet de route consultable (§9, prévu post-MVP) avancé à V1.
- **C.** Beat courant seul (statu quo).
- **RECO : A** — le scroll existe déjà, coût faible, et couvre le trou de mémoire à la reprise R108 ; B est un écran de plus contre la règle MINIMAL.

### UX-09 — Beat map CHEMIN
`merlin_beat_map.gd` (perles par quête, déviations, bornes) vit dans Z1. Garder / enrichir / couper ?
- **A.** Garder tel quel.
- **B.** Enrichir au survol : type de beat + « tu es ici » (le hover ENRICHIT, jamais exclusif, §23).
- **C.** Supprimer (minimalisme REIGNS).
- **RECO : B** — la map est le seul feedforward de rythme restant après le dé-jargonnage R136 ; l'enrichissement hover est gratuit en lisibilité de base.

### UX-10 — Deltas de jauges : anneaux seuls ?
R135 a réduit les deltas aux SEULS anneaux (commit différé post-typewriter) ; risque : le joueur fixe la pill Z4 et rate le −2 d'Intégrité. Protocole ?
- **A.** Playtest verbal d'abord : 5 joueurs verbalisent « qu'as-tu perdu ? » après 3 échecs ; on ne double l'info que si ≥2 échouent.
- **B.** Écho immédiat : « −2 » discret près de la pill sur échec/éclatante uniquement.
- **C.** Écho systématique sur tous les degrés.
- **RECO : A** — R112 anti « info ×2 » est canon ; on ne le casse que sur preuve mesurée, et B reste la correction prête si le test échoue.

### UX-11 — Anti double-clic sur Résoudre
Résoudre est permanent (désarmé alpha 0.35 → armé pulse, R136) ; deux courses de tweens au double-clic ont déjà été corrigées en review V2b. Faut-il une garde d'intention ?
- **A.** Rien de plus — l'armement visuel + gardes `_choice_open` suffisent.
- **B.** Cooldown d'armement 250 ms : Résoudre inerte pendant 0,25 s après le passage armé.
- **C.** Confirmation 2-taps (armer puis confirmer).
- **RECO : B** — invisible, tue le clic réflexe hérité de la pose du 2e trait, et préserve FACILE ≤2 gestes que C violerait.

### UX-12 — Comprendre les 3 types de greffe
R137 : +1 tag / +1 bande de dé / charges ✚❖✦ — draft 2 clics zéro modal, aucun tooltip aujourd'hui. Lisible sans aide ?
- **A.** Micro-libellé d'effet (1 ligne, ≥16 px) sur chaque carte de greffe présentée.
- **B.** Tooltip au survol des slots posés (couleur/pip/charges déjà dessinés).
- **C.** Les deux (libellé au draft + tooltip de rappel sur slots).
- **RECO : C** — le draft est LE concept le moins guidé du pivot v11 ; le libellé décide, le tooltip rappelle, aucun des deux n'ajoute de geste.

### UX-13 — LLM KO au boot
R61 garantit « jamais de blocage » en génération, mais rien ne couvre l'échec de CHARGEMENT (GGUF manquant/corrompu, RAM insuffisante). Quel écran ?
- **A.** Écran d'erreur diégétique (« Merlin ne rêve pas… ») + détail technique repliable + Réessayer/Quitter.
- **B.** Message d'erreur technique brut + fermeture.
- **C.** Mode fallback 100 % procédural jouable sans LLM.
- **RECO : A** — C viole « jamais de contenu fixe » (R32) et coûterait une version entière ; A coûte 1 session et sauve la première impression d'un joueur mal installé.

### UX-14 — Daltonisme : famille = couleur seule
Le vocabulaire R136 (« couleur de famille = tag ») contredit §11/§23 (« jamais la couleur seule ») pour les pastilles famille des slots de greffe et les liserés. Correction ?
- **A.** Glyphe/forme de famille systématique partout où la couleur famille est porteuse (pastilles slots, requis, tuiles).
- **B.** Palette daltonienne alternative dans Options.
- **C.** Audit ciblé (simulateur deutéranopie sur les captures 8 phases) puis fixes au cas par cas.
- **RECO : A** — c'est la règle canon existante (§11 : couleur + forme, le mot lisible) ; B ajoute une option là où le design de base doit suffire.

### UX-15 — Taille de police
R74 promet 3 paliers ; la grille fixe R136 encaisse mal +30 % de corps. Quel compromis ?
- **A.** 3 paliers globaux — Z3 scrolle, Z4/chips redessinés par palier.
- **B.** 2 paliers (100 % / 115 %) limités au texte narratif Z3 + pill (le scroll VN absorbe tout).
- **C.** Rien V1.
- **RECO : B** — 90 % du temps d'écran est le fil Z3 ; le palier global A force un re-audit complet « zéro changement de zone » du gate V2.

### UX-16 — Onboarding : 2 hints suffisent ?
Le micro-tuto = 2 hints one-shot ; rien ne guide le draft de greffes ni Encaisser/Pousser. Compléter ?
- **A.** Statu quo + télémétrie (taux d'échec beats 1-2, drafts passés) pour décider.
- **B.** +1 hint C au premier draft (« Greffe un pouvoir sur un verbe — 2 gestes ») et +1 hint D au premier partiel.
- **C.** Tuto optionnel rejouable depuis Options.
- **RECO : B** — même pattern one-shot déjà codé (coût ~1 h), sur les 2 seuls moments où le playtest peut se perdre ; C contredit « aucun panneau de règles » (§15). (NB : GD-35 propose 5 hints — compatible, B ici = les 2 premiers des 3 nouveaux.)

### UX-17 — Seuil onirique en UX
Le « seuil onirique » (R50) n'a aucune existence à l'écran aujourd'hui. Statut V1 ?
- **A.** Hors V1.0 — reste du lore latent, R50 marqué post-V1.
- **B.** Fondu dans les seuils existants : l'événement de seuil gagne une teinte onirique narrative, zéro UI neuve.
- **C.** Séquence dédiée (transition visuelle propre).
- **RECO : B** — zéro surface UI nouvelle (MINIMAL), le lore vit dans la prose. (⚠ dépend de GD-01/GD-09 : si le seuil-hub est retenu, C devient le chantier méta.)

### UX-18 — End screen : stats de run ?
MerlinEnd est narratif ; MerlinChronicle possède déjà runs_played/palmarès. Afficher des chiffres ?
- **A.** Fin narrative pure (statu quo).
- **B.** + panneau sobre 4 lignes : beats traversés · degrés (dont éclatantes) · Corruption max · greffes posées.
- **C.** B + palmarès cross-run (victoires/morts/corrompus).
- **RECO : B** — la relecture chiffrée nourrit le « je rejoue » (KPI PRO-05) sans casser le ton ; le palmarès C attendra un écran chronique dédié.

### UX-19 — Continuer vs Nouvelle partie : slots ?
R108 impose UN save de reprise auto ; « Nouvelle partie » écrase silencieusement la run en cours. Multi-slots ?
- **A.** 1 slot auto (statu quo strict).
- **B.** 3 slots manuels.
- **C.** 1 slot + confirmation « une run est en cours — l'abandonner ? » sur Nouvelle partie.
- **RECO : C** — B casse le contrat R108 et multiplie les cas de migration ; C répare la seule vraie perte accidentelle pour 20 lignes.

### UX-20 — Skip accidentel du texte
R63 : clic 1 = tout révéler, clic 2 = avancer ; un double-clic nerveux saute donc le beat sans l'avoir lu. Protection ?
- **A.** Statu quo (le fil Z3 re-scrollable UX-08 suffit comme filet).
- **B.** Zone morte 300 ms entre « texte révélé » et « clic = avancer ».
- **C.** Avancer uniquement via le caret Z4 (clic-texte ne fait que révéler).
- **RECO : B** — corrige le réflexe sans changer le geste appris ; C ajoute de la précision de visée contre FACILE.

### UX-21 — Contraste des chips en Z4
Vigilance V2a explicitement notée : « contraste chips sur BG_PAGE ». Comment la clore ?
- **A.** Audit automatisé : captures 8 phases + calcul de ratio (seuil 4.5:1) intégré à la fleet QA V4.
- **B.** Forcer un fond SURFACE sous pill+chips sans mesurer.
- **C.** Vérification à l'œil.
- **RECO : A** — la fleet QA V4 est déjà planifiée ; y ajouter le ratio rend le §23 « contrastes canon » vérifiable à chaque vague, pas une fois.

### UX-22 — Vignette 114 px dans Z4 72 px
Vigilance V2a : le cross-fade vignette↔push dépasse la ligne d'état (114 > 72). Résolution ?
- **A.** Compacter la vignette ≤72 px : pill 170×48 + chips sur UNE ligne horizontale.
- **B.** Débord cosmétique assumé (clip off), comme le lift Z5 sur Z4.
- **C.** Élargir Z4 à 96 px (re-gate « zéro changement de zone »).
- **RECO : A** — la hauteur fixe est LA règle unique de R136 ; un débord fonctionnel finira par chevaucher l'éventail actif.

### UX-23 — Langue V1.0
FR seul au MVP (R74) ; le préfixe KV-caché force le FR et les few-shots sont FR. EN à la release ?
- **A.** FR seul V1.0, EN étudié post-V1.
- **B.** EN à la release (re-tuning complet prompts + few-shots + UI).
- **C.** Architecture i18n préparée (strings externalisées) sans traduction.
- **RECO : A** — l'EN double la surface de QA LLM pour un solo dev ; même C est du temps volé au fun tant que le marché FR n'a pas validé le jeu. (NB : NAR-15-B propose C pour l'UI seule — arbitrage fin possible.)

### UX-24 — Symétrie Accepter/Refuser du pacte
R131 : pactes opt-in, +1 Corruption AFFICHÉE. Le refus doit-il peser autant visuellement que l'accept ?
- **A.** 2 boutons symétriques, même taille/hiérarchie, prix ✦ sur Accepter seulement.
- **B.** Statu quo (selon implémentation V2b).
- **C.** Refuser = caret discret (l'accept est mis en avant).
- **RECO : A** — un pacte est un dilemme, pas une conversion ; C serait un dark pattern qui fausserait la mesure du taux corrompu (cible ≤18 %).

### UX-25 — Contexte à la reprise (Continuer)
R108 reprend au début de beat, mais le joueur revient parfois 3 jours après, fil Z3 vide. Rappel de contexte ?
- **A.** Le résumé glissant (§9, déjà maintenu) s'écrit en tête du fil Z3 à la reprise, en style DIM (« Là où le rêve t'a laissé… »).
- **B.** Rejouer l'interstitiel de quête complet.
- **C.** Rien — le beat courant se suffit.
- **RECO : A** — la donnée existe déjà dans la save, zéro génération LLM, et transforme la contrainte technique R108 en moment narratif.

## PARTIE 7 — TECH/MOTEUR (20 questions)

### TEC-01 — ⚠ Streaming token-par-token (R57)
Le signal C++ token-par-token reste non branché ; le typewriter anime du texte complet et l'attente affiche une barre heuristique. Brancher pour V1 ?
- **A.** Streaming complet V1 (résolution prose + parsing incrémental).
- **B.** Rester heuristique V1, R57 reporté.
- **C.** Streaming sur la RÉSOLUTION seule (prose pure sans GBNF = zéro parsing incrémental).
- **RECO : C** — c'est l'attente post-Résoudre que le joueur subit à chaque beat ; 80 % du bénéfice perçu pour le risque GDExtension minimal, le JSON incrémental attendra.

> **RÉPONSE : C** *(tranché en session interactive, 2026-07-04)*

### TEC-02 — Budget cache-miss accepté
Cibles R58 : sélection <5 s, situation <8 s, résolution <5 s ; en cache-miss réel l'attente va jusqu'au cap 12 s. Quel contrat final ?
- **A.** Accepter cache-miss ≤12 s SI le taux de cache-miss mesuré (télémétrie) reste <10 % des beats.
- **B.** Durcir : prefetch N+2 pour écraser le taux de miss.
- **C.** Réduire max_tokens situation 250→180 pour raccourcir les miss.
- **RECO : A** — on gate un pourcentage mesurable plutôt qu'un pire cas ; B et C restent les leviers si la mesure sort de cible.

### TEC-03 — Modèle figé V1
Le binaire réel est `gemma4-e2b-q4_k_m.gguf` (3,3 GB) ; §14 mentionne E4B en option qualité. Que fige-t-on ?
- **A.** E2B Q4_K_M seul, figé V1.0 — c'est le SEUL artefact que les gates R109 ont jamais mesuré.
- **B.** + option E4B téléchargeable (Options avancées).
- **C.** + Q3 ~1B low-spec (plan B R94).
- **RECO : A** — chaque modèle supplémentaire double la matrice de QA ; le plan B Q3 reste documenté, pas shippé.

### TEC-04 — n_ctx 4096 et méta cross-run
n_ctx=4096 (R58) loge préfixe + résumé + tour ; la chronique cross-run s'ajoute au prompt d'arc. Suffisant ?
- **A.** Garder 4096 + surveiller « ctx utilisé » avec alerte à 85 %.
- **B.** Passer à 8192 (KV cache ~×2 en RAM, plus lent CPU).
- **C.** Garder 4096 + capper le bloc chronique injecté à ~60 tokens (résumé de résumé).
- **RECO : C** — la méta doit rester une ALLUSION (canon R127), pas un historique ; le cap protège le budget sans payer le prix RAM/latence de B.

### TEC-05 — Offload GPU optionnel
Le canon est CPU-aware (R94) ; llama.cpp sait offloader. V1 ?
- **A.** CPU only V1.0 — une seule config, celle que soak/autoplay mesurent.
- **B.** Offload auto si VRAM détectée, silencieux.
- **C.** Toggle « accélération GPU (expérimental) » dans Options.
- **RECO : A** — B crée des profils de perf/qualité non testés chez les joueurs (bugs irreproductibles) ; à réévaluer en V1.1 sur télémétrie réelle.

### TEC-06 — Presets perf joueur
R58/R74 promettent Éco/Équilibré/Perf ; en réalité seul l'auto existe. Exposer ?
- **A.** Exposer les 3 presets V1.
- **B.** Auto-détect silencieux seul (statu quo), R74 amendé.
- **C.** Auto + un seul toggle « mode économe ».
- **RECO : B** — aucun signal qu'un joueur règle mieux que l'auto ; le micro-bench TEC-20 informera mieux qu'un preset manuel.

### TEC-07 — ⚠ Export Windows : preset + gate
Aucun preset d'export configuré ; le jeu n'a JAMAIS tourné hors éditeur avec la GDExtension. Quand ?
- **A.** Immédiatement en V4 : preset Windows + gate « le build exporté passe 1 autoplay complet » ajouté à R109.
- **B.** Preset configuré à la beta, sans gate dédié.
- **C.** À la RC seulement.
- **RECO : A** — c'est LE risque existentiel restant (chemins res:// vs pack, chargement GGUF hors éditeur) ; le découvrir à la RC coûterait le jalon.

> **RÉPONSE : A** *(tranché en session interactive, 2026-07-04)*

### TEC-08 — Linux / Mac / Web : GO/NO-GO
La GDExtension C++ exige une recompilation par plateforme ; le Web est impossible (natif + 3,3 GB). Décision V1 ?
- **A.** NO-GO intégral V1.0 (canon §14 : multi-OS post-MVP), Windows seul.
- **B.** Linux best-effort en V1.1 selon demande itch.
- **C.** Démo Web sans LLM (contenu fixe).
- **RECO : A** — C viole frontalement « 100 % live, jamais de contenu fixe » (R32) ; B ne se discute qu'après des chiffres de demande réels.

### TEC-09 — Packaging du binaire (~4 GB)
GGUF 3,3 GB + build Godot : comment livrer ?
- **A.** Zip unique tout-inclus (~4 GB) sur itch — installe = dézipper, 100 % offline.
- **B.** Binaire léger + téléchargement du GGUF au premier lancement.
- **C.** Installeur (Inno Setup) avec GGUF inclus.
- **RECO : A** — B contredit la promesse « 100 % local » à l'instant le plus critique et ajoute un serveur à maintenir ; itch accepte les gros zips.

### TEC-10 — Robustesse des saves
SAVE_VERSION 2, invalidation propre, mais aucun checksum ni backup. V1 ?
- **A.** Checksum + copie `.bak` rotative à chaque save (restaurée automatiquement si le principal est illisible).
- **B.** Statu quo (version check seul).
- **C.** 3 slots manuels (couplé UX-19-B).
- **RECO : A** — ~1 session de travail contre le pire bug de churn possible ; le contrat mono-slot R108 reste intact.

### TEC-11 — Méta cross-run : fichier séparé ?
MerlinChronicle vit dans `user://options.cfg [chronique]` : réinitialiser ses options détruirait le palmarès. Migration ?
- **A.** Extraire la chronique vers `user://chronicle.cfg` dès la prochaine vague (lecture legacy conservée 1 version).
- **B.** Statu quo jusqu'à ce qu'un « reset options » existe.
- **C.** Unifier tout en un JSON versionné.
- **RECO : A** — séparation des cycles de vie (préférences ≠ mémoire) avant que la méta Graal (§8) ne grossisse.

### TEC-12 — Cibles perf runtime
Le gate v10.15 disait « zéro hitch >33 ms hors gen » ; rien n'est formalisé pour V1. Canoniser ?
- **A.** Canon V1 : 60 fps cible, 0 hitch >33 ms hors génération, mesuré sur les captures 8 phases ×2 biomes (fleet QA V4).
- **B.** 30 fps min suffisant (jeu de lecture).
- **C.** Pas de cible formelle, au ressenti.
- **RECO : A** — les décors `_draw` procéduraux + hover 7 éléments (R129) sont exactement le genre de code qui régresse sans gate chiffré.

### TEC-13 — Crash reporting
Rien n'existe ; le jeu est 100 % local (R98). Quel dispositif ?
- **A.** Log local : handler qui écrit `user://crash/*.log` (stack + version + seed) + mention « joignez ce fichier » sur la page itch.
- **B.** Rien V1.
- **C.** Upload opt-in réseau (Sentry-like).
- **RECO : A** — C introduit du réseau contre le canon ; A rend les bug reports actionnables pour un solo dev, coût ~2 h.

### TEC-14 — Seed de run exposée
Seed aléatoire en prod, fixe en debug (R59) ; dé pré-tiré et resume déterministe existent. Exposer ?
- **A.** Persister la seed de run dans la save + l'afficher discrètement sur MerlinEnd (partage, repro de bug, fleet QA).
- **B.** Statu quo (seed invisible).
- **C.** Mode replay complet d'une run.
- **RECO : A** — quasi gratuit, transforme chaque rapport de joueur en cas reproductible pour probe_soak ; C est disproportionné (le LLM reste non déterministe).

### TEC-15 — GemmaConsole & TweaksOverlay en prod
GemmaConsole (REPL prompt libre) est une des 6 scènes canon ; TweaksOverlay expose les constantes. Dans le build export ?
- **A.** Strippés des exports (gardés sous feature editor/debug), le smoke 6 scènes reste éditeur.
- **B.** Présents mais cachés (raccourci non documenté).
- **C.** Assumés visibles.
- **RECO : A** — un REPL de prompt libre en prod casse le 4e mur en un clic et invite le tweak sauvage ; le canon R96 vise le DEV, pas le joueur. (NB : NAR-27-B propose le flag caché — arbitrage A vs B à rendre, même décision.)

### TEC-16 — Injection via données persistées
Le résumé glissant et les faits marquants (générés) sont réinjectés dans les prompts ; une save éditée à la main devient un vecteur d'injection. Durcir ?
- **A.** Au load : sanitisation des champs texte de save (longueur max + filtre anti-dérive R61) avant toute réinjection.
- **B.** Rien — menace locale = le joueur ne peut s'attaquer que lui-même.
- **C.** Signature/HMAC des saves.
- **RECO : A** — réutilise un filtre existant pour fermer le seul vecteur d'entrée texte du jeu ; C punit les moddeurs pour un gain nul en solo local.

### TEC-17 — Whitelist required_tags → jeu réel
R137 l'avoue : « les tags greffés ne sont pas encore REQUIS en jeu » — les greffes +tag sont mécaniquement des placebos. Quand brancher la whitelist §F ?
- **A.** En V4, AVANT tout playtest externe et avant le recalibrage §K (sinon on calibre un faux système).
- **B.** Après le recalibrage §K.
- **C.** Couper les greffes +tag jusqu'au branchement.
- **RECO : A** — l'ordre inverse (B) invaliderait les 300 runs de mesure ; C ampute le draft déjà trop rare.

### TEC-18 — Cycle de vie de la télémétrie locale
1 JSON par run dans `user://` (R98) — sans purge, ça grossit à l'infini. Politique ?
- **A.** Rotation : cap 200 runs, agrégat mensuel compacté, purge du détail au-delà.
- **B.** Illimité (l'espace disque du joueur).
- **C.** Purge totale à chaque changement de version.
- **RECO : A** — garde assez d'historique pour les KPI PRO-05 tout en restant invisible pour le joueur ; C détruit les séries longitudinales.

### TEC-19 — Profondeur du lookahead
R110 : single-flight, priorités strictes, N+1 pendant qu'on joue N. Aller plus loin ?
- **A.** Statu quo N+1, décision pilotée par le taux de cache-miss (TEC-02).
- **B.** N+2 systématique en idle.
- **C.** Adaptatif : si le joueur lit lentement, générer plus loin.
- **RECO : A** — B chauffe le CPU pour des beats que la ramification peut invalider ; mesurer avant de complexifier le single-flight. (NB : NAR-29-B = N+2 opportuniste — arbitrage : A d'abord, B si miss >10 %.)

### TEC-20 — Config minimale & micro-bench
Aucune min spec publiée ; l'expérience dépend brutalement du CPU (E2B + KV 4096 → ~6-8 GB RAM, 5 GB disque). Quoi faire ?
- **A.** Publier des min specs mesurées sur 2 machines de référence, point.
- **B.** A + micro-bench au premier boot (~10 s de génération) : si tokens/s < seuil, avertissement honnête « les rêves de Merlin seront lents ».
- **C.** Rien.
- **RECO : B** — un joueur prévenu pardonne, un joueur surpris met 2/5 ; le bench réutilise le dashboard de métriques R96 existant.

## PARTIE 8 — PRODUIT / OBJECTIFS / QA (20 questions)

### PRO-01 — ⚠ Definition of DONE V1.0
R93 définit le DoD du MVP. Quel DoD chiffré pour V1.0 JOUABLE COMPLÈTE ?
- **A.** DoD composite : gate R109 vert + build EXPORTÉ passe autoplay + distribution §K dans les cibles + fleet QA PASS (§23 + charte) + 3 playtesteurs externes finissent une run sans aide et 2/3 relancent.
- **B.** R93 tel quel (l'éditeur suffit).
- **C.** Date butoir fixe, on shippe l'état atteint.
- **RECO : A** — chaque clause correspond à un trou connu de l'état réel (export jamais fait, §K hors cible, fleet QA jamais passée, zéro playtest externe).

> **RÉPONSE : A** *(tranché en session interactive, 2026-07-04)*

### PRO-02 — Jalons d'ici V1.0
Combien de versions entre v11-V4 et la 1.0 ?
- **A.** 3 jalons : V4 (fleet QA + purge + §K + whitelist) → v0.9 « beta export » (TEC-07, UX pack, playtests) → v1.0 RC.
- **B.** 5-6 jalons fins (1 par thème du questionnaire).
- **C.** Rolling release sans jalons.
- **RECO : A** — le rythme prouvé du projet est « 1 vague = 1 gate = 1 commit » ; 3 jalons gardent chaque gate significatif sans étirer le solo dev.

### PRO-03 — Cadence de la fleet QA
La fleet QA « agents humains » n'a JAMAIS tourné (task #45). Cadence ?
- **A.** Gate de sortie de CHAQUE vague livrée (captures fraîches 8 phases ×2 biomes, checklist charte/anim/overlap/§23).
- **B.** Hebdomadaire, décorrélée des vagues.
- **C.** Une seule passe avant la release.
- **RECO : A** — couplée aux vagues elle attrape les régressions quand elles sont fraîches ; C découvrirait 6 mois de dérive visuelle d'un coup.

### PRO-04 — Playtests humains externes
Zéro joueur externe à ce jour ; tout le « fun » est auto-évalué. Protocole ?
- **A.** 3 vagues × 3-5 joueurs (post-V4, post-v0.9, RC) : think-aloud 30-45 min sans aide, grille d'observation (blocages, relances, verbalisation deltas UX-10) + questionnaire 10 items.
- **B.** 1 grosse vague de 10 joueurs à la beta.
- **C.** Cercle proche informel au fil de l'eau.
- **RECO : A** — 3 points de mesure permettent de vérifier que les corrections corrigent.

### PRO-05 — KPI de fun mesurables
La télémétrie R98 loge tout en local. Quels seuils « c'est fun » ?
- **A.** 4 KPI : session médiane ≥25 min · ≥60 % des runs commencées finies · ≥40 % de re-run dans la session · <50 % de beats skippés au typewriter (proxy « je lis encore »).
- **B.** Uniquement le verbal des playtests.
- **C.** Un seul : « referais-tu une run ? » ≥7/10.
- **RECO : A** — mesurable sans réseau dès aujourd'hui via `cli godot telemetry`, et chaque KPI mappe un pilier (rétention, complétion, rejouabilité, lecture).

### PRO-06 — Gates enrichis de captures
Leçon v10.23 : ne JAMAIS mesurer le gate en mode capture. Comment intégrer le visuel au gate ?
- **A.** Job séparé post-gate : captures 8 phases ×2 biomes + diff screenshot vs baseline (seuil de pixels), échec = revue humaine.
- **B.** Captures manuelles quand on y pense.
- **C.** Statu quo (gate aveugle au visuel).
- **RECO : A** — sépare proprement mesure de perf et preuve visuelle, et automatise ce que la fleet QA vérifie aujourd'hui à l'œil.

### PRO-07 — Télémétrie réseau opt-in
R98 : 100 % local, partage anonyme opt-in « jamais par défaut ». Pour V1 ?
- **A.** V1 zéro réseau : tout local + bouton « exporter mes stats » (le joueur envoie s'il veut).
- **B.** Opt-in d'upload intégré (endpoint à héberger).
- **C.** Aucune trace du tout.
- **RECO : A** — respecte le canon à la lettre sans serveur à maintenir ; B introduit RGPD + infra pour un jeu gratuit solo dev.

### PRO-08 — Budget sessions par vague
Le rythme réel : plusieurs vagues majeures livrées par session Claude intensive. Cadrage ?
- **A.** Timebox : 8-12 sessions Claude par jalon PRO-02 ; un chantier qui dépasse ×2 son estimation est découpé ou coupé (report V1.1).
- **B.** Pas de budget, on avance au flow.
- **C.** 1 session/jour fixe.
- **RECO : A** — le pivot v11 a montré que le scope glisse par enthousiasme ; le timebox est le seul garde-fou d'un solo dev sans producer humain.

### PRO-09 — ⚠ Distribution
Gratuit probable, 100 % local, zip ~4 GB. Canal V1 ?
- **A.** itch.io gratuit (dons ouverts), page soignée, zip tout-inclus.
- **B.** Steam (100 $ + review + AI disclosure obligatoire pour le contenu généré).
- **C.** GitHub Releases seul.
- **RECO : A** — audience narrative/expérimentale idéale, tolérance aux gros fichiers, zéro friction légale ; Steam se réévalue si la traction itch le justifie.

> **RÉPONSE : A** *(tranché en session interactive, 2026-07-04)*

### PRO-10 — Nom final
« M.E.R.L.I.N. » est l'acronyme de travail. Le figer ?
- **A.** Garder M.E.R.L.I.N. + sous-titre évocateur (ex. « les rêves de Brocéliande »), après vérification rapide de collision (stores, marques FR/EU).
- **B.** Renommer complètement avant la beta.
- **C.** Décider à la RC.
- **RECO : A** — le nom est déjà diégétique (l'IA qui rêve, §13) et gravé dans le wordmark ; seule la collision juridique justifierait B.

### PRO-11 — Identité & page
Rien n'existe hors du wordmark in-game. Périmètre V1 ?
- **A.** Pack minimal : wordmark existant + 4-6 captures canon + GIF 15 s du jet de dé/fusion + page itch à la charte parchemin.
- **B.** Logo pro + trailer monté.
- **C.** Rien, le zip parle.
- **RECO : A** — tout est déjà produisible avec les outils du projet en 1-2 sessions ; B est du temps de polish pré-traction.

### PRO-12 — Licence des assets générés
La musique vient de MusicGen (poids CC-BY-NC : statut commercial douteux), SFX = forge procédurale maison, prose = Gemma, typos = OFL. Audit ?
- **A.** Audit licence par type d'asset avant la beta ; toute pièce MusicGen douteuse est regénérée via forge procédurale maison.
- **B.** Ignorer — jeu gratuit, risque faible.
- **C.** Tout regénérer maison par principe.
- **RECO : A** — même gratuit avec dons, le NC de MusicGen est le seul vrai point rouge ; l'audit coûte une session, le retrait forcé post-release coûterait bien plus.

### PRO-13 — Documentation joueur
Rien n'existe pour le joueur final ; le canon §15 interdit tout panneau de règles in-game. Quoi livrer ?
- **A.** Page itch + README court : install, min specs, « tout est généré localement, aucune donnée ne sort », crédits/licences — le gameplay reste 100 % in-game.
- **B.** Manuel PDF illustré.
- **C.** Rien.
- **RECO : A** — le README porte ce qui ne DOIT pas être diégétique (technique, vie privée) ; le jeu s'explique lui-même par design.

### PRO-14 — Versioning public
L'interne est à v11 (pivot). Numérotation de sortie ?
- **A.** Découpler : interne continue (v11, V4…), public = 0.9.0 beta → 1.0.0 (semver), mapping noté dans task_plan.
- **B.** Exposer la numérotation interne (v11.x) au public.
- **C.** Versions par date (2026.08).
- **RECO : A** — « v11 » raconterait 11 refontes aux joueurs ; le semver public donne un signal propre (0.9 = beta ouverte).

### PRO-15 — Definition of FAIL (quand pivoter)
Le projet a déjà pivoté sur signal user (« trop complexe »). Quel signal OBJECTIF pour couper/pivoter une mécanique ?
- **A.** Règle des deux échecs : 2 vagues de tuning sans atteindre la cible chiffrée OU 2 vagues de playtest où <50 % des joueurs comprennent la mécanique sans aide → pivot ou coupe, décision notée à la bible.
- **B.** Au jugement du user au fil des sessions.
- **C.** Jamais couper avant V1.0.
- **RECO : A** — les greffes sont déjà en zone grise (2,69 drafts/run vs 5-6, éclatante 2,9 % vs 8-15) ; sans règle écrite, le sunk cost décidera à votre place.

### PRO-16 — Priorité absolue en arbitrage
Quand une vague déborde (PRO-08), qu'est-ce qui saute en dernier ?
- **A.** Ordre : lisibilité/fun > fiabilité (R109/saves) > contenu (biomes, greffes) > polish (juice, audio).
- **B.** Contenu d'abord.
- **C.** Polish d'abord.
- **RECO : A** — c'est l'ordre que l'histoire du projet a déjà validé : le pivot v11 a sacrifié du spectacle (R135) pour la lecture, et R109 n'est jamais négocié.

### PRO-17 — Recalibrage §K (distribution des degrés)
Mesure V3 : échec 25,3 %, éclatante 2,8 %, morts 36,6 %, climax plein 1,1 % — « le dé seul ne suffit pas ». Approche ?
- **A.** Chantier V4 dédié multi-leviers : whitelist §F branchée (TEC-17) + fréquence de drafts remontée + contre-pression §E + DIE_BANDS, mesuré 300 runs ×5 archétypes après CHAQUE levier.
- **B.** Accepter un jeu punitif comme identité.
- **C.** Nerf global du dé uniquement.
- **RECO : A** — l'expérience DIE_BANDS a prouvé qu'un levier isolé ne bouge la distribution qu'à la marge ; B rend le fun invérifiable au playtest.

### PRO-18 — Périmètre contenu V1.0
État : 2 biomes, 4 verbes, 16 traits, 21 greffes, chaînes 2-3 quêtes. Geler ?
- **A.** Geler ce périmètre — V1.0 = profondeur (calibrage, lisibilité, fiabilité, méta), zéro contenu neuf.
- **B.** +1 biome (3e) pour la variété de re-run.
- **C.** +10 greffes et traits corrompus étendus.
- **RECO : A** — le moteur LLM fournit déjà la variété infinie des runs ; chaque ajout de contenu rouvre soak, fleet QA et calibrage §K. (NB : si GD-17-B est retenu, les fiches de figures ne comptent pas comme « contenu » au sens mécanique.)

### PRO-19 — Dette technique planifiée
Restes connus : banques legacy dans le chemin runtime, `addons/merlin_ai` hérité inutilisé, agents `.claude/agents` périmés. Traitement ?
- **A.** Purge intégrée à V4 (déjà listée au task_plan) + `--validate` du parc d'agents ajouté à la checklist de fin de jalon.
- **B.** Laisser — ça ne casse rien.
- **C.** Jalon « grand nettoyage » dédié avant la beta.
- **RECO : A** — la purge V4 est déjà décidée ; l'ancrer à la checklist évite qu'elle re-glisse, sans lui offrir un jalon entier qu'elle ne mérite pas.

### PRO-20 — Critère beta → release
Quel verrou final entre v0.9 publique et 1.0 ?
- **A.** Beta timeboxée 2-3 semaines : 0 crash bloquant sur ≥20 runs humaines cumulées + saves migrées sans perte + KPI PRO-05 atteints sur ≥5 joueurs + zéro régression fleet QA.
- **B.** Date fixe quoi qu'il arrive.
- **C.** Au ressenti après quelques retours.
- **RECO : A** — chaque clause est déjà outillée par ailleurs (crash logs, télémétrie, fleet QA) : la release devient une lecture de tableau de bord, pas un pari.
