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

### 2b. Post-Dev Checklist — FIN DE SESSION (OBLIGATOIRE)

**SYSTÉMATIQUEMENT après chaque modification de fichiers .gd/.tscn:**

```
1. VALIDATE  — .\validate.bat (Step 0 minimum)
2. FIX       — Corriger TOUTES erreurs + warnings
3. REVALIDATE — Confirmer 0 errors, 0 warnings
4. COMMIT    — git add + git commit (conventional commits)
5. PUSH      — git push origin main (ou rappeler si auth requise)
```

**JAMAIS** terminer une session ou répondre "terminé" sans avoir fait les 5 étapes.
**Erreurs typiques à vérifier**: type inference (`:=` sur Variant), static call on instance, unused vars.

### 3. Smart Workflow — ADAPTATIF

**Classifier la complexite AVANT d'agir:**

| Complexite | Critere | Action |
|------------|---------|--------|
| **TRIVIAL** | 1 fichier, <10 lignes, typo/rename | Faire directement. Ni dispatcher, ni planning files. |
| **SIMPLE** | 1-2 fichiers, tache claire | Faire directement. MAJ progress.md apres. |
| **MODEREE** | 3+ fichiers OU logique complexe | Planning files obligatoires. Dispatcher optionnel. |
| **COMPLEXE** | Multi-systeme, architecture, feature majeur | Dispatcher + planning files + agents review. |

**Hook v2 actif**: `route-and-dispatch.py` detecte automatiquement le projet, classifie la complexite, et injecte le dispatcher + skills.
Prefixer avec `*` pour bypass. Les slash commands (`/`) et `#` sont auto-bypassees.
Source de verite: `~/.claude/project_registry.json` (detection projet, keywords, branding, skills).

**Agents auto**: `debug_qa.md` (si .gd modifie), `git_commit.md` (3+ fichiers ou phase complete).
**LoRA auto**: `lora_gameplay_translator.md` si demande adaptation LLM ("le modele doit", "entraine", "fine-tune", "plus poetique/celtique").
**Dispatcher**: `.claude/agents/task_dispatcher.md` (overlay v2.0, EXTENDS `~/.claude/agents/common/dispatcher_base.md`).
**Agents communs**: `~/.claude/agents/common/` — dispatcher_base, git_commit_base, security_review_base, planning_enforcer, AGENT_TEMPLATE.
**Metriques**: `~/.claude/metrics/agent_invocations.jsonl` (hook PostToolUse automatique, dashboard: `python ~/.claude/metrics/dashboard.py`).

**Format commit**: Conventional Commits `type(scope): description`
`Co-Authored-By: Claude <noreply@anthropic.com>`
**Types**: feat, fix, refactor, docs, test, chore, perf | **Scope**: composant (store, ui, llm, cards, etc.)

> Pour les projets Orange (Data, Cours): ajouter `[AI-assisted]` en suffixe.

---

## Project Overview

M.E.R.L.I.N. is a narrative card game built with Godot 4.x.
- **Core Loop**: Choose from 3 options per card, balance 3 Aspects (Corps/Ame/Monde), survive
- **Game System**: Triade — 3 Aspects x 3 discrete states (Bas/Equilibre/Haut), Souffle d'Ogham
- **LLM Integration**: Qwen 2.5-1.5B (1.0 GB via Ollama, 17.8 tok/s) — DUAL Brain default
- **AI Architecture**: Narrator + Game Master in parallel, Worker Pool, RAG v2.0, guardrails
- **Companion**: Bestiole provides passive skills (18 Oghams)
- **Character**: Merlin le druide (narrator + guide)
- **Audio**: SFXManager (30+ procedural sounds, no external audio files)

---

## Quick Commands

