# Brain Swarm Architecture — Orchestration Multi-Cerveaux Hétérogène

**Last Updated:** 2026-03-15
**Version:** 2.0 (Phase 33)
**Source Files:**
- `addons/merlin_ai/brain_swarm_config.gd` — Profils matériels
- `addons/merlin_ai/brain_swarm_scheduler.gd` — Allocation intelligente
- `addons/merlin_ai/brain_process_manager.gd` — Gestion des processus

---

## 1. Rôle et Principes Fondamentaux

Le **Brain Swarm** est le système d'orchestration qui gère un ensemble hétérogène de modèles LLM (Qwen 3.5 multi-tailles) en parallèle ou en time-sharing, selon les capacités matérielles disponibles.

### Principes

1. **Hétérogène** — Chaque cerveau utilise un modèle de taille différente, optimisé pour son rôle
2. **Adaptatif** — Détection automatique du hardware et sélection du profil optimal
3. **Tolérant aux pannes** — Dégradation gracieuse si un cerveau crash
4. **Efficace en mémoire** — Time-sharing sur RAM limitée (SINGLE+) ou parallélisation sur desktop (DUAL/QUAD)
5. **Prioritaire** — Allocation intelligente avec preemption pour tâches critiques

### Bénéfices

| Bénéfice | Détail |
|----------|--------|
| **Latence réduite** | Narrator (4B) + GM (2B) parallèles vs sequentiel → ~8-12s vs ~12-15s par carte |
| **Flexibilité matériel** | NANO sur 4GB, QUAD sur 16GB — même codebase |
| **Qualité diversifiée** | Narrator creatif (T=0.70), GM logique (T=0.15), Judge critique (thinking=true) |
| **Resilience** | Crash d'un cerveau → dégradation automatique vs crash total |

---

## 2. Tiers Matériels (Profils)

Le système supporte 6 profils matériels, du plus léger au plus puissant.

### Matrice Complète

| Profil | Mode | RAM Pic | CPUs | Contexte | Latence/carte | Cas d'usage |
|--------|------|---------|------|----------|---------------|------------|
| **NANO** | Resident | 4 GB | 2+ | 2048 | ~12s | Mobile, ultra-low |
| **SINGLE** | Resident | 6 GB | 4+ | 4096 | ~10s | Laptop faible |
| **SINGLE+** | Time-sharing | 7 GB | 4+ | 8192/4096 | ~12-15s | Laptop gaming |
| **DUAL** | Parallèle | 12 GB | 6+ | 8192/4096 | ~8s | Desktop gaming |
| **TRIPLE** | Parallèle | 14 GB | 8+ | 8192/4096/2048 | ~7s | Desktop haute-perf |
| **QUAD** | Parallèle | 16 GB | 8+ | 8192/4096/2048/2048 | ~7s | Serveur multi-tâche |

### Détails par Profil

#### NANO (0.8B all roles)
```gdscript
"NANO": {
    "name": "Nano (0.8B all roles)",
    "mode": "resident",
    "brains": [
        {"role": "narrator", "model": "qwen3.5:0.8b", "n_ctx": 2048}
    ],
    "total_ram_mb": 800,
    "min_threads": 2,
    "min_ram_mb": 4000,
    "prefetch_depth": 0,
}
```

**Caractéristiques:**
- Un seul modèle en mémoire (0.8B)
- Toutes les tâches séquentielles
- Contexte réduit (2048 tokens)
- **Cas:** Téléphones, SBC (Raspberry Pi)
- **Latence:** ~12s par carte (lent mais fiable)

#### SINGLE (2B all roles)
```gdscript
"SINGLE": {
    "name": "Single (2B all roles)",
    "mode": "resident",
    "brains": [
        {"role": "narrator", "model": "qwen3.5:2b", "n_ctx": 4096}
    ],
    "total_ram_mb": 1800,
    "min_threads": 4,
    "min_ram_mb": 6000,
    "prefetch_depth": 1,
}
```

**Caractéristiques:**
- Un modèle 2B en mémoire (amélioré vs NANO)
- Prefetch depth=1 — peut démarrer à charger la prochaine carte pendant que celle-ci joue
- Contexte modéré (4096 tokens)
- **Cas:** Laptops avec 6GB libre
- **Latence:** ~10s (acceptable pour gameplay)

