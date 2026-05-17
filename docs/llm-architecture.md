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

### Roadmap console (Q3-Q4 2026) — tâches concrètes

#### Vue d'ensemble

| Console | Approche | Modèle cible | Quant | Contraintes mémoire | Fallback cloud |
|---------|----------|--------------|-------|---------------------|----------------|
| Switch 2          | GDExtension ARM64 (Tegra T239)       | gemma4:e2b                 | Q4_K_M (1.4 GB)  | 12 GB unified (jeu ~8 GB max), thermal severe | Groq cloud (cellular OK via Nintendo Online) |
| PS5 / PS5 Pro     | GDExtension x86_64 + Vulkan/AMD GPU  | gemma4:e4b → 26b-a4b       | Q4_K_M / Q5_K_M  | 16 GB unified (jeu ~12 GB), 13.4 TFLOPS GPU   | Groq via PSN + opt-in PS Network sharing |
| Xbox Series S     | GDExtension x86_64, DirectML possible | gemma4:e4b                 | Q4_K_M (2.5 GB)  | 10 GB total dont 8 GB jeu — **tight**          | Groq via Xbox Live (obligatoire si VRAM < 1 GB libre) |
| Xbox Series X     | GDExtension x86_64, DirectML possible | gemma4:26b-a4b             | Q4_K_M (14 GB)   | 16 GB unified (jeu 13.5 GB), 12 TFLOPS GPU    | Groq fallback si autres systèmes mémoire saturent |
| Steam Deck OLED   | Preset Linux/X11 existant, llama.cpp Vulkan | gemma4:e4b / 26b-a4b | Q4_K_M           | 16 GB unified LPDDR5, APU RDNA 2 1.6 TFLOPS    | Optionnel (Wi-Fi only) |

#### Tâches commitables

##### T-CONS-1 — Build matrix CI (toutes consoles) [bloquant pré-cert]

- [ ] Ajouter cible `addons/merlin_llm/SConstruct` pour `platform=switch2|ps5|xbox` (variants ARM64/x86_64).
- [ ] Demander accès Nintendo Developer Portal (TRC), Sony DevNet (TRC), Microsoft GDK.
- [ ] Documenter chaîne de compilation par plateforme dans `docs/console-build.md`.
- [ ] Bloquant légal : signer NDA Nintendo (Switch 2 SDK gated). Action humaine.

##### T-CONS-2 — Quantization pipeline cross-platform

- [ ] `tools/cli.py llm quantize --target switch2 --model gemma4-e2b` → Q4_K_M GGUF.
- [ ] Bench llama.cpp Q4_K_M vs Q4_0 vs Q5_K_M sur ARM64 (Tegra) et x86_64 PS5 dev kit.
- [ ] Définir tableau : taille mémoire vs perplexity loss pour chaque cible.
- [ ] Output : `addons/merlin_llm/models/console/{switch2,ps5,xbox}/merlin_narrator_*.gguf` (gitignored, builds CI seulement).

##### T-CONS-3 — Switch 2 (Tegra T239 ARM64)

Contraintes :
- 12 GB unified LPDDR5 (jeu ~8 GB max après OS), Vulkan + NVN.
- Thermal docked 15W / handheld 7W → throttling agressif.
- LLM doit céder VRAM dès que minigame 3D demande > 4 GB.

Tâches :
- [ ] Cross-compile llama.cpp branche `master` avec `LLAMA_VULKAN=1 -DGGML_CPU_AARCH64=1` via toolchain Nintendo (devkitA64 ou clang-aarch64-linux-gnu pour proto).
- [ ] Profil hardware ajouté à `brain_swarm_config.gd` : `SWITCH2_DOCKED` (NANO, 1 brain e2b, ctx 2048) et `SWITCH2_HANDHELD` (NANO downgraded, e2b ctx 1024).
- [ ] Bench : tok/s cible ≥ 8 tok/s sur e2b Q4_K_M handheld (sinon downgrade vers Groq).
- [ ] Hot-swap dynamique : `merlin_ai.gd` doit unloader le LLM si `Performance.get_monitor(MEMORY_VIDEO_USED)` > seuil (cf hook `_low_memory_handler`).
- [ ] Fallback Groq via Nintendo Online (HTTPS sortant autorisé, latence cellulaire OK ~300ms).

##### T-CONS-4 — PS5 / PS5 Pro (x86_64 + RDNA 2)

Contraintes :
- 16 GB GDDR6 unified, GPU 10.28 TFLOPS (Pro: 13.4) — large.
- Activity Cards / Game Help interdisent certains threads bg → LLM doit s'arrêter quand `EnterBackground` event reçu.

