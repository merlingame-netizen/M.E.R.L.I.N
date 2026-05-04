# ROADMAP.md — MERLIN

> Chantiers actifs ranked par valeur joueur perçue. Le studio-director
> lit ce fichier à chaque cycle pour choisir le prochain swarm à
> dispatcher. Mis à jour à mesure que les chantiers avancent ou que
> de nouvelles priorités émergent (playtester reports, user feedback).
>
> Source des décisions : `PROJECT.md`. Created 2026-05-01.

---

## Chantier #1 — Cohérence scénaristique & visuelle

**Pourquoi #1** : sans âme cohérente, même un gameplay tight ne tient
pas la quality bar Inscryption. Tout joueur ressent immédiatement
quand le ton dérive (palette qui change, voix Merlin qui sonne IA,
typographie hétérogène).

### Sous-chantiers

- [ ] **Audit visuel** des 8 scènes (palette, typo, contrastes, espaces)
  - Output : `docs/audits/visual_coherence_audit_2026-05.md`
  - Tentacles candidats : `art_direction`, `ui-ux:*`, `quality:visual_qa`
- [ ] **Audit narratif** : voix Merlin homogène, ton druidique tenu
  - Output : `docs/audits/narrative_coherence_audit_2026-05.md`
  - Tentacles candidats : `narrative:*`, `quality:narrative_qa`
- [ ] **Charte unifiée** : palette canonique + typo + spacing + iconographie
  - Output : `docs/CHARTE_VISUELLE.md`
- [ ] **Application charte** sur les 8 scènes (sweep multi-scènes)
- [ ] **Voice consistency pass** sur les 810 cartes RPG du pool
- [ ] **Ambient layer** par biome (préparation audio) — handed off au #5

### Definition of Done #1

- 8 scènes passent l'audit visual_qa avec 0 issue HIGH
- Pass narrative_qa sur intro tuto + 5 cartes random + endrun = ton homogène
- Charte versionnée dans docs/, référencée par CLAUDE.md

---

## Chantier #2 — Menus & connexions de scènes

**Pourquoi #2** : un menu cassé tue l'immersion avant même le run.
La boucle `IntroCeltOS → Menu → Sauvegarde → Hub → Options → Run →
EndRun → Hub` doit être polish, sans crash, sans flash blanc.

### Sous-chantiers

- [ ] **Smoke matrix** sur les 8 scènes individuellement
  - Output : `docs/audits/scene_smoke_matrix.md`
- [ ] **Smoke des transitions** (PixelTransition, fades, scene_transition SFX)
  - Tentacles : `core:godot_expert`, `quality:transition_qa`
- [ ] **MenuOptions** : cohérence avec les autres scènes (skip flag, audio toggle)
- [ ] **SelectionSauvegarde** : flow de slot save/load testé sur 3 profils
- [ ] **EndRunScreen** → Hub return : pas de stale state
- [ ] **Boot flow tutoriel** : vérifier le skip key + fast-forward C37 fonctionne sur des replays

### Definition of Done #2

- Toutes les transitions inter-scènes : 0 SCRIPT ERROR sur 50 cycles smoke
- Save / Load : 0 perte de state sur 20 cycles
- Tutorial skip + replay : OK

---

## Chantier #3 — Boucle gameplay core end-to-end

**Pourquoi #3** : c'est le run lui-même. Si la boucle a un softlock
en carte 4, tout le reste est cosmétique. Run = 5 cartes, choix →
minigame → résolution → effets → carte suivante.

### Sous-chantiers

- [ ] **ai_playtester batch 50 runs** sur la boucle complète
  - 5 personas × 10 runs = 50 runs analysés
  - Output : `docs/playtest_reports/2026-05-batch1.md`
- [ ] **Triage softlocks / crashes** détectés
- [ ] **Fix prioritaires** (un swarm par bug HIGH, en parallèle)
- [ ] **Couverture des 4 résolutions RPG** (critical / success / failure /
  critical_failure) sur les 5 cartes
- [ ] **Balance check** : aucun run < 50% completion sur 50 runs random
- [ ] **Re-batch validation** après fixes — 50 runs nouveau

### Definition of Done #3