#### SINGLE+ (4B/2B time-sharing)
```gdscript
"SINGLE+": {
    "name": "Single+ (4B Narrator / 2B GM, time-sharing)",
    "mode": "time_sharing",
    "brains": [
        {"role": "narrator", "model": "qwen3.5:4b", "n_ctx": 8192},
        {"role": "gamemaster", "model": "qwen3.5:2b", "n_ctx": 4096}
    ],
    "total_ram_mb": 3200,  # Peak RAM = largest model only
    "min_threads": 4,
    "min_ram_mb": 7000,
    "prefetch_depth": 1,
}
```

**Caractéristiques:**
- **Time-sharing:** Un seul modèle en RAM à la fois
- Étape 1 (Narrator/4B) → Étape 2 (swap modèle via Ollama) → Étape 3 (GM/2B)
- Penalty: ~2s supplémentaires pour le swap
- RAM pic = 3.2GB (le plus grand)
- **Cas:** Laptop gaming avec 7-10GB
- **Latence:** ~12-15s par carte (bonne balance RAM/perf)

#### DUAL (4B + 2B parallèle)
```gdscript
"DUAL": {
    "name": "Dual (4B Narrator + 2B GM parallel)",
    "mode": "parallel",
    "brains": [
        {"role": "narrator", "model": "qwen3.5:4b", "n_ctx": 8192},
        {"role": "gamemaster", "model": "qwen3.5:2b", "n_ctx": 4096}
    ],
    "total_ram_mb": 5000,  # Both loaded simultaneously
    "min_threads": 6,
    "min_ram_mb": 12000,
    "prefetch_depth": 1,
}
```

**Caractéristiques:**
- Narrator (4B) et GM (2B) chargés simultanément
- Génération **parallèle:** texte + effets JSON en même temps
- RAM pic = 5GB (somme des deux)
- CPU intense (6+ threads)
- **Cas:** Desktop gaming 12GB+
- **Latence:** ~8s par carte (plus rapide grâce au parallélisme)

#### TRIPLE (4B + 2B + 0.8B Worker)
```gdscript
"TRIPLE": {
    "name": "Triple (4B + 2B + 0.8B Worker)",
    "mode": "parallel",
    "brains": [
        {"role": "narrator", "model": "qwen3.5:4b", "n_ctx": 8192},
        {"role": "gamemaster", "model": "qwen3.5:2b", "n_ctx": 4096},
        {"role": "worker", "model": "qwen3.5:0.8b", "n_ctx": 2048}
    ],
    "total_ram_mb": 5800,
    "min_threads": 8,
    "min_ram_mb": 14000,
    "prefetch_depth": 2,
}
```

**Caractéristiques:**
- Narrator + GM + Worker (0.8B) tous actifs
- **Prefetch depth=2** — peut préparer 2 cartes d'avance
- Worker libre pour:
  - Prefetch des modèles pour la prochaine carte
  - Génération de voix (enrichissement)
  - Balancing en arrière-plan
- **Cas:** Desktop haute-perf 14GB+
- **Latence:** ~7s par carte

#### QUAD (4B + 2B + 0.8B Judge + 0.8B Worker)
```gdscript
"QUAD": {
    "name": "Quad (4B + 2B + 0.8B Judge + 0.8B Worker)",
    "mode": "parallel",
    "brains": [
        {"role": "narrator", "model": "qwen3.5:4b", "n_ctx": 8192},
        {"role": "gamemaster", "model": "qwen3.5:2b", "n_ctx": 4096},
        {"role": "judge", "model": "qwen3.5:0.8b", "n_ctx": 2048},    # Thinking=true
        {"role": "worker", "model": "qwen3.5:0.8b", "n_ctx": 2048}
    ],
    "total_ram_mb": 6600,
    "min_threads": 8,
    "min_ram_mb": 16000,
    "prefetch_depth": 3,
}
```

**Caractéristiques:**
- Configuration maximale: 4 cerveaux complètement parallèles
- **Judge** (0.8B) avec `thinking=true` — valide qualité de sorties critiques
- **Worker** (0.8B) pour tâches légères
- Prefetch depth=3 — prépare 3 cartes à l'avance
- **Cas:** Serveur multi-session, streaming avec IA critique
- **Latence:** ~7s par carte avec overhead de jugement

---

## 3. Auto-détection Matérielle

La détection se fait dans `BrainSwarmConfig.detect_profile()`.

