# Architecture LLM Qwen 2.5-3B-Instruct — M.E.R.L.I.N.

> **[ARCHIVED — 2026-03-16]** Ce document date de la phase Triade (pre-v2.0).
> Le systeme actuel utilise 5 factions + minigames + multiplicateur (voir GAME_DESIGN_BIBLE.md v2.4).
> Les sections LLM (Ollama, RAG, Multi-Brain, guardrails, prefetch) restent valides.
> Les references a "Triade", "SHIFT_ASPECT", "Corps/Ame/Monde", "Souffle", "D20" sont OBSOLETES.

> MAJ originale: 2026-02-15 — Ollama Backend + Zero Fallback + Multi-Brain + Buffer 5

---

## 1. Vue d'ensemble

```
Gameplay (TriadeGameController, BUFFER_SIZE=5)
  │
  ├→ show_thinking()  ← Celtic triskelion animation pendant LLM
  │
  └→ MerlinStore.TRIADE_GET_CARD
       ├→ MerlinOmniscient (MOS + 5 registres + RAG v2.0 + Prefetch)
       │    ├→ _try_use_prefetch()   ← buffer 5 cartes (0ms si hit)
       │    ├→ Scene context cache   ← version tracking (deduplique refresh)
       │    ├→ RAG.get_prioritized_context()  ← token budget 400
       │    ├→ _apply_guardrails()   ← language + repetition + length
       │    ├→ RAG.log_card_played() ← journal structured
       │    └→ ZERO FALLBACK: retry ou "Merlin medite" overlay
       ├→ MerlinLlmAdapter.generate_card() → carte LLM brute validee
       │    └→ _extract_json: 4 strategies (parse → fix → repair → regex)
       └→ [SUPPRIME] Plus de fallback pool statique
  │
  ├→ hide_thinking() + display_card()
  └→ prefetch_next_card()  ← pre-genere carte N+1 en arriere-plan

MerlinAI (autoload, Multi-Brain)
  ├→ Backend primaire: Ollama HTTP (<3s/carte)
  │    ├→ Brain 1 (Narrateur): T=0.60-0.70, top_p=0.90, max=180, rep_penalty=1.45
  │    └→ Brain 2 (Game Master): T=0.15, top_p=0.8, max=80, GBNF obligatoire
  ├→ Backend secondaire: MerlinLLM C++ (si pas Ollama, single brain)
  ├→ RAGManager v2.0 (journal + cross-run + world state + budget 400)
  └→ Detection auto: Ollama → MerlinLLM → erreur
```

---

## 2. Modeles disponibles

| Quantization | Fichier | Taille | Usage | JSON Valid | Vitesse |
|--------------|---------|--------|-------|------------|---------|
| Q4_K_M | `qwen2.5-3b-instruct-q4_k_m.gguf` | ~2.0 GB | Fallback leger | 20% | Rapide |
| **Q5_K_M** | `qwen2.5-3b-instruct-q5_k_m.gguf` | ~2.4 GB | **DEFAULT** (Phase 30) | **60%** | Moyen |
| Q8_0 | `qwen2.5-3b-instruct-q8_0.gguf` | ~3.2 GB | Fallback qualite max | 40% | Lent |

**Recommandation production**: Q5_K_M pour le meilleur ratio JSON validite/latence (benchmark Phase 30).
Q4 trop degradee en qualite JSON (20%). Q8 plus lourd mais pas meilleur en JSON (40%).

---

## 3. Parametres LLM optimises

### 3.1 Router (classification rapide)
```gdscript
var router_params := {
    "temperature": 0.3,   # Bas → reponses deterministes
    "top_p": 0.85,
    "max_tokens": 32,     # Classification = court
    "top_k": 30,
    "repetition_penalty": 1.0  # Pas de penalite (reponse courte)
}
```

