# M.E.R.L.I.N.: Le Jeu des Oghams - Index de Documentation

**Version**: 4.0 (Triade + Multi-Brain + Documentation Complete)
**Derniere mise a jour**: 2026-02-09
**Mainteneur**: Technical Writer Agent

---

## Vue d'ensemble du Projet

**M.E.R.L.I.N.: Le Jeu des Oghams** est un jeu narratif roguelite de style JDR Parlant developpe avec Godot 4.x. Le joueur incarne un druide guide par Merlin, un narrateur omniscient genere par LLM local (Qwen2.5-3B-Instruct), accompagne de Bestiole, un compagnon mystique qui offre des skills passifs (les 18 Oghams).

Le coeur du jeu est un **"JDR Parlant"** ou:
- **Merlin narre** des histoires generees dynamiquement par LLM local
- **Le joueur decide** via 3 choix par carte (Gauche / Centre payant / Droite)
- **Le LLM genere** les scenarios, retournements et consequences
- **Le systeme Triade** gere 3 Aspects (Corps/Ame/Monde) avec 3 etats discrets

Chaque partie (run) est une quete: maintenir 3 Aspects en equilibre. Si 2 aspects atteignent un extreme, le run se termine avec l'une des 12 chutes. Le joueur gere son Souffle d'Ogham (max 7) pour acceder aux options Centre payantes.

### Systeme de jeu
| Element | Detail |
|---------|--------|
| Aspects | Corps (Sanglier), Ame (Corbeau), Monde (Cerf) |
| Etats | Bas / Equilibre / Haut (3 discrets, pas de jauges) |
| Options | 3 par carte (Gauche, Centre payant, Droite) |
| Fins | 12 chutes + 3 victoires + 1 secrete |
| Souffle | Max 7, depart 3, +1 si 3 aspects equilibres |

---

## Architecture Technique

### LLM: Qwen2.5-3B-Instruct + Multi-Brain
- **Modele**: Qwen2.5-3B-Instruct Q4_K_M (~2.0 GB par cerveau)
- **Multi-Brain**: 1-4 cerveaux adaptatifs (auto-detection plateforme)
  - Brain 1: Narrator (texte creatif) — toujours present
  - Brain 2: Game Master (effets JSON via GBNF) — desktop+
  - Brain 3-4: Worker Pool (prefetch, voice, balance)
- **RAG v2.0**: Token budget 180, priorites, journal de jeu, cross-run memory
- **Guardrails**: FR language check, repetition detection (Jaccard), length bounds

**Parametres LLM:**
| Role | temp | top_p | max_tokens | top_k | rep_penalty |
|------|------|-------|------------|-------|-------------|
| Narrator | 0.7 | 0.9 | 200 | 40 | 1.3 |
| Game Master | 0.2 | 0.8 | 150 | 20 | 1.0 |

### Code Architecture
| Layer | Path | Fichiers cles |
|-------|------|---------------|
| Core Systems | `scripts/merlin/` | merlin_store.gd, merlin_card_system.gd, merlin_effect_engine.gd |
| UI | `scripts/ui/` | triade_game_ui.gd, triade_game_controller.gd |
| AI | `addons/merlin_ai/` | merlin_ai.gd (multi-brain), merlin_omniscient.gd, rag_manager.gd |
| Autoloads | `scripts/autoload/` | LLMManager, ScreenEffects, LocaleManager, SceneSelector, SFXManager |

### Audio
- **SFXManager**: 30+ sons proceduraux (synthese AudioStreamGenerator)
- **Zero fichiers audio externes** — tout genere en temps reel
- **ACVoicebox**: Voix robot Merlin (pitch 2.5, typewriter sync)

---

## Index des Documents par Categorie

### Legende des Statuts

| Statut | Signification |
|--------|---------------|
| **CURRENT** | Document a jour avec l'implementation |
| **NEEDS UPDATE** | Document valide mais necessite synchronisation |
| **LEGACY** | Document du systeme precedent (Reigns/DRU), garde pour reference |

---

### 00_overview - Installation et Architecture