### Algorithme

```gdscript
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int:
    # Parcours de QUAD vers NANO, retourne le plus grand qui rentre
    for profile_id in [Profile.QUAD, Profile.TRIPLE, Profile.DUAL,
                       Profile.SINGLE_PLUS, Profile.SINGLE, Profile.NANO]:
        var profile: Dictionary = PROFILES[profile_id]
        if available_ram_mb >= int(profile.min_ram_mb) and
           cpu_threads >= int(profile.min_threads):
            return profile_id
    return Profile.NANO  # Fallback ultime
```

### Critères de Sélection

| Critère | Valeur | Exemple |
|---------|--------|---------|
| RAM disponible | min_ram_mb | DUAL nécessite 12GB |
| Threads CPU | min_threads | DUAL nécessite 6 threads |
| Détection | Ordre décroissant | Tente QUAD en premier |
| Fallback | NANO toujours possible | Même sur 512MB (très lent) |

### Intégration dans merlin_ai.gd

```gdscript
# Dans _load_brain_config()
var available_ram_mb: int = OS.get_static_memory_usage() / (1024 * 1024)
var cpu_threads: int = OS.get_processor_count()

_active_profile_id = BrainSwarmConfig.detect_profile(available_ram_mb, cpu_threads)

# Afficher le profil détecté
var profile_name: String = BrainSwarmConfig.get_profile_name(_active_profile_id)
print("[MerlinAI] Profile auto-detected: %s (RAM=%dMB, CPU=%d cores)" %
      [profile_name, available_ram_mb, cpu_threads])
```

---

## 4. Time-sharing vs Parallélisation

Le système utilise deux modes orthogonaux selon le profil:

### Time-Sharing (SINGLE+)

Utilisé quand la RAM est limitée mais suffisant pour charger les 2 plus gros modèles alternativement.

```
Timeline (séquentiel):
┌─────────────────────────────────────────────────┐
│ T=0     Load Narrator (4B) in RAM               │
│ T=0.5   Narrator/4B genère texte + choix         │ (6s)
│ T=6.5   Unload Narrator, load GM (2B)           │ (2s swap)
│ T=8.5   GM/2B genère JSON des effets             │ (2s)
│ T=10.5  Résultats affichés                      │
└─────────────────────────────────────────────────┘
Total: ~12-15s
```

**Implémentation:**
- Ollama gère le swap de modèles (via `ollama pull` et unload)
- `_is_time_sharing` flag en merlin_ai.gd
- Tâches séquentielles: await generation 1, await generation 2

### Parallélisation (DUAL/TRIPLE/QUAD)

Utilisé quand suffisament de RAM pour charger tous les modèles simultanément.

```
Timeline (parallèle):
┌──────────────────────────────┐
│ T=0  Load Narrator (4B)      │
│      Load GM (2B)             │  (both load concurrently)
│ T=1  Both ready               │
├──────────────────────────────┤
│ T=1    Narrator starts        │
│        GM starts              │  (both generate in parallel)
│ T=6    Both done              │
│ T=7    Résultats affichés     │
└──────────────────────────────┘
Total: ~8s
```

**Implémentation:**
- Tous les modèles pré-loadés
- Appels HTTP simultanés via `HTTPRequest` ou coroutines
- `await gather(narrator_gen, gm_gen)` style

---

## 5. Routage par Rôle (Role Routing)

Chaque demande de génération est routée vers un cerveau spécifique selon son rôle.

### Rôles Disponibles

| Rôle | Modèle Typique | Température | Thinking | Use Cases |
|------|----------------|-------------|----------|-----------|
| **narrator** | 4B (DUAL+) ou 2B (SINGLE) | 0.70 | OFF | Texte créatif, scénarios, dialogue |
| **gamemaster** | 2B (DUAL+) ou partagé (SINGLE) | 0.15 | ON | JSON d'effets, équilibrage, JSON structs |
| **worker** | 0.8B (TRIPLE+) ou fallback à narrator | 0.30 | OFF | Prefetch, voix, balancing asynchrone |
| **judge** | 0.8B (QUAD) ou fallback à GM | 0.10 | ON | Scoring qualité, validation critique |
| **voice** | Toute 0.8B disponible | 0.40 | OFF | Enrichissement voix (léger) |

### Fonction de Routage

