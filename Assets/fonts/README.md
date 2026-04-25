# Fonts — M.E.R.L.I.N. Visual Direction v3

> Décidé 2026-04-25. Source : `docs/70_graphic/VISUAL_DIRECTION_v3.md` §2.6

## Polices requises

### 1. Uncial Antiqua (titres / Oghams / sacré)

- **Source** : Google Fonts — https://fonts.google.com/specimen/Uncial+Antiqua
- **License** : OFL (libre)
- **Usage** : titres de cartes, dialogues Merlin, noms d'Oghams, capitales narratives, écran de fin de run
- **Couleur d'application** : `celtic_gold` (`#AE8C52`)
- **Tailles cibles** : 32-72px

### 2. m6x11 (corps texte / UI / minigames)

- **Source** : itch.io — https://managore.itch.io/m6x11 (gratuit, CC0-like)
- **Auteur** : Daniel Linssen
- **Usage** : descriptions de cartes, options de choix, HUD, chiffres flottants, panneaux UI
- **Couleur d'application** : `ink` (`#382D24`) sur parchemin, blanc cassé sur fond sombre
- **Tailles cibles** : 11-16px (pixel-perfect)

## Installation

1. Télécharger les `.ttf` depuis les sources ci-dessus
2. Les placer dans ce dossier (`assets/fonts/`)
3. Importer dans Godot (auto-détection à l'ouverture du projet)
4. Créer les `FontFile` resources dans `assets/fonts/*.tres` si besoin de variations
5. Référencer dans `MerlinVisual` autoload (à étendre)

## STATUT 2026-04-25

- [x] `UncialAntiqua-Regular.ttf` téléchargée (63 KB, source : google/fonts mirror)
- [x] `VT323-Regular.ttf` téléchargée (153 KB, **alternative à m6x11** — Google Fonts, style PS1/terminal, support français complet)
- [x] `PressStart2P-Regular.ttf` téléchargée (118 KB, bonus 8-bit pour cas particuliers)
- [ ] Créer `MerlinVisual.FONT_TITLE` et `MerlinVisual.FONT_BODY` references dans le code

### Pourquoi VT323 au lieu de m6x11 ?

Le m6x11 original (Daniel Linssen / Managore) n'est disponible que sur itch.io avec download token, donc non-installable via curl/headless. **VT323** (Peter Hull, OFL, Google Fonts) couvre la même niche esthétique : police bitmap monospace style PS1/CRT terminal, parfaite pour le corps de texte du jeu, support complet des accents français.

Si tu veux le m6x11 authentique, il faut :
1. Aller sur https://managore.itch.io/m6x11
2. Cliquer "Download" (gratuit)
3. Extraire `m6x11plus.ttf` depuis le ZIP
4. Le placer ici dans `assets/fonts/m6x11plus.ttf`
5. Référencer dans `MerlinVisual.FONT_BODY`

Le code peut détecter dynamiquement laquelle est présente.
