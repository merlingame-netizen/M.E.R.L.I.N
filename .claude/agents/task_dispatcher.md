# Task Dispatcher — M.E.R.L.I.N.

> **EXTENDS**: `~/.claude/agents/common/dispatcher_base.md`
> **Lire le dispatcher base EN PREMIER** pour le workflow universel en 6 etapes,
> le format de sortie, les cascades standard, et les regles d'ordonnancement.
> Ce fichier ne contient que la **taxonomie projet-specifique** de M.E.R.L.I.N.

---

## Auto-Activation Rules (projet)

**TOUJOURS ajouter ces agents quand les conditions sont remplies:**

| Agent | Condition |
|-------|-----------|
| `debug_qa.md` | Tache implique des .gd OU corrige des bugs OU teste des fonctionnalites |
| `optimizer.md` | Tache cree/modifie du code GDScript |
| `git_commit.md` | Tache est une phase complete OU modifie 3+ fichiers |
| `project_curator.md` | Mots-cles: "inventaire", "nettoie", "range", "cleanup", "orphan" |

---

## Taxonomie de Classification

### Direction Creative (NEW)

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Direction Creative** | vision du jeu, direction creative, le joueur doit ressentir, coherence narrative, est-ce coherent, priorite feature, conflit agents, ton du jeu, emotion visee | `game_director.md` | `merlin_guardian.md`, `game_designer.md` |

> **REGLE** : Le Game Director est consulte AVANT implementation quand une decision creative
> est ambigue. Il repond avec un verdict (APPROUVE/REJETE/MODIFIE/ESCALADE_PDG) et un test emotionnel.
> Decisions sur les piliers VARIABLES : autonome. Piliers IMMUABLES : escalade au PDG humain.

### Taches Techniques Core

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **GDScript Code** | `.gd`, script, code, function, class, variable, methode | `lead_godot.md`, `optimizer.md` | `debug_qa.md` |
| **Performance** | slow, lag, optimize, memory, FPS, performance, bottleneck | `godot_expert.md`, `optimizer.md` | `lead_godot.md` |
| **LLM Integration** | LLM, prompt, Qwen, AI, brain, RAG, generation, parsing, GBNF | `llm_expert.md` | `lead_godot.md`, `godot_expert.md` |
| **Bug Fix** | bug, error, fix, broken, crash, not working, erreur, corrige | `debug_qa.md` | `lead_godot.md`, [agent du domaine] |
| **Tests** | test, QA, validation, verify, benchmark | `debug_qa.md` | `lead_godot.md` |

### Taches UI/UX

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **UI Layout** | UI, button, layout, control, theme, panel, dialog, menu, label | `ui_impl.md` | `ux_research.md` |
| **UX Design** | UX, usability, flow, feedback, interaction, feel, experience | `ux_research.md` | `ui_impl.md`, `game_designer.md` |
| **Animation** | animate, tween, particle, VFX, easing, transition, fade | `motion_designer.md` | `ui_impl.md` |
| **Shader** | shader, GLSL, visual effect, post-process, material, gdshader | `shader_specialist.md` | `godot_expert.md` |
| **Mobile/Touch** | mobile, touch, swipe, gesture, responsive, tactile | `mobile_touch_expert.md` | `ux_research.md` |

### Taches Contenu & Design

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Contenu Cartes** | card, text, dialogue, narrative, story, choice, option, carte | `narrative_writer.md` | `game_designer.md` |
| **Game Design** | balance, rules, mechanic, system, progression, difficulty, equilibrage | `game_designer.md` | `data_analyst.md` |
| **Assets Visuels** | art, sprite, texture, visual, graphics, style, pixel, image | `art_direction.md` | `ui_impl.md` |
| **Audio** | sound, SFX, music, audio, voice, ACVoicebox, voix | `audio_designer.md` | `ui_impl.md` |
| **Lore Merlin** | Merlin, personality, voice, character, personnalite, druide | `merlin_guardian.md` | `narrative_writer.md`, `lore_writer.md` |
| **Lore Deep** | mythology, lore, Ogham, Celtic, Breton, secret, apocalypse | `lore_writer.md` | `merlin_guardian.md`, `narrative_writer.md` |
| **Histoire** | Bretagne, Celtic history, authentic, recherche historique | `historien_bretagne.md` | `lore_writer.md` |

