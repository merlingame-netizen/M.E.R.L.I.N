# Phase 12 — RPG depth + Branching + Adaptive trait emergence

> **Source-of-decisions**: AskUserQuestion review session 2026-05-18 (8 questions, 2 rounds).
> Builds on Phase 10 (embedding-first) and Phase 11 (DnD-without-combat).
>
> **Headliner innovation** (user phrasing, verbatim): *"le LLM détecte le
> comportement du joueur et lui débloque des traits personnalisés"* —
> see §4 Adaptive Trait Emergence.

---

## 1. Decisions cadré (from the review)

| Axe | Choix retenu | Implication |
|---|---|---|
| Perfs / async | **Hybride** — loading screen ~30s + lookahead per-beat | Pas de mur en milieu de run; loading initial diégétique |
| Branching narratif | **Tree dur 3 routes + LLM pivots** | 3 macro-pools (ordre/chaos/liminal) + 5 LLM beats |
| Trigger fork | **Faction dominante après Beat 4** | Émergent, récompense la cohérence |
| LLM pivots | **Beat 8 + Beat 16 + carte fork (Beat 5/11) + outro + mid-run Beat 9** | ~5 LLM calls/run en lookahead |
| RPG depth | **Classless + affinités** (statu quo) | Identité fluide via choix, pas de classe à choisir |
| Progression | **XP cross-run, niveaux 1-30** | Boucle long-terme forte |
| Unlocks XP | **Oghams T2/T3 + souffle/essence max + traits passifs + slots mémoire** | Tout est sur la table — gros design |
| DC scaling | **DC fixe + débloquages = plus d'options** | Modèle Slay-the-Spire — pas de power-creep |
| Persistance | **Single JSON profil** étendu | Pas de SQLite, garde la portabilité |
| Balance method | **Monte-Carlo 1000 sim runs** | Tooling automatisable |
| Loading aesthetic | **Tirage de runes (mini-cérémonie)** | 3 oghams qui tournent et se révèlent |

---

## 2. Architecture cible (vue de 30 000 pieds)

```
                   ┌──────────────────────────────────┐
                   │   PROFIL JOUEUR (JSON unique)     │
                   │   character_level, xp_total,      │
                   │   traits, memory_slots,           │
                   │   behavioral_summary, anam        │
                   └──────────────────────────────────┘
                                  │
                ┌─────────────────┼─────────────────┐
                │                 │                 │
        ┌───────▼──────┐  ┌───────▼──────┐  ┌───────▼──────┐
        │  HUB 2D       │  │  RUN ENGINE   │  │  BEHAVIORAL  │
        │  (XP UI,      │  │  (v731 +      │  │  ANALYZER    │
        │  unlocks,     │  │  tree fork +  │  │  (LLM,       │
        │  trait gallery│  │  LLM pivots)  │  │  off-run)    │
        └──────────────┘  └──────────────┘  └──────────────┘
                                  │                 │
                                  │                 ▼
                                  │     ┌──────────────────────┐
                                  │     │  ADAPTIVE TRAIT      │
                                  │     │  EMERGENCE  (§4)     │
                                  │     │  output: trait_id +  │
                                  │     │  prose + effect spec │
                                  │     └──────────────────────┘
                                  ▼
                       ┌──────────────────────────┐
                       │  RUN ARTIFACTS (JSON)     │
                       │  feeds back into profile  │
                       └──────────────────────────┘
```

---

## 3. Tree dur — 3 macro-routes (Sprint 12.2)

### 3.1 Trigger
Après Beat 4, calculer `faction_dominante = argmax(faction_rep)`. Mapper :
- `druides | anciens` → **Route Ordre** (sagesse, tradition, structure)
- `korrigans | ankou` → **Route Chaos** (subversion, jeu, vertige)
- `niamh` → **Route Liminal** (seuil, transformation, mystère)
- Égalité ou < 5 pts d'écart → **Route Neutre** (Brocéliande générique, comme v7.7.31 actuel)

### 3.2 Pool extension
Chaque route reçoit son propre sous-pool de **~80 cartes spécifiques** (Beat 5 à 16) + le pool générique commun. Total : 90 (générique) + 3×80 (routes) = **330 canonical buckets** à enrichir via le batch existant.

