# M.E.R.L.I.N. Agent Team — Multi-Agent Architecture

## Overview

This document defines the team of specialized Claude Code agents for the M.E.R.L.I.N. project.
**123 agents + 1 knowledge base** organized by domain.

## Usage with Claude Code

**STEP 0 — TOUJOURS invoquer le Task Dispatcher EN PREMIER:**

```
Task tool:
- subagent_type: "general-purpose"
- model: "haiku"
- prompt: Read .claude/agents/task_dispatcher.md and analyze this task: [DESCRIPTION]
```

Le dispatcher retourne la sequence exacte d'agents a invoquer. Suivre le plan.

**Pour invoquer un agent individuel:**

```
Task tool:
- subagent_type: "general-purpose"
- prompt: Read .claude/agents/[agent].md and follow its instructions. Task: [your task]
```

---

## Agent Roster

### Direction (NEW)

| Role | File | Specialty |
|------|------|-----------|
| **Game Director** | `game_director.md` | **Vision du createur, decisions directionnelles, coherence globale, arbitrage inter-agents, test emotionnel** |

> Le Game Director est l'incarnation de la vision du createur humain. Il repond aux autres
> agents sur la direction creative et gameplay. Decide seul sur les piliers VARIABLES (80%),
> escalade au PDG humain sur les piliers IMMUABLES (20%). Toute decision inclut un "test emotionnel".

### Orchestration

| Role | File | Specialty |
|------|------|-----------|
| **Task Dispatcher** | `task_dispatcher.md` | **Classification de tache, dispatch automatique, sequence d'agents** |

> Le dispatcher est le point d'entree OBLIGATOIRE. Il classifie la tache,
> mappe vers les agents requis, determine l'ordre d'execution, et ajoute
> les agents auto-actives (debug_qa, optimizer, git_commit).

### Core Technical Agents (6)

| Role | File | Specialty |
|------|------|-----------|
| Lead Godot | `lead_godot.md` | Architecture, conventions, code review |
| **Godot Expert** | `godot_expert.md` | **Performance, GDExtension, memory optimization** |
| **LLM Expert** | `llm_expert.md` | **Prompt engineering, RAG, guardrails, Multi-Brain, GBNF** |
| Debug/QA | `debug_qa.md` | Testing, bug reproduction, fixes, **GUT framework, lessons learned** |
| **Optimizer** | `optimizer.md` | **GDScript best practices, code scanning, optimization** |
| **Shader Specialist** | `shader_specialist.md` | **GLSL, post-processing, VFX shaders** |

### UI/UX & Animation Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| UI Implementation | `ui_impl.md` | Control layouts, themes, shaders |
| UX Research | `ux_research.md` | Usability, **WCAG 2.1, playtesting, journey mapping** |
| **Motion Designer** | `motion_designer.md` | **Tweens, particles, easing, micro-interactions** |
| **Mobile/Touch Expert** | `mobile_touch_expert.md` | **Touch gestures, haptic feedback, device quirks, battery** |

### Content & Creative Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| Game Designer | `game_designer.md` | Rules, **data-driven balancing, economy, synergies** |
| Narrative Writer | `narrative_writer.md` | Card text, **QA narrative, prompt writing, faction templates** |
| **Balance Tuner** | `balance_tuner.md` | **Numeric balance, MOS convergence, difficulty curves, scoring tables** |
| Art Direction | `art_direction.md` | **Pixel art pipeline, shaders, procedural landscapes** |
| Audio Designer | `audio_designer.md` | **SFXManager procedural, adaptive music, accessibility** |

### Lore & World-Building Agents (3)

| Role | File | Specialty |
|------|------|-----------|
| **Merlin Guardian** | `merlin_guardian.md` | **Merlin's personality, voice, behavioral consistency** |
| **Lore Writer** | `lore_writer.md` | **Deep mythology, hidden narratives, apocalyptic truth** |
| **Historien Bretagne** | `historien_bretagne.md` | **Celtic/Breton history, mythology research, authenticity** |

### Operations & Documentation Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| Producer | `producer.md` | Priorities, **release management, risk register, retrospectives** |
| Localisation | `localisation.md` | Multi-language, translation |
| **Technical Writer** | `technical_writer.md` | **Docstrings, API docs, player docs, tutorials, onboarding** |
| **Data Analyst** | `data_analyst.md` | **RGPD, visualization, cohort analysis, predictive analytics** |

### Project Management Agents (2)

| Role | File | Specialty |
|------|------|-----------|
| **Git Commit** | `git_commit.md` | **Conventional commits, branch strategy, changelog, tags** |
| **Project Curator** | `project_curator.md` | **Inventory, cleanup, orphan detection, .gitignore** |

### Security & Quality Agents (3) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Accessibility Specialist** | `accessibility_specialist.md` | **WCAG 2.1 AA/AAA, CVD modes, keyboard nav, screen readers** |
| **Security Hardening** | `security_hardening.md` | **Save encryption, LLM sanitization, RGPD, anti-tampering** |
| **Prompt Curator** | `prompt_curator.md` | **Golden dataset, anti-hallucination Celtic, prompt versioning** |

### Progression & Economy Agents (1) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Meta-Progression Designer** | `meta_progression_designer.md` | **Talent Tree, Essences economy, Bestiole, unlock pacing, synergies** |

### CI/CD & Release Agents (1) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **CI/CD Release** | `ci_cd_release.md` | **GitHub Actions, multi-platform export, Steam, mobile stores** |

