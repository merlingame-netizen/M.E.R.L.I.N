# Formule d'equilibrage M.E.R.L.I.N. — orientation Vampire-Survivors-like

> Simple a jouer (1 axe, 3 choix), profond a maitriser (synergies emergent
> entre runs). Chaque variable ci-dessous est une cible quantifiee.

---

## Pilier 1 — DC scaling (difficulte croissante par carte)

Le run a 5 cartes. Le DC base augmente progressivement pour creer une courbe
de difficulte qui force le joueur a prendre des decisions plus tactiques au
fil du run.

```
DC(card_index) = 8 + (card_index * 1.2)
```

| Carte | DC base | Note |
|-------|---------|------|
| 1     | 8       | Facile — apprentissage des choix |
| 2     | 9       | Egal — confirmation des reflexes |
| 3     | 10      | Pivot — choix tactique requis |
| 4     | 11      | Pression — synergie debloquee aide |
| 5     | 12      | Climax — DC souvent trop haut sans ogham equipe |

Le LLM peut surcharger via le champ `dc` de la carte (+/-2 max). Les `dc_offset`
sur les choix individuels restent en plus (-1/+1 typique).

---

## Pilier 2 — XP curve (progression non-lineaire)

Cible : 3-4 stat level-ups sur les 10 premiers runs (~30 cartes), 1 sur les 30
suivants. La progression early est rapide pour donner du fil a tirer, puis
plateau pour valoriser les builds.

```
XP par tier (constants):     CRITICAL=20, SUCCESS=10, FAILURE=5, CRIT_FAIL=2
Stat level threshold:        100 XP par level
Run typique:                 ~50-60 XP/run sur l'axe domine
=> Stat level-up tous les 2 runs sur l'axe domine, ~tous les 4 runs sur les
   autres axes.
```

Cap stat = 10. Au-dela, l'XP est conserve mais ne convertit pas (memoire
"force" du voyageur).

---

## Pilier 3 — Modificateurs Ogham (3 niveaux d'investissement)

3 tiers d'ogham equipement qui apportent des bonus differencies :

| Tier | Description | Bonus stat | Cost | Source |
|------|-------------|------------|------|--------|
| **Surface** | Ogham appris, pas medite | +0 (juste cosmetique) | gratuit | Premier run |
| **Medite** | Ogham activement pratique 5 fois | +1 sur l'axe affin | 50 Anam | Hub tapisserie |
| **Profond** | Ogham + faction-aligned | +2 sur l'axe + +1 narrative_modifier | 200 Anam + faction rep 60+ | Hub tapisserie |

Affinites par ogham (mapping ogham → axe) — a definir dans
`data/oghams/ogham_axis_affinity.json` (Cycle 11 part 2).

Pour l'instant, dans `walk_event_controller._resolve_rpg_test`:
```
ogham_modifier = 0 si rien d'equipe
              = 1 si Surface equipe
              = 2 si Medite affine au test
              = 3 si Profond affine au test (cap)
```

---

## Pilier 4 — Risk-reward gradient (les choix)

Chaque carte propose 3 choix avec gradient de risque/recompense :

| Choix type | dc_offset | risk profile | reward_axis_xp |
|------------|-----------|--------------|----------------|
| **Voie sure** | -1 | failure rare, critical rare | XP standard sur axe |
| **Voie equilibree** | 0 | distribution standard | XP standard |
| **Voie audacieuse** | +1 a +2 | failure plus probable, critical plus probable | XP +50% si critical |

Le joueur peut TOUJOURS prendre la voie sure de SON axe fort (faible DC).
Mais pour gagner XP rapidement, il doit accepter du risque sur d'autres axes.
Cette tension cree la profondeur.

---

## Pilier 5 — Synergies emergentes (builds non-explicites)

3 archetypes principaux qui emergent naturellement (Cycle 12) :

### Build "Souffle Pur" (instinctif/physique)
- Empile stat Souffle (focus tests cadence/souffle_retenu)
- Ogham Beith ou Saille (affinite Souffle)
- Faction Korrigans (+2 narrative_modifier sur Souffle a faction 80+)
- Trait debloque "Souffle du Loup" + "Endurance celtique" + "Resistance a la nuit"
- En jeu : tres rapide, tres robuste, peu de subtilite narrative
- **Trade-off** : tests Coeur/Esprit a DC plein, narrations faillent souvent

### Build "Esprit Pur" (sage/dechiffreur)
- Empile stat Esprit (focus tests memoire_runes/lecture)
- Ogham Coll ou Tinne (affinite Esprit)
- Faction Druides (+2 narrative_modifier sur Esprit a 80+)
- Trait debloque "Lecteur de pierres" + "Memoire des anciens" + "Graveur d'oghams"
- En jeu : decode les enigmes, reconnait les pieges, narration riche
- **Trade-off** : combat frontal et negociation difficiles

### Build "Coeur Pur" (lien/empathie)
- Empile stat Coeur (focus tests resonance/echo)
- Ogham Duir ou Quert (affinite Coeur)
- Faction Niamh ou Anciens (+2 narrative_modifier sur Coeur)
- Trait debloque "Voix Grave" + "Coeur clair" + "Lien avec Korrigans"
- En jeu : negocie, apaise, trouve des allies
- **Trade-off** : echec sur tests purement physiques, peu de combat

### Build "Hybride" (deux axes a 7+)
- Pas de specialisation, mais plus de polyvalence
- Aucun build qui depasse stat 9
- Plus dur a construire mais survie plus stable cross-runs
- **Trade-off** : pas de critical-stack, narration moins flashy

---

## Pilier 6 — Run modifiers / "Gifts" (Cycle 14)

Tous les 2 cartes (cartes 2 et 4), proposer 3 dons aleatoires parmi 12-15.
Chaque don est un modificateur permanent pour le RUN (pas cross-run).

Exemples (full liste Cycle 14) :
- "Pas leger" : drain vie -1
- "Lien profond" : +0.5 sur tests Coeur jusqu'a la fin du run
- "Memoire chaude" : XP +25% jusqu'a la fin du run
- "Ombre du loup" : +1 critical_modifier sur le prochain test
- "Poids du serment" : +2 reward Anam mais -10 max life
- "Fil de Niamh" : prochain failure devient success

Les dons creent des combos build-defining DANS LE RUN (Vampire-Survivors-like).

---

## Cibles globales (matrice adherence)

Voir `docs/PLAYER_ADHERENCE_MATRIX.md` pour les seuils detailles. Resume :

| Dimension | Cible |
|-----------|-------|
| Run length | 9 min, run de 5 cartes |
| Choice latency | 6s (le joueur reflechit, mais pas trop) |
| Resolution distrib | 30/40/20/10 (critical/success/failure/crit_fail) |
| XP/run | 60 |
| Trait unlock | 1 toutes les 5 runs |
| FPS | 60 stable, p99 >= 45 |

Si une dimension sort des cibles via les metrics JSON, ajuster les piliers ci-dessus.

---

## Anti-patterns a ne pas tomber dedans

- ❌ DC qui depend de la stat du joueur (efface la progression)
- ❌ XP exponentiel (fait sentir le joueur impuissant en late)
- ❌ Trop de modificateurs visibles (joueur calcule au lieu de jouer)
- ❌ Builds trop forts (un seul "meta" tue la replay value)
- ❌ Dons cassants (un don qui multiplie x3, 5 dons et le run est trivial)
- ❌ Synergies explicites en UI (kill l'effet de decouverte)

---

*Doc canonique : 2026-04-26 — Version 1*