- 100 runs ai_playtester back-to-back : 0 crash, 0 softlock
- Distribution des 4 résolutions ≈ équilibrée selon BALANCE_FORMULA
- Run moyen : 5-10 min (cohérent avec audience casual)

---

## Chantier #4 — Balance & RPG depth (couches progressives)

**Pourquoi #4** : les mécaniques RPG (factions, oghams, gifts, traits)
sont codées (C16-C29) mais le joueur les ressent-il vraiment ? Couches
progressives : carte 1-3 simple, 4-5 dévoile la profondeur.

### Sous-chantiers

- [ ] **Audit "ressenti"** : sur 5 runs ai_playtester, est-ce que les
  effets de gifts / traits sont perceptibles ?
- [ ] **Tutorial-free UX pass** : pas de tooltip, retours visuels <100ms
  (cf. `docs/TUTORIAL_FREE_UX.md`)
- [ ] **Balance fine-tuning** : DC scaling, XP curve, anti-synergy gifts
- [ ] **Faction reputation visibility** : floaters HUD calibrés (C28b)
- [ ] **Trait announce moments** : critical_streak, faction_max — pop visuel + SFX
- [ ] **Gift offer flow** (cards 2 et 4) — validation lisibilité

### Definition of Done #4

- Playtester report : Stratège persona reconnaît au moins 3 trade-offs RPG
  par run sur 5 runs
- Conteur persona : citations narratives mentionnent les factions ≥ 2× / run
- Audit director : "le joueur sent évoluer son personnage" — verdict GO

---

## Chantier #5 (mid) — Audio

**Pourquoi mid** : decided in Q&A — pas avant que UX/balance soient propres.
Une fois #1-#4 PASS, la pipeline audio s'allume.

### Sous-chantiers (à activer plus tard)

- [ ] Audit hot spots où le silence pèse (card open/close, choice click,
  faction shift, critical) — déjà partiellement câblé via SFXManager (C31)
- [ ] Ambient music adaptive par biome (7 biomes) — leverage musique
  procédurale ou achat asset celtique
- [ ] Mix calibration entre PV / SFX / ambient
- [ ] Voice gen Merlin (TTS local ?) si jamais on s'aventure là

---

## Chantier #6 (last-mile) — Release packaging

**Pourquoi last** : ne touche que quand #1-#5 sont PASS.

### Sous-chantiers (à activer plus tard)

- [ ] Build pipeline desktop : Windows + Linux + macOS signés
- [ ] LLM dégradation testée sur 3 profils hardware
- [ ] Crash reporter intégré (Sentry / Backtrace ?)
- [ ] Steam page draft : capture, GIFs, copywriting
- [ ] itch.io page miroir

---

## Hors-roadmap — debt et nettoyages opportunistes

Le director peut dispatcher en arrière-plan quand les workers sont libres :

- Quarantaine définitive des `*.gd.disabled` (test scripts cassés)
- Cleanup des dirty files persistants dans `git status` (.claude/hooks/, settings.local.json, autodev/setup_cloud.sh)
- Suppression des dossiers `tools/autodev/captures/run_*` accumulés
- Cleanup des worktrees `.octogent/worktrees/studio-worker-*` orphelins
- Déprécation graduelle de `claude-agents-monitor` (extension VS Code) — Octogent canonique
- Documentation des commandes `python tools/cli.py *` qui ne sont plus utilisées

---

## Rangée par valeur joueur (résumé pour le director)

```
priorité  chantier                                       blocker pour
─────────────────────────────────────────────────────────────────────
  1       Cohérence scénaristique & visuelle             quality bar
  2       Menus & connexions de scènes                   first 30 sec UX
  3       Boucle gameplay core end-to-end                run completion
  4       Balance & RPG depth (couches progressives)     replay value
  5       Audio (mid)                                    polish phase
  6       Release packaging (last-mile)                  ship
```

---

*Le studio-director relit ROADMAP.md à chaque cycle. Si un chantier passe
DoD complet, il est retiré du top et le suivant prend la priorité. Si un
playtester report ouvre un crash bloquant pendant un chantier #1, le
director re-arbitre et insère le fix en sous-chantier de #3.*