### LLM Bi-Brain Agents (3) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Bi-Brain Orchestrator** | `bi_brain_orchestrator.md` | **Pipeline sequentiel GM→Narrator, visual/audio tags, prefetch, dialogue Merlin** |
| **Narrative Arc Designer** | `narrative_arc_designer.md` | **Arcs multi-cartes, state machine SETUP→CLIMAX→RESOLUTION, callbacks, reves** |
| **Player Profiler** | `player_profiler.md` | **Profil psychologique, adaptation ton, detection danger, difficulte narrative** |

> Ces 3 agents implementent l'architecture "LLM = peau expressive, Code = cerveau logique".
> Le **Bi-Brain Orchestrator** gere le pipeline technique, l'**Arc Designer** la coherence narrative,
> le **Player Profiler** l'adaptation au joueur. Ref: `docs/VISION_LLM_BI_CERVEAUX.html`

### LoRA Fine-Tuning Agents (4)

| Role | File | Specialty |
|------|------|-----------|
| **LoRA Gameplay Translator** | `lora_gameplay_translator.md` | **Point d'entree: traduit demande gameplay → plan d'entrainement LoRA** |
| **LoRA Data Curator** | `lora_data_curator.md` | **Extraction, curation, augmentation datasets (5 competences, ~1000 exemples)** |
| **LoRA Training Architect** | `lora_training_architect.md` | **QLoRA r=16, Qwen 2.5-1.5B, architecture adapter, pilotage training** |
| **LoRA Evaluator** | `lora_evaluator.md` | **Benchmark Celtic/format/diversity, GO/NO-GO, A/B testing in-game** |

> Pipeline de fine-tuning. Le **Gameplay Translator** est le point d'entree auto-active
> quand l'utilisateur demande une adaptation du LLM. Ref: `docs/LORA_TRAINING_SPEC.html`

### Autonomous Studio Agents (10) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Studio Orchestrator** | `studio_orchestrator.md` | **Meta-orchestration: 5 modes (Quick QA/Deep Test/Content Sprint/Overnight/Polish Pass), coordination multi-agent en boucle fermee** |
| **Playtester AI** | `playtester_ai.md` | **5 archetypes joueur (Prudent/Agressif/Explorateur/Min-maxer/Destructeur), choix motives via state.json** |
| **Balance Analyst** | `balance_analyst.md` | **Statistiques multi-run: distribution fins, difficulte, Souffle economy, aspects balance, fallback rate** |
| **Player Simulator** | `player_simulator.md` | **Stress testing: Speed run, AFK, Spam click, Back-and-forth, Long session (100+ cartes)** |
| **Content Factory** | `content_factory.md` | **Generation autonome: fallback cards, events, prompts, RAG sections, Bestiole skills** |
| **World Builder** | `world_builder.md` | **Nouveaux biomes: palette, ambiance, creatures, shader, cartes specifiques, integration complete** |
| **Visual QA** | `visual_qa.md` | **Regression visuelle: baseline screenshots, comparaison vision Claude, scoring PASS/REGRESSION/BREAKING** |
| **Regression Guardian** | `regression_guardian.md` | **Suivi long terme: snapshot avant/apres, metriques FPS/gen/fallback, historique append-only** |
| **Release Quality** | `release_quality.md` | **Checklist pre-release 60+ items (8 categories), verdict GO/NO-GO** |
| **Perf Profiler** | `perf_profiler.md` | **Profiling runtime: frame time, LLM latency, memory, auto-optimisation quick wins** |

> Ces 10 agents forment le **Studio Autonome** — un systeme en boucle fermee capable de
> jouer, analyser, corriger, generer du contenu et valider le jeu sans intervention humaine.
> Le **Studio Orchestrator** coordonne les autres agents selon 5 modes d'operation.

### Runtime Observation (1) — NEW

| Role | Specialty |
|------|-----------|
| **Game Observer** | **Vision via screenshots runtime, état jeu en direct, analyse design/lisibilité via Read tool + vision Claude** |

> **Game Observer** est un workflow inline (pas de fichier .md séparé) : Claude lit directement
> les fichiers produits par `GameDebugServer` (autoload GDScript actif en debug build) pour
> "voir" le jeu en cours d'exécution. L'agent analyse screenshots, état runtime et logs en temps réel.

#### Fichiers Debug (Godot user dir → accessible directement)

| Fichier | Chemin Windows | Contenu |
|---------|----------------|---------|
| `latest_screenshot.png` | `%APPDATA%\Godot\app_userdata\DRU\debug\latest_screenshot.png` | Dernier frame capturé (écrasé à chaque capture) |
| `latest_state.json` | `%APPDATA%\Godot\app_userdata\DRU\debug\latest_state.json` | État complet MerlinStore (phase, vie, souffle, biome, cartes, karma) |
| `log_buffer.json` | `%APPDATA%\Godot\app_userdata\DRU\debug\log_buffer.json` | Buffer circulaire 100 lignes filtrées |
| `snap_{ts}_{event}.png` | `%APPDATA%\Godot\app_userdata\DRU\debug\snap_*.png` | Historique snapshots horodatés par event |
| `live_log.json` | `tools/autodev/status/live_log.json` | Tail filtré godot.log (watch_live_game.ps1) |

#### Triggers Capture Automatique (GameDebugServer)

| Event | Fichier snap |
|-------|-------------|
| `card_resolved` | `snap_{ts}_card_resolved.png` |
| `life_changed` | `snap_{ts}_life_changed.png` |
| `run_ended` | `snap_{ts}_run_ended.png` |
| `phase_changed` | `snap_{ts}_phase_changed.png` |
| `souffle_changed` | `snap_{ts}_souffle_changed.png` |
| Timer 30s ambiant | `snap_{ts}_ambient.png` |
| F11 manuel | `snap_{ts}_manual.png` |

