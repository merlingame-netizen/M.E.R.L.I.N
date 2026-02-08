# DRU: Le Jeu des Oghams - Index de Documentation

**Version**: 3.0 (Triades + Deep Lore)
**Derniere mise a jour**: 2026-02-08
**Mainteneur**: Technical Writer Agent

---

## Vue d'ensemble du Projet

**DRU: Le Jeu des Oghams** est un jeu narratif roguelite de style Reigns developpe avec Godot 4.x. Le joueur incarne un druide guide par Merlin, un narrateur omniscient genere par LLM (Trinity-Nano), accompagne de Bestiole, un compagnon mystique qui offre des skills passifs (les 18 Oghams).

Le coeur du jeu est un **"JDR Parlant"** ou:
- **Merlin narre** des histoires generees dynamiquement par LLM local
- **Le joueur decide** via des choix de cartes (swipe gauche/droite)
- **Le LLM genere** les scenarios, retournements et consequences

Chaque partie (run) est une quete de survie: maintenir 3 Aspects en equilibre (Corps/Sanglier, Ame/Corbeau, Monde/Cerf) avec 3 etats possibles (Bas, Equilibre, Haut). Le joueur gere son Souffle d'Ogham pour acceder aux options payantes. Si un aspect atteint un extreme, le run se termine avec l'une des 12+ fins possibles.

### Inspirations
- **Reigns** - Gameplay swipe, 4 jauges, morts narratives
- **Gnosia** - Narration emergente, relations
- **Slay the Spire** - Structure roguelite, meta-progression

---

## Vision "JDR Parlant"

DRU reinvente le jeu de role solo en combinant:

1. **Narration LLM Dynamique**: Chaque scenario est unique, genere par Trinity-Nano selon le contexte de jeu
2. **Simplicite Extreme**: Une seule action (swipe) mais des consequences profondes
3. **Mystere Permanent**: Merlin ne revele jamais la verite - tout reste ambigu
4. **Rejouabilite Infinie**: Combinaison LLM + 50 cartes fallback + events saisonniers

Le joueur ne "joue" pas vraiment - il **decide** et **vit** les consequences de ses choix.

---

## Pivot Majeur (Fevrier 2026)

> **IMPORTANT**: Le jeu a pivote d'un roguelite combat vers un **Reigns-like narratif**.

### Changements Cles
| Avant | Apres |
|-------|-------|
| Combat tour par tour | Choix narratifs (swipe) |
| HP + Stats combat | 4 jauges equilibre |
| Bestiole combattant | Bestiole support passif |
| Oghams = attaques | Oghams = skills de Bestiole |
| GameManager v7 | DruStore modulaire |

### Documents Affectes
- `DOC_05_Combat_System_v2.md` - **DEPRECATED**
- `DOC_10_Moves_Library.md` - **DEPRECATED** (oghams = skills maintenant)
- `30_jdr/` - **A REEVALUER** (regles JDR classiques vs Reigns)

---

## Index des Documents par Categorie

### Legende des Statuts

| Statut | Signification |
|--------|---------------|
| **CURRENT** | Document a jour avec l'implementation |
| **NEEDS UPDATE** | Document valide mais necessite synchronisation |
| **DEPRECATED** | Document obsolete suite au pivot |
| **DRAFT** | Document en cours de redaction |

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

### 10_llm - Integration LLM (Merlin)

| Document | Description | Statut |
|----------|-------------|--------|
| [SPEC_OptimisationLLM_MERLIN.md](10_llm/SPEC_OptimisationLLM_MERLIN.md) | Optimisation performance LLM | CURRENT |
| [merlin_rag_cadrage.md](10_llm/merlin_rag_cadrage.md) | Cadrage RAG pour Merlin | NEEDS UPDATE |
| [STATE_Claude_MerlinLLM.md](10_llm/STATE_Claude_MerlinLLM.md) | Etat integration Claude | NEEDS UPDATE |

**Parametres LLM Actuels** (Trinity-Nano):
```
max_tokens: 60
temperature: 0.4
top_p: 0.75
top_k: 25
repetition_penalty: 1.6
```

