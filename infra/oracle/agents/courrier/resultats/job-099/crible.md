# Crible de la VM — 2026-09-06 (s99, deux nuits après le régime)

Méthode : 8 lecteurs (agents, pile du jeu, courrier, studio, prose et LLM, progression et lore,
tests et CI, hygiène des dépôts), chacun contredit par un sceptique qui devait réfuter chaque
constat sur pièces ; 76 constats, 74 survivants, 2 réfutés ; puis synthèse et critique de
complétude. 18 agents, 422 lectures de fichiers, 79 minutes. Le rapport brut de la VM est à
côté (`s99_crible.txt`, URL du tunnel retirée).

## Contre-vérifications de Claude après le crible

Confirmé sur pièces :
- `a_partie_nuit.sh` lance la partie sans `MERLIN_BOT_COUVRANT=1` ; `a_partie_journal.sh:110`
  transmet la variable vide ; `probe_partie_journal.gd:143` ne bascule que sur « 1 » ; job-093
  la posait. `merlin_resolution.gd:42` : DC 9 pour diff 2, donc 28 % de réussite sans tag,
  72 % avec un tag. CIBLE2 mesure les dés, pas le jeu.
- `game-stack.sh:191` écrit `desired=running` pour un harnais ; `a_quete_nuit.sh:29-30` sort 0
  sur « occupé ». `start_native` appelle `stop_native` d'abord : une quête lancée pendant la
  partie la tuerait. La bonne forme est l'enchaînement partie puis quête dans un seul agent.
- `agent-run.sh:39-41` : « déjà en cours » sort 0 sans ligne `rc=`, donc invisible au comptage ;
  `a_ollama_serve.sh:13-15` relance `ollama serve` en `nohup … &` qui hérite du fd 9 du verrou.
- `agents.json:113` dit `enabled: false` pour gd-content-gap (PAUSE du 25/08) ; la surcharge
  `*/30` le réveille 48 fois par jour ; `a_gd_content.sh:3` → `gd/run-gd-agent.sh` sans gates ;
  `router.py:128,135` donnent les fils de nuit à 0-6 h même si le jeu tourne.
- `job-099:65` lit `state/*.run.json`, que `agent-run.sh:74` efface à la fin de chaque course :
  la section « CHAQUE AGENT » était vide par construction. `proposals.py:27` nomme `inbox`, pas
  `pending`.
- `godot-ci.yml:5` du jeu : `branches: [main]`. La branche de travail n'a aucune CI.
- `merlin_run.gd:1191-1194` : le répit ne tombe qu'au changement de quête.
- `merlin_prompt_builder.gd:21-24,89-90,102` : deux biomes aliasés, repli silencieux sur
  Brocéliande, « a Broceliande » dans le préfixe système. Une rotation de biome produirait de
  la prose brocéliandaise sous une autre étiquette. `merlin_menu.gd:818-821` : deux biomes au
  menu.
- `merlin_native.gd:23` : « le PC livre le e2b » ; la nuit mesure le e4b.

Corrigé ou nuancé :
- **[Rectifié par s100 le soir même : FAUX.] native-bench (4 h 25) tourne PENDANT la partie de nuit.**
  L'état réel de l'agent dit « jeu en cours d'utilisation — mesure reportée » à 4 h 25 : le
  harnais ouvre x11vnc, donc `vnc_open` était vrai et la garde tenait. La synthèse avait raison,
  ma contre-vérification avait tort. Le paragraphe d'origine est gardé ci-dessous pour mémoire. Sa seule garde est `vnc_open`
  (`a_llm_native_bench.sh:26-27`), vrai seulement si quelqu'un regarde ; il lance un second Godot
  headless qui charge le e4b (6,1 Go) et génère jusqu'à 12 minutes (`:44-45`). Les beats 11-13
  lents des deux nuits (98-128 s) tombent à ce moment-là, avec gd-content-gap à 4 h 30 en plus.
  La synthèse le croyait reporté ; il ne l'est pas, et sa propre mesure est faussée.
- Le prompt en jeu : les lignes citées (511, 629, 356) n'existent pas dans
  `scripts/llm/merlin_prompt_builder.gd`. « Voyageur » y apparaît aux lignes 108, 220-221, 253
  et 732 : c'est la VOIX DE MERLIN (intros, pitchs, pensées), qui tutoie et apostrophe à
  dessein. Le préfixe des beats (`:102`) vouvoie et interdit la troisième personne. Les quatre
  « le Voyageur » de p74 viennent d'ailleurs : à mesurer sur les chroniques de nuit avant de
  toucher quoi que ce soit.

