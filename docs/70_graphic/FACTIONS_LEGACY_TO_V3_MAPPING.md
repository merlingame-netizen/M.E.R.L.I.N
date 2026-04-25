# Mapping Factions Legacy → V3 Totems

> Décidé 2026-04-25. Référence pour la migration code, narrative, et assets.
> Source : `VISUAL_DIRECTION_v3.md` §2.5

## Table de mapping

| Code interne (legacy) | Nom legacy long | Symbole legacy | Nouveau Clân (V3) | Animal totem | Symbolique celtique | Couleur signature |
|----------------------|----------------|----------------|-------------------|--------------|---------------------|-------------------|
| `druides` | Druides de Bretagne | chêne | **Clân du Cerf** | Cerf | Royauté, monde sauvage, savoir des forêts | Brun + or roux (`#6B4226` + `#C7882C`) |
| `anciens` | Les Anciens | menhir | **Clân de l'Ours** | Ours | Force, terre, protection des siens, ancestral | Rouge brique + brun terre (`#8C2A1F` + `#5C3A28`) |
| `korrigans` | Korrigans des Marais | champignon | **Clân du Loup** | Loup | Instinct, espièglerie, chasse en meute | Gris + argent froid (`#5C5C66` + `#B8C0CC`) |
| `niamh` | Niamh et Tir na nOg | lac | **Clân du Saumon** | Saumon | Sagesse ancestrale, mémoire, voyage entre mondes | Bleu profond + nacre (`#1E3A5F` + `#E0E8F0`) |
| `ankou` | L'Ankou | faux | **Clân du Corbeau** | Corbeau | Mort, prophétie, savoir caché | Noir + violet sombre (`#1A0F1F` + `#5B3A8C`) |

## Stratégie de migration

**PHASE 1 — Préservation code (immédiat)** :
- Garder les codes internes `druides / anciens / korrigans / niamh / ankou` partout dans le code (constants, save data, JSON cartes).
- AUCUNE modification de `merlin_constants.gd` ou `merlin_reputation_system.gd`.
- Les nouvelles cartes générées par LLM utilisent ces codes legacy.

**PHASE 2 — Surface visuelle (à venir)** :
- `MerlinVisual.gd` : ajouter `FACTION_TOTEMS` dictionnaire mappant code → animal/couleur/symbole.
- UI : afficher le nouveau nom long ("Clân du Cerf") quand on parle au joueur.
- Le code interne reste inchangé pour la save/load compatibility.

**PHASE 3 — Lore/dialogue (post-implémentation visuelle)** :
- Tous les dialogues Merlin et descriptions de cartes utilisent les nouveaux noms ("Clân du Cerf").
- Les anciens noms (druides, korrigans) peuvent persister comme synonymes narratifs occasionnels.

**PHASE 4 — Assets visuels (asset pipeline)** :
- 5 modèles 3D low-poly de pierres-totems (1 par animal).
- 5 sigils 2D pour les cartes (silhouette de l'animal).
- 5 palettes de bordure cartes.

## Compatibilité save existante

Aucun joueur n'a actuellement de save (jeu en dev). Mais si une save legacy existait :
- Codes internes inchangés → la save est lisible
- Affichage UI applique le mapping → rétrocompatibilité visuelle

## Pour les agents générateurs (LLM, card-generator)

**RÈGLE** : utilisez TOUJOURS les codes legacy dans les champs `faction` du JSON. Le mapping est appliqué côté UI uniquement.

```json
{
  "faction": "druides",   // ← code legacy obligatoire
  "title": "...",
  ...
}
```

Mais dans le texte narratif (titres, dialogues), vous pouvez utiliser les nouveaux noms si vous voulez:

```json
{
  "faction": "druides",
  "title": "Le Clân du Cerf t'observe",
  "description": "Un cerf majestueux apparaît dans la clairière..."
}
```

## Mappings narratifs additionnels

- `chene` (symbole druides) → **Cerf** se cache dans les chênaies sacrées
- `menhir` (symbole anciens) → **Ours** dort sous les menhirs ancestraux
- `champignon` (symbole korrigans) → **Loup** rôde autour des cercles de champignons (cercle des fées)
- `lac` (symbole niamh) → **Saumon** remonte les rivières des Tir na nOg
- `faux` (symbole ankou) → **Corbeau** annonce le passage de l'Ankou