#### Workflow Game Observer

```
1. CAPTURER (si jeu ouvert, appuyer F11 ou attendre event automatique)
   powershell -Command "Add-Type -AN System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{F11}')"

2. READ latest_screenshot.png → Claude voit l'image via vision native
   Read tool: C:\Users\PGNK2128\AppData\Roaming\Godot\app_userdata\DRU\debug\latest_screenshot.png

3. READ latest_state.json → contexte état jeu au moment de la capture
   Read tool: C:\Users\PGNK2128\AppData\Roaming\Godot\app_userdata\DRU\debug\latest_state.json

4. READ live_log.json → activité récente
   Read tool: c:\Users\PGNK2128\Godot-MCP\tools\autodev\status\live_log.json

5. ANALYSER (via vision Claude):
   - Lisibilité texte (contraste, taille, fond)
   - Visibilité (forêt vs UI, superpositions)
   - Layout (boutons, statut, carte centrale)
   - Couleurs (CRT, phosphore, cohérence palette)
   - Artefacts visuels (overflow, clipping, z-order)

6. RAPPORT → tools/autodev/status/design_analysis.json (optionnel)

7. FIX → Identifier fichier + ligne → modifier → validate.bat
```

#### Auto-Activation

**Invoquer Game Observer quand:**
- "comment ça s'affiche" / "je vois encore" / "l'écran est sombre"
- "le texte est illisible" / "la forêt est trop visible"
- Review design/UX d'une scène en cours d'exécution
- Bug visuel sans reproduction headless possible
- Validation post-implémentation d'un changement graphique

#### Intégration VS Code Live View

Le panneau **"Live View"** de l'extension `autodev-monitor-v4` affiche en temps réel (refresh 3s) :
- Screenshot inline (base64)
- État : Phase / Vie / Souffle / Cartes / Biome / Karma
- Log tail (10 dernières lignes filtrées)
- Bouton `[📷 Capture]` → envoie F11 au process Godot

Lancer le jeu en debug : `powershell -File tools/autodev/launch_debug.ps1`

### QA & Testing Agents (10) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **QA Regression** | `qa_regression.md` | **Regression test specialist, before/after behavior verification** |
| **QA Boundary** | `qa_boundary.md` | **Boundary/edge case tester, numeric limits, overflow detection** |
| **QA Integration** | `qa_integration.md` | **Integration test designer, cross-system signal chain testing** |
| **QA Headless** | `qa_headless.md` | **Headless testing specialist, CLI test automation, validate.bat** |
| **QA Coverage** | `qa_coverage.md` | **Test coverage analyzer, untested code path identification** |
| **QA Data Integrity** | `qa_data_integrity.md` | **JSON card format validation, save file integrity, schema drift** |
| **QA Smoke** | `qa_smoke.md` | **Smoke test designer, quick pass/fail health checks (<60s)** |
| **QA Stress** | `qa_stress.md` | **Stress/load tester, extreme values, rapid inputs, long sessions** |
| **QA Localization** | `qa_localization.md` | **i18n/l10n tester, French text quality, Celtic special characters** |
| **QA Determinism** | `qa_determinism.md` | **Determinism tester, seed-based reproducible runs, replay** |

### Game Design Agents (8) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **GD Economy** | `gd_economy.md` | **Anam flow, Ogham costs, cross-run reward curves** |
| **GD Difficulty** | `gd_difficulty.md` | **MOS convergence tuning, difficulty curves, drain/heal balance** |
| **GD Pacing** | `gd_pacing.md` | **Run length, card rhythm, tension/release, transition timing** |
| **GD Faction Dynamics** | `gd_faction_dynamics.md` | **Alliance/rivalry balance, cross-faction effects, rep thresholds** |
| **GD Narrative Flow** | `gd_narrative_flow.md` | **Per-run story arc, LLM narrative coherence, beat structure** |
| **GD Reward Loop** | `gd_reward_loop.md` | **Dopamine hooks, micro/macro rewards, "one more run" design** |
| **GD Onboarding** | `gd_onboarding.md` | **First-run experience, tutorial flow, progressive mechanic reveal** |
| **GD Endgame** | `gd_endgame.md` | **Replayability, T3 content depth, post-unlock progression** |

### UX & Accessibility Agents (8) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **UX Flow** | `ux_flow.md` | **Screen transitions, navigation clarity, state indication** |
| **UX Feedback** | `ux_feedback.md` | **Visual/audio response design, action acknowledgement** |
| **UX Readability** | `ux_readability.md` | **Font sizes, contrast ratios, WCAG 2.1, CRT readability** |
| **UX Color Blind** | `ux_color_blind.md` | **CVD palette alternatives, redundant encoding, faction colors** |
| **UX Input** | `ux_input.md` | **Keyboard/controller/touch mapping, focus navigation** |
| **UX Cognitive Load** | `ux_cognitive_load.md` | **Information density, progressive disclosure, decision time** |
| **UX Animation** | `ux_animation.md` | **Easing curves, transition timing, fondu coordination** |
| **UX Error States** | `ux_error_states.md` | **Graceful degradation, error messages, empty states, fallbacks** |

