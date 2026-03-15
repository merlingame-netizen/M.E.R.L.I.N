# M.E.R.L.I.N. — Design Status Post-Audit v2.4

> **Date**: 2026-03-15
> **Scope**: Status des mecaniques de jeu apres audit complet (14 docs systeme, suppression Triade, 4 bugs corriges)
> **Source de verite**: `docs/GAME_DESIGN_BIBLE.md` v2.4
> **Referentiel technique**: `docs/GAME_MECHANICS.md` v2.0 (45 sections, formules exhaustives)
> **Remplace**: `docs/_archive/NEW_MECHANICS_DESIGN.md` (2026-03-11, pre-audit)

---

## 1. Mecaniques Confirmees (v2.4)

| Mecanique | Statut | Section Bible | Doc systeme |
|-----------|--------|:---:|-------------|
| **Vie unique** (0-100, drain -1/carte) | Actif | 2.1 | `GAME_MECHANICS.md` §3 |
| **5 Factions** (Druides/Anciens/Korrigans/Niamh/Ankou, 0-100, cross-run) | Actif | 2.3 | `GAME_MECHANICS.md` §4, `DOC_15_Faction_Alignment_System.md` |
| **18 Oghams** (cooldown, 3 starters, decouverte en run, affinite biome) | Actif | 2.2 | `GAME_MECHANICS.md` §8 |
| **MOS** (convergence soft 8, target 20-25, soft max 40, hard max 50) | Actif | Bible 5 | `10_llm/DOC_OMNISCIENT.md` |
| **Pipeline 12 etapes** (drain → carte → ogham → choix → minigame → score → effets → ...) | Actif | 13.3 | `GAME_MECHANICS.md` §18 |
| **Confiance Merlin** (0-100, T0-T3, changement immediat mid-run) | Actif | Bible 4 | `GAME_MECHANICS.md` §6 |
| **Anam** (cross-run, ~10 runs/noeud, mort = anam x min(cartes/30, 1.0)) | Actif | 2.4 | `GAME_MECHANICS.md` §9 |
| **8 Biomes** (score maturite: runs x2 + fins x5 + oghams x3 + max_rep x1) | Actif | Bible 6 | `GAME_MECHANICS.md` §15-16 |
| **8 Champs lexicaux** + neutre (45 verbes liste fermee) | Actif | 2.5 | `GAME_MECHANICS.md` §28, `20_card_system/DOC_MINIGAMES.md` |
| **Minigames obligatoires** (score 0-100 → multiplicateur x-1.5 a x1.5) | Actif | 2.5 | `20_card_system/DOC_MINIGAMES.md` |
| **Promesses** (countdown X cartes, tenir/briser, effets rep + confiance) | Actif | Bible 3 | `GAME_MECHANICS.md` §7 |
| **Monnaie biome** (per-run, marchands/PNJ, boost minigame, offrandes) | Actif | 2.4 | `GAME_MECHANICS.md` §3 |
| **Arbre de talents** (34 noeuds, 5 branches factions + central, Anam-only) | Actif | Bible 8 | `GAME_MECHANICS.md` §10, §32 |
| **Profil unique + auto-continue** (Hades-style, save cross-run) | Actif | Bible 9 | `40_progression/DOC_SAVE_SYSTEM.md` |
| **FastRoute** (500+ cartes, variantes par tier confiance, resume JSON) | Actif | 13.1 | `20_card_system/DOC_FALLBACK_POOL.md` |
| **Multi-Brain LLM** (Qwen 3.5: Narrator 4B, Game Master 2B, Judge 0.8B) | Actif | — | `LLM_ARCHITECTURE.md`, `10_llm/DOC_BRAIN_SWARM.md` |
| **Multiplicateur direct** (bonus additifs, cap global x2.0, 3 effets/option max) | Actif | 13.1 | `GAME_MECHANICS.md` §1-2 |
| **Karma & Tension** (hidden state, difficulte adaptative) | Actif | — | `GAME_MECHANICS.md` §5, §11 |

---

## 2. Mecaniques Supprimees

