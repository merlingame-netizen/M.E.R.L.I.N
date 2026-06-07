# Branding Registry — charte par contexte (RÈGLE PRIORITAIRE)

> **À lire EN PREMIER, avant tout choix esthétique.** Le `/design` skill choisit
> la palette/typo selon le **contexte du projet**, pas selon une préférence
> arbitraire. L'ordre de priorité ci-dessous n'est **pas négociable**.

## Algorithme de sélection de charte

```
1. Le projet est-il un projet ORANGE (ou demande explicitement la marque Orange) ?
   → OUI : charte ORANGE obligatoire (design system Boosted). NE PAS appliquer le
           style signature sombre. Respecter l'identité Orange à la lettre.
2. Le client/marque est-il connu (registre ci-dessous : IDRAC, …) ?
   → OUI : appliquer SA charte (couleurs/typo/ton réels extraits de ses assets).
3. Le projet hôte impose-t-il un design system (tokens, UI bible) ?
   → OUI : il prime. S'y conformer.
4. Sinon (app/site HTML autonome hors Orange, pas de charte imposée)
   → style signature « Dark Animated » (styles/signature-dark-animated.md),
     teintes adaptées au sujet.
```

**Détection « projet Orange »** : chemin/َrepo contenant `orange`, `edh`, `bcv`,
`bigquery` Orange, PowerBI Orange, `partage voc`, ou mention explicite. En cas de
doute → **demander** (AskUserQuestion) plutôt que supposer.

---

## ORANGE — `#FF7900` (OBLIGATOIRE sur projets Orange)

Design system officiel : **Boosted** (surcouche Bootstrap d'Orange).
- **Primaire** : Orange `#FF7900` (jamais un autre orange).
- **Neutres** : noir `#000000`, blanc `#FFFFFF`, gris `#CCCCCC` `#999999`
  `#666666` `#333333` `#141414`.
- **Fonctionnels (Boosted)** : succès `#32C832`, info `#527EDB` /`#4BB4E6`,
  alerte `#FFCC00`, erreur `#CD3C14`.
- **Palette support** : `#FFB400` `#FFD200` `#50BE87` `#4BB4E6` `#A885D8`
  `#FFB4E6` `#D9C2F0` `#B5E8F7` `#B8EBD6` `#FFE8F7`.
- **Typo** : **Helvetica Neue** / Arial (système Orange) — PAS Montserrat/Inter.
- **Ton** : clair, accessible (Orange vise WCAG AA strict), sobre, corporate.
- **Logo** : carré orange, ne jamais déformer.
- **Règles** : fond plutôt clair, orange en accent fort ; animations **sobres**
  et fonctionnelles (Orange n'est pas un site « hyper animé » dark). La perf et
  l'accessibilité priment sur le spectacle.
- Réf : Boosted (boosted.orange.com) + Orange Brand. Vérifier la version courante
  du design system avant livraison.

> Sur Orange, le « max pack » d'animations est **bridé** : micro-interactions
> utiles, transitions douces, zéro fond sombre/néon. Marque > effet.

---

## IDRAC Business School — `#A71F28` + `#f5b731`

Charte extraite des assets réels du site AI Marketing Academy.
- **Rouge bordeaux** `#A71F28` (clair `#d4343f`, sombre `#7a161d`).
- **Or** `#f5b731`. Accents : cyan `#38bdf8`, vert `#34d399`, violet `#a78bfa`,
  rose `#f472b6`, orange `#fb923c`.
- **Fond sombre** `#0a0a12` / `#10101e`.
- **Gradient signature** : `linear-gradient(135deg,#A71F28,#d4343f,#f5b731)`.
- **Typo** : **Montserrat** (titres 800-900) + **Space Mono** (accents).
- Compatible style « Dark Animated » → max animations OK.
- Réf : `demos/idrac/index.html`.

---

## DÉFAUT — Signature « Dark Animated »

Hors Orange et hors charte imposée → `styles/signature-dark-animated.md`.
Fond sombre, accent bi-couleur en dégradé adapté au sujet, animations empilées,
perf en pilier. Réf : `demos/aurora/index.html`.

---

## Ajouter une marque

Pour enregistrer une nouvelle charte client : créer une section ici avec
couleurs (hex), typo, ton, règles d'animation, et la source (assets/site). Le
`/design` skill la lira automatiquement.