---

# Crible de la VM, s99 : synthèse

## 1. Ce que la VM a fait en deux nuits

| Nuit | Beats | Au banc | Attente moy. | Partiels | Quête gardée | Smoke |
|---|---|---|---|---|---|---|
| 05/09 | 14, fin mort | 6 | 39 s | 5, tous covNone | non | 1 épreuve rouge |
| 06/09 | 22, fin accomplissement | 8 | 30 s | 6, tous covNone | non | 1 épreuve rouge |

La partie de nuit a tourné deux fois sur deux et la nuit 2 est meilleure sur tout ; le verdict imprime pourtant six « MANQUEE ». Ces nuits ne mesurent ni la prose ni le registre réglé cette semaine : le bot cycle à l'aveugle et l'horaire empile trois agents sur le moteur. La quête de nuit et native-bench n'ont jamais produit, en rc=0. Le rapport lui-même lit à côté : section « CHAQUE AGENT » vide, « en attente : 0 » faux, ollama-serve absent de tous les comptes. L'épreuve rouge, test_ecran_chroniques, est déjà corrigée côté jeu (d2d6261e), la VM le verra à 3h00.

## 2. Pour nos objectifs

**Haute. Le créneau de nuit ne tient pas, et l'annulation sort en vert.** Une partie coûte ≥60 s par beat avant génération (probe_partie_journal.gd:36 `POSE_S = 25.0`, :38 `LECTURE_S = 35.0`) et tient `desired=running` de game-stack.sh:191 jusqu'à a_partie_journal.sh:149 ; à 4h25 native-bench se reporte (a_llm_native_bench.sh:26-27) et à 4h40 la quête s'annule (a_quete_nuit.sh:29-30 `exit 0`). Enchaîner partie puis quête dans un seul agent, tester `harness` + e2e.lock au lieu de `desired`/`vnc_open`, et sortir rc=75 « reporté » pour les douze renoncements en rc=0 (a_partie_nuit.sh:31,51 ; a_smoke_scenes.sh:14).

**Haute. Le bot de nuit joue à l'aveugle : CIBLE2 mesure les dés.** a_partie_nuit.sh:61-62 lance la partie sans `MERLIN_BOT_COUVRANT=1`, a_partie_journal.sh:110 transmet vide, probe_partie_journal.gd:143 ne bascule que sur « 1 » ; avec DC 9 (merlin_resolution.gd:42) la réussite passe de 28 % à 0 tag à 72 % à 1 tag, et tous les jobs témoins p70-p93 posent la variable. Un `export`, et verdict_partie.py:87 dit « NON MESURÉE » quand `choix_du_bot` est absent.

**Haute. gd-content-gap tourne 48 fois par jour contre la PAUSE, sans porte jeu, et le routeur donne 4 fils la nuit.** agents.json:113-114 dit `enabled: false`, la surcharge dit `*/30` et overrides.py:40-43 l'applique ; run-gd-agent.sh:27 n'appelle jamais gates.py ; router.py:128 `night_num_thread if (night or not playing)` et :135 `if playing and not night` exemptent 0-6 h. Maxime a choisi de ne pas couper l'agent : garder la cadence mais l'écrire dans agents.json, appeler gates.py dans run-gd-agent.sh, faire primer `playing` sur `night`, et faire lire à router.game_running la version de gates.py (pgrep, pas seulement le port 5900). Les beats 11-13 lents restent une hypothèse à dater sur la VM.

**Moyenne. ollama-serve est mort depuis deux semaines, et sa mort protège la nuit.** agent-run.sh:39-41 tient le verrou sur le fd 9 ; `nohup ollama serve &` (a_ollama_serve.sh:13-15) l'hérite, chaque réveil dit « déjà en cours » sans `rc=`, invisible au comptage. Vivant, il rechargerait le copilote avec `keep_alive 2h` (a_ollama_serve.sh:30) cinq minutes après le déchargement de a_partie_nuit.sh:42. Fermer le fd dans l'enfant (`9>&-` à agent-run.sh:68), imprimer `rc=75` à :41, et poser la garde harness/nuit AVANT de libérer le verrou.

**Moyenne. Le crible et le rapport du matin lisent à côté.** job-099:65 glob `*.run.json`, l'état de course effacé par agent-run.sh:74 ; :86 lit `pending/` alors que proposals.py:27 nomme `inbox` ; cron.log n'a pas de date (agent-run.sh:86) ; a_daily_report.sh:97-99 et probes.py:608 ignorent `epreuves_echouees` ; a_controle.sh:147 dépose chaque jour un faux retard de facturation depuis que billing est quotidien. Corriger les quatre lecteurs, dater cron.log, lister les agents planifiés absents du comptage.