```bash
# Validation (TOUJOURS avant test — inclut Editor Parse Check)
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

### Visual System (scripts/autoload/)
```
merlin_visual.gd            <- Centralized visual constants (PALETTE, GBC, fonts, animations)
```
- **UI/UX Bible**: `docs/70_graphic/UI_UX_BIBLE.md` — Complete visual specification
- **Agent Rules**: `.claude/agents/ui_consistency_rules.md` — Binding rules for UI agents
- **RULE**: ALL colors from `MerlinVisual.PALETTE` / `MerlinVisual.GBC`, ALL fonts from `MerlinVisual.get_font()`
- **RULE**: `var c: Color = MerlinVisual.PALETTE["x"]` (explicit type, NEVER `:=` with Dictionary)

### AI Layer (addons/merlin_ai/)
```
ollama_backend.gd        <- Backend Ollama HTTP API (drop-in MerlinLLM)
merlin_ai.gd             <- Multi-Brain (1-2 cerveaux), routing Ollama/MerlinLLM
merlin_omniscient.gd     <- Orchestrateur IA, zero fallback, scene cache, guardrails
rag_manager.gd           <- RAG v2.0, biome cache, token budget 400, journal
```

### Key Documents
- `docs/MASTER_DOCUMENT.md` — Project overview (v4.0)
- `docs/70_graphic/UI_UX_BIBLE.md` — Visual system specification (palettes, typography, animations, per-scene rules)
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

## LLM Integration Rules (Qwen 2.5-1.5B + Ollama + DUAL Brain)

### Model & Backend
- **Model**: Qwen 2.5-1.5B (~1.0 GB via Ollama, 17.8 tok/s)
- **Backend primaire**: Ollama HTTP API (`/api/generate`, raw=true, ~8s/carte avec 150 tokens)
- **Backend secondaire**: MerlinLLM C++ GDExtension (Qwen 3B GGUF, fallback si pas Ollama)
- **Ollama**: `ollama pull qwen2.5:1.5b`
- **Chat template**: ChatML (`<|im_start|>/<|im_end|>`)
- **Context window**: 4096 tokens (Ollama), 2048 (MerlinLLM)
- **Prompt format**: Plain text (pas de JSON) — scene + A)/B)/C) choices

### DUAL Brain (default, CPU >= 6 threads)
| Brain | Role | Params |
|-------|------|--------|
| Narrator (always) | Texte creatif, dialogues | T=0.75, top_p=0.92, max=150 |
| Game Master (dual+) | Effets JSON, equilibrage, prefetch | T=0.15, top_p=0.8, max=80 |

### Zero Fallback Policy
- **Aucune carte statique** n'est jamais servie au joueur
- Toutes les cartes proviennent du LLM (Ollama ou MerlinLLM)
- Echec LLM: retry backoff + "Merlin medite..." overlay + retour hub en dernier recours
- Labels generiques: `["Avancer prudemment", "Observer en silence", "Agir sans hesiter"]` (si LLM omet les labels)
- Parsers permissifs: gere A), **A)**, A:, Action A:, - **B**: etc.

### Performance KPIs
| Metrique | Seuil | Actuel (1.5B, 150tok) | Benchmark |
|----------|-------|-----------------------|-----------|
| p50 latence (warm) | < 10s | **~7s** | `--mode perf` |
| p90 latence (warm) | < 15s | **~11s** | `--mode perf` |
| Fallback rate | 0% | 0% | Zero Fallback test |
| Text variety (Jaccard) | < 0.7 | OK | Zero Fallback test |
| Throughput | > 10 tok/s | **17.8 tok/s** | `--mode perf` |
| French output | > 80% | **80%** | Quality test |

### Benchmarks
- **CLI**: `python tools/test_merlin_chat.py --mode perf --perf-runs 20`
- **In-engine**: Scene `TestTriadeLLMBenchmark.gd` (Perf + Zero Fallback buttons)
- **Resultats**: `tmp/perf_results.json`

### Prompt Engineering
- Qwen 2.5 uses ChatML format — supports structured system prompts
- Supports French natively
- RAG v2.0: token budget 400, biome cache, priority-based context
- Scene context: version-tracked cache (deduplique refresh 4x → 1x)
- Anti-hallucination guardrails: FR check, repetition detection (Jaccard), length bounds
- Buffer: 5 cartes pre-generees, prefetch Brain 2 si dual

### Current Parameters (in merlin_ai.gd)
```gdscript
# Narrator — creative text generation
var narrator_params := {
    "temperature": 0.75, "top_p": 0.92, "max_tokens": 150,
    "top_k": 40, "repetition_penalty": 1.35
}
# Game Master — structured JSON effects
var gamemaster_params := {
    "temperature": 0.15, "top_p": 0.8, "max_tokens": 80,
    "top_k": 15, "repetition_penalty": 1.0
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
    -> HubAntre -> TransitionBiome -> MerlinGame -> [Fin] -> HubAntre

Boucle roguelite:
  HubAntre -> TransitionBiome -> MerlinGame -> [Fin] -> HubAntre

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

## 33 Agents + 1 Knowledge Base

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
| **LoRA Fine-Tuning (4)** | **LoRA Gameplay Translator, LoRA Data Curator, LoRA Training Architect, LoRA Evaluator** |
| Knowledge Sharing | gdscript_knowledge_base.md (ressource partagée) |

### LoRA Fine-Tuning Pipeline (NOUVEAU)

**4 agents spécialisés** forment un pipeline complet de fine-tuning du modèle Qwen 2.5-3B :

| Agent | Fichier | Rôle |
|-------|---------|------|
| **LoRA Gameplay Translator** | `lora_gameplay_translator.md` | **POINT D'ENTREE** — traduit demande gameplay → spec d'entraînement |
| **LoRA Data Curator** | `lora_data_curator.md` | Extraction, curation, augmentation des datasets |
| **LoRA Training Architect** | `lora_training_architect.md` | Hyperparamètres, architecture adapter, pilotage training |
| **LoRA Evaluator** | `lora_evaluator.md` | Benchmark, métriques, décision GO/NO-GO |

**Auto-activation**: Quand l'utilisateur demande "entraine le modèle", "le LLM doit", "plus poétique",
"fine-tune", "adapte le modèle pour [gameplay]" → `lora_gameplay_translator.md` s'active automatiquement.

**Pipeline**: `tools/lora/` (export → augment → train → convert → benchmark)
**Datasets**: `data/ai/training/` (brut + augmenté, format ChatML)
**Adapters**: `addons/merlin_llm/adapters/` (fichiers .gguf)

### Skills Transversaux (AUTO-ACTIVATION)

**REGLE MCP-FIRST**: Les MCP (godot-mcp, dbeaver) sont l'action primaire. Les skills completent la methode.
`get_script` / `scene_tree` → MCP Godot d'abord, skills ensuite.

| Skill | Quand | Phase | Slash Command |
|-------|-------|-------|---------------|
| `planning-with-files` | Tache > 2 etapes | DEBUT | Auto (hooks) |
| `superpowers-writing-plans` | Spec multi-step avant code | DEBUT | `/write-plan` |
| `superpowers-executing-plans` | Executer un plan ecrit | EXECUTION | `/execute-plan` |
| `superpowers-systematic-debugging` | Bug, erreur, comportement inattendu | APRES repro | Auto |
| `superpowers-test-driven-development` | Nouvelle feature ou bug fix | AVANT code | Auto |
| `superpowers-verification-before-completion` | Avant commit/PR | FIN | Auto |
| `superpowers-dispatching-parallel-agents` | 2+ taches independantes | DEBUT | Auto |
| `superpowers-requesting-code-review` | Apres implementation | FIN | Auto |
| `tdd-workflow` (ECC) | TDD GDScript | AVANT code | `/tdd` |
| `verification-loop` (ECC) | Verification complete | FIN | `/verify` |
| `security-review` (ECC) | Save system, LLM input, data | VALIDATION | Auto |
| `coding-standards` (ECC) | Code GDScript quality | VALIDATION | Auto |
| `ui-ux-pro-max` | Interface UI/UX design | CONCEPTION | Auto |

**GSD Commands disponibles:**
- `/gsd:plan-phase` — Planifier une phase de dev
- `/gsd:execute-phase` — Executer avec wave-based parallelization
- `/gsd:debug` — Debugging systematique persistant
- `/gsd:verify-work` — Verification avant commit
- `/gsd:map-codebase` — Cartographier l'architecture
- `/gsd:progress` — Voir l'avancement global

Ref complete: `~/.claude/rules/common/skill-activation-matrix.md`

### Knowledge Base

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

*Updated: 2026-02-18 — Agent system v2.0 (common base + overlays), Hook v2 (route-and-dispatch), Metrics, 33 agents + 5 common*
