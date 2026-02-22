# LLM Pipeline — Reference Run (v3)

> Source: MERLIN_LLM_Pipeline_Test_Report_v3_REWRITE_actions_tree_v3.docx
> Aligned with: merlin_llm_adapter.gd, merlin_ai.gd, merlin_omniscient.gd

---

## 1. Pipeline Overview (6 Phases)

| Phase | Name | Description |
|-------|------|-------------|
| 1 | **Rich Narrative** | LLM generates scene text in French, atmospheric prose |
| 2 | **Consequential Choices** | 3 options with distinct verbs, each shifts Aspects |
| 3 | **Story Continuity** | Narrative references previous choices, biome, season |
| 4 | **Adaptive Verbs** | Action verbs match context (biome, NPC, event) |
| 5 | **Anti-Leakage** | Strip meta-text, prompt echo, self-referential AI output |
| 6 | **Prologue/Epilogue** | LLM-generated intro and outro per run |

---

## 2. Model Configuration

| Parameter | Narrator Brain | Game Master Brain |
|-----------|---------------|-------------------|
| Model | Qwen 2.5-1.5B | Qwen 2.5-1.5B |
| Temperature | 0.75 | 0.15 |
| top_p | 0.92 | 0.80 |
| max_tokens | 150 | 80 |
| top_k | 40 | 15 |
| repetition_penalty | 1.35 | 1.0 |

**Backend**: Ollama HTTP API (/api/generate, raw=true)
**Chat template**: ChatML
**Context window**: 4096 tokens

---

## 3. Prompt Structure

System prompt includes: Merlin persona, biome, season, RAG context (400 tokens budget).
User prompt includes: scene description + A)/B)/C) choices with verbs.

**RAG v2.0**: Token budget 400, biome cache, priority-based context injection.

---

## 4. Anti-Leakage Guardrails (v2 — reordered pipeline)

**Pipeline order**: Cleanup BEFORE label extraction (prevents prompt echo captured as labels).

### Step 1: Meta-word filter (40+ patterns)
Strips lines containing:
- Game mechanics: "choisissez", "cliquez", "le joueur", "options possibles"
- Prompt echo: "format obligatoire", "verbe a l'infinitif", "style obligatoire", "format:", "style:", "complement", "infinitif", "majuscules", "exactement 3", "4-6 phrases", "choix a/b/c)"
- AI self-reference: "programmation", "je m'excuse", "en tant qu'ia", "bug", "code source"

### Step 1.5: Inline leak fragments
Regex strips any bracketed content: `[...]{2+ chars}` (catches all `[verbe...]`, `[Vie:...]`, etc.)

### Step 1.6: Self-referential sentences
Full-line strip for: "je m'excuse", "je suis desole", "en tant qu'intelligence artificielle"

### Step 2+: Label extraction, markdown cleanup, length bounds, French check

### Prompt Simplification Rules
- System prompt MUST be concise (3-4 lines max for format instructions)
- NEVER include literal examples "A) VERBE — description" (Qwen 1.5B echoes them verbatim)
- NEVER use "STYLE OBLIGATOIRE", "FORMAT", "EXEMPLE" headers
- Use: "Termine par 3 choix commencant chacun par un verbe d'action."

---

## 5. Prologue / Epilogue

- **Prologue**: Generated at run start by TransitionBiome scene
- **Epilogue**: Generated at run end (3 victoires, 12 chutes, 1 secrete)
- Both use Narrator Brain parameters
- Stored in user://intro_{biome}.txt

---

## 6. KPIs

| Metric | Threshold | Current |
|--------|-----------|---------|
| p50 latency (warm) | < 10s | ~7s |
| p90 latency (warm) | < 15s | ~11s |
| Fallback rate | 0% | 0% |
| Text variety (Jaccard) | < 0.7 | OK |
| Throughput | > 10 tok/s | 17.8 tok/s |
| French output | > 80% | 80% |

---

## 7. Zero Fallback Policy

- No static cards served to player
- All cards come from LLM (Ollama or MerlinLLM C++)
- Failure path: retry backoff -> "Merlin medite..." overlay -> hub return
- Generic verb labels if LLM omits: ["Observer", "Canaliser", "Braver"]

---

## 8. Audio Looping

- **MusicManager** (autoload): `_player_intro` + `_player_loop`
- Both `finished` signals connected: intro chains to loop, loop restarts itself
- `loop_mode = AudioStreamWAV.LOOP_FORWARD` set at stream load time (not just at play)
- Biome music: crossfade out current -> play new intro -> chain to new loop

---

## 9. Input Accessibility — Mouse + Keyboard

All 12 interactive minigames support both mouse (buttons) and keyboard:

| Mini-jeu | Souris | Clavier |
|----------|--------|---------|
| De du Destin | Bouton STOP | ESPACE / ENTREE |
| Pile ou Face | PILE / FACE | Q / E |
| Rune Cachee | Grille 4x4 | 1-9 |
| Roue de Fortune | Bouton STOP | ESPACE / ENTREE |
| Lame du Druide | Symboles 1-4 | 1-4 |
| Pierre/Feuille/Racine | 3 boutons | Q / W / E |
| Bluff du Druide | HAUT / BAS | W-UP / S-DOWN |
| Joute Verbale | 3 actions | A / S / D |
| Enigme d'Ogham | 3 choix | 1 / 2 / 3 |
| Tir a l'Arc | Bouton TIR | ESPACE / ENTREE |
| Noeud Celtique | 3 chemins | 1 / 2 / 3 |
| Oeil du Corbeau | Grille | 1-9 |
| Negociation | Slider + CONFIRMER | GAUCHE-DROITE + ENTREE |
| Pas du Renard | Esquive G/D | GAUCHE-Q / DROITE-E |

Base class: `MiniGameBase._unhandled_input()` -> `_on_key_pressed(keycode)` (virtual).
