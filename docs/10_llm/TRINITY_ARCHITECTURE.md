# Architecture LLM Qwen2.5-3B-Instruct — M.E.R.L.I.N.

> MAJ: 2026-02-09 — Phase 30: GBNF Grammar + Two-Stage Fallback + Q5_K_M Default

---

## 1. Vue d'ensemble

```
Gameplay (TriadeGameController)
  │
  ├→ show_thinking()  ← Celtic triskelion animation pendant LLM
  │
  └→ MerlinStore.TRIADE_GET_CARD
       ├→ MerlinOmniscient (MOS + 5 registres + RAG v2.0 + Prefetch)
       │    ├→ _try_use_prefetch()   ← carte pre-generee? (0ms si hit)
       │    ├→ _sync_mos_to_rag()    ← registries → RAG world state
       │    ├→ RAG.get_prioritized_context()  ← token budget 180
       │    ├→ _apply_guardrails()   ← language + repetition + length
       │    └→ RAG.log_card_played() ← journal structured
       ├→ MerlinLlmAdapter.generate_card() → carte LLM brute validee
       │    └→ _extract_json: 4 strategies (parse → fix → repair → regex)
       └→ MerlinCardSystem.get_next_triade_card() → fallback pool
  │
  ├→ hide_thinking() + display_card()
  └→ prefetch_next_card()  ← pre-genere carte N+1 en arriere-plan

MerlinAI (autoload)
  ├→ Single LLM:   Qwen2.5-3B-Instruct Q4_K_M (router == executor, 1 instance)
  ├→ RAGManager v2.0 (journal + cross-run + world state + token budget)
  └→ Fallback chain: Q4_K_M → Q5_K_M → Q8_0
```

---

## 2. Modeles disponibles

| Quantization | Fichier | Taille | Usage | JSON Valid | Vitesse |
|--------------|---------|--------|-------|------------|---------|
| Q4_K_M | `Qwen2.5-3B-Instruct-Preview-Q4_K_M.gguf` | ~3.6 GB | Fallback leger | 20% | Rapide |
| **Q5_K_M** | `Qwen2.5-3B-Instruct-Preview-Q5_K_M.gguf` | ~4.1 GB | **DEFAULT** (Phase 30) | **60%** | Moyen |
| Q8_0 | `Qwen2.5-3B-Instruct-Preview-Q8_0.gguf` | ~6.1 GB | Fallback qualite max | 40% | Lent |

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
| Modele Q4_K_M | ~3.6 GB | Poids du modele en memoire |
| KV Cache (2048 tokens) | ~512 MB | Proportionnel a n_ctx |
| Godot Engine | ~200-400 MB | Scenes, textures, audio |
| **TOTAL** | **~4.5 GB** | Target: machines 8 GB RAM |

### 4.2 Strategies d'optimisation memoire

1. **Modele unique (router == executor)**: Un seul MerlinLLM en RAM.
   Gain: ~3.6 GB par rapport a l'architecture dual-model. (Phase 28 fix)

2. **n_ctx minimal**: 2048 tokens au lieu de 4096.
   Gain: ~256 MB de KV cache en moins.

3. **Quantization Q4_K_M**: Le plus leger qui preserve la qualite.
   Gain: ~2.5 GB vs Q8_0.

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
CONTEXT_BUDGET = 180 tokens (~720 chars)
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

Si echec → fallback_pool.get_fallback_card()
```

---

## 6. Architecture de fallback + Prefetch (Phase 29)

```
Requete carte
  │
  ├─[0] Prefetch Check (NOUVEAU Phase 29)
  │     Carte pre-generee disponible + contexte hash match?
  │     Si oui → retour immediat (~0ms) ← supprime latence
  │
  ├─[1] MerlinOmniscient (MOS)
  │     Cache + registres → carte contextualisee
  │     Si cache hit → retour immediat (~0ms)
  │
  ├─[2] MerlinLlmAdapter.generate_card()
  │     Qwen2.5-3B-Instruct → JSON → 4 strategies d'extraction
  │     Si JSON valide + schema OK → retour (~1-3s)
  │
  └─[3] MerlinCardSystem.get_next_triade_card()
        Pool de cartes pre-ecrites → fallback garanti
        Si LLM echoue → carte d'urgence (~0ms)

