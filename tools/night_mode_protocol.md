# Night Mode Protocol — M.E.R.L.I.N.

> Ce fichier definit les regles ABSOLUES du Night Mode.
> Chaque instance Claude Code lancee en Night Mode DOIT lire et respecter ce protocole.

---

## Principe

Le Night Mode est une **boucle autonome focalisee** sur UN SEUL theme.
Tu iteres : recherche -> reflexion -> documentation -> implementation -> test -> handoff.
Tu continues jusqu'a ce que:
- Le theme soit **100% traite** (documente, teste, implemente, valide)
- OU l'utilisateur t'arrete (ferme l'onglet)

---

## Regles ABSOLUES

### 1. FOCUS THEMATIQUE (ZERO DERIVE)

- Tu travailles UNIQUEMENT sur le theme defini dans `night_mode_handoff.md`
- Tu ne touches JAMAIS a un autre systeme du jeu
- Tu ne "corriges" pas des bugs ailleurs, meme si tu les vois
- Tu ne "ameliores" pas du code hors-theme
- Si tu decouvres un probleme hors-theme, note-le dans `findings.md` et CONTINUE sur ton theme
- **Chaque action doit servir directement le theme de la nuit**

### 2. PLANNING FILES OBLIGATOIRES

Au DEBUT de chaque iteration:
```
1. LIRE night_mode_handoff.md  (etat de la nuit)
2. LIRE progress.md            (contexte sessions)
3. LIRE task_plan.md           (taches en cours)
4. LIRE findings.md            (decouvertes)
```

Pendant le travail:
```
- METTRE A JOUR task_plan.md   (phases, statuts)
- METTRE A JOUR findings.md    (decouvertes, recherches)
```

En FIN d'iteration:
```
- METTRE A JOUR progress.md    (ce qui a ete fait)
- METTRE A JOUR night_mode_handoff.md (etat pour la suite)
```

### 3. AGENTS OBLIGATOIRES

Invoquer les agents pertinents au theme. Matrice minimale:

| Phase | Agents a invoquer |
|-------|-------------------|
| Recherche/reflexion | `game_designer.md`, `narrative_writer.md`, `lore_writer.md` |
| Architecture code | `lead_godot.md`, `godot_expert.md` |
| Implementation UI | `ui_impl.md`, `motion_designer.md`, `ux_research.md` |
| Implementation code | `lead_godot.md`, `optimizer.md` |
| Shaders/VFX | `shader_specialist.md` |
| Tests/Validation | `debug_qa.md`, `optimizer.md` |
| Documentation | `technical_writer.md` |
| Fin d'iteration | `git_commit.md` |

**Regle**: Invoquer AU MINIMUM 2 agents par iteration.

### 4. SKILL FRONTEND-DESIGN

Si le theme implique une interface visuelle (ecran, menu, carte, HUD):
- Invoquer le skill `frontend-design` pour tout composant UI
- Produire du code de qualite production, pas du prototype
- Respecter la direction artistique du projet (celtique, organique)

### 5. VALIDATION AVANT HANDOFF

Avant de passer au handoff suivant, OBLIGATOIREMENT:
```powershell
.\validate.bat
```
Si la validation echoue: corriger AVANT le handoff. Ne jamais transmettre du code casse.

### 6. QUALITE DU PROMPT DE HANDOFF

Le prompt transmis au prochain onglet DOIT contenir:
1. **Theme** — Rappel explicite du theme (1 ligne)
2. **Accompli** — Ce qui a ete fait dans cette iteration (liste)
3. **Restant** — Ce qu'il reste a faire (liste priorisee)
4. **Fichiers modifies** — Liste des fichiers touches
5. **Blockers** — Problemes rencontres
6. **Prochaine action** — L'action precise a faire en premier
7. **Agents suggeres** — Quels agents invoquer
8. **Satisfaction** — Niveau 1-5 (5 = tout est parfait, on peut s'arreter)

### 7. CONDITION D'ARRET AUTOMATIQUE

Tu peux decider de NE PAS lancer de handoff (fin naturelle) si:
- Niveau de satisfaction = 5/5
- Toutes les taches du task_plan.md sont `complete`
- La validation passe sans erreur
- La documentation est a jour
- Un commit a ete fait

Dans ce cas, ecris dans progress.md:
```
### Night Mode: [THEME] — TERMINE
- Status: COMPLETE
- Raison: Satisfaction 5/5, toutes taches completees
```

### 8. SECURITE

- **Jamais** de push git automatique (seulement des commits locaux)
- **Jamais** de suppression de fichiers existants sans justification
- **Jamais** de modification du CLAUDE.md ou des agents
- **Jamais** de derive vers un autre theme
- En cas de doute: documenter dans findings.md et continuer prudemment

---

## Template de Prompt de Handoff

```
NIGHT MODE — Iteration N+1

THEME: [Le theme exact, ne change jamais]

PROTOCOLE: Lis tools/night_mode_protocol.md AVANT de commencer.

ETAT ACTUEL:
- Iteration precedente: N
- Satisfaction: X/5
- Validation: PASSED/FAILED

ACCOMPLI (iteration N):
- [item 1]
- [item 2]

RESTANT (priorise):
1. [priorite haute]
2. [priorite moyenne]
3. [priorite basse]

FICHIERS MODIFIES:
- path/to/file.gd — description

BLOCKERS:
- [blocker ou "Aucun"]

PROCHAINE ACTION:
[La toute premiere chose a faire]

AGENTS A INVOQUER:
- [agent1.md] pour [raison]
- [agent2.md] pour [raison]

REGLES RAPPEL:
1. Lis night_mode_handoff.md, progress.md, task_plan.md, findings.md
2. Travaille UNIQUEMENT sur le theme ci-dessus
3. Utilise le skill planning-with-files
4. Utilise le skill frontend-design si UI impliquee
5. Invoque les agents listes
6. Lance validate.bat avant de finir
7. Mets a jour progress.md et night_mode_handoff.md
8. Si satisfaction < 5: lance le handoff suivant
9. Si satisfaction = 5: arrete-toi et documente la completion
```

---

*Created: 2026-02-08*
*Project: M.E.R.L.I.N. — Le Jeu des Oghams*
