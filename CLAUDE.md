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

### 4. AUTODEV v4 — Subagents + VS Code Sidebar

**Architecture**: Les workers sont des **subagents Claude Code** (Task tool) lances depuis la conversation VS Code.
Un **sidebar panel VS Code** (`vscode-monitor-v4/`) affiche la progression en temps reel.

#### 4a. Lancement via Claude Code (mot-cle `autodev:`)

```
1. DETECTER "autodev:" au debut du message
2. PARSER l'objectif → identifier les domaines concernes
3. ECRIRE status/session.json { state: "running", objective, workers: [...] }
4. ECRIRE status/worker_{domain}.json { status: "pending" } pour chaque worker
5. LANCER Task tool subagents EN PARALLELE (run_in_background: true)
6. ATTENDRE les resultats (TaskOutput)
7. CHECKPOINT: resumer les resultats a l'utilisateur
8. LANCER subagent validation (validate.bat Step 0)
9. CHECKPOINT: afficher resultats validation
10. Si erreurs → lancer subagent fix
11. ECRIRE status/session.json { state: "done" }
```

#### 4b. Status Protocol (3 fichiers JSON)

| Fichier | Contenu |
|---------|---------|
| `status/session.json` | Etat global: state, objective, workers[], checkpoint |
| `status/worker_{name}.json` | Par subagent: status, current_task, progress, log[], error |
| `status/validation.json` | Resultats validate.bat: status, errors, warnings, details[] |

#### 4c. Subagent Worker Prompt Template

```
Tu es un worker AUTODEV pour le domaine "{domain}" du projet M.E.R.L.I.N. (Godot 4).
OBJECTIF: {objective}
TACHES: {tasks_list}
SCOPE: {file_scope}
PROTOCOLE: Ecris status/worker_{domain}.json apres CHAQUE tache.
```

#### 4d. VS Code Sidebar

- Extension: `tools/autodev/vscode-monitor-v4/`
- Symlink: `~/.vscode/extensions/autodev-monitor-v4/`
- Read-only: affiche session + workers + validation + logs
- Refresh: fs.watch + fallback poll 5s

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
ollama_backend.gd        <- Backend Ollama HTTP API, model per instance, thinking mode
merlin_ai.gd             <- Multi-Brain heterogene (Qwen 3.5), time-sharing, routing
brain_swarm_config.gd    <- Hardware profiles NANO/SINGLE/SINGLE+/DUAL/TRIPLE/QUAD
merlin_omniscient.gd     <- Orchestrateur IA, zero fallback, scene cache, guardrails
rag_manager.gd           <- RAG v3.0, per-brain context budget, journal
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

## LLM Multi-Cerveaux Heterogene (Qwen 3.5 + Ollama)

### Principe fondamental
- **LLM = peau expressive** (texte, ton, ambiance, poetique)
- **Code = cerveau logique** (profiling joueur, equilibrage Triade, arcs, danger)
- Le LLM n'a pas besoin d'etre intelligent — il doit etre EXPRESSIF
- Tout raisonnement (calcul, state, decisions) est fait en GDScript
- **Chaque cerveau utilise un modele different**, optimise pour son role

### Model & Backend
- **Narrator**: Qwen 3.5-4B (~3.2 GB via Ollama) — creatif, vocabulaire riche
- **Game Master**: Qwen 3.5-2B (~1.8 GB) + thinking mode — precision JSON
- **Judge/Workers**: Qwen 3.5-0.8B (~0.8 GB) — taches rapides
- **Backend primaire**: Ollama HTTP API (`/api/generate`, raw=true)
- **Backend secondaire**: MerlinLLM C++ GDExtension (fallback, legacy)
- **Chat template**: ChatML | **Context**: 8192 (narrator), 4096 (GM), 2048 (workers)
- **Ollama**: `ollama pull qwen3.5:4b qwen3.5:2b qwen3.5:0.8b`
- **LoRA**: Per-brain QLoRA adapters (voir `docs/LORA_TRAINING_SPEC.html`)

### Pipeline Sequentiel (Narrator-first, time-sharing sur 8GB RAM)
```
1. CODE decide QUOI (profil joueur, danger, arc, biome, jour/saison)
2. Narrator/4B genere texte + 3 choix (~6-8s, 200 tok, T=0.70)
3. GM/2B+think genere effets JSON (~2-3s, 120 tok, T=0.15)
4. CODE valide (guardrails + Quality Judge) + display
5. SINGLE+ mode: swap modele entre etapes 2 et 3 (~2s penalty)
```

