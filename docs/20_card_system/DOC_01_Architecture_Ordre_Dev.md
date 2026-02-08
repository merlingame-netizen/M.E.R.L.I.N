# DOC 01 — Architecture & ordre de développement (MCP)

## Objectif
Mettre en place une base **data-driven**, **non frustrante**, compatible avec un **LLM local** (*Merlin*) qui génère récit/choix, tandis que le moteur applique uniquement des effets **whitelistés**.

---

## Ordre de développement recommandé

1. **State Machine + Store unique**
   - `GameManager` (phases)
   - `dispatch(action)` + reducer
   - journalisation des transitions (debug)

2. **SaveSystem (3 slots + versioning + reprise de run)**
   - schéma JSON stable
   - migration simple par version

3. **RNG déterministe (seed)**
   - même seed = même map + mêmes tirages

4. **EffectEngine (whitelist + logs)**
   - applique des effets codés
   - refuse tout effet non listé
   - trace *qui a demandé quoi* (LLM / système / joueur)

5. **UI Shell unique (layout GBC + 3 boutons FORCE/LOGIQUE/FINESSE)**
   - même structure écran pour Event & Combat

6. **EventSystem v2 (pipeline HoF + mini-jeux cachés)**
   - génération data-driven
   - 4 mini-jeux : DICE / TIMING / MEMORY / AIM

7. **CombatSystem v2 (mêmes boutons, même résolution de test)**
   - intentions ennemies
   - postures (stances), momentum

8. **MapSystem (STS-like + chemin + transitions)**
   - afficher chemin pris + embranchements immédiats

9. **Meta (Hub Tamagotchi + Bond + Achievements + Loadout)**
   - progression douce & visible

10. **SkillTrees + Evolutions stage 0..9 + variantes élémentaires**
   - évolutions systémiques (recolor/overlay)

11. **LLM Adapter (JSON contract + mémoire Merlin + validation)**
   - Merlin propose, moteur valide
   - mémoire persistante Merlin + contexte court terme

---

## Interfaces (contrats)

### 1) LLMAdapter
- `generate_scene(context) -> SceneJSON`
- `evaluate_decision(context, decision) -> EvalJSON` *(optionnel, si tu veux une “note Merlin”)*

### 2) EffectEngine
- `apply_effects(state, effects[])`
- `validate_effect(effect_code) -> bool`
- `record(effect, source, timestamp)`

### 3) ActionResolver
- `resolve(verb, subchoice, context) -> Resolution`
- renvoie test caché + coûts + éventuels pré-effets

### 4) MiniGameSystem
- `run(testType, difficulty, modifiers) -> {success, score, time_ms}`

### 5) CombatSystem
- `enter(enemyPack)`
- `step(playerResolution)`
- `exit()` + récompenses

### 6) SaveSystem
- `save_slot(n, payload)`
- `load_slot(n) -> payload`
- `migrate(payload)`

---

## Règles globales (anti-frustration)
- Aucun **one-shot** narratif par un seul jet.
- Échec = **coût** + **info** ou **progress** (jamais “zéro”).
- Système de **pity** : `fail_streak` augmente la réussite cachée.
- Si HP bas : augmente chances nœuds HEAL / outcomes “protecteurs”.