### Taches Operations & Docs

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Documentation** | docs, documentation, comment, docstring, README, tutorial | `technical_writer.md` | `lead_godot.md` |
| **Metriques** | analytics, metrics, data, A/B, stats, tracking, statistiques | `data_analyst.md` | `game_designer.md` |
| **Planning** | plan, roadmap, milestone, sprint, priority, schedule | `producer.md` | `game_designer.md` |
| **Traduction** | translate, i18n, locale, language, francais, anglais | `localisation.md` | `narrative_writer.md` |
| **Cleanup** | cleanup, inventory, orphan, unused, range, nettoie, inventaire | `project_curator.md` | `lead_godot.md` |

### Taches Securite & Qualite (NOUVEAU)

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Accessibilite** | accessibility, WCAG, daltonien, colorblind, keyboard nav, screen reader, a11y | `accessibility_specialist.md` | `ux_research.md`, `ui_impl.md` |
| **Securite** | security, encrypt, sanitize, RGPD, GDPR, privacy, tampering, injection, save integrity | `security_hardening.md` | `lead_godot.md`, `debug_qa.md` |
| **Qualite LLM** | golden dataset, hallucination, celtic validation, prompt quality, content curation, lore accuracy | `prompt_curator.md` | `llm_expert.md`, `narrative_writer.md` |
| **CI/CD** | build, pipeline, deploy, release, export, GitHub Actions, Steam, fastlane, APK, IPA | `ci_cd_release.md` | `producer.md`, `debug_qa.md` |
| **Meta-Progression** | talent tree, arbre de vie, essence, bestiole bond, evolution, unlock, pacing, synergy, run reward | `meta_progression_designer.md` | `game_designer.md`, `data_analyst.md` |

### LLM Bi-Brain Architecture (NOUVEAU)

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Pipeline LLM Bi-Brain** | pipeline LLM, visual tags, audio tags, bi-brain, bi-cerveaux, sequentiel GM→Narrator | `bi_brain_orchestrator.md` | `llm_expert.md` |
| **Arcs Narratifs** | arc narratif, coherence cartes, multi-cartes, callback, reve, temporel | `narrative_arc_designer.md` | `llm_expert.md`, `narrative_writer.md` |
| **Profil Joueur** | profil joueur, adaptation, danger, difficulte narrative, player pattern, psychologique | `player_profiler.md` | `game_designer.md`, `llm_expert.md` |

### Routing LLM Bi-Brain (NOUVEAU)

| Trigger | Agent(s) | Ordre |
|---------|----------|-------|
| Modification merlin_ai.gd, ollama_backend.gd | bi_brain_orchestrator | Avant llm_expert |
| Modification rag_manager.gd (arcs, journal) | narrative_arc_designer | Apres llm_expert |
| Modification difficulty, player_pattern | player_profiler | Apres game_designer |
| "pipeline LLM", "visual tags", "audio tags" | bi_brain_orchestrator | Seul ou + llm_expert |
| "arc narratif", "coherence cartes" | narrative_arc_designer | Seul |
| "profil joueur", "adaptation", "danger" | player_profiler | Seul |
| "entrainement", "LoRA", "fine-tune" | lora_gameplay_translator | Pipeline LoRA complet |

### LoRA Fine-Tuning (NOUVEAU)

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Adaptation LLM** | entraine le modele, fine-tune, LoRA, adapter, le LLM doit, le modele doit, specialize, ameliore la generation, plus poetique, plus celtique, meilleur ton, autre registre | `lora_gameplay_translator.md` | `llm_expert.md`, `prompt_curator.md` |
| **Donnees d'entrainement** | dataset, training data, augmentation, export donnees, enrichir dataset | `lora_data_curator.md` | `prompt_curator.md`, `narrative_writer.md` |
| **Training / hyperparametres** | training, entrainement, rank, alpha, epochs, learning rate, overfitting, convergence | `lora_training_architect.md` | `llm_expert.md` |
| **Evaluation modele** | benchmark, metriques LoRA, evaluer le modele, qualite generation, tone accuracy, GO/NO-GO | `lora_evaluator.md` | `llm_expert.md`, `prompt_curator.md` |