### Audio & Atmosphere Agents (6) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Audio Mix** | `audio_mix.md` | **Volume balance, bus architecture, priority rules, ducking** |
| **Audio Ambiance** | `audio_ambiance.md` | **Biome soundscapes, layered ambient, state-reactive atmosphere** |
| **Audio Feedback** | `audio_feedback.md` | **UI sounds, effect audio cues, Celtic audio palette** |
| **Audio Music Flow** | `audio_music_flow.md` | **Crossfade timing, biome themes, tension-reactive layers** |
| **Audio Procedural** | `audio_procedural.md` | **Celtic scale synthesis, SFXManager extension, tone generation** |
| **Audio Spatial** | `audio_spatial.md` | **3D audio positioning, distance attenuation, biome reverb** |

### Visual & Art Agents (8) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Vis Palette** | `vis_palette.md` | **CRT palette enforcement, biome colors, PALETTE/GBC constants** |
| **Vis Particle** | `vis_particle.md` | **Atmospheric particles, Ogham magic effects, performance budget** |
| **Vis Typography** | `vis_typography.md` | **Font hierarchy, Celtic styling, French glyph support** |
| **Vis Layout** | `vis_layout.md` | **Grid systems, responsive UI, container hierarchy, spacing** |
| **Vis Shader** | `vis_shader.md` | **CRT post-processing, biome shaders, shader optimization** |
| **Vis Animation Art** | `vis_animation_art.md` | **Sprite sheets, procedural art, Celtic knotwork animation** |
| **Vis Scene Composition** | `vis_scene_composition.md` | **Depth, focal points, visual hierarchy, z-order management** |
| **Vis Celtic Authenticity** | `vis_celtic_authenticity.md` | **Ogham accuracy, knotwork patterns, Celtic symbol validation** |

### Performance & Technical Agents (6) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Perf Memory** | `perf_memory.md` | **Memory leaks, orphan nodes, resource pooling, signal cleanup** |
| **Perf Render** | `perf_render.md` | **Draw calls, shader complexity, overdraw, 60fps target** |
| **Perf Loading** | `perf_loading.md` | **Async loading, scene preloading, transition masking** |
| **Perf Mobile** | `perf_mobile.md` | **Touch UI, reduced effects, 30fps mobile target, 256MB budget** |
| **Perf Network** | `perf_network.md` | **Offline-first, Ollama caching, request prefetch, retry logic** |
| **Perf Battery** | `perf_battery.md` | **Power-efficient modes, idle detection, timer coalescing** |

### Content & Narrative Agents (6) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Content Card Writer** | `content_card_writer.md` | **French card text, Celtic authenticity, 45-verb choices, biome variants** |
| **Content Dialogue** | `content_dialogue.md` | **NPC voice, trust tier dialogue, faction speech patterns** |
| **Content Flavor Text** | `content_flavor_text.md` | **Biome descriptions, Ogham lore, tooltips, loading quotes** |
| **Content Quest Arc** | `content_quest_arc.md` | **Multi-card storylines, callbacks, branching quest chains** |
| **Content Worldbuilding** | `content_worldbuilding.md` | **Timeline, geography, cosmology coherence, contradiction detection** |
| **Content Merlin Voice** | `content_merlin_voice.md` | **Merlin personality, ambiguity, trust tier modulation T0-T3** |

### Meta & Process Agents (4) — NEW

| Role | File | Specialty |
|------|------|-----------|
| **Meta Bible Guardian** | `meta_bible_guardian.md` | **Bible v2.4 enforcement, design drift detection, removed system audit** |
| **Meta Code-Bible Sync** | `meta_code_bible_sync.md` | **Constants alignment, enum sync, pipeline order verification** |
| **Meta Sprint Reviewer** | `meta_sprint_reviewer.md` | **Post-sprint quality assessment, validation, debt tracking** |
| **Meta Tech Debt** | `meta_tech_debt.md` | **TODO/FIXME tracking, duplication, complexity hotspots, dead code** |

### Blender Art Pipeline (12 agents) — NEW

Wave-based dispatch for 3D asset generation and scene composition.

#### Wave 1 — Foundation (parallel)
| Agent | File | Tier | Model | Triggers |
|-------|------|------|-------|----------|
| Terrain Sculptor | `blender_terrain_sculptor.md` | 1 | sonnet | terrain, cliff, displacement, biome terrain |
| Ocean Animator | `blender_ocean_animator.md` | 2 | haiku | ocean, waves, water, foam |
| Material Master | `blender_material_master.md` | 1 | sonnet | material, pbr, vertex color, texture |
| Export Engineer | `blender_export_engineer.md` | 1 | haiku | export glb, lod, batch export |

#### Wave 2 — Asset Producers (parallel)
| Agent | File | Tier | Model | Triggers |
|-------|------|------|-------|----------|
| Tower Architect | `blender_tower_architect.md` | 2 | sonnet | tower, celtic, dolmen, menhir, ruin |
| Vegetation Artist | `blender_vegetation_artist.md` | 2 | haiku | vegetation, tree, bush, grass, flora |
| VFX Artist | `blender_vfx_artist.md` | 2 | sonnet | vfx, particle, magic, crystal glow |

#### Wave 3 — Scene Assembly (parallel)
| Agent | File | Tier | Model | Triggers |
|-------|------|------|-------|----------|
| Lighting Director | `blender_lighting_director.md` | 1 | sonnet | lighting, eevee, volumetric, day night |
| Camera Director | `blender_camera_director.md` | 2 | haiku | camera, composition, cinematic, lens |
| Scene Compositor | `blender_scene_compositor.md` | 2 | sonnet | compose scene, placement, z-fighting |
| Animator | `blender_animator.md` | 2 | sonnet | animate, keyframe, nla, wave cycle |