Apres affichage carte N:
  └→ prefetch_next_card() ← generation carte N+1 en arriere-plan
```

**Taux de succes vise**: 40%+ prefetch, 40%+ LLM, 15% MOS cache, 5% fallback pool.

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

## 7. Fichiers cles

| Fichier | Role |
|---------|------|
| `addons/merlin_ai/merlin_ai.gd` | Autoload LLM, init modeles, routing |
| `addons/merlin_ai/rag_manager.gd` | RAG v2.0: journal, cross-run, token budget |
| `addons/merlin_ai/merlin_omniscient.gd` | Orchestrateur MOS + RAG + guardrails + prefetch |
| `scripts/merlin/merlin_llm_adapter.gd` | Contract carte TRIADE, prompts, validation, 4-stage JSON repair, two-stage fallback |
| `data/ai/triade_card.gbnf` | Grammaire GBNF pour decodage contraint des cartes TRIADE |
| `native/src/merlin_llm.h/.cpp` | GDExtension C++ — wrapper llama.cpp avec GBNF grammar support |
| `tools/benchmark_llm.mjs` | Benchmark standalone (Node.js) — test hors-Godot |
| `scripts/merlin/merlin_store.gd` | Redux-like state, dispatch TRIADE |
| `scripts/merlin/merlin_card_system.gd` | Pool cartes, fallback TRIADE |
| `scripts/merlin/merlin_constants.gd` | Constantes gameplay |
| `scripts/ui/triade_game_ui.gd` | UI cartes + thinking animation triskelion |
| `scripts/ui/triade_game_controller.gd` | Store-UI bridge + animation masking + prefetch |
| `scripts/LLMManager.gd` | Manager global legacy |
| `scripts/TestTriadeLLMBenchmark.gd` | Benchmark 5 tests |

---

## 8. Migration Qwen → Trinity (historique)

**Date**: 2026-02-09
**Raison**: Consolidation sur un modele optimise et prometteur.

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
- `addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf` (~2 GB)

### Fichiers NON touches (archives historiques)
- `archive/scripts/TestMerlinGBA.gd`
- `archive/scripts/test_merlin_gba.gd`
- `archive/colab/`, `archive/scenes/`
- `docs/old/`, `docs/root/QWEN_3B_MODELS.md`

---

## 9. Prochaines optimisations possibles

1. ~~**Speculative decoding**: Pre-generer des tokens avec un draft model ultra-leger~~ → Remplace par prefetch (Phase 29)
2. ~~**GBNF Grammar**: Decodage contraint JSON au niveau token~~ → Implemente Phase 30 (necessite recompilation)
3. ~~**Two-stage generation**: Texte libre + JSON wrapper programmatique~~ → Implemente Phase 30
4. ~~**Q5_K_M par defaut**: Meilleur ratio qualite/latence au benchmark~~ → Applique Phase 30
5. **Recompiler GDExtension**: Activer le grammar sampler avec CMake + Visual Studio
6. **LoRA fine-tuning**: 200-500 exemples de cartes TRIADE pour specialiser Qwen2.5-3B-Instruct
7. **Prompt caching**: Garder le KV cache du system prompt entre les appels
8. **Context pruning**: Reduire n_ctx a 1024 si le prompt total < 500 tokens (gain ~256 MB)
9. **Batch generation**: Generer 3 cartes en parallele pour le pre-fetching
10. **Hybrid local/API**: Fallback vers API cloud sur mobile (bande passante vs latence)

---

*Genere par l'equipe projet M.E.R.L.I.N. — Claude Code + 23 agents specialises*
