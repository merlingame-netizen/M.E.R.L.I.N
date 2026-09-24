# Charte P1 : Gravure sur bois

## 1. Intention
Chaque écran est une planche d'un livre de légendes taillée dans le même bois : encre, papier, un ton moyen, et l'or seulement sur ce qui est à toi. Merlin est la gravure la plus fouillée ; le monde autour reste sobre et se lit de loin.

Mots-clés : canif, taille d'épargne, hachure, encre grasse, incunable, veillée, rehaut d'or.

**Deux polarités, une grammaire.** Le support décide :
- **nuit** (décor, menu, panneaux, bulle) : taille blanche façon Bewick, traits clairs creusés dans le noir ;
- **page** (cartes, parchemins, sur CREAM) : encre sur papier.

Épaisseurs et motifs identiques ; seule la couleur du trait s'inverse.

## 2. Grammaire de forme
u = unité du viewBox 1600×900 (canevas 1920 : ×1,2 ; aperçu 680 : ×0,425, plancher 1 px). Tout trait est en `vector-effect="non-scaling-stroke"` et ne se met jamais à l'échelle.

| Trait | u | px 1920 | px 680 | Usage |
|---|---|---|---|---|
| ENC | 3,5 | 4,2 | 1,5 | contour extérieur |
| INT | 1,75 | 2,1 | 1 | plis, glyphes, filets |
| HACH | 1,25 | 1,5 | 1 | ombres |

- ENC/INT = 2, partout.
- `butt` + `miter` (limite 3) : coupe franche, jamais d'arrondi.
- Courbes facettées en segments de 8 à 14 u ; aucune Bézier lisse visible au-delà de 40 u.
- Irrégularité dans la géométrie, jamais en filtre : sommets décalés de ±0,6 u, graine fixe par objet, calculés une fois.
- Détail par hauteur (px 1920) : < 48, silhouette + 1 INT ; 48 à 120, 3 INT + 1 zone hachurée ; 120 à 300, contre-hachure ; > 300, complet.
- Tout objet reste reconnaissable en encre pleine. Deux formes superposées sont séparées par une épargne de 2 u.

## 3. Valeurs et couleurs
4 valeurs par écran, plus l'or et le violet :

| Valeur | Rôle | Couleurs |
|---|---|---|
| V0 | encre | SILHOUETTE #0E0B07, seul noir |
| V1 | bois | BG_DEEP, BG_PAGE, PANEL, SURFACE |
| V2 | ton moyen | DIM_WARM sur sombre, INK_DIM sur crème, BORDER_BRUN, RING_BG |
| V3 | papier | CREAM, INK sur crème |

Couleurs confinées, jamais en fond : GOLD (à toi, CTA, rehaut), VIOLET (Corruption seule), raretés, archétypes, degrés, EYE_*, MERLIN_BLUE (sur leurs composants), BIOME_* (dans la porte).

| Ajout | Hex | Rôle |
|---|---|---|
| GRAV_TAILLE | #C8B894 | trait clair sur nuit, sous CREAM pour que le texte domine |
| GRAV_PAPIER_FOULE | #D6C8A6 | ombre douce de la page |
| GRAV_OR_REHAUT | #E8CC7A | facette éclairée de l'or |

**Lumière.** Lune et porte, à 10 h 30 : liseré de lune (INT GRAV_TAILLE) en haut-gauche, hachures en bas-droite. Seule exception : Merlin grave, éclairé par en dessous.

**Ombres, 4 crans :** `h6` (pas de 6 u, 45°), `h4` (pas de 4 u), `x4` (45° + 135°), noir plein. Ombre portée : bande `h4` décalée de (+6, +6) u, jamais de flou.

```svg
<pattern id="h4" width="4" height="4" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
  <line x1="0" y1="0" x2="0" y2="4" stroke="var(--hach)" stroke-width="1.25"/>
</pattern><!-- h6 : 6×6 ; x4 = h4 + copie à rotate(135) -->
```

`--hach` vaut SILHOUETTE sur page, GRAV_TAILLE à 40 % sur nuit. Pas de hachure sous 48 px (moiré) ; à 680 px, pas ×1,5.

**Grain.** `feTurbulence` (0,85, 2 octaves, alpha 0,06) rendu une fois en image, en `background-image` des calques statiques et du papier, jamais sur un calque animé. Le grain d'encre vit dans le contour.