#### Wave 4 — QA (sequential)
| Agent | File | Tier | Model | Triggers |
|-------|------|------|-------|----------|
| QA Renderer | `blender_qa_renderer.md` | 1 | haiku | qa render, compare reference, quality score |

#### CLI Commands (20 total)
```
python tools/cli.py blender version|create-terrain|create-tower|create-object|create-ocean|batch-generate|scene-compose|list-assets|open|build-scene|render|cleanup|animate|light|material|lod|qa
```

### Director Review Agents (6) — NEW

Specialist agents for director-facing review, auditing, and dashboard curation.

| Role | File | Specialty |
|------|------|-----------|
| **Visual QA Agent** | `visual_qa_agent.md` | **Screenshot analysis as a player, visual bug detection, UI regression** |
| **UX Reviewer Agent** | `ux_reviewer_agent.md` | **Player-perspective UX evaluation, Nielsen heuristics, beginner experience** |
| **i18n Auditor Agent** | `i18n_auditor_agent.md` | **Hardcoded string detection, text_registry.json maintenance, coverage tracking** |
| **Platform Tester Agent** | `platform_tester_agent.md` | **Multi-platform compatibility: input, UI scaling, shaders, export presets** |
| **Accessibility Agent** | `accessibility_agent.md` | **WCAG contrast, font sizes, color blindness, keyboard/gamepad navigation** |
| **Dashboard Curator Agent** | `dashboard_curator_agent.md` | **Mission Control enrichment, director-first metrics, auto-evolving dashboard** |

> These agents support the **Command Center** workflow. They propose insights via `studio_insights.json`,
> which the director reviews on the Mission Control dashboard (approve/dismiss).

### Shared Resources

| Resource | File | Purpose |
|----------|------|---------|
| **Knowledge Base** | `gdscript_knowledge_base.md` | **Corrections, best practices, lessons learned** |

---

## Summary Count

```
Total: 123 agents + 1 knowledge base

By category:
  Direction:                  1 (game_director)
  Orchestration:              1 (task_dispatcher)
  Core Technical:             6 (lead_godot, godot_expert, llm_expert, debug_qa, optimizer, shader_specialist)
  UI/UX & Animation:          4 (ui_impl, ux_research, motion_designer, mobile_touch_expert)
  Content & Creative:         5 (game_designer, narrative_writer, art_direction, audio_designer, balance_tuner)
  Lore & World-Building:      3 (merlin_guardian, lore_writer, historien_bretagne)
  Operations & Documentation: 4 (producer, localisation, technical_writer, data_analyst)
  Project Management:         2 (git_commit, project_curator)
  Security & Quality:         3 (accessibility_specialist, security_hardening, prompt_curator)
  Progression & Economy:      1 (meta_progression_designer)
  CI/CD & Release:            1 (ci_cd_release)
  LLM Bi-Brain:               3 (bi_brain_orchestrator, narrative_arc_designer, player_profiler)
  LoRA Fine-Tuning:           4 (lora_gameplay_translator, lora_data_curator, lora_training_architect, lora_evaluator)
  Autonomous Studio:         10 (studio_orchestrator, playtester_ai, balance_analyst, player_simulator, content_factory, world_builder, visual_qa, regression_guardian, release_quality, perf_profiler)
  Runtime Observation:        1 (game_observer — inline workflow)
  QA & Testing:              10 (qa_regression, qa_boundary, qa_integration, qa_headless, qa_coverage, qa_data_integrity, qa_smoke, qa_stress, qa_localization, qa_determinism)
  Game Design:                8 (gd_economy, gd_difficulty, gd_pacing, gd_faction_dynamics, gd_narrative_flow, gd_reward_loop, gd_onboarding, gd_endgame)
  UX & Accessibility:         8 (ux_flow, ux_feedback, ux_readability, ux_color_blind, ux_input, ux_cognitive_load, ux_animation, ux_error_states)
  Audio & Atmosphere:          6 (audio_mix, audio_ambiance, audio_feedback, audio_music_flow, audio_procedural, audio_spatial)
  Visual & Art:                8 (vis_palette, vis_particle, vis_typography, vis_layout, vis_shader, vis_animation_art, vis_scene_composition, vis_celtic_authenticity)
  Performance & Technical:     6 (perf_memory, perf_render, perf_loading, perf_mobile, perf_network, perf_battery)
  Content & Narrative:         6 (content_card_writer, content_dialogue, content_flavor_text, content_quest_arc, content_worldbuilding, content_merlin_voice)
  Meta & Process:              4 (meta_bible_guardian, meta_code_bible_sync, meta_sprint_reviewer, meta_tech_debt)
  Blender Art Pipeline:       12 (terrain_sculptor, ocean_animator, material_master, export_engineer, tower_architect, vegetation_artist, vfx_artist, lighting_director, camera_director, scene_compositor, animator, qa_renderer)
  Director Review:             6 (visual_qa_agent, ux_reviewer_agent, i18n_auditor_agent, platform_tester_agent, accessibility_agent, dashboard_curator_agent)
  Knowledge Base:              1 (gdscript_knowledge_base)
```

---

## Workflow — DISPATCH FIRST

### Flux Standard (avec Dispatcher)

```
1. DISPATCHER analyse la tache → retourne plan d'agents
2. Suivre le plan: agents de planning EN PREMIER
3. Agents d'implementation AU MILIEU
4. Agents de validation (debug_qa, optimizer) APRES
5. git_commit EN DERNIER
```

