# NEW_MECHANICS_DESIGN.md — M.E.R.L.I.N. Nouveau Socle Mécanique

> **Document vivant** — mis à jour à chaque cycle studio_loop par l'agent `game_designer`.
> **Source de vérité** pour toutes les décisions de game design post-Triade.
> Dernière mise à jour : 2026-03-11 (initialisation)

---

## 1. Décisions Validées

### 1.1 Suppression totale de la Triade
- **Supprimé** : Corps / Âme / Monde (3 axes d'alignement BAS/EQUILIBRE/HAUT)
- **Supprimé** : Souffle d'Ogham (ressource consommable, max 7)
- **Supprimé** : SHIFT_ASPECT, ADD_ASPECT_ALIGNMENT, USE_SOUFFLE
- **Supprimé** : États discrets (Épuisé/Robuste/Surmené, Perdue/Centrée/Possédée, Exilé/Intégré/Tyran)
- **Date** : 2026-03-11

### 1.2 Mécaniques Conservées
| Mécanique | Statut | Détails |
|---|---|---|
| **Réputation x5 factions** | Conservé, À implémenter | Druides / Anciens / Korrigans / Niamh / Ankou |
| **18 Oghams** | Conservé | Système de progression/déblocage |
| **Calendrier Celtique** | Conservé | 8 festivals, phases lunaires, 4 saisons |
| **Cycle Jour/Nuit** | Conservé, À étendre | Heure réelle + saison — déjà dans Broceliande 3D |
| **Structure cartes** | Conservé (à confirmer) | 80% Narratif, 10% Événement, 5% Promise, 5% Merlin Direct |

---

## 2. Questions Ouvertes (À Trancher)

### Q1 — Structure des options par carte
> **Statut : DÉCIDÉ ✅ (2026-03-11)**

**Nombre variable d'options : 1 à 4 selon la situation narrative.**
- Carte narrative simple → 2-3 options
- Carte de crise / dilemme → 2 options (choix binaire fort)
- Carte à opportunités multiples → jusqu'à 4 options
- Carte narrative "inévitable" → 1 option (événement subi, pas de choix)
- Plus de distinction Gauche/Centre/Droite codée en dur — les options sont libres dans leur forme et leurs effets.

### Q2 — Conditions de Victoire/Défaite
> **Statut : DÉCIDÉ ✅ (2026-03-11 — Cycle 2)**

**Principe fondamental** : Il n'existe pas de "mauvaise fin". Toute fin de run est valide et porteuse de sens narratif. Finir tôt n'est pas un échec — c'est un autre chemin.

**Architecture des fins :**
- **Multiple endings** : chaque run peut se terminer de nombreuses façons différentes
- **Toujours progression** : quel que soit le dénouement, le joueur progresse (Oghams conservés ? Roguelite ?)
- **Fins par faction** : si réputation ≥ 80 avec une faction → fin thématique de cette faction disponible
- **Fins narratives inattendues** : certaines cartes/combinaisons déclenchent des fins uniques
- **Fin "naturelle"** : le run peut aussi s'achever simplement quand le cycle de cartes s'épuise

**Ce que ça implique techniquement :**
- `merlin_constants.gd` : les 12 "chutes" + 3 "victoires" + 1 secrète → **reclassées comme 16 fins distinctes sans hiérarchie**
- Chaque fin a un poids narratif propre, pas de score
- La réputation faction ≥ 80 = fin de faction disponible (déclenchée en fin de run selon contexte)

### Q3 — Ressource "coût" de l'option Centre
> **Statut : DÉCIDÉ ✅ (2026-03-12)**

**Options gratuites — plus de coût.** Le Souffle est supprimé sans remplacement.
Les 1-4 options variables + la réputation factions fournissent assez de profondeur stratégique.
Il n'y a plus de distinction Gauche/Centre/Droite — donc plus de "centre" à facturer.

### Q4 — Système de Réputation : affichage et poids
> **Statut : DÉCIDÉ ✅ (2026-03-12)**

**Écran stats dédié.** Les factions ne sont pas affichées dans le HUD principal.
Le joueur consulte sa réputation via un menu/écran dédié. Le HUD reste clean et narratif.

---

## 3. Architecture Technique Cible (Post-Triade)

### 3.1 État du jeu (merlin_store.gd)

```gdscript
# État minimal post-Triade
{
  "tour": int,
  "ogham_actif": String,           # Ogham courant
  "oghams_decouverts": Array,      # Oghams vus pendant le run
  "factions": {
    "druides": float,              # 0.0 - 100.0
    "anciens": float,
    "korrigans": float,
    "niamh": float,
    "ankou": float
  },
  "cartes_jouees": Array,
  "run_active": bool,
  "heure_debut_run": int           # timestamp Unix pour cycle jour/nuit
}
```

### 3.2 Effets de Cartes (merlin_effect_engine.gd)

```
ADD_REPUTATION:faction:amount   # ✅ Conservé
UNLOCK_OGHAM:ogham_name         # ✅ À créer
PLAY_SFX:sound_id               # ✅ Conservé
SHOW_DIALOG:dialog_id           # ✅ Conservé
TRIGGER_EVENT:event_id          # ✅ Conservé
PROMISE:promise_id              # ✅ Conservé
```

Effets supprimés :
```
SHIFT_ASPECT:aspect:delta       # ❌ Supprimé
ADD_ASPECT_ALIGNMENT:aspect:amt # ❌ Supprimé
USE_SOUFFLE                     # ❌ Supprimé
ADD_SOUFFLE                     # ❌ Supprimé
```

### 3.3 Contexte LLM (context_builder.gd)

Nouveau format du prompt contexte :
```
Tour: {tour}
Ogham actif: {ogham_actif}
Factions: Druides={druides}, Anciens={anciens}, Korrigans={korrigans}, Niamh={niamh}, Ankou={ankou}
Oghams découverts: {liste}
Heure: {heure_normalisee} ({periode}: aube/jour/crépuscule/nuit)
Saison: {saison} | Festival: {festival_actif_ou_none}
```

---

## 4. Système de Réputation (Détail)

Source : `docs/20_card_system/DOC_15_Faction_Alignment_System.md`

| Faction | Thème | Seuil Contenu | Seuil Fin |
|---|---|---|---|
| **Druides** | Connaissance, nature, druides | 50 | 80 |
| **Anciens** | Traditions, ancêtres, magie ancienne | 50 | 80 |
| **Korrigans** | Chaos, fées, trickery | 50 | 80 |
| **Niamh** | Amour, Tír na nÓg, nostalgie | 50 | 80 |
| **Ankou** | Mort, passage, nuit | 50 | 80 |

**Effets des seuils :**
- **≥ 50** : Cartes spéciales de la faction débloquées dans le pool
- **≥ 80** : Fin narrative de la faction disponible (déclenchée en fin de run)

---

## 5. Cycle Jour/Nuit (Détail)

**Source** : `scripts/broceliande_3d/broc_day_night.gd` (existant, à étendre)

### Périodes (heure système) :
| Période | Plage | Ambiance |
|---|---|---|
| Aube | 05h-08h | Lumière dorée, Druides actifs (+10% réputation) |
| Jour | 08h-18h | Lumière naturelle, cartes équilibrées |
| Crépuscule | 18h-21h | Lumière orangée, Korrigans actifs (+10%) |
| Nuit | 21h-05h | Obscurité, Ankou actif (+15% réputation Ankou) |

### Saisons (date système) :
| Saison | Mois | Festival | Effet |
|---|---|---|---|
| Hiver | Déc-Fév | Imbolc (Fév) | Pool Niamh +20% |
| Printemps | Mar-Mai | Beltane (Mai) | Pool Druides +20% |
| Été | Juin-Août | Lughnasadh (Août) | Pool Anciens +20% |
| Automne | Sep-Nov | Samhain (Oct) | Pool Ankou +30% |

---

## 6. Oghams (18) — Système de Progression

Les 18 Oghams sont des clés narratives qui se débloquent pendant le run.
Chaque Ogham débloqué ouvre de nouvelles options de cartes et dialogues de Merlin.

**Statut actuel** : Définis dans `merlin_constants.gd` — le système de déblocage est à créer.

---

## 7. Changelog

| Date | Cycle | Changement |
|---|---|---|
| 2026-03-11 | Init | Création du document — suppression Triade validée |
| 2026-03-11 | Cycle 2 | Q2 décidée : fins multiples sans hiérarchie win/lose, toujours progression |
| 2026-03-11 | Cycle 2 | Impl parallèle : merlin_reputation_system.gd + game_time_manager.gd |
| 2026-03-12 | Cycle 3 | Q3 décidée : options gratuites (pas de coût Souffle) |
| 2026-03-12 | Cycle 3 | Q4 décidée : factions dans écran stats dédié (pas dans HUD) |
| 2026-03-12 | Cycle 3 | Nettoyage refs Triade : SOUFFLE_START, TRIADE_NODE_TYPES, TRIADE_ASPECTS |

---

*Ce document est la propriété du Studio M.E.R.L.I.N. — co-écrit entre l'utilisateur (vision) et les agents (implémentation).*
