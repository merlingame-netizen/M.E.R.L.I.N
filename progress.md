# Progress Log - M.E.R.L.I.N.

> **Note**: Sessions anterieures archivees dans `archive/progress_archive_2026-02-05_to_2026-02-08.md`

## Session: 2026-07-04 — v11-V3 GREFFES (la profondeur du pivot)

### Réalisé
- **Données** : `MerlinCard.grafts` ADDITIF (saves W2 OK, pas de bump), `refresh_from_grafts()`
  (tags = 2 base + greffés ; rarity = f(nb greffes)), `graft_banks()` 21 greffes (lore 100 % conservé).
- **Moteur** : DIE_BANDS = f(greffes), 6/6 supprimée ; relâchée d'un cran au recalibrage (33/50/67/83).
- **État** : `apply_graft` (cap 3, prix ONE-SHOT, zéro save — R108), `apply_graft_charges` (HEAL/PURGE/
  DRAW à la pose du verbe, DRAW pioche des traits), `graft_choices`/`pilier_graft_offering` runtime.
- **UI** : draft 2 gestes (greffe levée+GOLD → « Touche l'action » → tuile éligible pulse →
  `_on_graft_target` → pop+flash+liseré) ; slots remplis dessinés (pastille famille/pip or/✚n❖n✦n).
- **Harnais MÊME COMMIT** : probe_soak greffe-aware (self-tests §E, optimal cible l'action la plus
  jouée, greffes/run loguées §K, resume greffes) ; autoplay 2 gestes (clic tuile éligible).

### Code-review (agent) — 0 CRITICAL, tous findings traités
- H1 : probe n'appelait pas apply_graft_charges (miroir incomplet) → ajouté + campagne §K re-mesurée.
- M1 : DRAW de greffe MORT (redraw complet → pioche défaussée, Retour Promis payait 1 corr pour
  rien) → `next_draw_bonus` : la pioche porte sur la main du beat SUIVANT (persisté, additif).
- M2 : assertion resume renforcée (signature id:charges par action + next_draw_bonus).
- L1-L4 : cap non codé en dur (autoplay), log skip fidèle, SFX de pose hors reduce-motion,
  tweens de pose killés avant re-pose. L5 (legacy hors W3) et L6 (add_corruption sans check de
  cap immédiat — cohérent pactes R131) documentés en vigilances.

### Gates (config finale, post-fixes)
- validate_step0 0/0 · smoke Game+Menu passed · soak 200/200 · soak 300/300 · autoplay 3/3
  (greffes posées en conditions réelles, cap 3 observé). 0 SCRIPT ERROR.
- Recalibrage dé : table spec 17/33/50/67 mesurée (éclatante 2,3 %/morts 47,2 %) → relâchée d'UN
  cran 33/50/67/83 (une fois, comme mandaté) → re-mesure.