### Invocation du Dispatcher

```
Task tool:
  subagent_type: "general-purpose"
  model: "haiku"
  prompt: "Read .claude/agents/task_dispatcher.md and analyze this task: [DESCRIPTION]"
```

Le dispatcher retourne un plan structure avec:
- Types de tache identifies (multi-label)
- Agents requis avec ordre d'execution
- Hints de parallelisation
- Agents auto-actives appliques
- Fichiers impactes estimes

---

## Cross-Functional Reviews

| Change Type | Required Review |
|-------------|-----------------|
| GDScript code | Lead Godot, Debug/QA, **Optimizer** |
| Performance issues | **Godot Expert**, **Optimizer** |
| LLM integration | **LLM Expert**, Godot Expert |
| UI/UX changes | UI Impl, UX Research |
| Card content | Narrative, Game Designer, **Merlin Guardian** |
| Visual assets | Art Direction |
| Audio changes | Audio Designer |
| Doc changes | Producer, **Technical Writer** |
| **Shader/VFX code** | **Shader Specialist**, Godot Expert |
| **Animations/Tweens** | **Motion Designer**, UI Impl |
| **Touch/Mobile input** | **Mobile/Touch Expert**, UX Research |
| **Game balance data** | **Data Analyst**, Game Designer |
| **Lore/Mythology** | **Merlin Guardian**, **Lore Writer** |
| **Creative direction** | **Game Director** |
| **Correction learned** | **Debug/QA**, **Optimizer** |
| **Best practice found** | **Optimizer**, Debug/QA |
| **Phase completed** | **Git Commit** |
| **Project cleanup** | **Project Curator** |
| **Accessibility** | **Accessibility Specialist**, UX Research |
| **Security/Privacy** | **Security Hardening**, Data Analyst |
| **LLM content quality** | **Prompt Curator**, LLM Expert |
| **Meta-progression** | **Meta-Progression Designer**, Game Designer |
| **Build/Release** | **CI/CD Release**, Producer |
| **LLM adaptation/fine-tuning** | **LoRA Gameplay Translator**, LLM Expert |
| **Training data changes** | **LoRA Data Curator**, Prompt Curator |
| **LoRA training/hyperparams** | **LoRA Training Architect**, LLM Expert |
| **Model benchmark/evaluation** | **LoRA Evaluator**, LLM Expert |
| **Bug visuel, lisibilité, layout runtime** | **Game Observer** (inline), UI Impl, UX Research |

---

## Agent Communication Protocol

### Handoff Format

When an agent completes work and needs handoff:

```markdown
## Agent Handoff: [Agent Role]

### Completed
- [List of completed items]

### Files Modified
- `path/to/file.gd` — Description

### For Next Agent: [Target Role]
- [Specific tasks or questions]

### Blockers
- [Any blockers or dependencies]
```

### Status Tags

- `[READY]` — Task complete, ready for review
- `[BLOCKED]` — Waiting on dependency
- `[WIP]` — Work in progress
- `[REVIEW]` — Needs review from specific agent

---

## Auto-Activation Matrix