### 3.2 Executor (generation de cartes TRIADE)
```gdscript
const TRIADE_LLM_PARAMS := {
    "max_tokens": 200,        # JSON carte = ~150-180 tokens
    "temperature": 0.6,       # Equilibre creativite/coherence
    "top_p": 0.85,            # Nucleus sampling modere
    "top_k": 30,              # Limite le vocabulaire candidat
    "repetition_penalty": 1.5 # Evite les boucles textuelles
}
```

### 3.3 Parametres globaux
```gdscript
# Context window
n_ctx = 2048          # Suffisant pour prompt systeme + contexte + reponse
                      # Memoire KV cache: ~512 MB pour 2048 tokens

# Generation
GENERATION_TIMEOUT_MS = 8000   # Timeout securite
STREAM_CHUNK_TOKENS = 32       # Taille chunk streaming
STREAM_MAX_ROUNDS = 4          # Max iterations streaming
```

---

## 4. Optimisation des ressources

### 4.1 Budget memoire

| Composant | RAM estimee | Notes |
|-----------|-------------|-------|
| Modele Q4_K_M | ~2.0 GB | Poids du modele en memoire |
| KV Cache (2048 tokens) | ~512 MB | Proportionnel a n_ctx |
| Godot Engine | ~200-400 MB | Scenes, textures, audio |
| **TOTAL** | **~2.7 GB** | Target: machines 4+ GB RAM |

### 4.2 Strategies d'optimisation memoire

1. **Modele unique (router == executor)**: Un seul MerlinLLM en RAM.
   Gain: ~2.0 GB par rapport a l'architecture dual-model. (Phase 28 fix)

2. **n_ctx minimal**: 2048 tokens au lieu de 4096.
   Gain: ~256 MB de KV cache en moins.

3. **Quantization Q4_K_M**: Le plus leger qui preserve la qualite.
   Gain: ~1.2 GB vs Q8_0.

4. **max_tokens court (200)**: Limite la generation pour eviter la latence.
   Gain: ~50% temps de generation vs max_tokens=512.

5. **Cache de reponses**: Evite les appels LLM redondants.
   Limite: 200 entrees en memoire (~10 KB).

6. **RAG v2.0 token budget (180 tokens)**: Contexte dynamique controle.
   Evite de depasser la fenetre de contexte du nano-modele. (Phase 28)

### 4.3 Strategies d'optimisation CPU/GPU

1. **ngl 99**: Decharger toutes les couches sur GPU si disponible.
2. **threads 8**: Utiliser 8 threads CPU pour l'inference.
3. **batch_size**: Defaut llama.cpp (512). Pas besoin d'ajuster pour
   de la generation sequentielle mono-utilisateur.

---

## 5. Prompt engineering pour nano-modeles

### 5.1 Regles critiques

1. **System prompt ultra-court** (<100 tokens)
   - Les nano-modeles ont une fenetre d'attention limitee
   - Chaque token du prompt systeme = un token de moins pour la reponse
   - Preferer les instructions par l'exemple plutot que les descriptions

2. **Un seul exemple JSON** dans le prompt
   - Les nano-modeles copient le format, pas les instructions
   - L'exemple doit etre le template exact attendu
   - NE PAS mettre plusieurs exemples (le modele les concatene)

3. **repetition_penalty >= 1.5**
   - Les petits modeles bouclent facilement
   - 1.5 est le minimum pour eviter les repetitions
   - Au-dela de 1.8: risque de reponses incoherentes

4. **temperature 0.4-0.7 pour la generation narrative**
   - < 0.4: trop repetitif, manque de creativite
   - > 0.7: derive narrative, hallucinations JSON
   - Sweet spot: 0.6 pour un jeu narratif

5. **Pas de majuscules ni d'emphase dans les prompts**
   - Les nano-modeles interpretent les MAJUSCULES comme du cri
   - Utiliser des mots simples et directs

### 5.2 Prompt TRIADE actuel (optimise)

