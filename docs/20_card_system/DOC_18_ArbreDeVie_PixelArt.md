# DOC_18 — Arbre de Vie : Pixel Art Procédural

**Version**: 1.0 | **Date**: 2026-02-26 | **Statut**: ACTIF

---

## 1. Concept

L'Arbre de Vie est la représentation visuelle de la progression du Voyageur.
Il se génère procéduralement en pixel art : au départ, seule la **souche** est visible.
À chaque talent débloqué, une nouvelle branche ou feuille apparaît avec une animation de croissance.

**Principes** :
- Pure `_draw()` — aucun nœud scène enfant
- Positions normalisées (0..1) → indépendant de la résolution
- Croissance animée par tween (scale 0→1 par nœud)
- 4 branches de couleurs distinctes (TALENT_BRANCH_COLORS)

---

## 2. Mapping Spatial Branches → Directions

```
           CIMES (haut)
    AME           MONDE
  (haut-gauche) (haut-droite)
        \       /
         TRONC
        (centre)
        /
  CORPS
(bas-gauche)
         SOUCHE (bas-centre)
```

| Branche | Animal | Direction | Couleur (TALENT_BRANCH_COLORS) |
|---------|--------|-----------|-------------------------------|
| Corps   | Sanglier | Bas-gauche (racines) | Marron terra `#8B5E3C` |
| Ame     | Corbeau  | Haut-gauche (ramures) | Bleu `#4A7FA5` |
| Monde   | Cerf     | Haut-droite (feuillage) | Vert `#5A8A5A` |
| Universel | Tronc | Centre vertical | Ambre `#C8A04A` |

---

## 3. Layout Algorithmique — 28 Nœuds

Coordonnées normalisées (x: 0=gauche, 1=droite ; y: 0=haut, 1=bas).
La souche est en `(0.50, 0.90)`. Le tronc monte vers `(0.50, 0.10)`.

### Corps (Sanglier) — 8 nœuds

| ID | Tier | x | y |
|----|------|---|---|
| racines_1 | Germe | 0.20 | 0.72 |
| racines_2 | Germe | 0.30 | 0.68 |
| racines_3 | Germe | 0.15 | 0.65 |
| racines_4 | Pousse | 0.18 | 0.52 |
| racines_5 | Pousse | 0.25 | 0.48 |
| racines_6 | Branche | 0.14 | 0.36 |
| racines_7 | Branche | 0.22 | 0.32 |
| racines_8 | Cime | 0.12 | 0.20 |

### Ame (Corbeau) — 8 nœuds

| ID | Tier | x | y |
|----|------|---|---|
| ramures_1 | Germe | 0.35 | 0.55 |
| ramures_2 | Germe | 0.28 | 0.50 |
| ramures_3 | Germe | 0.32 | 0.45 |
| ramures_4 | Pousse | 0.25 | 0.38 |
| ramures_5 | Pousse | 0.33 | 0.34 |
| ramures_6 | Branche | 0.22 | 0.24 |
| ramures_7 | Branche | 0.30 | 0.20 |
| ramures_8 | Cime | 0.20 | 0.12 |

### Monde (Cerf) — 8 nœuds

| ID | Tier | x | y |
|----|------|---|---|
| feuillage_1 | Germe | 0.65 | 0.55 |
| feuillage_2 | Germe | 0.72 | 0.50 |
| feuillage_3 | Germe | 0.68 | 0.45 |
| feuillage_4 | Pousse | 0.75 | 0.38 |
| feuillage_5 | Pousse | 0.67 | 0.34 |
| feuillage_6 | Branche | 0.78 | 0.24 |
| feuillage_7 | Branche | 0.70 | 0.20 |
| feuillage_8 | Cime | 0.80 | 0.12 |

### Universel (Tronc) — 4 nœuds + 1 bonus

| ID | Tier | x | y |
|----|------|---|---|
| tronc_1 | Pousse | 0.50 | 0.60 |
| tronc_2 | Branche | 0.50 | 0.42 |
| tronc_3 | Branche | 0.50 | 0.30 |
| tronc_4 | Cime | 0.50 | 0.16 |
| calendrier_des_brumes | Pousse | 0.42 | 0.42 |

