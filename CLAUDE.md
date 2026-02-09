# CLAUDE.md — M.E.R.L.I.N.: Le Jeu des Oghams

> **IMPORTANT**: Ce fichier définit les comportements OBLIGATOIRES pour Claude Code sur ce projet.
> Conforme aux best practices Orange AI-assisted coding (v1.25.0, 2025-12-31)
> Voir aussi: `AGENTS.md` (racine) pour les instructions cross-outils.

---

## 🟠 CONFORMITÉ ORANGE (OBLIGATOIRE)

### Traçabilité AI — Tag [AI-assisted]

> **NOTE**: Ce projet (M.E.R.L.I.N.) est un projet personnel hors périmètre Orange.
> Le tag `[AI-assisted]` n'est PAS requis ici.
> Il est requis uniquement sur les projets Orange (Data, Cours, etc.).

Format commit: **Conventional Commits** — `type(scope): description`

```
feat(card-system): add seasonal event cards
fix(ui): resolve swipe gesture on mobile
refactor(store): simplify state management
```

### Frugalité des modèles — Adapter le tier au besoin

| Tâche | Modèle Claude Code | Commande |
|-------|-------------------|----------|
| Documentation, formatage, renommage simple | Haiku | Subagent `model: "haiku"` |
| Code standard, debug, review, UI | Sonnet (défaut) | Subagent `model: "sonnet"` |
| Architecture complexe, sécurité, refactoring multi-fichiers | Opus | Uniquement quand nécessaire |

**Règle**: Utiliser Haiku ou Sonnet pour les subagents (Task tool) sauf besoin architectural.
Exemple: `Task(model: "haiku", prompt: "Documente cette fonction")` au lieu d'Opus.

### Signature des commits

Tout commit doit être signé (GPG) par le développeur humain.
Configuration: `git config --global commit.gpgsign true`

---

## 🔴 RÈGLES D'AUTO-ACTIVATION (MANDATORY)

### 1. Planning Files — TOUJOURS UTILISER

**Dès qu'une tâche nécessite > 2 étapes, OBLIGATOIREMENT:**

```
1. LIRE progress.md et task_plan.md (si existants)
2. CRÉER/METTRE À JOUR task_plan.md avec les phases
3. METTRE À JOUR progress.md après chaque phase complétée
4. DOCUMENTER les erreurs dans findings.md
```

**Fichiers de planning (dans la racine du projet):**
| Fichier | Contenu |
|---------|---------|
| `task_plan.md` | Phases de travail, statuts, blockers |
| `progress.md` | Log de session, historique des changements |
| `findings.md` | Découvertes, recherches, erreurs rencontrées |

**Quand utiliser Planning Files:**
- Tâche avec 3+ étapes
- Modification de plusieurs fichiers
- Recherche ou investigation
- Nouvelle fonctionnalité
- Bug complexe
- Toute demande non-triviale

### 2. Validation Automatique — AVANT CHAQUE TEST

**Exécuter SYSTÉMATIQUEMENT avant tout test Godot:**

```powershell
# Validation complète (logs + static + extensions)
.\validate.bat

# Ou directement:
powershell -ExecutionPolicy Bypass -File tools/validate_godot_errors.ps1
```

**Ordre obligatoire:**
1. Éditer le code
2. Lancer `validate.bat`
3. Corriger les erreurs détectées
4. Relancer validation (doit passer)
5. PUIS tester dans Godot

### 3. Agents Spécialisés — INVOQUER SELON LE TYPE

**Matrice d'invocation OBLIGATOIRE:**