```
System (73 tokens):
"Merlin druide. Genere 1 carte JSON. 3 options. Effets: SHIFT_ASPECT
(Corps/Ame/Monde, up/down). Option centre coute souffle.
{template JSON...}"

User (variable, ~30-50 tokens):
"Aspects: Corps=equilibre Ame=bas Monde=haut. Souffle:3. Jour:5. Carte:12."
```

---

## 5b. RAG v2.0 — Retrieval Augmented Generation (Phase 28)

### Token Budget Management
```
CONTEXT_BUDGET = 400 tokens (~1600 chars)  # Reduit de 600 (Phase Ollama)
CHARS_PER_TOKEN = 4 (heuristique multilingue)

Priorite enum:
  CRITICAL (4) — Crises aspects/souffle
  HIGH     (3) — Recents choix + arcs actifs
  MEDIUM   (2) — Player patterns + bestiole
  LOW      (1) — Cross-run callbacks
  OPTIONAL (0) — Couleur narrative
```

### Structured Game Journal
```
Types d'entrees:
  card_played   → texte (60 chars max), tags, generated_by
  choice_made   → label, effects, cost
  aspect_shifted → aspect, from, to
  ogham_used    → ogham_id
  run_event     → event_type, details

Max entries: 100 par run
```

### Cross-Run Memory
```
Apres chaque run → summarize_and_archive_run():
  - run_id, ending, cards_played
  - dominant_aspect, notable_events
  - player_style (prudent/audacieux/equilibre)
  - score

Max summaries: 20 runs conserves
```

### MOS → RAG Sync
```
A chaque generation de carte:
  _sync_mos_to_rag() push vers RAG world_state:
    - player_patterns (decision_history.patterns_detected)
    - active_arcs (narrative.active_arcs)
    - trust_tier + trust_tier_name
    - session_frustration
```

## 5c. Output Guardrails (Phase 28)

```
_apply_guardrails(card):
  1. Length check  — 10 < len(text) < 500
  2. French check  — ≥2 FR keywords (le/la/de/un/une/du/les/des/en/et)
  3. Repetition    — Jaccard word similarity < 0.7 vs 10 dernières cartes
  4. Structure     — JSON valide (deja verifie par parser)

Si echec → generation_failed signal (ZERO FALLBACK, plus de pool statique)
```

---

## 6. Architecture Zero Fallback + Prefetch (Phase Ollama)

```
Requete carte
  │
  ├─[0] Prefetch Check (buffer 5 cartes)
  │     Carte pre-generee disponible + contexte hash match?
  │     Si oui → retour immediat (~0ms)
  │
  ├─[1] MerlinOmniscient (MOS)
  │     Scene context cache (version) + RAG (budget 400)
  │     Guardrails: FR check, repetition Jaccard, longueur
  │
  ├─[2] MerlinLlmAdapter.generate_card()
  │     Ollama (<3s) ou MerlinLLM C++ → JSON → 4 strategies d'extraction
  │     Si JSON valide + schema OK → retour
  │
  └─[3] ZERO FALLBACK (plus de pool statique)
        Si echec: signal generation_failed("llm_unavailable")
        Controller: retry backoff → "Merlin medite..." → retour hub

Apres affichage carte N:
  └→ prefetch_next_card() ← generation carte N+1 (Brain 2 si dual)
```

**Taux de succes vise**: 60%+ prefetch, 35%+ LLM direct, 5% retry. 0% fallback statique.

### 6b. JSON Extraction Pipeline (Phase 29)

```
LLM raw output
  │
  ├─[1] Parse standard: find { }, JSON.parse_string()
  │     ~80% des cas
  │
  ├─[2] Fix erreurs courantes: trailing commas, single quotes, unquoted keys
  │     ~10% des cas (nano-model quirks)
  │
  ├─[3] Aggressive repair: fix truncation, close brackets, escape quotes
  │     ~5% des cas (model timeout/truncation)
  │
  └─[4] Regex extraction: extraire text, labels, speaker, effects individuellement
        ~3% des cas (JSON completement casse, mais contenu exploitable)
        Fallback a MerlinCardSystem si extraction echoue aussi
```