**Feuille d'or.** Aplat GOLD, facette GRAV_OR_REHAUT au tiers haut-gauche, `h4` GOLD_DARK côté ombre, contour ENC. Aucun dégradé ; seuls halos permis : disques radiaux précalculés (lune, orbe).

**Violet.** Encre qui bave : contour cassé en segments décalés de 1 à 3 u.

## 4. Typographie
- **IM Fell English SC** : titre, titres de récit, nom de biome, en-tête « MERLIN ».
- **EB Garamond** 400/600 et italique : tout le reste.
- Tailles FS 36/40/26/22/20, minimum 16, interlignage 1,4. Boutons en petites capitales 600, interlettrage 0,06 em.
- `M·E·R·L·I·N` : 64 px GOLD, interlettrage 0,14 em, contour ENC encre (`paint-order: stroke`), relief par copie encre décalée de (+2, +2) px ; respiration par un calque CREAM (opacité 0 à 0,35, 6 s).

## 5. Composants
**Bouton de menu 520×66.**
- Repos : disque PANEL 52, contour ENC, liseré ; glyphe, libellé, filet-diamant en DIM_WARM.
- Survol/focus (≤ 0,1 s) : disque en or, glyphe encre, libellé CREAM, gloire de 8 rayons INT GOLD (pas de halo).
- Appui : échelle 0,97 en 0,06 s, glyphe décalé de (+1, +1).
- Grisé : `h6` DIM_WARM à 50 %, sans liseré.

**Panneau.** PANEL, contour ENC, filet INT DIM_WARM à 6 u, coins biseautés de 8 u, ombre hachurée.

**Anneau 78.** Piste RING_BG entre 2 INT encre, remplissage de 6 px : Intégrité GREEN (bas-droite en `h4` GREEN_DARK), Corruption en 5 segments VIOLET entaillés. Glyphe central et valeur (20) en CREAM.

**Nœud de chemin 40.** Passé : DIM_WARM en `x4`. Courant : or qui pulse. Futur : contour INT DIM_WARM. Tracé plein, puis `stroke-dasharray: 2 5` pour la partie à venir.

**Empreinte de tag 56.** Creux BG_DEEP, contour INT et glyphe DIM_WARM. Une fois couverte : glyphe et contour ENC GOLD, gloire de 8 rayons.

**Carte 180×270 (page).** Anatomie du kit F, avec :
- CREAM grainé ; bordure de rareté doublée d'un INT encre à 3 px ;
- rune : tige ENC, entailles INT, `h6` à droite ;
- bande : mot en 19 gras CREAM (PAROLE en encre) ;
- gemme : losange VIOLET à 2 facettes, chiffre CREAM.

| Rareté | Traitement |
|---|---|
| Commune | filet simple |
| Rare | double filet RARE_BLUE, 4 coins entaillés |
| Épique | double filet, 3 fleurons symétriques ; la symétrie l'oppose à la Corruption |
| Mythique | bordure en or ; gloire de 12 rayons (opacité 0,5 à 1, 2,4 s) ; reflet `h4` GRAV_OR_REHAUT toutes les 6 s |
| Corrompue | bordure VIOLET cassée, fissure zigzag ENC doublée VIOLET, 2 taches bavées, tremblement du kit |

Survol : ×1,18 et -30 px en 0,12 s, l'ombre s'allonge ; évocation en italique 20 INK.

**Parchemin 420×560.** Papier CREAM grainé, bords taillés (±2 u), rouleaux en `h4` côté droit, symbole de faction en encre (64) avec une seule touche de couleur, titre IM Fell 36, bouton « Suivre ce sentier » en feuille d'or avec texte encre.

**Pill de degré 170×48** (le « sceau », R135). Aplat du degré, contour ENC, pastille CREAM de 32 gravée (losange fêlé, demi-disque, disque, étoile à 8 branches), libellé 19 gras CREAM, entrée en tampon.

**Bulle de Merlin.**
- MERLIN_SPEECH_BG, contour ENC, liseré INT MERLIN_SPEECH_BORDER à 4 u, coins biseautés, queue taillée vers le portrait.
- En-tête : 2 barres EYE_NEUTRAL + « MERLIN » IM Fell 20.
- Texte MERLIN_BLUE, 26 au menu, 22 au plateau.