| Mecanique | Remplacee par | Date | Nettoyage code |
|-----------|--------------|------|:-:|
| **Triade** (Corps/Ame/Monde) | 5 Factions | 2026-03-11 | Partiel (voir §4) |
| **Souffle d'Ogham** (0-7, cout d'activation) | Options gratuites, cooldown-only | 2026-03-11 | Partiel |
| **4 Jauges** (Vigueur/Esprit/Faveur/Ressources) | 1 barre de vie unique | 2026-03-12 | Partiel |
| **Bestiole** (compagnon + bond + besoins + Awen) | Oghams sont du joueur | 2026-03-12 | OK |
| **Awen** (0-5) | Supprime avec Bestiole | 2026-03-12 | OK |
| **D20 / dice roll** | Minigames systematiques | 2026-03-12 | OK |
| **Flux System** (terre/esprit/lien) | Factions suffisent | 2026-03-12 | A supprimer |
| **Run Typologies** (5 types) | Biomes suffisent | 2026-03-12 | A supprimer |
| **Decay reputation** | Pas de decay naturel | 2026-03-14 | OK |
| **Auto-run pre-run** | Supprime | 2026-03-14 | OK |

---

## 3. Index des 14 Documents Systeme (Audit 2026-03-15)

### LLM & IA (`docs/10_llm/`)

| Document | Scope | Lignes approx |
|----------|-------|:---:|
| `DOC_OMNISCIENT.md` | MerlinOmniscient: orchestrateur central, guardrails, routing | Architecture complete |
| `DOC_RAG_MANAGER.md` | RAG v3.0: budgets jetonnes per-cerveau, journal narratif, memoire cross-run | Architecture complete |
| `DOC_BRAIN_SWARM.md` | Orchestration multi-cerveaux heterogene (Qwen 3.5), time-sharing | Architecture complete |
| `DOC_REGISTRIES.md` | 5 registres IA: event, narrative, entity, faction, player profile | Architecture complete |

### Card System (`docs/20_card_system/`)

| Document | Scope |
|----------|-------|
| `DOC_MINIGAMES.md` | 8 champs lexicaux, 9+ minigames, scoring, detection verbes |
| `DOC_EVENT_SELECTOR.md` | Event Category Selector v2.0: ponderation 7 facteurs, selection cartes |
| `DOC_FALLBACK_POOL.md` | FastRoute: pools pre-authored, variantes par tier confiance, resume JSON |

### Scenes (`docs/30_scenes/`)

| Document | Scope |
|----------|-------|
| `DOC_3D_WALK.md` | Marche on-rails 3D, collecte monnaie, transitions fondu, events 3D |
| `DOC_SCENE_FLOW.md` | Flux complet: IntroCeltOS → Menu → Quiz → Rencontre → Hub → Run → Hub |

### Progression (`docs/40_progression/`)

| Document | Scope |
|----------|-------|
| `DOC_SAVE_SYSTEM.md` | Profil unique JSON + run_state, cross-run vs intra-run |

### Visuel (`docs/70_graphic/`)

| Document | Scope |
|----------|-------|
| `DOC_CRT_PALETTE.md` | CRT_PALETTE druido-tech, GBC legacy, constantes couleurs |
| `DOC_CRT_SHADER.md` | CRT shader v2.0: scanlines, phosphor, aberration chromatique |
| `DOC_UI_ARCHITECTURE.md` | Couche presentation, composants UI, MerlinVisual singleton |

### Architecture LLM (racine `docs/`)

| Document | Scope |
|----------|-------|
| `LLM_ARCHITECTURE.md` | Multi-cerveaux, LoRA, prompts, hardware profiles |

---

## 4. Ecarts Code vs Design — Etat du nettoyage

> Source: `GAME_DESIGN_BIBLE.md` section 14 + scan des docs

### Nettoyage termine

- Awen references (`merlin_constants.gd`) — supprime
- `bond_required` dans Oghams (`merlin_constants.gd`) — supprime
- Souffle refs (`merlin_game_controller.gd`) — nettoye
- Triade aspects refs (`merlin_game_controller.gd`) — nettoye
- Gauges dans `merlin_card_system.gd` — nettoye
- Champs lexicaux manquants (`minigame_registry.gd`) — 9 minigames ajoutes
- Talent tree redesign (34 noeuds, 5 branches factions) — OK
- Save system (profil unique + auto-continue) — OK

### Nettoyage en cours

| Element | Fichiers concernes | Action |
|---------|-------------------|--------|
| 4 Gauges (ADD/REMOVE/SET_GAUGE) | `merlin_store.gd`, `merlin_effect_engine.gd` | Remplacer par HEAL_LIFE/DAMAGE_LIFE |
| Bestiole (bond, needs, skills) | `merlin_constants.gd`, `merlin_store.gd` | Supprimer entierement |
| `aspect_bias` dans biomes | `merlin_biome_system.gd` | Remplacer par `faction_bias` |
| D20 / DC system | `merlin_constants.gd` | Remplacer par minigame difficulty |
| Souffle refs (constantes) | `merlin_constants.gd`, `merlin_effect_engine.gd` | Supprimer |
| TRIADE_LLM_PARAMS | `merlin_llm_adapter.gd` | Renommer |
| Flux system | `merlin_constants.gd` (FLUX_*) | Supprimer |
| Run Typologies | `merlin_constants.gd` (RUN_TYPOLOGIES) | Supprimer |
| left/center/right options | `merlin_constants.gd` (CardOption enum) | Remplacer par 3 options fixes |