---

### 20_dru_system - Systemes Core

| Document | Description | Statut |
|----------|-------------|--------|
| [DOC_11_Reigns_Card_System.md](20_dru_system/DOC_11_Reigns_Card_System.md) | **Systeme de cartes principal** | NEEDS UPDATE |
| **[DOC_12_Triade_Gameplay_System.md](20_dru_system/DOC_12_Triade_Gameplay_System.md)** | **Systeme Triades (3 aspects, Souffle, 3 options)** | CURRENT |
| [DOC_01_Architecture_Ordre_Dev.md](20_dru_system/DOC_01_Architecture_Ordre_Dev.md) | Architecture DruStore | NEEDS UPDATE |
| [DOC_02_UI_Interaction_FORCE_LOGIQUE_FINESSE.md](20_dru_system/DOC_02_UI_Interaction_FORCE_LOGIQUE_FINESSE.md) | Systeme verbes | DEPRECATED |
| [DOC_03_Systeme_Tests_Unifie.md](20_dru_system/DOC_03_Systeme_Tests_Unifie.md) | Tests unifes | NEEDS UPDATE |
| [DOC_04_Ressources_Unifiees.md](20_dru_system/DOC_04_Ressources_Unifiees.md) | Gestion ressources | NEEDS UPDATE |
| [DOC_05_Combat_System_v2.md](20_dru_system/DOC_05_Combat_System_v2.md) | Ancien systeme combat | DEPRECATED |
| [DOC_06_Event_System_v2.md](20_dru_system/DOC_06_Event_System_v2.md) | Systeme evenements | CURRENT |
| [DOC_07_LLM_Merlin_Contrat_Memoire.md](20_dru_system/DOC_07_LLM_Merlin_Contrat_Memoire.md) | Contrat LLM | CURRENT |
| [DOC_08_MVP_Profond_Checklist.md](20_dru_system/DOC_08_MVP_Profond_Checklist.md) | Checklist MVP | NEEDS UPDATE |
| [DOC_09_Effect_Whitelist.md](20_dru_system/DOC_09_Effect_Whitelist.md) | Whitelist effets | CURRENT |
| [DOC_10_Moves_Library.md](20_dru_system/DOC_10_Moves_Library.md) | Bibliotheque moves | DEPRECATED |
| [CALENDAR_SCENE_DESIGN.md](20_dru_system/CALENDAR_SCENE_DESIGN.md) | Scene calendrier | CURRENT |

---

### 30_jdr - Regles JDR

| Document | Description | Statut |
|----------|-------------|--------|
| [DRU_JDR_Cahier_des_Charges_Regles.md](30_jdr/DRU_JDR_Cahier_des_Charges_Regles.md) | Regles JDR completes | DEPRECATED? |
| [DRU_JDR_Cahier_des_Charges_LLM_Narrateur.md](30_jdr/DRU_JDR_Cahier_des_Charges_LLM_Narrateur.md) | LLM comme narrateur | NEEDS UPDATE |

> **Note**: Le dossier 30_jdr contient des regles JDR classiques (classes, combat, XP) qui ne correspondent plus au gameplay Reigns-like. A reevaluer: fusionner elements pertinents dans 40_world_rules ou archiver.

---

### 40_world_rules - Regles du Monde

| Document | Description | Statut |
|----------|-------------|--------|
| [GAMEPLAY_LOOP_ROGUELITE.md](40_world_rules/GAMEPLAY_LOOP_ROGUELITE.md) | **Boucle de jeu principale** | CURRENT |
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

---

### 50_lore - Univers et Narration

