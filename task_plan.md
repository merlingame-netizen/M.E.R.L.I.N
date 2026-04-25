# Task Plan — Tri scenes + refactor demo bout en bout

> Date: 2026-04-25 | Auteur: Claude (orchestrateur) | Branch: main
> Mode: MODERATE refactor — agent waves obligatoires

---

## Objectif

Reduire le projet a la **core experience jouable de bout en bout** :

```
IntroCeltOS
  -> First Run 3D (tutoriel guide, scripte, SANS LLM, biome Broceliande)
    -> Hub (cabane Merlin)
      -> Run libre 3D (Broceliande, AVEC LLM, choix carte/minigame/effets)
        -> EndRunScreen
          -> retour Hub OU Menu Principal (sauvegarde)
```

**Demo = un seul biome (Broceliande). Un seul hub. Un seul menu. Pas de meta-progression UI (Calendar/Collection/TalentTree/MapMonde) dans la demo.**

## Decisions verrouillees (user 2026-04-25)

| Decision | Reponse user |
|----------|--------------|
| Flow demo | Intro -> First Run tuto (sans LLM) -> Hub -> Run libre (LLM) -> Menu/save |
| Tri | `git rm` direct sur les non-essentiels |
| Doublons hubs/menus | Supprimer aussi (un seul de chaque) |
| Priorite | Flow connecte ET boucle gameplay reelle |

## Phases (Agent Waves)

### Wave 1 — Analyse (SEQUENTIAL)

1. **project_curator** : scan complet de `scenes/` + `scripts/` + `addons/`. Produit:
   - Tableau KEEP/DELETE/CONSOLIDATE pour chaque .tscn
   - Choix definitif : 1 hub, 1 menu, 1 scene de run 3D
   - Liste des scripts orphelins une fois les .tscn supprimees
   - Liste des autoloads/refs a mettre a jour dans project.godot
2. **game_designer** : valide la chaine cible vs bible v2.4. Confirme que :
   - First Run = tuto scripte (pas un vrai run avec faction/Ogham — juste le rail + 1 carte demo)
   - Run libre = boucle complete (drain, carte LLM, choix, minigame, effets, score)
   - Menu/Save inclut un point de save/load minimal

### Wave 2 — Implementation (SEQUENTIAL)

3. **lead_godot** + **godot_expert** (parallele) :
   - `git rm` les .tscn DELETE
   - `git rm` les scripts orphelins associes
   - Mettre a jour `project.godot` (main_scene, autoloads, input map si necessaire)
   - Renommer si besoin (ex: `MerlinCabinHub.tscn` -> `Hub.tscn` si c'est le retenu)
4. **ui_impl** :
   - Cabler IntroCeltOS -> FirstRunTuto
   - Cabler fin tuto -> Hub
   - Cabler bouton Hub "Partir en run" -> Run libre
   - Cabler EndRunScreen -> retour Hub + bouton Menu
   - Cabler Menu -> Save/Load
5. **godot_expert** : Differencier les 2 runs :
   - First Run guide : sequence scripte (cartes pre-ecrites en JSON local, voix off tuto)
   - Run libre : pipeline LLM existant (`merlin_card_system` + `merlin_ai`)

### Wave 3 — QA & Commit (SEQUENTIAL)

6. **debug_qa** : `validate.bat` + smoke test du flow via `mcp__godot-mcp__execute_editor_script`
7. **git_commit** : commit conventional + push

### Wave Finale

8. **Skill `everything-claude-code:learn-eval`** : extraction patterns de cette session

## 2026-04-25 (suite) — Refonte sequentielle tuto + visibilite 3D

### Decisions
- Plan canonique : `docs/INTRO_TUTO_SEQUENCE.md` (Merlin parle PUIS effet, jamais l'inverse)
- VO et effet sont SEQUENTIELS, pas concurrents (carte ne charge plus pendant la dialogue)
- Visibilite 3D : ProceduralSkyMaterial + Sun energy 1.6 + fog atmospherique dans .tscn
- Captures auto 100-200ms : reportees a un commit 2 (apres validation user de la base)

## Etat d'avancement (live)

- Wave 1 (analyse) : DONE — Explore agent rapport KEEP/DELETE
- Wave 2a (suppressions) : DONE — 21 .tscn + 22 .gd `git rm`
- Wave 2b (patches refs) : EN COURS — 7/10 fichiers patches
- Wave 2c (tutorial flag) : PENDING
- Wave 3 (validation + commit) : PENDING

## Sortie attendue

- ~10-15 .tscn restantes (vs 32 actuelles)
- 0 reference cassee (project.godot, autoloads, signals)
- `validate.bat` passe sans warning
- Smoke test : Intro -> Tuto -> Hub -> Run -> End -> Menu sans crash

## Risques

| Risque | Mitigation |
|--------|------------|
| Suppression d'une scene utilisee par autoload | project_curator fait grep des references AVANT delete |
| First Run guide encore inexistant | Wave 2 cree un script tutoriel minimal si absent |
| LLM dans Run libre cassee | Ne pas toucher a `addons/merlin_ai/*` — juste reconnecter |
| Sauvegarde Menu pas branchee | Si trop complexe, MVP = "Continue" desactive en demo |