| Agent | Declencheur | Action |
|-------|------------|--------|
| **task_dispatcher.md** | Toute tache non-triviale | Classifie et dispatch — INVOQUE EN PREMIER |
| `debug_qa.md` | Correction GDScript apprise | Documente dans gdscript_knowledge_base.md |
| `optimizer.md` | Bonne pratique decouverte ou nouveau code GDScript | Scanner et appliquer |
| `git_commit.md` | Phase complete, 3+ fichiers modifies | Commit conventionnel auto |
| `project_curator.md` | "inventaire", "nettoie", "range" | Rapport + nettoyage |
| **`game_director.md`** | **"vision du jeu", "direction creative", "le joueur doit ressentir", "coherence narrative", conflit inter-agents, ambiguite de direction** | **Evalue contre la vision du createur, decide ou escalade au PDG** |
| **`lora_gameplay_translator.md`** | **"entraine le modele", "le LLM doit", "adapte le modele", "fine-tune", adaptation gameplay LLM** | **Traduit demande → plan d'entrainement, orchestre pipeline LoRA** |
| `lora_data_curator.md` | Modification JSON contenu narratif, ajout nouveau gameplay | Re-export + augmentation dataset |
| `lora_evaluator.md` | Apres training LoRA complet | Benchmark automatique, decision GO/NO-GO |
| **Game Observer (inline)** | **"comment ça s'affiche", "je vois encore", "l'écran est sombre", "le texte est illisible", bug visuel, review design en cours d'exécution** | **Read latest_screenshot.png → vision Claude → analyse lisibilité/layout/couleurs → rapport** |
| **`studio_orchestrator.md`** | **"lance le studio", "overnight enhanced", "deep test", "quick qa", "content sprint", "polish pass", "mode studio"** | **Coordonne tous les agents en boucle fermee autonome** |
| **`playtester_ai.md`** | **"joue au jeu", "playtest", "teste le gameplay", "simule un joueur"** | **Joue avec 5 archetypes, choix motives, log dans playtest_log.json** |
| **`balance_analyst.md`** | **"equilibrage", "balance du jeu", "statistiques", "distribution des fins"** | **Analyse multi-run, detecte desequilibres, recommande ajustements** |
| **`visual_qa.md`** | **"regression visuelle", "compare screenshots", "baseline visuel"** | **Compare captures avec baseline, score PASS/REGRESSION/BREAKING** |
| **`content_factory.md`** | **"genere du contenu", "nouvelles cartes", "enrichis le jeu"** | **Genere cartes, events, prompts, RAG sections autonomement** |
| **`regression_guardian.md`** | **"regression", "avant/apres", "la perf a baisse"** | **Snapshot metriques avant/apres, alerte si delta hors seuils** |
| **`release_quality.md`** | **"pre-release", "GO/NO-GO", "pret a livrer", "checklist qualite"** | **Checklist 60+ items, verdict GO/NO-GO** |
| **`player_simulator.md`** | **"stress test", "spam click", "AFK test", "crash test"** | **Simule comportements extremes, detecte crashes et leaks** |
| **`world_builder.md`** | **"nouveau biome", "nouveau lieu", "construction de monde"** | **Cree biomes complets (palette, cartes, shader, lore)** |
| **`perf_profiler.md`** | **"profile performance", "FPS drop", "memory leak", "le jeu rame"** | **Profile runtime, correle avec code, auto-optimise** |
| **`qa_regression.md`** | **Core system file modified, refactor 3+ files, bug fix applied** | **Before/after behavior comparison, regression detection** |
| **`qa_boundary.md`** | **Clamp/cap logic modified, new effects added, division/percentage code** | **Boundary value testing, overflow detection** |
| **`qa_smoke.md`** | **Pre-commit, pre-release, new scene/autoload added** | **Fast <60s health check across all systems** |
| **`meta_bible_guardian.md`** | **Game mechanic code modified, new features without bible section** | **Design drift detection, bible alignment verification** |
| **`meta_code_bible_sync.md`** | **merlin_constants.gd or GAME_DESIGN_BIBLE.md edited** | **Constants alignment, enum sync check** |
| **`meta_tech_debt.md`** | **Code shortcuts introduced, sprint review, "clean up"** | **TODO tracking, duplication detection, complexity audit** |
| **`content_card_writer.md`** | **Fallback pool expansion, new biome cards needed** | **French card text, Celtic authenticity, 45-verb choices** |
| **`content_merlin_voice.md`** | **Merlin dialogue written, trust tier text needed** | **Merlin personality consistency, T0-T3 modulation** |
| **`ux_error_states.md`** | **LLM fallback designed, error handling added, empty states** | **Graceful degradation, friendly error messages** |
| **`audio_mix.md`** | **New sounds added, volume complaints, simultaneous sounds** | **Volume balance, priority rules, ducking** |
| **`vis_palette.md`** | **New colors used, hardcoded Color() found, biome theme change** | **PALETTE/GBC enforcement, CRT aesthetic consistency** |
| **`perf_memory.md`** | **Memory grows during play, node count increases, scene transitions** | **Orphan nodes, signal leaks, resource pooling** |

---

## Cross-Functional Reviews (Studio Agents)

| Change Type | Required Review |
|-------------|-----------------|
| **Playtest results** | **Balance Analyst**, Game Designer |
| **Balance changes** | **Playtester AI** (re-test), **Regression Guardian** |
| **New content** | **Content Factory** validation, **Visual QA**, Merlin Guardian |
| **New biome** | **World Builder**, Content Factory, Shader Specialist |
| **Visual change** | **Visual QA**, Art Direction |
| **Performance fix** | **Perf Profiler** (re-profile), **Regression Guardian** |
| **Pre-release** | **Release Quality** (full checklist) |
| **Studio mode session** | **Studio Orchestrator** (coordonne tous) |

### Cross-Functional Reviews (New Agents)

| Change Type | Required Review |
|-------------|-----------------|
| **Core system refactor** | **QA Regression**, QA Integration, Lead Godot |
| **Numeric constants changed** | **QA Boundary**, Meta Code-Bible Sync, Balance Tuner |
| **New biome content** | Content Card Writer, Audio Ambiance, Vis Palette, Vis Celtic Authenticity |
| **Card text added** | Content Card Writer, QA Localization, UX Readability |
| **Merlin dialogue** | Content Merlin Voice, Merlin Guardian |
| **UI screen added** | UX Flow, UX Cognitive Load, Vis Layout, UX Input |
| **CRT shader changed** | Vis Shader, UX Readability, Perf Render |
| **Font/typography change** | Vis Typography, UX Readability, QA Localization |
| **Color palette change** | Vis Palette, UX Color Blind |
| **Audio added** | Audio Mix, Audio Feedback |
| **Scene transition** | UX Animation, Perf Loading, UX Flow |
| **Error handling code** | UX Error States, QA Integration |
| **Save system change** | QA Data Integrity, QA Boundary |
| **Mobile deployment** | Perf Mobile, Perf Battery, UX Input |
| **Sprint/session end** | Meta Sprint Reviewer, Meta Tech Debt, QA Smoke |
| **Bible or constants edited** | Meta Bible Guardian, Meta Code-Bible Sync |
| **Multi-card narrative** | Content Quest Arc, GD Narrative Flow |
| **Economy/progression** | GD Economy, GD Reward Loop |
| **Difficulty tuning** | GD Difficulty, GD Pacing, Balance Tuner |
| **Onboarding/tutorial** | GD Onboarding, UX Cognitive Load |
| **Memory concerns** | Perf Memory, QA Stress |
| **Particle effects** | Vis Particle, Perf Render |

---

## Quick Reference Commands