| Type de changement | Agent(s) à invoquer | Quand |
|--------------------|---------------------|-------|
| Code GDScript | `lead_godot.md`, `optimizer.md` | Review après implémentation |
| Performance/Memory | `godot_expert.md`, `optimizer.md` | Problèmes de perf, GDExtension |
| Intégration LLM | `llm_expert.md` | Prompts, latence, parsing |
| Tests/Bugs | `debug_qa.md` | Avant validation finale |
| **Correction apprise** | `debug_qa.md` | **Documenter dans knowledge base** |
| **Bonne pratique découverte** | `optimizer.md` | **Scanner et appliquer au code** |
| Interface UI | `ui_impl.md` | Layouts, thèmes, contrôles |
| Expérience UX | `ux_research.md` | Usabilité, feedback |
| Animations/VFX | `motion_designer.md` | Tweens, particules, easing |
| Shaders | `shader_specialist.md` | GLSL, effets visuels |
| Touch/Mobile | `mobile_touch_expert.md` | Gestes, responsive |
| Contenu cartes | `narrative_writer.md` | Textes, dialogues |
| Design règles | `game_designer.md` | Équilibrage, méchaniques |
| Assets visuels | `art_direction.md` | Style, cohérence graphique |
| Audio/Voix | `audio_designer.md` | SFX, musique, ACVoicebox |
| Documentation | `technical_writer.md` | Docstrings, API docs |
| Métriques jeu | `data_analyst.md` | Analytics, A/B testing |
| Planning | `producer.md` | Priorisation, milestones |
| Traduction | `localisation.md` | Multi-langue |
| **Phase terminée** | `git_commit.md` | **Commit des changements notables** |
| **Nettoyage projet** | `project_curator.md` | **Inventaire, fichiers orphelins** |

**Comment invoquer un agent:**
```
Task tool:
  subagent_type: "general-purpose"
  prompt: "Read .claude/agents/[AGENT_FILE].md and follow its instructions. Task: [DESCRIPTION]"
```

### 4. Workflow Standard — SÉQUENCE OBLIGATOIRE

```
┌─────────────────────────────────────────────────────────────┐
│  NOUVELLE TÂCHE REÇUE                                       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  1. LIRE progress.md (contexte session précédente)          │
│     LIRE task_plan.md (tâches en cours)                     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. CRÉER/METTRE À JOUR task_plan.md                        │
│     - Définir les phases                                     │
│     - Marquer status: pending/in_progress/complete           │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. IMPLÉMENTER (avec agents si nécessaire)                 │
│     - Invoquer agent(s) selon matrice                        │
│     - Documenter dans findings.md si découvertes             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. VALIDER                                                  │
│     - Exécuter .\validate.bat                                │
│     - Corriger jusqu'à VALIDATION PASSED                     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  5. DOCUMENTER                                               │
│     - Mettre à jour progress.md (phase complétée)            │
│     - Mettre à jour task_plan.md (status: complete)          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6. GIT COMMIT (AUTO)                                        │
│     - Invoquer git_commit.md automatiquement                 │
│     - Commit formaté [TYPE] message                          │
└─────────────────────────────────────────────────────────────┘
```

### 5. Agents Auto-Invoqués — SANS DEMANDE EXPLICITE

**Ces agents s'activent AUTOMATIQUEMENT selon les conditions:**

| Agent | Condition d'auto-activation |
|-------|----------------------------|
| `debug_qa.md` | **Correction GDScript apprise** (documenter dans knowledge base) |
| `optimizer.md` | **Bonne pratique découverte** (scanner et appliquer au code) |
| `git_commit.md` | Phase complétée avec fichiers modifiés (3+ fichiers OU changement notable) |
| `project_curator.md` | Demande de nettoyage, réorganisation, ou "fais le ménage" |

**Déclencheurs Debug/Optimizer (automatique):**
- Erreur GDScript corrigée → documenter dans `gdscript_knowledge_base.md`
- Pattern problématique identifié → ajouter à la knowledge base
- Nouveau code GDScript → scanner avec optimizer
- Bonne pratique mentionnée → appliquer à tout le projet

**Déclencheurs Git Commit (automatique):**
- Fin de phase dans progress.md
- Création de nouveaux fichiers importants
- Modification de 3+ fichiers liés
- Demande explicite de commit
- Fin de session de travail

**Déclencheurs Project Curator (sur demande ou périodique):**
- "Fais l'inventaire" / "Nettoie le projet"
- "Trouve les fichiers inutilisés"
- "Réorganise" / "Range"
- Avant un release majeur
- Quand archive/ grossit