```gdscript
# Dans BrainSwarmScheduler
static func _get_compatible_roles(preferred: String) -> Array:
    match preferred:
        "narrator":
            return ["worker", "gamemaster"]  # Fallback prioritaire
        "gamemaster":
            return ["worker", "narrator"]    # Fallback si GM occupé
        "worker":
            return ["gamemaster", "narrator"] # Flexible
        "judge":
            return ["worker", "gamemaster"]   # Juge = critique pointue
        "voice":
            return ["worker"]                 # Léger, spécialisé
        _:
            return ["worker", "gamemaster", "narrator"]
```

### Pipeline Standard (DUAL)

```
1. get_model_for_role("narrator")
   → Si DUAL: retourne 4B
   → Si SINGLE: retourne 2B (l'unique modèle)

2. generate_narrative(model_4b, prompt)
   → 6-8s, texte + 3 choix

3. get_model_for_role("gamemaster")
   → Si DUAL: retourne 2B (différent du 4B)
   → Parallèle avec étape 2

4. generate_effects(model_2b, prompt)
   → 2-3s, JSON strictement formaté
```

---

## 6. Allocation Intelligente (BrainSwarmScheduler)

Le scheduler gère la distribution des tâches aux cerveaux disponibles avec support pour:
- Priorités (CRITICAL > HIGH > NORMAL > LOW)
- Affinité de rôle (hint de routing)
- Timeout automatique (libération forcée si gelé)
- Dégradation gracieuse

### États et Transitions

```
State Machine:
─────────────────────────────────────────────────

  IDLE                   REQUEST_BRAIN()
  ├─ Cherche exact match ──→ BUSY (priority = 0-3)
  ├─ Cherche compatible    │
  ├─ Cherche any idle      │
  └─ Preempt si CRITICAL   │
                           │
                       RELEASE_BRAIN()
                           │
                           ↓
                        IDLE
```

### Priorités

```gdscript
enum Priority {
    CRITICAL = 0,   # Remet le jeu immédiatement (MOS deadline)
    HIGH = 1,       # Narratif on-demand (choix joueur réagit)
    NORMAL = 2,     # Prefetch en arrière-plan
    LOW = 3,        # Balancing, historique
}
```

**Preemption:** Si une tâche CRITICAL arrive et aucun cerveau libre, un cerveau LOW en cours est annulé et reassigné.

### Affinity Chains

Quand un cerveau de rôle préféré n'est pas libre:

```gdscript
request_brain("narrator")
  ↓ Narrator occupé
  → Essaye "worker", "gamemaster" (chaîne de fallback)
  ↓ Tous occupés
  → Essaye ANY idle brain
  ↓ Aucun idle
  → Si priorité >= HIGH: preempt le plus ancien LOW
  ↓ Sinon: retourne null (appeler plus tard)
```

### Timeouts

```gdscript
const TIMEOUT_SMALL_MS := 30000   # 2B: 30s max
const TIMEOUT_LARGE_MS := 60000   # 7B: 60s max
const TIMEOUT_DEFAULT_MS := 45000 # Autre: 45s

# Dans _check_timeouts():
if now - slot.busy_since > slot.timeout_ms:
    cancel_generation()
    release_brain()
    print("Brain timed out")
```

### Dégradation de Tier

Si une cerveau crash ou devient inresponsif:

```
FULL (4 brains)
  ↓ crash d'un cerveau
SLIM (3 brains)
  ↓ crash d'un cerveau
DUAL (2 brains)
  ↓ crash d'un cerveau
SINGLE (1 cerveau)
  ↓ dernier crash → game over (fallback static)
```

Code:
```gdscript
func mark_brain_dead(llm: Object) -> void:
    for slot in _brains:
        if slot.llm == llm:
            slot.alive = false
            slot.busy = false
            _update_tier()  # Recalcule Tier
            return
```

---

## 7. Gestion des Processus (BrainProcessManager)

Le **BrainProcessManager** lance et surveille les processus llama-server.exe (ou équivalent Ollama).

### Architecture

```
BrainProcessManager (Godot)
├─ Configure brain_defs (avant start)
├─ start_all()
│  └─ Pour chaque cerveau: _start_brain(index)
│     └─ OS.create_process(llama-server.exe, args)
│        └─ Retourne PID
├─ wait_for_healthy() [startup seulement]
│  └─ HTTP health check sur port per brain
│     └─ GET /health → {"status": "ok"}
├─ poll_health() [every 10s durant gameplay]
│  └─ Détecte crash et _try_restart_brain()
└─ stop_all() [_exit_tree]
   └─ OS.kill(pid) pour chaque cerveau
```

