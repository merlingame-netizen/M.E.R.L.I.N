# 🍻 Site cagnotte EVG d'Alexandre

Petit site statique (GitHub Pages) pour héberger le RIB et un compteur de cagnotte
pour l'enterrement de vie de garçon d'Alexandre (logement + cadeaux).

## 📁 Les fichiers

| Fichier | Rôle |
|---------|------|
| `index.html` | La page (rien à toucher) |
| **`config.js`** | **👉 Le seul fichier à modifier** : montant, objectif, date, lieu, message, participants |
| `rib-maxime-babonneau.pdf` | Le RIB téléchargeable |

## ✏️ Mettre à jour le compteur

1. Ouvre **`config.js`**
2. Change `montant_recolte` (et `objectif` quand tu l'auras)
3. Ajoute des participants dans la liste `participants`
4. Sauvegarde → `commit` → `push`. La page se met à jour toute seule.

```js
montant_recolte: 250,        // ce qui est déjà récolté
objectif: 800,               // ta cible (jauge)
participants: [
  { nom: "Thomas", montant: 50 },
  { nom: "Julie",  montant: 30 },
]
```

## 🌐 Activer la mise en ligne (GitHub Pages) — à faire 1 seule fois

1. Sur GitHub : **Settings** → **Pages**
2. *Source* : **Deploy from a branch**
3. Branche : `claude/gitpage-evg-fundraiser-zFJm0` (ou `main` après fusion), dossier `/ (root)`
4. **Save**, attends ~1 min.

La page sera accessible à :

```
https://<ton-pseudo-github>.github.io/M.E.R.L.I.N/evg-alexandre/
```

Partage ce lien aux participants. 🎉

> ℹ️ L'IBAN est fait pour être partagé avec ceux qui te font un virement — c'est son usage normal.
> La page est en `noindex` (non référencée par Google).
