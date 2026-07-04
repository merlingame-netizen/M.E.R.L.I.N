# SPEC v11 — PIVOT « ACTION + TRAIT » (panel adversarial, 2026-07-04)

> Panel Workflow 4 lentilles (canon / playtest-humain / ux-4piliers / balance) + auditeur final.
> Verdict : GO_AVEC_AJUSTEMENTS unanime. Décisions user verrouillées : 4 verbes fixes évolutifs,
> traits = qualités/manières (main 4 repiochée), greffes par draft, résolution dégraissée.

## Spec finale (auditeur)

SPEC v11 — « ACTION + TRAIT » (auditeur final, 2026-07-04). Arbitrages rendus sur les 4 lentilles, ancrés sur le code réel (merlin_tags.gd FAMILIES 25 concepts / merlin_resolution.gd / merlin_card.gd / merlin_fx.gd FUSION_DURATIONS / merlin_dice.gd).

== A. GESTE ==
1 ACTION (tuile permanente) + 1 TRAIT (main de 4) = sélection en 2 clics. ARBITRAGE (lentille UX, HIGH retenu) : le bouton Résoudre EST CONSERVÉ — 2 clics = sélection complète, le bouton s'arme + pulse (_combo_complete_pulse existant) ; jamais de résolution auto au 2e clic (misclick irréversible sur une décision qui coûte de l'Intégrité). Le verrou user « 2 clics » qualifie la sélection, pas la suppression de la confirmation.