### Configuration Préalable

```gdscript
# Avant start_all():
var mgr = BrainProcessManager.new()
mgr.configure(
    "C:/path/to/llama-server.exe",
    [
        {"role": "narrator", "model": "C:/models/qwen35-4b.gguf", "threads": 4, "n_ctx": 8192},
        {"role": "gamemaster", "model": "C:/models/qwen35-2b.gguf", "threads": 2, "n_ctx": 4096},
    ]
)
```

### Startup Sequence

```
1. start_all()
   ├─ _start_brain(0) → OS.create_process() → PID 1234
   ├─ _start_brain(1) → OS.create_process() → PID 1235
   └─ Retourne count started (2)

2. wait_for_healthy(timeout=30s)
   ├─ Pour chaque cerveau:
   │  └─ _check_brain_health(index)
   │     └─ HTTPClient.connect() → GET /health
   │        ├─ Si 200 OK & {"status": "ok"}: health=true
   │        └─ Si timeout/error: health=false
   └─ Retourne count healthy (2)

3. create_backend(index)
   └─ Retourne BitNetBackend connecté à port 8081+index
```

### Health Polling (Gameplay)

Chaque 10s (HEALTH_CHECK_INTERVAL_MS):

```gdscript
func poll_health() -> Array:
    for i in range(_brain_configs.size()):
        if OS.is_process_running(_brain_pids[i]):
            var healthy = _check_brain_health(i)
            if not healthy:
                _try_restart_brain(i)
        else:
            # Process exited/crashed
            _try_restart_brain(i)
    return results
```

### Restart Logic

```
Brain crashes
  ↓
poll_health() → OS.is_process_running() = false
  ↓
_try_restart_brain(index)
  ├─ Check _restart_counts[index] < MAX_RESTART_ATTEMPTS (3)
  ├─ If yes:
  │  ├─ Sleep 5s (RESTART_COOLDOWN_MS)
  │  ├─ _start_brain(index)
  │  └─ _restart_counts[index]++
  └─ If no: print warning, mark as dead
```

### Port Allocation

Chaque cerveau obtient un port unique:
```
BASE_PORT = 8081
Brain 0 → 8081
Brain 1 → 8082
Brain 2 → 8083
Brain 3 → 8084
```

---

## 8. Configuration et Constantes

### BrainSwarmConfig — Constantes Critiques

```gdscript
# Modèles Qwen 3.5 (Ollama tags)
const MODEL_QWEN35_4B := "qwen3.5:4b"
const MODEL_QWEN35_2B := "qwen3.5:2b"
const MODEL_QWEN35_08B := "qwen3.5:0.8b"

# Estimations RAM (Q4 quantization + KV cache)
const RAM_BY_MODEL := {
    "qwen35_4b": 3200,      # 3.2 GB
    "qwen35_2b": 1800,      # 1.8 GB
    "qwen35_0.8b": 800,     # 0.8 GB
}

# Profiles
enum Profile { NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD }

# Chaque profil:
# - name: String pour display
# - mode: "resident" | "time_sharing" | "parallel"
# - brains: Array de {role, model_key, ollama_tag, n_ctx, ram_mb, thinking}
# - total_ram_mb: pic de mémoire
# - min_threads: CPU minimum
# - min_ram_mb: RAM système minimum
# - prefetch_depth: nombre de cartes à préparer d'avance
```

### BrainSwarmScheduler — Constantes

```gdscript
enum Priority { CRITICAL, HIGH, NORMAL, LOW }
enum Tier { SINGLE, DUAL, SLIM, FULL }

const TIMEOUT_SMALL_MS := 30000    # 2B
const TIMEOUT_LARGE_MS := 60000    # 4B
const TIMEOUT_DEFAULT_MS := 45000  # 0.8B
```

### BrainProcessManager — Constantes

```gdscript
const BASE_PORT := 8081
const MAX_BRAINS := 4
const HEALTH_CHECK_INTERVAL_MS := 10000    # 10s
const HEALTH_TIMEOUT_MS := 3000            # 3s par check
const STARTUP_TIMEOUT_MS := 30000          # 30s wait au démarrage
const RESTART_COOLDOWN_MS := 5000          # 5s avant re-try
const MAX_RESTART_ATTEMPTS := 3
```