| Document | Description | Statut |
|----------|-------------|--------|
| [installation-guide.md](00_overview/installation-guide.md) | Guide d'installation projet | CURRENT |
| [getting-started.md](00_overview/getting-started.md) | Demarrage rapide | CURRENT |
| [architecture.md](00_overview/architecture.md) | Vue d'ensemble technique | NEEDS UPDATE |
| [command-reference.md](00_overview/command-reference.md) | Reference des commandes | CURRENT |
| [mcp-server-readme.md](00_overview/mcp-server-readme.md) | Serveur MCP | CURRENT |
| [implementation-plan.md](00_overview/implementation-plan.md) | Plan d'implementation | NEEDS UPDATE |

---

### 10_llm - Integration LLM (Multi-Brain + RAG v2.0)

| Document | Description | Statut |
|----------|-------------|--------|
| [MOS_ARCHITECTURE.md](10_llm/MOS_ARCHITECTURE.md) | **Architecture MerlinOmniscient** | CURRENT |
| [TRINITY_ARCHITECTURE.md](10_llm/TRINITY_ARCHITECTURE.md) | Architecture multi-modele | CURRENT |
| [SPEC_OptimisationLLM_MERLIN.md](10_llm/SPEC_OptimisationLLM_MERLIN.md) | Optimisation performance LLM | CURRENT |
| [merlin_rag_cadrage.md](10_llm/merlin_rag_cadrage.md) | Cadrage RAG pour Merlin | NEEDS UPDATE |
| [STATE_Claude_MerlinLLM.md](10_llm/STATE_Claude_MerlinLLM.md) | Etat integration MerlinLLM | NEEDS UPDATE |

---

### 20_card_system - Systeme Triade et Cartes

| Document | Description | Statut |
|----------|-------------|--------|
| **[DOC_12_Triade_Gameplay_System.md](20_card_system/DOC_12_Triade_Gameplay_System.md)** | **Systeme Triades (3 aspects, Souffle, 3 options)** | CURRENT |
| [DOC_11_Card_System.md](20_card_system/DOC_11_Card_System.md) | Systeme de cartes | CURRENT |
| [DOC_13_Hidden_Depth_System.md](20_card_system/DOC_13_Hidden_Depth_System.md) | 8 couches de profondeur cachee | CURRENT |
| [GDD_MERLIN_OMNISCIENT_SYSTEM.md](20_card_system/GDD_MERLIN_OMNISCIENT_SYSTEM.md) | GDD systeme omniscient Merlin | CURRENT |
| [ALTERNATIVES_CARD_SYSTEM.md](20_card_system/ALTERNATIVES_CARD_SYSTEM.md) | Alternatives au systeme de cartes | CURRENT |
| [UX_SHORT_SESSION_DESIGN.md](20_card_system/UX_SHORT_SESSION_DESIGN.md) | Design parties courtes (<10 min) | CURRENT |
| [CALENDAR_SCENE_DESIGN.md](20_card_system/CALENDAR_SCENE_DESIGN.md) | Scene calendrier | CURRENT |
| [DOC_06_Event_System_v2.md](20_card_system/DOC_06_Event_System_v2.md) | Systeme evenements | CURRENT |
| [DOC_07_LLM_Merlin_Contrat_Memoire.md](20_card_system/DOC_07_LLM_Merlin_Contrat_Memoire.md) | Contrat LLM memoire | CURRENT |
| [DOC_08_MVP_Profond_Checklist.md](20_card_system/DOC_08_MVP_Profond_Checklist.md) | Checklist MVP | NEEDS UPDATE |
| [DOC_09_Effect_Whitelist.md](20_card_system/DOC_09_Effect_Whitelist.md) | Whitelist effets | CURRENT |
| [DOC_01_Architecture_Ordre_Dev.md](20_card_system/DOC_01_Architecture_Ordre_Dev.md) | Architecture DruStore | LEGACY |
| [DOC_02_UI_Interaction_FORCE_LOGIQUE_FINESSE.md](20_card_system/DOC_02_UI_Interaction_FORCE_LOGIQUE_FINESSE.md) | Systeme verbes (remplace par Triade) | LEGACY |
| [DOC_03_Systeme_Tests_Unifie.md](20_card_system/DOC_03_Systeme_Tests_Unifie.md) | Tests unifies | LEGACY |
| [DOC_04_Ressources_Unifiees.md](20_card_system/DOC_04_Ressources_Unifiees.md) | Gestion ressources | LEGACY |
| [DOC_10_Moves_Library.md](20_card_system/DOC_10_Moves_Library.md) | Bibliotheque moves (Oghams = skills maintenant) | LEGACY |