### References Triade stales dans la documentation

Les docs suivants referent encore a la Triade (systeme supprime). A mettre a jour ou archiver :

| Document | Nature de la reference |
|----------|----------------------|
| `docs/70_graphic/ART_DIRECTION_AUDIT.md` | TriadeGameUI restyle plan, style gap analysis |
| `docs/70_graphic/ANIMATION_INVENTORY.md` | `ui/triade_game_ui.gd` animations |
| `docs/30_scenes/CANONICAL_ONBOARDING_FLOW.md` | "Transition finale vers Triade" |
| `docs/30_scenes/SPEC_TRANSITION_SCENES.md` | "eviter confusion avec le gameplay Triade" |
| `docs/40_progression/SPEC_TALENT_TREES.md` | "Systeme Triade — 3 Aspects x 3 etats" |
| `docs/50_lore/00_LORE_BIBLE_INDEX.md` | Reference DOC_12_Triade |
| `docs/dashboard.html` | Section Game System: Triade, classes CSS `.triade-grid` |
| `docs/BEST_PRACTICES.md` | Historique suppression (correct: reference le fait que c'est supprime) |

> **Note**: `docs/50_lore/04_MERLIN.md` utilise "triade" au sens litteraire (pas le systeme de jeu) — correct.

---

## 5. Questions Ouvertes / Priorites Design

### Equilibrage (a confirmer au playtest)

- Valeurs exactes des prix marchands PNJ (fourchette indicative: 2-20 monnaie biome)
- Couts Anam des tiers d'arbre de talents (fourchette 50-350)
- Poids du score de maturite biome (runs x2, fins x5, oghams x3, max_rep x1)
- Pity system — seuils exacts de deblocage de contenu en cas de difficulte persistante

### Contenu a produire

- 500+ cartes FastRoute (pool actuel a evaluer)
- 18 Oghams — integration complete dans l'arbre de talents UI
- 8 biomes — assets 3D et configurations specifiques
- Arcs narratifs par biome (chaines de 3-5 cartes)

### Systemes a implementer

- Monnaie biome: marchands PNJ visibles en 3D (Gwenn, Puck, Bran, Seren)
- Carte du voyage (ecran fin de run)
- Multiplicateur UI feedback (affichage du score → multiplicateur en temps reel)
- Phases lunaires (impact gameplay)
- Calendrier celtique (8 festivals, 4 saisons)

### Architecture a finaliser

- Pipeline 14 etapes (`GAME_MECHANICS.md` §18) vs Pipeline 12 etapes (Bible §13.3) — harmoniser
- Section 45 "Faveurs System" dans `GAME_MECHANICS.md` — systeme non reference dans la Bible, clarifier statut

---

## 6. Hierarchie documentaire

```
GAME_DESIGN_BIBLE.md (v2.4)          ← Source de verite unique (WHAT + WHY)
    │
    ├── GAME_MECHANICS.md (v2.0)      ← Referentiel technique (HOW, formules, constantes)
    │
    ├── DESIGN_STATUS.md (ce doc)     ← Etat post-audit, tracking nettoyage
    │
    ├── docs/10_llm/                  ← 4 docs systeme IA
    ├── docs/20_card_system/          ← 3 docs systeme cartes + 6 docs legacy
    ├── docs/30_scenes/               ← 2 docs scenes
    ├── docs/40_progression/          ← 1 doc save
    ├── docs/70_graphic/              ← 3 docs visuel
    └── docs/LLM_ARCHITECTURE.md      ← Architecture multi-cerveaux
```

Documents archives ou supersedes :
- `docs/_archive/NEW_MECHANICS_DESIGN.md` — remplace par ce document
- `docs/MASTER_DOCUMENT.md` — remplace par `GAME_DESIGN_BIBLE.md`
- `docs/20_card_system/DOC_12_Triade_Gameplay_System.md` — systeme supprime
- `docs/20_card_system/DOC_13_Hidden_Depth_System.md` — a verifier si encore pertinent
- `docs/20_card_system/DOC_16_Run_Typologies.md` — systeme supprime

---

*Cree le 2026-03-15 — Post-audit M.E.R.L.I.N. v2.4*
*Prochaine mise a jour : apres nettoyage des ecarts code vs design (section 4).*
