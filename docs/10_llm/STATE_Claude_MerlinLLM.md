# Etat des lieux pour Claude (Merlin LLM / Godot)

> **[ARCHIVED — 2026-03-16]** Ce document date de 2026-02-09 (phase Triade pre-v2.0).
> Le systeme actuel utilise Multi-Brain Qwen 3.5 via Ollama (voir docs/LLM_ARCHITECTURE.md).
> Les references a "Triade", "TestTriadeLLMBenchmark", "SHIFT_ASPECT" sont OBSOLETES.

Purpose
- Current state snapshot for Merlin LLM integration in Godot.

Scope
- Paths, status, known issues, and next actions.

Derniere MAJ: 2026-02-09 (ARCHIVE)

Ce document resume l'etat actuel du projet, les scripts en place, les chemins exacts, et les points restants pour stabiliser/optimiser la reactivite et la coherence du LLM dans Godot.

---

## 1) Contexte general

- Moteur: Godot 4.5.1
- Objectif: LLM local integre (pas de serveur) via GDExtension `MerlinLLM`.
- Modele unique: **Qwen 2.5-3B-Instruct** (Multi-Brain: 1-4 instances)
- Quantization: Q4_K_M (2.0 GB)
- UI de test: `TestTriadeLLMBenchmark.tscn` (5 benchmarks), `TestLLMSceneUltimate.tscn`

Etat actuel:
- Migration Ministral -> Qwen 2.5-3B-Instruct complete (Phase 31)
- Pipeline TRIADE fonctionnel (3 aspects, 3 options par carte)
- Fallback automatique Q4 -> Q5 -> Q8
- Streaming disponible via MerlinAI autoload

---

## 2) Chemins clefs (exactitudes)

### 2.1 Addons LLM
- `addons/merlin_llm/merlin_llm.gdextension`
- `addons/merlin_llm/bin/` (DLL/so)
- `addons/merlin_llm/models/`
- `qwen2.5-3b-instruct-q4_k_m.gguf` (2.0 GB, default)

### 2.2 Addons AI (GDScript)
Chemin: `addons/merlin_ai/`
- `merlin_ai.gd` (singleton/autoload, coeur LLM)
- `fast_route.gd` (routing deterministe, patterns)
- `rag_manager.gd` (memoire simple + recherche keywords)
- `action_validator.gd`
- `game_state_sync.gd`
- `llm_client.gd` (HTTP -> pas utilise actuellement)

### 2.3 Persona / prompts
Chemin: `addons/merlin_llm/Comportement/`
- `MERLIN_Character_Document.md`
- `prompts_merlin.json`

### 2.4 Scenes / Scripts principaux
Scenes:
- `scenes/MenuPrincipal.tscn`
- `scenes/TestMerlinGBA.tscn`
- `scenes/TestJDRMerlin.tscn`
- `scenes/TestMerlin.tscn`, `TestMerlinAI.tscn`, `TestAventure.tscn`, `TestCombat.tscn`, `TestAntreMerlin.tscn`

Scripts:
- `scripts/MenuPrincipalAnimated.gd` (menu)
- `scripts/TestMerlinGBA.gd` (UI + chat)
- `scripts/TestJDRMerlin.gd` (JDR)
- `scripts/TestMerlinAI.gd` (ancien test)
- `scripts/merlin_ai.gd` n'existe pas (seul le singleton `addons/merlin_ai/merlin_ai.gd`)

Docs spec:
- `docs/old/10_llm/FOC_MerlinLLM.md` (archive)
- `docs/SPEC_OptimisationLLM_MERLIN.md`

---

## 3) Architecture technique (etat actuel)

### 3.1 `addons/merlin_ai/merlin_ai.gd`
Fonctions principales:
- `_init_local_models()` : charge les GGUF via `MerlinLLM` (GDExtension).
- `generate_with_system(...)` : requete executeur classique (non streaming).
- `generate_with_system_stream(...)` : pseudo-stream en plusieurs appels (chunks).
- `FastRoute` : classifie rapidement sans LLM si possible.
- Cache reponses (hash prompts).
- Sessions multiples (session_id + channel).

Limitations:
- Pas de streaming token-precis (GDExtension non expose).
- `generate_with_system_stream` est une simulation en multi-calls (latence cumul).
- RAG = keywords uniquement (pas d'embeddings).

### 3.2 `scripts/TestMerlinGBA.gd`
UI chat + panneau LLM:
- Envoi + affichage typewriter.
- Indicateur de chargement (points).
- Diagnostic complet (models, paths, statut).
- Persona chargee via `prompts_merlin.json`.
- Reponses nettoyees (ASCII only, suppression tokens, anti-anglais).
- Mode "complexe" -> liste numerotee.
- Streaming par chunks (si method dispo).

Problemes residuels:
- Persona drift: sortie de role, anglais, reponses incoherentes.
- Lenteur vs Colab (TTFT > 5s selon question).
- Reponses parfois vides (retry fait 1x).

---

## 4) Ce qui a ete fait (resume rapide)

1) Chargement GGUF local via MerlinLLM (pas de serveur).
2) Routing rapide hybride (FastRoute + LLM).
3) UI Test MerlinGBA fonctionnelle (envoi/affichage/diagnostic).
4) Persona definie (MERLIN_Character_Document + prompts_merlin.json).
5) Pseudo-streaming + typewriter pour perception reactivite.
6) Session context + cache.