### Multi-Cerveaux (tiers adaptatifs)
| Brain | Model | Role | Params | Thinking |
|-------|-------|------|--------|----------|
| Narrator | qwen3.5:4b | Texte creatif, choix | T=0.70, top_p=0.90, max=180 | OFF |
| Game Master | qwen3.5:2b | Effets JSON, equilibrage | T=0.15, top_p=0.8, max=80 | ON |
| Judge | qwen3.5:0.8b | Scoring qualite (QUAD+) | T=0.1, max=100 | ON |
| Workers | qwen3.5:0.8b | Prefetch, voix, balance | T=0.3, max=50 | OFF |

### Hardware Tiers (auto-detection)
| Tier | RAM | Mode | Latence/carte |
|------|-----|------|---------------|
| NANO (0.8B) | 4 GB | Resident | ~12s |
| SINGLE (2B) | 6 GB | Resident | ~10s |
| **SINGLE+ (4B/2B)** | **7 GB** | **Time-sharing** | **~12-15s** |
| DUAL (4B+2B) | 12 GB | Parallele | ~8s |
| QUAD (4B+2B+2x0.8B) | 16 GB | Parallele | ~7s |

### 27 Capacites LLM (3 categories)
**Narrator (7)**: Narration immersive, choix significatifs (GBNF), adaptation au joueur, arcs multi-cartes, personnalite Merlin, atmosphere biome, conscience temporelle
**Game Master (4)**: Equilibrage intelligent, detection danger, economie Souffle, minigames
**Unique/Differenciateurs (9)**: Profilage psychologique, emergent storytelling, memoire cross-run, Bestiole personnalite, ambiguite morale, Merlin 4e mur, difficulte narrative, generation lore, dialogue interactif
**Innovants (7)**: Visual tags proceduraux, audio tags adaptatifs, chemins non-pris, titres joueur, recaps fin de run, reves inter-runs, tutoriel narratif
**Ref**: `docs/VISION_LLM_BI_CERVEAUX.html`, `docs/LLM_CAPABILITIES_MATRIX.html`

### Zero Fallback Policy
- **Aucune carte statique** — toutes proviennent du LLM
- Echec: retry backoff + "Merlin medite..." overlay + hub en dernier recours
- GBNF grammar force le format (remplace parsing regex fragile)

### Performance KPIs
| Metrique | Seuil | Actuel | Cible post-LoRA |
|----------|-------|--------|-----------------|
| p50 latence (warm) | < 10s | ~7s | ~8s (sequentiel) |
| Fallback statique | 0% | ~30% | 0% (GBNF) |
| Celtic vocab density | > 5 mots/carte | ~2 | > 5 (LoRA) |
| French output | > 95% | 80% | > 95% (LoRA) |
| Format compliance | > 95% | ~70% | > 95% (GBNF) |
| Throughput | > 10 tok/s | 17.8 | 17.8 |

### Benchmarks
- **CLI**: `python tools/test_merlin_chat.py --mode perf --perf-runs 20`
- **In-engine**: Scene `TestTriadeLLMBenchmark.gd`
- **LoRA**: `python tools/lora/benchmark_lora.py`

### Prompt Engineering
- Prompts COURTS (<200 tokens system) — petit modele perd le fil au-dela
- EXEMPLES > INSTRUCTIONS — 2-3 few-shot valent mieux que 10 regles
- GBNF grammar pour Narrator (format) ET GM (JSON)
- RAG v2.0: 400 tokens, 12 sections prioritisees (CRITICAL→OPTIONAL)
- Ref complete: `docs/BI_BRAIN_PROMPT_GUIDE.html`

### LoRA Strategy (CPU-friendly)
- **Config**: QLoRA r=16, alpha=32, 3-5 epochs, Qwen 2.5-1.5B
- **5 competences**: ton celtique (200ex), format (500ex), arcs (250ex), dilemmes (100ex), Merlin (150ex)
- **NE PAS LoRA**: adaptation joueur, danger, temporel, profiling, cross-run (prompt/code suffit)
- **Pipeline**: `tools/lora/` (export → augment → train → convert → benchmark)
- **Ref**: `docs/LORA_TRAINING_SPEC.html`

### Agents LLM (7 + 3 nouveaux)
- `llm_expert.md` — Prompt engineering, RAG, guardrails, Multi-Brain, GBNF
- `bi_brain_orchestrator.md` — **Pipeline sequentiel, visual/audio tags, prefetch, dialogue Merlin**
- `narrative_arc_designer.md` — **Arcs multi-cartes, state machine, callbacks, reves**
- `player_profiler.md` — **Profil psychologique, adaptation, danger, difficulte narrative**
- `lora_gameplay_translator.md` → `lora_data_curator.md` → `lora_training_architect.md` → `lora_evaluator.md`

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

## 37 Agents + 1 Knowledge Base

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
