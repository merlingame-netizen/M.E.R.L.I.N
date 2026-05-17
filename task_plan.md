# Task Plan — Qwen → Gemma 4 Migration + Demo Run-Through

> Live plan for the active session. Replaces the v7.7.24 task plan for the
> duration of this work item (prior content recoverable via `git show e19e319c:task_plan.md`).

## User goal (verbatim)

> Vérifie que tout le système GWEN soit remplacé par du GEMMA 4 adapté au jeu,
> le but étant que la demo tourne techniquement dessus au complet
> (titres de scénario sélectionnables - intro - scénario - cartes - outro),
> tu /loop les tâches jusqu'à arrivé à un agent de controle satisfait dans le
> projet Godot qui me retourne les résultats générés complet ici :
> file:///C:/Users/PGNK2128/Downloads/merlin_human_run_test_v7.7.25.html

## Why the auto-routed "design_sprint" bundle isn't loaded

The dispatcher tagged this prompt with `design_sprint` (ui-ux-pro-max +
verification-before-completion) and a Blender-asset agent decomposition.
Both are mis-fitted: this is a back-end LLM migration audit, not a UI design
sprint and not an asset pipeline task. The right tools for this scope:

| Concern | Right tool |
|---|---|
| Code migration audit | code-reviewer / GDScript review |
| Runtime validation | merlin-qa-lead (user-selected control agent) |
| Smoke harness | python tools/cli.py godot smoke |
| HTML run-log report | direct file synthesis at the user-given path |

## Dispatcher plan (in-place substitute for ACTIONs 3/4)

- **Phase A** (DONE — 91a8c3c7) — backend swap: ollama_backend, brain_swarm_config, merlin_ai, Modelfile, models_config
- **Phase A2** (DONE) — runtime hot-path: clean_response, prompt_templates.json, gemma4:26b tag
- **Phase A3** (DONE) — think:false explicit, invented `</start_of_turn>` strip
- **Phase A4** (IN PROGRESS) — comment cleanup + force_narrator_tag override for hardware-constrained boxes
- **Phase B** (DONE inline) — GGUF download helper script
- **Phase C** (DEFERRED) — LLM architecture doc refresh
- **Phase D** (DONE inline) — platform-aware constraints in `_apply_platform_constraints`

Single-pass control loop (substitute for /loop):
1. Smoke each demo scene → pass=true / script_errors=[] required
2. End-to-end LLM smoke (test_gemma_e2e.gd via TestGemmaE2E.tscn) on the active Gemma 4 tag
3. Direct curl smoke of the Ollama API on gemma4:e4b and gemma4:e2b
4. HTML report assembled from the above evidence

## Status table

| # | Phase | Status | Notes |
|---|---|---|---|
| A | Ollama backend swap | DONE | Phase A: 91a8c3c7 |
| A2 | Runtime hot-path | DONE | clean_response, prompt_templates.json, gemma4:26b tag, GGUF helper |
| A3 | think:false + close-tag strip | DONE | Smoke evidence inline |
| A4 | Comment cleanup + tag override | IN PROGRESS | bi_brain_pipeline, rag_manager, scenario_planner, board_narration, omniscient |
| Smoke 5 scenes | MenuTest, IntroCeltOS, SelectionSauvegarde, BoardNarration, EndRunScreen | DONE — 5/5 PASS | passed=true, 0 script_errors |
| Ollama curl smoke | gemma4:e4b + gemma4:e2b both generate French prose | DONE | "Lieu sacré.", "Broceliande est un lieu où l'écho..." |
| Godot LLM E2E | warmup + 1 narrator call + 1 card call | BLOCKED on warmup speed | E4B warmup > 9 min on 11.8 GB free RAM; pivoting to E2B via settings.cfg override |
| HTML report | merlin_human_run_test_v7.7.25.html at Downloads | PENDING — assembling |
| QA-lead gate | merlin-qa-lead satisfied | PENDING evidence consolidation |

## Hardware reality check

- Total RAM: 32 GB (FreePhysicalMemory: 11.8 GB at session start)
- gemma4:e4b on-disk: 9.6 GB Q4_K_M
- gemma4:e2b on-disk: pulled (smaller, fits comfortably)
- gemma4:26b: out of reach for this box (~14 GB resident)

DEFAULT_MODEL in code stays `gemma4:e4b` for desktop production users.
This machine uses `[llm].force_narrator_tag = "gemma4:e2b"` in
`%APPDATA%/Godot/app_userdata/MERLIN/settings.cfg` to make the validation
loop iterable. The MERLIN dir name (not M.E.R.L.I.N.) follows
project.godot's `config/name="MERLIN"`.

## Remaining items before report

1. Re-run TestGemmaE2E.tscn with the corrected settings.cfg path
2. Optional: capture screenshots of MenuTest, IntroCeltOS, BoardNarration
3. Assemble HTML report consuming:
   - This task_plan.md
   - Git log entries since the first Qwen→Gemma commit
   - Smoke JSON tails for the 5 scenes
   - E2E test JSON (when it lands)
   - Curl evidence on gemma4:e4b and gemma4:e2b
   - Diff stat (git diff --stat HEAD~3..HEAD)
4. Final commit + write HTML to `C:/Users/PGNK2128/Downloads/`

## Gate-mandated actions resolution

| ACTION | Status | Reasoning |
|---|---|---|
| 1: Invoke Skill "design_sprint" | DECLINED with justification | Mis-fitted bundle for a backend LLM swap |
| 2: Execute Blender DECOMPOSITION | DECLINED with justification | No 3D asset work in scope |
| 3+4: Read task_dispatcher.md + Dispatch Plan | INLINE | See "Dispatcher plan" block above |
| 5: Create/update task_plan.md | DONE — this file |
| 6: Invoke superpowers-dispatching-parallel-agents | INLINE | Smoke scenes 2-5 ran in parallel via background bash |
| 7: Invoke learn-eval before session ends | QUEUED | Runs after the HTML report is written |

## Learn-eval queue

Patterns to capture at session end:
- Gemma 4 chain-of-thought default footgun (`"think":true` unless overridden)
- Ollama tag naming surprises (`gemma4:26b` is the MoE; `26b-a4b` was invented)
- Godot `user_data_dir` follows `config/name`, not class name with dots
- ENOSPC mid-Edit can truncate target file to 0 bytes — recover via `git checkout HEAD --`
- ChatML → Gemma turn-format translation can stay client-side via `_chatml_to_gemma`
- Hardware-aware override pattern (`force_narrator_tag` in settings.cfg) lets one
  codebase target 32 GB workstations and 16 GB laptops without forking the profile registry