---

## 9. API Publique

### BrainSwarmConfig

```gdscript
# Detection
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int
    # Retourne Profile.QUAD/TRIPLE/DUAL/SINGLE_PLUS/SINGLE/NANO
    # Cherche du plus gros au plus petit

# Accessors
static func get_profile(profile_id: int) -> Dictionary
    # {name, mode, brains, total_ram_mb, min_threads, min_ram_mb, prefetch_depth}

static func get_profile_name(profile_id: int) -> String
    # "Quad (4B + 2B + 0.8B Judge + 0.8B Worker)"

static func get_peak_ram_mb(profile_id: int) -> int
    # 6600 pour QUAD, 1800 pour SINGLE

# Brain queries
static func get_brain_config(profile_id: int, role: String) -> Dictionary
    # Retourne brain spec pour un rôle

static func get_model_for_role(profile_id: int, role: String) -> String
    # "qwen3.5:4b" pour narrator en DUAL
    # Fallback intelligent si rôle absent

static func get_required_models(profile_id: int) -> Array
    # ["qwen3.5:4b", "qwen3.5:2b"] pour DUAL
    # Utile pour ollama pull préalable

# Modes
static func is_time_sharing(profile_id: int) -> bool
    # true pour SINGLE+

static func get_prefetch_depth(profile_id: int) -> int
    # 0, 1, 2, ou 3
```

### BrainSwarmScheduler

```gdscript
# Registration
func register_brain(llm: Object, role: String, model_size: String = "small") -> int
    # Retourne slot index
    # model_size: "small" (30s timeout) ou "large" (60s timeout)

# Allocation
func request_brain(preferred_role: String = "", priority: int = Priority.NORMAL) -> Object
    # Retourne Object si disponible, null sinon
    # Affinity: exact role > compatible roles > any idle > preempt LOW
    # Marque immédiatement comme busy

func release_brain(llm: Object) -> void
    # Remet en idle, accumule stats

# Gestion d'erreur
func mark_brain_dead(llm: Object) -> void
    # Marque crash/unresponsive, trigger dégradation

func mark_brain_alive(llm: Object) -> void
    # Remet en service après restart

# Interrogation
func get_idle_count() -> int
func get_alive_count() -> int
func get_total_count() -> int
func get_current_tier() -> int
func get_tier_name() -> String
func get_stats() -> Array
    # [{index, role, busy, alive, model_size, tasks_completed, total_busy_ms}]

# Maintenance
func check_timeouts() -> Array
    # Libère brains figés, retourne list d'Objects released

func clear() -> void
    # Reset complet
```

### BrainProcessManager

```gdscript
# Setup
func configure(server_path: String, brain_defs: Array) -> void
    # Avant start_all()
    # brain_defs: [{role, model, threads, n_ctx}]

# Lifecycle
func start_all() -> int
    # Retourne count de brains lancés
    # Lance les OS.create_process()

func wait_for_healthy(timeout_ms: int = 30000) -> int
    # Block jusqu'à timeout
    # Retourne count de brains "ok"
    # Utilisé au startup

func poll_health() -> Array
    # Non-blocking, retourne [] si pas temps de checker
    # Sinon retourne [healthy0, healthy1, ...]

func stop_all() -> void
    # Cleanup à _exit_tree
    # OS.kill() tout, reset state

# Interrogation
func get_brain_count() -> int
    # Config'd count
func get_running_count() -> int
    # Count avec PID > 0 et OS.is_process_running()

func get_brain_info() -> Array
    # [{index, role, port, pid, running, restarts}]

# Backend creation
func create_backend(brain_index: int) -> Object
    # Retourne BitNetBackend connecté au port 8081+index
    # À appeler après wait_for_healthy()
```

---

## 10. Intégration dans merlin_ai.gd

Le orchestrateur principal utilise les 3 composants ainsi:

### Init Sequence

