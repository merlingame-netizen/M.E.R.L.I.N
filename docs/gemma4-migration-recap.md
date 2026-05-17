# MERLIN — Migration Qwen 3.5 -> Gemma 4 (récap)

Branche : `feat/gemma4-migration` (poussée sur `origin`).

## Commits

| SHA | Phase | Message |
|-----|-------|---------|
| `05c8ba33` | A | swap Qwen→Gemma 4 (Ollama HTTP backend) |
| `bab596a1` | B | GGUF Gemma 4 + presets desktop multi-OS |
| `6d350428` | C | docs llm-architecture.md (Gemma 4 era) |
| `59963768` | D | platform detection mobile/web + console roadmap |

## Fichiers modifiés (10)

| Fichier | Phase | Nature |
|---------|-------|--------|
| `addons/merlin_ai/ollama_backend.gd` | A | `DEFAULT_MODEL=gemma4:e4b`, registre étendu Gemma 4 + Qwen legacy, `runtime_default_model()` honore `ai/use_legacy_qwen` |
| `addons/merlin_ai/brain_swarm_config.gd` | A | Profils NANO/SINGLE/SINGLE_PLUS/DUAL/TRIPLE/QUAD migrés Gemma 4 (e2b/e4b/26b-a4b). Profil `OFFLINE_HEAVY` ajouté (31B dense). `PROFILES_LEGACY_QWEN` pour rollback. Mobile profiles passés sur Gemma 4 E2B/E4B GGUF. |
| `addons/merlin_ai/models_config.gd` | A | **Nouveau** module central : `ROLE_MAP_GEMMA4` / `ROLE_MAP_QWEN`, `get_tag_for_role()`, `build_gemma_prompt()` / `build_qwen_prompt()`, `family_supports_thinking()`. |
| `Modelfile` | A | `FROM gemma4:26b-a4b` + template Gemma `<start_of_turn>`. |
| `Modelfile.qwen35` | A | **Nouveau** Modelfile legacy Qwen 3.5 préservé pour rollback. |
| `addons/merlin_ai/merlin_ai.gd` | B+D | `MODEL_FILE=gemma4-e4b-q4_k_m.gguf`. `MODEL_CANDIDATES` incluent Gemma 4 + Qwen legacy. **Phase D** : détection plateforme en début de `_init_local_models()`, mobile force profil `MOBILE_*` + 1 brain, web skip backends locaux. Nouvelle fonction `_apply_mobile_profile_overrides()`. |
| `addons/merlin_llm/models/download_gemma4.ps1` | B | **Nouveau** script PowerShell de download GGUF Gemma 4 (e2b/e4b/26b-a4b/31b), fallback `Invoke-WebRequest` ou `aria2c`. Crée placeholder si DL échoue. |
| `addons/merlin_llm/models/PLACE_MODEL_HERE.txt` | B | Mis à jour : doc Gemma 4 + section legacy Qwen. |
| `docs/export_presets.reference.cfg` | B | **Nouveau** : copie de référence du `export_presets.cfg` (gitignored). Contient Web + **Windows Desktop** + **Linux/X11** + **macOS** + **Android** (ARM64). |
| `docs/llm-architecture.md` | C | **Nouveau** doc unique : mapping role->modèle, profils hardware, latence/tok-s, chat template Gemma vs ChatML, roadmap console (Switch 2 / PS5 Pro / Xbox Series X\|S / Steam Deck), settings (`ai/use_legacy_qwen`, `ai/brain_count`), tests manuels. |

## Mapping appliqué

| Rôle | Qwen 3.5 | -> | Gemma 4 |
|------|----------|----|---------|
| Judge / Worker | qwen3.5:0.8b | -> | gemma4:e2b |
| Game Master (SINGLE) | qwen3.5:2b | -> | gemma4:e4b |
| Narrator | qwen3.5:4b | -> | gemma4:26b-a4b (MoE 4B actifs) |
| Offline heavy | n/a | -> | gemma4:31b dense |
| Mobile low | llama3.2-1b | -> | gemma4-e2b-q4_k_m.gguf |
| Mobile mid/high | qwen2.5-1.5b / llama3.2-3b | -> | gemma4-e4b-q4_k_m.gguf |