---

### 30_jdr - Regles JDR (Legacy)

| Document | Description | Statut |
|----------|-------------|--------|
| [MERLIN_JDR_Cahier_des_Charges_Regles.md](30_jdr/MERLIN_JDR_Cahier_des_Charges_Regles.md) | Regles JDR classiques | LEGACY |
| [MERLIN_JDR_Cahier_des_Charges_LLM_Narrateur.md](30_jdr/MERLIN_JDR_Cahier_des_Charges_LLM_Narrateur.md) | LLM comme narrateur | NEEDS UPDATE |

> **Note**: Le dossier 30_jdr contient des regles JDR classiques pre-pivot. Les elements pertinents ont ete integres dans le systeme Triade (20_card_system) et le lore (50_lore).

---

### 40_world_rules - Regles du Monde

| Document | Description | Statut |
|----------|-------------|--------|
| [BIOMES_SYSTEM.md](40_world_rules/BIOMES_SYSTEM.md) | **7 biomes + modificateurs + events** | CURRENT |
| [GAMEPLAY_LOOP_ROGUELITE.md](40_world_rules/GAMEPLAY_LOOP_ROGUELITE.md) | Boucle de jeu principale | CURRENT |
| [World_Rules_Overview.md](40_world_rules/World_Rules_Overview.md) | Vue d'ensemble monde | CURRENT |
| [PROMISE_PLAYBOOK.md](40_world_rules/PROMISE_PLAYBOOK.md) | Systeme de promesses | CURRENT |
| [CALENDAR_2026_PRINT.md](40_world_rules/CALENDAR_2026_PRINT.md) | Calendrier celtique 2026 | CURRENT |
| [HOURLY_SLICES_GUIDE.md](40_world_rules/HOURLY_SLICES_GUIDE.md) | Tranches horaires | CURRENT |
| [UTILITY_UNLOCK_MAP.md](40_world_rules/UTILITY_UNLOCK_MAP.md) | Map des deblocages | NEEDS UPDATE |
| [EVENT_TAG_GLOSSARY.md](40_world_rules/EVENT_TAG_GLOSSARY.md) | Glossaire des tags | CURRENT |
| [MERLIN_NARRATIVE_TEMPLATES.md](40_world_rules/MERLIN_NARRATIVE_TEMPLATES.md) | Templates narratifs Merlin | CURRENT |
| [MERLIN_MEMORY_RULES.md](40_world_rules/MERLIN_MEMORY_RULES.md) | Regles memoire Merlin | CURRENT |
| [MERLIN_EVENT_EXAMPLES.md](40_world_rules/MERLIN_EVENT_EXAMPLES.md) | Exemples evenements | CURRENT |
| [TUNING_SHEET.md](40_world_rules/TUNING_SHEET.md) | Parametres equilibrage | NEEDS UPDATE |
| [KNOWN_RISKS.md](40_world_rules/KNOWN_RISKS.md) | Risques identifies | CURRENT |
| [TEST_MATRIX.md](40_world_rules/TEST_MATRIX.md) | Matrice de tests | NEEDS UPDATE |
| [CHANGELOG.md](40_world_rules/CHANGELOG.md) | Historique changements | CURRENT |
| [DECISION_LOG.md](40_world_rules/DECISION_LOG.md) | Log decisions design | CURRENT |
| [README.md](40_world_rules/README.md) | Index world rules | CURRENT |

---

### 50_lore - Univers et Narration