**Format commit auto (Conventional Commits):**
```
type(scope): description courte

- Fichier 1: changement
- Fichier 2: changement

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**: feat, fix, refactor, docs, test, chore, perf
**Scope**: composant concerné (store, ui, llm, cards, lore, etc.)

> Pour les projets Orange (Data, Cours): ajouter `[AI-assisted]` en suffixe.

---

## Project Overview

M.E.R.L.I.N. is a narrative card game built with Godot 4.x.
- **Core Loop**: Choose from 3 options per card, balance 3 Aspects (Corps/Ame/Monde), survive
- **Game System**: Triade — 3 Aspects x 3 discrete states (Bas/Equilibre/Haut), Souffle d'Ogham
- **LLM Integration**: Qwen2.5-3B-Instruct Q4_K_M (2.0 GB) — Multi-Brain (1-4 cerveaux)
- **AI Architecture**: Narrator + Game Master in parallel, Worker Pool, RAG v2.0, guardrails
- **Companion**: Bestiole provides passive skills (18 Oghams)
- **Character**: Merlin le druide (narrator + guide)
- **Audio**: SFXManager (30+ procedural sounds, no external audio files)

---

## Quick Commands

```bash
# Validation (TOUJOURS avant test)
.\validate.bat

# Run Godot project
godot --path .

# Run specific scene
godot --path . scenes/MerlinGame.tscn

# Build MCP server
cd server && npm run build
```

---

## Architecture

### Core Systems (scripts/merlin/)
```
merlin_store.gd          <- Central state (Redux-like), Triade system
merlin_card_system.gd    <- Card engine, fallback pool, TRIADE generation
merlin_effect_engine.gd  <- SHIFT_ASPECT, SOUFFLE, KARMA, PROMISE
merlin_llm_adapter.gd    <- LLM contract, format TRIADE, JSON repair
merlin_constants.gd      <- 18 Oghams, 12 endings, 3 victoires
merlin_save_system.gd    <- 3 slots JSON
```

### UI Layer (scripts/ui/)
```
triade_game_ui.gd           <- 3 aspects, 3 options, souffle, typewriter
triade_game_controller.gd   <- Store-UI bridge, run flow, LLM wiring
```

### AI Layer (addons/merlin_ai/)
```
merlin_ai.gd             <- Multi-Brain (1-4 cerveaux), worker pool
merlin_omniscient.gd     <- Orchestrateur IA, pipeline parallele, guardrails
rag_manager.gd           <- RAG v2.0, token budget, priority, journal
```

### Key Documents
- `docs/MASTER_DOCUMENT.md` — Project overview (v4.0)
- `docs/20_card_system/DOC_12_Triade_Gameplay_System.md` — Triade system
- `docs/20_card_system/DOC_11_Card_System.md` — Card system
- `progress.md` — Session logs
- `task_plan.md` — Current tasks
- `.claude/agents/AGENTS.md` — Agent roster

---

## Code Style

### GDScript
- `snake_case` for variables and functions
- `PascalCase` for classes
- Prefix private methods with `_`
- Use type hints: `var x: int = 0`
- **JAMAIS** `:=` avec `CONST[index]` (utiliser type explicite)
- **JAMAIS** `yield()` (utiliser `await`)
- **JAMAIS** `//` pour division entière (utiliser `int(x/y)`)

### TypeScript (Server)
- `camelCase` for variables/functions
- `PascalCase` for classes/interfaces
- Strong typing, avoid `any`

---

## LLM Integration Rules (Qwen2.5-3B-Instruct + Multi-Brain)

### Model Info
- **Model**: Qwen2.5-3B-Instruct Q4_K_M (2.0 GB per brain)
- **Source**: https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF
- **Benchmark**: 83% comprehension, 100% logic, 100% role-play, 100% JSON
- **Architecture**: Multi-Brain (1-4 cerveaux adaptatifs par plateforme)