Tâches :
- [ ] Compile llama.cpp avec `LLAMA_HIPBLAS=1` pour RDNA 2 (ROCm pas dispo sur PS5, utiliser CPU-only ou explorer Sony GPU compute via Vulkan compute shaders).
- [ ] Profil `PS5` (DUAL, 26b-a4b + e4b) et `PS5_PRO` (TRIPLE).
- [ ] Bench cible : 26b-a4b Q4_K_M ≥ 12 tok/s sur PS5 base, ≥ 18 tok/s sur Pro.
- [ ] Implémenter hook `notification(NOTIFICATION_APPLICATION_PAUSED)` → flush LLM cache.
- [ ] Trophy : interdit de modifier le save quand le LLM tourne en bg (Sony TRC R4055).
- [ ] Fallback Groq via PSN HTTPS — opt-in obligatoire (parental controls TRC R4011).

##### T-CONS-5 — Xbox Series X|S (x86_64 + RDNA 2 + DirectML)

Contraintes :
- Series S : **10 GB total**, 8 GB jeu, 2 GB OS. LLM ≤ 2.5 GB → e4b Q4_K_M tient mais juste.
- Series X : 16 GB GDDR6 (10 GB high-speed + 6 GB slow), jeu max ~13.5 GB.
- DirectML disponible → option compute shaders pour MoE routing.

Tâches :
- [ ] Compile llama.cpp avec `LLAMA_CUBLAS=0 LLAMA_HIPBLAS=0` (Xbox bloque ROCm) → CPU-only + DirectML compute hint.
- [ ] Branche expérimentale : porter `ggml-directml.cpp` (existe dans fork llama-cpp-python, non upstreamé).
- [ ] Profil `XBOX_SERIES_S` (SINGLE, e4b Q4_K_M only, ctx 4096) et `XBOX_SERIES_X` (DUAL, 26b-a4b + e4b).
- [ ] Series S : forcer Groq dès que LLM utilise > 1.8 GB (marge 200 MB).
- [ ] GDK certification : Microsoft Game Sandbox interdit `fork()` → llama.cpp doit être linké statiquement, pas de subprocess.

##### T-CONS-6 — Steam Deck OLED (Linux/X11 + RDNA 2 APU)

Le preset Linux/X11 existant (`docs/export_presets.reference.cfg`) couvre déjà. Reste :
- [ ] Tester export `godot --headless --export-release "Linux/X11"` puis copier sur Deck via USB.
- [ ] Bench `gemma4-e4b-q4_k_m.gguf` via llama.cpp Vulkan : cible ≥ 15 tok/s en mode 15W (docked TDP).
- [ ] Ajouter détection APU dans `merlin_ai.gd` → profil `STEAM_DECK` (SINGLE_PLUS, e4b principal + e2b worker).
- [ ] Vérifier compat Proton/Wine si jeu shipped via Windows runtime (préférer build natif Linux).

##### T-CONS-7 — Fallback Groq universel

Tous les ports console partagent un fallback cloud :

- [ ] Module `addons/merlin_ai/cloud_backends/groq_backend.gd` (déjà esquissé dans `merlin_ai.gd`).
- [ ] Endpoint : `https://api.groq.com/openai/v1/chat/completions`, modèle `gemma2-9b-it` (proxy car Gemma 4 pas encore sur Groq fin 2026 ; vérifier roadmap).
- [ ] Stratégie déclenchement :
  - Si platform == web → Groq always.
  - Si console ET (VRAM < seuil OU thermal throttle détecté) → Groq.
  - Si user a opt-in "Cloud LLM" dans Settings → Groq préféré.
- [ ] Quota / billing : nécessite **clé API Groq côté serveur Anthropic + proxy** (l'utilisateur final ne configure pas de clé). **Décision business pending Maxime** : self-host proxy via Cloudflare Workers ? Coût ~0.05$/1k tokens × N joueurs = à modéliser.

##### T-CONS-8 — Embedded LoRA dans le .pck

- [ ] LoRA narrator (post-refinetune Gemma 4, cf `docs/lora-refinetune-plan.md`) doit être inclus dans le pack console signé.
- [ ] Vérifier que `addons/merlin_llm/models/merlin_narrator_lora_gemma4.gguf` est **inclus** dans les filtres export (pas dans `.gitignore` côté pck).
- [ ] Taille LoRA ~50–150 MB (rank 16) → acceptable pour Switch 2 cartouche 16 GB, PS5/Xbox download.

#### Bloquants transverses

1. **Pas de daemon Ollama sur console** : tout via GDExtension `merlin_llm` recompilée pour chaque SDK. Ollama HTTP backend est désactivé automatiquement (`merlin_ai.gd` Phase D platform detection).
2. **Cert SDK obligatoire** : TRC Nintendo, Sony, Microsoft. Délai 4–8 semaines après cert request. Action humaine : signer NDA fin 2026.
3. **LoRA embedded** : interdit de downloader des poids modèle à l'exécution sur console (sauf via store officiel). LoRA doit être dans le pck signé.
4. **Réseau** : Groq fallback nécessite HTTPS sortant. Nintendo Switch 2 cellulaire OK, PS5 PSN OK, Xbox Live OK, Steam Deck Wi-Fi only.
5. **Thermal & background** : tous les ports doivent gérer `NOTIFICATION_APPLICATION_PAUSED` → flush LLM. Sinon TRC fail.

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