#### Lore Bible (numerotee, reference canonique)
| Document | Description | Statut |
|----------|-------------|--------|
| [00_LORE_BIBLE_INDEX.md](50_lore/00_LORE_BIBLE_INDEX.md) | **Index general + hierarchie secrets S0-S4** | CURRENT |
| [01_LE_MONDE.md](50_lore/01_LE_MONDE.md) | Le monde de Broceliande | CURRENT |
| [02_CHRONOLOGIE.md](50_lore/02_CHRONOLOGIE.md) | Timeline: Geants -> Druides -> Rois -> Present | CURRENT |
| [03_LES_FACTIONS.md](50_lore/03_LES_FACTIONS.md) | 5 factions + 7 druides nommes | CURRENT |
| [04_MERLIN.md](50_lore/04_MERLIN.md) | Merlin: personnage visible | CURRENT |
| [05_LE_VOYAGEUR.md](50_lore/05_LE_VOYAGEUR.md) | Le joueur = Temoin (Tyst) | CURRENT |
| [06_BESTIOLE.md](50_lore/06_BESTIOLE.md) | Fragment d'Awen primordial | CURRENT |
| [07_LES_OGHAMS_COMPLET.md](50_lore/07_LES_OGHAMS_COMPLET.md) | 18+7 Oghams consolides | CURRENT |
| [08_LES_BIOMES.md](50_lore/08_LES_BIOMES.md) | 7 sanctuaires sacres | CURRENT |
| [09_LES_FINS.md](50_lore/09_LES_FINS.md) | 12 chutes + 3 victoires + 1 secrete | CURRENT |
| [10_LE_PONT_MECANIQUE.md](50_lore/10_LE_PONT_MECANIQUE.md) | Connexion lore-mecaniques | CURRENT |
| [11_LES_PNJ.md](50_lore/11_LES_PNJ.md) | 12 PNJ recurrents | CURRENT |
| [12_LES_INDICES.md](50_lore/12_LES_INDICES.md) | Catalogue indices par run | CURRENT |
| [13_GARDES-FOU.md](50_lore/13_GARDES-FOU.md) | Garde-fous narratifs | CURRENT |

#### Deep Lore (NEVER REVEALED to player)
| Document | Description | Statut |
|----------|-------------|--------|
| **[COSMOLOGIE_CACHEE.md](50_lore/COSMOLOGIE_CACHEE.md)** | 3 Royaumes, Membrane, Fin par epuisement | CURRENT |
| **[MERLIN_TRUE_NATURE.md](50_lore/MERLIN_TRUE_NATURE.md)** | M.E.R.L.I.N. acronyme, 3 Merlins historiques | CURRENT |
| **[LES_CYCLES_ANTERIEURS.md](50_lore/LES_CYCLES_ANTERIEURS.md)** | 4 cycles cosmiques, eschatologie celtique | CURRENT |
| **[THE_HIDDEN_TRUTH.md](50_lore/THE_HIDDEN_TRUTH.md)** | Verite apocalyptique, timeline, easter eggs | CURRENT |

#### Personnalite et comportement
| Document | Description | Statut |
|----------|-------------|--------|
| [MERLIN_COMPLETE_PERSONALITY.md](50_lore/MERLIN_COMPLETE_PERSONALITY.md) | Dualite 95/5, taunts, voice lines | CURRENT |
| [MERLIN_BEHAVIOR_PROTOCOL.md](50_lore/MERLIN_BEHAVIOR_PROTOCOL.md) | Protocole comportement Merlin | CURRENT |
| [NARRATIVE_GUARDRAILS.md](50_lore/NARRATIVE_GUARDRAILS.md) | Garde-fous narratifs globaux | CURRENT |
| [NARRATIVE_ENGINE.md](50_lore/NARRATIVE_ENGINE.md) | Moteur narratif, arcs proceduraux | CURRENT |
| [CELTIC_FOUNDATION.md](50_lore/CELTIC_FOUNDATION.md) | Fondation mythologie celtique | CURRENT |

#### Autres documents lore
| Document | Description | Statut |
|----------|-------------|--------|
| [LORE_COMPLETE.md](50_lore/LORE_COMPLETE.md) | Lore complet (hints only) | CURRENT |
| [LORE_BIBLE_MERLIN.md](50_lore/LORE_BIBLE_MERLIN.md) | Bible Merlin | CURRENT |
| [LORE_HINTS_CATALOG.md](50_lore/LORE_HINTS_CATALOG.md) | Catalogue indices | CURRENT |
| [LORE_PROGRESSION_MAP.md](50_lore/LORE_PROGRESSION_MAP.md) | Map progression lore | CURRENT |
| [OGHAMS_SECRETS.md](50_lore/OGHAMS_SECRETS.md) | 18 druides dissous, 7 perdus | CURRENT |
| [README.md](50_lore/README.md) | Index lore | CURRENT |

---

