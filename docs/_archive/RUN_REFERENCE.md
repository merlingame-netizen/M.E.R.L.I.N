# Card System — Reference Run (20 cartes)

> Source: MERLIN_LLM_Pipeline_Test_Report_v3_REWRITE_actions_tree_v3.docx
> Aligned with: merlin_card_system.gd, triade_game_ui.gd, triade_game_controller.gd

---

## 1. Card Format

Each card contains:
- **text**: Narrative scene description (French, atmospheric prose)
- **speaker**: "MERLIN" or NPC archetype
- **options**: Array of 3 choices, each with:
  - `label`: Action verb (e.g., "Ecouter", "Pister", "Prier")
  - `action_desc`: Optional description shown on hover
  - `effects`: Array of SHIFT_ASPECT effects
  - `dc_hint`: Difficulty class for D20 roll (1-20)
  - `result_success` / `result_failure`: Outcome text

---

## 2. Action Verbs — Simple, Single Word

Buttons display ONLY a single verb in title case:

| Correct | Incorrect |
|---------|-----------|
| Ecouter | [A] Ecouter attentivement |
| Pister | [B] Suivre la piste |
| Prier | [C] Prier les dieux |

**Reference verbs from test run**: ECOUTER, PISTER, PRIER, SUIVRE, FORCER,
POURCHASSER, INVOQUER, CONFRONTER, PURIFIER, OBSERVER, MEDITER,
MARCHANDER, BRAVER, TRAVERSER, APPELER, DEFIER, IGNORER

**Fallback verbs** (if LLM omits labels): Observer, Canaliser, Braver

---

## 3. Three-Act Structure (20 cards)

| Act | Cards | Tone | Description |
|-----|-------|------|-------------|
| **Eveil** | 1-7 | Discovery | Introduction, biome exploration, first NPCs |
| **Confrontation** | 8-15 | Rising tension | Conflict, challenges, aspect shifts intensify |
| **Resolution** | 16-20 | Climax | Final choices, endings, consequences |

---

## 4. Reference Run — Decision Tree (20 cartes)

### Acte 1: Eveil
| # | Scene | Verb A | Verb B | Verb C |
|---|-------|--------|--------|--------|
| 1 | Le vent souffle sur les landes... | Ecouter | Avancer | Observer |
| 2 | Une silhouette entre les arbres... | Suivre | Appeler | Ignorer |
| 3 | Un cercle de pierres pulse... | Toucher | Contourner | Mediter |
| 4 | Le renard guide vers une clairiere... | Pister | Attendre | Braver |
| 5 | Une riviere bloque le chemin... | Traverser | Chercher | Plonger |
| 6 | Le druide offre un breuvage... | Accepter | Refuser | Negocier |
| 7 | Un cri resonne dans la brume... | Courir | Ecouter | Fuir |

### Acte 2: Confrontation
| # | Scene | Verb A | Verb B | Verb C |
|---|-------|--------|--------|--------|
| 8 | L'esprit du dolmen s'eveille... | Invoquer | Confronter | Apaiser |
| 9 | Les korrigans exigent un tribut... | Marchander | Defier | Sacrifier |
| 10 | La tempete arrache les branches... | Proteger | Resister | Esquiver |
| 11 | Merlin parle d'un pacte ancien... | Accepter | Sonder | Refuser |
| 12 | Un guerrier fantome barre la route... | Attaquer | Parler | Contourner |
| 13 | La source sacree est empoisonnee... | Purifier | Chercher | Prier |
| 14 | Le cerf blanc apparait... | Suivre | Observer | Implorer |
| 15 | Les flammes encerclent le village... | Soigner | Braver | Appeler |

### Acte 3: Resolution
| # | Scene | Verb A | Verb B | Verb C |
|---|-------|--------|--------|--------|
| 16 | L'arbre de vie tremble... | Canaliser | Proteger | Sacrifier |
| 17 | Le voile entre mondes s'amincit... | Traverser | Resister | Conjurer |
| 18 | Merlin revele la verite... | Accepter | Defier | Mediter |
| 19 | Le sanglier charge... | Esquiver | Confronter | Grimper |
| 20 | L'aube se leve sur Broceliande... | Avancer | Observer | Prier |

---

## 5. Aspect Mechanics (Triade)

| Aspect | Animal | Bas | Equilibre | Haut |
|--------|--------|-----|-----------|------|
| Corps | Sanglier | Epuise | Robuste | Surmene |
| Ame | Corbeau | Perdue | Centree | Possedee |
| Monde | Cerf | Exile | Integre | Tyran |

**State transitions**: 3 discrete states per aspect (no numeric gauge).
**Endings**: 12 chutes (2 aspects at extremes) + 3 victoires + 1 secrete.

---

## 6. Souffle d'Ogham

- **Max**: 7 charges, start with 3
- **Regen**: +1 when all 3 aspects are in Equilibre
- **Usage**: Dedicated button (bottom-right), +4 to next D20 roll
- **Visual**: Pulse animation on activation, dim when empty

---

## 7. D20 Resolution

| Roll | Outcome |
|------|---------|
| 1 | Critical failure |
| 2-7 | Failure |
| 8-13 | Partial success |
| 14-19 | Success |
| 20 | Critical success |

DC (Difficulty Class) varies per choice: 8-15 typical range.
Souffle bonus: +4 to roll when active.
