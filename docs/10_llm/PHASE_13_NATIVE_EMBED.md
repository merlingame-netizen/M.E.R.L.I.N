# Phase 13 — Native embed() in merlin_llm.dll

> Path A from the 2026-05-18 user choice ("A + B + C"). B (drop runtime HTTP)
> and C (compose from already-retrieved hits) shipped in Sprint 12.4(B+C) on
> the same day. This doc plans the native embed call so we eliminate the
> Ollama runtime dependency entirely while keeping the dynamic-query flexibility.
>
> **Status** : design + scaffolding only. No C++ code written yet.

---

## 1. Why this matters

User directive (verbatim, 2026-05-18 review of cards_rag HTTP) :
> *"pourquoi du http request ?"*

And the original Phase 4 directive (2026-05-17) :
> *"Je ne veux pas nécessité à mes joueurs de DL Ollama, tout doit être géré
> en natif depuis le jeu !"*

Sprint 12.4(B+C) shipped a **functional metadata-only retrieval** that needs
no embeddings at runtime, but the embedding signal still has value for :
- Personalised `route_vec` from arbitrary text seeds (not just stored cards)
- Cross-biome semantic search (Brocéliande pool → Morbihan / Karnac)
- Adaptive trait emergence sidecar `behavioral_summary` enrichment
- Future MERLIN Omniscient context retrieval

The metadata-only path covers ~90% of the gameplay loop. The 10% gap is
where Phase 13 lives.

---

## 2. State today

| Component | What it can do | What it can't |
|---|---|---|
| `merlin_llm.dll` (commit C38) | `load_model`, `generate_async` | No `embed()` surface |
| `gemma4-e2b-q4_k_m.gguf` (shipped) | Causal generation | Not an embedding model |
| `nomic-embed-text` (Ollama) | Embed text → 768-dim vector | Runs in Ollama daemon, HTTP dep |
| `cards_rag.gd` Sprint 12.4(B) | metadata kNN + compose_from_hits | Cannot embed arbitrary new text |

Native LLM smoke (TestNativeProbe, 2026-05-18) :
```
[NATIVE-PROBE] MerlinLLM class registered          OK
[NATIVE-PROBE] GGUF present (3106736256 bytes)     OK
[NATIVE-PROBE] load_model OK in 3239ms             OK
[NATIVE-PROBE] generate_async returned, entering poll loop  (gen running)
```

The C++ binding is sound; we just need a second model + a second method.

---

## 3. Target API

```gdscript
# In addons/merlin_ai/cards_rag.gd:
var embedder := ClassDB.instantiate("MerlinEmbed")
embedder.load_model("res://addons/merlin_llm/models/nomic-embed-text-Q4_K_M.gguf")
var vec: PackedFloat32Array = embedder.embed("Une marche dans la brume druidique")
# vec.size() == 768, L2-normalised
```

Either as a sibling class `MerlinEmbed` or as a method on `MerlinLLM` if the
underlying `llama_context` is shared (it can be — llama.cpp's pooling-type
parameter switches a context between causal and embedding modes).

**Decision: separate class `MerlinEmbed`.** Reasons :
- The embedding model is a different GGUF (137 MB vs 1.6 GB).
- Pooling type, context size, and batch shape differ.
- Lifecycle is independent (load once at boot, never unload).
- Easier to lazy-load or skip entirely when shipping a Lite build.

---

## 4. Implementation plan (5 tasks)

### Task 13.1 — Acquire / convert the embed GGUF

- `nomic-embed-text` is available as GGUF on Hugging Face.
- Target file : `addons/merlin_llm/models/nomic-embed-text-Q4_K_M.gguf`
  (~137 MB, gitignored — added to `.gitignore` next to the gemma4 GGUF).
- Download script : `addons/merlin_llm/models/download_nomic_embed.sh` /
  `.ps1` (mirror the existing `download_gemma4_gguf.*` pattern).
- The Sprint 10 Python embeddings used `nomic-embed-text` via Ollama, so
  re-using the same model preserves vector compatibility with
  `data/ai/cards_index_broceliande.json` (no re-embed required).

### Task 13.2 — C++ MerlinEmbed class

`native/src/merlin_embed.h` + `.cpp` :

```cpp
class MerlinEmbed : public RefCounted {
    GDCLASS(MerlinEmbed, RefCounted)
public:
    MerlinEmbed();
    ~MerlinEmbed();
    Error load_model(const String& gguf_path);
    PackedFloat32Array embed(const String& text);
    int get_dim() const { return _dim; }
    bool is_loaded() const { return _model != nullptr; }

protected:
    static void _bind_methods();

private:
    llama_model* _model = nullptr;
    llama_context* _ctx = nullptr;
    int _dim = 0;
    bool _normalize_output = true;
};
```

Init pattern (using llama.cpp embedding API) :
```cpp
llama_context_params cparams = llama_context_default_params();
cparams.embeddings = true;
cparams.pooling_type = LLAMA_POOLING_TYPE_MEAN;
cparams.n_ctx = 512;
cparams.n_batch = 512;
_ctx = llama_init_from_model(_model, cparams);
```