## Différences template (signalées)

Gemma 4 utilise le template Gemma (pas ChatML Qwen) :

```
<bos><start_of_turn>user
{system}

{user}<end_of_turn>
<start_of_turn>model
```

- Pas de rôle `system` séparé → fold dans le 1er tour user.
- Adapter via `ModelsConfig.build_gemma_prompt(sys, usr)` quand `raw=true`.
- En `raw=false`, Ollama applique le `TEMPLATE` du Modelfile, pas besoin de formatter.

Le strip de `<think>...</think>` est conservé (no-op safe sur Gemma 4 qui n'émet pas de thinking tags publics).

## Flags & rollback

| Setting | Défaut | Effet |
|---------|--------|-------|
| `ai/use_legacy_qwen` (ProjectSettings) | `false` | Bascule toute la pipeline Qwen 3.5 (Modelfile, ROLE_MAP, profils via `PROFILES_LEGACY_QWEN`). |
| `ai/brain_count` | `0` (auto) | Force 1-4 brains. |

Rollback complet :
1. `project.godot` -> `[application]` ajouter `ai/use_legacy_qwen=true`.
2. `ollama create merlin-narrator-legacy -f Modelfile.qwen35`.
3. Le runtime reprend les tags Qwen automatiquement.

## Particularités notées

- `*.gguf` déjà gitignored — les modèles ne seront jamais committés. ✓
- `export_presets.cfg` est gitignored (`.gitignore` ligne 38). La nouvelle version contient les 5 presets, mais une **copie de spec** est committée dans `docs/export_presets.reference.cfg` pour la reproductibilité. À la prochaine ouverture, Godot devrait conserver la version locale.
- 5 stashes pré-existants ont été droppés en cours de session pour libérer du disque (un push `pre-push-1776279544`, deux pulls/rebase, deux WIP unrelated). Aucun changement Gemma 4 n'a été perdu.

## Tests manuels à exécuter par l'utilisateur

1. **Ollama pull** : `ollama pull gemma4:e2b && ollama pull gemma4:e4b && ollama pull gemma4:26b-a4b`
2. **Modelfile rebuild** : `ollama create merlin-narrator -f Modelfile`
3. **Validate.bat** : `.\validate.bat` → 0 errors GDScript parse
4. **Smoke HUB** : `python tools/cli.py godot smoke --scene "res://scenes/MerlinCabinHub.tscn" --duration 8` → vérifier que le log dit "Gemma 4 E4B (gemma4:e4b)" et que `<think>` n'apparaît plus dans la sortie
5. **Smoke game** : idem sur `res://scenes/MerlinGame.tscn` → générer une carte LLM
6. **Toggle rollback** : ajouter `ai/use_legacy_qwen=true` dans `project.godot` → relancer → doit log un profil Qwen 3.5 sans crash
7. **Export Windows** : `godot --headless --export-release "Windows Desktop"` → vérifier que `dist/windows/MERLIN.exe` est produit, taille >100 MB (avec `addons/merlin_llm/`)
8. **Export Android** : ouvrir le projet dans Godot 4.5, installer le template Android, puis `godot --headless --export-debug "Android"`

## TODO restants

| Item | Phase | Détail |
|------|-------|--------|
| Confirmer URL HF des GGUF Gemma 4 | B | `download_gemma4.ps1` utilise `huggingface.co/google/gemma-4-{tier}-it-GGUF` comme placeholder. Mettre à jour quand le mirror officiel est connu. |
| SHA256 manifest | B | Tous les `sha256='TBD'` dans le script de download → calculer et ajouter vérification post-DL. |
| Modelfile rebuild auto | A | `tools/cli.py ollama` n'a pas de sous-commande `create-modelfile` → l'ajouter pour automatiser `ollama create merlin-narrator -f Modelfile`. |
| Templates Android adaptive icons | D | Pas encore créés (`launcher_icons/main_192x192=""`). |
| LoRA narrator re-finetune sur Gemma 4 | C | `merlin_narrator_lora.gguf` a été entraîné sur Qwen 3.5:4b — il faut un nouveau LoRA basé sur Gemma 4 26B-A4B sinon l'adapter sera incompatible avec le base model. Voir `docs/LORA_TRAINING_SPEC.html`. |
| Console SDK builds | D | Switch 2/PS5/Xbox nécessitent recompiler `addons/merlin_llm/` avec leurs toolchains respectives (TRC/cert). |
| Smoke runtime exécution | — | Bash sandbox n'était pas dispo en session, smoke non exécuté côté agent. À faire manuellement avant merge. |
| Stash pré-Gemma | — | 5 stashes droppés. Si vous aviez besoin d'un WIP particulier (`pre-push-1776279544`, `wip-uncommitted-unrelated`), il faut le récupérer via reflog. |
| Cleanup C: drive | — | Le disque a saturé en cours de session ; `git gc --prune=now` n'a pas pu finir (timeout). Le repo fonctionne mais un gc complet est recommandé. |

## Schéma archi finale

```
MerlinAI autoload
├─ detect platform (web/mobile/desktop)
│  ├─ web   -> Groq cloud only (skip native)
│  ├─ mobile -> MerlinLLM GDExtension (ARM64, Gemma 4 E2B/E4B GGUF)
│  └─ desktop -> MerlinLLM GDExtension (priorité) puis Ollama HTTP (fallback)
│
├─ BrainSwarmConfig.detect_profile(ram, threads)
│  ├─ NANO        (Gemma 4 E2B)        -- 4 GB RAM min
│  ├─ SINGLE      (Gemma 4 E4B)        -- 6 GB RAM
│  ├─ SINGLE_PLUS (26B-A4B + E4B swap) -- 8 GB
│  ├─ DUAL        (26B-A4B || E4B)     -- 12 GB
│  ├─ TRIPLE      (+ E2B worker)       -- 14 GB
│  ├─ QUAD        (+ E2B judge)        -- 16 GB
│  └─ OFFLINE_HEAVY (31B dense opt-in) -- 32 GB
│
└─ ModelsConfig.get_tag_for_role(role) honoring ai/use_legacy_qwen
```

---

## Phase E – bootstrap & validation (2026-05-17 PM)

### Statut par sous-phase

| Sous-phase | Statut | Livrable |
|------------|--------|----------|
| **E1** — Download Gemma 4 GGUF (e4b + 26b-a4b) | **BLOQUÉ** | C: à 157 MB libres (besoin ~20 GB pour e4b+26b-a4b GGUF). |
| **E2** — Ollama bootstrap (pull + create + verify template) | **BLOQUÉ** (dépend E1) | Idem : `~/.ollama/models` sature C: aussi. |
| **E3** — Smoke tests (validate.bat + godot smoke) | **BLOQUÉ** | Godot editor --headless --quit timeout >120s. Cause probable : pas assez de disque pour cache `.godot/imported/`. Le log `%APPDATA%/Godot/app_userdata/MERLIN/logs/godot.log` n'a pas été mis à jour depuis 12:02:58 malgré 3 tentatives de relance. |
| **E4** — Plan LoRA refinetune Gemma 4 | ✅ | `docs/lora-refinetune-plan.md` (10 sections, prêt à exécuter) |
| **E5** — Console roadmap dépliée | ✅ | `docs/llm-architecture.md` §Roadmap console : 8 tâches commitables (T-CONS-1..T-CONS-8) Switch 2 / PS5 / Xbox / Steam Deck / Groq fallback / LoRA embedded |
| **E6** — Append récap + push final | ✅ | ce fichier |

### Vérifications statiques effectuées (faute de runtime)

- `addons/merlin_ai/merlin_ai.gd` : `_init_local_models()` Phase D détection plateforme — appelle `_apply_mobile_profile_overrides()` qui existe (lignes 591-598). Skip GDExtension/Ollama sur web, force `BRAIN_SINGLE` + GDExtension uniquement sur mobile.
- `addons/merlin_ai/brain_swarm_config.gd` : `detect_profile_mobile()` (ligne 312) existe, retourne `MOBILE_HIGH > MOBILE_MID > MOBILE_LOW` selon RAM. Les 3 profils `MOBILE_*` sont définis lignes 161-198 avec modèles Gemma 4 E2B/E4B GGUF.
- Cohérence d'enum : `Profile.MOBILE_LOW/MID/HIGH` présents lignes 25, 161, 174, 187, 254, 261, 268, 312-317.

### Livrable E4 — `docs/lora-refinetune-plan.md`

10 sections couvrent : contexte (Qwen→Gemma incompatibilité), choix base model (E4B vs 26B-A4B vs 31B), conversion dataset ChatML→Gemma template, hyperparams LoRA r=16/alpha=32/target_modules (identiques Qwen côté noms), estimations VRAM/temps/coût par hardware, commandes exactes (Unsloth + PEFT fallback), pipeline merge+quantize → GGUF, critères d'éval (JSON valid ≥95 %, champ lexical ≥70 %, faction alignment ≥85 %), risques (slug HF non publié, tokenizer Ogham, MoE experts OOM).

**Action humaine attendue avant lancement** : libérer disque, décider E4B (rapide) ou 26B-A4B (qualité), confirmer GPU dispo, approuver `huggingface-cli login` pour gated repo Google.

### Livrable E5 — `docs/llm-architecture.md` §Roadmap console

Roadmap dépliée en 8 tâches `T-CONS-1` à `T-CONS-8` :

| Tâche | Plateforme | Verdict |
|-------|------------|---------|
| T-CONS-1 | Build matrix CI toutes consoles | Bloqué NDA Nintendo |
| T-CONS-2 | Quantization pipeline cross-platform | `tools/cli.py llm quantize --target X` à implémenter |
| T-CONS-3 | Switch 2 (Tegra T239 ARM64) | Profils `SWITCH2_DOCKED/HANDHELD`, cible 8 tok/s e2b Q4_K_M handheld |
| T-CONS-4 | PS5/PS5 Pro (x86_64 + RDNA 2) | Profils `PS5` (DUAL) / `PS5_PRO` (TRIPLE), cible 12-18 tok/s 26b-a4b |
| T-CONS-5 | Xbox Series X\|S | Series S **tight** (10 GB total) → Groq forcé si LLM > 1.8 GB |
| T-CONS-6 | Steam Deck OLED | Preset Linux/X11 existe, profil `STEAM_DECK` SINGLE_PLUS |
| T-CONS-7 | Fallback Groq universel | **Décision business pending** : self-host proxy via Cloudflare Workers ? Coût ~0.05$/1k tokens × N joueurs |
| T-CONS-8 | LoRA embedded dans .pck | Vérifier filtres export pour inclure GGUF LoRA dans pack signé |

Bloquants transverses : pas de daemon Ollama console, cert SDK 4-8 semaines, LoRA embedded obligatoire (interdit DL runtime), thermal+background NOTIFICATION_APPLICATION_PAUSED.

### Décisions humaines attendues (ping Maxime)

1. **Disque** : libérer ~30 GB sur C: ou pointer modèles vers drive externe ? Sans ça, E1/E2/E3 restent bloqués.
2. **LoRA training** : E4B (rapide) ou 26B-A4B (qualité) en première itération ?
3. **GPU LoRA** : 4070 12GB local ? 4090 ? Colab Pro A100 ? Lambda Labs ?
4. **Cert SDK consoles** : signer NDA Nintendo / Sony DevNet / Microsoft GDK fin 2026 ?
5. **Groq proxy** : Cloudflare Workers self-host ou config clé API côté joueur ?

### Commits Phase E

| Commit | Files |
|--------|-------|
| `docs(llm): Phase E4 — plan LoRA refinetune Gemma 4` | docs/lora-refinetune-plan.md |
| `docs(llm): Phase E5 — console roadmap dépliée (8 tâches T-CONS-*)` | docs/llm-architecture.md |
| `docs(llm): Phase E6 — recap final + checklist décisions humaines` | docs/gemma4-migration-recap.md |