```gdscript
func _ready():
    _load_brain_config()      # Lit config sauvegardée
    _load_prompts()
    _load_prompt_templates()
    # Models loaded on-demand via start_warmup()

func start_warmup():
    _init_local_models()

func _init_local_models():
    # 1. Detect profil
    var available_ram = OS.get_static_memory_usage() / (1024*1024)
    var cpu_threads = OS.get_processor_count()
    _active_profile_id = BrainSwarmConfig.detect_profile(available_ram, cpu_threads)

    # 2. Créer scheduler
    _swarm_scheduler = BrainSwarmScheduler.new()

    # 3. Obtenir la config profil
    var profile = BrainSwarmConfig.get_profile(_active_profile_id)
    _is_time_sharing = BrainSwarmConfig.is_time_sharing(_active_profile_id)

    # 4. Si BitNet (fallback):
    if active_backend == BackendType.BITNET:
        _brain_process_manager = BrainProcessManager.new()
        _brain_process_manager.configure(
            "C:/path/to/llama-server.exe",
            profile.brains
        )
        var started = _brain_process_manager.start_all()
        var healthy = _brain_process_manager.wait_for_healthy()

        # Créer les backends
        for i in range(profile.brains.size()):
            var backend = _brain_process_manager.create_backend(i)
            _swarm_scheduler.register_brain(backend, profile.brains[i].role)

    # 5. Sinon, utiliser Ollama
    else:
        narrator_llm = OllamaBackend.new()
        narrator_llm.initialize(BrainSwarmConfig.MODEL_QWEN35_4B)
        _swarm_scheduler.register_brain(narrator_llm, "narrator", "large")

        if profile.brains.size() > 1:
            gamemaster_llm = OllamaBackend.new()
            gamemaster_llm.initialize(BrainSwarmConfig.MODEL_QWEN35_2B)
            _swarm_scheduler.register_brain(gamemaster_llm, "gamemaster", "small")

    is_ready = true
    ready_changed.emit(true)
```

### Usage Standard

```gdscript
# SINGLE/SINGLE+ mode (séquentiel)
func generate_narrative(prompt: String) -> String:
    var brain = _swarm_scheduler.request_brain("narrator", Priority.CRITICAL)
    if brain == null:
        return fallback_text()

    var result = await brain.generate(prompt)
    _swarm_scheduler.release_brain(brain)
    return result

# DUAL+ mode (parallèle)
func generate_card_parallel(prompt_narrator: String, prompt_gm: String):
    var narrator = _swarm_scheduler.request_brain("narrator", Priority.CRITICAL)
    var gm = _swarm_scheduler.request_brain("gamemaster", Priority.CRITICAL)

    if narrator == null or gm == null:
        return fallback_card()

    # Lancer en parallèle
    var narrator_task = narrator.generate(prompt_narrator)
    var gm_task = gm.generate(prompt_gm)

    var text = await narrator_task
    var effects = await gm_task

    _swarm_scheduler.release_brain(narrator)
    _swarm_scheduler.release_brain(gm)

    return {text, effects}
```

### Health Loop

```gdscript
func _process(delta):
    if _brain_process_manager != null:
        var health_results = _brain_process_manager.poll_health()
        if health_results.size() > 0:
            for i in range(health_results.size()):
                if not health_results[i]:
                    print("Brain %d unhealthy" % i)
                    # Scheduler automatiquement fera dégradation via mark_brain_dead()

    # Check timeouts scheduler
    if _swarm_scheduler != null:
        var released = _swarm_scheduler.check_timeouts()
        if released.size() > 0:
            print("Released %d timed-out brains" % released.size())
```

---

## 11. Migration SINGLE → SINGLE+/DUAL

Évolution sans refonte du code game:

### Cas 1: Desktop → DUAL

**Avant** (SINGLE, 2B séquentiel):
```
Narrator (2B) 6s → GM (2B swap) 3s → Total 9s
```

**Après** (DUAL, 4B+2B parallèle):
```
Narrator (4B) || GM (2B) → Total 6s (parallèle)
```

**Code change: MINIMAL**

```gdscript
# Aucun changement gameplay!
var narrator = request_brain("narrator")
var gm = request_brain("gamemaster")

# Si DUAL: retourne 2 objets différents
# Si SINGLE: retourne 2x le même objet (pas de parallélisme)
# Scheduler gère la compatibilité automatiquement
```

### Cas 2: Laptop 7GB → SINGLE+

**Avant** (fallback à SINGLE 2B):
```
Narrator (2B) 6s → GM (2B swap) 3s → Total 9s
```

**Après** (SINGLE+ 4B/2B time-sharing):
```
Narrator (4B) 6s → [Swap 2s] → GM (2B) 2s → Total 10s
Meilleure qualité Narrator, même latence acceptable
```

