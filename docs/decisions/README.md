# Les fourches — ce que seul Maxime tranche

Une fourche est un choix qui change l'expérience du joueur et qu'aucun agent ne peut trancher
sans trahir le jeu. **Trois ouvertes au plus.** Le protocole complet est dans `docs/ATELIER.md`.

## Le format

```
---
id: 004
titre: La question, en une ligne
domaine: regles | lore | ecrans | outillage
ouverte: 2026-09-10
etat: ouverte | tranchee | perimee
---

## La fourche
Pourquoi il faut trancher, en cinq lignes. Ce qui se passe si on ne tranche pas.

## Aujourd'hui
Ce que le code fait, avec les fichiers et les mesures.

## Options

### A — Titre court
Ce que ça donne pour le joueur. **Coût** : ce que ça demande et ce qu'on perd. **Mesure** : ce qui dira si ça a marché.

### B — Titre court
…

**Recommandation** : A — pourquoi, en une phrase.

## Réponse
_En attente._
```

## La réponse

Maxime choisit une lettre dans l'onglet Décider du Studio (et peut ajouter une note). La session
suivante grave la réponse ici, sous « Réponse », et passe `etat: tranchee` :

```
**Tranchée le 2026-09-11 : B.** la note de Maxime, si elle existe.
```

Une fourche qui n'a plus de sens (le code a changé, la question s'est dissoute) passe
`etat: perimee` avec une ligne qui dit pourquoi — jamais supprimée : la liste des fourches est
aussi l'histoire des choix.