---

## 5) Problemes connus (a corriger)

1) **Persona instable**
   - Le modele bascule parfois en anglais.
   - Repond "je suis Carter", "butler" etc.
   - Probable: prompt system mal applique, few-shot trop court, historique pollue.

2) **TTFT / latence**
   - Plus lent que Colab.
   - Probable: GDExtension bloque, pas de KV cache reutilise.

3) **Streaming non natif**
   - Actuellement simule par multi-calls.
   - Peut fragmenter le contexte.

4) **RAG minimal**
   - Pas d'embeddings, seulement keywords.
   - Pas de priorisation par contexte de jeu.

5) **Log / Debug**
   - Le backlog montre les logs, mais manque de details profilage (temps par call, tokens/sec).

---

## 6) Ce qu’il reste a faire (priorite)

### Phase 4 (SPEC_OptimisationLLM_MERLIN)
1) **Verrouillage Persona**
   - Revoir prompt system avec contraintes fortes.
   - Injecter "persona checksum" (ex: repete un identifiant de style).
   - Ajouter un anti-english enforce plus dur.

2) **Optimisation temps reponse**
   - Forcer le 3B unique (router + executor) pour simplifier.
   - Raccourcir contexte / appliquer resume auto (condensation).
   - Re-utilisation KV cache si possible (extension).

3) **Streaming natif**
   - Verifier si MerlinLLM expose une API streaming.
   - Sinon, etendre la GDExtension (C++).

4) **RAG avance**
   - Embeddings local (miniLM) + index (Chroma/FAISS local).
   - Segmenter les memoires (journal, choix, lore).

5) **Instrumentation**
   - Mesure du temps par requete: TTFT, tokens/s, total.
   - Afficher dans UI debug.

---

## 7) Instructions pour Claude (ce qu il doit faire)

### A. Lancer un audit rapide
1. Ouvrir `addons/merlin_ai/merlin_ai.gd`:
   - Verifier quel modele est utilise (executor_candidates).
   - Verifier si `generate_with_system_stream` est utilise dans TestMerlinGBA.

2. Ouvrir `scripts/TestMerlinGBA.gd`:
   - Verifier streaming, typewriter, nettoyage.
   - Verifier que `prompts_merlin.json` est charge.

3. Ouvrir `addons/merlin_llm/Comportement/prompts_merlin.json`
   - Verifier la structure JSON, few-shot, system prompt.

### B. Stabiliser la Persona
1. Ajouter des regles strictes dans `executor_system`.
2. Ajouter few-shot plus courts et clairs.
3. Filtrer anglais + mots bannis ("Human:", "Assistant:").

### C. Optimiser la vitesse
1. Garder un seul modele 3B (router + executor).
2. Adapter max_tokens selon demande (simple = 64, complexe = 192).
3. Ajouter resume historique quand contexte > N.

### D. Metriques
1. Ajouter mesure `Time.get_ticks_msec()` autour des appels LLM.
2. Logguer TTFT et total.
3. Afficher dans le panel debug.

---

## 8) Tests rapides a effectuer (recommandes)

1. Question simple:
   - "salut"
   - Attendu: une phrase FR, ton Merlin, < 120 caracteres.

2. Question complexe:
   - "explique les regles du jeu"
   - Attendu: "Bien sur, mon ami, les voici:" + 3-6 points.

3. Anti-anglais:
   - "summarize this"
   - Attendu: correction FR ("Je parle en francais...").

4. Temps:
   - TTFT < 2s, total < 5s.

---

## 9) Notes techniques

- `MerlinLLM` est une GDExtension (pas de source C++ disponible ici).
- Donc streaming natif n'est pas garanti.
- L’optimisation devra se faire par:
  - modeles plus petits
  - prompts courts
  - resumes de contexte

---

Si besoin, creer un rapport d execution automatique avec logs: 
- appeler `MerlinAI.get_log_text()` + stats routing
- dump dans `user://ai/logs/merlin_runtime.log`

---

## 10) Extraits de scripts clefs (concis)