### 60_companion - Systeme Bestiole

| Document | Description | Statut |
|----------|-------------|--------|
| **[BESTIOLE_BIBLE_COMPLETE.md](60_companion/BESTIOLE_BIBLE_COMPLETE.md)** | **Bible Bestiole complete** | CURRENT |
| **[BESTIOLE_OGHAM_WHEEL_DESIGN.md](60_companion/BESTIOLE_OGHAM_WHEEL_DESIGN.md)** | **Design Roue d'Oghams** | CURRENT |
| **[BESTIOLE_TOOL_WHEEL_SPEC.md](60_companion/BESTIOLE_TOOL_WHEEL_SPEC.md)** | **Spec UI roue radiale** | CURRENT |
| [BESTIOLE_SYSTEM.md](60_companion/BESTIOLE_SYSTEM.md) | Systeme compagnon principal | CURRENT |
| [BESTIOLE_ACTIONS.md](60_companion/BESTIOLE_ACTIONS.md) | Actions Bestiole | NEEDS UPDATE |
| [BESTIOLE_EVENTS.md](60_companion/BESTIOLE_EVENTS.md) | Evenements Bestiole | CURRENT |
| [BESTIOLE_ITEMS.md](60_companion/BESTIOLE_ITEMS.md) | Objets Bestiole | NEEDS UPDATE |
| [BESTIOLE_UI.md](60_companion/BESTIOLE_UI.md) | Interface Bestiole | NEEDS UPDATE |
| [BESTIOLE_PROMISES.md](60_companion/BESTIOLE_PROMISES.md) | Promesses Bestiole | CURRENT |
| [BESTIOLE_TRAITS.md](60_companion/BESTIOLE_TRAITS.md) | Traits personnalite | CURRENT |
| [BESTIOLE_FORMS.md](60_companion/BESTIOLE_FORMS.md) | Formes evolution | NEEDS UPDATE |
| [BESTIOLE_GROWTH_TABLE.md](60_companion/BESTIOLE_GROWTH_TABLE.md) | Table croissance | CURRENT |
| [BESTIOLE_ANNUAL_MILESTONES.md](60_companion/BESTIOLE_ANNUAL_MILESTONES.md) | Milestones annuels | CURRENT |
| [BESTIOLE_MATRIX.md](60_companion/BESTIOLE_MATRIX.md) | Matrice interactions | CURRENT |
| [BESTIOLE_NARRATIVE_GUIDE.md](60_companion/BESTIOLE_NARRATIVE_GUIDE.md) | Guide narratif | CURRENT |
| [BESTIOLE_FAQ.md](60_companion/BESTIOLE_FAQ.md) | FAQ Bestiole | CURRENT |
| [BESTIOLE_TUNING_SHEET.md](60_companion/BESTIOLE_TUNING_SHEET.md) | Equilibrage Bestiole | NEEDS UPDATE |
| [BESTIOLE_TEST_MENU_SPEC.md](60_companion/BESTIOLE_TEST_MENU_SPEC.md) | Spec menu test | CURRENT |
| [README.md](60_companion/README.md) | Index companion | CURRENT |

---

### 70_graphic - Specifications Graphiques

| Document | Description | Statut |
|----------|-------------|--------|
| [MERLIN_STYLE_GUIDE.md](70_graphic/MERLIN_STYLE_GUIDE.md) | Guide style M.E.R.L.I.N. | CURRENT |
| [ART_DIRECTION_AUDIT.md](70_graphic/ART_DIRECTION_AUDIT.md) | Audit coherence visuelle (19 issues) | CURRENT |
| [ANIMATION_INVENTORY.md](70_graphic/ANIMATION_INVENTORY.md) | Inventaire animations | CURRENT |
| [VISUAL_SPEC_TRANSITION_SCENES.md](70_graphic/VISUAL_SPEC_TRANSITION_SCENES.md) | Spec visuelles transitions | CURRENT |
| [CALENDAR_VISUAL_SPEC.md](70_graphic/CALENDAR_VISUAL_SPEC.md) | Spec visuelle calendrier | CURRENT |
| [retro_cpp_graphics_spec.md](70_graphic/retro_cpp_graphics_spec.md) | Spec graphiques retro | CURRENT |

---

### 80_sound - Audio et Voix