### 3.3 Beat-pool routing
À partir de Beat 5, `retrieve_skeleton()` injecte un filtre `route_tag` dans le kNN :
```python
hits = rag.knn(route_vec, k=8, filters={"route_tag": route, ...}, ...)
```

### 3.4 5 LLM pivots
Chaque pivot reçoit un prompt cascadé qui inclut tout l'historique pertinent :

| Pivot | Quand | Input du prompt |
|---|---|---|
| Beat 5 (carte fork) | T=après skeleton + dominante | Faction dominante + 4 beats précédents + route choisie |
| Beat 8 (MERLIN_DIRECT) | T=après Beat 7 résolu | 7 beats + tags acquis + faction dominante |
| Beat 9 (breathing) | T=après Beat 8 | Recap 8 beats + emotional arc + dominante |
| Beat 11 (sous-fork) | T=après Beat 10 | Tags depuis Beat 5 + DC results jusqu'ici |
| Beat 16 (climax) | T=après Beat 15 | Full run history + promesses non-tenues + anchor |
| Outro | T=après Beat 16 | Run history + final state + LLM-generated climax echo |

Tous en lookahead **2 beats avant** dans une `ThreadPoolExecutor(max_workers=2)` (réutilise `tools/beat_chain_stitcher.py` pattern).

---

## 4. Adaptive Trait Emergence (§4 — l'innovation Phase 12)

### 4.1 Idée
Plutôt qu'un catalogue de 20 traits design-time, **un agent LLM observe le profil joueur cross-run et propose des traits sur-mesure** quand le pattern devient lisible (≥3 runs avec cohérence).

### 4.2 Pipeline (off-run, async)

```
End of run N
    │
    ▼
behavioral_summary = aggregate(last_3_runs)
    {
      faction_pref:        {ankou: 0.45, niamh: 0.30, ...},
      verb_pref:           {refuser: 0.30, observer: 0.25, ...},
      dc_outcome_profile:  {success: 0.40, partial: 0.50, failure: 0.10},
      pole_signature:      {Liminal: 0.55, Chaos: 0.30, Ordre: 0.15},
      anchor_callbacks:    3,   # ratio of beats where anchor honored
      risk_appetite:       0.65 # avg DC threshold of chosen options
    }
    │
    ▼
LLM trait_detector  (gemma4:e4b, ~30s async)
    system: "Tu observes un druide. Voici 3 runs de comportement.
             Propose UN trait personnalisé qui:
             1. Reflète son style sans être flatteur.
             2. Donne un bonus tactique modeste (jamais +DC, jamais
                +effet brut). Doit débloquer une OPTION ou un SLOT,
                pas une statistique.
             3. Est livré avec une prose 2-phrases de révélation
                (style 'le vieux druide te reconnaît comme...')."
    output: {trait_id, name, prose, effect_spec, rarity}
    │
    ▼
Sanitizer  (Python validator)
    - effect_spec must be in {UNLOCK_OPTION_TAG, UNLOCK_OGHAM, ADD_SLOT, BIAS_KNN}
    - no raw stat boost
    - prose < 250 chars
    - duplicate-check against profile.traits  (no near-duplicate)
    │
    ▼
profile.traits.append({...})
profile.behavioral_summary = updated
    │
    ▼
Next run shows the new trait as a "Don de la forêt" toast on intro
```

### 4.3 Catégories d'effets autorisées (validator allow-list)

| effect_spec | Effet en run | Exemple LLM-prone-to-generate |
|---|---|---|
| `UNLOCK_OPTION_TAG:<tag>` | Une option gated_on ce tag devient jouable | `UNLOCK_OPTION_TAG:silence_attentif` |
| `UNLOCK_OGHAM:<id>` | Un ogham hors paliers s'active | `UNLOCK_OGHAM:fearn` |
| `ADD_SLOT:memory:1` | +1 slot pour stocker un tag cross-run | — |
| `BIAS_KNN:emotion:<emo>:+0.05` | Légère pondération du retrieval | `BIAS_KNN:emotion:fascination:+0.05` |

**Tout autre** effect_spec → trait rejected, fallback à un trait template générique.