### 10.1 `addons/merlin_ai/merlin_ai.gd` (points importants)
```gdscript
func _init_local_models() -> void:
    # charge router + executor via MerlinLLM (GDExtension)
    router_llm = ClassDB.instantiate("MerlinLLM")
    router_llm.load_model(_to_fs_path(router_file_used))
    executor_llm = ClassDB.instantiate("MerlinLLM")
    executor_llm.load_model(_to_fs_path(executor_file_used))

func generate_with_system(system_prompt, user_input, params_override={}):
    var prompt = template.format({"system": system_prompt, "input": user_input})
    return await _run_llm(executor_llm, prompt, params)

func generate_with_system_stream(system_prompt, user_input, params_override={}, on_chunk=Callable()):
    # pseudo-stream: plusieurs appels courts + on_chunk
    while remaining > 0 and rounds < STREAM_MAX_ROUNDS:
        params.max_tokens = min(STREAM_CHUNK_TOKENS, remaining)
        var result = await _run_llm(executor_llm, prompt, params)
        on_chunk.call(text, false)
```

### 10.2 `scripts/TestMerlinGBA.gd` (points importants)
```gdscript
const HISTORY_LIMIT := 6
const STREAMING_MODE := true

func _send_message(text):
    _start_loading()
    var prompt = _build_prompt(text)
    if STREAMING_MODE and merlin_ai.has_method("generate_with_system_stream"):
        answer = await _stream_response(system_prompt, prompt, params, complex)
    else:
        answer = _clean_response(_extract_text(result), complex)

func _clean_response(text, allow_multi=false):
    # supprime tokens, force ASCII, coupe anglais, limite longueur
```

---

## 11) Plan migration streaming natif (si possible)

**But**: obtenir du token-par-token sans multi-calls.

1. **Verifier GDExtension**
   - Chercher si MerlinLLM expose:
     - `generate_stream_async(...)`
     - `on_token` callback
     - un signal "token" / "chunk"
2. **Si non expose**
   - Modifier C++ (dans addon merlin_llm) pour:
     - lancer llama.cpp en mode streaming
     - exposer une API GDExtension:
       - `generate_stream(prompt, params, on_token)`
       - `poll_stream()` + `get_stream_chunk()`
3. **Integrer dans Godot**
   - Remplacer `generate_with_system_stream` par:
     - une boucle `while streaming` + chunks
   - Supprimer pseudo-stream multi-calls
4. **Perf**
   - Mesurer TTFT
   - Montrer tokens/s dans le panel debug

### 11.2 Garde-fous "persona" en streaming natif
Objectif: eviter que Merlin sorte du personnage pendant le streaming (token par token).

**Principe**: chaque chunk/token passe par un filtre + validateur. Si violation, on stoppe le flux et on remplace par une reponse safe.

Garde-fous proposes (ordre d'application):
1) **Filtre tokens interdits**
   - Supprimer/stopper si chunk contient:
     - balises (`<|im_start|>`, `<|im_end|>`, `<|eot_id|>`)
     - roles (`Human:`, `Assistant:`)
2) **Filtre langue**
   - Detecter anglais (mots clefs + ratio).
   - Si anglais > seuil: STOP + fallback FR.
3) **Filtre persona**
   - Exiger au moins un marqueur de style (ex: "Voyageur", "mon ami", "Broceliande").
   - Si absent apres N tokens -> forcer une correction "Je suis Merlin..."
4) **Filtre longueur / structure**
   - Interdire paragraphs longs.
   - Couper au 1er point si mode "court".
5) **Filtre coherence**
   - Si la phrase part sur un autre sujet (keywords bannis), stop + fallback.

Pseudo-implementation (chunk guard):
```gdscript
func on_token(token):
    if contains_forbidden(token): return STOP_STREAM
    if looks_english(token): return STOP_STREAM
    if persona_broken() and token_count > 20: return STOP_STREAM
    return CONTINUE
```

Fallback safe (si violation):
```
"Je suis Merlin, voyageur. Pose ta question en francais."
```

Note: si streaming natif impossible, appliquer ces filtres au niveau "chunk" dans la pseudo-stream (multi-calls).

---

## 12) Tableau comparatif modele (recommandations)

| Modele | Vitesse | Qualite | Usage recommande | Params conseilles |
|---|---|---|---|---|
| Qwen 3B | ++ | ++ | Mode unique (router + executor) | T=0.35-0.5, top_p=0.75-0.9, max=160-240 |

Conseil:
- **Par defaut**: 3B unique pour simplifier et stabiliser.

---

## 13) Liste d'actions rapides pour stabiliser

1. Forcer langue FR (hard check):
   - Si reponse contient anglais -> regenere avec T+0.1 et "FR only".
2. Ajouter un "persona checksum":
   - Exiger une phrase courte signature (ex: "Voyageur," au debut).
3. Ajouter resume historique automatique:
   - Quand contexte > N, compresser en 2 lignes.