**Moyenne. Le verdict de nuit est tout-ou-rien et rien ne s'accumule.** verdict_partie.py:28 `CIBLE_S = 20.0` et :86-87 exigent le plein à chaque beat ; relire.py:52-60 attend `n/scene/issue` et n'a jamais lu une partie ; « banc » mélange scène (provenance) et issue (secours), verdict_partie.py:81 dit « ni leur prose », faux ; merlin_scenario.gd:2338 `break` condamne toutes les tranches d'arc après la première abandonnée. Émettre une ligne JSON par nuit (médiane, p90, banc scènes/issues, registre), aliaser six lignes dans relire.py, remplacer le `break`.

**Moyenne. Le prompt en jeu désapprend le registre du générateur.** merlin_prompt_builder.gd:511 nomme « le Voyageur » trois fois, :629 et :356 encore ; p74 en porte quatre dans `resolution`. Six remplacements de chaîne, une ligne REGISTRE dans le verdict.

**Moyenne. La boucle de retour n'archive rien, et l'URL du tunnel est publiée.** courrier-recu.yml:13 n'est enregistré que depuis `main`, où il n'est pas ; job-099:95 écrit l'URL dans le rapport envoyé à :105 et commis (105280ed). Régénérer le tunnel via job-046, ajouter `trycloudflare` à FORME_SENSIBLE, retirer `$URL` de a_tunnel_watch.sh:25, pousser le workflow seul sur main vers une branche `courrier-archive`.

**Moyenne. Aucune CI sur la branche du jeu, et le CI de la VM tue les harnais.** godot-ci.yml:5 `branches: [main]`, 363 commits sans parse check, runs annulés par :21 `timeout-minutes: 10` à cause de :34 `--editor` ; a_ci_commit.sh:49-54 fait `restart` sans lire `harness` ; a_smoke_scenes.sh:34 liste les épreuves en dur et :23-24 confond `--quit-after` (itérations, native-inner.sh:87-89) avec des secondes. Différer la synchro sous harnais, glob `test_*.gd`, capturer rc et durée par scène.

**Basse. Fine-tuning parquée mais mal étiquetée.** train_colab.py:169 lit `messages`, convert_to_gguf.sh:23 dit Qwen, README.md:53 promet un adapter que le natif ne charge pas. Corriger le README, écrire le convertisseur de 20 lignes, attendre un GPU.

**Hygiène.** CLAUDE.md:21,146,157-158,213,519 décrit un jeu mort et des rituels inexécutables ; un schéma NPS Orange est commis sur les deux branches et sur main ; flight-tracker.yml:24 tourne chaque matin depuis main ; vm-run.yml:56 porte l'IP en dur ; un seul dépôt, `main` morte depuis le 10/08.

## 3. Pour le jeu

**Haute. La mort à 14 beats est structurelle.** Le répit ne se déclenche qu'au changement de quête (merlin_run.gd:1191-1194) et build_quest_beats pose `quest: 0` partout ; à 1 tag couvert, 19 % de morts à 14 beats, 54 % à 22. gd-run juge une chaîne de quêtes (probe_soak.gd:1371-1382) que le jeu ne joue plus, sa gate :447 est verte pour rien. Ne pas incrémenter `quest` (il pilote dc_ramp) ; répit par Rencontre, test_progression.gd, `_skel` sur build_quest_beats.

**Moyenne. Les chapitres sont derrière un verrou déclaré, et la nuit reste mono-chapitre, mono-biome.** merlin_game.gd:2964 passe chapitre `""`, merlin_quete.gd:16 le dit ; a_quete_nuit.sh:51-52 ne pose pas MERLIN_CHAPITRE que generer_quete.gd:79 lit ; la partie tourne toujours en forêt (a_partie_journal.sh:97/106). Rotation `date +%j % 12` pour biome et chapitre ; ne jamais déduire le chapitre du biome (R181). hauts_faits.json:36 ment : pilier_favors existe (merlin_run.gd:1449), pas persisté.

**Moyenne. Deux formats de quête disjoints.** generer_quete.gd:458 écrit dc/at/de/rune, merlin_scenario.gd:1867 joue required_tags ; corpus sur 5 biomes sur 12. L'importateur est le chantier d'une semaine, après le bot couvrant.