> **IMPORTANT — Pipeline LoRA auto-orchestre**: Quand le type est "Adaptation LLM",
> le `lora_gameplay_translator.md` est TOUJOURS le point d'entree. Il orchestre
> automatiquement les 3 autres agents (data → training → eval).
> NE PAS invoquer les agents LoRA individuellement sauf demande explicite.

### Autonomous Studio (NOUVEAU)

| Type | Mots-cles de detection | Agents primaires | Agents review |
|------|------------------------|-----------------|---------------|
| **Studio Mode** | lance le studio, overnight, deep test, quick qa, content sprint, polish pass, mode studio, full QA | `studio_orchestrator.md` | Tous selon mode |
| **Playtest intelligent** | joue au jeu, playtest, teste le gameplay, simule un joueur, lance une partie | `playtester_ai.md` | `balance_analyst.md`, `game_designer.md` |
| **Equilibrage** | equilibrage, balance du jeu, statistiques, distribution des fins, desequilibre, trop de morts | `balance_analyst.md` | `game_designer.md`, `playtester_ai.md` |
| **Stress testing** | stress test, spam click, AFK test, crash test, comportement extreme, robustesse | `player_simulator.md` | `debug_qa.md`, `regression_guardian.md` |
| **Generation contenu** | genere du contenu, nouvelles cartes, nouveaux events, enrichis le jeu, manque de contenu | `content_factory.md` | `merlin_guardian.md`, `visual_qa.md` |
| **Construction monde** | nouveau biome, nouveau lieu, construction de monde, environnement | `world_builder.md` | `content_factory.md`, `merlin_guardian.md` |
| **QA visuelle** | regression visuelle, compare screenshots, baseline, le rendu a change | `visual_qa.md` | `art_direction.md`, `ui_impl.md` |
| **Regression** | regression, avant/apres, la perf a baisse, ca marchait avant | `regression_guardian.md` | `perf_profiler.md`, `debug_qa.md` |
| **Pre-release** | pre-release, checklist qualite, GO/NO-GO, pret a livrer | `release_quality.md` | `studio_orchestrator.md` |
| **Performance runtime** | profile performance, FPS drop, memory leak, le jeu rame, latence | `perf_profiler.md` | `optimizer.md`, `godot_expert.md` |

> **IMPORTANT — Studio Orchestrator**: Pour les modes complets (Overnight, Deep Test, etc.),
> le `studio_orchestrator.md` est le point d'entree. Il coordonne automatiquement les autres
> agents du studio. Pour des taches isolees (juste le playtest, juste la QA visuelle), invoquer
> l'agent specifique directement.

---

## Patterns de Fichiers → Agents Additionnels

Quand la tache mentionne des chemins specifiques:

| Pattern de chemin | Agents additionnels |
|-------------------|---------------------|
| `scripts/merlin/*.gd` | `lead_godot.md`, `optimizer.md` (systemes core) |
| `scripts/ui/*.gd` | `ui_impl.md`, `ux_research.md` |
| `addons/merlin_ai/*.gd` | `bi_brain_orchestrator.md`, `llm_expert.md`, `godot_expert.md` |
| `scenes/*.tscn` | `ui_impl.md` (scene UI) ou `game_designer.md` (scene jeu) |
| `data/ai/*.gbnf` | `llm_expert.md` |
| `data/ai/*.json` | `llm_expert.md`, `game_designer.md` |
| `docs/*.md` | `technical_writer.md` |
| `*.shader`, `*.gdshader` | `shader_specialist.md` |
| `.claude/agents/*.md` | `technical_writer.md` |
| `scripts/autoload/*.gd` | `lead_godot.md`, `godot_expert.md` (systemes globaux) |
| `data/ai/test/*.json` | `prompt_curator.md` (golden dataset) |
| `scripts/merlin/merlin_save_system.gd` | `security_hardening.md` (encryption, integrity) |
| `.github/workflows/*.yml` | `ci_cd_release.md` (CI/CD pipeline) |
| `tools/lora/*.py` | `lora_training_architect.md`, `lora_data_curator.md` (pipeline LoRA) |
| `data/ai/training/*.json` | `lora_data_curator.md`, `lora_evaluator.md` (datasets) |
| `addons/merlin_llm/adapters/*.gguf` | `lora_evaluator.md` (validation adapter) |
| `tools/autodev/captures/playtest_log.json` | `balance_analyst.md` (analyse stats) |
| `tools/autodev/captures/balance_report.json` | `game_designer.md`, `balance_analyst.md` |
| `tools/autodev/captures/baseline/*.png` | `visual_qa.md` (regression visuelle) |
| `tools/autodev/captures/regression_log.json` | `regression_guardian.md` |
| `tools/autodev/captures/release_quality_report.json` | `release_quality.md` |
| `data/ai/fallback_cards.json` | `content_factory.md`, `narrative_writer.md` |
| `scripts/merlin/merlin_biome_system.gd` | `world_builder.md`, `game_designer.md` |

---

## Skills Transversaux (Invocation Automatique)

En PLUS des agents projet, le dispatcher recommande des skills globaux deployes dans `~/.claude/skills/`.

### Matrice Skill x Complexite

| Complexite | Skills automatiques |
|------------|-------------------|
| TRIVIAL | Aucun |
| SIMPLE | `verification-before-completion` |
| MODEREE | + `planning-with-files` + `writing-plans` |
| COMPLEXE | + `dispatching-parallel-agents` |

### Matrice Skill x Type de Tache

| Type de tache | Skills additionnels | Phase |
|---------------|-------------------|-------|
| Bug Fix | `superpowers-systematic-debugging` | Phase 0 (avant agents) |
| New Feature | `superpowers-test-driven-development` | Phase 1 (en parallele du planning) |
| Code Review | `superpowers-requesting-code-review` | Phase finale (avant git_commit) |
| Architecture | `gsd-planner` + `gsd-codebase-mapper` | Phase 0 (avant agents) |
| Multi-Phase | `gsd-planner` + `gsd-executor` | Orchestre le plan entier |
| Performance | `verification-loop` (ECC) | Phase validation |
| Security | `security-review` (ECC) | Phase validation (apres security_hardening.md) |
| UI/UX | `ui-ux-pro-max` | Phase conception |

### Format de Sortie Augmente

Ajouter dans le plan de dispatch:

```
## Skills Recommandes
- [ ] `skill-name` — Raison, Phase d'invocation
```

---

## Matrice de Review Croise

Quand un agent primaire travaille, ces agents doivent REVIEW:

| Agent primaire | Doit etre review par | Raison |
|----------------|---------------------|--------|
| `lead_godot.md` | debug_qa, optimizer | Architecture + optimisation |
| `ui_impl.md` | ux_research, debug_qa | Qualite UX + tests interaction |
| `motion_designer.md` | ux_research | Animation n'altere pas l'UX |
| `shader_specialist.md` | godot_expert | Impact performance shaders |
| `llm_expert.md` | lead_godot, godot_expert, bi_brain_orchestrator | Integration affecte l'architecture |
| `bi_brain_orchestrator.md` | llm_expert, lead_godot | Pipeline sequentiel + visual/audio tags |
| `narrative_arc_designer.md` | llm_expert, narrative_writer, game_designer | Arcs multi-cartes + coherence |
| `player_profiler.md` | game_designer, llm_expert, data_analyst | Profil psychologique + adaptation |
| `narrative_writer.md` | game_designer, merlin_guardian, **game_director** | Contenu conforme au design + voix + **vision** |
| `game_designer.md` | data_analyst, **game_director** | Decisions de balance besoin data + **coherence vision** |
| `audio_designer.md` | ui_impl | Timing audio synchronise UI |
| `art_direction.md` | ui_impl | Assets integres correctement |
| `lore_writer.md` | merlin_guardian, narrative_writer, **game_director** | Lore conforme au canon + **vision** |
| `localisation.md` | narrative_writer | Traductions preservent le ton |
| `accessibility_specialist.md` | ux_research, ui_impl | WCAG compliance + UI compat |
| `security_hardening.md` | lead_godot, debug_qa | Architecture securite + tests |
| `prompt_curator.md` | llm_expert, narrative_writer | Qualite technique + ton |
| `ci_cd_release.md` | producer, debug_qa | Release planning + tests pre-release |
| `meta_progression_designer.md` | game_designer, data_analyst | Balance mecaniques + metriques |
| `lora_gameplay_translator.md` | llm_expert, prompt_curator | Spec d'entrainement coherente |
| `lora_data_curator.md` | prompt_curator, narrative_writer | Qualite donnees + voix Merlin |
| `lora_training_architect.md` | llm_expert, godot_expert | Config technique + impact memoire |
| `lora_evaluator.md` | llm_expert, debug_qa | Metriques fiables + integration |

**Reviews universels (toujours quand leur domaine est touche):**
- `debug_qa.md` — TOUT changement .gd
- `optimizer.md` — TOUT changement .gd
- `lead_godot.md` — TOUT changement d'architecture
- `ux_research.md` — TOUT changement UI/interaction
- `game_designer.md` — TOUT changement de mecanique
- `game_director.md` — TOUTE decision creative ambigue ou conflit inter-agents
- `merlin_guardian.md` — TOUT contenu impliquant Merlin
- `accessibility_specialist.md` — TOUT changement UI affectant l'accessibilite
- `security_hardening.md` — TOUT changement save/data/LLM input
- `prompt_curator.md` — TOUT changement de prompt ou contenu LLM
- `lora_gameplay_translator.md` — TOUTE demande d'adaptation comportementale du LLM

---

## Format de Sortie

> **Voir `dispatcher_base.md`** pour le template complet de Dispatch Plan.
> Inclut: Resume, Classification, Sequence d'Agents (phases), Auto-Activation,
> Fichiers Impactes, Skills Recommandes, Instructions pour Claude Code.

---

## Exemples de Dispatch

### Exemple 1: Tache UI Simple

**Demande**: "Ajoute un hover effect aux boutons de carte"

```
Types: UI Layout, Animation
Complexite: Simple
Phase 1 (Implementation): ui_impl.md || motion_designer.md (parallele)
Phase 2 (Review): ux_research.md
Phase 3 (Validation): debug_qa.md, optimizer.md [AUTO]
Phase 4 (Finalisation): git_commit.md [AUTO]
Total: 6 agents
```

### Exemple 2: Bug Fix LLM Complexe

**Demande**: "Corrige les erreurs de parsing LLM et optimise le prompt Qwen"

```
Types: LLM Integration, Bug Fix, GDScript Code, Performance
Complexite: Complexe
Phase 1 (Analyse): llm_expert.md || debug_qa.md (parallele)
Phase 2 (Implementation): lead_godot.md || godot_expert.md (parallele)
Phase 3 (Validation): debug_qa.md, optimizer.md [AUTO]
Phase 4 (Documentation): technical_writer.md
Phase 5 (Finalisation): git_commit.md [AUTO]
Total: 7 agents
```

### Exemple 3: Creation de Contenu

**Demande**: "Ecris 10 cartes narratives foret avec la voix de Merlin"

```
Types: Contenu Cartes, Lore Merlin, Game Design
Complexite: Moderee
Phase 1 (Design): game_designer.md || merlin_guardian.md (parallele)
Phase 2 (Creation): narrative_writer.md || lore_writer.md (parallele)
Phase 3 (Validation contenu): game_designer.md + merlin_guardian.md
Phase 4 (Test): debug_qa.md [AUTO]
Phase 5 (Finalisation): git_commit.md [AUTO]
Total: 7 agents (2 invoques 2 fois)
```

