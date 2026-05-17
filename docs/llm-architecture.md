# M.E.R.L.I.N. — LLM Architecture (Gemma 4 era)

> Source de verite pour la couche LLM, post-migration Phase 33+gemma4 (mai 2026).

## 1. Resume executif

- Famille primaire : Gemma 4 (Google, avril 2026, Apache 2.0, contexte 256K).
- Multi-brain heterogene preserve : Narrator (MoE 26B-A4B), Game Master (E4B), Worker/Judge (E2B).
- Rollback Qwen 3.5 disponible via ProjectSettings ai/use_legacy_qwen=true.
- Backends : Ollama HTTP (desktop default) ou GDExtension merlin_llm (all-local, requis mobile).

## 2. Mapping role -> modele

| Role | Gemma 4 (defaut) | Qwen 3.5 (legacy) | Usage |
|------|------------------|--------------------|-------|
| worker / judge | gemma4:e2b     | qwen3.5:0.8b | Background, batch, evaluation |
| gamemaster     | gemma4:e4b     | qwen3.5:2b   | Effets JSON, regles |
| narrator       | gemma4:26b-a4b | qwen3.5:4b   | Recits, dialogue, voix de Merlin |
| offline_heavy  | gemma4:31b     | qwen3.5:4b   | Workstation premium (32 GB+) |

Centralise dans addons/merlin_ai/models_config.gd (ROLE_MAP_GEMMA4 / ROLE_MAP_QWEN).

## 3. Profils hardware (BrainSwarmConfig.PROFILES)

| Profile | Brains (Gemma 4) | RAM peak | Min RAM | Min threads | Mode |
|---------|------------------|----------|---------|-------------|------|
| NANO          | E2B narrator | 0.9 GB | 4 GB  | 2 | resident |
| SINGLE        | E4B all roles | 2.0 GB | 6 GB | 4 | resident |
| SINGLE_PLUS   | 26B-A4B + E4B (swap) | 4.2 GB | 8 GB | 4 | time-sharing |
| DUAL          | 26B-A4B + E4B parallel | 6.4 GB | 12 GB | 6 | parallel |
| TRIPLE        | 26B-A4B + E4B + E2B Worker | 7.3 GB | 14 GB | 8 | parallel |
| QUAD          | 26B-A4B + E4B + 2x E2B | 8.2 GB | 16 GB | 8 | parallel |
| OFFLINE_HEAVY | 31B dense | 17 GB | 32 GB | 16 | opt-in |
| MOBILE_LOW    | E2B GGUF | 0.8 GB | 3 GB | 4 | resident ARM64 |
| MOBILE_MID    | E4B GGUF | 2.0 GB | 6 GB | 6 | resident ARM64 |
| MOBILE_HIGH   | E4B GGUF | 2.0 GB | 7 GB | 6 | resident ARM64 |

Auto-detection : BrainSwarmConfig.detect_profile(ram, threads) / detect_profile_mobile(...).
OFFLINE_HEAVY n'est jamais auto-selectionne (opt-in via set_brain_count / settings).

## 4. Latence et tok/s (Gemma 4 Q4, CPU 8 threads)

| Modele            | RAM   | Cold load | t/s steady | Usage cible |
|-------------------|-------|-----------|------------|-------------|
| gemma4:e2b        | 0.9 G | ~3 s  | 30-45 | Judge, prefetch |
| gemma4:e4b        | 2.0 G | ~6 s  | 18-25 | GM JSON |
| gemma4:26b-a4b    | 4.2 G | ~12 s | 12-18 | Narrator long-form |
| gemma4:31b dense  | 17 G  | ~35 s | 4-7   | Offline cinematique, GPU recommande |

GPU (RTX 4070+) : multiplier t/s par 4-8x. 26B-A4B MoE active 4B params -> latence comparable a un dense 4B.

## 5. Chat template

Gemma 4 utilise le template Gemma :

```
<bos><start_of_turn>user
{system}

{user_prompt}<end_of_turn>
<start_of_turn>model
```

Differences vs Qwen ChatML :
- Pas de role system separe ; system_prompt fold dans le 1er tour user.
- raw=true : utiliser ModelsConfig.build_gemma_prompt(sys, usr).
- raw=false : Ollama applique le TEMPLATE du Modelfile.

## 6. Thinking mode

- Qwen 3.5 : <think>...</think> tags, strip via _strip_thinking_tags().
- Gemma 4 : pas de thinking publics ; champ think no-op cote serveur Ollama. Strip safe.
Helper : ModelsConfig.family_supports_thinking().

## 7. Multi-plateforme

Desktop (Windows/Linux/macOS) : merlin_llm GDExtension principal + Ollama HTTP fallback.
Mobile (Android/iOS) : GDExtension uniquement, cross-compile ARM64. Detection auto force MOBILE_*.
Web : Groq cloud uniquement, MerlinLLM/Ollama skip si OS.has_feature("web").

### Roadmap console (Q3-Q4 2026)

| Console | Approche | Modele cible | Constraints |
|---------|----------|--------------|-------------|
| Switch 2          | GDExtension ARM64 (Tegra T239), int4 | gemma4:e2b / e4b | 12 GB partage, thermal severe -> NANO/MOBILE_MID |
| PS5 Pro           | GDExtension x86_64 + Vulkan offload  | gemma4:e4b / 26b-a4b | 16 GB unified |
| Xbox Series X\|S  | GDExtension x86_64, DirectML possible | e4b (S) / 26b-a4b (X) | 10 GB (S) / 16 GB (X) |
| Steam Deck OLED   | Preset Linux/X11 existant, llama.cpp Vulkan | e4b / 26b-a4b | 16 GB unified |

Bloquants : pas de daemon Ollama, tout via GDExtension recompilee ; TRC/cert signature SDK obligatoire ; LoRA embarques dans le pck.

## 8. Settings & flags

| Setting | Defaut | Effet |
|---------|--------|-------|
| ai/use_legacy_qwen | false | Bascule vers Qwen 3.5 toute la pipeline |
| ai/brain_count     | 0 (auto) | Force 1-4 brains |
| MERLIN_SKIP_LLM_INIT=1 (env) | unset | Skip init LLM (tests capture) |

## 9. Migration commits

| Commit | Phase | Files |
|--------|-------|-------|
| feat(llm): Phase A | Swap Ollama HTTP        | ollama_backend.gd, brain_swarm_config.gd, models_config.gd, Modelfile, Modelfile.qwen35 |
| feat(llm): Phase B | GGUF + presets desktop  | merlin_ai.gd, download_gemma4.ps1, PLACE_MODEL_HERE.txt, docs/export_presets.reference.cfg |
| feat(llm): Phase C | Profils + docs          | docs/llm-architecture.md |
| feat(llm): Phase D | Console/mobile          | merlin_ai.gd (platform detection) |

## 10. Tests manuels post-migration

1. ollama pull gemma4:e4b ; ollama pull gemma4:26b-a4b
2. ollama create merlin-narrator -f Modelfile
3. .\validate.bat (0 errors GDScript)
4. python tools/cli.py godot smoke --scene res://scenes/MerlinCabinHub.tscn --duration 8
5. python tools/cli.py godot smoke --scene res://scenes/MerlinGame.tscn --duration 8 -> verifier aucun <think> ne fuit
6. Toggle legacy : ai/use_legacy_qwen=true dans project.godot -> doit log Qwen 3.5 legacy
7. godot --headless --export-release "Windows Desktop" -> verifier addons/merlin_llm/ inclus
8. godot --headless --export-debug "Android" -> APK + Gemma 4 E2B (download a la 1re run)