### 4.4 Cap et garde-fous
- Max **1 trait par 3 runs** (sinon spam)
- Max **6 traits actifs** (le joueur en désactive s'il dépasse)
- Trait dormant 5 runs sans usage → archivé (rejouable plus tard)
- Sanitizer rejette si l'effect_spec n'est pas dans l'allow-list
- A/B test cap: 50% des sessions ont la feature, 50% pas (mesurer engagement)

### 4.5 Implémentation
- Module : `tools/adaptive_trait_emergence.py` (offline, post-run)
- Stockage : extension JSON profil (§5)
- Réutilise `gemma4:e4b` + `json_repair` (déjà installé)
- Boot tool : `python tools/adaptive_trait_emergence.py --profile <path>` (CLI diag)

---

## 5. Persistance — Single JSON profil étendu (Sprint 12.3)

Extension de `MerlinSaveSystem` profile :

```json
{
  "version": "v7.7.32",
  "character": {
    "name": "...",
    "level": 7,
    "xp_total": 4200,
    "xp_for_next_level": 5000,
    "unlocked_oghams": ["beith", "luis", "nion"],     // T1 starters + T2 unlocked
    "souffle_max": 6,                                  // 5 + 1 (palier niv 5)
    "essence_max": 25,                                 // 20 + 5 (palier niv 5)
    "traits": [
      {
        "id": "trait_silence_attentif_001",
        "name": "Silence attentif",
        "prose": "Les vieux druides reconnaissent...",
        "effect_spec": "UNLOCK_OPTION_TAG:silence_attentif",
        "acquired_at_run": 12,
        "source": "adaptive_emergence",
        "active": true
      }
    ],
    "memory_slots": [
      {"tag": "sanglier_soigne", "source_run": 8, "slot_idx": 0}
    ]
  },
  "behavioral_summary": {
    "window_runs": [10, 11, 12],
    "faction_pref": {"ankou": 0.45, "niamh": 0.30},
    "dc_outcome_profile": {"success": 0.40, "partial": 0.50, "failure": 0.10},
    "pole_signature": {"Liminal": 0.55},
    "risk_appetite": 0.65,
    "computed_at": "2026-05-18 16:30:00"
  },
  "anam": 245,
  "completed_runs": 12
}
```

---

## 6. Hybride async + tirage de runes (Sprint 12.1)

### 6.1 Phases temporelles

```
T=0   Player clicks title
T=0+1s   Loading screen visible: 3 oghams tournent
T=0+1s   Boot parallel:
           - intro LLM call (gemma4:e2b, 30s budget)
           - tirage_runes animation (8s fixed)
           - skeleton kNN retrieval (~2s, hidden)
T=8s     Runes settle - reveal 3 ogham picks (cosmétique)
T=30s    Intro arrives - parchment animates in
         loading screen dissolves to Beat 1
T=30s+   Background lookahead starts:
           - Stitcher pre-fetches transition Beat 2,3
           - Card N+2 pre-fetched if it's a LLM pivot
```

### 6.2 Engine code
```python
# pseudo-code
async def boot_run():
    runes = animate_runes_picking()  # 8s, blocking display
    intro_future = asyncio.create_task(llm_intro())
    skeleton_future = asyncio.create_task(retrieve_skeleton())
    await runes  # 8s
    intro = await intro_future  # ~30s total elapsed
    skeleton = await skeleton_future  # already done
    return intro, skeleton

# during play
async def play_loop(beats):
    for i, beat in enumerate(beats):
        await render_beat(beat)  # display + wait for player
        if i + 2 < len(beats) and is_llm_pivot(beats[i+2]):
            asyncio.create_task(prefetch_pivot(beats[i+2]))
```

### 6.3 UI éléments
- `scenes/RuneCeremonyLoader.tscn` — 3 oghams en rotation
- `assets/ogham_sprites/` — réutilise les sprites existants
- Audio : un drum loop celtique léger pendant la cérémonie

---

## 7. Monte-Carlo balance (Sprint 12.5)

### 7.1 Tool
```bash
python tools/montecarlo_balance.py \
  --runs 1000 \
  --strategies greedy,balanced,random,trait_focused \
  --output ~/Downloads/balance_report_v7.7.32.html
```

### 7.2 Output
- Win-rate par niveau (1-30) × stratégie
- DC threshold distribution réelle vs designed
- Faction-dominante distribution (target: chaque dominante ≥15%)
- Failure-cascade detection (joueur en spiral négative → quels traits le sauveraient)
- Trait emergence pertinence (quels traits émergent le plus souvent — révèlent les patterns de joueur)

### 7.3 Décision threshold
Critères d'acceptation v7.7.32 :
- Win-rate niveau 10 ∈ [40, 60]%
- Pas de stratégie dominante avec >70% win-rate
- Chaque route Tree dur (Ordre/Chaos/Liminal) ≥ 20% des runs
- DC-failure rate ∈ [10, 25]% (assez pour faire mal, pas frustrant)

---

## 8. Roadmap proposée

### Ordre recommandé (logique de dépendances)

| # | Sprint | Effort | Dépend de | Livre |
|---|---|---|---|---|
| **12.0** | Plan + commit Sprints 11.1-11.5 + bible v3.5→v3.6 | 1-2j | — | Solidification de l'acquis |
| **12.1** | Hybride async + RuneCeremonyLoader | 3-4j | 12.0 | Loading screen jouable |
| **12.2** | Tree dur 3 routes + 5 LLM pivots + pool extension 330 buckets | 6-8j | 12.1 | Run narratif robuste |
| **12.3** | XP cross-run + JSON profil étendu + UI hub | 5-6j | 12.0 | Boucle long-terme |
| **12.4** | **Adaptive Trait Emergence** (headliner) | 5-7j | 12.3 | Trait personalisé live |
| **12.5** | Monte-Carlo balance harness + tuning pass | 3-4j | 12.4 | Balance honnête |
| **12.6** | Bible v3.6 → v3.7 + commit + release v7.7.32 | 1-2j | tout précédent | Phase 12 close |

**Total**: ~24-33 dev-days.

### Parallélisation possible
- 12.1 + 12.3 peuvent commencer en parallèle (UI hub vs RuneCeremonyLoader)
- 12.5 peut être branché dès 12.3 (le harness peut tourner sur des runs simulés sans 12.2/12.4)

---

## 9. Risques + plans de contingence

| Risque | Mitigation |
|---|---|
| Pool extension 90→330 buckets demande ~5h de LLM batch sur gemma4:e4b | Run overnight + cache idempotent (mécanisme déjà éprouvé) |
| Adaptive Trait Emergence génère traits broken | Sanitizer strict allow-list + cap 1 trait / 3 runs + manual review queue |
| LLM pivots lookahead saturent Ollama queue | max_workers=2 + timeout=25s par appel + fallback retrieval si timeout |
| XP scaling trop facile niveau 30 → trivialisation | DC fixe (déjà décidé) + Monte-Carlo 1000 sims pour valider win-rate |
| Tirage de runes anim fait trop attendre | Animation skippable + speed-toggle option settings |
| JSON profil corruption (gros profil 6 traits + 30 runs) | Sauvegarde rolling 3 versions + backup automatique avant write |

---

## 10. Pré-requis pour démarrer Phase 12

1. **Sprint 11.6 terminé** : bible v3.5→v3.6 avec §25-§26 ; commit Sprints 11.1-11.5
2. **Pool v2 complet** : les 53 fallback restants upgradés (re-run du batch quand Ollama est stable)
3. **Validation des décisions ci-dessus** : si tu veux ajuster une réponse de la review, modifier §1 en premier

---

## 11. Concrete next deliverable proposé

Quand tu dis "go Phase 12" :

1. **Étape A (1j)** : Sprint 12.0 — bible §25/§26 + commit
2. **Étape B (2j)** : PoC de `tools/adaptive_trait_emergence.py` sur 3 runs synthétiques pour valider l'idée headliner AVANT de la coder en in-game
3. **Étape C (varie)** : suite Sprint 12.1 → 12.6 selon priorité que tu indiqueras

L'Étape B est strategique : on ne s'engage pas dans Sprint 12.2 (tree dur, gros design) avant d'avoir prouvé que le LLM trait-detector produit des traits *cool sans être broken*.

---

*Author: synthesis post-review 2026-05-18.*
*Decisions: 8 AskUserQuestion responses + 1 free-form innovation.*
*Builds on: PHASE_11_NARRATIVE_DEPTH_PLAN.md, EMBEDDING_FIRST_ARCHITECTURE.md.*