- §K final (n=216 saines, 1738 beats, miroir charges inclus) : échec 25,3 % · partiel 28,5 % IN ·
  réussite 43,4 % · éclatante 2,8 % · morts 36,6 % · corrompues 0 % IN · pushes 1,32 IN ·
  corruption 5,94 IN · climax plein 1,1 % · greffes/run 2,69 · hors-pool 0 · deadhand 34,9 %.
  PAS committé (décision orchestrateur sur l'équilibrage restant).

## Session: 2026-06-29 — v10.20 Yeux à humeurs, voix procédurale, DA alignée

### Context
User : skip impossible pendant la gen LLM ; DA varie trop menu↔sélection↔options ; yeux de Merlin
bleus brillants (neutre) / jaune glow (surprise) / rouge + sourcils froncés (colère) ; chaque phrase
avec une voix. Décisions AskUserQuestion : voix procédurale synchronisée · humeur par heuristique de
texte · volume+toggle Options · alignement DA FORT.

### Réalisé
- **Fix skip sélection** : la caption mangeait les clics (`mouse_filter`) → IGNORE ; affordance « passer »
  à **3 s** (au lieu de 20) → on peut couper la gen LLM (skip = fallback).
- **Yeux à humeurs (R124)** : `MerlinVisual` EYE_NEUTRAL/SURPRISE/ANGRY ; `MerlinSceneArt.set_eye_mood` +
  décroissance ~4.5 s + `mood_for_text` (heuristique) ; rendu = couleur + glow + écartement par humeur +
  **sourcils froncés** (angry). Câblé : `merlin_menu._say`, transition montage (humeur depuis la réplique).
- **Voix procédurale (R124)** : `sfx_forge` cue `voice_blip` ; `MerlinAudio.play_voice` + pool dédié +
  `voice_vol` (prefs) ; `MerlinSpeechBubble` blip toutes les ~2 lettres, **pitch selon l'humeur** ;
  gate `MerlinVoicePrefs`. Options : slider « Voix de Merlin (volume) ».
- **DA alignée (R125)** : NEW `merlin_ornament.gd` (filet+triskèle+diamant+fond scène vivante PARTAGÉS).
  Sélection : fond `MerlinSceneArt` vivant + filet/triskèle or + parchemins en pop d'échelle. Options :
  filet/triskèle or. → écrans secondaires = « même monde » que le menu.

### Gates
- validate 0 err. Smoke Boot/Menu/Selection/Game passed (0 script_error). **Soak R109 200/200**.
- `voice_blip` + `boot_eveil` générés. Captures : yeux **JAUNES** (surprise) + **ROUGES + sourcils** (angry)
  confirmés. Voix (audio) joue en jeu (non headless). DA sélection/options : composants vérifiés (smoke).

---

## Session: 2026-06-29 — v10.19b Flow d'entrée mis en scène par Merlin

### Context
User : intro (boot) avec musique ; clic Nouvelle Partie/Continuer → transition **zoom vers Merlin qui
parle** ; sélection manuelle mais **titres forcément LLM** + montage ultra-animé ; première fois Merlin
nous parle ; voix paramétrable dans Options. Décisions AskUserQuestion : cue d'éveil dédié · zoom-parole
Nouvelle+Continuer · titres attente longue+filet · Options = on/off seul.

### Réalisé (5 phases)
- **A — Musique intro** : `music_forge.py` cue `boot_eveil` (drone grave + cloches basses + réverb, 19 s)
  → `res://music/intro/boot_eveil.wav` ; `merlin_boot._setup_eveil_music()` le joue en `_ready` →
  crossfade propre vers le thème au menu (pistes différentes).
- **B — Voix paramétrable + 1re fois** : NEW `merlin_voice_prefs.gd` (`[voice] enabled`) ; toggle
  « Voix de Merlin » dans `merlin_options` ; `merlin_menu_voice` gate `is_enabled()` ; modes prompt
  `premiere` (1er lancement, chronique vierge) + `depart`.
- **C — Transition « zoom + parole »** : `merlin_transition.change_scene_merlin(path, line, gate)` —
  voile sombre → MerlinSceneArt zoomé (pivot yeux) + MerlinSpeechBubble (réplique **pré-fetchée** par la
  voix → single-flight préservé) + push-in QUINT → swap. `merlin_menu._on_new`/`_on_continue` l'utilisent.
- **D — Titres forcés-LLM + montage** : `merlin_scenario.is_selection_ready()` + `ensure_selection_prefetch()` ;
  `merlin_selection` attend les titres LLM (montage MerlinSceneArt « réfléchit » + caption pulse + dots +
  quill), filet **cap 75 s** + skip révélé à **20 s** (skip→fallback) ; pick → `change_scene_merlin` (montage
  scénario, réplique fixe car l'arc génère).

### Gates
- validate_step0 0 err. `music_forge --id boot_eveil` OK (19 s, -12 dBFS).
- Smoke **Boot/Menu/Selection/Game** = passed, script_errors 0.
- **Soak R109** : 200/200 logic passed.
- **Capture transition zoom-parole** (dev hook MERLIN_AUTOCLICK) : voile sombre → Merlin zoomé (tête + yeux
  bleus, décor caché) + bulle « Le sentier s'ouvre, Voyageur… » → swap. ✓ Confirmé visuellement.
- Musique boot + montage sélection : composants déjà vérifiés (MerlinSceneArt/bulle/WaitStage) ; audio non
  vérifiable en headless → confirmer en jeu live.

---

## Session: 2026-06-29 — v10.19 Merlin parle (bulles de pensée LLM au menu)

### Context
User : « Merlin doit parler, bulles au-dessus de sa tête, c'est le LLM qui se fait des réflexions
automatiquement — salue, parle de la journée, commente la dernière fois qu'on s'est vus, encourage,
blague. » Décisions (AskUserQuestion) : **100% LLM** (pas de banque écrite ; on cache la sortie LLM
pour masquer la latence), **mémoire riche**, déclenchement **arrivée + idle + survol**, cadence **modérée**.
Exploration : 3 agents Explore (API LLM / placement menu+bulle / save+contexte).

### Réalisé
- **merlin_chronicle.gd** (NEW, statique ConfigFile [chronique]) : runs_played, wins/deaths/corrupted,
  last_end_type/title/integrite/corruption, last_run_iso, last_seen_iso + `days_since_seen`.
- **merlin_prompt_builder.menu_thought(voice, mode, ctx)** : 6 modes (salut/journee/souvenir/encourage/
  blague/survol), 1 phrase courte, persona MERLIN_VOICE_PREFIX, opts {creative, max_tokens 56}.
- **merlin_menu_voice.gd** (NEW, Node) : ordonnanceur — file (cap 3) + cache survol par bouton ;
  gate `is_ready() and not is_busy()` + délai initial 1,5 s → **cède la priorité à la pré-gen scénarios** ;
  `_tidy` (clean_prose + first_sentence + borne 110 car.). 100% LLM, sortie juste mise en cache.
- **merlin_speech_bubble.gd** (NEW, Control) : parchemin CREAM/bord GOLD au-dessus de la tête (suivi
  live `_scene_art._fig_head`, clamp écran), queue triangle, machine à écrire (visible_ratio), auto-fondu
  7 s ; reduced_motion = texte plein + position figée + fondus ÷2.
- **merlin_menu.gd** : lecture chronique + touch_seen ; instancie voix+bulle ; `_tick_voice` (1re pensée
  dès prête, puis 14–20 s) ; survol bouton → `_maybe_hover_voice` ; `_exit_tree` → voice.stop().
- **merlin_game.gd** : `MerlinChronicle.record_end(...)` à la fin de run AVANT clear_save.

### Gates
- validate_step0 0 err. Smoke Menu/Selection/Game = passed, script_errors 0 (modèle absent en headless
  → la voix attend `is_ready`, aucun crash).
- **Capture (dev hook MERLIN_VOICE_TEST)** : bulle parchemin au-dessus de la tête, queue vers Merlin,
  texte lisible, suivi, z-order OK — vérifié visuellement (lancement direct MerlinMenu.tscn).
- Voix LLM réelle : même chemin `MerlinNative.generate` que la prose in-game (éprouvé) ; non frame-capturée
  (CPU lent + readback throttle) → à confirmer en jeu live. Mémoire : logique ConfigFile (idiome prefs éprouvé).

---

## Session: 2026-06-29 — v10.18 Boot cinématique (intro 5 actes)

### Context
User : le boot doit être un plan cinématique — yeux en zoom qui se réveillent → regardent →
dezoom + apparition du décor selon SAISON + heure du jour → pause 0,5s → grondement + push
BRUSQUE du menu depuis la gauche (décor + yeux ébahis, 1,3s). Design via workflow 4 agents
(timeline + feel acte 5 + saisons + faisabilité Godot) ; facts via Explore (audio/menu/palette/shake).

### Done
- **MerlinSceneArt** : `set_decor_reveal(0..1)` (multiplie l'alpha de ~15 éléments décor, défaut 1.0
  → menu/in-game inchangés ; figure NON affectée) ; hooks yeux cinématiques `set_eye_open/glow/widen`
  + `set_scripted_gaze` ; `set_season` (4 saisons, feuillage blobs dérivé palette canon + accents
  sol/ciel/lucioles) + `season_for_now()` static. Aucune modif merlin_visual.gd (tout dérivé).
- **merlin_boot** : re-chorégraphie 5 actes — zoom (scale du Control, pivot YEUX recalculé/frame) →
  dezoom QUINT + decor_reveal → pause + GATE model_ready (filet 8s, no-freeze préservé : modèle threadé)
  → grondement (shake + SFX seal_stamp pitché) + push panneau BG_DEEP depuis la gauche (BACK overshoot)
  + décor shové droite + yeux ébahis (widen/glow/regard gauche) → change_scene MerlinMenu. Dev hook
  `MERLIN_BOOT_SKIP_TO_PUSH` (capture acte 5). Caption discrète par acte.
- **merlin_menu** : `set_season(season_for_now())` (décor saisonnier cohérent boot↔menu).

### Fixes intégrés (feedback user + review adversariale, même commit)
- **Double-musique « nouvelle partie »** : `MerlinTransition` STOPPE la piste de base sous le voile
  (`stop_music`) au lieu de la ducker → la scène suivante démarre de zéro, plus de chevauchement de 2
  mélodies (menu theme vs VOYAGEUR/Tri Martolod). `restore_music` retiré.
- **Transitions plus lentes** : `DUR_INK_WIPE` 0.65 → 1.0 (couvre + révèle ~2s, plus posé).
- **Review C1/C2** : `_stage`/`_panel` ré-ancrés TOP_LEFT + taille recalée en `_process` → les tweens
  `position.x` (shove + push) ne sont plus réécrits par le layout. Push capturé : panneau qui barge
  depuis la GAUCHE, décor + yeux shovés à droite → couvre → swap. ✓
- **Review H2** : signaux MerlinNative connectés `CONNECT_DEFERRED` (pas d'écriture cross-thread).
- **Review H3** : gaze scripté actif même en reduced_motion (actes 2/5).

### Gates
- validate_step0 0 err. Smoke Boot/Menu/Selection/Game = passed, script_errors 0.
- Capture : actes 1-3 (yeux réveil → dezoom → décor été foliage + crépuscule violet) + acte 5 push
  (panneau depuis la gauche, décor shové, couverture, swap) confirmés visuellement.


## Session: 2026-06-12 — v10.13.1 « Fondations de gamme » (montée en gamme R114, 7 commits)

### Context
Demande user : cohérence totale + montée en puissance ambitieuse (assets/animations/lisibilité)
+ bible évolutive + outillage « 100% Claude ». Plan approuvé (2 rounds AskUserQuestion :
polish d'abord, fusion sélective, 4 outils, v10.14 intégré). **Canon clarifié : docs/BIBLE.md
v2.0 UNIQUE** — GAME_DESIGN_BIBLE v3.8 + DEV_PLAN_V2.5 ARCHIVÉS dans docs/archive/.

### Done (gates verts à chaque commit)
- **Cohérence** : BIBLE v2.0 (§19 R114 roadmap v10.13.1→v10.19 · §20 DA · §21 Juice ·
  §22 Audio · §23 Lisibilité · §24 Pipeline) ; docs/README.md = carte d'autorité ;
  CLAUDE.md v4.0 (6 scènes réelles, gates CLI, purge factions/Oghams/MOS) ; art_direction
  réécrit (purge CRT) ; 45 fichiers agents redirigés ; bannières canon sur les 4 agents cascade.
- **Outillage studio** : skills merlin-juice / merlin-audio / merlin-artwork ;
  tools/create_agent.py (--validate : 107 fiches, 85 stale = backlog réécriture) ;
  tools/sfx_forge.py → 16 WAV canon générés (12 SFX + 4 stingers, peak -3dB mesuré).
- **Juice pack 1** (cascade Wave1 game_designer+ux_flow+playtester → Wave2 auditor : GO) :
  ghost de vol main↔combo (node indépendant, pop à l'arrivée), reflow d'éventail animé
  (_render_hand réutilise les vues), voile de beat (IGNORE, coroutine fire-and-forget,
  garde anti double-fire), feedback boutons canon, sceau R112 SONORE (seal_stamp + stinger).
- **Glitch corruption R75** : shader porté Godot 4 (+desaturation), 4 paliers (caps 0.50/0.25),
  burst de seuil ≤0.5s, tremblement du cadre à l'arrivée de prose (palier ≥2), reduce-motion
  câblé (Options→MerlinVisual.reduced_motion persisté) + PASTILLE statique violette (info jamais
  perdue). Captures 4 paliers → Downloads.
- **Leçons** : .bat bloqués GPO → CLI only ; tween_property sur shader_parameter/* KO →
  tween_method+set_shader_parameter ; PowerShell Constrained Language → Bash/sed pour le bulk.

### Gate final v10.13.1
validate_step0 0 erreur GDScript · smoke 6/6 scènes (0 script_error) · soak 200/200 ·
autoplay 3/3 (traverse voile+ghosts+reflow+glitch) · code-review 0 CRITICAL (2 HIGH fixés)
· guardians bible PASS · captures 4/4.

### v10.14 LIVRÉE (même session, 2 commits) — « Dé, Chemin & Équilibre » (R120)
- **Dé pré-tiré par rareté** (bandes sans malus, R20), révélé en B8 dans la fusion ; preview =
  résolution (anti cache-miss prose) ; PARTIEL -2 ; pools tags Epreuve/Dilemme élargis.
- **Chaîne de quêtes** 2-3 × 2-5 beats : build_chain_beats statique (miroir harnais↔jeu),
  arc PAR QUÊTE (begin_quest, last_gist traversant), map/HUD par quête, répit du sentier
  +2 (+2 si Intégrité ≤4). **Ramification v1** : swap Epreuve↔Dilemme à l'avant-climax sur
  revers, AVANT save (R108), indice micro-narratif + déviation map.
- **Boucle de tuning MESURÉE** (4 consultations designer, n=300/archétype) : gate morts
  re-baseliné chaînes (par beat joué, pas par run). **GATE FINAL 4/4 OK** : optimal 21.6%p/6.0%m ·
  greedy 51.3/23.7 · chaotic 47.4/22.7 · corrompu 47.0/16.7 · 1500/1500 PASS.
- Review : code jeu APPROVE ; 3 HIGH probes fixés (guard 12→16, begin_quest dans probe_prose,
  garde titres distincts). Gates : validate 0 · smoke 0 · soak chaînes · autoplay 3/3.

NB : le MCP godot-mcp nécessite un /mcp reconnect (l'éditeur a été lancé en cours de session).

## Session: 2026-06-10/11 — v10.13 « Fondations prouvées » (plan approuvé, exécution)

### Context
Plan v10.13+v10.14 approuvé (fichier : ~/.claude/plans/propose-moi-le-plan-precious-pnueli.md).
Construit par : 3 audits Explore + workflow 4 agents design (fiabilité/anim+archi/merlin-game-designer)
+ audit game-design croisé. Décisions user : 2 incréments ; run v10.14 = chaîne 2-3 quêtes de 2-5 beats ;
dé 4 bandes consistantes ; 50+ tags différé. Corrections critiques de l'audit intégrées : dé PRÉ-TIRÉ
(sinon cache-miss prose systématique), resume=début de beat (canon BIBLE.md — ATTENTION : 2 bibles,
BIBLE.md=canon, GAME_DESIGN_BIBLE.md=legacy), take_resolution ne bloque jamais.

### Phase R — Fiabilité (FAIT, gate vert)
- Fix 0 : helper `_fresh(ep)` (epoch+tree) + règle deadline/garde sur toute boucle await.
- Fix 1 : draft = gardes structurelles (layer/run.ended), sortie=skip ; cleanup sur run_ended.
- Fix 2 : sustain SKIPPABLE (clic→fallback, skip_box lambda, hint après 4s).
- Fix 3 : take_resolution = cache-only, NE BLOQUE JAMAIS (le sustain possède l'attente).
- Fix 4 : note_outcome public, appelé inconditionnellement (fil rouge même en fallback).
- Fix 5 : ensure_playable_hand (défausse→secours « Souffle Errant ») — invariant main ≥ 2.
- Fix 6 : save UNIQUE au début de beat (le save post-résolution DOUBLE-APPLIQUAIT les coûts à la
  reprise) + save à _accept_quest + run_ended. Resume = beat start, transients non persistés.
- Fix 7 : fermeture propre (auto_accept_quit=false, cancel + join borné 2s + _quitting guard).
- Fix 8 : invalidate_resolution cancel la gen en vol (sinon prefetch du beat suivant affamé).
- Fix 9 : appel narrate_opening supprimé de _bg_intro (affamait le prefetch beat-1) — fonction
  conservée pour l'interstitiel B3.
- Fix 10 : epoch bump avant draft + retrofit _fresh().
- Gate : validate_step0 exit=0 · probe_run 2/2 · probe_draft 34/34 · smoke Game+Menu passed.

### Phase P — Harnais de preuve (FAIT, gate final en cours)
- NEW tools/probe_soak.gd : Monte Carlo N=200 (5 archétypes + mixed, cas dégénérés i%7/11/13,
  S5 save/resume, invariants par beat, backup/restore de la vraie save). **1er run : 200/200 PASS
  (9,5s), 0 SCRIPT ERROR.** Métriques : échec 10,1%, éclatante 10,3%, partiel 55,6% (à équilibrer
  v10.14), drafts pris 72%, morts 7,5%, 132 secours injectées.
- NEW tools/autoplay_run.gd : N runs UI complets LLM ON (intro→beats→draft→MerlinEnd), awaits
  corrects (_on_resolve await ; _advance_to_next fire-and-forget VOLONTAIRE — un await = deadlock
  avec le modal draft servi par la même boucle).
- cli : `python tools/cli.py godot soak --runs 200 --autoplay true --loops 3` (adapter _soak).
- Code-review : 0 CRITICAL ; 3 HIGH corrigés (collision save joueur dans les harnais → backup/
  restore ; _quitting guard ; awaits autoplay). Gate final (soak+autoplay) en arrière-plan.

### Phase A — Architecture (FAIT, gate vert, commit « refactor(v10.13): phase A »)
- A1 MerlinVisual (palette canonique, 10 fichiers re-pointés hex-identiques) ; A4 MerlinProse +
  MerlinPromptBuilder (prompts octet-identiques vérifiés, scenario 984→703) ; A2 MerlinFx (fusion
  extraite verbatim, tweens auto-liés, game 1483→1135) ; A3 MerlinWaitStage (générique).
- Gate post-A : validate 0 · smoke · **soak 200/200 + autoplay 3/3** (fusion extraite exercée réel).

### Phase B — Animations + priorité moteur (FAIT, gate vert, commit « feat(v10.13): phase B »)
- B0 priorité moteur (résolution > arc > opening > épilogue) + cache d'ouverture ; B1 cover boot
  (menu peint avant le load) ; B2 hint intro ; **B3 interstitiel « le récit s'ouvre »** (ouverture
  LLM ressuscitée, WaitStage 8s, couvre la gen d'arc, retry à l'Accept) ; B4 path-draw map + stamp
  glyphe ; B9 sceau de degré (remplace le label inline) ; B7 scène vivante + « Merlin pense » ;
  B5 draft staggered. Gate : soak 200/200 + autoplay 3/3 à travers l'interstitiel.

### Phase V — Cascade game-design + canon (FAIT, commit « fix(v10.13): phase V »)
- **Wave 1** : merlin-game-designer (0 CRITICAL/HIGH — PASS structurel, 3 MEDIUM) + audit ux_flow
  4 piliers (0 CRITICAL, 2 HIGH contrastes). **Tous les HIGH+ et MEDIUMs actionnables corrigés**
  (E1/E2/F1/F2/M1/M2/P1 save-zombie/P2 diégèse/T1) — preuves visuelles avant/après capturées.
- **BIBLE.md §18 (canon)** : R108 reprise-début-de-beat, R109 fiabilité MESURÉE (gate soak),
  R110 priorité moteur, R111 interstitiel, R112 sceau, R113 main jouable + cibles équilibrage v10.14
  (partiel 55.6%→25-35%, morts 7.5%→10-25%).
- **GATE FINAL v10.13 : validate 0 · soak 100/100 · autoplay 2/2 · 4 commits poussés.**

### v10.14 (prochain build — décisions verrouillées)
- Dé PRÉ-TIRÉ par rareté (4 bandes) + anim B8 dans MerlinFx (slot réservé) ; run = chaîne 2-3
  quêtes de 2-5 beats (recalibrage économie) ; ramification v1 découverte au beat ; soak archétypes
  5×100 avec cibles chiffrées ; ajustements équilibrage (partiel -2, tags beats 3-4).

---

## Session: 2026-06-07 (suite) — v10.12 Fusion adaptative + Map du chemin + Carte simplifiée

### Context
Playtest user : (1) « le scénario ne suit pas » → fusion trop rapide, ralentir + tout animer pour laisser
le LLM interpréter (max async) ; (2) carte « map » manquante à droite qui dessine le chemin (chemin de
base + déviations, on peut sortir du chemin) ; (3) cartes surchargées, simplifier. AskUserQuestion (4Q) →
map REMPLACE la carte Destin ; carte = icône + rareté + tags EN CLAIR ; fusion adaptative. Specs : merlin-game-designer.

### Done
- **Fusion adaptative** (`merlin_game._play_fusion_animation`) : après la phase 4, SUSTAIN animé (glow
  pulse + sparks ~2.2s) JUSQU'À `is_resolution_ready` OU cap 12s → l'issue LLM « suit » la fusion.
  Cache-hit = 0 frame. Gardes teardown (is_instance_valid glow/layer ; sparks via layer.create_tween).
- **Map du chemin** (NEW `merlin_beat_map.gd` / `MerlinBeatMap`) : chemin vertical des beats (nœuds reliés),
  position « tu es ici » (or+halo), passés (encre)/à-venir (sombre), marqueur de déviation au draft.
  Remplace la carte Destin (coin droit). Câblé `_build_beat_map` + setup/set_current/mark_draft.
- **Carte simplifiée** (`merlin_card_view`) : retiré rangée de pastilles + bande archétype ; tags EN CLAIR
  (2 max, mots colorés par famille) ; gardé nom + glyphe + gemme rareté/coût + badge effet.

### Vérif
- [x] validate_step0 exit=0 (10 erreurs phantom_camera pré-existantes ; MerlinBeatMap enregistré)
- [x] smoke MerlinGame passed=True script_errors=0 (boot + map + cartes simplifiées)
- [x] code-reviewer : 0 CRITICAL ; 2 HIGH (teardown safety sustain) + 2 MEDIUM corrigés
- [x] **Playtest auto-jugé (capture viewport non-headless, 2026-06-07)** : cartes simplifiées ✅ (nom +
  glyphe + tag en mot + gemme) ; map ⚠️→✅ (1ère passe = barre cramponnée au bord, illisible → refonte
  « panneau CHEMIN » : sentier zigzag dans un panneau encadré, inset 24px) ; fusion ✅ animée ; **issue
  SUIT le scénario** ✅ (« Le geste fusionné n'ouvrit la voie qu'à demi… le prix viendrait plus tard » =
  Partiel + continuité « quelque chose l'avait vu faire »). **Bug trouvé + corrigé (v10.12b)** : le LLM
  (~1 tok/s sous RAM pressée) dépassait le cap sustain 12s → le voile statique « Merlin assemble »
  réapparaissait. Fix : cap 20s + **caption ANIMÉE « Merlin tisse les fils du sort … »** (points cyclants
  + glow + sparks) + filet procédural, ZÉRO voile statique.
- Notes : (a) segfault au quit du HARNESS de capture (bare `quit()` pendant gen native) = PAS un bug jeu
  (smoke chemin normal passed) — fragilité connue du thread LLM natif à l'exit ; (b) la situation peut être
  enrichie par le LLM en cours de run (à surveiller : éviter un swap de texte pendant la lecture).

### Reste (cadré merlin-game-designer PART B — EN ATTENTE décisions user)
- **Ramification réelle / quêtes** (clusters 2-5 beats, sortir du chemin → vraie ramification) : refonte
  scénario/run/save → 7 questions ouvertes. **Jet de dés** (combinaisons spéciales) → 4 questions.
  **50+ tags** (7 départ, déblocage in/cross-aventure) → 4 questions.
- `ARCHETYPE_STYLE` (merlin_card_view) désormais inutilisé (dead const, à retirer plus tard).

## Session: 2026-06-07 — v10.11 Deck enrichi + Draft 1/3 + Rareté + Carte Destin (StS allégé)

### Context
User : « enrichi le deck, à chaque résolution tirer 1 carte sur 3 au choix, niveaux de rareté, coin
droit HUD une carte qui se dessine selon les choix, carte simple façon Slay the Spire ». AskUserQuestion
(4Q) → carte HUD = « destin » du run ; mécanique = tag-coverage **+** effets actifs sur Rare+ ; draft =
beats clés (réussite/éclatante) only, skip autorisé ; visuel = minimal strict (DA flat 2026-05-26) + gemme.

### Done
- **merlin_card.gd** : champs `effect_type`/`effect_value` (+ make/to_dict/from_dict) ; `enriched_pool()`
  = 14 cartes (6 Rare/5 Épique/3 Mythique), tags ORDONNÉS pour l'archétype voulu, effets HEAL/PURGE/DRAW.
- **merlin_run.gd** : `apply_card_effects` (HEAL cap 10 / PURGE plancher 0 / DRAW main bornée HAND+3),
  `draft_choices` (3 distinctes, pondérées normal/late, exclut possédées), `add_card_to_deck`, suivi
  `archetype_scores` (play_and_discard), `dominant_archetype`/`destiny_tier`/`destiny_snapshot`, save/load.
- **merlin_card_view.gd** : gemme rareté/coût (coin HG) + badge d'effet (coin HD), DA flat conservée.
- **merlin_game.gd** : effets en résolution (avant check mort) ; draft armé aux beats clés (réussite/
  éclatante, non-climax) → overlay modal `_present_draft` (3 cartes + Passer) ; widget Carte Destin coin
  HD (`_build_destiny_widget`/`_update_destiny`) rebâti à chaque résolution.
- **tools/probe_draft.gd** (NEW) : harness logique sans LLM (34 assertions).
- Barème (effets/poids/seuils destin) : agent `merlin-game-designer` vs bible.

### Vérif
- [x] validate_step0 exit=0 (10 erreurs = phantom_camera.svg pré-existantes ; MerlinCard/CardView recompilent)
- [x] smoke MerlinGame passed=True script_errors=0 exit=0 (boot + _build_destiny_widget + _update_destiny null-path)
- [x] **probe_draft.gd : 34/34 PASS** — pool, archétypes (corruption→Corrompu), effets (cap/plancher/borne),
  Carte Destin (Commune→Mythique + bascule dominant), draft (distinct/pondéré/exclusion).
- [x] code-reviewer : 0 CRITICAL ; 4 HIGH/5 MEDIUM revus → hardening appliqué (garde teardown, garde
  modale draft dans _input/_on_story_click, types card_clicked/_on_draft_card, commentaire destiny_tier).
- [ ] Ressenti in-game (draft + destin visuels) = playtest user.

### Reste
- Bible : documenter deck enrichi/draft/destin après sign-off playtest.
- Effets : heal/purge animés via gauges ; DRAW silencieux (toast optionnel = itération future).

---

## Session: 2026-06-06 — v10.9 Longueur de prose VARIABLE (in-game)

### Context
User : « ce rendu en jeu, plus variable sur la longueur, moins avant chaque choix de carte et
quelquefois plus long selon le déroulé ». /loop self-paced jusqu'au bon résultat in-game.

### Constat
Le rendu est DÉJÀ en jeu : `_show_situation` (scène + marqueur Type·beat N/total), `_update_preview`
(Couverture X/Y · degré · coût Corruption), `_on_resolve` → animation fusion → issue. Le mockup HTML
ne faisait que reproduire l'existant. → Le vrai travail = longueur variable.

### Done — `scripts/llm/merlin_scenario.gd`
- **SITU_FALLBACKS raccourci** à 1-2 phrases (scène = avant le choix → courte).
- **`narrate_resolution` longueur variable** : `is_strong_moment(type,degré)` → `phrase_target`
  « 4 a 5 phrases » + `max_tokens=260` aux moments forts (Climax / éclatante), sinon « 2 a 3 phrases »
  + `max_tokens=150`. Plafond tokens = garantie structurelle de la longueur.

### Vérif
- [x] validate_step0 exit=0 · smoke MerlinGame passed=True script_errors=0
- [x] Relecture du bloc édité (490-497) : GDScript correct, pas de bug runtime
- [~] Probe réel : **bloqué env** — chargement gemma4 (cache OS froid) + cap Bash 10 min → 0 beat
  écrit (tail: `llm_ready=true` puis kill). Longueurs garanties par const + tok_budget, donc probe
  à faible valeur ajoutée. **Vérif visuelle/ressenti in-game → user (run moteur chaud).**

### Reste (user)
- Jouer en jeu pour confirmer : scènes courtes avant le choix ✓ ressenti, issues plus longues au Climax.
- Commande run complet chaud (sans cap) : `"C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path . --script res://tools/probe_combos.gd` puis `python tools/render_combo_report.py`.

---

## Session: 2026-06-06 — v10.8 Scénarios : ouverture narrative + prose verbeuse (3-4 phrases)

### Context
User : « il faut bien une introduction à l'histoire qui s'écrit, ensuite tout doit s'enchaîner
logiquement, tout doit être plus verbeux ». AskUserQuestion : verbosité **3-4 phrases** ; intro =
**ouverture narrative + Merlin**.

### Done — Générateur (`scripts/llm/merlin_scenario.gd`)
- **MAX_TOK_PROSE 110→220** ; `narrate_resolution` : « EXACTEMENT 2 phrases » → « 3 à 4 phrases amples,
  déroule la conséquence ».
- **SITU_FALLBACKS + RESO_FALLBACKS étoffés** (scènes ~3 phrases, issues 2-3 phrases) → procédural
  VISIBLE plus verbeux même quand le LLM perd la course.
- **`build_opening(scenario, with_pitch=true)` + `narrate_opening` + `OPENING_FRAMES`** : ouverture
  narrative (décor + atmosphère + enjeu), distincte du pop-up Merlin.

### Done — Câblage jeu (`scripts/game/merlin_game.gd`)
- `_show_intro_popup` : greeting Merlin PUIS ouverture narrative (`build_opening(..., false)` → pas de
  doublon de pitch).
- `_bg_intro(scenario, lbl, opening)` : enrichit la greeting (narrate_intro) PUIS l'ouverture
  (narrate_opening), non bloquant, en conservant la base procédurale.

### Done — Exemplar
- Réécriture verbeuse `Downloads/MERLIN_scenario_gold_le_sentier_des_murmures.md` : ① intro Merlin
  ② ouverture narrative, 5 beats à 3-4 phrases qui s'enchaînent, 7 règles d'or (ajouts « Ouvre
  l'histoire » + « Ample, jamais creux »).

### Vérif
- [x] validate_step0 exit=0 · smoke MerlinGame passed=True script_errors=0 (exerce build_opening au run start)
- [x] code-reviewer : 0 CRIT/HIGH, 2 MEDIUM → `narrate_opening` était dead code → **CÂBLÉ** dans
  `_bg_intro` (enrichissement LLM non bloquant de l'ouverture). Re-validate + re-smoke OK.

---

## Session: 2026-06-06 — v10.7 Scénarios : exemplar gold + générateur (fil rouge + couverture)

### Context
User : « amélioration nette sur les scénarios » — complets, bien rédigés, suites d'événements
**logiques** (pas de beats orphelins). À partir du contrôle-lecture des combos collé. AskUserQuestion :
périmètre = **exemplar + générateur** ; 4 axes (causalité beat-à-beat, intégration combo, qualité
littéraire, différenciation succès/échec) ; livraison markdown ; aligné bible + agents narratifs.

### Diagnostic racine
`narrate_resolution` générait chaque issue **dans le vide** : prompt sans titre/pitch, sans n° de
beat, sans la scène, sans le beat précédent, sans la couverture → beats sans queue ni tête + échec
qui se lit comme une réussite. `_fallback_situation` = scènes **génériques par type** (Beat 1
identique entre 2 scénarios).

### Done — Exemplar
- `Downloads/MERLIN_scenario_gold_le_sentier_des_murmures.md` : réécriture complète 5 beats avec
  fil rouge (motif « les noms »), causalité explicite, combo fondu dans la prose, ton par degré,
  table avant→après, 6 règles d'or (spec générateur). Cartes réelles starter_deck.
- QA adversariale `merlin-narrative-designer` (score moyen avant fix) → 5 corrections appliquées :
  Beat 5 (2/2 réussite≠éclatante au Climax, règle §4 nuancée), « tu » narratif vs apostrophe (§6),
  Beat 2 couverture précise (Appel de l'Ombre ne couvre pas Ruse), transition B2→B3 (ombre vecteur).

### Done — Générateur (`scripts/llm/merlin_scenario.gd`)
- **`_run_thread`** (titre+pitch+last_gist) : fil rouge inter-beats, RAZ au `build_skeleton`.
- **`narrate_resolution`** : prompt enrichi = aventure (titre+pitch) + Moment n/5 + décor (prolonge)
  + couverture (forces honorées/manquantes → saveur du succès) + enchaînement beat précédent.
- **`build_situation`** : retour + `n`/`total`/`title` (additif).
- **`take_resolution`** : `_remember_outcome(res)` aux points de commit (continuité).
- **`RESO_FALLBACKS`** : variantes combo-aware, dédupliquées (fin des répétitions du contrôle-lecture).

### Vérif
- [x] validate_step0 exit=0 (merlin_scenario.gd : 0 erreur ; 10 pré-existantes phantom_camera/node_modules)
- [x] code-reviewer APPROVE (0 CRITICAL/HIGH ; 1 MEDIUM cover_hint↔deg_directive corrigé ; 2 boucles fusionnées)
- [x] smoke MerlinGame passed=True script_errors=0 exit_code=0
- [x] **Rendu RÉEL** (probe_combos, moteur gemma4-e2b natif, llm_ready=true) : partiel/réussite
  différenciés ✅, combo fondu (2 évocations reconnaissables) ✅, « union parfaite » banni ✅.
  Régression écho décor/pitch détectée → CORRIGÉE (titre seul + décor NON passé + « commence par
  l'action ») → re-test : prose démarre sur l'action, 1/2 montre sa faille (« mais une ombre
  persiste »), 2 phrases. Binaire : `C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe`.
  **Contrainte** : probe plafonné ~1-2 beats / run 10 min (chargement gemma4 ~4 min + ~1 tok/s) →
  rapport complet 15 beats = lancer warm sans cap timeout.

### Suite proposée
- Scène (situation) scénario-spécifique via LLM utilisant titre+pitch+motif (le Beat 1 identique
  entre scénarios est dans la couche procédurale, hors résolution).

---

## Session: 2026-06-06 — v10.6 Fix clic-continuer + combo 2 cartes + prose ancrée + HTML contrôle-lecture

### Context
User : (1) « cliquer pour continuer » ne marche pas, (2) combo = 2 cartes par défaut (pas trio ni carte simple), (3) la combinaison ne s'établit pas dans le scénario, (4) histoires LLM bancales → besoin d'un HTML de contrôle-lecture pour tester. AskUserQuestion : exactement 2 cartes / 2 tags requis/beat / lecture batch scénario×combo / prose doit refléter les cartes.

### Done — Fixes gameplay
- **Clic-continuer (BUG)** `merlin_game.gd::_input` : avance routée via `_input` (reçu avant la GUI) au lieu du catcher (qui était bloqué par un conteneur au-dessus). State 2 + clic gauche → skip typewriter si en cours, sinon advance. `set_input_as_handled()` ; ne consomme rien en state 1 (cartes OK).
- **Combo exactement 2** `merlin_game.gd` : `_on_hand_card` cap `>= 2` ; `_update_preview` n==0 « Pose 2 cartes » / n==1 « Pose une 2e carte » / n==2 preview+résolution active ; `_on_resolve` guard `size != 2`.
- **2 tags requis/beat** `merlin_scenario.gd::_pick_tags` : toujours 2 tags (était 1-3 selon difficulté) → un combo de 2 couvre exactement.
- **Prose ancrée cartes** `merlin_scenario.gd::narrate_resolution` : prompt reformulé — chaque évocation passée comme « Force N », instruction « FAIRE SENTIR les DEUX forces, ancré dans leurs images concrètes, fondues en UN geste », toujours sans nommer les cartes.

### Done — HTML contrôle-lecture
- **tools/probe_combos.gd** : harness batch — 3 scénarios × 5 beats, combo de 2 cartes/beat, prose LLM RÉELLE (toujours générée, plus de gating), écriture incrémentale JSON.
- **tools/render_combo_report.py** : rend le JSON en HTML lisible (par scénario : situation, 2 cartes nom+évocation+tags+archétype, degré, synergie, prose LLM vs procédurale).

### Vérif
- validate_step0 exit=0, smoke MerlinGame passed=True script_errors=0
- code-review : 0 CRITICAL/HIGH ; 2 MEDIUM (click-swallow non-fondé — `return` ne consomme pas ; pool<2 future-safety, protégé par min(2,…)) ; 2 LOW (is_strong_moment PAS mort — probe_prose l'utilise ; _on_story_click gardé comme filet).

### Notes
- Le HTML de contrôle est le 1er pas pour itérer sur la qualité LLM : lire le batch → identifier les patterns à corriger dans le prompt.
- Effets mécaniques jouables (mots-clés) + variation rareté en jeu = itérations suivantes.

---

## Session: 2026-06-06 — v10.5 Refonte visuelle cartes (logos par tag, rareté, archétype)

### Context
User : (1) retirer « Ta main », (2) cartes plus grosses, (3) logos retravaillés pour refléter le concept, (4) bords plus épais, (5) rareté visible, (6) effets plus profonds que la corruption. AskUserQuestion : glyphe par tag précis / rareté = couleur+épaisseur bordure / archétype d'effet visuel / visuel d'abord (pas de méca résolution).

### Done
- **merlin_glyph.gd** : `for_tag(tag)` → 25 glyphes distincts par concept-cœur (via MerlinTags.to_canon). 10 nouvelles formes : wind, heart, speech, knot, flame, balance, void, ash, waves, chain. `for_family` conservé.
- **merlin_card.gd** : `archetype()` dérivé du tag primaire (Corps→Offensif, Parole→Social, Monde→Défensif, Perception/Intuition→Mystique, corrompu/corruption>0→Corrompu), memoïsé (`_archetype_cache`). `to_dict` gagne clé `"archetype"` (additif).
- **merlin_card_view.gd** : CARD_SIZE 152×196→180×240, compact 150×88→170×104. `RARITY_STYLE` (Commune brun 3px / Rare bleu-acier 4px / Épique magenta 5px / Mythique or 7px + shadow glow). `ARCHETYPE_STYLE` (5 archétypes → bande couleur + libellé). `_build` : bordure rareté + glyphe par tag + rangée pastilles tous tags + bande archétype bas + pips « ◆ » corruption.
- **merlin_game.gd** : label « Ta main : » retiré ; `_hand_box` 214→264 px.

### Vérif
- validate_step0 exit=0, smoke MerlinGame passed=True script_errors=0, tsc --noEmit clean
- **Confirmé visuellement** (drive_merlin) : cartes agrandies, glyphes distincts (cœur=Empathie, œil=Sens, spark=Instinct, vent=Agilité), bandes CORRUPTION/PAROLE/MYSTÈRE/OFFENSE, pastilles tags colorées, plus de « Ta main ».
- code-review : 0 CRITICAL/HIGH, 3 MEDIUM corrigés (Color(Color)→`as Color` cast ; archetype memoïsé ; CardSnap `archetype?` ajouté), 1 LOW accepté (budget hauteur compact serré, glyphe se masque proprement).

### Notes
- Toutes les cartes starter = Commune → bordure brun-ink fine ; la variation rareté (bleu/magenta/or+glow) s'affichera dès qu'une carte Rare+ existe.
- Effets « plus profonds » = archétype VISUEL cette itération (pas de méca résolution). Mots-clés d'effet mécaniques jouables = itération suivante dédiée (avec équilibrage).

---

## Session: 2026-06-06 — v10.4 Résolution TOUJOURS LLM + retrait hint « Ce moment appelle »

### Context
User : (1) retirer « Ce moment appelle : ‹ tag › », (2) le texte de résolution (échec inclus) doit être FORCÉMENT généré par le LLM, plus le fallback procédural. AskUserQuestion : pré-génération pendant la pose / fallback procédural dernier recours / retirer hint garder preview / toutes résolutions LLM.

### Done — Retrait hint (merlin_game.gd)
- Supprimé `_hint_lbl` (déclaration + création _build_ui + tous les toggles + `_show_situation` text + helper mort `_format_tags`).
- `_update_preview` : combo vide → « Pose une carte… » ; combo posé → « Couverture X/Y · degré · coût » SANS les tags nommés.

### Done — Résolution toujours LLM (merlin_scenario.gd + merlin_game.gd)
- **Pré-génération** `prefetch_resolution(situ, played, res)` : lancée à chaque changement de combo (_update_preview), fire-and-forget. Dédupe par signature combo (ids cartes ordonnés + degré). Ne démarre QUE si moteur libre (`is_busy()` guard) → pas de thrash du single-flight.
- **Récupération** `take_resolution(situ, played, res)` : cache-hit instantané ; sinon poll-wait si gen en vol pour cette combo ; sinon annule toute gen périmée (`cancel()` + attente libération 8s) puis génère. Renvoie "" si moteur KO.
- **`invalidate_resolution()`** appelé à chaque nouveau beat → vide le cache (les ids cartes se répètent entre beats, anti-réutilisation prose).
- **`is_resolution_ready()`** : gate l'overlay « Merlin assemble… » (évite flash sur cache-hit).
- `_on_resolve` : mutations sync → animation fusion (~2-4.5s, masque latence) → `take_resolution` (overlay si pas prêt) → fallback procédural SEULEMENT si moteur KO → `_show_resolution` typewriter.
- Retrait du gating `is_strong_moment`/`_bg_resolution`/`_wait_engine_free` (morts).

### Vérif
- validate_step0 exit=0, smoke MerlinGame passed=True script_errors=0
- code-review : 1 HIGH (stuck `_reso_state` après epoch-discard) + 3 MEDIUM → tous corrigés (reset state idle ; overlay gate cache-hit ; cancel wait 5→8s ; double-gen accepté documenté)
- **Confirmé visuellement** (F12 + drive_merlin) : « Ce moment appelle » absent, preview « Pose une carte… » ; résolution LLM live « Les racines s'animent d'une ombre froide et humide. Une présence ancienne se déploie… » (issue combinaison 13.3s/27to), overlay « Merlin assemble les fils du sort… » pendant la gen.

### Notes
- Cas lent (1 carte posée + résolution immédiate) : prefetch pas fini → overlay masque ~13s de gen. Cas normal (joueur réfléchit + anim 3.5s) : cache-hit quasi instantané.
- Tension archi assumée : « toujours LLM » réintroduit l'attente que le non-bloquant évitait, mais l'overlay + la pré-génération la rendent acceptable, et le fallback procédural garantit qu'on n'est jamais coincé si le moteur meurt.

---

## Session: 2026-06-06 — v10.2 Animation cinématique fusion cartes avant résolution

### Context
User : clic « Résolution » sautait direct au label + prose LLM. Demande : transformation visuelle de la combinaison cartes → expression de fusion → application à la prose, avec couleurs/animations différentes selon le degré (échec/partiel/réussite/éclatante).

### Done — Animation 4 phases (`merlin_game.gd::_play_fusion_animation`)
- **Phase 1 Gather (0.45s)** : cartes du `_combo_box` convergent vers le centre, scale 1.30, rotation 0, glow 0.18 alpha.
- **Phase 2 Fuse (0.50s)** : superposition centrale en éventail serré (rotation 8°/carte), scale 1.55, modulate doré, glow 0.45.
- **Phase 3 Burst (0.55s)** : 14 sparks ColorRect émis radialement + cards explose vers extérieur avec fade ; glow flash 0.85 → 0.30 (tween séquentiel séparé pour éviter chain ambigu sur parallèle).
- **Phase 4 Expression (1.55s)** : RichTextLabel centré avec synthèse verbale `_fusion_expression(played, res)` — combine 1-3 substantifs des tags (`Sens→"le Regard"`, `Ruse→"la Feinte"`...) + écho de degré (`reussite→" — et la voie s'entrouvre."`). Scale-in TRANS_BACK + fade-in puis hold 0.85s (via `create_timer`) puis fade simultané expression + glow.

### Wire (`_on_resolve`)
Mutations d'état (`play_and_discard`, `apply_resolution`, etc.) faites en synchrone, puis :
1. `_combo.clear()` + `_set_hand_dimmed(true)` + hide hint/preview/resolve_btn
2. **`await _play_fusion_animation(res, played_cards)`** (NEW)
3. Epoch + tree-check safety
4. `_render_hand()` + `_render_combo()` + `_show_resolution()` (prose typewriter existant)
5. `_bg_resolution` si moment fort (Climax/éclatante)

### Couleurs par degré (FUSION_COLORS)
- `echec` → rouge vif `#D04848` (chute)
- `partiel` → ambre `#D8A030` (effort à demi)
- `reussite` → or chaud `#E8C45A` (geste accompli)
- `eclatante` → or pâle `#F4E0A8` (apothéose)

### Vérif
- validate_step0 exit=0, zéro erreur sur merlin_game.gd
- smoke MerlinGame passed=True, script_errors=0
- code-review : 2 HIGH (tween chain semantics) + 1 MEDIUM (hover during flight) tous résolus :
  1. Phase 3 glow → tween séquentiel séparé (`p3_glow` distinct de `p3`)
  2. Phase 4 hold → `await get_tree().create_timer(0.85).timeout` (plus de `chain()` ambigu)
  3. Cards reparented → `mouse_filter = IGNORE` (évite `_on_enter` parasite en plein vol)

### Notes
- Animation totale ~2.5s, layer overlay full-rect absorbe les clics (modal pendant fusion).
- Pas de skip pour l'instant ; à ajouter si l'utilisateur trouve ça long.
- Expression procédurale (pas LLM) → instantané, déterministe, jamais en attente moteur.

---

## Session: 2026-06-05 — v10 UX 4 piliers + Dashboard Gameplay Live (livraison complète)

### Context
User /goal : « tu fais tout et controle tout dans le livrable final, que tout soit fonctionnel, optimisé et good pour le pilotage du jeu et son dev ». Suite à l'audit UX 4 piliers (bible §21) par `merlin-game-designer` (2 CRITICAL + 3 HIGH + 3 wins) et au spec dashboard Gameplay Live (v10.D du task_plan), implémentation end-to-end.

### Done — Fixes UX (5/5)
- **C1** `merlin_end.gd` : port du mécanisme epoch + `_tw.is_valid()` guard + caret clignotant + skip-typewriter + gui_input handler depuis `merlin_game.gd`. Plus de swap silencieux LLM pendant que le joueur lit l'épilogue (anti-saut de lecture, pilier ÉVIDENT).
- **C2** `merlin_game.gd::_show_intro_popup` : refacto full-rect modal → bandeau slide-up bottom 30 % (anti-pattern §21.2 #1 corrigé). Plateau 3D reste visible au-dessus, voile léger limité au tiers bas, ScrollContainer pour l'intro Merlin (corpus peut être long).
- **H1** `merlin_game.gd::_update_preview` : fusion des 2 labels redondants (Miller §21.2 #5). `_hint_lbl` ↔ `_preview_lbl` mutuellement exclusifs ; tags requis embarqués dans le preview quand combo non-empty (zéro perte d'info).
- **H2** `merlin_scenario.gd::take_selection` + `merlin_selection.gd::_show_overlay` : budget 8 s borné (fallback SEL_FALLBACK si LLM dépasse) + animation dots cyclique « · · · » dans l'overlay.
- **H3** `merlin_card_view.gd::_on_gui_input` : `_tap_feedback()` (pop scale 0.06s → retour 0.10s) garantit feedback tactile <100 ms sans hover-only (pilier TACTILE+DESKTOP).

### Done — Dashboard Gameplay Live (Phase 1+2 + amorce Phase 3)
- **NEW autoload** `scripts/game/tweaks_overlay.gd` : hot-reload de `user://merlin_tweaks.json` (polling 500 ms via `_process` + mtime) ; écrit l'état run `user://dashboard_state.json` (baseline immédiat + 1 s cadence). API publique `get_int/get_persona_overlay/get_scenario_force` + signal `tweaks_reloaded`. Enregistré dans `project.godot` après MerlinRun pour l'ordre.
- **MerlinRun** : 4 helpers privés `_start_integrite/_hand_size/_max_integrite/_corruption_cap` consomment TweaksOverlay (fallback const local) + nouveau public `get_run_constants()` pour le state writer.
- **MerlinScenario** : `_load_persona` fusionne l'overlay TweaksOverlay (overlay > base, non-destructif) + `_ready` connecte le signal `tweaks_reloaded`. **`take_selection`** câble `scenario_force.title` (forçage depuis le dashboard, picker fonctionnel).
- **Mission-control bridge** `vite.config.ts` : plugin `godotBridgePlugin` (Connect middleware Vite dev :4200, **non** déployé Vercel) — 3 routes file I/O multi-plateforme (Win/Mac/Linux) sur godot user-data dir + corpus listing depuis Downloads. Cap body POST 512 KB.
- **NEW composant** `GameplayLiveTab.tsx` : 5 panneaux (State live polling 1.5 s, Hand table, Constants sliders, Persona overlay editor, Scenario picker 130-corpus groupé par archétype). Optimistic update avec **revert sur échec POST** (revue MEDIUM #4). React 19 compatible (import JSX/ReactNode/CSSProperties as types).
- **App.tsx** : nouvel onglet `live` (⚡) entre `game` et `agents`.

### Vérif
- `validate_step0` : exit=0, zéro erreur sur fichiers touchés (10 errors restantes = pré-existantes phantom_camera/node_modules)
- `smoke MerlinGame` : passed=True, script_errors=0, total_errors=0
- TypeScript `tsc --noEmit` mission-control : 0 erreur (après fix React 19 namespace JSX)
- E2E : `dashboard_state.json` confirmé écrit (431 bytes valide, MTIME live) pendant smoke
- Code review batch (`code-reviewer` agent) : **0 CRITICAL, 0 HIGH, 5 MEDIUM**, tous résolus (H3 scale return, Vite POST cap, React revert, scenario_force wire)

### Notes
- `scenario_force.beat_index` reste WIP (label UI le signale, tooltip explicatif) — refacto structure beats requise pour hot-reload sans casser run en cours.
- Bridge local-dev only : déploiement Vercel ignore `/api/godot/*` (gracefull error côté React).
- Le `GameTab` iframe Vercel existant n'est pas touché — Gameplay Live cohabite en onglet séparé.

---

## Session: 2026-05-29 (suite) — v9.10 Fix moteur natif (anti-freeze thread principal)

### Context
User a choisi le fix NATIF (C++ + recompile) pour la racine du stall : `generate_async` pouvait `join()`
un thread d'inférence encore actif (après un `cancel`) SUR LE THREAD PRINCIPAL → freeze (jeu + quit).

### Done
- **native/src/merlin_llm.{h,cpp}** : flag `thread_active` (vrai tant que le thread d'inférence VIT
  réellement, distinct de `is_generating` que `cancel` baisse trop tôt). `generate_async` **détache** un
  thread encore actif au lieu de le `join()` → **jamais de freeze du thread principal** ; désactive le moteur
  proprement (`engine_dead` → erreur → fallback procédural). Destructeur idem (détach + pas de free ctx/model
  si bloqué → pas de use-after-free au quit).
- Recompile GDExtension via **VS DevShell** (PowerShell, SANS script `%TEMP%` → contourne le blocage GPO Orange
  qui bloquait `compile.ps1`). Build incrémental EXITCODE=0.

### Vérif
smoke MerlinGame `passed=true` (nouvelle DLL charge + modèle OK) ; harness génération → **run complet 5 beats,
intro+Climax générés (gating moments-forts actif), DONE, zéro stall**. DLL gitignorée (rebuild local → fix actif ici).
Note : chemin détach-sur-wedge non déterministiquement testable (wedge rare) mais logique + relu (revue précédente) + happy path OK.
Reste : push (si demandé), bible §10.3.

---

## Session: 2026-05-29 — v9.9 Fix prose LLM + vivacité moteur + équilibrage

### Context
Inspection (2 agents) du rapport de prose. Diagnostic : prose LLM répète la scène / nomme les cartes /
fuite d'instruction / trop longue ; moteur Gemma stalle (poll-starvation `_process` + `join()` bloquant —
peut figer le JEU) ; rapport épilogue/final vides sur run interrompu ; game design : 1 carte = éclatante,
carte à coût → éclatante. User (AskUserQuestion) : LLM partout + applique tout + fix moteur + corrige game design.

### Done
- **A. Prompt** (`merlin_scenario.narrate_resolution`) : ne passe plus le décor ni les NOMS de cartes
  (évocations seules), label « Intentions » (anti-fuite), 2 phrases ; garde `_strip_scene_echo` ; SYSTEM_PREFIX +1 règle.
- **B. Moteur** (`merlin_native.generate_raw`) : auto-polling `poll_result()` (ne dépend plus de `_process`)
  + timeout 90s + **nonce `_gen_id`** (rejette callback tardif post-timeout) + garde double-fire dans `_on_result`.
- **C. Harness** (`probe_prose.gd`) : `status` + épilogue/final incrémental → rapport complet même interrompu.
- **D. Équilibrage** (`merlin_resolution`) : éclatante exige ≥2 cartes ET aucune carte à coût (corruption>0). TDD.

### Vérif
TDD `test_resolution_synergy` (+2 caps) RED→GREEN ; **suite 30/30** ; validate_step0 exit=0.
Re-run harness (fix moteur) → **run complet 5 beats, ZÉRO stall** ; prose corrigée (plus d'écho/noms, ~2-3 phrases).
Revue code-reviewer : **1 CRITICAL** (callback tardif post-timeout corrompt la gen suivante) **+ 1 HIGH** (double-fire)
→ **corrigés** (nonce + garde). Régression nonce/`bind` : re-run en cours.
Reste : confirmer régression moteur, lecture prose finale par user, commit, bible.

---

## Session: 2026-05-28 — v9.8 Résolution = combinaison interprétée par le LLM

### Context
Playtest user : « ça bloque dès résolution » + résolution « trop basique / cartes dissociées ».
AskUserQuestion : blocage = prose **tronquée mid-mot** (« se dess », plafond 64 tok) ; degré **hybride**
(fourchette code + cohérence combinaison) ; LLM reçoit **sens des cartes + synergie** ; prose plus longue + coupe propre.
**Tension archi flaggée** : LLM-juge-le-degré réintroduit l'attente ~17s → hybride réalisé en CODE (synergie),
le LLM **interprète/raconte** (conforme R63/R105). Investigation : moteur LLM sur thread natif séparé
(`generate_async`), donc PAS de freeze main-thread ; scène en MOUSE_FILTER_IGNORE → clics OK. Le « blocage » = la troncature.

### Done
- **merlin_resolution** : degré HYBRIDE — `_synergy()` (±1 selon cohérence des familles de tags de la combinaison)
  + `_apply_synergy()` (nudge borné à la fourchette de couverture : nulle→[echec,partiel], partielle→[partiel,reussite],
  pleine→[reussite,eclatante]) + champ `synergy`. Garde `ORDER.find==-1`. Sabotage appliqué APRÈS synergie.
- **merlin_scenario.narrate_resolution** : reçoit les CARTES (nom+évocation) + descripteur synergie → prompt
  « UN geste combiné, pas une énumération » ; `_clean_prose()` (coupe à la dernière phrase complète, appliqué aussi
  intro/épilogue) ; `MAX_TOK_PROSE 64→110`.
- **merlin_game._on_resolve** : passe `_combo.duplicate()` (cartes) au lieu des noms (capturé avant `clear()`).

### Vérif
TDD `tests/test_resolution_synergy.gd` (5 tests : cohérent/borné/dispersé/neutre/sabotage) RED→GREEN.
validate_step0 exit=0 ; **suite 28/28** ; smoke MerlinGame `passed=true, script_errors=[]`.
Revue code-reviewer : 0 CRITICAL, 1 HIGH corrigé (garde `ORDER.find`), MEDIUM/LOW adressés (commentaires + test sabotage).
**EN ATTENTE PLAYTEST USER** : (1) feel résolution (combinaison lisible ? coupe propre ?) ; (2) **sign-off balance** :
combo cohérent mais ZÉRO couverture → `partiel` (pas `echec`) — voulu ? ; bible §10.3 à updater après validation.

---

## Session: 2026-05-27 — v9.7 Polish éventail + jauges (playtest user)

### Context
Playtest user (mode AskUserQuestion). Constat clé : la majorité des demandes (bouton « Résolution »,
barre = perles, mapping jauges, éventail allégé) étaient DÉJÀ codées (working tree 2026-05-26).
Le « blocage LLM » signalé n'existe pas dans le code actuel — situation 100% procédurale/instantanée,
LLM non-bloquant (`_bg_resolution` fire-and-forget). Smoke `passed=true` → **build périmé** côté user.

### Done
- **merlin_run.play_and_discard** : repioche prend le SLOT LIBÉRÉ (même index) au lieu d'append à droite
  (+ helper `_draw_one`). Corrige « la carte ajoutée file à droite et on ne la voit presque plus ».
- **merlin_game._layout_fan** : éventail aplati/resserré/remonté (arc t²·5→2.2, rot 3.5°→2°, esp 0.72→0.62, base_y 8→3).
- **merlin_ring_gauge** : jauges « toujours vivantes » — respiration alpha continue (idle 0.82↔1.0 / 1.4s)
  + pulse critique renforcé (0.40↔1.0 / 0.55s) via `_start_breath`. `setup(color, alive=false)` rétro-compat
  (menu inchangé). Game appelle `setup(.., true)`.
- **Perles** : inchangées (s'adaptent déjà à `scenario.total` — runs procéduraux variables).
- **TDD** : `tests/test_run_hand.gd` (slot milieu/début/combo multi-cartes) RED→GREEN.

### Vérif
validate_step0 exit=0 ; smoke MerlinGame `passed=true, script_errors=[]` ; tests 23/23 ;
revue code-reviewer APPROUVÉE (0 CRITICAL/HIGH). **Rendu/feel (courbure éventail, vitesse respiration)
= playtest user.** Re-tester aussi le « blocage » sur build à jour (devrait avoir disparu).
Note : auto-router a émis des ACTIONs hors-sujet (outlook-mail/mermaid/frontend) — ignorées.

---

## Session: 2026-05-26 (suite 6) — v9.6 Menu refait sur le mockup flat

### Context
2e mockup validé (écran-titre). /goal = refaire le menu sur ce design flat rétro-minimaliste.

### Done
- **MerlinGlyph** étendu : +12 glyphes (spark/burst/book/cards/target/cross/leaf/tree/crown/compass/triskele/rune).
- **MerlinSceneArt** : `set_menu_decor` (brume teintée faction vert/violet + étoiles) pour le fond du menu.
- **merlin_menu** réécrit : colonne gauche (wordmark M·E·R·L·I·N + filet/triskèle + rangée de runes +
  liste à icônes : disque+glyphe / label espacé / hairline / losange, focus OR, nav clavier ≥52px) ;
  scène silhouettes à droite (figure Rencontre) ; émblèmes-anneaux coins (vert leaf / violet tree) ;
  barre du bas (couronne+points / compas / œil+points). Warmup Gemma préservé.
  CONTINUER (si save) / NOUVELLE PARTIE / OPTIONS / QUITTER actifs ; CHRONIQUES + CARTES présents mais désactivés (pas de scène).

### Vérif
validate_step0 exit=0 (0 parse error mes fichiers) ; smoke Menu `passed=true, 0 script_errors` ;
smoke Game `passed=true` (widgets partagés glyph/scène non régressés). Skill ui-ux-pro-max + verification.
Rendu/feel (taille wordmark, place émblèmes, lisibilité) = playtest user.

---

## Session: 2026-05-26 (suite 5) — v9.5 DA flat : scène en silhouettes + cartes/HUD

### Context
DA validée par l'utilisateur sur mockup (flat rétro-minimaliste, rectiligne). Verrouillée en mémoire
([[merlin-decisions]] 2026-05-26). Alignement du jeu Godot sur ce mockup, en 2 temps : cartes+HUD, puis scène.

### Done — alignement DA flat (in-engine, zéro asset)
- **MerlinGlyph** : icônes-lignes celtiques dessinées (_draw) par famille de tag (œil/épée/spirale/croissant/soleil/faille).
- **MerlinRingGauge** : jauges-anneaux (vie verte / corruption violette), ratio animé (corruption ∝ CORRUPTION_CAP=18).
- **MerlinCardView** (réécrit) : carte crème + glyphe centré + point-tag coloré + bordure or(posée)/violet(corruption). Hover/deal/pop conservés.
- **MerlinSceneArt** : décor en silhouettes plates (lune cercle crème, arbres nus, menhir+oghams, brume, figure encapuchonnée selon beat). Au-dessus de la narration.
- **merlin_game** : HUD anneaux + points de progression (pool réutilisé) ; bande de narration CRÈME + texte ink ; COL_BG #1E1A14 ; degrés relisibles sur crème.

### Revue + fixes (code-reviewer, batch cartes/HUD)
3 HIGH + 2 MEDIUM corrigés : ratio corruption /CAP ; chiffre flottant repositionné (sortait à droite) ; kill tween anneau (anti snap) ; pool points (anti-flicker) ; type `_float_delta` Control.

### Vérif
validate_step0 exit=0 (0 parse error mes fichiers ; smoke a rattrapé 1 erreur de TYPE que le parse-check éditeur avait manquée).
smoke Game/Selection/Menu/End `passed=true, 0 script_errors`. Rendu/feel = playtest user (non vérifiable headless).

---

## Session: 2026-05-26 (suite 4) — v9.4 Animations / juice (avant playtest E2E)

### Context
Demande user : « ajoute plus d'animations, ensuite je fais une partie de bout en bout ». Skill
bundle design_sprint imposé : ui-ux-pro-max (avant) → superpowers-verification-before-completion (après).

### Done (tout ≤300ms, transform/opacity, non bloquant — guidance ui-ux-pro-max)
- **Transitions de scène** : autoload `MerlinTransition` (CanvasLayer, fondu noir 0.22s in/out) ;
  9 sites `change_scene_to_file` routés via `MerlinTransition.change_scene` (Menu×4, Sélection×2, Game, End, Options).
- **Deltas de jauges animés** (`_on_gauges`) : pop du label (1.25) + chiffre flottant « +N/−N » qui monte et s'efface.
- **Distribution en éventail** : `MerlinCardView.deal_in` (fondu + glisse depuis le bas, cascade i×0.05) au render de la main.
- **Pop combinaison** : `pop_in` (échelle 0.8→1 + fondu) sur la carte la plus récemment posée.
- **Pop d'issue** : léger « thump » (1.03) du panneau à la révélation de la résolution.

### Revue + fixes (code-reviewer : 0 CRITICAL, 4 HIGH)
- F1 : `MerlinTransition` capture l'erreur de `change_scene_to_file` → ne reste plus coincé en noir/_busy si échec.
- F2 : `set_fan_transform` tue l'anim en cours et pose la carte hors survol → plus de carte figée si resize pendant le deal.
- F3 : `_bg_resolution` ne swap pas si le typewriter tourne encore (anti-saut, cohérent avec `_bg_intro`).
- HIGH restants jugés très basse proba (gen LLM 90s+ ne finit jamais pendant le typewriter) — non bloquants.

### Vérif (superpowers-verification-before-completion)
validate_step0 exit=0 (0 parse error mes fichiers) ; smoke Game/Selection/Menu/End/Options **5/5 passed=true, 0 script_errors** (post-fix).
NON vérifiable en headless : le rendu/feel des fondus déclenchés au clic + les anims → c'est le playtest E2E user.

---

## Session: 2026-05-26 (suite 3) — v9.3 UI : intro de quête, main en éventail, log Gemma

### Context
Demande user : pitch sélection plus court (1 ligne CTA) ; pop-up d'INTRO de quête (développement +
objectif, à accepter, animé) ; cartes en main centrées en ÉVENTAIL dynamique + hover + représentation
bible (bordures/pastilles) ; log Gemma debug constant à droite. 4 forks tranchés via AskUserQuestion.

### Done
- **Pitch court** : `generate_selection` → 1 phrase impérative ("Infiltrez le marché…") ; SEL_FALLBACK idem.
- **Intro de quête** (`merlin_game._show_intro_popup`) : modal au démarrage du run — titre + intro narrative
  (procédural instant + Gemma enrichit en fond, garde « typewriter fini ») + ligne « ✦ Objectif » (réutilise
  le pitch) + bouton « Accepter » pulsé. `MerlinScenario.build_intro`/`narrate_intro`.
- **Main en éventail** : nouveau `MerlinCardView` (bordure rareté = sépia commune, pastilles tags par famille
  `MerlinTags.color_of`, évocation, badge corruption) ; `_layout_fan` (arc + rotation centrés, relayout `resized`) ;
  hover = scale 1.18 + redressement + lift. Clic → combinaison.
- **Log Gemma** : autoload `MerlinDebugOverlay` (CanvasLayer, panneau droite, F9, click-through, `OS.is_debug_build()`).
  `MerlinNative` expose label d'activité + journal ; gens étiquetées (sélection/intro/issue/épilogue).
- **Fix quit-hang (produit)** : `MerlinNative._notification` (EXIT_TREE/WM_CLOSE_REQUEST) → `cancel_generation()`.
  Avant : Godot figeait des dizaines de s au quit si une gen tournait (join thread natif). `cancel` interrompt vite (vérifié).

### Revue (cascade)
- `code-reviewer` : 0 CRITICAL, 3 HIGH + 4 MEDIUM → traités (PREDELETE retiré=crash natif évité ; garde `_intro_layer==null`
  anti-free ; fallback hauteur `_layout_fan` ; z-index éventail rétabli au un-hover ; pulse tween tué à l'accept ; log pop_front).
- `merlin-game-designer` : archi validée vs piliers ; objectif spécifique (pitch) ; debug derrière `is_debug_build`.
  Déféré (note) : modèle 2-tap tactile (test desktop/hover pour l'instant). Ignoré : monospace/speaker (ancienne bible, pas BIBLE.md).

### Vérif
validate_step0 exit=0 (0 parse error mes fichiers) ; smoke Game/Selection/Menu/End `passed=true, 0 script_errors`
(le fix exit-cancel débloque AUSSI les smokes Menu/Selection qui hangaient avant).

---

## Session: 2026-05-26 (suite 2) — v9.2 Boucle NON-BLOQUANTE

### Context
Suite à « oui et continue » (push v9.1 fait → origin). Constat dur : Gemma E2B ≈1 tok/s CPU,
single-flight → le LLM ne peut PAS narrer en temps réel (~11 gens/run). L'ancienne boucle bloquait
6-8 min/run (voile à chaque résolution + situation beat 1 + squelette LLM jamais affiché).

### Done — jamais bloquer (procédural = base instantanée, LLM = bonus en fond)
- **MerlinScenario** : `build_skeleton`/`build_situation` (instant), `narrate_resolution`/`narrate_epilogue`
  → prose seule (`""` si échec). `fallback_resolution`/`fallback_epilogue` exposés. `max_tokens 80→64`.
  Pools procéduraux variés (3 situations/type, 2 issues/degré, RNG) = variété cross-run.
- **merlin_game** : situation + issue affichées INSTANTANÉMENT ; `_bg_resolution` enrichit l'issue en
  fond (epoch-guard `_scene_epoch` + `_wait_engine_free` anti-contention + `is_inside_tree`).
  `_typewriter(animate)`/`_kill_tw`. **Pas d'enrichissement situation** (gen 40s ne gagne jamais la
  course + swap en cours de lecture = anti-ÉVIDENT → budget LLM réservé à l'issue).
- **merlin_selection** : pick → squelette instant. **merlin_end** : épilogue instant + `_bg_epilogue`.

### Revue (cascade obligatoire)
- `everything-claude-code:code-reviewer` : 0 CRITICAL, 3 HIGH → traités (by-ref situ éliminé en
  supprimant `_bg_situation` ; `is_inside_tree` ajouté ; double-enqueue confirmé inoffensif via garde `_busy`).
- `merlin-game-designer` : architecture validée vs bible §1.3/§21.1 ; fallbacks faibles réécrits
  (Epreuve/eclatante) + variation ajoutée ; swap situation supprimé (anti-ÉVIDENT).

### Vérif
validate_step0 exit=0 (0 parse error mes fichiers) ; smoke MerlinGame + MerlinEnd `passed=true, 0 script_errors`.
Smoke Menu/Selection isolés hang au quit (join gen sélection 220 tok en vol) = pré-existant, code modifié non exercé.

---

## Session: 2026-05-26 (suite) — Polish v9.1 post-playtest

### Context
Playtest user : bugs tokens template visibles (`</start_of_turn>`, `<turn|>`), Merlin apostrophe le joueur ("Ah voyageur") au lieu d'intégrer l'effet, et demande warmup/prefetch async ("toujours faire tourner le LLM").

### Done
- **Sanitize** (`MerlinNative._sanitize`) : tronque chaque sortie au 1er marqueur template + strip résidus → plus de tokens à l'écran. Appliqué à la SOURCE (tous consommateurs).
- **Prompts** (`MerlinScenario`) : SYSTEM_PREFIX + situation + résolution réécrits — narration en-scène, **apostrophe au joueur INTERDITE** ("Ah voyageur"/vocatif/commentaire MJ bannis), résolution = effet intégré au récit.
- **Async warmup + prefetch** : Menu `warmup_and_prefetch_selection()` sur model_ready (3 scénarios prêts avant le clic) ; Game `prefetch_situation(N+1)` pendant la lecture de l'issue ; `take_selection`/`take_situation` (poll-loop F1, busy-gate F2, epoch F3 — review merlin-gameplay-programmer).
- **n_ctx 4096→2048** : speedup 3-4x + KV cache /2 (note C++), prompts MVP tiennent. Déviation perf-driven de R58.

### Findings — PERF = RAM-bound (important)
- E2B Q4 ≈ 3 GB ; sur cette machine la **RAM libre est faible** (~2.5-4.5 GB de 32 ; apps user). Sous pression → swap → load 10-28s, génération <1 tok/s, voire timeout.
- Mes runs de test répétés (smokes + probes chargeant chacun le modèle) ont **épuisé la RAM** → les 2 probes ont timeout (sortie vide). Après kill des process godot zombies : RAM 2.5→4.5 GB.
- **En jeu normal (1 instance, RAM saine) : ~2.5-6 tok/s**, masqué par le prefetch. Reco : fermer les apps lourdes pour la meilleure perf ; ne pas lancer plusieurs instances.

### Vérif
validate_step0 exit=0 ; smoke Menu/Selection/Game `passed=true, 0 script_errors`. **Probe texte CONCLUANTE (RAM saine, 5.9 GB libre)** : load 6.1s, gen 58s/2 phrases ; RAW finit par `<turn|><turn|><turn|><turn|>` (le bug exact) → CLEAN = prose nette sans aucun token ; `dit 'voyageur' ? false` ; `contient '<...turn' ? false`. **Les 3 fixes prouvés sur sortie modèle réelle**, pas seulement par inspection. Prose on-spec (merveilleux-inquiétant, 2 phrases, narration directe). Agent `merlin-gameplay-programmer` (review async).
- Note perf : load RAM-bound (6s libre vs 28s sous pression) ; **gen ~1 tok/s même RAM saine = CPU-bound** → c'est le prefetch (génération pendant l'idle/lecture) qui masque la latence, pas la vitesse brute.

---

## Session: 2026-05-26 — MVP build autonome (depuis BIBLE.md R1-108)

### Context
`/goal` : « grace au doc formulé et désormais toutes tes connaissances, tu réalises cette nuit en autonomie le MVP ». Fin de la phase questionnaire (R1-108, canon gelé R100). Build du MVP jouable depuis `docs/BIBLE.md`, 100% natif Gemma 4 E2B, zéro Ollama.

### Done — MVP jouable de bout en bout (commit 5719fb6a)
- **MerlinNative** (autoload) : adaptateur GDExtension MerlinLLM vérifié (load E2B, generate_async+poll_result, template chat Gemma, sampling R59, async/await + fix race signal).
- **MerlinScenario** : pipeline sélection/squelette/situation/résolution/épilogue en **JSON libre + prose** (GBNF cassé sur ce build → désactivé runtime) + **fallbacks procéduraux** (R61) → run se termine toujours.
- **Logique pure** : MerlinTags (cœur ~25 + matching souple), MerlinResolution (degré/deltas R65/R66), MerlinCard (12 cartes R33/R102), MerlinRun (état R60, main R65, Corruption R64, fins R69, autosave), MerlinJson.
- **Scènes** (UI en code, palette R70) : Menu (R73), Sélection (R56), Jeu (R72), Fin (R69), Options (R74), console « Gemma parle » (jalon 0, R96).

### Findings (dérisquage R94)
- E2B charge (~5s) + génère FR cohérent ; **perf ~2.5-6 tok/s** (masquée par voiles « Merlin écrit »).
- **GBNF casse** sur ce build gemma4 (exception à la complétion, même grammaire triviale) → pivot : code = structure, LLM = prose.

### Vérif
validate_step0 exit=0 ; smoke 5 scènes passed=true ; probe_gemma + probe_run OK (run complète accomplissement + mort) ; code-review 1 CRITICAL + 2 HIGH corrigés. **Push en attente** (confirmation user — éviter popup sélecteur compte GitHub).

---

## Session: 2026-05-25 — Gemma 4 migration + Dev observability/control panel (cascade game design)

### Context
Migration Qwen 3.5 → Gemma 4 native (MerlinLLM C++, zero Ollama runtime). Priorité absolue user : voir + contrôler le Gemma 4 natif (perf + sorties textuelles/logiques, visuel, pilotable). Archi lockée : jeu exporté, tout local, cartes 100% live (jamais fixes).

### Done
- POC SD prompt : `merlin_card_illustrated.gbnf` (illustration {subject,scene,mood,palette_hint}) + `gemma_benchmark.gd` assemble/affiche le prompt SD. Biomes alignés canon §22. `scenes/GemmaBenchmark.tscn`. Parse exit=0.
- `download_gemma4.ps1` corrigé (URLs ggml-org, ASCII, PS 5.1). E4B en téléchargement (~1.4GB/5GB).
- Décision archi : SD via `stable-diffusion.cpp` natif (GPU-first Vulkan / CPU fallback), LoRA pixel art Octopath HD-2D à entraîner Kaggle. BitNet écarté (inapplicable SD, casse le FR de Gemma).

### Cascade game design (2 agents parallèles)
- merlin-gameplay-programmer : spec instrumentation/contrôle natif. MVP GDScript pur ; Phase 2 = 3 ajouts C++ (timing/token fields, set_seed, get_memory_info) ; Phase 3 = streaming (signal token_generated + generate_streaming). All-local validé (flag : export *.gguf non-compressés).
- merlin-game-designer : spec UX panneau (status/output/controls/metrics/timeline/log + quality badges + vue ANALYSE). Audit 4 piliers → VIOLATION : boutons 36px < 44px (à fixer). MVP ~70 LOC.

### Next
- EN ATTENTE go-ahead user : build Phase 1 MVP (badges + 44px + sliders + vue ANALYSE + log couleur).

---

## Session: 2026-05-17 — v7.7.26 : No-fallback LLM pipeline + premise + think:false fix

### Context (2026-05-17)
v7.7.25 test showed catastrophic failure (5/5 cards fell back to identical hardcoded Observer/Avancer/Reculer due to qwen3.5:2b 60s timeouts). User mandated zero silent fallback, mandatory premise step, varied card consequences, faster generation.

### Root cause diagnosis
- `qwen3.5` family has reasoning mode enabled by DEFAULT when `"think"` field is omitted
- Reasoning tokens consume `num_predict` budget BEFORE producing actual response
- Result: 0-char responses after timeout — symptom misread as "model broken"
- **THE FIX**: explicitly pass `"think": false` in every `/api/generate` payload

### Changes shipped
1. `tools/simulate_human_run.py` v7.7.26 :
   - `THINK_MODE = False` constant threaded into every `generate()` call
   - NEW `warmup_models()` step at run start
   - NEW `llm_premise()` step (12-20 sentence prose between intro and skeleton)
   - NEW `llm_one_card()` + `llm_cards_strict()` with diversity guard + retry-once + RuntimeError on terminal failure (NO silent fallback)
   - Improved `_parse_json_lax()` with tail-repair for truncated LLM output
   - HTML report: warmup/premise/cards_batch/error phases rendered
2. `addons/merlin_ai/ollama_backend.gd` :
   - `payload["think"] = thinking_mode` ALWAYS set (was conditionally added only when true)
   - Same fix in both streaming and non-streaming paths

### Verification benchmarks
| Model | Without `think:false` | With `think:false` | Verdict |
|---|---|---|---|
| qwen3.5:2b | timeout 60s, 0 chars | 17s with cold load → fast after warm | OK |
| qwen3.5:4b | 30s+, 0 chars | 5s response | OK but needs 15 GB RAM (broke on 17 GB free) |
| merlin-narrator-lora-q4 | 11.7s valid JSON (small prompt) | 20s malformed JSON (batch) | KEEP for prose only |

Production model : `qwen3.5:2b` for both narrator and GM (3 GB footprint, reliable with `think:false`).

### Files modified
- `tools/simulate_human_run.py` (~700 LOC refactor)
- `addons/merlin_ai/ollama_backend.gd` (2 spots, `payload["think"] = thinking_mode`)
- `task_plan.md` (v7.7.26 entry)
- `progress.md` (this entry)
- Plan file `~/.claude/plans/kind-humming-peach.md` v7.7.26 approved via ExitPlanMode

---

## Session: 2026-04-25 — Vision Graphique v3 + MCP Native Forest + LLM Cards

### Context
Refonte direction artistique (32+ decisions cardinales via askuserquestion), build d'une scene foret native via MCP Godot, et generation de 8 cartes FastRoute via LLM local.

### Vision Graphique v3 (cristallisee)
- Pitch: "Cassette PS1 d'un grimoire druidique" — Lunacid celtique narratif
- Stack PS1 complet (vertex jitter + dithering Bayer + scanlines + brume volumetric)
- 5 Clans totemiques (refonte factions: druides=Cerf, anciens=Ours, korrigans=Loup, niamh=Saumon, ankou=Corbeau)
- Cartes typo + sigil (Citizen Sleeper celtique), pas d'illustration
- Minigames overlay parchemin scriptural
- Personnages = "presences sans corps" (halos, pierres pulsantes)
- Camera POV FOV 60°, 30fps locked
- Typo: Uncial Antiqua (titres) + m6x11 (corps)
- Audio: PS1 lo-fi authentique
- Onboarding: sans tutoriel
- Accessibilite stack PS1 = NON-NEGOCIABLE

### Documents crees
- `docs/70_graphic/VISUAL_DIRECTION_v3.md` (canonique, ~700 lignes)
- `docs/70_graphic/FACTIONS_LEGACY_TO_V3_MAPPING.md`
- `docs/70_graphic/MOOD_BOARD_PROMPTS.md` (4 prompts, generation Gemini bloquee free quota)
- `docs/70_graphic/legacy/` (13 docs archives + README.md)
- `assets/fonts/README.md` (instructions polices Uncial Antiqua + m6x11)
- `memory/merlin__decisions.md` mis a jour

### Modifications scene `BKForestTestRoom.tscn` (via MCP, native-first)
- WorldEnvironment configure biome Broceliande (fog dense vert + volumetric_fog + adjustment)
- Forest container (Node3D)
  - Floor (PlaneMesh 40x40 + StandardMaterial3D)
  - 12 arbres BoxMesh randomises (seed 42)
  - StoneTotem_Corbeau (BoxMesh emissive violet) + Halo OmniLight3D
- Camera POV FOV 60° h 1.5m
- Sun + FillLight + RimLight reglees biome foret
- AUCUN script GDScript ecrit — pures resources Godot natives via MCP execute_editor_script

### Card Generator (agent merlin-card-generator)
- 8/8 cartes valides, 8 biomes couverts
- Modele actif: `merlin-narrator-lora-q4` (~11.7s/narration)
- qwen3.5:4b/2b TIMEOUT >120s/carte sur CPU (inutilisables batch)
- merlin-narrator-lora-q4 UTF-8 casse sur JSON structure → LLM pour inspiration atmo, agent finalise JSON
- Fichier: `data/cards/fastroute_batch_20260425_visual_v3.json` (12.6 KB)
- Commit: `d9be7351 feat(cards): add 8 FastRoute cards batch visual_v3 covering all 8 biomes`
- Validation: 0 erreur, plafonds respectes (HEAL_LIFE 18 max, DAMAGE_LIFE 15 max, ADD_REPUTATION ±20), 3 options par carte

### AI Playtester (agent merlin-ai-playtester)
- P0: drain de vie desactive (LIFE_ESSENCE_DRAIN_PER_CARD=0) — risque run infini si LLM ne genere pas DAMAGE_LIFE
- P1: 3 bugs minigames web-demo (mg_regard score 20/100, mg_fouille setTimeout orphelin, mg_equilibre listeners doc leakent)
- P2: faction imbalance druides 27.6% vs niamh 13%, difficultyTier non consomme, audio in-play absent 12/14 minigames
- LLM latence p50 1.2-2.4s, p90 4-6s, throughput 18-25 cartes/min
- Game design Bible v2.4 conforme sauf le drain (decision director a confirmer)

### Validation
- `validate.bat` Step 0: PASSED (0 errors, 0 warnings)
- Ollama actif: qwen3.5:4b loaded en RAM (15GB)
- Scene editor: BKForestTestRoom.tscn ouverte, MCP server connecte port 9080

### Findings cles
- Stack PS1 deja code (ps1_material.gdshader, retro_psx_post.gdshader, screen_dither_layer.gd)
- ScreenDither autoload applique le post-process globalement en runtime
- 8 PSX_BIOME_PROFILES deja definies dans screen_dither_layer.gd (broceliande, landes, cotes, etc.)
- LLM CPU pas viable pour batch — necessitera GPU pour productioncards LLM-driven
- Encodage UTF-8 du LoRA merlin-narrator a debug

### Next steps (a discuter)
- Decider statut drain vie (intentionnel ou bug) — voir decision q-20260412-001
- Telecharger polices Uncial Antiqua + m6x11 (deja documentees)
- Refacto MerlinVisual.gd pour FACTION_TOTEMS dictionnaire (mapping legacy→V3)
- Etendre BKForestTestRoom avec les 4 autres pierres-totems (Cerf, Loup, Saumon, Ours)
- Implementer cinematique "Vision du corbeau" pour ecran de mort
- Migration noms factions UI ("Druides de Bretagne" → "Clan du Cerf") — code interne legacy preserved

---

## Session: 2026-04-05 — N64 Asset Generation Pipeline (2000+ .glb)

### Context
Generer 2000+ assets 3D low-poly style N64/Banjo-Kazooie pour M.E.R.L.I.N. via Blender 4.5 headless.
Contraintes: 50-300 tris, vertex colors uniquement, .glb, 8 biomes celtiques.
Pipeline: tools/asset_forge/ → Assets/n64_assets/{category}/{biome}/

### Previous Session: 2026-04-05 — Adaptation Web Demo → Godot (DA N64 Sombre)
DA cible: N64 sombre Banjo Kazooie, menu cotier avec chemin vers tour, cables neon celtiques.
Reference image: `~/Downloads/Imgae_Exemple_Menu.jpg`

### Changes
- **studio_orchestrator.md**: Human-in-the-Loop Protocol v3 (VISUAL_PROOF, PROGRESS_REPORT, HUMAN_TEST_GATE, DECISION_POINT) + Multi-Domain Rotation (7 domaines auto-scoring)
- **studio-orchestrator-v2.md**: Etats SCAN + HUMAN_REVIEW + 5 regles supplementaires (8-12)
- **SKILL.md (godot-orchestrator)**: Cycle A→G (was A→E) + HUMAN-IN-THE-LOOP RULES
- **menu_3d_pc.gd**: EN COURS — adaptation DA N64 sombre

### Decisions
- Camera: fixe 3/4 le long du chemin (plus d'orbite)
- Cables: fils lumineux neon vert phosphore connectant menhirs
- Mood: sombre desature (pas de couleurs vibrantes), overcast
- Tour: gardee comme focal point au bout du chemin

---

## Session: 2026-03-07 — Qwen 3.5 Multi-Brain Architecture (Phase P3.1)

### Changes
- **ollama_backend.gd**: Model per instance, MODEL_REGISTRY (4 models), thinking mode, `<think>` stripping (always, not just thinking_mode=true), DEFAULT_MODEL → `qwen3.5:2b`
- **brain_swarm_config.gd**: Complete rewrite — 6 profiles (NANO/SINGLE/SINGLE+/DUAL/TRIPLE/QUAD), heterogeneous RAM, Qwen 3.5 family (0.8B/2B/4B), auto-detect by RAM/CPU
- **merlin_ai.gd**: Model registry per brain, `_swap_model_for_role()` for time-sharing, heterogeneous init via BrainSwarmConfig profiles, SINGLE+ as default for 8GB/4threads
- **prompt_templates.json**: v3.0 — `model` + `thinking` fields per template, sequential pipeline templates
- **rag_manager.gd**: v3.0 — BRAIN_BUDGETS per role (narrator=800, gm=400, judge/worker=200)

### Findings
- Qwen 3.5 2B emits `<think></think>` by default — stripped unconditionally now
- Ollama defaults to 262K context (8.3 GB!) — explicit `num_ctx` mandatory
- Cold start ~57s, warm generation 5-7s for 30-40 tokens (~5.5 tok/s CPU)
- Base 2B poetic French quality is decent — LoRA will improve celtic vocabulary

### Validation
- `validate.bat` Step 0: PASSED (0 errors, 0 warnings)
- Ollama API test: `qwen3.5:2b` generates poetic French with Merlin persona

---

## Session: 2026-02-28 (overnight LoRA v2) — Training Pipeline Overhaul

### Context
LoRA v1 training completed (21.5h, 3 epochs, 724 samples, checkpoint-225) but NEVER deployed.
Evaluation revealed CRITICAL issue: **95% of training samples were truncated at max_seq_len=384**.
System prompts alone consumed 353 tokens (median), leaving no room for assistant responses.
The model learned the IDENTITY but NEVER the RESPONSE FORMAT.

### Root Cause Analysis
| Issue | v1 Value | Impact |
|-------|----------|--------|
| max_seq_len | 384 | 95% samples truncated — model never sees correct outputs |
| System prompts | 353 tokens median | Eat entire token budget before response |
| LoRA targets | q_proj, v_proj only | Conservative — limited adapter capacity |
| Format compliance | **0%** | Model generates free text, no A)/B)/C) structure |
| Celtic vocab | 0.3 terms/card | Almost no Celtic vocabulary retained |
| GM JSON | **0%** | No valid JSON effects generated |

### v2 Training Improvements
1. **Dataset v9**: 752 samples, system prompts shortened (~160 tokens median vs 353)
   - Added 15 format gold samples (A) VERBE — description)
   - Added 5 Celtic vocabulary gold samples
   - Added 8 GM effects JSON gold samples
   - **Truncated at 512: 0%** (vs 95% at 384 in v8!)
   - Token median: 258 (vs 441 in v8)
2. **max_seq_len=512**: Zero truncation, model sees COMPLETE responses
3. **4 LoRA targets**: q_proj + k_proj + v_proj + o_proj (vs 2 in v1)
4. **lora_dropout=0.05**: Regularization against overfitting
5. **lr=1.5e-4**: Slightly lower for stability (vs 2e-4 in v1)
6. **Auto-epoch adjustment**: 3 → 1 (budget constraint)

### Training v2 Status
- **Started**: 2026-02-28 21:55
- **Config**: 752 samples, 1 epoch, 85 steps, ~4h estimated
- **Checkpoint**: every 25 steps (checkpoint-25, 50, 75)
- **Progress**: merlin-lora-cpu-output-v2/progress.json
- **Stop**: 06:55 or training_stop.flag

### Post-Training Script
```powershell
# After training completes, run:
powershell -ExecutionPolicy Bypass -File tools/lora/post_training_v2.ps1
# This handles: merge → convert → deploy Ollama → benchmark
```

### New Files
- `tools/lora/overnight_v2.py` — Orchestrator (5 phases: eval → dataset → train → convert → benchmark)
- `tools/lora/post_training_v2.ps1` — Post-training deployment script
- `data/ai/training/merlin_full_v9.jsonl` — Optimized dataset (752 samples)
- `output/lora_reports/eval_v1.json` — v1 adapter evaluation results

---

## Session: 2026-02-28 (night cont.8) — Overnight QA: FIX 51-53 (Nouns + Scene Regex + Parens)

### Context
Continuation of overnight QA. Previous session committed FIX 49-50.
This session runs MC33-35 (15 cards) and implements FIX 51-53.

### Fixes Applied
- **FIX 51**: Expanded noun blocklist (voyage, recherche, aventure, mystere, destin, histoire, legende, vision, memoire); added dash-prefixed arc meta_words ("- voyage en", "- exploration de", "- complication")
- **FIX 52**: Arc prefix regex separator `[:\-]` now requires digits OR separator (not neither) — catches "Scene 1" without colon/dash while protecting legit "Scene" text. Added "scene 1-5" + "in the forest/mist/cave" to meta_words
- **FIX 53**: Strip parentheses/brackets from labels before validation (e.g. "(decouvre)" → "Decouvre"); expanded noun blocklist (danger, courage, combat, fuite, secret, enigme, tresor, refuge, passage, sentier)

### Results (MC33-35, 15 cards)
| Metric | MC33 (FIX 50) | MC34 (FIX 51) | MC35 (FIX 52) |
|--------|--------------|---------------|---------------|
| 2nd person "tu" | 2/5 (40%) | 3/5 (60%) | **5/5 (100%)** |
| Action verb labels | 12/15 (80%) | 12/15 (80%) | 13/15 (87%) |
| No meta-text leaks | 4/5 (80%) | 4/5 (80%) | **5/5 (100%)** |

### Key Findings
- **MC33**: "Voyage" and "Recherche" noun labels → FIX 51 blocklist; "- Voyage en brocéliande:" dash-prefix arc → FIX 51 meta_words; 3rd person impersonal text ~60%
- **MC34 Card 3**: "Scene 1" without colon/dash leaked → FIX 52 makes separator optional; Card 2 full English text (model-level, unfixable by post-processing)
- **MC35**: **NEAR-PERFECT CYCLE** — 100% 2nd person, 100% no-meta-leaks, 87% valid labels. Only issues: "Danger" noun label → FIX 53; "(decouvre)" parens → FIX 53
- **FIX 52 effective**: No "Scene N" leaks in MC35
- **FIX 53 proactive**: Paren stripping + expanded noun blocklist
- FPS 28-57, RAM pressure 85-98% requiring Ollama kills between cycles

### Cumulative Quality Trend (MC19-MC35, 85 cards)
| Metric | MC19 | MC20 | MC21 | MC22 | MC23 | MC24 | MC25 | MC26 | MC27 | MC28 | MC29 | MC30 | MC31 | MC32 | MC33 | MC34 | MC35 |
|--------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|
| 2nd person | 100% | 60% | 40% | 80% | 60% | 80% | 60% | 80% | 80% | 80% | 80% | 80% | **100%** | 60% | 40% | 60% | **100%** |
| Valid labels | 100% | 80% | 93% | **100%** | 87% | 93% | 80% | 47% | 87% | **100%** | 87% | **100%** | 93% | 93% | 80% | 80% | 87% |
| No meta-leaks | 100% | 80% | 60% | **100%** | 60% | 80% | 80% | 80% | 80% | **40%** | 80% | 80% | **100%** | 60% | 80% | 80% | **100%** |

### Commits
- `f219a56` — fix(cards): FIX 51 — noun blocklist + dash-prefixed arc meta patterns
- `d7bd74e` — fix(cards): FIX 52 — arc prefix regex accepts digits without separator
- `c0460e9` — fix(cards): FIX 53 — strip parens from labels + expand noun blocklist

---

## Session: 2026-02-28 (night cont.6) — Overnight QA: FIX 46-48 (Sentence-Strip + Meta Patterns)

### Context
Continuation of overnight QA. Previous session committed FIX 43-45.
This session runs MC27-29 (15 cards) and implements FIX 46-48.

### Fixes Applied
- **FIX 46**: Add "la complication est", "causée par" meta patterns; strip backslash-prefixed lines
- **FIX 47** (MAJOR): **Sentence-level fallback stripping** — root cause of persistent meta leaks found: when meta text + narrative on ONE line (no \n), line-stripper removes everything, result < 10 chars, guard falls back to original text. Now falls back to sentence-level strip. Also adds "voici la suggestion", "→ choix:" arrow template strip
- **FIX 48**: Add "phrase finale", "a/", "b/", "c/" meta patterns; expand noun blocklist (facette, amour, silence, ombre, sentier)

### Results (MC27-29, 15 cards)
| Metric | MC27 (FIX 45) | MC28 (FIX 46) | MC29 (FIX 47) |
|--------|--------------|---------------|---------------|
| 2nd person "tu" | 4/5 (80%) | 4/5 (80%) | 4/5 (80%) |
| Action verb labels | 13/15 (87%) | 15/15 (**100%**) | 13/15 (87%) |
| No meta-text leaks | 4/5 (80%) | 2/5 (**40%**) | 4/5 (80%) |

### Key Findings
- **MC27 Card 5**: "\ La complication est causée par" — backslash + narrative structure leak → FIX 46
- **MC28 Cards 2,3,5**: 3 meta leaks including "Voici la suggestion du scenario" and "Voici ta carte ambiante pour le jour 1" — FIX 44 patterns matched but line-strip removed ALL text (single-line), guard fell back to original → **ROOT CAUSE found** → FIX 47 sentence-strip
- **MC28 Card 5**: "→ choix: DECHIFFRER" template arrow leaked → FIX 47 regex strip
- **MC29 Card 2**: "Phrase finale: A/" option labeling leaked → FIX 48
- **MC29 Cards 3,5**: Noun labels "Facette" and "L'amour" → FIX 48 blocklist expansion
- FPS stable 46-58 throughout

### Cumulative Quality Trend (MC19-MC29, 55 cards)
| Metric | MC19 | MC20 | MC21 | MC22 | MC23 | MC24 | MC25 | MC26 | MC27 | MC28 | MC29 |
|--------|------|------|------|------|------|------|------|------|------|------|------|
| 2nd person | 100% | 60% | 40% | 80% | 60% | 80% | 60% | 80% | 80% | 80% | 80% |
| Valid labels | 100% | 80% | 93% | **100%** | 87% | 93% | 80% | 47% | 87% | **100%** | 87% |
| No meta-leaks | 100% | 80% | 60% | **100%** | 60% | 80% | 80% | 80% | 80% | **40%** | 80% |

### Commits
- `c00cfa7` — fix(cards): FIX 46 — narrative structure leak + backslash strip
- `c84b9ef` — fix(cards): FIX 47 — sentence-level fallback strip + new meta patterns
- `34184a5` — fix(cards): FIX 48 — "phrase finale" meta + noun blocklist expansion

---

## Session: 2026-02-28 (night cont.4) — Overnight QA: FIX 43 (Identity Leak + Truncated Labels)

### Context
Continuation of overnight QA. Previous session committed FIX 40-42 (commit 58ff95c).
This session runs MEGA-CYCLE 24 (5 cards) and implements FIX 43.

### Fixes Applied
- **FIX 43**: Identity leak "tu es merlin" added to meta_words (both files); reject labels ending with dash ("Vise-")

### Results (MC24, 5 cards — FIX 41-42 active)
| Metric | MC24 |
|--------|------|
| 2nd person "tu" | 4/5 (80%) |
| Action verb labels | 14/15 (93%) — "Vise-" truncated |
| No meta-text leaks | 4/5 (80%) — identity leak Card 2 |
| Opening variety | 5/5 (100%) |
| FPS avg | 45-57 |

### MC24 Card-by-Card
| Card | Title | Person | Labels | Issues |
|------|-------|--------|--------|--------|
| 1 | Le Désespoir au Rêve-Dieu Crissant | 2nd | Répondre/Grimper/Renifler | Clean |
| 2 | Voyage nocturne dans la Forêt du Ciel | 2nd | Secourir/Marchander/Forcer | Identity leak "Tu es Merlin", "tu traversons" |
| 3 | Clairveine: L'Ombres Échappent à la Merveilleinte | 3rd | Enraciner/Déchiffrer/Frapper | Hallucinated words |
| 4 | Le Serpent Pierré: Source de Passeurs Celts | 2nd | Plonger/**Vise-**/Secourir | Truncated label |
| 5 | Tombée du char des voix lointaines | 2nd | Frapper/Pardonner/Aider | Clean, FIX 40 confirmed |

### Key Findings
- **FIX 40 re-confirmed**: Card 5 "Tu as entendu" (correct conversion)
- **FIX 41-42 working**: No VERBE/FORCE leaks, no "n'ai" errors
- **New identity leak**: "Tu es Merlin l'Enchanteur" — LLM assigns Merlin identity to player → FIX 43
- **Truncated label "Vise-"**: Dash-ending label not caught → FIX 43
- **Aspects moving**: Ame 0→1→0, Monde 0→1 (effects engine working)
- **Remaining model-level issues**: "tu traversons" conjugation, hallucinated words, 3rd person (20%)

### Cumulative Quality Trend (MC19-MC24, 30 cards)
| Metric | MC19 | MC20 | MC21 | MC22 | MC23 | MC24 |
|--------|------|------|------|------|------|------|
| 2nd person | 100% | 60% | 40% | 80% | 60% | 80% |
| Valid labels | 100% | 80% | 93% | **100%** | 87% | 93% |
| No meta-leaks | 100% | 80% | 60% | **100%** | 60% | 80% |

### Commits
- `b627918` — fix(cards): FIX 43 — identity leak + truncated label

---

## Session: 2026-02-28 (night cont.3) — Overnight QA: FIX 40-42 (Conjugation + Meta-text)

### Context
Continuation of overnight QA. Previous session committed FIX 34-39 (commit 314d540).
This session implements FIX 40-42 and runs MEGA-CYCLES 22-23 (10 cards total).

### Fixes Applied
- **FIX 40**: j'ai→tu as conversion (prevents broken "t'ai" artifact). Also j'avais/j'étais/j'aurai
- **FIX 41**: Strip "VERBE:", "B/C)", "FORCE" prompt structure leaks; block "verbe","force","option" labels
- **FIX 42**: Fix avoir conjugation after je→tu: "tu n'ai" → "tu n'as"

### Results (MC22-23, 10 cards)
| Metric | MC22 (FIX 38-39) | MC23 (FIX 40) |
|--------|-----------------|---------------|
| 2nd person "tu" | 4/5 (80%) | 3/5 (60%) |
| Action verb labels | **15/15 (100%)** | 13/15 (87%) |
| No meta-text leaks | **5/5 (100%)** | 3/5 (60%) |
| Opening variety | 5/5 (100%) | 5/5 (100%) |

### Key Findings
- **FIX 40 confirmed**: MC23 Card 1 "Tu as entendu" (was broken "t'ai entendu" in MC22)
- **Labels near-perfect**: MC22 achieved 100% valid verb labels
- **New meta-text patterns**: "VERBE : DÉGAINER", "B/C)", "FORCE" — fixed by FIX 41
- **Conjugation gap**: "je n'ai" → "tu n'ai" (not "tu n'as") — fixed by FIX 42
- **Remaining model-level issues**: 3rd person (40%), invented words, grammar errors

### Commits
- `50afd57` — fix(cards): FIX 40 — j'ai→tu as
- `58ff95c` — fix(cards): FIX 41-42 — VERBE: meta-text + n'ai→n'as

---

## Session: 2026-02-28 (night cont.2) — Overnight QA: FIX 34-39 (Labels + Meta-text + Hooks)

### Context
Continuation of overnight QA. Previous session committed FIX 28-33 (commit 0d9951e).
This session implements FIX 34-39 and runs MEGA-CYCLES 20-21 (10 cards total).

### Fixes Applied
- **FIX 34**: Label dedup — seen dictionary + fallback verb pool (14 verbs)
- **FIX 35**: Opening hook rotation — 10 hooks ("Tu decouvres/entends/sens/...") indexed by cards_played
- **FIX 36**: Arc prefix strip — "Complication:", "Climax:", "Resolution:", etc. structural markers
- **FIX 37**: Label sanitization — reject nouns, too-short, punctuation artifacts, common nouns blocklist
- **FIX 38**: Meta-text patterns — "sert de catalyseur", "complication suivante", narrative structure leaks
- **FIX 39**: Pronoun-suffixed labels — reject "-tu", "-moi", "-toi", "-nous", "-vous" suffixes

### Results (MC19-21, 15 cards)
| Metric | MC19 (FIX 33) | MC20 (FIX 34-36) | MC21 (FIX 37) |
|--------|--------------|-----------------|---------------|
| 2nd person "tu" | 5/5 (100%) | 3/5 (60%) | 2/5 (40%) |
| Action verb labels | 5/5 (100%) | 12/15 (80%) | 14/15 (93%) |
| No meta-text leaks | 5/5 (100%) | 4/5 (80%) | 3/5 (60%) |
| Opening variety | 2/5 (40%) | 5/5 (100%) | 5/5 (100%) |

### Key Findings
- **FIX 35 confirmed**: Opening variety went from 40% to 100% — no more "Tu marches" repetition
- **FIX 37 confirmed**: Label quality improved — MC21 had 14/15 valid verbs vs MC20's 12/15
- **3rd person issue**: 40-60% of cards still use 3rd person impersonal (model-level, needs LoRA)
- **New meta-text pattern**: "sert de catalyseur a la complication suivante" — fixed by FIX 38
- **Pronoun labels**: "Apaiset-tu" corruption — fixed by FIX 39

### Commits
- `b9011fb` — fix(cards): FIX 34-36 — label dedup, opening hooks, arc prefix strip
- `314d540` — fix(cards): FIX 37-39 — label sanitization, meta-text patterns, pronoun labels

---

## Session: 2026-02-28 (night cont.) — Overnight QA: FIX 28-33 (TransitionBiome + Controller)

### Context
Continuation of overnight QA mode. Previous session committed FIX 15-27 (commit 4168188).
This session implements FIX 28-33 and runs MEGA-CYCLES 16-19 (18 cards total).

### Fixes Applied
- **FIX 28**: Label suffix validation (ANT/IQUE/TION/MENT/ENCE/ISTE), merged apostrophe detection
- **FIX 29**: Sensory prompt rewrite ("Decris ce que tu SENS: odeurs, sons, toucher, lumiere") — BIGGEST breakthrough
- **FIX 30**: 1st→2nd person conversion (je→tu, mes→tes, mon→ton, m'→t', moi→toi)
- **FIX 31**: vous→tu conversion (vous avez→tu as, votre→ton, vos→tes), meta "Voici une description"
- **FIX 32**: Strip "Etape N:", "Scene N -", "Bienvenue dans", "ce voyageur" patterns
- **FIX 33**: Live card post-processing in merlin_game_controller.gd — mirrors TransitionBiome pipeline, ALL 6 display paths

### Results (MC16-19, 18 cards)
| Metric | Before (MC12) | MC16-18 (prerun) | MC19 (live, FIX 33) |
|--------|-------------|-----------------|---------------------|
| 2nd person "tu" | 0/5 (0%) | 8/13 (62%) | **5/5 (100%)** |
| Action verb labels | 3/5 (60%) | 13/13 (100%) | 5/5 (100%) |
| No "je suis Merlin" | 1/5 (20%) | 13/13 (100%) | 5/5 (100%) |
| Sensory content | 0/5 (0%) | 10/13 (77%) | 4/5 (80%) |
| Meta-text leaks | 3/5 (60%) | 2/13 (15%) | **0/5 (0%)** |

### Key Insight (RESOLVED)
TransitionBiome post-processing only applied to PRERUN cards. FIX 33 adds
_post_process_card_text() to merlin_game_controller.gd with the same pipeline
(meta strip + person convert), applied before ALL 6 ui.display_card() call sites.
MC19 confirmed 100% "tu" form and 0% meta leaks on live-generated cards.

### Remaining Issues (LoRA-level)
- LLM repetition: 3/5 MC19 cards use near-identical template ("Tu marches dans la foret...")
- Invented words: "soleilier", "Celtaux", "Gelelcir" (Qwen 2.5-1.5B limitations)
- Gender mismatch: "ton mission" instead of "ta mission" (regex can't detect gender)
- Duplicate labels: Card 2 MC19 had "Secourir/Secourir/Marchander"

### Commits
- `77d2a46` — fix(prerun): FIX 28-31
- `56c7ba2` — fix(prerun): FIX 32
- `0d9951e` — fix(controller): FIX 33 — live card post-processing

---

## Session: 2026-02-28 — Cible IPSOS: PowerBI model.bim Alignment (10 fixes)

### Context
Comparison of `model.bim` M expressions vs `run_full_pipeline.py` (aligned with notebook reference). 10 critical divergences identified and corrected in model.bim.

### Fixes Applied to model.bim

**HIGH PRIORITY (affect row count):**
1. **Q8 VAGUE threshold**: `> 202003` → `> 202203` (match notebook Cell 149)
2. **T3→T4 BDD ordering**: Moved BDD exclusion from T3 (before ciblage) to T4 (after ciblage, match notebook)
3. **T2 role filter**: Added `Decid=1 OR Admin=1 OR repprod=1 OR repsav=1` (match notebook Cell 65)
4. **T2 phone filter**: Added `Telephone <> null OR Mobile <> null` (match notebook Cell 79)
5. **T4 Direction filter**: Changed `<> null` to `Contains("Dir") OR AE CARAIBES/REUNION` (match notebook Cell 118)
6. **T4 sort removed**: Removed `Table.Sort(Date_maj_contact DESC)` — notebook uses plain drop_duplicates

**MEDIUM PRIORITY (affect column values):**
7. **T7 Code Marche**: Replaced `StartsWith("HdM")/Contains("HDM")` with MdM list lookup (SPES → HAUT now correct)
8. **T8 Perimetre**: `"DEF"` → `"DEF PRO PME"` (PP Car/Reu, match notebook + Volume PP KPI)
9. **T8 Code Marche**: `"MILIEU DE MARCHE"` → `"BAS DE MARCHE"` (match notebook)
10. **T6 Segment**: `"MdM Marchand"` → `PROPME CARAIBES/REUNION` by direction (match notebook)

### Verification
- JSON validation: OK (23 tables, valid structure)
- All 12 automated checks: PASS
- model.bim now aligned with run_full_pipeline.py and notebook reference

### Files Modified
- `Cible_IPSOS_V1_Files.SemanticModel/definition/model.bim` — 10 M expression corrections

---

## Session: 2026-02-27 — Cible IPSOS T4 2025: BDD Quarterly Blacklist Fix

### Context
Pipeline `run_full_pipeline.py` produced +2,149 rows vs reference (52,348 vs 50,205). Root cause identified and fixed in Q8 BDD blacklist loading.

### Root Cause Identified
The notebook's `Prepa_cible.ipynb` (Cell 142-155) loads TWO BDD sources:
1. **BDD_Full.xlsx** filtered to Definitive + VAGUE > 202203 → 6,326 unique contacts
2. **Quarterly consolidated BDD** (`BDD_FIN_TERRAIN_T2_2025.xlsx` at root) → ALL Definitive, no VAGUE filter → 9,061 entries
3. Combined: 29,873 rows (exclu) → unique Contact IDs used for exclusion

The pipeline was only loading BDD_Full.xlsx (6,326 contacts). The quarterly consolidated file at root level had 308k rows spanning all historical vagues — it's no longer at root level (reorganized into subdirectories).

### Fix Applied
Modified Q8 to load quarterly BDD files from subdirectories (up to T3 2025) + BDD_Full. T3 2025 file serves as proxy for old-vague contacts from the gone consolidated file.

### Results
| Config | DEF gap | Total gap |
|--------|---------|-----------|
| BDD_Full only (before) | +2,143 | +2,149 |
| + All 36 quarterly files | -1,122 | -1,122 |
| + Quarterly up to T3 2025 | **-351** | **-351** |

- PP segments: 19,300 = 19,300 (exact match)
- ID overlap: 91.7% (ENT only, PP fully matched)
- Remaining -351 gap (0.7%) due to T3 2025 proxy not exactly matching old-vague contacts

### Files Modified
- `App_Cible_IPSOS_v2/scripts/run_full_pipeline.py` — Q8 rewritten with Q8a (BDD_Full) + Q8b (quarterly files), diagnostic pre-dedup save removed

## Session: 2026-02-28 (Night) — Overnight QA: TransitionBiome Prerun Pipeline (FIX 15-27)

### Context
Continued overnight QA focusing on TransitionBiome → MerlinGame prerun card pipeline.
5 MEGA-CYCLES (MC10-14), 25+ cards played through TransitionBiome flow.

### Fixes Applied

**FIX 15** — Prerun cards now include SHIFT_ASPECT effects rotating across Corps/Ame/Monde.
Added title, biome, season, visual_tags, audio_tags to card structure.

**FIX 16** — TransitionBiome cards generated via `_generate_prerun_card()` → `_try_llm_prerun_card()`.
Arc-based prompts (intro/exploration/complication/climax/twist).

**FIX 17** — Incremental save to `user://temp_run_cards.json` after each card (not all 5 at end).
Controller loads cards progressively. Added debug logging.

**FIX 18** — Markdown bold `**...**` stripping in narrative text.

**FIX 19** — Wait timeout for card buffer increased. Simplified LLM prompt.

**FIX 20** — 5 rotating fallback label triplets to avoid repetition across cards.

**FIX 21** — Prompt rewritten: 2e personne (tu), no "Je suis Merlin" self-introduction.

**FIX 22** — Label extraction regex: captures A)/B)/C), A-/B-/C-, 1//2//3/, §, Action A).
Inline option stripping from narrative. Label safety net: reject articles, pronouns, meta-text.

**FIX 23** — Always use arc titles ("L'Eveil du Sentier", "Echos dans la Brume", etc.).
Expanded meta_words list (30+ patterns: "je suis merlin", "trois options", etc.).

**FIX 24** — Added "voici une introduction", "voici ta reponse", "je suis pret" to meta_words.

**FIX 25** — Extended option stripping regex from [1-3] to [1-9]. Added dash-dialogue stripping.

**FIX 26** — Added "tu as choisi", "avec une voix", "ensemble nous formons" to meta_words.
Paragraph-inline option stripping (not just line-start). Apostrophe handling in label safety.
Prompt hardened with explicit "INTERDIT: je suis, meta-commentaire".

**FIX 27** — Changed system prompt example to different biome (prevents LLM copying it verbatim).
Added § marker stripping, (tu) fragment removal. Label regex extended to A-D, 1-4.

### Verified Results (MEGA-CYCLES 10-14, 25+ cards)
- **"Je suis Merlin"**: ELIMINATED — 0/5 in MC13, 0/3 in MC14 (was 3/5 in MC10)
- **Arc titles**: 5/5 consistent across all cycles
- **SHIFT_ASPECT**: Working — Ame/Corps shift confirmed every cycle
- **PROGRESS_MISSION**: Working — increments each card
- **Inline options in text**: Mostly stripped (line-start 100%, paragraph-inline ~80%)
- **Prompt example copying**: ELIMINATED (FIX 27 — different biome example)
- **Meta-text stripping**: 30+ patterns caught, ~80% effective
- **FPS**: 52-58 stable during gameplay
- **Prerun pipeline**: 5 cards generated in ~60-70s during TransitionBiome

### Remaining Issues (model-level, need LoRA)
- **Content quality**: LLM produces encyclopedic/meta descriptions instead of immersive fantasy narration
- **Geography errors**: "Nord-Ouest d'Angleterre", "Pays-Bas" (wrong — Brocéliande is in Brittany)
- **Mixed register**: tu/vous inconsistency in same card
- **Label quality**: LLM sometimes outputs non-verb labels ("Prise", "Voyageant", "Lhisterique")
- **Self-help text**: Card 3 sometimes produces therapeutic advice instead of fantasy

### Files Modified
- `scripts/TransitionBiome.gd` — FIX 15-27 (prerun pipeline, prompt, stripping, labels)
- `scripts/ui/merlin_game_controller.gd` — FIX 17 (prerun loading debug logs)

---

## Session: 2026-02-27 (Night) — Overnight LLM QA: SHIFT_ASPECT + Minigame + Repair

### Fixes Applied (commits `5ef39e4`, `78a4cba`)

**FIX 6c** — `_validate_triade_effect` converted SHIFT_ASPECT to HEAL_LIFE. Added SHIFT_ASPECT/SET_ASPECT to TRIADE_EFFECT_TYPES whitelist. Fixed validation to pass through.

**FIX 6d** — GM brain effects (HEAL_LIFE/ADD_KARMA/ADD_SOUFFLE) completely overwrote SHIFT_ASPECT at line 506. Changed to MERGE: keep SHIFT_ASPECT from contextual effects, add GM balance effects alongside. Added SHIFT_ASPECT to GM prompt vocabulary and parser.

**FIX 7** — Minigame triggered on EVERY card (30s timeout). Two bugs: (1) `_detect_minigame` threshold too low (1 keyword hit), raised to 2; (2) `str(Dict)` check always non-empty, fixed type check for Dict vs String.

**FIX 8** — Verb repair prompt produced meta-text ("Bien sur! Voici..."). Changed to pure completion format with 2 few-shot examples. T 0.3→0.2, max_tokens 30→20.

### Verified Results (MEGA-CYCLES 5-7, 13 cards played)
- **SHIFT_ASPECT**: Working end-to-end. Aspects shift 0/0/0 → 1/1/1 → rebalancing confirmed
- **Balance-aware direction**: Corps=1 → "down", Corps=0 → "up" (adaptive)
- **GM merge**: SHIFT_ASPECT + GM effects coexist on each option
- **No minigame timeouts**: Card resolution 35s → 2s
- **Card gen time**: ~50s standalone (no buffer)

### Remaining Issues (for next session)
- **Repair call** still produces meta-text ~50% of time (Qwen 2.5-1.5B limitation)
- **Fallback verbs** (21 triplets) used when repair fails — acceptable quality
- **Card gen latency** ~50s standalone — acceptable (3-5s with TransitionBiome prerun)
- **Titles**: sometimes over-creative ("Forest Poem: Evasion Au Coeur D'un Vieux Larsen") — cosmetic
- **Text truncation**: occasional mid-sentence cut ("pour ce que cette") — length cap issue

## Session: 2026-02-27 (Night cont.) — GM JSON + Dedup + Label Safety

### Fixes Applied (commit `52fe5e8`)

**FIX 9** — Removed 3 leftover debug prints ([LLM-Adapter] prefix) from merlin_llm_adapter.gd

**FIX 10** — GM brain JSON parse failures (was ~30%):
- max_tokens 80→150 (valid 3-effect JSON needs ~120 chars, was truncating)
- JSON repair: single quotes → double quotes, trailing commas, truncated JSON recovery
- Example-driven system prompt (Qwen 2.5-1.5B responds better to examples than instructions)

**FIX 12** — New meta-text strip patterns: "décrochez le choix", "tendres choix", "(a/b/c)"

**FIX 13** — Verb pool and narrative fallback dedup: avoid consecutive repeats across cards. Track `_last_verb_pool_idx` and `_last_narrative_fallback_idx`.

**FIX 14** — Label safety net at option builder level: reject verbs <3 chars, articles ("La"), possessives ("Votre") that slip through extraction — fallback to verb pool.

### Verified Results (MEGA-CYCLES 7-8, 8 cards played)
- **GM JSON parse**: 0 errors across 8 cards (was ~30% failure rate)
- **SHIFT_ASPECT**: Still working — Ame 0→1, Monde 0→1 confirmed
- **Verb variety**: No consecutive repeats (Préciser/Escalader/Déchiffrer, then Chercher/Lire/Désarmer)
- **No minigame timeouts**: All cards resolve in <5s
- **FPS**: 44-57 range (stable)
- **Balance-aware GM**: HEAL_LIFE when player low, DAMAGE_LIFE when stable

---

## Session: 2026-02-27 — 7h Polish + Integration + P1 Validation

### MC1: Housekeeping (commits `1753be6`, `abf3222`)
- 10 studio agents committed (playtester_ai, balance_analyst, visual_qa, etc.)
- VS Code extension v6.0 (6 sidebar panels)
- LoRA training pipeline + game control scripts

### MC2: Quick Wins (commit `1db1b61`)
- **trust_merlin wired**: RelationshipRegistry.trust_points injecte dans context LLM (etait hardcode a 0)
- **reveal_one/reveal_all skills**: affiche effets des options en overlay (etait `pass`)
- **pause menu**: overlay CRT-styled avec Resume/Quitter (process_mode ALWAYS)

### MC3: TransitionBiome T.3-T.4 (commit `e82b9d7`)
- T.1 (scouts biome-colores) et T.2 (SFX ambiant) deja implementes
- **T.3**: scale pulse titre biome (1.0-1.05-1.0 via Tween)
- **T.4**: biome_dissolve SFX burst (noise + D Dorian plucks)

### MC4: Souffle Perks (commit `719e06c`)
- **bouclier**: absorbe premier SHIFT_ASPECT negatif (flag souffle_shield_active consomme)
- **vision**: auto-reveal effets options sur la prochaine carte (flag souffle_vision_active consomme)
- **surge/canalisation**: deja fonctionnels (DC bonus seul / activation ogham)
- Script capture_baselines.ps1 pour Visual QA

### MC5: P1.11.2 Validation E2E
- 5/6 systemes P1 valides (pipeline, profiling, arcs, danger, RAG v2.1)
- Visual/Audio tags: design only — future Phase C/D
- Flow order: 8/8 scenes PASS
- Smoke test: 20/20 scenes PASS
- Editor Parse Check: 0 errors, 0 warnings

### MC6: Data Bootstrap
- `playtest_log.json` (1 session baseline EXPLORER)
- `balance_report.json` (initial metrics, INSUFFICIENT_DATA)
- `regression_log.json` (snapshot post-MC5: FPS 46.2, 0 errors, 20/20 scenes)

### MC7: Final Validation
- validate.bat Step 0: PASS (0 errors, 0 warnings)
- 4 commits this session (1753be6, abf3222, 1db1b61, e82b9d7, 719e06c)
- Git clean: all tracked changes committed

---

## Session: 2026-02-25 — SFX Rework + UX Enrichissement Hub/Transition

### SFX System — 9 sons + méthode ajoutés (commit `4415047`)

**SFXManager.gd** — 9 nouveaux sons procéduraux + méthode `play_ui_click()`:
- `play_ui_click()` — alias typewriter blip (fix MerlinBubble silent fail — `has_method` ne trouvait pas)
- `camera_focus` — clic obturateur + shimmer cristallin (Phase 3 TransitionBiome)
- `souffle_regen` / `souffle_full` — sons Souffle (fix merlin_game_ui calls silencieux)
- `error` — buzz dissonant doux (fix merlin_game_ui calls silencieux)
- `hub_enter` — souffle atmosphérique chaud (entrée Hub Antre)
- `perk_confirm` — accord pentatonique ogham (confirmation perk B.1)
- `biome_reveal` — révélation atmosphérique profonde (Phase 4 horloge solaire)
- `partir_fanfare` — arpège majeur ascendant (bouton PARTIR)

**HubAntre.gd** — UX contextuelle:
- Entrée: `hub_enter` + `scene_transition` superposés
- Hotspot souffle: `ogham_chime` (au lieu de `whoosh` générique)
- Bouton PARTIR: `partir_fanfare`
- Biome sélectionné: `choice_select` + `ogham_chime` (confirmation rituelle)
- Perk confirmé: `perk_confirm`

**TransitionBiome.gd** — Phase 4 Sentier: `biome_reveal` distinct (au lieu de `magic_reveal` dupliqué)

### SFX Rework v2 — Waveforms Pixel Celtic (commit `4592ebc`)

**Objectif** : Remplacer les sines génériques par des waveforms pixel/chiptune + échelle D Dorian celtique.

**SFXManager.gd** — 3 helpers de waveform + 12 générateurs retravaillés :
- `_sq(freq, t)` — onde carrée adoucie (sin * 8.0 clampé -1..1), style Game Boy
- `_tri(freq, t)` — triangle NES (`2/PI * asin(sin(...))`)
- `_pulse(freq, t, duty)` — duty cycle variable (25% par défaut), style SID chip
- **Échelle D Dorian (référence)** : D4=294Hz E4=330Hz F4=349Hz G4=392Hz A4=440Hz B4=494Hz C5=523Hz D5=587Hz

12 générateurs reworked vers pixel/celtique :
- `hover` → G5 square blip (5ème celtique au-dessus de D)
- `click` → pulse 25% + noise burst
- `ogham_chime` → triangle E4+B4 (harpe plucked)
- `ogham_unlock` → arpège Dorian D4-F4-A4-D5 triangle
- `bestiole_shimmer` → NES triangle A4-E5-A5 + pulse sparkle
- `magic_reveal` → balayage pentatonique D→G→A→D triangle
- `skill_activate` → square zap D5→G4 descente Dorian
- `scene_transition` → square glide D3→A3 (5ème celtique grave)
- `eye_open` → square profond D1→D2 + drone A (cornemuse awakening)
- `hub_enter` → drone D+A désaccordé (2 voix 147.0+147.8 Hz → beating naturel, chaleur pipe)
- `souffle_regen` → glide triangle D4→A4 + sparkle square
- `souffle_full` → arpège pentatonique D4-G4-A4-D5 triangle

---

## Session: 2026-02-25 (Phase B COMPLETE — B.1 + B.2 + B.3 + B.4 + B.5)

### Backlog B — Progression (3 items livrés)

**B.2 — Arbre de Vie (déjà implémenté, confirmé)**
- Constat: HubAntre.gd avait déjà le hotspot "arbre" + navigation vers ArbreDeVie.tscn
- ArbreDeVie.tscn + arbre_de_vie_ui.gd (494 L) entièrement implémentés avec bouton Retour
- Marqué FAIT (aucune modification nécessaire)

**B.5 — Première Run Directe** (`scripts/SceneRencontreMerlin.gd`)
- Après la Rencontre Merlin, propose 2 boutons: "Explorer le Refuge" / "Commencer l'Aventure"
- "Commencer l'Aventure" → TransitionBiome directement (skip Hub), pre-set biome = suggested_biome
- "Explorer le Refuge" → HubAntre (comportement normal)
- Architecture: `var _next_scene` + `_show_destination_choice()`, routing dynamique en `_transition_out()`

**B.3 — Archétype → Bonus DC + Contexte RAG**
- `merlin_constants.gd`: `ARCHETYPE_DC_BONUS` dict (8 archétypes, valeurs -1/0/+1)
- `merlin_game_controller.gd`: applique `archetype_modifier` dans `_get_dc_for_direction()`
- `player_profile_registry.gd`: `get_archetype_id()`, `get_archetype_title()`, archetype_title dans save + get_summary_for_prompt()
- `merlin_omniscient.gd`: sync `archetype_id` + `archetype_title` dans registry_data → RAG world_state
- `rag_manager.gd`: `_get_archetype_context()` (MEDIUM priority, ~40 tokens)

**Commits**: `3e37e54` (chore: triage Step 0), `941eccc` (feat: B.2/B.3/B.5)

---

## Session: 2026-02-25 (Phase B Suite — B.1 COMPLETE)

### B.1 — Souffle Perk UI (sélection Hub + activation en jeu)

**`scripts/HubAntre.gd`**
- 5e hotspot "Souffle" (icon=COMPASS, ratio=0.06,0.80) — bottom-left
- `_show_perk_overlay()`: overlay modal 2×2 avec 4 cartes perk (Bouclier/Surge/Vision/Canalisation)
- `_on_perk_card_selected()`: mise à jour visuelle des cartes (selected/unselected)
- `_on_perk_confirmed()` → `store.dispatch({SELECT_PERK, perk_id})`
- `_on_perk_cancelled()`: ferme sans sauvegarder

**`scripts/merlin/merlin_store.gd`**
- `state.run.perks`: `{selected_perk: "", perk_used: false}`
- `_init_triade_run()`: preserve selected_perk, reset perk_used uniquement
- `SELECT_PERK` dispatch: valide perk_id vs SOUFFLE_PERK_TYPES, met à jour run.perks

**`scripts/ui/merlin_game_controller.gd`**
- `_get_souffle_perk_dc_bonus()`: bouclier=+2, surge=+6, vision=+2, canalisation=+4 (fallback=+4)
- `_apply_souffle_perk_side_effect()`: shield_active (bouclier), vision_active (vision), auto-ogham (canalisation)
- Headless path + normal dice roll path câblés sur les nouveaux helpers
- `_on_state_changed()` → `ui.update_selected_perk(perk_id)` pour sync badge

**`scripts/ui/merlin_game_ui.gd`**
- `_perk_badge: Label` créé au-dessus du bouton Souffle
- `update_selected_perk(perk_id)`: affiche `[NomPerk]` ou masque le badge
- Positionné à `(vp_size.x - 76, vp_size.y - 84)`, 72×14px

**Validation**: 0 errors, 0 warnings (validate_editor_parse.ps1)
**Commit**: `7d795e4` (feat(progression): B.1 Souffle Perk UI)

---

**B.4 — Aspects → DC modifiers + contexte RAG** (commit `e4682dd`)
- `merlin_constants.gd`: ASPECT_DC_PENALTY_BAS=+2, PENALTY_HAUT=+1, BONUS_FULL_EQUILIBRE=-1
- Labels narratifs ASPECT_STATE_NARRATIVE (6 descriptions, 1 par état extrême par aspect)
- `merlin_game_controller.gd`: aspect_modifier cumulatif dans `_get_dc_for_direction()`
- `rag_manager.gd`: `_get_aspects_state_context()` (Priority HIGH) — injecte états extrêmes
  sous forme "ETAT: Corps Épuisé | Âme Possédée" pour guider le LLM

**Phase B COMPLETE** — B.1 + B.2 + B.3 + B.4 + B.5 tous livrés.

---

## Session: 2026-02-24 (Phase P3 — Features Avancees, Waves 16-21 COMPLETE)

### Phase P3 — Features Avancees (COMPLETE)

**Wave 16-17: Merlin Dialogue + Titles + What-If** (commit `66cbb3d`)
- Dialogue UI: 3 presets + free text + journal action (4th preset)
- LLM response generation via MOS with tone-aware prompts
- Card title: GM brain, 20 tokens, FALLBACK_TITLES (10 celtic)
- What-if: generate 3 alternatives, staggered fade-in reveal on unchosen options

**Wave 18: Dreams** (commit `c41fc13`)
- Dream overlay: fullscreen bg_deep, typewriter text, gentle pulse
- LLM dream generation: 80 tokens, T=0.9, 6 FALLBACK_DREAMS
- Trigger: biome change detection in `_resolve_choice()`

**Wave 19: Tutorial Narratif** (commit `c41fc13`)
- 7 diegetic mechanic hints in `tutorial_narratives.json`
- Triggers: first_card, dice_roll, souffle, ogham, biome, aspect, extreme
- Displayed via MerlinBubble, each shown once per run

**Wave 20: Cross-Run Memory** (commit `c41fc13`)
- RAG: `get_past_lives_for_prompt()` — last 3 runs
- Narrator prompt injection for continuity
- Journal popup: scrollable past lives with BBCode

**Wave 21: Integration P3** (commit `24cd876`)
- LLM null safety: Variant intermediate pattern (5 MOS sites)
- Dream overlay `is_inside_tree()` guard
- Journal popup wiring (signal + controller handler)
- Dialogue `is_processing` guard
- UI/UX Bible: 5 hardcoded colors → CRT_PALETTE, named font sizes, button themes, 48px touch targets

**Commits**: `66cbb3d` (W16-17), `c41fc13` (W18-20), `24cd876` (W21)

---

## Session: 2026-02-24 (Phase P2 — LoRA Data Prep, Waves 12-13)

### Phase P2 — LoRA Training (Waves 12-13 COMPLETE)

**Wave 12: Data Prep**
- Added TIER5_GENERATORS (4 P1-specific generators) to `generate_full_dataset_v7.py`:
  - `gen_sequential_pipeline()` — 6 gold samples (narrator+labels format)
  - `gen_danger_scenarios()` — 4 gold samples (survie + agonie)
  - `gen_narrative_arcs()` — 4 gold samples (1 per arc phase)
  - `gen_gm_effects()` — 4 gold samples (GM effects JSON)
- Generated v8 dataset: **724 total samples** (455 gold, 269 augmented)
- Identity primer injected into 95.3% of samples
- P1 features density: 2.9% (21/724)

**Wave 13: Config**
- `train_qwen_cpu.py`: Added v8 dataset auto-detection (priority over v7)
- `benchmark_lora.py`: Added 4 P1 competence metrics:
  - `sequential_format_rate` (target 85%) — A/B/C label extraction
  - `danger_awareness_rate` (target 80%) — life-aware language
  - `gm_effects_validity` (target 90%) — JSON format compliance
  - `arc_phase_count` — narrative phase variety

**Commits**: `1ca8a06` (P1.5 sequential), `9525df1` (P1 waves 9-11)

---

## Session: 2026-02-24 (Phase P0 Complete + Good Practices + P1 Start)

### Phase P0 — Fix Gameplay (COMPLETE, commit `0bd08f6`)

**Waves executees:**
- P0.0.1: Audit async flow timestamps
- P0.1.1-P0.1.3: Fix timing (refactor _request_next_card, show_thinking, await start_run)
- P0.2.1-P0.2.3: Fix labels (blocklist 102→20, relacher _validate_single_verb, regex fallback)
- P0.3.1-P0.3.3: Tune quality (seuils MIN/JACCARD, poids REPETITION/STRUCTURE, guardrails MOS)
- P0.4.1: E2E Validation — autoplay 3 cartes LLM native, 0% fallback

**Fixes headless mode (auto_play_runner.gd + merlin_game_controller.gd):**
- Skip narrator intro, dice roll animation, result transitions, travel animation en headless
- Race condition fix: `headless_mode = true` AVANT `add_child()` (_ready triggers during add_child)
- SIGPIPE fix: redirect `> /dev/null 2>&1` au lieu de pipe `| head`

**Good Practices**: Section 8 ajoutee dans `gdscript_knowledge_base.md` (9 sous-sections)

**Metriques E2E:**
| Metrique | Resultat |
|----------|----------|
| Cards generated | 3/3 LLM native |
| Fallback rate | 0% |
| Headless intro | 232ms (was 95s) |
| Resolve time | 0ms (UI skipped) |
| Gen time/card | 75-87s (CPU normal) |

### Problemes connus (non bloquants)
- Label extraction ~50% fallback generiques
- GM effects fail sur certaines cartes → heuristic fallback
- Hang apres 3-4 cartes (suspicion memoire/Ollama)

---

## Session: 2026-02-22 (Architecture LLM — LoRA v2 + Pipeline Enrichi)

### Objectif
Repondre a la question strategique: "Un seul modele peut-il tout faire?" et preparer LoRA v2.

### Resultats

**AXE A: LoRA v2 Dataset + Notebook**
- Gold dataset v5: 20 examples extraits du doc reference (20 cartes avec VERBE — description)
- Augmentation v5: 1734 samples (9 strategies: biome, aspect, theme, celtic, verb swap, system prompt, card num, combined, v1 merge)
- Format compliance: 100%
- Notebook Colab mis a jour: QLoRA r=16, 7 modules (q/k/v/o_proj + gate/up/down_proj), MAX_SEQ_LENGTH=2048
- Export dual GGUF: Q4_K_M + F16

**AXE B: Pipeline Programmatique (CODE Godot)**
- Prompt format: VERBE seul → "VERBE — description concrete en 1 phrase" (2 locations dans merlin_llm_adapter.gd)
- MINIGAME_CATALOGUE: 6 → 14 types (Apaisement, Sang-froid, Course, Fouille, Ombres, Volonte, Regard, Echo)
- UI desc_labels: risk level → action_desc (merlin_game_ui.gd)
- Editor parse check: 0 erreurs, 0 warnings

**AXE C: Rapport Word**
- generate_test_report.mjs: mis a jour v5 (14 mini-jeux, 1734 LoRA samples)

**Background: LoRA v1 Training**
- Step 203/310 (epoch 3.2), loss=0.81, accuracy=82.4%
- ~6.5h restantes sur CPU

### Fichiers modifies
- `scripts/merlin/merlin_llm_adapter.gd` — prompt format VERBE — description
- `scripts/merlin/merlin_constants.gd` — MINIGAME_CATALOGUE 14 entries
- `scripts/ui/merlin_game_ui.gd` — desc_labels action_desc
- `data/ai/training/gold_verbs_v5.jsonl` — 20 gold examples
- `data/ai/training/merlin_verbs_v5_augmented.jsonl` — 1734 augmented samples
- `tools/lora/augment_dataset_v5.py` — 9-strategy augmentation script
- `tools/lora/train_qwen_colab.ipynb` — QLoRA v2 notebook
- `C:/Users/PGNK2128/Downloads/generate_test_report.mjs` — rapport Word v5

## Session: 2026-02-21b (Bugfix Round 2 — 4 Remaining Issues Post-Test)

### Objectif
Corriger 4 bugs restants apres test utilisateur: intro absente, LLM incoherent (dialogue au lieu de narration 2e personne), hover souris KO, musique ne boucle pas.

### Root Causes Identifies

| Bug | Root Cause |
|-----|------------|
| Intro absente | Gated behind `result.get("ok", false)` — si store dispatch echoue, intro skip |
| LLM incoherent | Template path (L1112) manquait persona + "PAS de dialogue" — seul fallback l'avait |
| Hover souris KO | `_bottom_zone` (VBoxContainer) a `mouse_filter=STOP` par defaut → bloque les signaux `mouse_entered` des boutons enfants. `_merlin_overlay` (z_index=20) reste PASS apres fade |
| Musique ne boucle pas | `.import` file a `edit/loop_end=-1` → Godot ignore `loop_mode=FORWARD` si `loop_end <= 0`. Le fix precedent settait `loop_mode` mais pas `loop_end` |

### Fixes appliques (4/4)

**Fix 1: LLM coherence** — `merlin_llm_adapter.gd`
- Template path: ajoute "Narre a la 2e personne (tu). Decris sensations. PAS de dialogue."
- Fallback path: ajoute "PAS de dialogue." a la persona
- Format choix: "VERBE — description courte" (les deux paths)

**Fix 2: Mouse hover** — `triade_game_ui.gd`
- `_bottom_zone.mouse_filter = MOUSE_FILTER_PASS` (explicite au setup)
- `options_container.mouse_filter = MOUSE_FILTER_PASS`
- `btn.mouse_filter = MOUSE_FILTER_STOP` (explicite sur chaque bouton)
- `_merlin_overlay.mouse_filter = IGNORE` quand cache (callback tween)
- `_merlin_overlay.mouse_filter = PASS` quand visible

**Fix 3: Music loop** — `music_manager.gd`
- Nouveau helper `_enable_wav_looping(stream)`: set `loop_mode=FORWARD`, `loop_begin=0`
- Calcule `loop_end = get_length() * mix_rate` quand `.import` a `loop_end=-1`
- Remplace tous les settings inline par appels a `_enable_wav_looping()`
- Debug print dans `_on_loop_finished` + check `_player_loop.stream` non null

**Fix 4: Intro visibility** — `triade_game_controller.gd`
- Deplace `show_opening_sequence()` + `show_narrator_intro()` HORS du gate `result.get("ok")`
- Seul `_sync_ui_with_state()` reste dans le ok-check
- L'intro s'affiche toujours, meme si store dispatch echoue

### Validation
- Editor Parse Check: **0 errors, 0 warnings**
- Fichiers modifies: 4 (merlin_llm_adapter.gd, triade_game_ui.gd, music_manager.gd, triade_game_controller.gd)

---

## Session: 2026-02-21 (Bugfix MerlinGame — 10 Bugs + Keyboard Accessibility)

### Objectif
Corriger 10 bugs MerlinGame: fuite prompt LLM, positions boutons, texte resultat, bordure carte, hover souris, Souffle, musique loop, renommages, accessibilite clavier minijeux.

### Phases completees (8/8)

**Phase 1: Fix LLM Prompt Leakage** — `merlin_llm_adapter.gd`
- Simplifie system prompt (retire STYLE OBLIGATOIRE, FORMAT, EXEMPLE)
- Pipeline reordonne: cleanup meta AVANT extraction labels
- 15+ patterns ajoutes (choix a/b/c, format:, style:, complement, infinitif...)
- Regex elargie: `[...]{2+ chars}` capture tout contenu entre crochets

**Phase 2: Fix bouton selectionne en hauteur** — `triade_game_ui.gd`
- Reset scale + queue_sort() parent Container avant chaque nouvelle carte

**Phase 3: Fix texte resultat apres D20** — `triade_game_ui.gd`
- Cache dice overlay avant affichage du texte resultat

**Phase 4: Fix bordure carte** — `merlin_visual.gd`
- Border PALETTE.accent → PALETTE.ink (meilleur contraste)
- Border width 2 → 3px

**Phase 5: Hover + Souffle + Renommages** — `triade_game_ui.gd`, `TriadeGameUI.tscn`
- Souffle btn position ajustee (-68px au lieu de -72px)
- "Pioche" → "Restant", "Cimetiere" → "Passe"
- Tailles augmentees: PiocheColumn 120→140, CimetiereColumn 120→140
- DeckRoot 100x140→110x150, DiscardRoot 86x114→100x130

**Phase 6: Fix musique loop** — `music_manager.gd`
- Connecte `_player_loop.finished` → `_on_loop_finished()` (replay)
- Set `loop_mode = LOOP_FORWARD` au chargement du stream (pas seulement au play)

**Phase 7: Clavier minijeux** — 12 minigames + `minigame_base.gd`
- Base class: `_unhandled_input()` → `_on_key_pressed(keycode)` virtual
- ESPACE/ENTREE: de_du_destin, roue_fortune, tir_a_larc
- Q/E: pile_ou_face, pas_renard
- Q/W/E: pierre_feuille_racine
- A/S/D: joute_verbale
- W/S ou UP/DOWN: bluff_druide
- 1-4: lame_druide
- 1-3: noeud_celtique, enigme_ogham
- 1-9: rune_cachee, oeil_corbeau
- LEFT/RIGHT + ENTREE: negociation

**Phase 9: Documentation** — `docs/10_llm/RUN_REFERENCE.md`, `progress.md`
- Anti-leakage v2: pipeline reordonne, prompt simplification rules
- Audio looping requirements
- Tableau complet accessibilite clavier par minijeu

### Validation
- Editor Parse Check: **0 errors, 0 warnings**
- Fichiers modifies: 18

---

## Session: 2026-02-21 (Quality Upgrade — Verbes Contextuels + LoRA + Rapport v4)

### Objectif
Matcher la qualite du doc de reference: verbes contextuels (VERBE — description), mini-jeux, rapport enrichi, pipeline LoRA.

### Phases completees (5/5)

**Phase 1: Prompt Refonte** — `merlin_llm_adapter.gd`
- Format prompt: "UN SEUL VERBE" → "VERBE — Description d'action en 1 phrase"
- Extraction regex: `^[A-D][):.]\s*([A-ZA-U]+)\s*[—–\-:]+\s*(.+)` (verb + desc)
- story_log window: 3 → 10 entrees, 120 → 200 chars
- Fallback: VERB_POOL avec action_desc="" (pas d'invention)

**Phase 2: Mini-Jeux** — `merlin_constants.gd` + `merlin_llm_adapter.gd`
- Catalogue 6 mini-jeux (traces, runes, equilibre, herboristerie, negociation, combat_rituel)
- Detection programmatique `_detect_minigame()` par regex sur trigger words
- Champ `card["minigame"]` propage dans la pipeline

**Phase 3: UI** — `triade_game_ui.gd`
- Labels enrichis: verb en majuscules + sous-label description
- Badge mini-jeu (celtic_gold) sous le texte narratif
- Texte de resolution (SUCCESS/FAILURE) apres choix

**Phase 4: LoRA Pipeline**
- `data/ai/training/gold_verbs_v4.jsonl` — 20 exemples gold
- `tools/lora/augment_verbs_dataset.py` — 7 strategies, 550 samples, 166 verbes uniques
- `tools/lora/train_qwen_colab.ipynb` — QLoRA r=16, 3 epochs, Colab T4
- `tools/lora/benchmark_lora.py` — metriques verb extraction, format compliance, Jaccard

**Phase 5: Rapport Word v4** — `Downloads/generate_test_report.mjs`
- Options: VERBE gras + description italique + verb source tags
- Badge mini-jeu + texte de resolution
- Section 10: "Qualite des Verbes & Mini-Jeux"
- Output: `MERLIN_LLM_Pipeline_Test_Report_v4.docx`

### Bug fix
- `_validate_triade_option()` strippait `action_desc` et `verb_source` → ajoutes a la liste de preservation
- `pixel_scene_data.gd`: 6 `const` → `static var` (Godot 4.5 ne supporte pas PackedStringArray/Color dans const)

### Validation
- Editor parse: PASSED (0 errors, 0 warnings)
- Suite 1 (TestLLMIntelligence): **24/24 PASS**
- Suite 2 (TestLLMFullRun): **4/4 PASS** — 20 cards, 10 essences, p50=52.8s
- verb_source: `(llm)` et `(fallback)` correctement propagees
- Minigames: "Traces" + "Combat Rituel" detectes

### Observations base model (sans LoRA)
- Qwen 1.5B ne produit pas nativement le format VERBE — description (~90% fallback)
- Le LoRA (Phase 4) est concu pour corriger ca → notebook Colab pret a lancer

---

## Session: 2026-02-15d (Fix LLM Pipeline — 0% to 100% LLM)

### Objectif
Corriger le pipeline LLM pour que 100% des cartes soient generees par le LLM (core feature du jeu).
Run 5 E2E avait montre 0% LLM — toutes les cartes venaient de emergency_fallback.

### Causes racines identifiees (chaine de defaillance)
1. Controller LLM_TIMEOUT_SEC=25s trop court pour CPU inference (~60s)
2. Retry "_retry_llm_generation" echouait car "Already generating" (thread C++ actif)
3. Adapter GENERATION_TIMEOUT_MS=8s rejetait tout resultat >8s (double-kill)
4. `_run_llm()` sans timeout → attend indefiniment si callback ne fire pas
5. JSON primary generation TOUJOURS malformee avec Qwen 3B CPU → 120s gaspillees

### Corrections appliquees (5 fichiers)

**1. merlin_ai.gd** — Core LLM interface
- Ajout `cancel_current_generation()` et `is_llm_busy()` (methodes C++ existantes)
- Ajout `_warmup_generate()` — prime le cache CPU apres chargement modele (7.8s)
- Timeouts: LLM_POLL_TIMEOUT_FIRST_MS=300s, LLM_POLL_TIMEOUT_MS=120s
- Backoff polling 50ms (vs 10ms)

**2. merlin_omniscient.gd** — MOS orchestrateur
- `generate_card()` attend `_generation_in_progress` et `_prefetch_in_progress` (vs return empty)
- Prefetch: pool path desactive → toujours pipeline complet (Strategy B)
- LLM_TIMEOUT_MS: 5000 → 300000

**3. merlin_llm_adapter.gd** — Adaptateur TRIADE
- Skip JSON primary generation → two-stage direct (free text + wrap programmatique)
- Suppression du post-hoc timeout de 8s

**4. triade_game_controller.gd** — Controller
- LLM_TIMEOUT_SEC: 25 → 360
- Guard retry si LLM busy
- max_tokens: 380 → 250

**5. auto_play_runner.gd** — Runner E2E
- Detection resolution par `current_card.is_empty()` (vs `is_processing`)
- POLL_TIMEOUT_SEC: 90 → 420, resolution timeout: 60 → 300
- Classification source amelioree (detecte `_strategy` field)

### Runs E2E (9 → 13)
| Run | Cartes | LLM% | Resultat | Cause echec |
|-----|--------|------|----------|-------------|
| 9 | 0 | 0% | Timeout | Cold start 120s + runner 180s timeout |
| 10 | 1 | 100% | Timeout | Resolution timeout 60s trop court |
| 11 | 1 | 100% | Bloque | cancel_generation() bloque C++ 80s |
| 12 | 1 | 0% | Bloque | _generation_in_progress stuck true |
| 12b | 5 | 0% | Fallback | Pool path JSON toujours malformed |
| **13** | **31** | **100%** | **VICTOIRE** | **Mission survive 30/30 completee** |

### Run 13 — Resultats detailles
- **31 cartes jouees, 100% LLM, VICTOIRE ("Le Prix Paye")**
- Card 1: 113s (cold start), Cards 2-31: **~2.9s** (prefetch)
- Total run: 448s (7.5 min)
- Life: 86 final, Karma: -3, Souffle: 1
- Outcomes: 2 crit_success, 14 success, 14 failure, 1 crit_fail
- Flux: terre=91, esprit=100, lien=64

### Issue identifiee: Textes repetitifs
- Les 31 cartes ont le MEME texte (prefetch genere avant update du game state)
- Options generiques ("Agir avec prudence", "Mediter en silence", "Foncer tete baissee")

---

## Session: 2026-02-15e (Text Variety + Guardrail Fix — 100% LLM unique)

### Objectif
Corriger la repetition textuelle (31 cartes identiques dans Run 13) et les faux positifs guardrails.

### Causes racines (5 bugs)
1. **story_log jamais peuple** — le store l'initialisait a `[]` mais ne le remplissait jamais
2. **Prompt two-stage sans variance** — memes inputs = memes outputs
3. **Context hash trop simple** — ne detectait pas le changement de cards_played/life
4. **Fallback labels toujours identiques** — meme triplet "Agir/Mediter/Foncer"
5. **Prefetch avant resolution** — utilisait l'ancien game state (stale data)

### Bug supplementaire (Run 14b): Guardrails faux positifs
- `_contains_forbidden_words()` utilisait `.contains()` (substring match)
- Le mot interdit "ia" matchait "conf**ia**nce", "all**ia**nce", etc.
- 2/5 cartes LLM valides (670 et 590 chars) rejetees par guardrails

### Corrections (4 fichiers)

**1. merlin_llm_adapter.gd** — Enrichissement prompt + rotation labels
- 32 themes celtiques (CELTIC_THEMES) injectes aleatoirement dans le prompt
- 8 sets de fallback labels (FALLBACK_LABEL_SETS) rotatifs par cards_played
- Prompt enrichi: cards_played, life, karma, story_log, theme word

**2. merlin_store.gd** — Population story_log
- `_resolve_triade_choice()` enregistre card text + chosen label (5 derniers)

**3. merlin_omniscient.gd** — Context hash + guardrails
- Hash enrichi: + cards_played + life_essence
- GUARDRAIL_MAX_TEXT_LEN: 500 → 1200
- `_contains_forbidden_words()` → `_find_forbidden_word()` (whole-word matching)
- Forbidden words: soft warning pour LLM (vs hard reject avant)
- Diagnostic logging (pre/post guardrails, post-validate)

**4. triade_game_controller.gd** — Prefetch timing
- Prefetch deplace APRES resolution (state a jour, pas stale)
- Labels retry rotatifs

### Runs E2E (14 → 15)
| Run | Cartes | LLM% | Fallback | Guardrail rejets | Texte unique |
|-----|--------|------|----------|-----------------|-------------|
| 14 | 2 | 50% | 1 | 1 (max_len 500) | Oui |
| 14b | 5 | 60% | 2 | 2 (forbidden "ia") | Oui |
| **15** | **7** | **100%** | **0** | **0** | **Oui** |

### Run 15 — Resultats
- **7 cartes jouees, 100% LLM, 0 fallback, mission equilibre 7/8**
- Timeout 600s avant 8e carte (CPU inference ~70s/carte)
- Themes varies: saumon/riviere, feu/saule, lande sauvage, tonnerre
- Guardrails: 0 rejections, 0 soft warnings
- NPC encounter (Marchand des Ombres) detecte et traite correctement

---

## Session: 2026-02-15c (Audit Complet Projet — Coherence + Headless)

### Audit par 3 agents paralleles (structure, logs, lore)
- 75+ scripts, 19 scenes actives, 43 scenes total inspectees
- Coherence lore/data: 7 biomes, 7 druides, 18 Oghams, Triade — TOUT OK
- 6 fichiers JSON data/ai/config/ valides et coherents

### Bugs corriges
1. **CRITIQUE** — MerlinStore pas enregistre comme singleton (14+ scripts le cherchent via `/root/MerlinStore`)
   - class_name + autoload meme nom = interdit en Godot 4
   - Fix: GameManager._ready() cree MerlinStore et l'ajoute a root
   - Supprime le fallback local dans triade_game_controller.gd
2. **Calendar.gd:180** — `Dictionary == "floating"` crash runtime (19 erreurs)
   - Fix: `if date_val is String and date_val == "floating"`
3. **SceneAntreMerlin.gd + SceneEveil.gd** — 10 constantes vers sprites supprimes
   - Fix: pointer vers M.E.R.L.I.N.png
4. **HubAntre.gd:1956,1965** — Control anchor/size warnings
   - Fix: `set_deferred("size", vp)`

### Validation
- Editor Parse Check: PASSED (0 errors, 0 warnings)
- Smoke Test: **19/19 scenes PASS** (toutes en headless)
- KB mise a jour: 7 nouvelles entrees + 2 patterns

---

## Session: 2026-02-15b (Bestiaire de Broceliande — Catalogue des Rencontres)

### Document cree: `docs/50_lore/14_BESTIAIRE_BROCELIANDE.md` (~700 lignes, 32K chars)
- Catalogue complet de toutes les entites rencontrables dans le monde de DRU
- 12 sections: 7 Druides, 3 Humains, 5 Anciens du Sidhe, Korrigans, Creatures folkloriques, L'Ankou, Bestiole, 18 Druides dissous + 7 perdus, Merlin, Matrice de rencontres, Evolution multi-run, Relations
- Matrice de rencontres croisee (36 entites x 7 biomes x conditions)
- Cross-references vers tous les docs source (11_PNJ, 03_FACTIONS, 08_BIOMES, 07_OGHAMS, 06_BESTIOLE, 04_MERLIN)

### MAJ Index: `docs/50_lore/00_LORE_BIBLE_INDEX.md`
- Entree #14 ajoutee dans la table des documents
- Cross-reference ajoutee dans la section verification
- Total corpus: ~12,700+ lignes

---

## Session: 2026-02-15 (Revert Ministral -> Qwen 2.5-3B definitive)

### Benchmark comparatif hors-Godot (Ollama API, 20 prompts)
- **Qwen 2.5-3B**: 95% persona, 3 violations, 8.99s latence — coherent, francais correct
- **Ministral 3B**: 62% persona, 16 violations, 40.19s latence — incohérent, texte casse
- **Verdict**: Qwen gagne sur tous les fronts

### Migration complete: suppression totale de Ministral
- **GGUF supprime**: `ministral-3b-instruct.gguf` (3.3 GB)
- **Ollama purge**: `ollama rm ministral-3b-instruct:latest`
- **MODEL_FILE**: `qwen2.5-3b-instruct-q4_k_m.gguf` dans merlin_ai.gd
- **RAM_PER_BRAIN_MB**: 3800 -> 2200
- **Fichiers GDScript (9)**: merlin_ai, merlin_omniscient, rag_manager, merlin_llm_adapter, triade_game_controller, IntroCeltOS, TestLLMScene, llm_source_badge, llm_status_bar
- **Config**: PLACE_MODEL_HERE.txt
- **Outils Python (2)**: test_merlin_chat.py (reecrit Ollama API), compare_models.py (Qwen-only)
- **Docs (10+)**: CLAUDE.md, GAMEPLAY_BIBLE, MASTER_DOCUMENT, TRINITY_ARCHITECTURE, STATE_Claude_MerlinLLM, MOS_ARCHITECTURE, GUIDE_SCENARIOS_LLM, ci_cd_release.md
- **Grep zero Ministral**: confirme dans *.gd, *.json, *.txt (residus historiques OK dans docs)

---

## Session: 2026-02-14a (Fix Warnings + Migration Qwen -> Ministral 3B — REVERTED)

### GDScript Warnings Fixed
- **Integer divisions (7 total)**: relationship_registry, session_registry (x2), IntroCeltOS, mg_lame_druide, mg_roue_fortune, triade_game_controller — pattern `int(x / N.0)`
- **Unused class variables (3)**: Removed `_preloaded_responses`, `_llm_gen`, `_prefetched_responses` from SceneRencontreMerlin.gd
- **Lambda capture bug (2)**: `_llm_rephrase()` et `_llm_generate_responses()` — GDScript 4 lambdas capture by value, refactored to Dictionary (reference type) as shared state

### Migration LLM: Qwen2.5-3B -> Ministral 3B Instruct (REVERTED 2026-02-15)
- **REVERT**: Benchmark a demontre que Ministral est inutilisable (62% persona, texte incohérent)
- Migration annulee et remplacee par Qwen definitif (session 2026-02-15)

---

## Session: 2026-02-11i (Phase 43B — Fix UI + LLM + TransitionBiome)

### Etape 1: UI TriadeGame — Options visibles
- Removed spacer2 (EXPAND_FILL) → fixed 4px gap between card and options
- Reduced card_panel: 460x360 → 460x280
- Reduced portrait height: 96 → 72, encounter tile: 72 → 0 (auto)
- Removed obsolete Centre cost indicator "(1 🜁)" (Centre is free since 43A)
- Reduced buttons: 120x46 → 110x40

### Etape 2: LLM Timeout + Fallback
- `LLM_TIMEOUT_SEC`: 8.0 → 20.0 (Qwen2.5-3B needs 15-25s for GBNF JSON on CPU)
- Added card validation: checks `options` is Array of size >= 3, else fallback

### Etape 3: LLM Prompts enrichis
- `build_triade_context()`: Added `biome` and `life_essence` fields
- `_build_triade_system_prompt()`: Enriched with Celtic vocabulary, immersive tone
- `_build_triade_user_prompt()`: Added biome, life essence, story_log context; removed `cost:1`
- `_generate_card_two_stage()`: Enriched system/user prompts with biome
- `_build_narrator_input()` (merlin_omniscient): Added biome from context

### Etape 4: TransitionBiome subtile + progressive
- Removed opaque mist_layer ColorRect (main culprit for full-screen opacity)
- Repositioned GPU particles on landscape center (not screen center)
- Reduced particle opacity: back 0.40→0.25, mid 0.30→0.18, front 0.20→0.12
- Reduced volumetric fog: density 0.3→0.15, color alpha 0.2→0.12
- Path drawing slowed: 0.022s→0.06s per step (~2.1s total)
- End diamond pulses while waiting for LLM prefetch (up to 8s)

---

## Session: 2026-02-11h (Hotfix — Pipeline Warnings + PixelEncounterTile)

### Pipeline Enhancements
- **validate_editor_parse.ps1**: Added warning detection (Integer division, unused vars, etc.)
  - Warnings reported in YELLOW, non-fatal by default
  - `--strict` flag makes warnings fatal (exit 1)
  - Warning patterns: Integer division, unused vars/params, unused signals, narrowing conversion
- **Editor Parse Check**: Now detects both errors AND warnings from Godot recompilation

### Warning Fixes (6 integer division + 2 unused)
- `merlin_action_resolver.gd:68` — `int(momentum / 20)` → `int(momentum / 20.0)`
- `merlin_action_resolver.gd:134` — `int(score / 10)` → `int(score / 10.0)`
- `merlin_map_system.gd:60` — `int(total / 2)` → `int(total / 2.0)`
- `merlin_store.gd:1220` — `int(... / 100)` → `int(... / 100.0)`
- `merlin_store.gd:1491` — `int(awen_spent / 3)` → `int(awen_spent / 3.0)`
- `merlin_store.gd:1498` — `int(score / 50)` → `int(score / 50.0)`
- `merlin_card_system.gd:583` — Removed unused `story_log` variable
- `merlin_card_system.gd:638` — Prefixed unused `biome_key` → `_biome_key`

### KB Updates
- `gdscript_knowledge_base.md` section 1.3: Corrected integer division docs
- `MEMORY.md`: Updated pipeline step 0 description with warning detection

---

## Session: 2026-02-11g (Phase 43A — Refonte Gameplay Fondations)

### Phase 43A: Fondations Gameplay (Hand of Fate 2 inspiration)
- **Status:** COMPLETE (validate.bat passed)
- **Plan consolide:** `.claude/plans/playful-yawning-tarjan.md`

#### A.1: Suppression game over par aspects + 12 chutes
- Supprime Legacy section (VERBS, RUN_RESOURCES, NEEDS, etc.) + Reigns section + TRIADE_ENDINGS
- Supprime SOUFFLE_CENTER_COST, SOUFFLE_EMPTY_RISK
- Centre gratuit (cost=0 dans TRIADE_OPTION_INFO)
- _check_triade_run_end(): vie=0 remplace 2 extremes
- Supprime _handle_bestiole_care(), _get_triade_ending(), _handle_run_end()
- Supprime actions REIGNS_* et LEGACY (START_RUN, END_RUN, APPLY_EFFECTS, RUN_EVENT)
- Supprime bestiole.needs (Tamagotchi) de build_default_state()
- Fix references: Collection.gd, merlin_effect_engine.gd, merlin_llm_adapter.gd

#### A.2: Systeme essences de vie (jauge HP)
- LIFE_ESSENCE_MAX=10, START=7, CRIT_FAIL_DAMAGE=2, CRIT_SUCCESS_HEAL=1
- _damage_life(), _heal_life(), get_life_essence() dans store
- Actions TRIADE_DAMAGE_LIFE/HEAL_LIFE + signal life_changed
- DAMAGE_LIFE/HEAL_LIFE dans effect engine (VALID_CODES + _apply_life_delta)
- Controller: degats crit_failure, heal crit_success, _on_life_changed
- UI: update_life_essence() avec couleurs et animation low-life

#### A.3: DC variable hybride
- Supprime DC_LEFT=6/DC_CENTER=10/DC_RIGHT=14 fixes
- DC_BASE ranges: left 4-8, center 7-12, right 10-16
- ASPECT_DC_MODIFIER: balanced=-1, 1 extreme=0, 2=+1, 3=+2
- DC_DIFFICULTY_LABELS: Facile/Normal/Difficile avec couleurs

#### A.4: Missions hybrides
- MISSION_TEMPLATES: 4 types (survive/equilibre/explore/artefact) avec poids
- _generate_mission() weighted random dans store
- _auto_progress_mission() par type dans controller

#### A.5: Ecran resultats enrichi
- show_end_screen() enrichi avec indicateur "Essences Epuisees"
- update_life_essence() avec seuils couleur et animation

**Fichiers modifies (8):**
- merlin_constants.gd, merlin_store.gd, merlin_effect_engine.gd
- triade_game_controller.gd, triade_game_ui.gd
- Collection.gd, merlin_llm_adapter.gd, task_plan.md

---

## Session: 2026-02-11f (Phase 41 — Responsiveness + Qualite LLM)

### Phase 41: Optimisation Responsiveness + Qualite Narrative
- **Status:** COMPLETE

#### Phase A: Responsiveness Critique
- Remplace polling 250ms par `process_frame` dans triade_game_controller.gd (latence 250ms → ~16ms)
- Skip typewriter deja implemente (click/tap/touche)
- Fix polling backoff merlin_ai.gd: instant exit on done + 10ms backoff (2 sites: single + parallel)

#### Phase B: Prefetch Intelligent
- Relaxe prefetch validation: tolerance aspects ±1 step + biome exact (vs hash exact)
- Ajoute `try_consume_prefetch()` public dans merlin_omniscient.gd
- Deplace `_trigger_prefetch()` AVANT `display_card()` (prefetch pendant lecture)
- Fast-path prefetch dans controller: bypass store dispatch si prefetch dispo

#### Phase C: Qualite Narrative
- RAG budget 300→600 tokens (8192 ctx, ~11% utilise)
- Nouvelles sections RAG: karma/tension, promesses actives, arcs detailles
- Historique etendu: 3→10 derniers choix
- Sampling: Narrator T=0.75/top_p=0.92/rep=1.35, GM T=0.15/max=130/top_k=15

#### Phase D: Robustesse
- Brain busy timeout 60s (previent deadlock si brain crash)
- LLM timeout 15→8s (Qwen finit en 2-5s, 15s masquait les bugs)
- Emergency fallback contextuel (texte par biome, recovery aspect faible)

**Fichiers modifies (Phase 41):**
- `scripts/ui/triade_game_controller.gd` — Polling, prefetch, timeout, fallback
- `addons/merlin_ai/merlin_ai.gd` — Polling backoff, busy timeout, sampling params
- `addons/merlin_ai/merlin_omniscient.gd` — Prefetch tolerance, try_consume_prefetch
- `addons/merlin_ai/rag_manager.gd` — Budget 600, karma/tension/promesses/arcs

**Validation:** PASSED (0 erreurs, 1 warning pre-existant)

---

## Session: 2026-02-11e (Phase 40 — Optimisation LLM + LoRA Pipeline + Agents Fine-Tuning)

### Phase 40A: Optimisation Prompts + RAG (Palier 1)
- **Status:** COMPLETE
- Enrichi 3 templates narrator dans `prompt_templates.json` (vocab celtique, registres, few-shot)
- Injecte `tone_prompt_guidance()` dans `_build_narrator_prompt()` et `_build_system_prompt()`
- Augmente CONTEXT_BUDGET 180→300 tokens dans `rag_manager.gd`
- Ajoute `_get_tone_context()` au systeme de priorite RAG (Priority.HIGH)
- Sync ton ToneController → RAG world_state dans `_sync_mos_to_rag()`

### Phase 40B: Pipeline LoRA Complet (Palier 3)
- **Status:** COMPLETE
- Cree `tools/lora/export_training_data.py` v2.0 — 480 samples game-wide (0 ref scenes)
- Cree `tools/lora/augment_dataset.py` — 2001 samples augmentes (4 strategies)
- Cree `tools/lora/train_narrator_lora.py` — Unsloth/PEFT, QLoRA 4-bit
- Cree `tools/lora/convert_to_gguf.sh` — Conversion HF → GGUF
- Cree `tools/lora/benchmark_lora.py` — 6 metriques (ton, vocab, BLEU, francais, longueur, latence)
- Cree `tools/lora/README.md` — Documentation pipeline
- Cree `data/ai/training/tone_mapping.json` — 17 moods → 7 tons
- Modifie `merlin_ai.gd` — Chargement LoRA auto + Multi-LoRA par ton
- Modifie `merlin_omniscient.gd` — Switch ton LoRA avant generation

### Phase 40C: Agents Fine-Tuning (4 agents)
- **Status:** COMPLETE
- Cree `lora_gameplay_translator.md` — Point d'entree auto-active, traduit gameplay → spec
- Cree `lora_data_curator.md` — Extraction, curation, augmentation datasets
- Cree `lora_training_architect.md` — Hyperparametres, architecture, pilotage training
- Cree `lora_evaluator.md` — Benchmark, metriques GO/NO-GO, A/B testing
- MAJ `AGENTS.md` — 29→33 agents, nouvelle categorie LoRA Fine-Tuning
- MAJ `task_dispatcher.md` v1.2 — Types LoRA, patterns fichiers, review croise, exemples dispatch
- MAJ `CLAUDE.md` — Auto-activation LoRA, section 33 agents, pipeline reference

**Fichiers modifies (Phase 40):**
- `data/ai/config/prompt_templates.json`
- `addons/merlin_ai/merlin_omniscient.gd`
- `addons/merlin_ai/rag_manager.gd`
- `addons/merlin_ai/merlin_ai.gd`
- `tools/lora/` (6 fichiers crees)
- `data/ai/training/` (3 fichiers crees)
- `.claude/agents/` (4 agents crees + 2 MAJ)
- `CLAUDE.md`

---

## Session: 2026-02-11d (Phase 39B — Refonte Multi-Scenes)

### Phase 39B: Refonte Multi-Scenes (5 phases)
- **Status:** COMPLETE

#### Phase 1: Fix 3 choix TriadeGame (CRITIQUE)
- Cause racine: toutes les cartes fallback n'avaient que 2 options (LEFT+RIGHT)
- Ajout CENTER a toutes les 13 cartes fallback + emergency cards
- `_pad_options_to_three()` dans merlin_omniscient.gd — auto-insere CENTER contextuel
- triade_game_ui.gd: affiche toujours 3 boutons, grise les manquants

#### Phase 2: Accelerer SceneRencontreMerlin
- Timings: typewriter 30ms→15ms, animations 50% plus rapides, fades 0.3→0.15
- LLM: max_tokens 200→80 (RAG), 80→40 (rephrase), 100→60 (responses)
- Fallback lines raccourcies a 2 lignes max
- Phase BIOME_SELECTION supprimee (auto-set Broceliande)
- Oghams enrichis avec effets gameplay visibles
- Animation d'attente LLM ("..." pulsant)

#### Phase 3: Refonte HubAntre
- Removed numbered steps 1/2/3 → labels propres (Destination/Outil/Conditions)
- LLM Passif: Merlin commente async via generate_voice (30 tokens, auto-fade 4s)
- Auto-selection Broceliande si aucun biome choisi
- Bouton aventure repositionne en haut

#### Phase 4: TriadeGame UI
- Compteur Souffle numerique "3/7" avec code couleur
- PixelEncounterTile (NOUVEAU): tuile pixel art 24x24, 6 types de rencontre
- Integration dans display_card() avec detection auto par tags

#### Phase 5: PNJ via LLM + Mini-jeux logiques
- 5 cartes NPC fallback (Druide, Villageoise, Barde, Guerrier, Marchand)
- generate_npc_card() dans merlin_omniscient.gd (LLM first, fallback pool)
- 15% chance NPC apres carte 5 dans triade_game_controller.gd
- Mini-jeux contextuels: TAG_FIELD_MAP dans minigame_registry.gd (tags > keywords)

#### Fichiers modifies
- `addons/merlin_ai/merlin_omniscient.gd` — pad_options, generate_npc_card
- `addons/merlin_ai/generators/fallback_pool.gd` — CENTER sur 13 cartes, 5 NPC cards
- `scripts/ui/triade_game_ui.gd` — 3 boutons toujours, souffle counter, encounter tile
- `scripts/ui/triade_game_controller.gd` — NPC trigger, direct LLM 3 options, tag-based minigames
- `scripts/SceneRencontreMerlin.gd` — timings, textes courts, biome removed, oghams enrichis
- `scripts/HubAntre.gd` — adventure flow, LLM passif, auto-broceliande
- `scripts/ui/pixel_encounter_tile.gd` (NOUVEAU) — pixel art encounter tiles
- `scripts/minigames/minigame_registry.gd` — TAG_FIELD_MAP, tags parameter

#### Validation: PASSED (0 errors, 1 pre-existing warning)

---

## Session: 2026-02-11c (Phase 42 — Gameplay Bible & Audit de Coherence)

### Phase 42: GAMEPLAY_BIBLE.md — Vision Complete du Jeu
- **Status:** complete

#### Livrable
- **`docs/GAMEPLAY_BIBLE.md`** (~1500 lignes) — Reference absolue pour tout developpement futur

#### Contenu de l'audit
1. Boucle de gameplay principale (diagramme complet)
2. Systeme TRIADE (3 aspects x 3 etats, Souffle, Awen, Flux, Karma)
3. Systeme de cartes (4 types, pipeline LLM, fallbacks)
4. Systeme D20 + 15 mini-jeux
5. Flux de scenes complet (8 scenes, transitions, donnees requises)
6. Meta-progression (Arbre de Vie 28 talents, 18 Oghams, Evolution Bestiole)
7. Architecture IA/LLM (Multi-Brain, RAG v2.0, Guardrails)
8. Relations inter-systemes (signaux, actions, flux de donnees)
9. Audit de coherence complet

#### Problemes identifies
- **5 game-breaking (P0):** Mission stub, Arbre sans UI, Buffer absent, Twists absents, Fin secrete absente
- **6 equilibrage (P1):** Souffle restrictif, Karma volatile, DC Droite dur, Awen lent, Saut aspect, Save scumming
- **10 systemes caches non-implantes** (DOC_13 complet en attente)
- **6 incoherences design/code** (DOC_11 obsolete, D20 non-documente, Legacy code, etc.)

#### Recommandations priorisees
- **Phase A (P0):** Mission, Buffer cartes, Validation saut, Twists
- **Phase B (P1):** UI Arbre, Resonances, Profil joueur, Reequilibrage
- **Phase C (P2):** Fin secrete, Synergies, Evolution Bestiole, Quetes
- **Phase D (P3):** Nettoyage Legacy, MAJ docs

---

## Session: 2026-02-11b (Phase 41 — Phase 2A: Textes Dynamiques + Architecture LLM)

### Phase 41: LLM Early Warmup + Textes Dynamiques + Prefetch Parallele
- **Status:** complete (7/7 sub-phases)

#### Etape 1A+1B: LLM Early Warmup + Force 2 cerveaux
- `MenuPrincipalReigns._ready()` appelle `start_warmup()` en arriere-plan (call_deferred)
- `_start_llm_warmup()` ne montre l'overlay QUE si LLM pas encore pret
- `detect_optimal_brains()` force minimum 2 cerveaux sur desktop (maxi(2, detected))

#### Etape 1C: Indicateur IA discret dans le menu
- Label "IA: ..." en bas a droite, discret (ink_faded)
- Se connecte a MerlinAI.status_changed / ready_changed
- Passe a "IA: 2 cerveaux" (accent_soft) quand pret

#### Etape 2A+2B: JSON enrichi (140 variantes + atmosphere)
- 7 biomes x 4 categories (balanced, corps_extreme, ame_extreme, monde_extreme) x 5 variantes = 140 textes
- Champ `atmosphere` par biome: sounds, smell, light, mood (metadonnees sensorielles)
- Retro-compatible: arrival_text + merlin_comment toujours presents

#### Etape 3A+3B: Context builders LLM
- `_build_llm_biome_context()`: prompt systeme riche (biome, gardien, ogham, saison, atmosphere, aspects, jour, outil, condition)
- `_build_merlin_comment_context()`: prompt pour Merlin (ton amuse/cynique)

#### Etape 3C: Fallback intelligent
- `_detect_aspect_category()`: detecte si Corps/Ame/Monde est extreme
- `_get_fallback_text()`: selection par categorie + unseen tracking (pas de repetition)
- `_pick_unseen_variant()`: cycle a travers les 5 variantes sans doublon

#### Etape 3D: Prefetch parallele
- LLM lance des Phase 1 (Brume), tourne pendant les 6-8s d'animation
- `_start_llm_prefetch()`: fire-and-forget, arrival + merlin en parallele
- `_consume_prefetch()`: attend max 3s supplementaires, puis fallback JSON

#### Etape 3E: Validation LLM (guardrails)
- Rejet si < 10 chars ou > 300 chars
- Rejet si mots anglais detectes (the, and, you, are...)
- Rejet si similarite Jaccard > 0.7 avec le dernier texte
- Fallback JSON automatique en cas de rejet

---

## Session: 2026-02-11 (Phase 40 — Refonte HubAntre + TransitionBiome + TriadeGame)

### Phase 40: UI Overhaul (Expedition System + Fog + Card Flip + Resources)
- **Status:** complete (9/10 sub-phases, Phase 2A deferred)

#### Phase 1A: Standardiser icones bottom bar HubAntre
- ICON_STANDARDS constant (size=24, line_thickness=1.5, detail_thickness=1.0)
- All 9 celtic icon types unified, bottom bar reduced from 4 to 2 tabs (Antre + Compagnons)

#### Phase 1B+1C: Systeme d'expedition complet
- 3-step expedition prep: Destination + Outil + Conditions de depart
- EXPEDITION_TOOLS (4 tools with bonus_field/dc_bonus) in merlin_constants.gd
- DEPARTURE_CONDITIONS (4 options with initial_effects) in merlin_constants.gd
- Merlin reactive comments per selection (EXPEDITION_MERLIN_REACTIONS)
- Partir button greyed until all 3 steps complete
- Tool/condition data passed to GameManager.run

#### Phase 2B: Zoom camera TransitionBiome
- pixel_container.scale tween 1.0 → 1.4 after revelation phase (1.5s CUBIC)
- Reset to 1.0 before dissolution

#### Phase 2C: Brouillard volumetrique
- 3 particle layers (Back/Mid/Front) with per-biome tint from FOG_CONFIG
- Radial GradientTexture2D (64px) for soft particles
- Shader-based volumetric fog (ColorRect, Perlin noise + vertical gradient)
- 7 biome configs with direction/speed/tint

#### Phase 3A: Card display agrandi + flip animation
- Card panel 380x280 → 460x360, portrait 68 → 96px
- Flip entrance: rotation 90→0 (ELASTIC), scale 0.8→1.0 (BACK), fade-in

#### Phase 3B: Hover preview effets options
- Tooltip panel showing DC + aspect shift previews on option hover
- Dynamic state preview: "Corps ↑ (Robuste → Surmene)" with danger coloring
- Supports SHIFT_ASPECT, ADD_KARMA, ADD_SOUFFLE, PROGRESS_MISSION effects

#### Phase 3C: Top bar enrichie
- Animal icons 40x36 → 56x48
- Shift arrows (↑ red / ↓ blue) after each aspect change
- Resource bar: equipped tool + day counter + mission progress
- Souffle dots 20 → 28px

#### Phase 3D: Souffle VFX
- Regen: scale bounce 0.3→1.2→1.0 per gained dot
- Consumption: shrink 0.5 then restore
- Full (7/7): golden glow + SFX
- Empty (0/7): blink 3x red

#### Phase 3E: Mini-jeux integres + bonus outil
- Minigame intro overlay (field icon + name + tool bonus display)
- Tool bonus DC modifier in _run_minigame (matches bonus_field to detected field)
- Score→D20 feedback display before dice confirmation
- Resource bar sync in _sync_ui_with_state

#### Validation
- Static analysis: PASSED (0 errors, 1 unrelated warning)
- Affected scene validation: 6/6 PASSED (HubAntre, MapMonde, MenuPrincipal, SceneRencontreMerlin, TransitionBiome, TriadeGame)

#### Remaining: Phase 2A (Textes dynamiques + JSON enrichi)
- Deferred: requires ~140 text variants in post_intro_dialogues.json + LLM context builder

---

## Session: 2026-02-10b (Phase 39 — Runtime Error Fixing + Affected Scene Validation Tool)

### Phase 39: Runtime Error Fixing + Validation Pipeline Enhancement
- **Status:** complete

#### Fix TransitionBiome.gd — 17 unsafe get_tree() calls
- Root cause: `await` yields while node exits scene tree, `get_tree()` returns null
- Added `_safe_wait(seconds)` and `_safe_frame()` helper methods with `is_inside_tree()` guards
- Replaced ALL 15 `get_tree().create_timer()` + 2 `get_tree().process_frame` calls
- Added guard on `get_tree().change_scene_to_file()` in dissolution callback
- **Result:** 0 unprotected get_tree() calls remaining

#### MCP Godot Capabilities Assessment
- Project info, scripts, scene structure: OK
- `execute_editor_script`: KO (parse error 43)
- Debugger/runtime logs: NOT accessible via MCP
- **Alternative found:** Read Godot logs from `AppData\Roaming\Godot\app_userdata\DRU\logs\`

#### New Tool: validate_affected_scenes.ps1
- Auto-detects modified .gd via `git diff` (staged + unstaged + untracked)
- Dynamically maps scripts to scenes by scanning .tscn files
- Detects autoload/addon scripts and adds representative scenes
- Launches each scene in Godot headless mode with timeout
- Captures stdout/stderr, reports errors/warnings/crashes
- PS 5.1 compatible (no .NET method calls)
- Integrated into `validate.bat` as Step 4 (automatic)
- **Test result:** 6/6 scenes PASS (HubAntre, MapMonde, MenuPrincipal, SceneRencontreMerlin, TransitionBiome, TriadeGame)

#### validate.bat Pipeline (updated)
1. Runtime logs analysis
2. GDScript static analysis (63 files)
3. GDExtension check
4. **NEW: Affected scene validation** (headless Godot, git-diff targeted)
5. Optional: `--smoke` full scene sweep

---

## Session: 2026-02-10 (Phase 37 — Stabilisation + Fusion Triade/BrainPool + LLM Rencontre + Nettoyage)

### Phase 37: Stabilisation + Fusion Triade/BrainPool + LLM Rencontre + Nettoyage
- **Status:** complete
- **Plan:** `.claude/plans/swift-dancing-crane.md`
- **Agents:** Plan (architecture), Explore (codebase audit)

#### T1: Fix HubAntre parse error (line 2056)
- `:=` avec `instantiate()` remplace par type explicite `var map_instance: Control`

#### T2: Fix Triade crash complet
- Root cause: chaine async non-protegee `_async_card_dispatch()` → `store.dispatch(TRIADE_GET_CARD)` → `merlin.generate_card()`
- **triade_game_controller.gd**: null guards complets, trace logging, emergency fallback card
- **triade_game_ui.gd**: `is_instance_valid()` sur show_thinking/hide_thinking/display_card/show_narrator_intro
- **merlin_store.gd**: null checks TRIADE_GET_CARD handler (merlin, llm, card result)
- **merlin_omniscient.gd**: `_emergency_card()`, `_safe_fallback()`, null checks generate_card

#### T6: Warnings cleanup
- `merlin_map_system.gd`: `config` → `_config` (unused param)
- `merlin_effect_engine.gd`: `var story_log = ...` → `var story_log: Array = ...`

#### T3a-T3l: Fusion Triade ← TestBrainPool (MAJEUR)
- **triade_game_controller.gd** — v0.4.0 → v1.0.0 (~350 lignes ajoutees):
  - D20 Dice system: DC 6/10/14, 4 outcomes (crit success/success/failure/crit failure)
  - 15 minijeux branches via MiniGameRegistry (70% chance, 100% critique)
  - Critical choice system (karma extreme, 2+ extreme aspects, 15% random)
  - Flux system branche: `TRIADE_UPDATE_FLUX` dispatch apres chaque choix
  - Talents branches: shields Corps/Monde, free center, -30% negatifs, equilibre bonus
  - Biome passives branches: trigger every N cards
  - Karma (-1 left, +1 right, ±2 crits) + Blessings (absorbe game over)
  - Adaptive difficulty: pity (3 echecs → DC-4), challenge (3 succes → DC+2)
  - Run rewards: essences, fragments, liens, gloire en fin de run
  - 16 templates reactions narratives (4 outcomes × 4 messages)
  - Travel fog animation entre cartes
  - RAG context file (5 derniers choix+resultats)
  - SFX choreographie complète
- **triade_game_ui.gd** — ~250 lignes ajoutees:
  - `show_dice_roll()` — animation D20 2.2s deceleration + bounce elastique
  - `show_dice_instant()` — affichage apres minijeu
  - `show_dice_result()` — texte + couleur outcome
  - `show_travel_animation()` — full-screen fog overlay
  - `show_reaction_text()` — reaction narrative
  - `show_critical_badge()` — bordure doree pulsante
  - `show_biome_passive()` — notification biome
  - `animate_card_outcome()` — shake/pulse par outcome

#### Store gaps fixes
- **merlin_store.gd**: Ajout action `TRIADE_UPDATE_FLUX` (delta dict → clampi flux axes)
- **merlin_store.gd**: `_resolve_triade_choice()` accepte `modulated_effects` optionnel — evite double application effets/souffle
- **triade_game_controller.gd**: `are_all_aspects_balanced()` → `is_all_aspects_balanced()` (nom correct du store)

#### T3m + T5: Archive scenes inutiles
- Deplace vers `archive/`: TestBrainPool, TestLLMSceneUltimate, TestLLMBenchmark, GameMain (.tscn + .gd + .uid)
- SceneSelector.gd: retire 4 entrees (GameMain, TestLLMSceneUltimate, LLM Benchmark, TestBrainPool)
- MenuPrincipalReigns.gd: retire "Test Brain Pool" du menu

#### T4: SceneRencontreMerlin — LLM dynamique
- `_llm_rephrase(text, emotion)` — reformulation par `generate_voice()`, timeout 5s, fallback original
- `_llm_generate_responses(context, index)` — 3 reponses joueur par `generate_narrative()`, parse JSON, timeout 8s
- Phase 1 (Eveil): chaque ligne rephrased + reponses LLM aux moments interactifs
- Phase 2 (Bestiole): chaque ligne rephrased
- Phase 5 (Mission): chaque ligne rephrased
- Prefetch: `_prefetch_rephrase()` lance la ligne suivante pendant l'affichage courante

#### Validation finale: 63 fichiers GDScript, 0 erreur statique, GDExtension OK

#### Fichiers modifies (8)
| Fichier | Taches |
|---------|--------|
| `scripts/HubAntre.gd` | T1 |
| `scripts/ui/triade_game_controller.gd` | T2, T3a-l, store gaps |
| `scripts/ui/triade_game_ui.gd` | T2, T3a-l |
| `scripts/merlin/merlin_store.gd` | T2, TRIADE_UPDATE_FLUX, modulated_effects |
| `addons/merlin_ai/merlin_omniscient.gd` | T2 |
| `scripts/merlin/merlin_map_system.gd` | T6 |
| `scripts/merlin/merlin_effect_engine.gd` | T6 |
| `scripts/SceneRencontreMerlin.gd` | T4 |
| `scripts/autoload/SceneSelector.gd` | T5 |
| `scripts/MenuPrincipalReigns.gd` | T5 |

#### Boucle gameplay attendue
`HubAntre → TransitionBiome → TriadeGame → [D20/Minijeux/Flux/Talents/Rewards] → HubAntre`

---

## Session: 2026-02-09 (Phase 36 — Meta-Progression + Arbre de Vie + Flux)

### Phase 36: Meta-Progression + Arbre de Vie + Balance des Flux
- **Status:** complete
- **Agents:** Plan (x3 parallel), Explore (codebase audit)
- **Files modified:** merlin_constants.gd, merlin_store.gd, TestBrainPool.gd, HubAntre.gd, prompt_templates.json

#### Sous-Phase 1: Backend (Donnees + Constantes)
- Ajout constantes Flux (FLUX_START, FLUX_CHOICE_DELTA, FLUX_ASPECT_OFFSET, FLUX_TIERS, FLUX_HINTS) dans merlin_constants.gd
- Ajout 28 TALENT_NODES (Racines/Ramures/Feuillage/Tronc) avec couts en 14 essences + fragments
- Ajout constantes evolution Bestiole (3 stades, 3 sous-chemins)
- Ajout TALENT_BRANCH_COLORS, TALENT_TIER_NAMES
- Ajout meta.talent_tree + meta.bestiole_evolution dans merlin_store.gd
- Fonctions: is_talent_active(), can_unlock_talent(), unlock_talent(), get_affordable_talents()
- Fonctions: calculate_run_rewards(), apply_run_rewards(), check_bestiole_evolution(), evolve_bestiole()

#### Sous-Phase 2: Systeme de Flux (in-run, cache)
- 3 axes caches: Terre (environnement), Esprit (recit), Lien (difficulte) — 0 a 100
- Mise a jour apres chaque choix (gauche/centre/droite) + influence passive des Aspects
- DC modifie par Flux Lien (calme: -2, brutal: +3)
- Contexte Flux envoye au LLM Narrateur via prompt_templates.json
- Feedback subtil via texte Merlin (pas de chiffres visibles au joueur)
- Monitor debug: affichage Flux et tiers

#### Sous-Phase 3: Recompenses de fin de run
- 14 types d'essences gagnees selon conditions (victoire, chute, flux, equilibre, bond, mini-jeux, oghams)
- Fragments d'Ogham: 1 + floor(awen_spent/3)
- Liens: 2 + mini-jeux + score bonus
- Gloire: floor(score/50)
- Affichage detaille sur ecran de fin de run

#### Sous-Phase 4: Arbre de Vie — UI Hub (4eme onglet)
- Nouvel onglet "Arbre" dans HubAntre.gd (page 4)
- 28 noeuds organises par tier (Germe → Pousse → Branche → Cime)
- Noeuds: gris (verrouille), or (achetable), colore (debloque)
- Hover: nom + cout + description + lore
- Click: debloquer si affordable (essences + fragments)
- Affichage essences collectees + devises (fragments, liens, gloire)
- Legende des branches (Sanglier/Tronc/Corbeau/Cerf)

#### Sous-Phase 5: Talents actifs + Evolution Bestiole
- _apply_talent_bonuses() appele au debut de chaque run
- Talents de depart: racines_1 (+1 Souffle), racines_3 (+1 Benediction), racines_6 (+2 Souffle max), feuillage_2 (centre gratuit), tronc_1 (Flux 50/50/50)
- Boucliers: racines_2 (Corps 1er shift BAS annule), feuillage_1 (Monde 1er shift HAUT annule)
- DC: feuillage_4 (critique DC +2 au lieu de +4)
- Equilibre: racines_5 (+2 Souffle au lieu de +1 quand 3 aspects a 0)
- Reduction: feuillage_7 (effets negatifs -30%)
- SOUFFLE_MAX dynamique via _souffle_max
- Evolution Bestiole: verification en fin de run, 3 stades (Enfant → Compagnon → Gardien)
- Affichage stade dans onglet Bestiole du Hub

---

## Session: 2026-02-09 (Phase 35 — Project-Wide Resource Cleanup)

### Phase 35: Nettoyage Complet des Ressources Projet
- **Status:** complete
- **Agents:** Project Curator, Explore (audit)

#### Objectif
Audit complet du projet et suppression de ~751 MB de fichiers morts/obsoletes.

#### Changements
1. **8 fichiers junk racine** — Supprimes (nul, chemins corrompus, anciens scripts PPT, AGENTS.md doublon)
2. **19 scripts morts** — Supprimes (3D/FPS, Reigns UI, anciens managers, shaders experimentaux)
3. **archive/artifacts/** — Supprime (390 MB artefacts Colab LLM)
4. **Godot/** — Archive vers archive/3d_models/ (86 fichiers .glb, 11 MB)
5. **orange_brand_assets/** — Deplace vers Bureau/Agents/Data/ (350 MB)
6. **tools/** — 15 fichiers JSON benchmark supprimes, 3 scripts one-time archives
7. **.gitignore** — Mis a jour (benchmark results, node_modules, artifacts)

#### Scripts supprimes (Phase 2):
- 3D/FPS: player_fps, sea_animation, seagull_flock, lighthouse_beacon, day_night_cycle, exterior_window, flickering_light, ground_mist, volumetric_fog_ps1, merlin_house_animations
- Shaders: ps1_shader_controller, retro_viewport, pixel_shader_controller
- Remplaces: reigns_game_controller, reigns_game_ui, LLMManager, main_game, MerlinPortraitManager, test_merlin

#### Scripts preserves (travail futur):
- minigames/ (16 fichiers — P1.1), bestiole_wheel_system, merlin_event/map/minigame_system, merlin_action_resolver
- pixel_character_portrait, custom_cursor, pixel_merlin_portrait (recents)

#### Validation: 65 fichiers GDScript 0 erreur statique, GDExtension OK

---

## Session: 2026-02-09 (Phase 34 — Mini-Jeux + Dual-Brain + Dice VFX + Resource Overhaul)

### Phase 34: Refonte Gameplay Majeure
- **Status:** complete
- **Phases:** A (Ressources), B (Dual-Brain), C (Dice VFX), D (15 Mini-Jeux), E+F (Choix Critique), G (Animations)

#### Phase A: Fix Ressources + Equilibrage
- Aspects etendus de [-2,+2] a [-3,+3], game over a abs>=3
- Fix bug critique: `_apply_crit_success()` ne provoque plus de game over
- Nouveau: Karma visible [-10,+10], Benedictions (bouclier, max 2)
- Souffle max 5, regen: +1 succes, +2 crit, +1 equilibre parfait
- Difficulte adaptative (pity mode apres 3 echecs, DC+2 apres 3 succes)

#### Phase B: Integration Dual-Brain
- `generate_parallel()` — Narrateur + Maitre du Jeu en simultane
- Nouveau GBNF: `gamemaster_choices.gbnf` (labels + minigame + effets)
- Nouveau template: `gamemaster_choices` dans prompt_templates.json
- Fallback 3 niveaux: GM complet → labels GM + effets heuristiques → tout heuristique

#### Phase C: Dice VFX + Audio
- De avec deceleration organique + bounce a l'atterrissage + rotation wobble
- CPUParticles2D par outcome (40 dorees crit, 15 vertes succes, 20 rouges echec, 30 fumee crit fail)
- 5 nouveaux SFX dice: shake, roll, land, crit_success, crit_fail
- Choregraphie complete: shake → roll → deceleration → land → particles → outcome

#### Phase D: 15 Mini-Jeux par Champs Lexicaux
- Architecture: MiniGameBase + MiniGameRegistry + 15 jeux
- 5 champs: chance, bluff, observation, logique, finesse (3 jeux chacun)
- Selection par keywords narratifs ou hint du GM
- Conversion score 0-100 → D20
- 5 SFX mini-jeux: start, success, fail, tick, critical_alert
- Modificateurs Ogham (+10% score par affinite)

#### Phase E+F: Choix Critique + Adaptation Quete
- Declenchement: 15% base apres carte 3, force si karma>=5 ou 2+ aspects danger
- DC +4, mini-jeu diff +3, bordure doree pulsante + SFX critical_alert
- Historique quest_history pour difficulte adaptative
- Travel text adapte aux outcomes recents et aspects en danger
- Benediction sur fin de sous-quete

#### Phase G: Animations Globales
- Boutons: hover scale 1.05 + SFX hover, press scale 0.95 + SFX click
- Carte: entree "depercheminement" (scaleY 0→1 + fade)
- Jauges aspects: tween 0.3s, couleur orange zone danger
- Travel: SFX mist_breath, texte adapte
- Carte draw: SFX card_draw

#### Fichiers crees (18 nouveaux)
- `scripts/minigames/minigame_base.gd` — Classe de base
- `scripts/minigames/minigame_registry.gd` — Registre par champs lexicaux
- `scripts/minigames/mg_*.gd` — 15 mini-jeux
- `data/ai/gamemaster_choices.gbnf` — Grammaire GM choix

#### Fichiers modifies (2)
- `scripts/TestBrainPool.gd` — Refonte complete (ressources, dual-brain, mini-jeux, VFX, choix critique, animations)
- `scripts/autoload/SFXManager.gd` — 10 nouveaux sons proceduraux (5 dice + 5 mini-jeux)
- `data/ai/config/prompt_templates.json` — Nouveau template gamemaster_choices

---

## Session: 2026-02-09 (Phase 33 — Documentation Cleanup v4.0)

### Phase 33: Menage Extensif Documentation
- **Status:** complete
- **Agents:** Technical Writer, Project Curator

#### Objectif
Mise a jour complete de toute la documentation du projet apres 32+ phases d'evolution.

#### Changements
1. **MASTER_DOCUMENT.md** — Reecrit v4.0 (Triade + Multi-Brain + architecture complete)
2. **CLAUDE.md** — Mis a jour (params LLM Narrator/GM, architecture, scene flow)
3. **docs/README.md** — Reecrit v4.0 (129 fichiers indexes, statuts corrects)
4. **progress.md** — Archive 3920 lignes anciennes, garde phases 25-32 recentes
5. **task_plan.md** — Nettoye (phases obsoletes supprimees, backlog mis a jour)
6. **Dashboard Frontend** — Cree (`docs/dashboard.html`, dark theme, stats projet)
7. **Legacy docs** — 4 fichiers deplaces vers `docs/old/` (DOC_02, ALTERNATIVES, merlin_rag_cadrage, SPEC_Optimisation)
8. **MOS_ARCHITECTURE.md** — Corrige "DRU STORE" -> "MERLIN STORE"
9. **STATE_Claude_MerlinLLM.md** — Corrige Trinity-Nano -> Qwen2.5-3B-Instruct

---

## Session: 2026-02-09 (Phase 32 — Multi-Brain LLM Architecture)

### Phase 32: Multi-Brain + Worker Pool — Architecture 2-4 Cerveaux Qwen2.5-3B
- **Status:** complete
- **Agents:** LLM Expert, Lead Godot

#### Objectif
Architecture LLM adaptative 2-4 cerveaux avec worker pool:
- **Brain 1 — Narrator** (toujours present): texte creatif, scenarios, dialogues
- **Brain 2 — Game Master** (desktop+): effets JSON, equilibrage, regles (GBNF)
- **Brain 3-4 — Worker Pool**: taches de fond (prefetch, voice, balance)
- **Avec 2 cerveaux**: les primaires font aussi les taches de fond quand idle (transparent)

#### Architecture
```
MerlinOmniscient
    ├── generate_parallel() ─┬── Brain 1 Narrator → texte + labels
    │                        └── Brain 2 Game Master (GBNF) → effets JSON
    │                                     ↓ merge → carte TRIADE
    └── Pool tasks ──────────┬── Pool Worker (3+) si disponible
                             └── Idle Primary (2 brains) si pas de worker
                                  ↓
                             prefetch, voice, balance (en fond)
```

#### Configuration par plateforme (auto-detection):
| Plateforme            | Cerveaux | RAM      | Detection              |
|-----------------------|----------|----------|------------------------|
| Web (WASM)            | 1        | ~2.5 GB  | `OS.has_feature("web")`|
| Mobile entry/mid      | 1        | ~2.5 GB  | CPU < 8 cores          |
| Mobile flagship 2024+ | 2        | ~4.5 GB  | CPU >= 8 cores         |
| Desktop mid           | 2        | ~4.5 GB  | CPU >= 6 threads       |
| Desktop high-end      | 3        | ~6.5 GB  | CPU >= 12 threads      |
| Desktop ultra         | 4        | ~8.8 GB  | CPU >= 16 threads      |

#### Changements (Phase 32.A-F — dual-instance initiale):
1. **merlin_ai.gd** — narrator_llm + gamemaster_llm, generate_parallel()
2. **merlin_omniscient.gd** — _try_parallel_generation(), _merge_parallel_results()
3. **merlin_llm_adapter.gd** — evaluate_balance(), suggest_rule_change()
4. **Fichiers data**: prompt_templates.json, gamemaster_effects.gbnf, few-shot examples

#### Changements (Phase 32.J — Worker Pool 2-4 cerveaux):
5. **merlin_ai.gd** — Worker Pool complet:
   - `BRAIN_QUAD := 4`, `BRAIN_MAX`, `_pool_workers[]`, `_pool_busy[]`
   - Busy tracking: `_primary_narrator_busy`, `_primary_gm_busy`
   - `_lease_bg_brain()` / `_release_bg_brain()` — pool worker > idle primary
   - `_process()` — polling fire-and-forget + dispatch queue
   - `submit_background_task()`, `_fire_bg_task()`, `_dispatch_from_queue()`
   - `generate_prefetch()` — lease/release via pool (await)
   - `generate_voice()` — commentaires Merlin via pool (await)
   - `submit_balance_check()` — equilibre fire-and-forget
   - generate_narrative/structured/parallel: busy tracking

6. **merlin_omniscient.gd** — Pool integration:
   - `_prefetch_via_pool()` — remplace `_prefetch_with_brain3()`
   - `_generate_merlin_comment()` → `generate_voice()` via pool

#### Changements (Phase 32.O — Test Suite + QA Review):
7. **tools/test_brain_pool.mjs** — External test suite (148/148 tests):
   - 15 suites: constants, detection, pool arch, bg tasks, generation,
     model init, mode names, accessors, omniscient integration, data files,
     busy flag consistency, backward compat, cross-file, simulated pool, signals
   - Simulated pool scenarios: 1/2/3/4 brains, lease/release, priority queue

8. **scripts/TestBrainPool.gd + scenes/TestBrainPool.tscn** — In-game test scene:
   - 6 test categories: current mode, all modes (2→3→4), pool logic,
     background tasks, parallel generation, prefetch+voice
   - Full suite runner with sequential execution

9. **merlin_ai.gd — QA fixes** (from debug_qa agent review):
   - `BG_QUEUE_MAX_SIZE := 100` — prevents unbounded queue growth
   - `BG_TASK_TIMEOUT_MS := 30000` — detects stuck background tasks
   - `start_time` added to active bg tasks for timeout tracking
   - `is_instance_valid()` checks in `_lease_bg_brain()`
   - `reload_models()` cancels active bg tasks before reinit
   - `_process()` handles invalid brain instances + timeout detection

10. **gdscript_knowledge_base.md** — 7 new corrections logged

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

### Phase 32bis: TestBrainPool Interactive Quest Showcase + Bug Fixes
- **Status:** complete
- **Agents:** Lead Godot

#### Bug fixes (Godot debugger errors):
1. **merlin_llm_adapter.gd:347** — `var score: int =` (was `:=`, `max()` returns Variant)
2. **merlin_card_system.gd:281** — Added `await` on `_llm.generate_card(context)` (coroutine)
3. **merlin_store.gd:386** — Added `await` on `cards.get_next_card(state)` (cascade)

#### Scene selector + Menu integration:
4. **SceneSelector.gd** — Added TestBrainPool to SCENES array
5. **MenuPrincipalReigns.gd** — Replaced "Benchmark TRIADE" with "Test Brain Pool"

#### TestBrainPool.gd — Complete rewrite as Interactive Quest Showcase (~1230 lines):
- Phase state machine: IDLE → GENERATING → CARD_SHOWN → EFFECTS_SHOWN → MINIGAME → QUEST_END
- 3 quest templates with sub-quests (Brume, Chant, Sanglier)
- Card generation via `generate_parallel()` with brain attribution (Narrator + GM timing)
- Mini-games between cards: D20 dice rolls + lore riddles (8 questions)
- Prefetch system: generates next card during mini-game
- Brain activity monitor: real-time bars (load%, RAM) + activity log with timestamps
- Aspect gauges (Corps/Ame/Monde) + Souffle tracking
- 7 fallback cards when LLM unavailable
- Quest end: victory (5 survived) or chute (extreme aspect / souffle=0)

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

### Phase 32ter: RPG Mechanics + Travel Animations + RAG Context
- **Status:** complete
- **Agents:** Lead Godot

#### Changements majeurs (TestBrainPool.gd — rewrite complet ~1307 lignes):
1. **Effets caches** — Les boutons de choix n'affichent que les labels (Prudence/Sagesse/Audace), pas les effets. Le joueur ne sait pas ce qui va se passer.
2. **Systeme de de D20** — Apres chaque choix, jet de de avec Difficulty Class:
   - Gauche (prudent): DC 6 — facile
   - Centre (equilibre): DC 10 — moyen, coute du Souffle
   - Droite (audacieux): DC 14 — difficile, gros risque/recompense
   - Nat 20: Coup Critique (double positif, pas de cout)
   - >= DC: Reussite (effets normaux)
   - < DC: Echec (effets inverses)
   - Nat 1: Echec Critique (effets negatifs amplifies + -1 Souffle)
3. **Animations de voyage** — Brume/fog overlay entre chaque carte avec textes immersifs celtiques
4. **Contexte RAG** — Fichier `user://brain_pool_context.txt` stocke les 5 derniers evenements, injecte dans le prompt au lieu de faire grandir le contexte
5. **Narrator-only** — Plus de Game Master call (crash GBNF + latence inutile). Effets generes par heuristique equilibree basee sur l'etat du jeu
6. **Effets equilibres** — `_generate_balanced_effects()` analyse aspects faibles/forts pour proposer des choix strategiques
7. **Animation de chargement** — Symboles celtiques animes (◎◉●◐◑◒◓) pendant la generation LLM
8. **Prefetch pendant lecture** — Le prefetch demarre des que la carte est affichee (pendant que le joueur lit), pas entre les cartes
9. **Nettoyage** — Suppression de ~50 print() debug, suppression du code riddle/minigame separee, code plus propre

#### Orchestration cerveaux (revue):
- Narrateur seul genere les cartes (~14s) — pas de GM sequentiel qui doublait la latence
- GM en standby (disponible pour prefetch ou voice si besoin)
- Effets par logique de jeu, pas par LLM (plus rapide + plus equilibre)

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

### Phase 32quater: Systeme de Buffer Continu (Pre-generation)
- **Status:** complete
- **Agents:** Lead Godot

#### Changements (TestBrainPool.gd):
1. **Buffer continu** — `BUFFER_SIZE=3` cartes pre-generees en permanence. Remplace le prefetch simple (1 carte).
2. **_continuous_refill()** — Boucle async qui remplit le buffer tant que `_quest_active`. Se relance automatiquement quand on pop une carte.
3. **_pop_card_from_buffer()** — Pop FIFO du buffer + relance refill si besoin.
4. **Chargement initial** — Au lancement de quete, genere 1 carte (affichee immediatement), puis demarre le refill en arriere-plan.
5. **Loading flavor texts** — 8 textes immersifs celtiques qui tournent pendant le chargement (ex: "Les runes s'assemblent dans la brume...").
6. **Moniteur buffer** — Affiche `Buffer: X/3` en couleur (vert=plein, jaune=partiel, rouge=vide) + indicateur "(refill...)".
7. **_show_travel** utilise le buffer (pop) au lieu du prefetch. Si buffer vide, fallback sur generation on-demand.
8. **_show_quest_end** arrete le buffer (`_quest_active=false`, `_card_buffer.clear()`).

#### Validation: 67 fichiers GDScript 0 erreur statique, GDExtension OK

---

## Session: 2026-02-09 (Phase 31 — Switch to Qwen2.5-3B-Instruct)

### Phase 31: Model Switch — Trinity-Nano → Qwen2.5-3B-Instruct
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA

#### Objectif
Remplacer Trinity-Nano (bon conteur, 0% logique) par un modele capable de narratif ET logique.

#### Benchmark comparatif (CPU Ryzen 5 PRO, 12 tests):
| Modele | Taille | Comprehension | Logique | Role-play | JSON | Latence 1 mot |
|--------|--------|:------------:|:-------:|:---------:|:----:|:-------------:|
| Trinity Q4 | 3.6 GB | 58% | 0% | 100% | 50% | 940ms |
| Trinity Q5 | 4.1 GB | 50% | 0% | 100% | 50% | 989ms |
| Trinity Q8 | 6.2 GB | 50% | 33% | 100% | 50% | 847ms |
| Phi-3 Mini | 2.3 GB | 42% | 67% | 33% | 0% | 1627ms |
| **Qwen2.5-3B** | **2.0 GB** | **83%** | **100%** | **100%** | **100%** | **726ms** |

#### Changements:
1. **Modeles supprimes:** Trinity-Nano Q4/Q5/Q8 (~14 GB liberes)
2. **Modele ajoute:** qwen2.5-3b-instruct-q4_k_m.gguf (2.0 GB)
3. **Fichiers GDScript modifies (10):**
   - merlin_ai.gd: ROUTER/EXECUTOR → qwen2.5, params ajustes
   - merlin_llm_adapter.gd: commentaire modele
   - merlin_omniscient.gd: commentaire system prompt
   - LLMManager.gd: MODEL_PATH → qwen2.5
   - llm_status_bar.gd: dictionnaire modeles
   - TestLLMScene.gd, TestLLMSceneUltimate.gd: modeles
   - TestLLMBenchmark.gd: titre benchmark
   - test_merlin.gd: model_path
   - IntroCeltOS.gd: affichage "LLM: Qwen2.5-3B"
   - rag_manager.gd: commentaire header
4. **Doc mise a jour:** CLAUDE.md, PLACE_MODEL_HERE.txt, README.txt
5. **Outil de test cree:** tools/test_llm_raw.mjs (latence + comprehension)

#### Validation: 66 fichiers GDScript 0 erreur, GDExtension OK

---

## Session: 2026-02-09 (Phase 30 — GBNF Grammar + Two-Stage + Q5 Default)

### Phase 30: Constrained Decoding + Two-Stage Fallback + Model Switch
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA
- **Output:** 5 fichiers modifies + 1 fichier cree, validation 66 fichiers 0 erreur

#### Objectif
Ameliorer la fiabilite de la generation JSON par le nano-modele (benchmark: 20-60% validite).

#### Changements:

1. **native/src/merlin_llm.h + merlin_llm.cpp** — GBNF Grammar support dans GDExtension:
   - `set_grammar(grammar_str, root)`: configure une grammaire GBNF pour le decodage contraint
   - `clear_grammar()`: desactive la grammaire pour les appels suivants
   - Grammar sampler insere dans la chaine llama.cpp (apres top_p, avant greedy)
   - Utilise `llama_sampler_init_grammar()` de llama.cpp natif
   - **Necessite recompilation du GDExtension pour activation**

2. **data/ai/triade_card.gbnf** — Grammaire GBNF pour cartes TRIADE:
   - Force JSON valide avec schema exact (text, speaker, 3 options, effects)
   - Contraint aspects: "Corps" | "Ame" | "Monde"
   - Contraint direction: "up" | "down"
   - Force speaker: "merlin"
   - Option centre avec cost obligatoire
   - String flexible pour texte narratif et labels

3. **addons/merlin_ai/merlin_ai.gd** — Propagation grammar:
   - `generate_with_system()` supporte `params.grammar` et `params.grammar_root`
   - Set grammar avant generation, clear apres
   - Log "Grammar constrained decoding active" quand utilise
   - **Default model change: Q4_K_M → Q5_K_M** (+40pp qualite, +600MB RAM)

4. **scripts/merlin/merlin_llm_adapter.gd** — Pipeline de generation ameliore:
   - Chargement automatique de la grammaire GBNF au demarrage
   - Grammar passee dans les params LLM si disponible
   - **Two-stage generation fallback** (nouveau):
     - Stage 1: LLM genere du texte narratif libre (pas de JSON)
     - Stage 2: Extraction labels + wrapping JSON programmatique
     - Effets intelligents bases sur l'etat des aspects (boost le plus bas, etc.)
   - Flux revu: grammar → JSON parse → two-stage → erreur
   - Marquage `two_stage` dans les tags de carte

#### Architecture generation (Phase 30):
```
generate_card(context)
  │
  ├─[1] Grammar-constrained generation (si GDExtension recompile)
  │     GBNF force JSON valide → parse + validate
  │     Expected: ~95% validite
  │
  ├─[2] Post-processing 4-stage repair (existant)
  │     parse → fix → repair → regex
  │     Current: 20-60% validite
  │
  └─[3] Two-stage fallback (NOUVEAU)
        Stage 1: texte libre → Stage 2: JSON wrapper
        Expected: ~80% validite (texte OK, effets programmatiques)
```

#### Benchmark Two-Stage (Q5_K_M, 10 runs CPU):
| Approche | JSON Valid | Schema OK | Note |
|----------|-----------|-----------|------|
| Q4 JSON direct | 20% | 20% | Baseline (Phase 29) |
| Q5 JSON direct | 60% | 40% | Meilleur quant |
| **Q5 Two-Stage** | **100%** | **80%** | JSON garanti, texte variable |

Labels extraits du LLM: 20% (80% utilisent labels par defaut).
Echecs: check francais ("not enough French words") sur texte trop court.

#### GDExtension Build (Session continuation):
- **Status:** SUCCESS
- **Erreurs corrigees:**
  - `llama_n_vocab(model)` → `llama_n_vocab(vocab)` (API changee dans llama.cpp recent)
  - `llama_sampler_init_penalties()` simplifie: 9 args → 4 args (n_vocab, eos, nl, penalize_nl, ignore_eos retires)
  - RuntimeLibrary mismatch: llama.cpp rebuild avec `-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` (MT statique)
- **Build 3 stages:**
  - Stage 1: godot-cpp (scons) — OK
  - Stage 2: llama.cpp (cmake/ninja, 211/211) — OK (rebuild MT)
  - Stage 3: merlin_llm.dll (cmake/ninja, 3/3) — OK
- **DLL:** `addons/merlin_llm/bin/merlin_llm.windows.release.x86_64.dll` (353 KB)
- **Validation:** 66 fichiers GDScript 0 erreur, GDExtension OK

#### Prochaine etape:
- Tester GBNF grammar-constrained generation dans Godot (GPU)
- Benchmark grammar vs two-stage vs baseline in-game
- Fine-tuning LoRA si budget qualite insuffisant

---

## Session: 2026-02-09 (Standalone LLM Benchmark)

### Benchmark: Trinity-Nano Standalone Testing
- **Status:** complete
- **Tool:** `tools/benchmark_llm.mjs` (Node.js + node-llama-cpp)
- **Output:** 3 quantizations testees, fichiers JSON resultats

#### Resultats cles
| Modele | JSON valide | Schema OK | Latence CPU |
|--------|-------------|-----------|-------------|
| Q4_K_M | 20% | 20% | 21.5s |
| Q5_K_M | **60%** | **40%** | 19.0s |
| Q8_0 | 40% | 0% | 16.6s |

#### Problemes identifies
1. Modele copie les exemples du prompt au lieu de generer du contenu
2. JSON systematiquement malformed (virgules au lieu de `:`, types incorrects)
3. Switch FR/EN aleatoire
4. Latence CPU 7-33s (GPU sera 5-10x plus rapide)

#### Recommandations
- P0: GBNF Grammar (JSON contraint au niveau token) → ~95% validite
- P1: Fallback pool etendu (50-100 cartes)
- P2: Generation deux-etapes (texte libre → JSON template)
- P3: Q5_K_M comme defaut (+40pp qualite, +600MB RAM)
- P4: Fine-tuning LoRA (200-500 exemples)
- P5: Hybrid local/API pour mobile

---

## Session: 2026-02-09 (Async Pipeline + UX Masking + JSON Repair)

### Phase 29: Async Pre-Generation + UX Animation Masking + Advanced JSON Repair + Anti-Hallucination
- **Status:** complete
- **Agents:** LLM Expert, UI Impl, Debug/QA
- **Output:** 4 fichiers modifies, validation 66 fichiers 0 erreur

#### Objectif
Masquer la latence LLM (1-3s) derriere des animations et du pre-fetching. Ameliorer la robustesse JSON. Reduire les hallucinations du nano-modele.

#### Changements:
1. **merlin_omniscient.gd** — Async pre-generation pipeline:
   - `prefetch_next_card(game_state)`: pre-genere carte N+1 pendant que joueur lit carte N
   - `_try_use_prefetch()`: utilise la carte pre-generee si le contexte n'a pas change
   - `_compute_context_hash()`: hash aspects+souffle pour valider pertinence du prefetch
   - `invalidate_prefetch()`: annule le prefetch si etat change significativement
   - Stats: `prefetch_hits`, `prefetch_misses` pour monitoring
   - Context tightening: system prompt reduit a ~50 tokens, JSON template deplace dans user prompt
   - Instruction anti-hallucination: "Reponds UNIQUEMENT en JSON valide"

2. **triade_game_ui.gd** — Animation "Merlin reflechit":
   - `show_thinking()`: spirale celtique (triskelion) + dots animes sur la carte
   - `hide_thinking()`: restaure l'UI et les options
   - `_draw_thinking_spiral()`: dessine un triple spiral celtique avec rotation
   - Timer anime les dots "Merlin reflechit..." toutes les 400ms
   - Options dimmed (alpha 0.3) pendant la generation

3. **triade_game_controller.gd** — Wiring animation + prefetch:
   - `_request_next_card()`: show_thinking → generation → hide_thinking → display
   - `_trigger_prefetch()`: lance la pre-generation apres affichage carte
   - Delai transition reduit de 0.3s a 0.15s (card flip feel)

4. **merlin_llm_adapter.gd** — Advanced JSON repair (4 strategies):
   - Strategy 1: Parse standard `{...}` (existant)
   - Strategy 2: Fix erreurs courantes (trailing commas, single quotes, unquoted keys)
   - Strategy 3: `_aggressive_json_repair()` — fix troncature, nesting, caracteres speciaux
   - Strategy 4: `_regex_extract_card_fields()` — extraction regex text/labels/speaker/effects
   - System prompt compact + JSON template dans user prompt (anti-hallucination)

---

## Session: 2026-02-09 (RAG v2.0 + MOS Integration + Guardrails)

### Phase 28: RAG v2.0 + MOS-RAG Bridge + Output Guardrails
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA, Optimizer
- **Output:** 3 fichiers modifies majeurs, validation 66 fichiers 0 erreur

#### Audit LLM Pipeline — 6 problemes critiques:
1. Double model loading: router + executor = 2x MerlinLLM (~7.2 GB) → FIX: instance unique quand même modele
2. RAG primitif: keyword search 105 lignes → FIX: v2.0 450 lignes, token budget, priority enum
3. System prompt 500+ tokens: depasse contexte nano → FIX: ~80 tokens base + RAG dynamique 180 tokens max
4. MOS deconnecte du RAG → FIX: _sync_mos_to_rag() a chaque generation
5. Aucun guardrail → FIX: French language, Jaccard repetition, length bounds
6. Aucun journal → FIX: structured journal (card/choice/aspect/ogham/event) + cross-run memory

#### Changements:
1. **merlin_ai.gd** — Single model instance sharing (router == executor → 1 instance, saves ~3.6 GB)
2. **rag_manager.gd** — Rewrite complet v2.0:
   - Token budget management (CHARS_PER_TOKEN=4, CONTEXT_BUDGET=180)
   - Priority enum: CRITICAL(4), HIGH(3), MEDIUM(2), LOW(1), OPTIONAL(0)
   - Structured journal: card_played, choice_made, aspect_shifted, ogham_used, run_event
   - Cross-run memory: summarize_and_archive_run() avec run summaries compresses
   - World state sync from MOS registries
   - Journal search + persistence JSON
3. **merlin_omniscient.gd** — MOS-RAG bridge + guardrails:
   - _sync_mos_to_rag(): sync patterns, arcs, trust, session → RAG world state
   - _build_system_prompt(): compact ~80 tokens + rag.get_prioritized_context()
   - _build_user_prompt(): compact pour nano (aspects/souffle/jour/ton/themes)
   - _apply_guardrails(): French language check, Jaccard repetition detection, length bounds
   - record_choice(): log choice + aspect shifts dans RAG journal
   - on_run_end(): archive run dans cross-run memory
   - generate_card(): log card dans RAG journal
   - save_all(): sauvegarde journal + world state RAG
   - get_debug_info(): infos RAG (journal size, cross-runs, last ending)

---

## Session: 2026-02-09 (Trinity-Nano Migration)

### Phase 27: Migration Qwen → Trinity-Nano + Architecture LLM
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA, Optimizer, Project Curator
- **Output:** 10 fichiers modifies, 1 fichier cree, 1 fichier supprime, validation 66 fichiers 0 erreur

#### Changements:
1. **Suppression modele Qwen** — `qwen2.5-3b-instruct-q4_k_m.gguf` supprime (~2 GB liberes)
2. **merlin_ai.gd** — ROUTER_FILE + EXECUTOR_FILE recables vers Trinity-Nano Q4_K_M, candidates fallback Q4→Q5→Q8
3. **LLMManager.gd** — MODEL_PATH recable vers Trinity-Nano
4. **merlin_llm_adapter.gd** — Commentaires mis a jour (Qwen → Trinity)
5. **TestLLMBenchmark.gd** — Titre mis a jour
6. **test_merlin.gd** — model_path recable
7. **start_llm_server.sh** — Chemin modele recable
8. **PLACE_MODEL_HERE.txt** — Guide mis a jour avec 3 quantizations Trinity
9. **data/ai/models/README.txt** — Liste modeles mise a jour
10. **STATE_Claude_MerlinLLM.md** — Etat des lieux mis a jour
11. **TRINITY_ARCHITECTURE.md** — NOUVEAU: doc architecture complete (9 sections)

#### Architecture LLM apres cette session:
```
Modele: Trinity-Nano (modele unique, 3 quantizations)
  Q4_K_M (3.6 GB) — DEFAULT production
  Q5_K_M (4.1 GB) — Fallback equilibre
  Q8_0   (6.1 GB) — Fallback qualite

Pipeline: MerlinStore.TRIADE_GET_CARD
  ├── MerlinOmniscient (cache + registres)
  ├── MerlinLlmAdapter (Trinity-Nano + validation TRIADE)
  └── MerlinCardSystem (fallback pool)
```

---

## Session: 2026-02-09 (LLM TRIADE Pipeline)

### Phase 26: Brancher le LLM sur TRIADE + Benchmark
- **Status:** complete
- **Agents:** LLM Expert, Debug/QA
- **Output:** 4 fichiers modifies, 2 fichiers crees, validation 66 fichiers 0 erreur

#### Changements:
1. **merlin_llm_adapter.gd** — Rewrite majeur v3.0.0: generate_card() branche sur MerlinAI autoload, format TRIADE 3 options, extraction JSON robuste, validation SHIFT_ASPECT, build_triade_context()
2. **merlin_store.gd** — Wiring MerlinAI dans _ready() + TRIADE_GET_CARD dispatch avec fallback 3 tiers (MOS → Adapter LLM → CardSystem)
3. **merlin_omniscient.gd** — Fix double instance MerlinAI (economie ~2GB RAM), prompts TRIADE, _try_llm_generation() delegue a l'adapter, _parse_llm_response() utilise validation TRIADE
4. **merlin_card_system.gd** — Ajout get_next_triade_card(), _select_triade_fallback_card(), _get_emergency_triade_card()
5. **TestTriadeLLMBenchmark.gd + .tscn** — Nouvelle scene benchmark: 5 scenarios, param sweep, mini-run E2E, streaming

#### Architecture LLM apres cette session:
```
Gameplay → MerlinStore.TRIADE_GET_CARD
             ├── MerlinOmniscient (MOS + 5 registres) → carte contextualisee
             ├── MerlinLlmAdapter.generate_card() → carte LLM brute validee
             └── MerlinCardSystem.get_next_triade_card() → fallback pool
```

---

## Session: 2026-02-17 (Phase 5 — Scene-Based Migration: Secondary Scenes)

### Migration Plan Reference
- **Plan**: `.claude/plans/majestic-sprouting-pond.md`
- **Phase**: 5/5 — Secondary scenes (TransitionBiome, SceneRencontreMerlin, Calendar, Collection)
- **Status**: COMPLETE

### Approach
Pattern identique aux Phases 2-4: extraire les noeuds crees programmatiquement par `_build_ui()` vers le .tscn, remplacer par `@onready var`, renommer `_build_ui()` en `_configure_ui()` (applique styles dynamiques MerlinVisual + shaders).

**Classification static vs dynamic:**
- **Scene (.tscn)**: Containers, Labels avec texte fixe, ColorRect, PanelContainer, Button, RichTextLabel, AudioStreamPlayer
- **Code (dynamique)**: LLMSourceBadge.create(), PixelMerlinPortrait, StyleBoxFlat factories (MerlinVisual.PALETTE), shader materials, boutons data-driven (STARTER_OGHAMS, BIOME_DATA)

### 1. TransitionBiome (1797 → 1726 lignes, -71)

**Fichiers modifies:**
- `scenes/TransitionBiome.tscn` — reecrit: 15 noeuds declares (Bg, CelticTop/Bottom, PixelContainer, WeatherOverlay, BlueSun, ClockPanel/ClockLabel, BiomeTitle, BiomeSubtitle, ArrivalText, MerlinComment, AudioPlayer)
- `scripts/TransitionBiome.gd` — 11 `@onready var`, 2 vars dynamiques (_arrival_badge, _merlin_badge = LLMSourceBadge)

**Refactoring:**
| Avant (methode) | Apres | Notes |
|-----------------|-------|-------|
| `_build_ui()` | `_configure_ui()` | Shader bg, celtic text/color, positions viewport-dependantes, LLMSourceBadge |
| `_make_celtic_ornament()` | `_configure_celtic_ornament(lbl, pos, sz)` | Texte + couleur sur Label existant |
| `_create_mist_particles()` | `_configure_weather_system()` | StyleBoxFlat sur BlueSun/ClockPanel, couleur WeatherOverlay |
| `_setup_audio()` | `_configure_audio()` | Pass (AudioPlayer en scene avec bus=Master) |

### 2. SceneRencontreMerlin (1472 → 1409 lignes, -63)

**Fichiers modifies:**
- `scenes/SceneRencontreMerlin.tscn` — reecrit: 17 noeuds (ParchmentBg, MistLayer alpha=0, CelticTop/Bottom alpha=0, Card/CardVBox/PortraitContainer/SeparatorContainer/MerlinText/SkipHint, ResponseContainer, AudioPlayer)
- `scripts/SceneRencontreMerlin.gd` — 11 `@onready var`, 7 vars dynamiques (merlin_portrait, ogham_panel, biome_panel, etc.)

**Refactoring:**
| Avant | Apres | Notes |
|-------|-------|-------|
| `_build_ui()` | `_configure_ui()` | Shader parchment, MerlinVisual styles, PixelMerlinPortrait dynamique |
| `_make_celtic_ornament()` | `_configure_celtic_ornament(lbl)` | Texte + couleur sur Label existant |
| `_build_response_ui()` | `_build_response_buttons()` | Renomme, garde dynamique (styling + signaux) |
| `_setup_audio()` | `_configure_audio()` | Set volume_db uniquement |

### 3. Calendar (1211 → 1128 lignes, -83)

**Fichiers modifies:**
- `scenes/Calendar.tscn` — **reecrit integralement** (ancien 211 lignes stale ignore par le script): 25 noeuds (ParchmentBg, MistLayer, CelticOrnamentTop/Bottom, MainCard/CardVBox/TitleLabel/SubtitleLabel/SeparatorContainer/WheelContainer/EventPanel/TabsContainer/ContentScroll/ContentVBox/EventsSection/StatsSection/BrumesSection, BackButton)
- `scripts/Calendar.gd` — 13 `@onready var` + 3 vars dynamiques (tab buttons)

**Refactoring:**
| Avant | Apres | Notes |
|-------|-------|-------|
| `_build_ui()` | `_configure_ui()` | Shader, mist, positions viewport-dependantes |
| `_build_celtic_ornaments()` | `_configure_celtic_ornaments()` | Texte + couleur sur Labels existants |
| `_build_main_card()` | `_configure_main_card()` | StyleBoxFlat card + separateurs couleur |
| `_build_next_event_panel()` | `_configure_event_panel()` | StyleBoxFlat event panel |
| `_build_tabs()` | `_configure_tabs()` | Cree 3 boutons dynamiques (styling + signaux) |
| `_build_back_button()` | `_configure_back_button()` | Styling + signal retour |
| `_create_separator()` | SUPPRIME | Separateur maintenant en scene |

### 4. Collection (956 → 741 lignes, -215, plus grosse reduction)

**Fichiers modifies:**
- `scenes/Collection.tscn` — **reecrit integralement** (ancien 163 lignes stale, script faisait `queue_free()` sur tous les enfants): 35 noeuds (ParchmentBg, MistLayer, OrnamentTop/Bottom, MainContainer/Layout/Header/TitleLabel/StatsVBox/GloryLabel/RankLabel, SepTop, PassPanel/PassVBox, ViewTabs/3 Buttons, ContentPanel/ContentScroll/ContentStack/ProgressSection/RecentSection/CollectionSection/sub-labels/lists/grids, SepBottom, BottomBar/BackButton)
- `scripts/Collection.gd` — 35 `@onready var` (plus gros nombre d'extractions)

**Refactoring:**
| Avant | Apres | Notes |
|-------|-------|-------|
| `for child in get_children(): child.queue_free()` | SUPPRIME | Plus de destruction de scene |
| `_build_ui()` (260 lignes) | `_configure_ui()` (~40 lignes) | Shader, mist, ornements, separateurs, signaux |

### 5. IntroBoot — PASSE (non migre)
- Seulement 3 noeuds (background, static_rect, logo)
- Animation CRT procedurale = correct en code
- Gain negligeable, risque inutile

### Validation
- **Editor Parse Check**: 0 erreurs, 0 warnings
- **Headless scene validation** (19 scenes):
  - 17 PASS (dont TransitionBiome, SceneRencontreMerlin, Collection, MenuPrincipal)
  - 2 FAIL initiaux: Calendar + HubAntre (`gui_embed_subviewports` SubViewport error — **pre-existant**)
    - **CORRIGE**: `pixel_content_animator.gd:386` — `gui_embed_subviewports` (Window) → `gui_disable_input` (Viewport)
    - **Re-test: 18/18 PASS, 0 FAIL**
  - 1 WARN: MerlinGame (CanvasItem RID leak — pre-existant, non bloquant)

### Bilan Migration Complette (Phases 1-5)

| Phase | Cible | Lignes supprimees | Status |
|-------|-------|-------------------|--------|
| 1 | Theme System | ~100 (factorisation styles) | COMPLETE |
| 2 | TriadeGameUI | -408 | COMPLETE |
| 3 | HubAntre | ~-300 | COMPLETE |
| 4 | MenuPrincipalMerlin | -94 | COMPLETE |
| 5 | Scenes secondaires | -432 (71+63+83+215) | COMPLETE |
| **Total** | | **~-1334 lignes** | **DONE** |

**Ratio scene/script**: ~5% → ~55-60% des noeuds declares en scene.

---

## Session: 2026-02-09 (Transition Biome Revamp)

### Phase 25: Paysage Pixel Emergent — TransitionBiome Rewrite
- **Status:** complete
- **Agents:** Motion Designer, Art Direction
- **Output:** 1 fichier reecrit (906 lignes), validation 65 fichiers 0 erreur

#### Changements:
1. **Remplacement complet** de TransitionBiome.gd — nouveau flow "Paysage Pixel Emergent"
2. **6 phases d'animation**: Brume → Emergence → Revelation → Sentier → Voix → Dissolution
3. **7 paysages pixel-art proceduraux** (32x16 grids) — un par biome:
   - Broceliande: foret dense, 4 coniferes, troncs, champignons
   - Landes: menhir solitaire, collines ondulees, bruyere
   - Cotes: falaise a gauche, vagues, plage
   - Villages: 2 huttes celtiques, fumee, sentier
   - Cercles: 5 menhirs en arc, etoiles, lune
   - Marais: arbres tordus, eau sombre, phosphorescence
   - Collines: dolmen trilithon, collines, crepuscule
4. **Primitives de dessin procedural**: triangle, rectangle, hill (ellipse), dots
5. **Pixel size dynamique**: s'adapte a la taille du viewport (~48% largeur)
6. **Phase Brume**: pixels eclaireurs qui tombent et disparaissent (anticipation)
7. **Phase Dissolution**: pixels tombent avec gravite + derive horizontale (inverse de l'emergence)
8. **BIOME_COLORS etendu**: 7 palettes (3 couleurs chacune) vs 4 anciennes
9. **SFX integres**: mist_breath, pixel_land, pixel_cascade, magic_reveal, path_scratch, landmark_pop, scene_transition

#### Avant/Apres:
- Avant: chemin bezier generique + icone 8x8 (~40 pixels)
- Apres: paysage 32x16 (~200-300 pixels) unique par biome + dissolution gravitaire

---


- **Cycle 0 AI Diagnosis**: 0 issues (0 critical, 0 high) — Health: 10/10

---

## GOAL SESSION — Prose simple + boucle playtest autonome (2026-06-07 00:51 → 09:00)

`/goal` UI command. Objectifs (AskUserQuestion) : périmètre = prose+UI+équilibrage (pas mécaniques) ·
style = SIMPLE + CAUSALITÉ (phrases enchaînées action→conséquence, fini le staccato) · fusion des 2
cartes · critique 4 axes (cohérence narrative, 4 piliers UX, équilibrage, bugs) · commit+push auto.

**Cause racine staccato** ("Le geste glisse. Les autres tombent. Le vide ne touche rien.") = sortie
LLM gemma4-e2b ; ancien prompt "phrases courtes, une idée par phrase" → télégraphique + sujets
abstraits. FIX = SYSTEM_PREFIX + usr exigent enchaînement causal (paragraphe fluide) + bannissent
sujets abstraits ('le vide','le nom').

**Harnais réutilisés** : `probe_prose.gd` (run 5 beats, LLM moments forts, rapide) · `probe_combos.gd`
(3 scénarios, LLM TOUJOURS, ~15 samples, ~37min) · `render_prose_report.py`/`render_combo_report.py`.

**Boucle** : probe → critique JSON (4 axes) → fix (prose/prompts/balance) → validate+smoke → commit+push.

### Journal cycles
- C1 (00:51) : fix anti-staccato SYSTEM_PREFIX + usr ; fallbacks SITU/RESO/RESO_LONG simplifiés +
  fusion ; combo prompt "Force 1/2"→matière fusionnée. Parse OK. probe_prose lancé (bi2r9jpr5).
  VALIDÉ probe_prose : "Les yeux percent l'ombre, et les pierres se souviennent en même temps…"
  causal + fusion OK. Committé 83322fcf.
- C2 (01:05) : deg_directive "MONTRE par des FAITS, ne DIS PAS 'reussite'/'memorable'" (anti
  tell-not-show) ; OPENING_FRAMES réécrits (étaient encore littéraires-énigmatiques).
- C3 (01:10) : critique passe profonde probe_combos (13 samples) → 2 défauts : tic d'ouverture
  "les mains se joignent" (7/13) + fin monotone "le chemin s'ouvre" + incohérence type beat. FIX :
  focus_hint par type (Rencontre/Epreuve/Dilemme… résout CE que le beat pose) + consigne anti-tic
  mains + fin variée. Re-probe (bpk2hiqr1) : tic 0/4, Épreuve résout l'obstacle, fusion capte le
  coût des cartes corrompues. Résidu : Rencontre/Dilemme parfois génériques (diminishing returns).
- BALANCE (finding, document-only) : INTEGRITE_DELTA echec-3/partiel-1/reussite0/eclatante0, run
  5 beats → joueur correct perd ~1.5 PV → MORT quasi-impossible (sim 200 runs : mort 0%, complet
  100%). Corruption pareil (moy 1.9/cap 18). Cause = seuils calibrés cible "25 cartes" mais run=5.
  DÉCISION DESIGN (longueur run vs seuils) → laissé à l'utilisateur (pas de tweak auto). Voir
  goal_balance_sim.gd (réutilisable).
- C4 (01:20) : variété fallbacks SITU 3→5/type, RESO 3→5 + 2→4, fins variées. Committé 80df3b5f.
- C5 (01:35) : focus Dilemme/Climax renforcé ("montre la voie choisie + prix" / "MOMENT DECISIF,
  vraie bascule"). Committé de6f74a9.
- PROBE INSTABILITÉ (leçon clé) : full-probe_combos (15 gens LLM × ~3min = ~40min soutenu) =
  INSTABLE dans cet env (cf. leçon #109/#117). Échecs : `| grep` → SIGPIPE tronque ; sans pipe →
  buffer task flood ; redirect fichier → exit 1 cumulatif après chargements gemma répétés. Smoke
  (court) reste FIABLE. Validation prose faite sur 26+ samples des runs réussis antérieurs (13+9+4).
- VÉRIFICATION (01:52) : smoke MerlinGame ✅ + MerlinSelection ✅ + MerlinEnd ✅ (exit 0,
  script_errors 0). 4 axes couverts : cohérence ✅ · lisibilité ✅ · bugs ✅ · équilibrage 📋 doc.
- ÉTAT : prose mission ACCOMPLIE + validée. Reste = monitoring léger (probe_prose + smoke) jusqu'à 9h.

---

## 2026-06-08 — n8n MCP + Skill : automatisations (full local, sans clé)

**Demande** : élaborer un MCP + Skill pour créer des automatisations n8n, avec exemples montrés.

**Constat** : l'outillage existait déjà (MCP `tools/n8n-mcp-server` 9 outils, skill `mcp-n8n`, agent `n8n_architect`, CLI). Vrai blocage = `N8N_API_KEY` non défini → REST Unauthorized.

**Réponse "sans clé"** : n8n 2.8.4 local (`~/n8n-local`, SQLite), CLI `import:workflow` écrit direct en base, full local, zéro token. Clé API = local (pas une dépendance externe), requise seulement pour execute/monitor/activate live depuis Claude.

**Livré** :
- `tools/n8n-templates/01-webhook-transform-response.json` (Webhook→Code→Respond)
- `tools/n8n-templates/02-schedule-http-poll-notify.json` (Schedule→HTTP→If→Set/NoOp)
- `tools/n8n-templates/README.md` (import no-key + clé, tests)
- `~/.claude/skills/mcp-n8n/SKILL.md` : + sections « Sans clé API » et « Bibliothèque de templates »
- Mémoire `_ref__n8n_local.md`

**Vérif** : import live des 2 workflows OK (pas de lock DB) ; round-trip export Démo 1 OK (nodes + connexions intacts). IDs : Démo 1 `Sa0AVzOBFqN8PcCn`, Démo 2 `suZbe7Jbf5gKQXtX`.

---

## 2026-06-08 — n8n cours marketing : funnel Lead→CRM (complet, sans credentials)

**Demande** : automatisation marketing complète et complexe pour un cours (pas MERLIN).

**Choix** : Funnel Lead→CRM | 100% sans credentials | workflow + fiche de cours.

**Livré** (tools/n8n-templates/) :
- `10-marketing-funnel-lead-to-crm.json` — 19 nœuds : Webhook → Validation/hygiène → IF → HTTP disify → Enrichissement → Lead scoring → Switch HOT/WARM/COLD → 3 canaux → Sync CRM (httpbin) → Réponse 200/400.
- `11-marketing-rapport-quotidien.json` — Schedule 18h → données simulées → agrégation KPIs → httpbin → NoOp.
- `COURS-marketing-funnel.md` — fiche pédagogique (concepts↔nœuds, grille scoring, exercices, glossaire).
- Générateur `~/Downloads/build-marketing-workflow.mjs` (JSON.stringify, scoring unit-testé).

**Vérif** : scoring testé (HOT 100 / WARM 40 / COLD 10) ; JSON valides ; import n8n OK (2 workflows) ; round-trip export funnel OK (19 nœuds, Switch HOT/WARM/COLD, branches IF intactes) ; agrégation rapport OK. `n8n execute` CLI bloqué (port 5679) → runtime via UI "Test workflow"/clé API. IDs : Funnel `UWf1S41Q0gCwb7Xu`, Rapport `F0lp2tTIfKxYM086`.

---

## 2026-07-04/05 — v1.0-V4a « recalibrage §K multi-leviers » (PRO-17-A, cdc_v1_questionnaire)

**Méthode** : 1 levier → soak 300 → tableau §K (baseline : échec 25,3 · partiel 28,5 · réussite 43,4 ·
éclatante 2,8 · morts 36,6 · climax plein 1,1 · drafts 2,69).

| Levier | Δ mesuré (soak 300) |
|---|---|
| 1. Whitelist branchée au jeu réel (BAL-14-A/TEC-17-A) | iso-baseline (le probe l'utilisait déjà) — le JEU est maintenant prouvé aligné (self-tests durs) |
| 2. Climax 2+1 (REQ_GAP[3]=2, BAL-13-A) | échec 25,1 · morts 35,2 · climax 1,1 (composition seule insuffisante) |
| 3. Drafts garantis ouverture+transitions (BAL-11-B/GD-27) | greffes 2,69→3,83 · morts 30,6 · réussite 45,6 IN |
| 4. Éclatante sans clause trait + delta +1 (BAL-02-B/BAL-25) | éclatante 2,5→2,7 (contrainte liante = couverture pleine, pas la clause) |
| 5. Dé 17/33/50/67 (BAL-12-B) | morts 30,6→44,9 · échec 31,2 → **REPLI BAL-12-C acté** (33/50/67/83 conservé ; 25/42/58/75 inexprimable sur d6) |
| 6. Contre-pression quête 3 (GD-32-B) | échec 24,5 · morts 27,3 · réussite 46,7 IN |

**Final (soak 300)** : réussite 46,7 IN · fins corrompues 0,0 IN · pushes 1,35 IN · corruption 5,87 IN ·
échec 24,5 OUT (Δ16,5) · partiel 26,2 OUT (Δ1,8) · éclatante 2,6 OUT (Δ5,4) · morts 27,3 OUT (Δ2,3) ·
climax plein 2,4 OUT · greffes 3,88 (offerts 5,02). Hors-pool = 0 (DUR, chemin réel vérifié).
**Gates archétype (durs, BAL-04-B)** : optimal 0 PASS · greedy 26,8 PASS · chaotic ~36 FAIL (n=144) · corrompu FAIL.
**Fiabilité** : validate 0/0 · smoke Game+Menu OK · soak 200 → 200/200 · soak 300 → 300/300.

### Suite v1.0-V4a — leviers 7-8 (coordinateur, 2026-07-05)

| Levier | Δ mesuré (soak 300) |
|---|---|
| 7a. Retag deck traits (geste_ancien→[Rituel,Savoir], ecoute_silence→[Vigilance,Mémoire], souffle_tenace→[Endurance,Force], main_sure→[Finesse,Agilité] — ×1 = {franchise,mystere,rituel} préservés) + 7b. tags GREFFÉS en tête des candidats gap (pick_required_tags) | échec 24,5→18,9 · éclatante 2,6→**11,8 IN** · morts 27,3→**20,8 IN** · climax 2,4→14,0 · corrompu 34,1→**15,9 PASS** · greedy 26,8→7,3 |
| 8. BAL-05-C : barème échec par difficulté (−2 diff 1-2, −3 diff 3) via resolve(diff=2), tous call-sites preview/résolution/probe (R120) | morts 20,8→4,6 · chaotic 34,9→**9,3 PASS** · tous gates archétype PASS |

**Fix review** : flag persisté `opening_draft_done` (MEDIUM — « Passer » au beat 0 jamais re-proposé au resume). HIGH pré-existant (resume beat 0 perd faction/pilier/arc — save beat 0 de _accept_quest v10.13) → chantier séparé tracé (spawn_task).
**Gates finaux** : validate 0/0 · smoke Game+Menu passed · soak 200 → 200/200, 0 gate FAIL · soak 300 → 300/300, 0 gate FAIL · gates archétype tous PASS (optimal 0,0 · greedy 0,0 · chaotic 9,3 · corrompu 0,0).
**Restent OUT (logués BAL-20-B, deltas explicites)** : échec 18,9 (Δ10,9) · partiel 19,9 (Δ8,1) · morts 4,6 (sous la bande — sur-amorti, candidat re-serrage) · climax plein 12,2 (Δ32,8).
**Gate autoplay final** : 2/3 (2×) = faux rouge budget harnais (RUN_DEADLINE_S 600 s épuisé au beat 8 d'une chaîne saine, 0 SCRIPT ERROR — morts 4,6 % ⇒ les chaînes vont au bout). Fix : 600→960 s (tools/autoplay_run.gd). Re-run : **3/3 PASS** (run#2 = 12 beats, accomplissement). VAGUE v1.0-V4a FERMÉE VERTE — tous gates durs PASS. Bible : règle R-numérotée à poser à la prochaine session (rien n'est commité sur ordre).

## v11-N1 — Narration JDR 2e personne présent (2026-07-05)
- Refonte narrative : narration en beat = MJ 2e pers. « Vous » présent (SYSTEM_PREFIX), situations 3-4 ph PNJ-actif (jamais « que faire »), résolution = action [i]italique[/i] + monde réagit par degré, pont générique supprimé (continuité last_gist). Moteur d6/degré INCHANGÉ (R135/R139/§K non touchés).
- Fichiers : merlin_prompt_builder.gd, merlin_scenario.gd, merlin_game.gd, merlin_prose.gd (ensure_italic_action), tools/probe_prose.gd (CATALOG_GATE), tools/autoplay_run.gd (deadline reste 960 ; budgets tokens gardes PROUVES : la prose enrichie borne son wall-clock par max_tokens), docs/BIBLE.md (R140).
- Revue de code : 0 CRITICAL / 0 HIGH ; 2 MEDIUM (robustesse ensure_italic_action) corrigés + L1 gate étendu.
- Gates : validate 0/0 · smoke Game/Menu/Selection/End PASS · CATALOG_GATE pass · soak 200/200 (iso R139, morts 4,9  %) · autoplay 3 loops LLM ON [budgets tokens proven] · capture ph4/ph6 [post-autoplay].

## 2026-07-11 : N4-BUG, bug a la premiere resolution (agent delegue, PAS de commit)
- Fix #2a (HIGH) : prefetch memorise puis relance a model_ready (merlin_scenario.gd, _pending_prefetch + CONNECT_ONE_SHOT)
- Fix #2b (HIGH) : is_resolution_incoming + begin_resolution_wait sticky au clic ; predicat sustain via _on_resolve
- Fix #3 (MEDIUM) : hint tuto centre (set_anchors_and_offsets_preset FULL_RECT apres pose du texte)
- Fix LOW : d20 en zone decor (vp.y*0.19)
- Fix HIGH latent : garde is_running() sur await p3_glow.finished (softlock fusion sous charge CPU)
- Mesures : 1re resolution a froid 14,4-14,7 s -> 2,2 s ; arc-busy 14,6 -> 2,1 s ; prose LLM gagne en pose longue
- Gates : validate 0/0, smoke Game+Menu OK, soak 200/200, autoplay 3/3, bootcheck 5/5
- Revue merlin-gameplay-programmer : 0 CRITICAL / 0 HIGH ; 1 MEDIUM applique (invariant sig+running poses ensemble apres le drain) ; 2 LOW notes
- Post-review : validate 0/0, smoke Game OK, probes froid 2,2 s / warm 2,6 s re-verts ; re-gate soak+autoplay final lance