**Moyenne. Trois défauts de prose visibles par le joueur.** parse_arc (merlin_prose.gd:143-158) laisse fuir les numéros d'étape, 7 beats sur 20 à p74 ; le Climax re-sert la dernière scène écrite (merlin_scenario.gd:1749-1750), copie du beat 16 au beat 22 ; la liste de figures de l'arc est Brocéliande-only (merlin_prompt_builder.gd:424-429) alors que data/figures n'est lu que par generer_quete.gd:844-854.

**Basse. Effets de bord non figés.** settle_debt `maxi(0, gwenneg - prix)` (merlin_run.gd:1449) rend la Promesse gratuite à bourse 0 ; merlin_journal.gd:210 réécrit la chronique en WRITE sans rename ; « reprise » atterrit dans le champ chapitre (merlin_run.gd:1611).

## 4. À faire cette semaine

1. **a_partie_nuit.sh** : `export MERLIN_BOT_COUVRANT=1`, rotation MERLIN_BIOME et MERLIN_CHAPITRE, capturer la sortie de la partie dans `$GARDE/partie.log`, appeler a_quete_nuit.sh après la partie ; **agents.json** : native-bench à 6h00. Heures. Mesure : demain, `~/.cache/merlin-quete/nuit/<date>` existe, le verdict ne dit plus covNone.
2. **agent-run.sh** : `9>&-` à :68, `rc=75` à :41, date à :86 ; **a_ollama_serve.sh** : ne pas réchauffer si `harness` non vide ou entre 2 h et 6 h ; job Courrier `rm ollama-serve.lock`. Heures. Mesure : `[ollama-serve]` dans cron.log, zéro « rechargé » entre 4 h et 6 h.
3. **job-099** : glob `state/*.json` hors `.run.json`, `inbox`, état du tunnel sans URL ; **a_courrier.sh** : `trycloudflare` dans FORME_SENSIBLE ; relancer job-046. Minutes. Mesure : s100 montre last_run et summary de quete-nuit.
4. **run-gd-agent.sh** appelle gates.py ; **router.py:128,135** `playing` prime ; cadence dans agents.json, surcharge retirée. Heures. Mesure : cron.log dit « jeu en cours » à 4h30, b11-b13 sous 60 s.
5. **verdict_partie.py** `--json` vers nuits.jsonl et « NON MESURÉE » sans choix_du_bot ; **relire.py** alias index/narration/resolution ; **tools/tests/test_progression.gd** et `_skel` sur build_quest_beats. Jour. Mesure : deux lignes de série après deux nuits, gd-run rouge sur la mortalité, ce qui est la mesure cherchée.

## 5. À ne pas toucher

La chaîne harnais : posée game-stack.sh:130, effacée :156, lue par a_game_idle.sh:80-84 et a_game_watchdog.sh:25-28 ; la cause des six morts de l'été est fermée par construction. Le remplacement d'inode du verrou a_partie_journal.sh:43-60, à copier, pas à réinventer. a_courrier.sh : `.fait` avant exécution (:43), canari trois instances, filtre de forme. overrides.py comme mécanisme ; gates.py comme primitive. merlin_resolution.gd, N_CTX 2048, tête stable du prompt et préfixe KV, POSE_S/LECTURE_S : ils ne sont pas la cause des nuits. curated_corpus ignoré par git (.gitignore:464), sinon tools-autosync casse. docs/README.md et troupe.json comme cartes d'autorité.

## 6. Idées reçues écartées

- Le keepalive ne rend pas une mort du Studio muette : a_tunnel_watch.sh:30 sort rc=1 en dix minutes.
- « L'argent est mort » : décidé et livré (bc108016), la vente à l'étal paie ; seule la Promesse gratuite survit.
- CIBLE3 n'est pas hors de portée : 15 beats sur 22 tiennent 20 s la nuit 2 ; c'est le tout-ou-rien qui est faux.
- LORE_CANON et « huttes de chaume » ne sont pas dans le prompt d'issue depuis v42.1 ; scene_jit n'a aucun appelant.
- gd-content-gap ne recharge pas e4b à froid : a_ollama_idle le garde résident 24/7.
- Il n'y a pas deux dépôts : un seul remote, deux branches, et `main` en est une troisième, morte.

---

## Critique de complétude — crible s99