```bash
# NEW — Invoke Game Director for creative direction
claude "Use Task to read .claude/agents/game_director.md and evaluate: est-ce coherent avec la vision du jeu de [feature proposee]?"

# STEP 0 — DISPATCH (TOUJOURS EN PREMIER)
claude "Use Task with general-purpose agent (haiku) to read .claude/agents/task_dispatcher.md and analyze: [TASK]"

# Invoke Lead Godot for architecture review
claude "Use Task to read .claude/agents/lead_godot.md and review the merlin_store.gd architecture"

# Invoke QA for testing
claude "Use Task to read .claude/agents/debug_qa.md and test the TriadeGame scene"

# Invoke Narrative Writer for card content
claude "Use Task to read .claude/agents/narrative_writer.md and write 10 new fallback cards"

# Invoke Motion Designer for animation polish
claude "Use Task to read .claude/agents/motion_designer.md and add entry animations to the menu"

# Invoke Shader Specialist for visual effects
claude "Use Task to read .claude/agents/shader_specialist.md and create a CRT scanline effect"

# Invoke Mobile Expert for touch optimization
claude "Use Task to read .claude/agents/mobile_touch_expert.md and improve card swipe gesture"

# Invoke Data Analyst for balance review
claude "Use Task to read .claude/agents/data_analyst.md and analyze aspect ending distribution"

# Invoke Technical Writer for documentation
claude "Use Task to read .claude/agents/technical_writer.md and document the MerlinStore API"

# Invoke Optimizer for best practices scan
claude "Use Task to read .claude/agents/optimizer.md and scan scripts/merlin/ for optimization"

# Invoke Debug with knowledge base update
claude "Use Task to read .claude/agents/debug_qa.md and document the correction in gdscript_knowledge_base.md"

# NEW — Invoke Accessibility Specialist
claude "Use Task to read .claude/agents/accessibility_specialist.md and audit the TriadeGame UI"

# NEW — Invoke Security Hardening
claude "Use Task to read .claude/agents/security_hardening.md and review save system encryption"

# NEW — Invoke Prompt Curator
claude "Use Task to read .claude/agents/prompt_curator.md and evaluate golden dataset coverage"

# NEW — Invoke Meta-Progression Designer
claude "Use Task to read .claude/agents/meta_progression_designer.md and balance Talent Tree costs"

# NEW — Invoke CI/CD Release
claude "Use Task to read .claude/agents/ci_cd_release.md and setup GitHub Actions pipeline"

# NEW — LoRA Fine-Tuning Pipeline
# Point d'entree: Gameplay Translator (auto-active par "le LLM doit", "entraine le modele")
claude "Use Task to read .claude/agents/lora_gameplay_translator.md and translate this need: le modele doit etre plus poetique dans les biomes forestiers"

# LoRA Data Curator (auto-active par modification contenu JSON)
claude "Use Task to read .claude/agents/lora_data_curator.md and re-export training data after content update"

# LoRA Training Architect
claude "Use Task to read .claude/agents/lora_training_architect.md and configure training for multi-LoRA per tone"

# LoRA Evaluator (auto-active apres training)
claude "Use Task to read .claude/agents/lora_evaluator.md and benchmark the new narrator adapter"

# STUDIO — Studio Orchestrator (5 modes autonomes)
claude "Use Task to read .claude/agents/studio_orchestrator.md and run Quick QA mode"
claude "Use Task to read .claude/agents/studio_orchestrator.md and run Deep Test (1h, all archetypes)"
claude "Use Task to read .claude/agents/studio_orchestrator.md and run Overnight mode (7h)"

# STUDIO — Playtester AI (5 archetypes)
claude "Use Task to read .claude/agents/playtester_ai.md and play 3 runs as CAUTIOUS archetype"

# STUDIO — Balance Analyst
claude "Use Task to read .claude/agents/balance_analyst.md and analyze playtest data for imbalances"

# STUDIO — Visual QA
claude "Use Task to read .claude/agents/visual_qa.md and compare current screenshots with baseline"

# STUDIO — Content Factory
claude "Use Task to read .claude/agents/content_factory.md and generate 5 fallback cards for missing biomes"

# STUDIO — World Builder
claude "Use Task to read .claude/agents/world_builder.md and create a new biome"

# STUDIO — Player Simulator (stress testing)
claude "Use Task to read .claude/agents/player_simulator.md and run all 5 stress scenarios"

# STUDIO — Regression Guardian
claude "Use Task to read .claude/agents/regression_guardian.md and snapshot metrics before changes"

# STUDIO — Release Quality
claude "Use Task to read .claude/agents/release_quality.md and run full pre-release checklist"

# STUDIO — Perf Profiler
claude "Use Task to read .claude/agents/perf_profiler.md and profile runtime performance"
```

---

```bash
# NEW — Game Observer (inline workflow — vision runtime)
# 1. Capturer F11 (si jeu ouvert)
#    powershell -Command "Add-Type -AN System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('{F11}')"
# 2. Read C:\Users\PGNK2128\AppData\Roaming\Godot\app_userdata\DRU\debug\latest_screenshot.png
# 3. Read C:\Users\PGNK2128\AppData\Roaming\Godot\app_userdata\DRU\debug\latest_state.json
# 4. Read tools/autodev/status/live_log.json
# → Claude analyse visuellement l'interface, lisibilité, layout, couleurs
```

---

*Created: 2026-02-06*
*Updated: 2026-03-15 — 105 agents + 1 KB (new: 56 specialized agents — 10 QA/Testing, 8 Game Design, 8 UX/Accessibility, 6 Audio/Atmosphere, 8 Visual/Art, 6 Performance/Technical, 6 Content/Narrative, 4 Meta/Process)*
*Project: M.E.R.L.I.N. — Le Jeu des Oghams*