---

## 4. États Visuels d'un Nœud

| État | Remplissage | Contour | Alpha | Rayon |
|------|-------------|---------|-------|-------|
| LOCKED | `CRT_PALETTE.bg_dark` | `CRT_PALETTE.locked` (gris) | 0.4 | tier × base |
| AVAILABLE | `CRT_PALETTE.bg_panel` | `CRT_PALETTE.amber_bright` (pulsing) | 1.0 | tier × base |
| UNLOCKED | `branch_color × 0.7` | `branch_color` | 1.0 | tier × base |

**Rayon de base par tier** :
| Tier | Rayon |
|------|-------|
| 1 Germe | 10px |
| 2 Pousse | 13px |
| 3 Branche | 16px |
| 4 Cime | 20px |

---

## 5. Animation de Croissance

Lors du débloquage d'un nœud via `animate_unlock(node_id)` :

```gdscript
# _node_progress[node_id] : float 0.0 → 1.0
# scale = progress (le cercle "pop" en apparaissant)
var tw := create_tween()
tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
tw.tween_method(func(v: float) -> void:
    _node_progress[node_id] = v
    queue_redraw()
, 0.0, 1.0, 0.5)
```

SFX : `SFXManager.play("skill_unlock")` au début de l'animation.

---

## 6. Palette

| Usage | Constante MerlinVisual |
|-------|----------------------|
| Fond arbre | `CRT_PALETTE["bg_dark"]` |
| Lignes connexion UNLOCKED | `TALENT_BRANCH_COLORS[branch]` |
| Lignes connexion LOCKED | `CRT_PALETTE["locked"]` alpha 0.3 |
| Souche tronc | `GBC["dark_gray"]` |
| Glow AVAILABLE | `CRT_PALETTE["amber_bright"]` alpha 0.15 oscillant |
| Contour nœud AVAILABLE | `CRT_PALETTE["amber_bright"]` |

---

## 7. Intégration avec arbre_de_vie_ui.gd

L'`arbre_de_vie_ui.gd` reçoit les états du store et passe les données au pixel art :

```gdscript
# arbre_de_vie_ui.gd
func _refresh_tree() -> void:
    _update_currency_label()
    var unlocked: Array = []
    var available: Array = []
    for nid in MerlinConstants.TALENT_NODES:
        if store.is_talent_active(nid):
            unlocked.append(nid)
        elif store.can_unlock_talent(nid):
            available.append(nid)
    pixel_tree.setup(unlocked, available)
    _update_detail_panel()
```

Signal de retour : `pixel_tree.node_selected.connect(_on_talent_clicked)`
Debloquer : `pixel_tree.animate_unlock(node_id)` avant `_refresh_tree()`

---

## 8. Fichiers Concernés

| Fichier | Rôle |
|---------|------|
| `scripts/ui/arbre_pixel_art.gd` | Nouveau — dessin procédural pixel art |
| `scripts/ui/arbre_de_vie_ui.gd` | Modifié — intégration pixel_tree, suppression VBox texte |
| `scenes/ArbreDeVie.tscn` | Modifié — nœud ArbrePixelArt à la place de TreeScroll |
| `scripts/merlin/merlin_constants.gd` | Lecture seule — TALENT_NODES, TALENT_BRANCH_COLORS |

---

## 9. Évolution Future (28 → 129 nœuds)

La structure de positions normalisées est conçue pour être étendue :
- Chaque branche peut accueillir 30 nœuds (vs 8 actuels) par subdivision de l'espace
- Les ponts inter-branches (12 nœuds) occuperont les zones entre branches
- À 129 nœuds, l'arbre ressemblera à un véritable arbre celtique touffu
- L'animation de croissance reste identique — seul le layout évolue

*Réf : SPEC_TALENT_TREES.md (129 nœuds cible, 90 mineurs + 18 notables + 9 majeurs + 12 ponts)*

---

*Généré par tools/write_doc_18.py | M.E.R.L.I.N. v4.0*
