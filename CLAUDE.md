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

### 3. Smart Workflow — ADAPTATIF

**Classifier la complexite AVANT d'agir:**

| Complexite | Critere | Action |
|------------|---------|--------|
| **TRIVIAL** | 1 fichier, <10 lignes, typo/rename | Faire directement. Ni dispatcher, ni planning files. |
| **SIMPLE** | 1-2 fichiers, tache claire | Faire directement. MAJ progress.md apres. |
| **MODEREE** | 3+ fichiers OU logique complexe | Planning files obligatoires. Dispatcher optionnel. |
| **COMPLEXE** | Multi-systeme, architecture, feature majeur | Dispatcher + planning files + agents review. |

**Prompt optimizer actif**: Le hook severity1 evalue automatiquement la clarte des prompts.
Prefixer avec `*` pour bypass. Les slash commands (`/`) sont auto-bypassees.

**Agents auto**: `debug_qa.md` (si .gd modifie), `git_commit.md` (3+ fichiers ou phase complete).
**Ref dispatcher/matrice/agents**: `.claude/agents/task_dispatcher.md` (lire QUE si MODEREE+).

**Format commit**: Conventional Commits `type(scope): description`
`Co-Authored-By: Claude <noreply@anthropic.com>`
**Types**: feat, fix, refactor, docs, test, chore, perf | **Scope**: composant (store, ui, llm, cards, etc.)

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
Premiere partie:
  IntroCeltOS -> MenuPrincipal -> IntroPersonalityQuiz -> SceneRencontreMerlin
    -> HubAntre -> TransitionBiome -> TriadeGame -> [Fin] -> HubAntre

Boucle roguelite:
  HubAntre -> TransitionBiome -> TriadeGame -> [Fin] -> HubAntre

Continuer:
  MenuPrincipal -> SelectionSauvegarde -> HubAntre
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

## 29 Agents + 1 Knowledge Base

Voir `.claude/agents/AGENTS.md` pour la liste complète et les instructions d'invocation.

| Catégorie | Agents |
|-----------|--------|
| **Orchestration** | **Task Dispatcher** (invoque si complexite MODEREE+, voir Smart Workflow) |
| Core Technical (6) | Lead Godot, Godot Expert, LLM Expert, Debug/QA, Optimizer, Shader Specialist |
| UI/UX & Animation (4) | UI Impl, UX Research, Motion Designer, Mobile/Touch Expert |
| Content & Creative (4) | Game Designer, Narrative Writer, Art Direction, Audio Designer |
| Lore & World-Building (3) | Merlin Guardian, Lore Writer, Historien Bretagne |
| Operations & Docs (4) | Producer, Localisation, Technical Writer, Data Analyst |
| Project Management (2) | Git Commit, Project Curator |
| **Security & Quality (3)** | **Accessibility Specialist, Security Hardening, Prompt Curator** |
| **Progression & Economy (1)** | **Meta-Progression Designer** |
| **CI/CD & Release (1)** | **CI/CD Release** |
| Knowledge Sharing | gdscript_knowledge_base.md (ressource partagée) |

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

*Updated: 2026-02-09 — 29 agents (5 new), enriched competencies, Task Dispatcher v1.1*