### 1. Questions de Maxime encore faibles
- **« Pour le jeu »** : la synthèse juge la prose et la mortalité, mais jamais **ce que le joueur peut atteindre**. Le menu n'offre que 2 biomes (`merlin_menu.gd:818-821` `BIOME_CARDS` = foret, falaises), le décor n'en connaît que 2 (`merlin_scene_art.gd:103-108` « démo 2 BIOMES »), alors que `data/quete/chapitres.json` place 10 chapitres sur 12 ailleurs (ys, mont, marche, archipel, village, chateau, ile, souterrain, landes, cairn). Le verrou des chapitres (constat F) est doublé d'un verrou UI que personne n'a nommé.
- **Quelle machine est la cible ?** La nuit mesure e4b sur VM ; le PC joue e2b (`merlin_native.gd:21-25` « le PC livre le e2b »). Aucune nuit ne mesure le modèle que Maxime joue.
- **GPU** : « attendre un GPU » est trop faible — `tools/lora/remote_kaggle_train.py:1-6` est un orchestrateur Kaggle (GPU gratuit) déjà écrit, verrouillé Qwen (`train_colab.py:249` `MODEL_NAME = "Qwen/Qwen3.5-2B"`).
- **Capacité inutilisée** : charge 0.10, 15 Go libres ; une partie de jour gatée par `gates.chain_allowed()` doublerait les points de mesure. Non proposé.

### 2. Non lu par personne
- **La chaîne du matin** : `a_mesures.sh:16-33` relève `balance.cards` depuis `analyzers/balance.py:31-35` (corpus + `fastroute_cards.json`, jeu mort) ; `journal.py` et `journal_plume.py:166` (« compte rendu de la nuit », LLM 5h50) ne lisent jamais `merlin-partie/nuit` (`grep -ln merlin-partie tools/gd_agents/journal.py` → rien) ; `design_council.py:38-48` (LLM 6h40) ne lit que `memory.digest`. Deux appels LLM par matin sur un jeu mort, zéro sur la partie de la nuit.
- `merlin_menu.gd`, `merlin_scene_art.gd`, `data/quete/chapitres.json`, `tools/lora/remote_kaggle_train.py`, `tools/cockpit/control_loops.py` (appelé par `a_corpus_night.sh`), `game-stack.sh:176-183` `require_import`.

### 3. À vérifier SUR LA VM (job Courrier)
| Supposition | Commande |
|---|---|
| quete-nuit annulée par `desired=running` | `grep -a '\[quete-nuit\]' ~/.cache/merlin-agents/cron.log \| tail -4; cat ~/.cache/merlin-agents/state/quete-nuit.json` |
| Durée réelle partie-nuit (2 boots : sélection + partie, sortie jetée `a_partie_nuit.sh:58,62`) | `python3 -c "import json;d=json.load(open('$HOME/.cache/merlin-agents/state/partie-nuit.json'));print(d['last_run'],d['duration_s'],d['summary'])"` |
| Verrou ollama-serve tenu par `ollama serve` | `ls -l /proc/$(pgrep -x ollama\|head -1)/fd \| grep ollama-serve; cat ~/.cache/merlin-agents/state/ollama-serve.json` |
| Rechargement e4b à 4h10 (b2 = 68-71 s) | `grep -a 'loading\|runner' ~/.cache/ollama-serve.log \| grep ' 04:0\| 04:1' \| tail -5` |
| Le bot n'a pas joué couvrant | `grep BOT ~/.cache/merlin-partie/nuit/*/verdict.txt` (job-099:43 ne grep que `CIBLE`) |
| Arc jamais écrit (banc terminal) | `python3 -c "import json,glob;[print(f,[b.get('provenance') for b in json.load(open(f))['beats']]) for f in glob.glob('$HOME/.cache/merlin-partie/nuit/*/journal.json')]"` |
| Ollama à 4 fils pendant la partie | `grep -a 'num_thread' ~/.cache/merlin-agents/cron.log \| tail -6` (router.py:201 sur stderr) |
| n_ctx réel | `grep -a 'n_ctx=' ~/.cache/merlin-game/godot.log \| tail -2` |

### 4. La chose manquée
La recommandation « rotation `date +%j % 12` pour biome » (§3 et §4.1) est un piège : `merlin_prompt_builder.gd:21-24` n'aliase que `foret`/`falaises`, et `:90` `BIOMES.get(cle, BIOMES["foret_broceliande"])` **retombe en silence sur Brocéliande** ; `SYSTEM_PREFIX:102` dit « a Broceliande » pour tout biome. Dix nuits sur douze produiraient de la prose brocéliandaise étiquetée « village » ou « ys » — le champ absent qui échoue en silence, version biome. Rotation à 2 valeurs tant que `BIOME_ALIAS` n'en porte pas 12.