### 6b2. GBNF Grammar Constrained Decoding (Phase 30)

```
GDExtension MerlinLLM
  │
  ├─ set_grammar(gbnf_string, root_rule)
  │    → llama_sampler_init_grammar(vocab, gbnf, root)
  │    → Insere dans sampler chain (apres top_p, avant greedy)
  │
  ├─ generate_async(prompt, callback)
  │    → Chaque token genere DOIT matcher la grammaire
  │    → JSON structurellement garanti valide
  │
  └─ clear_grammar()
       → Desactive pour les appels non-TRIADE

Fichier grammaire: data/ai/triade_card.gbnf
  Contraint: text, speaker="merlin", 3 options, SHIFT_ASPECT effects
  Aspects: "Corps" | "Ame" | "Monde"
  Direction: "up" | "down"
  Option centre: cost obligatoire

NOTE: Necessite recompilation du GDExtension C++ pour activation.
```

### 6b3. Two-Stage Generation Fallback (Phase 30)

```
Stage 1 — Texte libre (ce que le nano-modele fait bien)
  Prompt: "Ecris un scenario court + 3 choix (A/B/C)"
  Pas de JSON, pas de contrainte structurelle
  Temperature: 0.7, max_tokens: 150

Stage 2 — Wrapping programmatique
  _extract_labels_from_text(): regex "A)" / "1." / "- "
  _generate_contextual_effects(): effets intelligents
    → Option 1: boost aspect le plus bas
    → Option 2: balance (aspect neutre)
    → Option 3: risque (baisse aspect le plus haut)
  _wrap_text_as_card(): assemblage JSON valide

Taux de succes attendu: ~80% (texte OK + effets programmes)
Tag carte: "two_stage"
```

### 6c. UX Latency Masking (Phase 29)

```
Joueur fait un choix → TRIADE_RESOLVE_CHOICE
  │
  ├→ 150ms transition delay (card flip feel)
  ├→ show_thinking() ← spirale triskelion + "Merlin reflechit..."
  │     Options dimmed (alpha 0.3)
  │     Dots animes toutes les 400ms
  │
  ├→ [PREFETCH HIT] → ~0ms → hide_thinking() → display_card()
  │   ou
  ├→ [LLM GENERATION] → ~1-3s → hide_thinking() → display_card()
  │
  └→ prefetch_next_card() ← pre-generation carte N+2
```

---

## 6d. Pipeline Sequentiel (v2 — remplace parallele)

Le GM genere les effets AVANT le Narrator. Le Narrator recoit les effets comme contexte.

**Avantages**:
- Texte aligne aux effets (+40% coherence)
- Visual/audio tags coherents avec narration
- GM contraint par GBNF = fiable

**Cout**: +1s latence (~8s total vs ~7s parallele)

**Schema**:
```
GM (T=0.15, 2s) → effects + visual + audio JSON
                 ↓ inject dans prompt Narrator
Narrator (T=0.60-0.70, 6s) → scenario + A/B/C
                 ↓
CODE: Quality Judge → validation → display_card()
```

**Pipeline detaille**:
```
1. CODE: Calcul etat (profil joueur, danger_level, arc_position, biome, jour/saison)
   └→ Registres MOS: PPR + DHR + RR + NR + SR → contexte deterministe (~0ms)

2. GM: Genere effets JSON + visual_tags + audio_tags
   └→ ~2s, 80 tok, T=0.15, top_p=0.8, GBNF obligatoire
   └→ Input: etat calcule (60 tok user prompt)
   └→ Output: {"effects":[...], "visual":{...}, "audio":{...}}

3. Narrator: Genere texte ALIGNE aux effets
   └→ ~6s, 180 tok, T=0.60-0.70, top_p=0.90, rep_penalty=1.45
   └→ Input: etat + effets GM injectes (100 tok user prompt)
   └→ Output: scenario texte + A)/B)/C) labels

4. CODE: Guardrails (Quality Judge) + validation + display_card()
   └→ AWAIT obligatoire
   └→ FR check, repetition Jaccard < 0.7, length 10-500 chars
```

