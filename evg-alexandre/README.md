# 🛶 Site EVG d'Alexandre — Vallon-Pont-d'Arc (nuit du 18 au 19 juillet 2026)

Site statique (GitHub Pages) ultra-interactif : cagnotte + RIB + choix du
logement et des activités avec budget par personne calculé en direct.

## 📁 Les fichiers

| Fichier | Rôle |
|---------|------|
| `index.html` | La page interactive (rien à toucher) |
| **`config.js`** | **👉 Le seul fichier à modifier** : compteur, statuts de dispo, prix, activités, participants |
| `rib-maxime-babonneau.pdf` | Le RIB téléchargeable |
| `whatsapp.md` | Messages WhatsApp prêts à coller + checklist résas urgentes |

## 🎮 Ce que fait la page

- **Cagnotte** : compteur animé (`montant_recolte`)
- **Logement** : 7 vraies options recherchées le 10/06 (5 pers, 1 nuit), 1 seul
  choix par personne, bouton « Vérifier la dispo » (annonce avec dates pré-remplies)
- **Activités** : 15 options réelles (canoë, rando, soirées, sensations) en
  multi-choix avec prix 2026 vérifiés
- **Budget live** : (logement ÷ nb de participants) + activités cochées, dans une barre flottante
- **Envoi WhatsApp** : chaque copain envoie ses choix + budget dans le groupe
- Les choix sont mémorisés sur l'appareil (localStorage)

## ✏️ Mises à jour courantes (dans `config.js`)

```js
montant_recolte: 250,          // le compteur de la cagnotte

// après avoir appelé un gîte / un loueur :
statut: "dispo"                // ✅  ("a_verifier" 🔍, "option_posee" ⏳, "complet" ❌)

participants: [
  { nom: "Thomas", montant: 50 },
]
```

Une carte passée en `"complet"` se grise et devient non-sélectionnable.

## 💰 Cagnotte sans frais

Deux options 100 % gratuites (voir `whatsapp.md` pour le pas-à-pas) :
- **Virement sur le RIB** (déjà affiché) — virement instantané gratuit depuis 2025.
- **OnParticipe** — pot en ligne 0 commission au retrait. Crée la cagnotte sur
  onparticipe.fr, puis colle son URL dans `lien_cagnotte` (config.js) → le bouton
  « 🔗 Participer à la cagnotte » s'active. Le suivi de qui a payé se fait dans le
  tableau `participants`.
- ❌ À éviter : Leetchi / Le Pot Commun (4-6 % de frais au retrait bancaire).
Sauvegarde → commit → push : la page se met à jour toute seule.

## 🌐 Activer GitHub Pages (1 seule fois)

1. Sur GitHub : **Settings** → **Pages**
2. *Source* : **Deploy from a branch**
3. Branche : `claude/gitpage-evg-fundraiser-zFJm0` (ou `main` après fusion), dossier `/ (root)`
4. **Save**, attends ~1 min → `https://<ton-pseudo>.github.io/M.E.R.L.I.N/evg-alexandre/`

## ⚠️ Vérification de dispo — comment ça marche

GitHub Pages ne peut pas interroger Airbnb/Booking en direct (site statique,
pas de serveur). Le système :
1. Chaque carte a un bouton **« Vérifier la dispo »** → ouvre l'annonce ou la
   recherche avec **nuit du 18 au 19/07 et 5 voyageurs déjà réglés** (1 tap)
2. Après vérification (ou appel), tu mets à jour le champ `statut` dans
   `config.js` → tout le groupe voit ✅ / ⏳ / ❌ en temps réel au prochain push

## 📞 Pistes logement prioritaires (recherche du 10/06)

| Gîte | Contact | Pourquoi |
|------|---------|----------|
| **Les Trois Eaux (Vagnas)** | 06 60 51 20 65 | Week-ends sur demande, groupes bienvenus, piscine chauffée |
| **L'Azuré (St-Remèze)** | 06 10 62 62 31 (WhatsApp) | 10-15 pers, piscine + spa, village à pied |

Mi-juillet beaucoup de gîtes ne font que la semaine — appeler vite, et annoncer
« week-end entre amis » plutôt que « EVG » (certains gîtes refusent les EVG).

> ℹ️ La page est en `noindex` (non référencée). L'IBAN est fait pour être
> partagé avec ceux qui te font un virement — usage normal.