| Document | Description | Statut |
|----------|-------------|--------|
| [README.md](80_sound/README.md) | Index audio | CURRENT |
| [AUDIO_DESIGN_3_SCENES.md](80_sound/AUDIO_DESIGN_3_SCENES.md) | Design audio 3 scenes | CURRENT |
| **10_voice/** | | |
| [robot_voice_setup.md](80_sound/10_voice/robot_voice_setup.md) | Setup voix robot | CURRENT |
| [robot_voice_colab.md](80_sound/10_voice/robot_voice_colab.md) | Colab voix | CURRENT |
| [BESTIOLE_LINES.md](80_sound/10_voice/BESTIOLE_LINES.md) | Lignes Bestiole | CURRENT |
| **20_sfx/bestiole/** | | |
| [Bestiole_SFX_Pack.md](80_sound/20_sfx/bestiole/Bestiole_SFX_Pack.md) | Pack SFX Bestiole | CURRENT |
| [Bestiole_SFX_Event_Map.md](80_sound/20_sfx/bestiole/Bestiole_SFX_Event_Map.md) | Map evenements SFX | CURRENT |
| [Bestiole_SFX_Naming_Guidelines.md](80_sound/20_sfx/bestiole/Bestiole_SFX_Naming_Guidelines.md) | Conventions nommage | CURRENT |
| **30_music/** | | |
| [README.md](80_sound/30_music/README.md) | Index musique | CURRENT |
| [MERLIN_MUSIC_TEMPO_MAP.md](80_sound/30_music/MERLIN_MUSIC_TEMPO_MAP.md) | Map tempo musique | CURRENT |
| [MERLIN_MUSIC_STATE_SCHEMA.md](80_sound/30_music/MERLIN_MUSIC_STATE_SCHEMA.md) | Schema etats musique | CURRENT |
| [MERLIN_MUSIC_MIX_GUIDE.md](80_sound/30_music/MERLIN_MUSIC_MIX_GUIDE.md) | Guide mixage | CURRENT |
| [SUNO_PROMPTS_GUIDE.md](80_sound/30_music/SUNO_PROMPTS_GUIDE.md) | Guide prompts Suno | CURRENT |
| [SUNO_QUICK_REFERENCE.md](80_sound/30_music/SUNO_QUICK_REFERENCE.md) | Reference rapide Suno | CURRENT |

---

### 30_scenes - Specifications Scenes

| Document | Description | Statut |
|----------|-------------|--------|
| [SPEC_TRANSITION_SCENES.md](30_scenes/SPEC_TRANSITION_SCENES.md) | Spec scenes de transition | CURRENT |

---

### root - Documents Techniques Racine

| Document | Description | Statut |
|----------|-------------|--------|
| [QUICK_START.md](root/QUICK_START.md) | Demarrage rapide | CURRENT |
| [COMPILE_WINDOWS_LOCAL.md](root/COMPILE_WINDOWS_LOCAL.md) | Compilation Windows | CURRENT |
| [QWEN_3B_MODELS.md](root/QWEN_3B_MODELS.md) | Modeles Qwen 3B | CURRENT |
| [LLM_SIMPLE_README.md](root/LLM_SIMPLE_README.md) | README LLM simple | CURRENT |
| [LLM_SIMPLE_SUMMARY.md](root/LLM_SIMPLE_SUMMARY.md) | Resume LLM simple | CURRENT |
| [GUIDE_COLAB_ULTIMATE.md](root/GUIDE_COLAB_ULTIMATE.md) | Guide Colab complet | LEGACY |
| [GUIDE_COMPILATION_COLAB.md](root/GUIDE_COMPILATION_COLAB.md) | Compilation Colab | LEGACY |
| [COLAB_README.md](root/COLAB_README.md) | README Colab | LEGACY |
| [UPGRADE_COLAB_ALIGNMENT.md](root/UPGRADE_COLAB_ALIGNMENT.md) | Mise a jour Colab | LEGACY |
| [ULTIMATE_FIXES.md](root/ULTIMATE_FIXES.md) | Corrections ultimes | LEGACY |
| [INSTRUCTIONS_FINALES.md](root/INSTRUCTIONS_FINALES.md) | Instructions finales | LEGACY |
| [VERSION_ULTRA_AMELIORATIONS.md](root/VERSION_ULTRA_AMELIORATIONS.md) | Ameliorations version | LEGACY |
| [CLAUDE.md](root/CLAUDE.md) | Ancien CLAUDE.md | LEGACY |
| [README.md](root/README.md) | Ancien README | LEGACY |
| [doc.md](root/doc.md) | Documentation ancienne | LEGACY |

---

### old - Archives

| Document | Note |
|----------|------|
| [AUDIT_CANDIDATES.md](old/AUDIT_CANDIDATES.md) | Archive |
| [godot-addon-readme.md](old/00_overview/godot-addon-readme.md) | Archive |
| [FOC_MerlinLLM.md](old/10_llm/FOC_MerlinLLM.md) | Archive |
| [ff6_like_cpp_graphics_spec.md](old/70_graphic/ff6_like_cpp_graphics_spec.md) | Archive |

---

## Guide pour Nouveaux Contributeurs

### Documents Essentiels (Lire en Premier)

1. **[MASTER_DOCUMENT.md](MASTER_DOCUMENT.md)** — Vue d'ensemble et principes (v4.0)
2. **[DOC_12_Triade_Gameplay_System.md](20_card_system/DOC_12_Triade_Gameplay_System.md)** — Systeme Triade
3. **[GAMEPLAY_LOOP_ROGUELITE.md](40_world_rules/GAMEPLAY_LOOP_ROGUELITE.md)** — Boucle de jeu
4. **[BESTIOLE_BIBLE_COMPLETE.md](60_companion/BESTIOLE_BIBLE_COMPLETE.md)** — Compagnon
5. **[00_LORE_BIBLE_INDEX.md](50_lore/00_LORE_BIBLE_INDEX.md)** — Index lore complet

### Deep Lore (Reference Interne - JAMAIS REVELE)

1. **[COSMOLOGIE_CACHEE.md](50_lore/COSMOLOGIE_CACHEE.md)** — Structure secrete de la realite
2. **[MERLIN_TRUE_NATURE.md](50_lore/MERLIN_TRUE_NATURE.md)** — Qui est vraiment M.E.R.L.I.N.
3. **[LES_CYCLES_ANTERIEURS.md](50_lore/LES_CYCLES_ANTERIEURS.md)** — Les 4 cycles cosmiques
4. **[THE_HIDDEN_TRUTH.md](50_lore/THE_HIDDEN_TRUTH.md)** — La verite apocalyptique

### Par Role

| Role | Documents Prioritaires |
|------|------------------------|
| **Dev Godot** | 00_overview, scripts/merlin/, scripts/ui/ |
| **Dev LLM** | 10_llm, addons/merlin_ai/, DOC_07, DOC_09 |
| **Game Designer** | 40_world_rules, DOC_12, TUNING_SHEET |
| **Narrative** | 50_lore (incluant DEEP LORE), NARRATIVE_GUARDRAILS |
| **Artist** | 70_graphic, MERLIN_STYLE_GUIDE |
| **Sound** | 80_sound, SFXManager |

---

## Statistiques Documentation

| Categorie | Fichiers | Statut |
|-----------|----------|--------|
| 00_overview | 6 | 4 CURRENT, 2 NEEDS UPDATE |
| 10_llm | 5 | 3 CURRENT, 2 NEEDS UPDATE |
| 20_card_system | 16 | 9 CURRENT, 1 NEEDS UPDATE, 6 LEGACY |
| 30_jdr | 2 | 1 NEEDS UPDATE, 1 LEGACY |
| 30_scenes | 1 | 1 CURRENT |
| 40_world_rules | 17 | 13 CURRENT, 4 NEEDS UPDATE |
| 50_lore | 25 | 25 CURRENT |
| 60_companion | 19 | 14 CURRENT, 5 NEEDS UPDATE |
| 70_graphic | 6 | 6 CURRENT |
| 80_sound | 13 | 13 CURRENT |
| root | 15 | 5 CURRENT, 10 LEGACY |
| old | 4 | 4 Archive |
| **TOTAL** | **129** | **97 CURRENT, 14 NEEDS UPDATE, 17 LEGACY, 1 Archive** |

---

*Document genere par Technical Writer Agent*
*Derniere mise a jour: 2026-02-09*