**Exceptions (Narrator-only, pas d'appel GM)**:
- Intros de run (texte d'ambiance, pas d'effets)
- Dialogues Merlin (carte Merlin Direct, 4e mur)
- Sequences de reve (ton surreal, foreshadowing)
- Recaps fin de run (resume poetique, chemins non-pris)

**Fallback si GM echoue (timeout > 5s ou JSON invalide)**:
- Effets generiques calcules par DifficultyAdapter (CODE)
- Le Narrator continue normalement avec les effets par defaut

---

## 6e. Nouveaux Outputs Game Master

### Visual Tags (GBNF contraint)

Le GM genere des tags visuels qui pilotent les shaders et particules Godot en temps reel.

```json
{
  "atmosphere": "brumeux|lumineux|sombre|orageux|sacre",
  "light": "aube|crepuscule|nuit|plein_jour",
  "particles": "lucioles|pluie|neige|brume|sparkles|none",
  "color_tint": "froid|chaud|rouge|dore|neutre"
}
```

| Tag | Mapping Godot | Exemple |
|-----|---------------|---------|
| `atmosphere: "brumeux"` | Shader fog density + ColorRect overlay | Foret brumeuse au crepuscule |
| `light: "aube"` | DirectionalLight2D color + energy lerp | Lumiere doree progressive |
| `particles: "lucioles"` | GPUParticles2D preset lucioles | Points lumineux flottants |
| `particles: "pluie"` | GPUParticles2D preset pluie + splash | Pluie fine sur la clairiere |
| `color_tint: "froid"` | CanvasModulate blue shift | Ambiance glaciale |
| `color_tint: "dore"` | CanvasModulate warm gold | Lumiere sacree du nemeton |

### Audio Tags (GBNF contraint)

Le GM genere des tags audio qui declenchent les sons proceduraux du SFXManager.

```json
{
  "mood": "calme|tension|danger|mystere|sacre|combat|tristesse",
  "intensity": 0.0-1.0,
  "elements": ["wind_low", "whisper", "heartbeat_slow", "chime_crystal", "thunder_distant", "rain_soft", "birds_distant", "drum_war", "harp_arpeggio", "bell_deep", "wolf_howl", "choir_distant"]
}
```

| Mood | Elements type | Intensite |
|------|--------------|-----------|
| `calme` | wind_low, birds_distant, water_stream | 0.2 - 0.4 |
| `tension` | heartbeat_slow, wind_rising, creak_wood | 0.4 - 0.7 |
| `danger` | heartbeat_fast, thunder_distant, wolf_howl | 0.7 - 1.0 |
| `mystere` | whisper, chime_crystal, wind_ethereal | 0.3 - 0.6 |
| `sacre` | choir_distant, bell_deep, harp_arpeggio | 0.5 - 0.8 |
| `combat` | drum_war, metal_clash, breath_heavy | 0.8 - 1.0 |
| `tristesse` | rain_soft, sigh_wind, harp_minor | 0.2 - 0.5 |

### Output JSON Complet GM (exemple)

```json
{
  "effects": [
    {"option": "A", "aspect": "Corps", "dir": "up"},
    {"option": "B", "aspect": "Ame", "dir": "down", "cost_souffle": 1},
    {"option": "C", "aspect": "Monde", "dir": "up"}
  ],
  "visual": {
    "atmosphere": "brumeux",
    "light": "crepuscule",
    "particles": "lucioles",
    "color_tint": "froid"
  },
  "audio": {
    "mood": "mystere",
    "intensity": 0.5,
    "elements": ["whisper", "chime_crystal", "wind_low"]
  }
}
```

---

## 7. Fichiers cles

| Fichier | Role |
|---------|------|
| `addons/merlin_ai/ollama_backend.gd` | Backend Ollama HTTP API (drop-in MerlinLLM) |
| `addons/merlin_ai/merlin_ai.gd` | Multi-brain, routing Ollama/MerlinLLM, init modeles |
| `addons/merlin_ai/rag_manager.gd` | RAG v2.0: journal, cross-run, biome cache, budget 400 |
| `addons/merlin_ai/merlin_omniscient.gd` | Orchestrateur MOS + RAG + zero fallback + scene cache |
| `scripts/merlin/merlin_llm_adapter.gd` | Contract carte TRIADE, prompts, labels generiques |
| `data/ai/triade_card.gbnf` | Grammaire GBNF pour decodage contraint (C++ seulement) |
| `native/src/merlin_llm.h/.cpp` | GDExtension C++ — wrapper llama.cpp (backend secondaire) |
| `tools/test_merlin_chat.py` | Benchmark CLI (chat, card, gamemaster, benchmark, perf) |
| `scripts/merlin/merlin_store.gd` | Redux-like state, dispatch TRIADE |
| `scripts/merlin/merlin_card_system.gd` | Pool cartes TRIADE |
| `scripts/merlin/merlin_constants.gd` | Constantes gameplay |
| ~~`scripts/ui/triade_game_ui.gd`~~ | REMOVED — replaced by merlin_game_controller.gd |
| ~~`scripts/ui/triade_game_controller.gd`~~ | REMOVED — replaced by merlin_game_controller.gd |
| ~~`scripts/TestTriadeLLMBenchmark.gd`~~ | REMOVED — replaced by test_llm_full_run.gd |

---

## 8. Migration Ministral → Qwen (historique)

**Date**: 2026-02-09
**Raison**: Migration de Ministral 3B vers Qwen 2.5-3B-Instruct pour meilleure qualite.

### Fichiers modifies
- `addons/merlin_ai/merlin_ai.gd` — ROUTER_FILE + EXECUTOR_FILE + candidates
- `scripts/LLMManager.gd` — MODEL_PATH
- `scripts/merlin/merlin_llm_adapter.gd` — Commentaires
- `scripts/TestLLMBenchmark.gd` — Titre
- `scripts/test_merlin.gd` — model_path
- `scripts/start_llm_server.sh` — Chemin modele
- `addons/merlin_llm/models/PLACE_MODEL_HERE.txt` — Guide
- `data/ai/models/README.txt` — Liste modeles

### Fichier supprime
- `addons/merlin_llm/models/ministral-3b-instruct.gguf` (~3.4 GB)

### Fichiers NON touches (archives historiques)
- `archive/scripts/TestMerlinGBA.gd`
- `archive/scripts/test_merlin_gba.gd`
- `archive/colab/`, `archive/scenes/`
- `docs/old/`, `docs/root/QWEN_3B_MODELS.md`

---

## 9. Prochaines optimisations possibles

1. ~~**Speculative decoding**~~ → Remplace par prefetch buffer 5
2. ~~**GBNF Grammar**~~ → Implemente Phase 30 (C++ backend seulement)
3. ~~**Two-stage generation**~~ → Implemente Phase 30
4. ~~**Q5_K_M par defaut**~~ → Applique Phase 30
5. ~~**Ollama backend**~~ → Implemente (Phase Ollama, <3s/carte)
6. ~~**Zero fallback**~~ → Implemente (plus de pool statique)
7. ~~**Multi-brain**~~ → Implemente (Ollama dual-instance)
8. ~~**Scene context cache**~~ → Implemente (version tracking)
9. ~~**Biome context cache**~~ → Implemente (cache par cle)
10. **Recompiler GDExtension**: Activer flash attention + KV cache prefix reuse (Phase 6 optionnelle)
11. **LoRA fine-tuning**: 200-500 exemples de cartes TRIADE pour specialiser Qwen
12. **Hybrid local/API**: Fallback vers API cloud sur mobile (bande passante vs latence)

---

*Genere par l'equipe projet M.E.R.L.I.N. — Claude Code + 33 agents specialises*