| Document | Description | Statut |
|----------|-------------|--------|
| [LORE_COMPLETE.md](50_lore/LORE_COMPLETE.md) | **Lore complet (hints only)** | CURRENT |
| [LORE_BIBLE_MERLIN.md](50_lore/LORE_BIBLE_MERLIN.md) | Bible Merlin | CURRENT |
| [LORE_HINTS_CATALOG.md](50_lore/LORE_HINTS_CATALOG.md) | Catalogue indices | CURRENT |
| [LORE_PROGRESSION_MAP.md](50_lore/LORE_PROGRESSION_MAP.md) | Map progression lore | CURRENT |
| [NARRATIVE_GUARDRAILS.md](50_lore/NARRATIVE_GUARDRAILS.md) | Garde-fous narratifs | CURRENT |
| [MERLIN_BEHAVIOR_PROTOCOL.md](50_lore/MERLIN_BEHAVIOR_PROTOCOL.md) | Protocole comportement Merlin | CURRENT |
| **[COSMOLOGIE_CACHEE.md](50_lore/COSMOLOGIE_CACHEE.md)** | **Cosmologie secrete (3 Royaumes, Membrane, Epuisement)** | CURRENT |
| **[MERLIN_TRUE_NATURE.md](50_lore/MERLIN_TRUE_NATURE.md)** | **Vraie nature de M.E.R.L.I.N. (acronyme, tissage)** | CURRENT |
| **[LES_CYCLES_ANTERIEURS.md](50_lore/LES_CYCLES_ANTERIEURS.md)** | **4 cycles cosmiques (eschatologie celtique)** | CURRENT |
| **[OGHAMS_SECRETS.md](50_lore/OGHAMS_SECRETS.md)** | **18 druides = 18 Oghams, 7 perdus** | CURRENT |
| [THE_HIDDEN_TRUTH.md](50_lore/THE_HIDDEN_TRUTH.md) | Verite apocalyptique cachee | CURRENT |
| [CELTIC_FOUNDATION.md](50_lore/CELTIC_FOUNDATION.md) | Fondation mythologie celtique | CURRENT |
| [NARRATIVE_ENGINE.md](50_lore/NARRATIVE_ENGINE.md) | Moteur narratif, arcs | CURRENT |
| [MERLIN_COMPLETE_PERSONALITY.md](50_lore/MERLIN_COMPLETE_PERSONALITY.md) | Personnalite duale Merlin | CURRENT |
| [BIOMES_SYSTEM.md](50_lore/BIOMES_SYSTEM.md) | 7 biomes et regles specifiques | CURRENT |

> **DEEP LORE** (cosmologie, cycles, oghams, nature de Merlin): Ces documents contiennent des secrets **jamais reveles au joueur**. Ils servent de reference interne pour la coherence narrative.

---

### 60_companion - Systeme Bestiole

| Document | Description | Statut |
|----------|-------------|--------|
| [BESTIOLE_SYSTEM.md](60_companion/BESTIOLE_SYSTEM.md) | **Systeme compagnon principal** | CURRENT |
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
| [BESTIOLE_COMBAT_EXAMPLES.md](60_companion/BESTIOLE_COMBAT_EXAMPLES.md) | Exemples combat | DEPRECATED |
| [BESTIOLE_NARRATIVE_GUIDE.md](60_companion/BESTIOLE_NARRATIVE_GUIDE.md) | Guide narratif | CURRENT |
| [BESTIOLE_FAQ.md](60_companion/BESTIOLE_FAQ.md) | FAQ Bestiole | CURRENT |
| [BESTIOLE_TUNING_SHEET.md](60_companion/BESTIOLE_TUNING_SHEET.md) | Equilibrage Bestiole | NEEDS UPDATE |
| [BESTIOLE_TEST_MENU_SPEC.md](60_companion/BESTIOLE_TEST_MENU_SPEC.md) | Spec menu test | CURRENT |

---

### 70_graphic - Specifications Graphiques

| Document | Description | Statut |
|----------|-------------|--------|
| [REIGNS_STYLE_GUIDE.md](70_graphic/REIGNS_STYLE_GUIDE.md) | **Guide style Reigns** | CURRENT |
| [gba_like_cpp_graphics_spec.md](70_graphic/gba_like_cpp_graphics_spec.md) | Spec graphiques GBA | CURRENT |
| [CALENDAR_VISUAL_SPEC.md](70_graphic/CALENDAR_VISUAL_SPEC.md) | Spec visuelle calendrier | CURRENT |