**Code change: NONE**

Simplement installer 4B sur le disque, Ollama la détecte et SINGLE+ profile activé automatiquement.

---

## 12. Dégradation Gracieuse

Exemple de crash en QUAD → SINGLE:

```
T=0    QUAD: 4 brains all healthy
       ├─ Narrator (4B)
       ├─ GM (2B)
       ├─ Judge (0.8B)
       └─ Worker (0.8B)

T=5    Worker crash!
       _brain_process_manager.poll_health() detects
       → mark_brain_dead(worker)
       → _swarm_scheduler._update_tier()
       → tier = SLIM (3/4 alive)

T=10   Judge also crash
       → tier = DUAL (2/4 alive)
       → Gameplay continues, un peu plus lent

T=15   Narrator crash (oh no!)
       → tier = SINGLE (1/4 alive)
       → Chutes drastiques, fallback à static card si GM crash aussi

T=20   GM still alive, keep going with SINGLE mode
```

**Utilisateur ne voit:** Aucune interruption, seulement ralentissement progressif.

---

## 13. Diagnostics et Monitoring

### Brain Stats

```gdscript
var stats = _swarm_scheduler.get_stats()
# [{
#     "index": 0,
#     "role": "narrator",
#     "busy": false,
#     "alive": true,
#     "model_size": "large",
#     "tasks_completed": 42,
#     "total_busy_ms": 240000
# }]

var idle = _swarm_scheduler.get_idle_count()
var tier = _swarm_scheduler.get_tier_name()  # "DUAL"
```

### Brain Processes Info

```gdscript
var brain_info = _brain_process_manager.get_brain_info()
# [{
#     "index": 0,
#     "role": "narrator",
#     "port": 8081,
#     "pid": 1234,
#     "running": true,
#     "restarts": 0
# }]
```

### Debug Log

```
[MerlinAI] Profile auto-detected: Dual (4B Narrator + 2B GM parallel)
           (RAM=14456MB, CPU=8 cores)
[MerlinAI] Brain config loaded from settings: 2 cerveaux
[BrainProcessManager] Brain 1 (narrator) started: PID 5678, port 8081, threads=4, n_ctx=8192
[BrainProcessManager] Brain 2 (gamemaster) started: PID 5679, port 8082, threads=2, n_ctx=4096
[BrainProcessManager] Brain 1 (narrator) healthy on port 8081
[BrainProcessManager] Brain 2 (gamemaster) healthy on port 8082
[Scheduler] Brain 'gamemaster' timed out after 30000ms — force release
[BrainProcessManager] Brain 2 (gamemaster) crashed (PID 5679)
[BrainProcessManager] Brain 2: restart attempt 1/3
[Scheduler] Current tier: SLIM (2 alive)
```

---

## 14. Performance Benchmarks

### Latence par Profil (Qwen 3.5 family)

| Profil | p50 | p95 | Notes |
|--------|-----|-----|-------|
| NANO | 12s | 15s | Acceptable pour mobile |
| SINGLE | 10s | 12s | Bon pour laptop |
| SINGLE+ | 12-15s | 18s | Time-sharing penalty ~2-3s |
| DUAL | 8s | 10s | Desktop standard |
| TRIPLE | 7s | 9s | High-perf |
| QUAD | 7s | 9s | Serveur, overhead juge ~0.5s |

### Throughput (tokens/s)

Tous profils: **~17.8 tok/s** (Qwen 3.5-4B baseline)
- Narrator: 180 tok/réponse
- GM: 80 tok/réponse
- Total: 260 tok ≈ 15s en SINGLE/SINGLE+, ≈ 8s parallèle

---

## Résumé

| Aspect | Détail |
|--------|--------|
| **Composants Core** | BrainSwarmConfig, BrainSwarmScheduler, BrainProcessManager |
| **Profils** | 6 (NANO → QUAD), auto-detection RAM/CPU |
| **Modes** | Resident (1 modèle), Time-sharing (swap 2), Parallèle (2-4 simultanés) |
| **Routage** | Role-based + affinity fallback + preemption |
| **Resilience** | Health polling, restart auto (max 3), dégradation tier |
| **Latence** | 7-15s selon profil/charge |
| **Integration** | Transparent dans merlin_ai.gd, zéro changement gameplay |