**Pictogrammes.** Grille 48 u, 6 formes au plus, silhouette ENC, détails INT, facettés.

| Glyphe | Recette |
|---|---|
| Sens | œil en amande, pupille losange, 3 cils |
| Force | poing de profil, 4 entailles |
| Empathie | 2 mains en coupe jointes |
| Verbe | banderole ondulée, 3 traits |
| Instinct | 3 griffures courbes |
| Nature | feuille de chêne à 5 lobes |
| Savoir | livre ouvert, 3 lignes |
| Sacrifice | vasque, goutte |
| Franchise | main ouverte levée |
| Factions | gui, lanterne, épée brisée (kit D) ; spirale voilée pour les Corrompus |
| Biomes | motifs du kit A ; sceau (cercle, 2 liens croisés, point) |

Autres glyphes G10 : même recette.

## 6. Merlin, portrait gravé
**Calques précalculés**, du fond vers l'avant :
- cadre : arche PANEL, `h6` à droite, ENC, filet INT GOLD ;
- fond : hachure horizontale MIST, nimbe CREAM à 20 % ;
- manteau et col : encre pleine, plis GRAV_TAILLE, fermoir GOLD ;
- tête : MERLIN_SLATE, côté droit en `h4` MERLIN_SLATE_DARK, nez et rides en INT ;
- mèches et barbe : MERLIN_ASH, gouges INT, perle GOLD ;
- orbites en encre, puis yeux : barres EYE_* avec halo en rectangle 3 fois plus large à 25 %, sans flou, point le plus clair du visage ;
- sourcils (3 mèches, pivot intérieur), bouche (3 poses) ;
- main gauche (7 poses échangées), main droite et orbe en or (halo précalculé, 3 étincelles).

**Expressions.** Valeurs au format menu ; ×0,67 en Sélection, ×0,37 au plateau.

| Expression | Sourcils (y, rotation) | Barres | Bouche | Main G | Tête |
|---|---|---|---|---|---|
| Neutre | 0, 0° | 1 NEUTRAL | fermée | repos | 0° |
| Taquin | G -8/+12° | G 1, D 0,35 | coin relevé | « viens » | +4° |
| Intrigué | G -10, D -8° | 1,1 SURPRISE | pincée | menton | -8° |
| Inquiet | -6, intérieur +15° | 0,6 pâle | tombante | poitrine | épaules +2 |
| Grave | +6 | 0,4 assombri | serrée | clocher | `x4` sur le front |
| Émerveillé | -12 | 1,3 SURPRISE, +20 % | mi | doigts écartés | orbe ×1,1 |
| Désapprobateur | +4, intérieur -20° | 0,7 ANGRY, x -4 | V inversé | revers | -6° |

Idle, parole et déclencheurs : kit C.

**Entre 110 et 170 px.** Épaisseurs fixes : la vignette engraisse, c'est voulu. On retire rides, mèches fines et hachures, sauf le noir du col. Barres ≥ 3×10 px, sourcils ≥ 4 px. Silhouette + 2 barres suffisent à reconnaître Merlin.

## 7. Le Seuil
Positions du kit B, tout en nuit :
- ciel BG_DEEP, 14 étoiles en croix, lune-œil CREAM à anneau INT GOLD ;
- trilithe PANEL : ENC, `h6`/`h4` à droite, liseré à gauche ;
- 8 menhirs identiques, glyphe incisé en INT ;
- brume : 3 bandes de hachure horizontale MIST, 20 s ;
- aucun biome hors de l'ouverture.

| Statut | Vignette | Pierre |
|---|---|---|
| Débloqué | gravure complète (BIOME + encre + tailles), animée | glyphe GOLD qui respire de 0,6 à 1 |
| Entrouvert | voile `h4` CREAM levé à 40 %, filet GOLD qui fuit | glyphe DIM_WARM |
| Scellé | silhouette SILHOUETTE sur `h6` MIST, sceau DIM_WARM | glyphe DIM_WARM à 60 % |

**Changement de biome : le rouleau (0,6 s).** Une bande `x4` de 40 u traverse l'ouverture de gauche à droite : l'ancienne vignette s'efface derrière, la nouvelle apparaît dans son sillage.