---

### 80_sound - Audio et Voix

| Document | Description | Statut |
|----------|-------------|--------|
| [README.md](80_sound/README.md) | Index audio | CURRENT |
| **10_voice/** | | |
| [robot_voice_setup.md](80_sound/10_voice/robot_voice_setup.md) | Setup voix robot | CURRENT |
| [robot_voice_colab.md](80_sound/10_voice/robot_voice_colab.md) | Colab voix | CURRENT |
| [BESTIOLE_LINES.md](80_sound/10_voice/BESTIOLE_LINES.md) | Lignes Bestiole | CURRENT |
| **20_sfx/bestiole/** | | |
| [Bestiole_SFX_Pack.md](80_sound/20_sfx/bestiole/Bestiole_SFX_Pack.md) | Pack SFX Bestiole | CURRENT |
| [Bestiole_SFX_Event_Map.md](80_sound/20_sfx/bestiole/Bestiole_SFX_Event_Map.md) | Map evenements SFX | CURRENT |
| [Bestiole_SFX_Naming_Guidelines.md](80_sound/20_sfx/bestiole/Bestiole_SFX_Naming_Guidelines.md) | Conventions nommage | CURRENT |
| **30_music/** | | |
| [MERLIN_MUSIC_TEMPO_MAP.md](80_sound/30_music/MERLIN_MUSIC_TEMPO_MAP.md) | Map tempo musique | CURRENT |
| [MERLIN_MUSIC_STATE_SCHEMA.md](80_sound/30_music/MERLIN_MUSIC_STATE_SCHEMA.md) | Schema etats musique | CURRENT |
| [MERLIN_MUSIC_MIX_GUIDE.md](80_sound/30_music/MERLIN_MUSIC_MIX_GUIDE.md) | Guide mixage | CURRENT |
| [SUNO_PROMPTS_GUIDE.md](80_sound/30_music/SUNO_PROMPTS_GUIDE.md) | Guide prompts Suno | CURRENT |

---

### root - Documents Techniques Racine

| Document | Description | Statut |
|----------|-------------|--------|
| [QUICK_START.md](root/QUICK_START.md) | Demarrage rapide | CURRENT |
| [COMPILE_WINDOWS_LOCAL.md](root/COMPILE_WINDOWS_LOCAL.md) | Compilation Windows | CURRENT |
| [GUIDE_COLAB_ULTIMATE.md](root/GUIDE_COLAB_ULTIMATE.md) | Guide Colab complet | CURRENT |
| [GUIDE_COMPILATION_COLAB.md](root/GUIDE_COMPILATION_COLAB.md) | Compilation Colab | CURRENT |
| [COLAB_README.md](root/COLAB_README.md) | README Colab | CURRENT |
| [UPGRADE_COLAB_ALIGNMENT.md](root/UPGRADE_COLAB_ALIGNMENT.md) | Mise a jour Colab | CURRENT |
| [LLM_SIMPLE_README.md](root/LLM_SIMPLE_README.md) | README LLM simple | CURRENT |
| [LLM_SIMPLE_SUMMARY.md](root/LLM_SIMPLE_SUMMARY.md) | Resume LLM simple | CURRENT |
| [QWEN_3B_MODELS.md](root/QWEN_3B_MODELS.md) | Modeles Qwen 3B | CURRENT |
| [ULTIMATE_FIXES.md](root/ULTIMATE_FIXES.md) | Corrections ultimes | CURRENT |
| [INSTRUCTIONS_FINALES.md](root/INSTRUCTIONS_FINALES.md) | Instructions finales | CURRENT |
| [VERSION_ULTRA_AMELIORATIONS.md](root/VERSION_ULTRA_AMELIORATIONS.md) | Ameliorations version | CURRENT |

---

### old - Archives (NE PAS MODIFIER)

| Document | Description | Note |
|----------|-------------|------|
| [AUDIT_CANDIDATES.md](old/AUDIT_CANDIDATES.md) | Candidats audit | Archive |
| [godot-addon-readme.md](old/00_overview/godot-addon-readme.md) | Ancien README addon | Archive |
| [FOC_MerlinLLM.md](old/10_llm/FOC_MerlinLLM.md) | Ancien focus Merlin | Archive |
| [ff6_like_cpp_graphics_spec.md](old/70_graphic/ff6_like_cpp_graphics_spec.md) | Spec FF6 | Archive |

---

## Gaps et Priorites de Mise a Jour

### Documents Manquants (A Creer)

| Document Propose | Raison | Priorite |
|------------------|--------|----------|
| `20_dru_system/API_REFERENCE.md` | Reference API DruStore | MOYENNE |
| `70_graphic/BESTIOLE_VISUAL_GUIDE.md` | Guide visuel Bestiole (aucun sprite actuellement) | MOYENNE |

> **Crees recemment**: DOC_12_Triade_Gameplay_System.md, BIOMES_SYSTEM.md, NARRATIVE_ENGINE.md, 4 documents deep lore (cosmologie, cycles, Merlin, Oghams)

### Documents Obsoletes (A Archiver)

| Document | Raison | Action |
|----------|--------|--------|
| `DOC_02_UI_Interaction_FORCE_LOGIQUE_FINESSE.md` | Verbes FORCE/LOGIQUE/FINESSE remplaces par swipe | Archiver |
| `DOC_05_Combat_System_v2.md` | Plus de combat traditionnel | Archiver |
| `DOC_10_Moves_Library.md` | Oghams = skills, pas moves | Fusionner avec skills |
| `BESTIOLE_COMBAT_EXAMPLES.md` | Combat deprecated | Archiver |
| `30_jdr/DRU_JDR_Cahier_des_Charges_Regles.md` | Regles JDR classiques inutilisees | Reevaluer |

### Documents a Mettre a Jour (Prioritaires)

| Document | Elements a Corriger | Priorite |
|----------|---------------------|----------|
| `BESTIOLE_SYSTEM.md` | Ajouter les 18 Oghams avec effets complets | HAUTE |
| `DOC_01_Architecture_Ordre_Dev.md` | Refleter architecture DruStore post-pivot | HAUTE |
| `GAMEPLAY_LOOP_ROGUELITE.md` | Ajouter ressources invisibles, retournements | HAUTE |
| `TUNING_SHEET.md` | Parametres equilibrage 4 jauges | MOYENNE |
| `BESTIOLE_FORMS.md` | Verifier coherence avec nouveau systeme | MOYENNE |

### Incoherences Detectees

1. **Oghams**: Decrits comme attaques dans `DOC_10_Moves_Library.md` mais comme skills Bestiole dans `BESTIOLE_SYSTEM.md`
   - **Resolution**: Archiver DOC_10, creer DOC_12_Oghams_Skills.md

2. **Verbes FORCE/LOGIQUE/FINESSE**: Presents dans DOC_02 mais absents du gameplay Reigns-like
   - **Resolution**: Archiver DOC_02

3. **Combat**: Plusieurs documents referent au combat (DOC_05, COMBAT_EXAMPLES)
   - **Resolution**: Archiver tous les docs combat

4. **JDR classique vs Reigns**: Le dossier 30_jdr contient des regles D&D-like non utilisees
   - **Resolution**: Extraire elements pertinents (lore, factions) vers 50_lore, archiver le reste

---

## Guide pour Nouveaux Contributeurs

### Documents Essentiels (Lire en Premier)

1. **[MASTER_DOCUMENT.md](MASTER_DOCUMENT.md)** - Vue d'ensemble et principes
2. **[DOC_12_Triade_Gameplay_System.md](20_dru_system/DOC_12_Triade_Gameplay_System.md)** - Systeme Triades (NOUVEAU)
3. **[GAMEPLAY_LOOP_ROGUELITE.md](40_world_rules/GAMEPLAY_LOOP_ROGUELITE.md)** - Boucle de jeu
4. **[BESTIOLE_SYSTEM.md](60_companion/BESTIOLE_SYSTEM.md)** - Compagnon
5. **[LORE_COMPLETE.md](50_lore/LORE_COMPLETE.md)** - Univers

### Deep Lore (Reference Interne - JAMAIS REVELE)

Ces documents sont reserves aux contributeurs et ne doivent JAMAIS etre exposes au joueur:

1. **[COSMOLOGIE_CACHEE.md](50_lore/COSMOLOGIE_CACHEE.md)** - Structure secrete de la realite
2. **[MERLIN_TRUE_NATURE.md](50_lore/MERLIN_TRUE_NATURE.md)** - Qui est vraiment M.E.R.L.I.N.
3. **[LES_CYCLES_ANTERIEURS.md](50_lore/LES_CYCLES_ANTERIEURS.md)** - Les 4 cycles cosmiques
4. **[OGHAMS_SECRETS.md](50_lore/OGHAMS_SECRETS.md)** - Les 18 druides dissous

### Par Role

| Role | Documents Prioritaires |
|------|------------------------|
| **Developpeur Godot** | 00_overview, 20_dru_system, scripts/dru/ |
| **Developpeur LLM** | 10_llm, DOC_07, DOC_09, MERLIN_BEHAVIOR_PROTOCOL |
| **Game Designer** | 40_world_rules, GAMEPLAY_LOOP, TUNING_SHEET |
| **Narrative Designer** | 50_lore (incluant DEEP LORE), NARRATIVE_GUARDRAILS, MERLIN_BEHAVIOR |
| **Artist** | 70_graphic, REIGNS_STYLE_GUIDE |
| **Sound Designer** | 80_sound |

### Conventions de Contribution

1. **Fichiers ASCII only** - Pas de caracteres speciaux
2. **Mise a jour MASTER_DOCUMENT.md** - Apres tout changement majeur
3. **Prefixes documents** - DOC_XX pour systemes, noms descriptifs pour autres
4. **Archivage** - Documents obsoletes vont dans `old/`
5. **Status obligatoire** - Tout document doit avoir un statut (CURRENT, NEEDS UPDATE, DEPRECATED)

---

## Structure de Documentation Recommandee

### Proposition de Reorganisation

```
docs/
+-- README.md              <- Cet index (point d'entree)
+-- MASTER_DOCUMENT.md     <- Source unique de verite
|
+-- 00_overview/           <- Installation, demarrage, architecture
+-- 10_llm/                <- Integration LLM (Merlin, Trinity-Nano)
+-- 20_dru_system/         <- Systemes core Godot (DruStore, cards, effects)
|
+-- 40_world_rules/        <- Regles monde (temps, promesses, equilibrage)
+-- 50_lore/               <- Univers, narration, garde-fous
+-- 60_companion/          <- Systeme Bestiole
|
+-- 70_graphic/            <- Specifications visuelles
+-- 80_sound/              <- Audio, voix, musique
|
+-- root/                  <- Docs techniques (compilation, Colab)
+-- old/                   <- Archives (NE PAS MODIFIER)
```

### Documents a Fusionner

| Destination | Sources |
|-------------|---------|
| `60_companion/BESTIOLE_SKILLS.md` | DOC_10_Moves_Library + section skills BESTIOLE_SYSTEM |
| `50_lore/WORLD_BUILDING.md` | Elements pertinents de 30_jdr (factions, geographie) |

### Documents a Supprimer (apres archivage)

- `30_jdr/` (contenu extrait ou archive)
- `docs/root/doc.md` (doublon)
- `docs/root/CLAUDE.md` (doublon de racine)

---

## Notes Techniques

### Fichiers de Code Associes

| Document | Code Source |
|----------|-------------|
| DOC_11 Card System | `scripts/dru/dru_card_system.gd` |
| BESTIOLE_SYSTEM | `scripts/dru/dru_store.gd` (state.bestiole) |
| Effect Whitelist | `scripts/dru/dru_effect_engine.gd` |
| LLM Contract | `scripts/dru/dru_llm_adapter.gd` |

### Validation Automatique

Avant tout test Godot:
```powershell
.\validate.bat
```

---

*Document genere par Technical Writer Agent*
*Derniere mise a jour: 2026-02-08*