Embed flow :
```cpp
// 1. Tokenise the input text
std::vector<llama_token> tokens = llama_tokenize(_model, text_utf8, true);
// 2. Decode (single batch, MEAN pooling collapses N tokens to 1 vector)
llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
for (size_t i = 0; i < tokens.size(); ++i)
    llama_batch_add(batch, tokens[i], i, {0}, i == tokens.size() - 1);
llama_decode(_ctx, batch);
// 3. Pull the pooled embedding for sequence 0
const float* emb = llama_get_embeddings_seq(_ctx, 0);
int n_embd = llama_n_embd(_model);
// 4. L2-normalize + return as PackedFloat32Array
PackedFloat32Array out;
out.resize(n_embd);
double sq_sum = 0.0;
for (int i = 0; i < n_embd; ++i) { out[i] = emb[i]; sq_sum += emb[i] * emb[i]; }
double norm = std::sqrt(sq_sum);
if (norm > 0.0) for (int i = 0; i < n_embd; ++i) out[i] /= norm;
return out;
```

Add to `register_types.cpp` :
```cpp
ClassDB::register_class<MerlinEmbed>();
```

### Task 13.3 — Build + smoke

Same Windows MSVC bypass we already documented in
`~/.claude/skills/learned/windows-msvc-build-bypass-vswhere-group-policy.md`.

Verification smoke (mirroring TestNativeProbe pattern) :
```gdscript
# scripts/test/test_native_embed_probe.gd
var emb := ClassDB.instantiate("MerlinEmbed")
emb.load_model("res://addons/merlin_llm/models/nomic-embed-text-Q4_K_M.gguf")
var t0 := Time.get_ticks_msec()
var vec: PackedFloat32Array = emb.embed("druide marche dans la brume")
var ms := Time.get_ticks_msec() - t0
# Expected : vec.size() == 768, L2-normalised, ms < 500ms on dev box
```

### Task 13.4 — Wire into cards_rag.gd

Add a 4th method to `cards_rag.gd` :
```gdscript
func embed_query_native(text: String) -> PackedFloat32Array:
    if _native_embedder == null:
        _native_embedder = ClassDB.instantiate("MerlinEmbed")
        if _native_embedder == null:
            push_warning("MerlinEmbed unavailable - falling back to compose_route_vec_from_hits")
            return PackedFloat32Array()
        _native_embedder.load_model(EMBED_MODEL_GGUF_PATH)
    return _native_embedder.embed(text)
```

The existing HTTPRequest path stays as a fallback only when
`MERLIN_USE_HTTP_EMBED=1`. The default becomes : try native first,
then metadata-only retrieval.

### Task 13.5 — Compatibility check + ship

- The 768-dim output must be **bitwise-identical** to the Ollama-produced
  vectors in `cards_index_broceliande.json` (within float tolerance).
  If not, re-run `tools/embed_reference_cards.py` against the native path.
- Update `.gitignore` for the 137 MB GGUF.
- Bump bible v3.6 → v3.7 with new §32 "Native embed surface".

---

## 5. Effort estimate

| Task | Estimate |
|---|---|
| 13.1 GGUF download script + .gitignore | 0.5 h |
| 13.2 C++ MerlinEmbed class | 4 h |
| 13.3 Build + smoke | 2 h |
| 13.4 Wire into cards_rag.gd + test | 1 h |
| 13.5 Compatibility check + bible | 1 h |
| **Total** | **~1 dev-day** |

Plus the ship cost : 137 MB GGUF added to the player install (already
shipping the 1.6 GB gemma4, so +9% is acceptable).

---

## 6. Failure modes + fallback strategy

| If task 13.x fails | Fallback |
|---|---|
| GGUF download blocked | Use Ollama via HTTP (existing path, env-gated) |
| C++ build fails | Sprint 12.4(B+C) metadata-only retrieval is already shipped |
| Vector incompatible with stored index | Re-embed `cards_index_broceliande.json` (~3 min) |
| Native embed >500 ms / query | Cache + LRU at the `cards_rag.gd` layer |

The B+C paths ship today and cover the demo. A is a quality-of-life upgrade
that removes the last Ollama dependency. The game does not block on it.

---

## 7. Acceptance criteria

When Phase 13 ships :

- [ ] `ClassDB.class_exists("MerlinEmbed") == true` after .dll load
- [ ] `MerlinEmbed.load_model()` returns OK on the 137 MB nomic GGUF
- [ ] `MerlinEmbed.embed("test")` returns a 768-dim L2-normalised vector
- [ ] kNN result equality (top-3 by uid) between native embed and the
      pre-stored Ollama embed for a 20-query smoke sample
- [ ] `cards_rag.gd.embed_query_native()` returns within 500 ms on dev box
- [ ] Game can run a full demo with `OLLAMA_HOST=invalid:0` and produce
      identical narrative coherence as today

---

*Author : Sprint 12.4(B+C) commit + Phase 13 design — 2026-05-18*
*Builds on : EMBEDDING_FIRST_ARCHITECTURE.md, PHASE_11_NARRATIVE_DEPTH_PLAN.md,
PHASE_12_RPG_BRANCHING_PLAN.md, the existing native MerlinLLM C++ stack.*