**Glitch des scellés :** double GRAV_TAILLE décalé et tremblé (amplitudes du kit), par crans.

## 8. Animation
Durées §21 inchangées. Courbes : ease-out (tap, pulse, float_delta), cubic-bezier(.2,.8,.2,1) (fast, ui), cubic-bezier(.34,1.56,.64,1) (deal), ease-in (discard), linear (veil).

**Ajouts :** taille (trait qui s'écrit par dashoffset, 0,6 s, ease-in-out), tampon (0,12 s, back-out), rouleau (0,6 s, linear).

**Deux régimes.** Interface fluide ; ambiance (inventaire du kit, motes en losange) en tirage à pas, 12 images par seconde (`steps()` ou rAF bridé).

**Budget CPU.** Transform et opacity seulement, 1 canvas, 24 particules au plus, aucun `filter` animé, pause quand l'onglet est caché.

**Mouvement réduit.** Durées divisées par 2, ambiance figée, secousses coupées, glitch ≤ 0,1, voile VIOLET à 6 % et pastille.

## 9. Lisibilité
**Contrastes :** sur BG_PAGE, CREAM 12:1, DIM_WARM 5:1, GOLD 7:1 ; sur CREAM, INK 11:1, INK_DIM 4,9:1 ; encre sur GOLD 8:1.

- Bandes et pills : 19 px gras, soit un grand texte, seuil 3:1.
- INK_DIM jamais sur fond sombre.
- Jamais de texte sur hachure : aplat uni (PANEL ou CREAM) qui déborde de 12 u.

**Test des 2 s :** flou de 4 px (CTA, barres de Merlin et jauges restent repérables), niveaux de gris (chaque état se distingue par sa forme), silhouette de chaque pictogramme lisible à 40 px.

## 10. Portage Godot
**MerlinVisual** : GRAV_* (3), STROKE_ENC 4.2, STROKE_INT 2.1, STROKE_HACH 1.5, HATCH_PITCH 4/6.

**Rendu :**
- Contours : `draw_polyline(pts, c, w, true)` sur des `PackedVector2Array` décalés et mis en cache.
- Aplats : `Polygon2D` triangulé une fois (garde #52).
- Hachures : 3 `ImageTexture` 64×64 tuilables générées au démarrage, en `texture_repeat`, sans shader.
- Panneaux et grain : `StyleBoxTexture` 9-patch ; calque statique redessiné au seul redimensionnement.
- Merlin : un `Node2D` par calque, tweens transform et modulate, mains échangées par `visible`.

**Coûteux :** triangulation à chaque image, hachures en `draw_line`, halos empilés, particules en nœuds, `StyleBox` dans `_draw`, shaders plein écran. Cible : Compatibility.

## 11. Checklist de cohérence
1. SILHOUETTE est le seul noir.
2. Contour ENC, détail INT, hachure HACH, en non-scaling-stroke partout.
3. `butt`/`miter`, jitter à graine fixe ; aucune courbe lisse > 40 u.
4. Polarité : clair sur sombre, encre sur crème.
5. Hachures en bas-droite, liseré en haut-gauche.
6. Aucun flou, `box-shadow` ni dégradé, hors halos de la lune et de l'orbe.
7. ≤ 4 valeurs par écran, plus l'or et le violet.
8. Or = interactif, focus, à toi.
9. VIOLET = Corruption seule ; Épique à fleurons symétriques.
10. BIOME_* seulement dans la porte.
11. Aucune icône générique ; aucune hachure sous 48 px.
12. 2 polices ; texte ≥ 16 px.
13. Aucun texte sur hachure ; contraste ≥ 4,5:1, ou ≥ 3:1 pour 19 px gras.
14. Barres = point le plus clair ; pas de pupille, chapeau, capuche, ni corps entier.
15. Main droite sur l'orbe, sauf en grave.
16. Ambiance à 12 i/s ; retour ≤ 0,1 s ; interface ≤ 0,5 s hors fusion et voile.
17. Rareté lisible sans couleur.
18. Degré = couleur + pastille + libellé.
19. Carte, médaillon, pierre et bouton : même trait, même lumière, même grain.
20. Mouvement réduit : ambiance figée, indice statique présent.