### Multi-Brain Roles
| Brain | Role | Params |
|-------|------|--------|
| Narrator (always) | Texte creatif, dialogues | T=0.7, top_p=0.9, max=200 |
| Game Master (desktop+) | Effets JSON (GBNF), equilibrage | T=0.2, top_p=0.8, max=150 |
| Worker Pool (3-4) | Prefetch, voice, balance check | Inherits from task type |

### Prompt Engineering
- Qwen2.5 follows instructions well — supports longer system prompts
- Supports French natively (29 languages)
- RAG v2.0: token budget 180, priority-based context
- Anti-hallucination guardrails: FR check, repetition detection (Jaccard), length bounds

### Current Parameters (in merlin_ai.gd)
```gdscript
# Narrator — creative text generation
var narrator_params := {
    "temperature": 0.7, "top_p": 0.9, "max_tokens": 200,
    "top_k": 40, "repetition_penalty": 1.3
}
# Game Master — structured JSON effects (GBNF)
var gamemaster_params := {
    "temperature": 0.2, "top_p": 0.8, "max_tokens": 150,
    "top_k": 20, "repetition_penalty": 1.0
}
```

---

## Game Design Summary

### 3 Aspects (Triade) — 3 etats discrets
| Aspect | Animal | Bas | Equilibre | Haut |
|--------|--------|-----|-----------|------|
| Corps | Sanglier | Epuise | Robuste | Surmene |
| Ame | Corbeau | Perdue | Centree | Possedee |
| Monde | Cerf | Exile | Integre | Tyran |

**Choix:** 3 options par carte (Gauche/Centre/Droite), Centre payant (Souffle)
**Souffle d'Ogham:** Max 7, depart 3, +1 si 3 aspects equilibres
**Fins:** 12 chutes (2 aspects extremes) + 3 victoires + 1 secrete
**Ref:** DOC_12_Triade_Gameplay_System.md, 09_LES_FINS.md

### Card Types
- Narrative (80%) — LLM-generated scenarios, 3 options
- Event (10%) — Time/season triggers
- Promise (5%) — Merlin pacts
- Merlin Direct (5%) — Narrator messages

### Bestiole Skills (18 Oghams)
- Starter: beith, luis, quert
- Categories: reveal, protection, boost, narrative, recovery, special
- Unlock via bond level

### Scenes Flow
```
IntroBoot -> IntroCeltOS -> IntroPersonalityQuiz -> IntroMerlinDialogue
  -> SceneEveil -> SceneAntreMerlin -> HubAntre
  -> TransitionBiome -> TriadeGame -> [Fin] -> HubAntre
```

---

## Audio Standards

### Voice (ACVoicebox)
- Merlin preset: robotic, low pitch (2.5)
- Letter-by-letter sync with typewriter
- pitch_variation: 0.12, speed_scale: 0.65

### UI Sounds
- Soft clicks for buttons
- Subtle feedback (hover, press)
- Location: `audio/sfx/ui/`

---

## 23 Agents + 1 Knowledge Base

Voir `.claude/agents/AGENTS.md` pour la liste complète et les instructions d'invocation.

| Catégorie | Agents |
|-----------|--------|
| Core Technical | Lead Godot, Godot Expert, LLM Expert, Debug/QA, **Optimizer**, Shader Specialist |
| UI/UX & Animation | UI Impl, UX Research, Motion Designer, Mobile/Touch Expert |
| Content & Creative | Game Designer, Narrative Writer, Art Direction, Audio Designer |
| Operations & Docs | Producer, Localisation, Technical Writer, Data Analyst |
| **Project Management** | **Git Commit, Project Curator** |
| **Knowledge Sharing** | **gdscript_knowledge_base.md** (ressource partagée) |

### Knowledge Base (NOUVEAU)

Fichier: `.claude/agents/gdscript_knowledge_base.md`

**Contenu:**
- Erreurs GDScript courantes et corrections
- Patterns d'optimisation
- Leçons apprises au fil des sessions
- Log chronologique des corrections

**Agents qui l'utilisent:**
- `debug_qa.md` — documente les corrections
- `optimizer.md` — applique les corrections au code

---

*Updated: 2026-02-09 — Triade system, Multi-Brain architecture, documentation cleanup v4.0*