== B. ACTIONS (4, fixes, évolutives) ==
ARBITRAGE 1-tag vs 2-tags : 2 TAGS DE BASE EXACTEMENT par action (lentilles 2+4 convergentes avec chiffrage : couverture pleine ~67%, partiel ~31% DANS la cible 28-38 ; le 1-tag de la lentille 1 rend l'éclatante diff2 impossible avant greffe, le full-family rend 50% des beats auto-gagnés). Jamais la famille entière. Mapping (valeurs affichées EXACTES de MerlinTags.FAMILIES) :
- PERCEVOIR = [Sens, Savoir] (famille Perception)
- AGIR = [Force, Agilité] (famille Corps)
- PARLER = [Empathie, Verbe] (famille Parole)
- RESSENTIR = [Instinct, Nature] (famille Intuition)
Implémentation : action-as-card — MerlinCard-like {id: "action_percevoir"…, tags: base+greffes-tags, corruption: 0, rarity: dérivée du nb de greffes} passé à resolve() en position [0]. R20 INTACT : le contrat de resolve() (couverture, bornes _apply_synergy, sabotage R66, bonus_tags R131, dé pré-tiré) ne change pas. Famille de synergie de l'action = sa famille canonique FIXE (les tags greffés ne la changent pas).
Tags GAP (réservés traits+greffes) : Mémoire, Vigilance (Perception) ; Endurance, Finesse (Corps) ; Ruse, Autorité, Franchise (Parole) ; Vision (Intuition). Monde : Mystère+Rituel via traits ; Sacrifice+Équilibre EXCLUSIFS aux greffes. Corrompu : uniquement traits injectés aux seuils.

== C. TRAITS ==
Deck de départ 16 (arbitrage : 16/main 4 des lentilles 1-3-4 contre 20/main 5 de la lentille 2 ; le déficit de couverture est traité par la whitelist required_tags + les greffes, pas par l'inflation du pool). 12 noms canon CONSERVÉS (évocations R102 recyclées en tooltips — lore 100% préservé) + 4 nouveaux. Structure lentille 4 : 8 tags gap ×2 slots + ≥1 slot secondaire par tag de base (nourrit la synergie et la couverture cross-action). RÈGLE DURE : tout trait porte ≥1 tag NON-dupliqué par une action (zéro trait mort). Exception assumée : Franchise ×1 (Parole a 3 gaps pour 16 traits) — compensée par la whitelist (émission des tags ×1 bornée à 1 beat/quête).
Main : 4 traits, REDRAW COMPLET chaque beat en CYCLE VRAI (tirage sans remise, défausse totale, reshuffle quand <4 restants — les 16 traits vus en ~4 beats, les corrompus polluent réellement). Pas de réserve de trait en v11.0 (re-crée de la gestion de main) — A/B possible post-soak si deadhand mesuré >45%.
Traits corrompus : 1 injecté au pool par seuil de Corruption franchi (5/10/15), 2 tags dont 1 Corrompu (ex. Le Murmure Complice [Murmure, Ruse] corr 1 ; La Faim du Vide [Vide, Force] corr 1 ; L'Emprise Douce [Emprise, Empathie] corr 1), corr 1 récurrent (SEUL porteur de coût récurrent du jeu), teinte VIOLET 7B4FA3 + pastille coût 28 px normée v10.21. Purgeables : PURGE du Chœur retire 1 trait corrompu du POOL. R113 re-spécifié : 4 actions toujours jouables (soft-lock impossible PAR CONSTRUCTION) + cap 1 trait corrompu par main (re-tirage silencieux de l'excédent) + ≥3 traits sains.

== D. MOTEUR (3 changements chirurgicaux dans merlin_resolution.gd, R20 préservé) ==
1. _synergy RÉÉCRITE (CRITICAL unanime — l'actuelle L140-163 donne +1 permanent à toute action 2-tags mono-famille et -1 systématique au geste cross-famille normal) : +1 SI le trait apporte ≥1 tag NON-dupliqué dont la famille == famille canonique de l'action ET trait non corrompu ; −1 SI trait corrompu ; 0 sinon. Les tags de base de l'action ne comptent JAMAIS entre eux.
2. ÉCLATANTE redéfinie (CRITICAL — l'actuel « extra non corrompu » donne 43-67% d'éclatantes avec union 3-4 tags) : éclatante = couverture pleine ET coût corruption 0 ET le TRAIT couvre ≥1 tag requis ET (synergie == +1 OU die_mod == +1). Remplace le plafond L87 (≥2 cartes, structurellement toujours satisfait). Cible soak : 8-15%.
3. DÉ (source unique, MEDIUM/HIGH convergent) : die_rarity = f(nb greffes de l'action jouée). Table INITIALE (lentille équilibrage, recalibrée à la baisse car le plancher de degré monte ; 6/6 supprimée = dé garanti = dé mort) : 0 greffe [0,0,0,0,0,1] 17% · 1 [0,0,0,0,1,1] 33% · 2 [0,0,0,1,1,1] 50% · 3 (cap) [0,0,1,1,1,1] 67%. Labels Commune/Rare/Épique/Mythique conservés pour le langage R133 (« liseré = qualité » — l'action EST la principale ; liseré de tuile = qualité). Face pré-tirée par beat conservée (R120 preview = résolution). W2 transitoire : bande fixe 33% tant que les greffes n'existent pas. Table = constante gatée TweaksOverlay, re-dérivée au soak W3 (si éclatante <8% ou morts >25% → relâcher d'un cran).
INTEGRITE_DELTA, PARTIEL_CORRUPTION_PRICE, PUSH_PRICE/BUDGET (R130), sabotage R66, bonus_tags (R131) : INCHANGÉS. R130 opère sur le degré post-resolve, intact.

== E. GREFFES (la profondeur) ==
Cap 3 par action (12 total, jamais saturé : E[acquisitions] = 5-6/run). 3 slots FIXES 24 px en pied de tuile, TOUJOURS dessinés (vides = cercle pointillé BORDER_BRUN → greffabilité ÉVIDENTE <2s ; glyphe = type sans hover : pastille FAMILY_COLORS = tag, pip or = bande de dé, ✚n/❖n/✦n = charges avec compteur). 3 types : (a) +1 tag permanent (25 concepts, Sacrifice/Équilibre exclusifs greffes) ; (b) +1 bande de dé ; (c) effet à charges HEAL 1-2 ×2 / PURGE 1 ×2 / DRAW 1 ×2 (DRAW pioche des TRAITS). Draft actuel « 1 sur 3 » → choix d'1 greffe parmi 3 + choix de l'action cible = 2 gestes (modal draft réutilisé). 4e greffe proposée = modal de REMPLACEMENT.
CORRUPTION (CRITICAL unanime) : coût récurrent INTERDIT sur toute greffe (une greffe permanente à corr 1 = +0,6-0,9 Corruption/beat = cap 18 défoncé en 2 quêtes). Le prix se paie ONE-SHOT à la pose (+1 affiché dans le modal, via run.add_corruption existante) ou PAR CHARGE activée. Banques pilier converties depuis pilier_bank()/enriched_pool() (noms+évocations conservés) : Chœur = HEAL/PURGE gratuits ; Être = +tag Mystère/Vision/Sacrifice contre +1 corr one-shot ; Compagnon = DRAW/HEAL tentation +1 corr one-shot ; Chevalier = +bande de dé ou +tag Force/Autorité corr 0 ; Enfant = piège 100% narratif corr 0.
CONTRE-PRESSION (HIGH lentille 4) : required_tags passe de 2 à 3 sur (a) tout beat difficulté 3 (climax, déjà flaggé build_chain_beats) et (b) tout beat de quête 3 dès que total_greffes ≥ 3 → couverture pleine retombe à 45-55% là où le récit culmine.

== F. GÉNÉRATION DES BEATS (HIGH convergent) ==
Whitelist des required_tags générables = {8 tags de base des actions} ∪ {tags du deck de traits courant} ∪ {tags greffés}. Validation des arc_tags LLM contre cette liste avec remplacement par le fallback du même index (merlin_scenario + merlin_prompt_builder : injecter le pool courant comme contrainte dure). Difficulté = nb de tags requis HORS tags de base des actions (1 à 3). Tags ×1 dans le pool (Franchise, Mystère, Rituel) : émission bornée 1 beat/quête. Sacrifice/Équilibre : jamais requis tant que non greffés. Assertion soak : 0 beat avec requis entièrement hors-pool.

== G. R131 REMAP (mécanismes inchangés, cibles re-mappées) ==
Bénédiction Chœur/Chevalier = tag temporaire VISIBLE posé sur UNE action, consommé au prochain usage (canal bonus_tags de resolve() inchangé sur TOUS les call-sites → R120 préservé tel quel) ; Enfant = offre un tag REQUIS (inchangé) ; Être/Compagnon = pactes opt-in +1 Corruption one-shot affichée (add_corruption/draw_extra inchangées, draw_extra pioche des traits). Cap 2 interventions/run, jamais au climax, persistance R108 reprise telle quelle.

== H. RÉSOLUTION DÉGRAISSÉE ==
Voir sequence_resolution. Décisions : expression jaune + copies CA = suppression CONFIRMÉE (déjà fait v11-W0, merlin_fx.gd L6/L237) et remplacée par RIEN de textuel ; purge du code mort (TAG_NOUNS, DEGREE_ECHO, FUSION_CA_OFFSET, _fusion_expression, factory label, _slam_degree_seal + SEAL_D ; DEGREE_SEAL_LABEL migre vers la pill). UN SEUL marqueur de degré : pill 170×48 (pastille 32 px degree_color + libellé 18-20 px CREAM — l'actuel badge 58 px/libellé 11 px viole déjà §23). Deltas de jauges : UNIQUEMENT dans les anneaux, en visuel DIFFÉRÉ post-typewriter (le modèle s'applique immédiatement — CRITICAL UX : l'actuel _on_gauges joue SOUS le layer MerlinFx plein écran) ; sur PARTIEL : deltas UNIQUEMENT dans le ledger Encaisser/Pousser (R130 différé respecté), anneaux APRÈS le choix, hauteur des boutons réservée dès la vignette (zéro layout shift). Chips : effets HEAL/PURGE/DRAW seuls + chip dé si die_mod>0. Zéro chip Intégrité/Corruption.

== I. LAYOUT (@1920×1080) ==
4 tuiles d'action 260×116 (SURFACE + liseré = qualité de dé, verbe FS_BTN 26 px, 2 pastilles tags de base 18 px, 3 slots greffe 24 px), rangée fixe bas, 1088 px centré. 4 traits 150×190 CREAM en éventail au-dessus (nom ≥16 px, 1-2 pastilles famille). Deux grammaires distinctes (tuile SURFACE vs carte CREAM) = anti-confusion « je cherche à jouer 2 cartes ». SUPPRESSION du combo panel (104 px) : la sélection se lit SUR l'élément (tuile = bordure GOLD 3 px + press 0.96 ; trait = levée +20 px + bordure GOLD). Bande basse ≈330 px, prose ≥500 px. Feedforward : required_tags en pastilles FAMILY_COLORS sur l'encart + souligné GOLD alpha 0.4 pulsé sur la tuile qui couvre ≥1 requis. connect_button_feedback réutilisé (retour ≤100 ms).

== J. MIGRATION ==
12 cartes canon → 12 des 16 traits (starter_deck() remplacé par starter_traits()) ; enriched_pool() + pilier_bank() → banques de greffes (zéro perte de contenu validé) ; saves : bump save_version + INVALIDATION PROPRE des saves antérieures (message + retour menu, JAMAIS de conversion mid-run — R108 rend la migration inutile), champs R130/R131 (pushes_left_quest, intervention_beats, pilier_interventions) repris ; probe_soak + autoplay_run réécrits action×trait EN W2 AVANT tout commit runtime (période aveugle R109 interdite) ; BIBLE : nouvelle règle R-numérotée par vague (cadence 10.3) + re-spec lore R49/R90/R92 (cartes-souvenir → traits/greffes-souvenir).

== K. CIBLES SOAK v11 (assertions codées dans probe_soak) ==
échec 3-8% · partiel 28-38% · réussite 45-55% · éclatante 8-15% · morts 10-25% · fins corrompues ≤18% · ~1 push/run · corruption/run ≈ 5,4 ±1,5 · couverture pleine au climax (3 requis) 45-55% · 0 beat requis hors-pool · sabotage R66 et ramification variant_type mesurés (fréquences loguées). Recalibrage : 2 passes soak 5×300 dédiées (W2, W3) — accepter que les cibles bougent transitoirement entre vagues.

## Mapping actions

### PERCEVOIR — tags de base : Sens, Savoir
- +1 tag [Mémoire] — greffe du Chœur (L'Eau Claire : « elle lave la mémoire de la peur »), corr 0
- +1 bande de dé — L'Œil du Druide (Chevalier/draft générique), pip or sur slot, corr 0
- Charge PURGE 1 ×2 — Le Baume du Chœur, gratuit, glyphe ❖2 sur slot
- +1 tag [Vision] — Le Pacte de Lisière (Être), +1 Corruption ONE-SHOT affichée au modal

### AGIR — tags de base : Force, Agilité
- +1 tag [Endurance] — La Lame Ternie (Chevalier), corr 0
- +1 bande de dé — La Charge du Déchu (Chevalier), corr 0
- Charge HEAL 1 ×2 — Le Bras de Fer (draft générique), glyphe ✚2
- +1 tag [Sacrifice] — L'Offrande de Sang (Être), +1 corr one-shot — débloque les requis Sacrifice greffe-only

### PARLER — tags de base : Empathie, Verbe
- +1 tag [Autorité] — Le Serment de Cendre (Chevalier), corr 0
- +1 tag [Franchise] — Le Serment Tenu (draft générique), corr 0 — 2e source de Franchise du build
- Charge DRAW 1 ×2 — Le Retour Promis (Compagnon), +1 corr one-shot, glyphe ✦2 (pioche des TRAITS)
- +1 bande de dé — La Voix d'Autorité (draft générique), corr 0

### RESSENTIR — tags de base : Instinct, Nature
- +1 tag [Mystère] — La Faveur Indicible (Être), +1 corr one-shot affichée
- +1 tag [Équilibre] — La Marche d'Équilibre (draft générique Épique), corr 0 — débloque les requis Équilibre greffe-only
- Charge HEAL 2 ×2 — La Promesse Ancienne (Compagnon), +1 corr one-shot
- +1 bande de dé — La Transe Druidique (draft générique), corr 0

## Mapping traits (deck de départ 16)

- **Le Regard Perçant** — [Vigilance, Sens]
- **L'Écoute du Silence** — [Vigilance]
- **La Mémoire des Lieux** — [Mémoire, Savoir]
- **La Main de Fer** — [Force, Endurance]
- **Le Pas Léger** — [Agilité, Finesse]
- **Le Souffle Tenace** — [Endurance]
- **La Langue de Miel** — [Ruse, Empathie]
- **Le Mot Rusé** — [Ruse, Verbe]
- **La Présence Calme** — [Autorité, Empathie]
- **Le Pressentiment** — [Vision, Instinct]
- **La Voix de la Forêt** — [Vision, Nature]
- **L'Appel de l'Ombre (corr 1)** — [Mystère, Nature]
- **La Main Sûre (nouveau)** — [Finesse]
- **Le Verbe Haut (nouveau)** — [Autorité, Verbe]
- **Le Cœur Franc (nouveau)** — [Franchise, Empathie]
- **Le Geste Ancien (nouveau)** — [Rituel, Mémoire]

## Séquence de résolution

Clic Résoudre (bouton CONSERVÉ, armé+pulse dès la paire action+trait complète) → t0 : MODÈLE appliqué immédiatement (invariants soak intacts), VISUEL : fusion courte gather+burst fusionnés, swell supprimé — durées {échec 0,90 s / partiel 1,10 s / réussite 1,30 s / éclatante 1,70 s} (vs 1,88-3,35 s post-W0 ; l'expression jaune + aberration + copies CA sont DÉJÀ supprimées v11-W0) → dé lancé EN CHEVAUCHEMENT sur la décrue de fusion à t0+0,6 s : TUMBLE 0,35 + SLOW 0,40 + SETTLE 0,25 + hold 0,15 = 1,15 s (vs 2,10 s ; pips conservés, face PRÉ-TIRÉE au beat — R120/R133 preview=résolution intact) → fin des visuels fixes ≈ t0+1,8 s (échec) à t0+2,4 s (éclatante) → prose : cache-hit = typewriter immédiat (fil unique R128) ; cache-miss = sustain skippable cap 12 s INCHANGÉ → à la FIN du typewriter (déclencheur _on_typewriter_done) : pill de degré 170×48 slam 0,25 s (pastille 32 px degree_color + libellé 18-20 px CREAM, remplace badge 58 px/11 px) + anneaux Intégrité/Corruption animent les deltas EN PARALLÈLE (float_delta fonte 24 px, montée 40 px, 1,2 s + flash) + chips effets HEAL/PURGE/DRAW uniquement + chip dé si die_mod>0 → si PARTIEL : AUCUN delta animé avant le choix — deltas UNIQUEMENT dans le ledger des boutons Encaisser/Pousser 320×56 (hauteur réservée dès la vignette, zéro layout shift), anneaux animés APRÈS le choix (R130 différé respecté, info à UN endroit). OVERHEAD FIXE hors LLM/typewriter : ~2,1-2,4 s (vs ~4,4-5,5 s post-W0, ~6,0-8,3 s avant) soit −60%. REDUCE-MOTION : fusion ÷2, face de dé directe, pill directe → ≤1,2 s ; TOUTE durée passe par ×motion() (leçon R134).

## Vagues

### W1 — Résolution dégraissée (UI pure, ZÉRO règle changée)

Fusion recapée {0,90/1,10/1,30/1,70 s} : gather+fuse fusionnés, phase swell supprimée. Purge code mort v11-W0 : TAG_NOUNS, DEGREE_ECHO, FUSION_CA_OFFSET, _fusion_expression, factory RichTextLabel d'expression, _slam_degree_seal+SEAL_D (DEGREE_SEAL_LABEL migre vers la pill) — aucun remplacement textuel. Dé compressé : TUMBLE_S 0,55→0,35, SLOW_S 0,65→0,40, SETTLE_S 0,35→0,25, hold 0,55→0,15, lancé en chevauchement sur la décrue de fusion. Pill de degré 170×48 (pastille 32 px + libellé 18-20 px) remplace le badge 58 px/11 px. Vignette dégraissée : 3 éléments max ordre fixe [pill][chip dé si die_mod>0][chips effets]. Deltas de jauges retirés de la vignette → anneaux en commit visuel DIFFÉRÉ post-typewriter (modèle appliqué immédiatement — fix du bug 'deltas joués sous le layer MerlinFx'). PARTIEL : deltas ledger seuls + hauteur boutons réservée. Reduce-motion : ×motion() sur toutes les nouvelles durées.

**Fichiers** : scripts/game/merlin_fx.gd · scripts/game/merlin_dice.gd · scripts/game/merlin_game.gd (_build_effect_vignette L~700, commit anneaux, _on_typewriter_done L~1244) · scripts/game/merlin_visual.gd (constantes pill)

**Gate** : validate_step0 0 erreur + smoke 6 scènes canon + soak 200/200 + autoplay 3/3 avec le harnais EXISTANT (aucune règle changée → R109 reste vert sans réécriture) + captures avant/après (§24) + vérif reduce-motion ≤1,2 s

### W2 — Moteur Action+Trait + harnais R109 réécrit

4 actions-as-card (id action_percevoir/agir/parler/ressentir, 2 tags de base fixes, rarity transitoire 'Commune' 33%) passées à resolve() en position [0] — R20 intact. Deck 16 traits (12 canon retaggés + 4 nouveaux, évocations conservées), main 4, cycle vrai (défausse totale/reshuffle <4). _synergy RÉÉCRITE (+1 trait apporte ≥1 tag non-dupliqué de la famille de l'action ; −1 corrompu ; 0 sinon). Éclatante REDÉFINIE (couverture pleine ET coût 0 ET trait couvre ≥1 requis ET (synergie +1 OU die_mod +1)). Requis 3 sur difficulté 3 (climax). Whitelist required_tags + validation arc_tags avec fallback même index (merlin_scenario, merlin_prompt_builder). UI : 4 tuiles 260×116 + éventail 4 traits 150×190 CREAM + SUPPRESSION combo panel + sélection sur l'élément + bouton Résoudre conservé + feedforward pastilles requis. R113 re-spécifié (4 actions toujours jouables + cap 1 corrompu/main). PRÉREQUIS DE MERGE : probe_soak 5 archétypes réécrits action×trait (optimal=max couverture, greedy=max dé/tags, corrompu=préfère corr, chaotic=uniforme, tag-ignorant=aléatoire) + autoplay_run réécrit (16 combos/beat).

**Fichiers** : scripts/game/merlin_resolution.gd · scripts/game/merlin_card.gd (+ merlin_action.gd) · scripts/game/merlin_run.gd · scripts/game/merlin_game.gd (_on_resolve L460+, _update_preview L~504) · scripts/game/merlin_card_view.gd · scripts/llm/merlin_scenario.gd · scripts/llm/merlin_prompt_builder.gd · tools/probe_soak.gd · tools/autoplay_run.gd

**Gate** : AUDIT 4 piliers §23 sur maquette statique AVANT le code UI. Puis soak 200/200 avec NOUVELLES assertions (échec 3-8%, partiel 28-38%, réussite 45-55%, éclatante 8-15%, morts 10-25%, 0 beat requis hors-pool) + 1 passe soak 5×300 de recalibrage + autoplay 3/3 + smoke 6 scènes. AUCUN commit runtime tant que le harnais réécrit n'est pas vert.

### W3 — Greffes (la profondeur) + dé par niveau de greffe

Draft '1 sur 3' → choix d'1 greffe parmi 3 + choix de l'action cible (2 gestes, modal draft réutilisé). Cap 3 greffes/action, 3 slots fixes 24 px toujours dessinés (vides = cercle pointillé BORDER_BRUN ; glyphes : pastille famille=tag, pip or=bande, ✚n/❖n/✦n=charges). 3 types : +1 tag permanent (Sacrifice/Équilibre exclusifs greffes) · +1 bande de dé · charges HEAL 1-2 ×2 / PURGE 1 ×2 / DRAW 1 ×2. Dé : die_rarity=f(greffes) table 17/33/50/67% (6/6 supprimée), liseré de tuile = qualité (langage R133 conservé). Banques pilier converties depuis pilier_bank()+enriched_pool() (Chœur gratuit, Être +1 corr ONE-SHOT, Compagnon +1 corr one-shot, Chevalier corr 0, Enfant narratif corr 0) — CORRUPTION RÉCURRENTE INTERDITE sur toute greffe. Requis 3 en quête 3 si total_greffes ≥3. 4e greffe = modal remplacement. Archétypes probe_soak greffe-aware.

**Fichiers** : scripts/game/merlin_card.gd (banques) · scripts/game/merlin_run.gd (état greffes, save) · scripts/game/merlin_game.gd (draft flow, rendu tuiles) · scripts/game/merlin_resolution.gd (mapping die_rarity) · scripts/llm/merlin_scenario.gd (pool greffé dans whitelist) · tools/probe_soak.gd

**Gate** : soak 200/200 avec drafts actifs : fins corrompues ≤18%, éclatante maintenue 8-15%, couverture pleine climax (3 requis) 45-55%, corruption/run ≈5,4 ±1,5 + 2e passe soak 5×300 recalibrage (table de dé re-dérivée si hors cible) + autoplay 3/3 + smoke

### W4 — Intégration R131, traits corrompus, save v2, purge legacy

R131 remap : bénédiction Chœur/Chevalier = tag temporaire VISIBLE sur UNE action via bonus_tags (consommé au prochain usage, TOUS les call-sites preview/prefetch/résolution → R120 préservé) ; Enfant = tag requis (inchangé) ; Être/Compagnon = pactes opt-in +1 corr one-shot ; cap 2 interventions/run, jamais au climax. Traits corrompus injectés aux seuils /5 (1/seuil, pool 16→17→18, 2 tags dont 1 Corrompu, corr 1, PURGE Chœur retire 1 du pool, cap 1/main). save_version bump + invalidation propre des saves v10.x (message + retour menu, zéro crash, zéro conversion) + reprise des champs R130/R131. Purge legacy : starter_deck/enriched_pool hors chemin runtime. BIBLE : nouvelle règle R-numérotée (pivot v11) + re-spec lore R49/R90/R92 en traits/greffes-souvenir. Passe merlin-juice dédiée sur le DÉ (il devient le héros de la séquence — identité Citizen Sleeper).

**Fichiers** : scripts/game/merlin_run.gd · scripts/game/merlin_game.gd · scripts/llm/merlin_scenario.gd · scripts/game/merlin_card.gd · docs/BIBLE.md · tools/probe_soak.gd (assertions finales)

**Gate** : R109 COMPLET : soak 200/200 + autoplay 3/3 + 0 SCRIPT ERROR + smoke 6 scènes + toutes les assertions K vertes + checklist post-dev CLAUDE.md (validate → smoke → soak → commit → push) + BIBLE mise à jour vérifiée

## Guardrails

- GATE JAMAIS AVEUGLE : probe_soak + autoplay_run réécrits action×trait DANS W2, AVANT tout commit runtime touchant une règle ; interdiction absolue de commit tant que le harnais réécrit n'est pas vert (soak 200/200 + autoplay 3/3) ; vérifier que le gate échoue BRUYAMMENT (autoplay 0/3) sur tout renommage de nœuds/boutons des tuiles — jamais de faux vert par duck-typing silencieux.
- R20 INTACT : le contrat de resolve() ne change pas — l'action est passée comme card-like en position [0]. Seuls _synergy, la condition éclatante et le mapping die_rarity changent, chacun couvert par une assertion soak dédiée. Toute autre modification du moteur = hors périmètre v11.
- R120 PREVIEW = RÉSOLUTION : bonus_tags transmis sur TOUS les call-sites (preview, prefetch, résolution) ; face de dé pré-tirée UNE fois par beat ; liseré de tuile = bande déterministe de l'action sélectionnée. Toute divergence preview/résultat = bug bloquant (pire bug de confiance possible).
- CORRUPTION DES GREFFES : zéro coût récurrent par résolution, sans exception — one-shot à la pose ou par charge activée uniquement. Le coût récurrent vit UNIQUEMENT sur les traits corrompus (corr 1). Assertion soak : corruption/run ≈ 5,4 ±1,5.
- WHITELIST required_tags : émission bornée au pool atteignable (tags de base actions ∪ deck de traits ∪ greffes), validation des arc_tags LLM avec fallback même index, tags ×1 dans le pool bornés à 1 beat/quête, Sacrifice/Équilibre jamais requis sans greffe. Assertion soak : 0 beat à requis entièrement hors-pool.
- SAVES R108 : bump save_version + invalidation PROPRE des saves antérieures (message + retour menu, jamais de crash, JAMAIS de conversion mid-run) ; champs R130/R131 (pushes_left_quest, intervention_beats, pilier_interventions) repris tels quels dans le save v2.
- PREFETCH LLM : spéculation sur la SÉLECTION courante uniquement — jamais les 16 combos action×trait. Le prefetch dès le 1er clic (action posée) pour les 4 traits de la main est une option à chiffrer en latence Gemma AVANT activation (le geste 2-clics raccourcit la fenêtre qui masquait le prefetch).
- CIBLES SOAK = ASSERTIONS CODÉES dans probe_soak (échec 3-8, partiel 28-38, réussite 45-55, éclatante 8-15, morts 10-25, corrompu ≤18, ~1 push/run) ; pool de traits (16) et table de dé figés comme constantes gatées (TweaksOverlay) — tout ajout au pool ou changement de table impose une re-dérivation des cibles (2 traits ajoutés sans recalcul suffisent à sortir le partiel de la cible).
- BOUTON RÉSOUDRE CONSERVÉ : 2 clics = sélection, confirmation explicite obligatoire — jamais de résolution automatique au 2e clic (misclick irréversible sur une décision à coût d'Intégrité).
- R130 : re-mesurer partiel et pushes/run au gate W2 AVANT de toucher PUSH_BUDGET_PER_QUEST ; sabotage R66 et ramification variant_type inclus dans les assertions soak (leurs fréquences effectives bougent silencieusement avec le nouveau profil de degrés).
- UX : audit 4 piliers §23 sur maquette STATIQUE avant le code UI de W2 ; captures avant/après à chaque vague (§24) ; distinction tuile SURFACE vs trait CREAM testée sur quelqu'un qui n'a jamais vu le jeu (compréhension des 4 verbes <2 s) ; protocole playtest verbal des deltas-anneaux (le testeur annonce ses deltas après 3 beats — 2 échecs sur 3 → ajouter un écho minimal sur la pill) ; toute nouvelle durée d'animation passe par ×motion() (leçon R134).
- BIBLE-FIRST (cadence 10.3) : nouvelle règle R-numérotée à la clôture de CHAQUE vague ; re-spécifier le lore cartes → traits/greffes-souvenir (R49/R90/R92) en W4 sous peine de divergence canon ; docs/archive reste non-autoritaire.
- PÉRIODE TRANSITOIRE ASSUMÉE : W2 sera plus plat que l'actuel (la profondeur = greffes en W3) et tout le tuning mesuré v10.14-v10.21 est invalidé — les cibles bougent transitoirement entre vagues, c'est acceptable SI chaque vague ferme sur son gate vert et si W3 suit vite.