### Exemple 4: Refactoring Systeme

**Demande**: "Refactore le store pour supporter les sauvegardes multiples"

```
Types: GDScript Code, Performance, Game Design
Complexite: Complexe
Phase 1 (Design): game_designer.md, producer.md
Phase 2 (Architecture): lead_godot.md
Phase 3 (Implementation): godot_expert.md
Phase 4 (Validation): debug_qa.md, optimizer.md [AUTO]
Phase 5 (Documentation): technical_writer.md
Phase 6 (Finalisation): git_commit.md [AUTO]
Total: 7 agents
```

### Exemple 5: Adaptation LLM (Fine-Tuning LoRA)

**Demande**: "Le modele doit etre plus poetique et utiliser plus de vocabulaire celtique"

```
Types: Adaptation LLM
Complexite: Complexe
Phase 1 (Traduction): lora_gameplay_translator.md → spec d'entrainement
Phase 2 (Donnees): lora_data_curator.md → enrichir dataset poetique + celtique
Phase 3 (Training): lora_training_architect.md → configurer et lancer
Phase 4 (Evaluation): lora_evaluator.md → benchmark GO/NO-GO
Phase 5 (Integration): llm_expert.md → verifier integration Godot
Phase 6 (Finalisation): git_commit.md [AUTO]
Total: 6 agents (pipeline orchestre par gameplay_translator)
```

### Exemple 6: Decision de Direction Creative (NEW)

**Demande**: "Le narrative_writer veut que Merlin soit plus sombre dans le biome Marais"

```
Types: Direction Creative, Lore Merlin
Complexite: Moderee
Phase 1 (Direction): game_director.md → verdict APPROUVE/REJETE/MODIFIE + test emotionnel
Phase 2 (Implementation si approuve): narrative_writer.md, merlin_guardian.md
Phase 3 (Validation): game_designer.md (impact gameplay)
Phase 4 (Finalisation): git_commit.md [AUTO]
Total: 5 agents
```

### Exemple 7: Nouveau Gameplay + Adaptation LLM

**Demande**: "Ajoute un systeme de combat et entraine le modele pour generer des cartes de combat"

```
Types: Game Design, GDScript Code, Adaptation LLM
Complexite: Complexe
Phase 1 (Design): game_designer.md, producer.md
Phase 2 (Implementation): lead_godot.md, godot_expert.md
Phase 3 (Contenu): narrative_writer.md, merlin_guardian.md
Phase 4 (LoRA Pipeline): lora_gameplay_translator.md → orchestre Data/Train/Eval
Phase 5 (Validation): debug_qa.md, optimizer.md [AUTO]
Phase 6 (Finalisation): git_commit.md [AUTO]
Total: 10+ agents (gameplay + fine-tuning en sequence)
```

---

## Quand Invoquer / Ne Pas Invoquer

> **Voir `dispatcher_base.md`** pour les regles generiques (typo=non, multi-fichier=oui).

Regles M.E.R.L.I.N. specifiques:
- **TOUJOURS** pour toute modification `.gd` ou `.tscn`
- **TOUJOURS** pour toute creation de contenu (cartes, lore, prompts)
- **TOUJOURS** pour toute adaptation LLM (LoRA pipeline)
- **JAMAIS** pour fix de typo 1 ligne ou question conversationnelle

---

*Task Dispatcher v2.1 (overlay)*
*Base: `~/.claude/agents/common/dispatcher_base.md`*
*Created: 2026-02-09 | Updated: 2026-02-24 — Added LLM Bi-Brain routing (3 new agents: bi_brain_orchestrator, narrative_arc_designer, player_profiler)*
*Previous: 2026-02-22 — Added Game Director (Direction Creative category, cross-review)*
*Project: M.E.R.L.I.N. — Le Jeu des Oghams*
