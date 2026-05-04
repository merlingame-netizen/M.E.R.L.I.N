# PROJECT.md — MERLIN

> **Source de vérité unique du projet.** Synthèse validée
> 2026-05-01 via 24 questions/réponses (état des lieux + cahier des charges).
> Lu par le studio-director Octogent à chaque cycle pour aligner son dispatch.

---

## Finalité

Sortie commerciale **MERLIN — Le Jeu des Oghams** sur Steam / itch.io payant.
Pas de release web. Cible : desktop + console (mobile envisagé).

Le studio agentique (Octogent + 103 agents + studio-director) est un MOYEN
de production, pas un livrable. Une fois MERLIN shippé, le studio peut être
jeté.

## Quality bar

**Slay the Spire / Inscryption** — indie indé-AAA. Target review Steam 90%+.
Tight UX, pas de bug visible, balance affinée, narration cohérente, audio
adapté. Couches progressives : carte 1-3 simple, 4-5 dévoile la profondeur
(casual-friendly, sessions 5-10 min).

## Timeline

**No deadline — quality first.** Boucles longues, seuil d'acceptabilité
très élevé. Ne pas shipper tant que la qualité Inscryption n'est pas atteinte.

## Audience

Casual desktop + console. Sessions courtes 5-10 min. Le joueur installe
localement, le jeu fait tourner ce qu'il a (LLM Qwen quantisé adaptatif
selon hardware).

## Vision technique

| Couche | Choix |
|---|---|
| **Engine** | Godot 4.5.1 |
| **LLM** | Qwen 3.5 local via Ollama, runtime sur la machine joueur |
| **Build target** | Desktop d'abord, consoles ensuite, mobile en bonus. **Pas de web.** |
| **Assets** | Mix procédural (CRT phosphor + pixel art) + AI-gen highlights (cartes mythiques, biomes signature) |
| **Audio** | SFXManager existant, ambient music adaptatif par biome — priorité MID (après UX/balance) |

---

## Le studio (infra dev autonome)

### Architecture

```
                ┌─────────────────────────────────────┐
                │     studio_director (tentacle)      │
                │  • Lit GAME_DESIGN_BIBLE + DEV_PLAN │
                │  • Identifie gaps de cohérence       │
                │  • Priorise par valeur joueur        │
                │  • Dispatch swarms                   │
                │  • Déclenche ai_playtester           │
                │  • Ré-arbitre si nouvelle priorité   │
                └────────────┬────────────────────────┘
                             │
                             ▼
                ┌─────────────────────────────────────┐
                │   Octogent dashboard (canonique)    │
                │   http://localhost:8787              │
                │  • 103 tentacles (catalog complet)  │
                │  • Status / logs PTY / metrics      │
                │  • Roadmap living (chantiers + ETA) │
                │  • Bouton stop par tentacle         │
                └────────────┬────────────────────────┘
                             │
                             ▼
                ┌─────────────────────────────────────┐
                │   Swarms (parent + workers worktree)│
                │  • POST /api/deck/tentacles/<id>/swarm
                │  • 1 worker par todo, isolé git     │
                │  • Quality gates auto post-commit   │
                │  • Auto-rollback si smoke fail      │
                └─────────────────────────────────────┘
```

### Composants opérationnels

- **Octogent** = canonique unique. autodev / claude-agents-monitor à
  déprécier progressivement (pas de migration urgente, juste plus de
  développement neuf dessus).
- **103 agents catalog** = `tools/autodev/agent_cards/_registry.json` →
  pré-intégrés en tentacles avec couleurs Druido-Tech (C40).
- **ai_playtester** = 5 personas (Explorateur, Stratège, Conteur, +2)
  exécutés en boucle après chaque batch de commits par le director.

### Quality gates (non-négociables avant merge sur main)

1. `validate.bat` / parse-check headless — 0 errors GDScript
2. Smoke runtime sur la scène touchée — `script_errors=0` `exit_code=0`
3. `code-reviewer` agent pass — no HIGH issues
4. ai_playtester — 1 run par persona finit sans crash ni softlock

Si l'un échoue post-commit : **auto-rollback git** + ré-ouverture de la
todo dans le tentacle responsable.

### Mode opératoire

**Continu autonome** — boucles `/loop` sans interruption. Le user
intervient seulement si quelque chose dérive (bouton stop dashboard
→ director re-affecte).

---

## Chantiers prioritaires (auj. → cette semaine)

Ranked par valeur joueur perçue :

1. **Cohérence scénaristique / visuelle** — palette unifiée, voix Merlin
   homogène, atmosphère celtique tenue à travers les 8 scènes
2. **Menus + connexions de scènes** — IntroCeltOS ↔ Menu ↔ Sauvegarde
   ↔ Hub ↔ Options ↔ Run ↔ EndRun, sans crash, transitions polish
3. **Boucle gameplay core end-to-end** — intro → hub → run 5 cartes →
   fin sans bug ni softlock
4. **Balance + RPG depth** — factions, oghams, gifts, traits doivent
   se SENTIR au jeu (couches progressives — invisible cartes 1-3,
   visible 4-5)

Audio reste mid-priority. Asset AI-gen vient après cohérence.

---

## Documents de référence (lus par le director)

| Doc | Contenu |
|---|---|
| `docs/GAME_DESIGN_BIBLE.md` (v2.4) | Source de vérité game design : core loop, 5 factions, 18 Oghams, RPG, 8 biomes, MOS |
| `docs/DEV_PLAN_V2.5.md` | Plan de dev strict (10 phases, specs code, acceptance criteria) |
| `docs/RPG_TEST_SYSTEM.md` | Système 3 axes (Souffle/Esprit/Coeur), DC, 4 résolutions |
| `docs/BALANCE_FORMULA.md` | DC scaling, XP curve, ogham modifiers |
| `docs/HUD_LAYOUT_RULES.md` | Règles UI/UX |
| `docs/INTRO_TUTO_SEQUENCE.md` | Boot flow + tutorial intro VO |
| `tools/autodev/agent_cards/_registry.json` | Catalogue 103 agents |
| `tools/octogent/MERLIN.md` | Deploy Octogent |

---

## Definition of Done (release)

MERLIN est mergeable vers `main-release` quand :

- [ ] Boucle gameplay end-to-end stable sur 100 runs ai_playtester (0 crash, 0 softlock)
- [ ] Cohérence visuelle homogène (audit director PASS sur les 8 scènes)
- [ ] 5 personas ai_playtester finissent au moins 1 run avec note balance ≥ "good"
- [ ] Audio integré (ambient + SFX feedback) sur les hot spots
- [ ] LLM dégradation testée sur 3 profils hardware (1080p haut, 1080p moyen, intégrated GPU bas)
- [ ] Code coverage 80%+ sur scripts/merlin/ et scripts/broceliande_3d/
- [ ] 0 issues HIGH ouvertes par code-reviewer
- [ ] Build desktop Windows + Linux + Mac signés
- [ ] Steam page draft prête (capture, GIFs, copywriting)

---

*Document canonique du 2026-05-01. Mis à jour quand le user change la
direction stratégique. Le studio-director relit ce fichier au début
de chaque cycle.*
