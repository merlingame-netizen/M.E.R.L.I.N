# UI/UX Bible — M.E.R.L.I.N.: Le Jeu des Oghams
# Version 1.0 — Systeme Visuel Centralise

> **Source de verite**: scripts/autoload/merlin_visual.gd (MerlinVisual autoload)
> **Style cible**: Kingdom Two Crowns — pixel-inspired, minimaliste, animations subtiles, parchemin

---

## 1. Vision Artistique

### 1.1 Deux mondes visuels

| Monde | Usage | Palette | Texture |
|-------|-------|---------|---------|
| **Parchemin Mystique Breton** | UI narrative, menus, dialogues | MerlinVisual.PALETTE | merlin_paper.gdshader |
| **GBC (Game Boy Color)** | Biomes, gameplay, monde exterieur | MerlinVisual.GBC | Pixel-art 4 couleurs/biome |

**Philosophie**: Le parchemin = l'intimite de Merlin. Le GBC = le monde sauvage. Chaque scene sait a quel monde elle appartient.

### 1.2 Principes fondamentaux

1. **Lisibilite absolue** — Tout texte doit etre lisible en 0.5s, contraste >= 4.5:1
2. **Animations non-bloquantes** — Jamais de freeze input pendant une animation
3. **Coherence typographique** — 3 polices, pas une de plus
4. **Palette unique** — MerlinVisual.PALETTE est la SEULE source de couleurs narratives
5. **Touch-first** — Cibles tactiles >= 48px (MerlinVisual.MIN_TOUCH_TARGET)
6. **Economie visuelle** — Moins d'elements, plus d'impact

---

## 2. Systeme de Couleurs

### 2.1 Palette Parchemin (MerlinVisual.PALETTE)

| Cle | Hex approx | Usage |
|-----|-----------|-------|
| paper | #F7F1E7 | Fond principal des panneaux narratifs |
| paper_dark | #EFE7DA | Fond secondaire, zones enfoncees |
| paper_warm | #F4EDE3 | Fond intermediaire, cartes |
| ink | #382E24 | Texte principal, titres |
| ink_soft | #615242 | Texte secondaire, sous-titres |
| ink_faded | #807059 (35%) | Texte desactive, watermarks |
| accent | #947042 | Surbrillance principale, liens, bronze |
| accent_soft | #A68557 | Hover, surbrillance douce |
| accent_glow | #B89461 (25%) | Lueur derriere elements importants |
| shadow | #403428 (18%) | Ombres portees des panneaux |
| line | #665847 (12%) | Separateurs, bordures fines |
| mist | #F0EBE1 (35%) | Brume, overlay leger |
| celtic_gold | #AD8C52 | Ornements celtiques, dorures |
| celtic_brown | #735C47 | Bordures celtiques, bois |
| ogham_glow | #739E52 | Lueur des glyphes Ogham actifs |
| bestiole | #6B99B8 | Indicateur Bestiole, liens d'affinite |
| danger | #B84738 | Etat critique, alerte, mort |
| success | #529447 | Etat positif, guerison, bonus |
| warning | #B89438 | Attention, seuil, transition |

### 2.2 Palette GBC (MerlinVisual.GBC)

Chaque biome a 3 nuances: base, light, dark.

| Biome | Base | Usage |
|-------|------|-------|
| grass/grass_light/grass_dark | Vert foret | Biome Foret, Monde |
| water/water_light/water_dark | Bleu profond | Biome Lac, Eau |
| earth/earth_light/earth_dark | Brun terre | Biome Montagne, Corps |
| mystic/mystic_light/mystic_dark | Violet arcane | Biome Sanctuaire, Ame |
| fire/fire_light/fire_dark | Orange flamme | Biome Volcan, Feu |
| shadow_gbc/light_gbc | Gris | Ombres/lumieres GBC |
| thunder/thunder_light | Jaune electrique | Orage, evenements |

### 2.3 Couleurs des Aspects (MerlinVisual.ASPECT_COLORS)

| Aspect | Couleur | Animal | Symbolique |
|--------|---------|--------|------------|
| Corps | Brun terre (0.55, 0.40, 0.25) | Sanglier | Force physique, endurance |
| Ame | Violet mystique (0.40, 0.45, 0.70) | Corbeau | Intuition, magie |
| Monde | Vert foret (0.35, 0.55, 0.35) | Cerf | Nature, liens sociaux |

Variantes: ASPECT_COLORS_LIGHT (pastel), ASPECT_COLORS_DARK (profond)

### 2.4 Couleurs des Saisons (MerlinVisual.SEASON_COLORS)

| Saison | Couleur | Ambiance |
|--------|---------|----------|
| Printemps | Vert tendre | Renouveau, espoir |
| Ete | Or chaud | Abondance, maturite |
| Automne | Roux cuivre | Changement, melancolie |
| Hiver | Bleu givre | Silence, survie |

---

## 3. Typographie

### 3.1 Polices

| Role | Police | Fichier | Tailles |
|------|--------|---------|---------|
| **Titres** | MorrisRomanBlack | resources/fonts/morris/MorrisRomanBlack.otf | 48 (grand), 36 (petit) |
| **Corps** | MorrisRomanBlackAlt | resources/fonts/morris/MorrisRomanBlackAlt.otf | 20 (normal), 22 (grand), 14 (caption) |
| **Ornements** | celtic-bit | resources/fonts/celtic_bit/celtic-bit.ttf | Variable selon contexte |

### 3.2 Constantes de taille (MerlinVisual)

| Constante | Valeur | Usage |
|-----------|--------|-------|
| TITLE_SIZE | 48 | Titres principaux de scene |
| TITLE_SMALL | 36 | Sous-titres, titres de section |
| BODY_SIZE | 20 | Texte narratif, dialogues |
| BODY_LARGE | 22 | Texte important, instructions |
| CAPTION_SIZE | 14 | Legendes, metadata |
| BUTTON_SIZE | 18 | Texte des boutons |

### 3.3 Regles typographiques

- **JAMAIS** de gras/italique sur le corps de texte — MorrisRomanBlack est deja decoratif
- **JAMAIS** de police systeme (Godot default) — toujours MerlinVisual.get_font()
- **JAMAIS** de majuscules completes sur plus de 3 mots
- Titres: MorrisRomanBlack + ink color + TITLE_SIZE
- Corps: MorrisRomanBlackAlt + ink color + BODY_SIZE
- Ornements separateurs: celtic_ornament() entre sections

### 3.4 API

```gdscript
# Charger une police
var font: Font = MerlinVisual.get_font("title")   # MorrisRomanBlack
var font: Font = MerlinVisual.get_font("body")    # MorrisRomanBlackAlt
var font: Font = MerlinVisual.get_font("celtic")  # celtic-bit

# Appliquer un style de label
MerlinVisual.apply_label_style(label, "title", MerlinVisual.TITLE_SIZE)
MerlinVisual.apply_label_style(label, "body", MerlinVisual.BODY_SIZE)
```

---

## 4. Panneaux et Styles

### 4.1 Panneaux disponibles

| Style | Methode | Fond | Bordure | Usage |
|-------|---------|------|---------|-------|
| Parchemin | make_parchment_style() | paper_warm | ink_faded 1px | Dialogues, menus, cartes |
| Grotte | make_grotte_style() | ink (sombre) | celtic_gold 1px | Antre, scenes sombres |

### 4.2 Boutons

```gdscript
# Appliquer le theme complet a un bouton
MerlinVisual.apply_button_theme(mon_bouton)
# Cree 3 styles: normal (paper), hover (paper_dark), pressed (accent)
# + police body, taille BUTTON_SIZE, couleur ink
```

Regles boutons:
- Taille minimum: 48x48px (MIN_TOUCH_TARGET)
- Padding horizontal: 24px minimum
- Coins arrondis: 4-6px
- Feedback visuel: changement de fond au hover ET au press
- Espacement entre boutons: >= 12px

### 4.3 Shader parchemin

Fichier: res://shaders/merlin_paper.gdshader

| Uniform | Type | Defaut | Effet |
|---------|------|--------|-------|
| paper_tint | vec4 | PALETTE["paper"] | Couleur de fond du parchemin |
| grain_strength | float | 0.08 | Intensite du grain de papier |
| vignette_strength | float | 0.3 | Assombrissement des bords |
| grain_scale | float | 800.0 | Echelle du bruit de grain |
| warp_strength | float | 0.002 | Deformation ondulatoire |

---

## 5. Animations

### 5.1 Constantes de timing (MerlinVisual)

| Constante | Valeur | Usage |
|-----------|--------|-------|
| ANIM_FAST | 0.2s | Feedback immediat: hover, click, toggle |
| ANIM_NORMAL | 0.3s | Transitions standard: fade, slide |
| ANIM_SLOW | 0.5s | Transitions importantes: scene change, reveal |
| ANIM_VERY_SLOW | 1.5s | Transitions cinematiques: intro, outro |
| TW_DELAY | 0.025s | Delai par lettre (typewriter) |
| TW_PUNCT_DELAY | 0.080s | Delai ponctuation (typewriter) |
| TW_BLIP_FREQ | 880.0 | Frequence blip voix Merlin |
| TW_BLIP_VOLUME | -18.0 | Volume blip voix |
| BREATHE_DURATION | 5.0s | Cycle de respiration (elements vivants) |

### 5.2 Easing standard

| Constante | Valeur | Usage |
|-----------|--------|-------|
| EASING_UI | EASE_OUT | Toutes les animations UI |
| TRANS_UI | TRANS_SINE | Courbe douce pour le UI |
| EASING_PATH | EASE_IN_OUT | Mouvements de cameras, trajets |
| TRANS_PATH | TRANS_CUBIC | Courbe pour les deplacements |

### 5.3 Regles d'animation

1. **Non-bloquant** — L'input utilisateur n'est JAMAIS bloque par une animation
2. **Typewriter** — Tout texte narratif apparait lettre par lettre (TW_DELAY)
3. **Fade-in** — Les elements apparaissent toujours en fade (ANIM_NORMAL)
4. **Respiration** — Les elements actifs pulsent doucement (BREATHE_DURATION, scale 1.0-1.005)
5. **Ornements** — Les separateurs celtiques apparaissent avec un draw progressif
6. **Pas de bounce** — Les animations sont fluides, pas rebondissantes
7. **Coherence** — Toujours utiliser EASING_UI / TRANS_UI, jamais de valeurs ad hoc

### 5.4 API Animation

```gdscript
# Tween standard
var tween := create_tween()
tween.set_ease(MerlinVisual.EASING_UI)
tween.set_trans(MerlinVisual.TRANS_UI)
tween.tween_property(node, "modulate:a", 1.0, MerlinVisual.ANIM_NORMAL)

# Typewriter
for i in text.length():
    label.visible_characters = i + 1
    var delay: float = MerlinVisual.TW_PUNCT_DELAY if text[i] in ".,;:!?" else MerlinVisual.TW_DELAY
    await get_tree().create_timer(delay).timeout
```

---

## 6. Regles par Scene

### 6.1 IntroCeltOS (Boot / CRT)
- **Monde**: Transition (ecran CRT -> parchemin)
- **Fond**: Noir pur -> shader CRT -> fade to paper
- **Couleurs**: fire (texte terminal), puis paper
- **Police**: celtic-bit (terminal), puis MorrisRomanBlack
- **Animation**: Typewriter rapide (terminal), ember_timeline
- **Special**: Ecran CRT avec scanlines, bruit statique

### 6.2 MenuPrincipal (Merlin card-style)
- **Monde**: Parchemin
- **Fond**: merlin_paper.gdshader (plein ecran)
- **Couleurs**: PALETTE complete — paper, ink, accent, celtic_gold
- **Police**: MorrisRomanBlack (titre), MorrisRomanBlackAlt (options)
- **Animation**: Swipe gauche/droite (card-based), fade-in des elements
- **Special**: Ornements celtiques decoratifs, logo anime, breathing

### 6.3 IntroPersonalityQuiz (Questionnaire)
- **Monde**: Parchemin
- **Fond**: paper_warm uni ou shader leger
- **Couleurs**: ink (questions), accent (reponses), celtic_gold (progression)
- **Police**: MorrisRomanBlack (question), MorrisRomanBlackAlt (reponses)
- **Animation**: Slide horizontal entre questions, typewriter
- **Special**: Barre de progression avec ornements celtiques

### 6.4 SceneEveil (Premiere rencontre)
- **Monde**: Transition (GBC feu -> parchemin)
- **Fond**: Noir -> flammes GBC -> paper shader
- **Couleurs**: GBC fire -> PALETTE paper progressivement
- **Police**: celtic-bit (chuchotements), MorrisRomanBlack (revelation)
- **Animation**: Typewriter lent, particules de braise, fade progressif
- **Special**: Texte emerge des flammes, premier contact avec Merlin

### 6.5 SceneRencontreMerlin (Dialogue initial)
- **Monde**: Parchemin + GBC
- **Fond**: Grotte (make_grotte_style) avec elements GBC
- **Couleurs**: PALETTE grotte (ink fond, celtic_gold accents) + bestiole
- **Police**: MorrisRomanBlack (Merlin), MorrisRomanBlackAlt (narration)
- **Animation**: Typewriter + voix ACVoicebox, portrait anime
- **Special**: Portrait pixel de Merlin, choix narratifs

### 6.6 HubAntre (Hub central)
- **Monde**: Parchemin (grotte eclairee)
- **Fond**: make_grotte_style() + eclairages dynamiques
- **Couleurs**: celtic_gold (interactions), paper (panneaux), ASPECT_COLORS (jauges)
- **Police**: MorrisRomanBlack (sections), MerlinVisual (descriptions)
- **Animation**: Respiration des lumieres, hover feedback
- **Composants**: Carte du monde, portrait Bestiole, jauges Triade, menu radial
- **Special**: Point central du jeu, acces a toutes les features

### 6.7 TransitionBiome (Voyage entre zones)
- **Monde**: GBC pur
- **Fond**: Paysage GBC genere (6 phases)
- **Couleurs**: MerlinVisual.BIOME_COLORS[biome] — 4 couleurs par biome
- **Police**: celtic-bit (noms de lieux), MorrisRomanBlackAlt (narration)
- **Animation**: Scrolling parallaxe 6 couches, fade entre phases
- **Phases**: ciel -> montagnes -> collines -> vegetation -> sol -> premier plan
- **Special**: Chaque biome a son profil visuel (BIOME_ART_PROFILES)

### 6.8 TriadeGameUI (Gameplay principal)
- **Monde**: Parchemin + Aspects
- **Fond**: merlin_paper.gdshader
- **Couleurs**: ASPECT_COLORS (jauges), paper (cartes), ink (texte)
- **Police**: MorrisRomanBlack (titres cartes), MorlinBlackAlt (choix)
- **Animation**: Slide cartes (Merlin card-style), typewriter, jauges animees
- **Composants**: 3 cartes de choix, 3 jauges d'Aspect, compteur Souffle
- **Special**: Les cartes utilisent ASPECT_COLORS selon l'aspect affecte

### 6.9 Calendar (Calendrier celtique)
- **Monde**: Parchemin
- **Fond**: make_parchment_style() panel
- **Couleurs**: SEASON_COLORS (saisons), celtic_gold (ornements), ink (dates)
- **Police**: MorrisRomanBlack (mois), celtic-bit (symboles saisonniers)
- **Animation**: Rotation de la roue saisonniere, fade entre saisons
- **Special**: Roue des saisons avec ornements celtiques

### 6.10 Collection (Succes / Collection)
- **Monde**: Parchemin
- **Fond**: make_parchment_style()
- **Couleurs**: celtic_gold (acquis), ink_faded (verrouille), accent (rare)
- **Police**: MorrisRomanBlack (titres), MorrisRomanBlackAlt (descriptions)
- **Animation**: Reveal progressif, lueur pour nouveaux items
- **Special**: Cartes de collection avec effet parchemin

### 6.11 BestioleWheel (Roue des Oghams)
- **Monde**: GBC + Parchemin
- **Fond**: Sombre (ink) avec halo central
- **Couleurs**: OGHAM_CATEGORY_COLORS (6 categories), ogham_glow (actif)
- **Police**: celtic-bit (glyphes Ogham), MorrisRomanBlackAlt (descriptions)
- **Animation**: Rotation radiale, lueur pulsante sur selection
- **Special**: Menu radial avec 18 skills Ogham, categorisees par type

### 6.12 ArbreDeVie (Arbre de talents)
- **Monde**: Parchemin + Aspects
- **Fond**: make_parchment_style() avec reseau de noeuds
- **Couleurs**: ASPECT_COLORS (branches), celtic_gold (connexions), accent (debloque)
- **Police**: MorrisRomanBlack (noms), MorrisRomanBlackAlt (effets)
- **Animation**: Pulse sur noeuds actifs, draw progressif des connexions
- **Special**: 28 noeuds (TALENT_NODES), 3 branches par Aspect

---

## 7. Composants UI

### 7.1 Cartes de choix (Triade)

Structure:
```
+-------------------------+  <- make_parchment_style()
|  * Titre du choix *     |  <- MorrisRomanBlack, TITLE_SMALL
|-------------------------|  <- celtic_ornament()
|  Description narrative   |  <- MorrisRomanBlackAlt, BODY_SIZE
|  du choix propose...     |
|                          |
|  [Corps +1] [Ame -1]    |  <- ASPECT_COLORS badges
+-------------------------+
```

- Fond: paper_warm avec bord ink_faded 1px
- Coins: 4-6px arrondis
- Ombre: shadow, 16px blur
- Largeur: min 240px, max 380px
- Hauteur: adaptative au contenu

### 7.2 Jauges d'Aspect

3 jauges verticales ou horizontales, une par Aspect:
- Couleur remplissage: ASPECT_COLORS[aspect]
- Couleur fond: ASPECT_COLORS_DARK[aspect] (30% opacity)
- Bordure: celtic_brown 1px
- Etats: Bas (danger pulse), Equilibre (steady glow), Haut (warning pulse)
- Animation: tween ANIM_NORMAL pour changements de valeur

### 7.3 Boutons d'action

```gdscript
# Standard
MerlinVisual.apply_button_theme(button)

# Etats:
# Normal:  paper bg, ink text, ink_faded border
# Hover:   paper_dark bg, ink text, accent border
# Pressed: accent bg, paper text, accent border
# Disabled: paper bg, ink_faded text, line border
```

### 7.4 Ornements celtiques

- Separateur: MerlinVisual.celtic_ornament() returns ornament string
- Usage: entre sections de texte, en-tete/pied de panneau
- Police: celtic-bit pour les symboles
- Couleur: celtic_gold
- Animation: fade-in ANIM_SLOW

### 7.5 Typewriter (texte narratif)

Tout texte de Merlin ou narratif utilise le typewriter:
- Delai par lettre: TW_DELAY (0.025s)
- Delai ponctuation: TW_PUNCT_DELAY (0.080s)
- Blip sonore: TW_BLIP_FREQ (880 Hz), TW_BLIP_VOLUME (-18 dB)
- Skip: clic/tap pour afficher tout le texte instantanement
- Police: MorrisRomanBlackAlt, BODY_SIZE

---

## 8. Accessibilite

### 8.1 Contraste
- Texte principal: ink sur paper = ratio >= 7:1
- Texte secondaire: ink_soft sur paper = ratio >= 4.5:1
- Texte desactive: ink_faded = informatif seulement, pas d'action
- JAMAIS de texte clair sur fond clair

### 8.2 Cibles tactiles
- Taille minimum: 48x48px (MerlinVisual.MIN_TOUCH_TARGET)
- Espacement minimum: 12px entre cibles
- Zone de hit: toujours >= zone visuelle

### 8.3 Daltonisme
- Ne jamais utiliser la couleur seule pour transmettre une info
- Ajouter icones/symboles aux indicateurs de couleur
- Les 3 Aspects ont des animaux-symboles (Sanglier, Corbeau, Cerf)

---

## 9. Patterns Interdits

| Pattern | Raison | Alternative |
|---------|--------|-------------|
| Color(0.5, 0.3, 0.7) | Couleur hardcodee | MerlinVisual.PALETTE["accent"] |
| const PALETTE := {} | Copie locale | MerlinVisual.PALETTE |
| Police Godot par defaut | Casse l'unite | MerlinVisual.get_font("body") |
| var c := PALETTE["x"] | Inference impossible | var c: Color = MerlinVisual.PALETTE["x"] |
| yield() | Deprecie Godot 4 | await |
| Animation bloquante | Freeze input | Tween non-bloquant |
| Gras/italique sur body | Regles typo | Seul MorrisRomanBlack pour titres |
| Rouge/vert pour jauges | Generique | ASPECT_COLORS |
| Tween custom easing | Incoherent | EASING_UI / TRANS_UI |
| sleep() ou Timer bloquant | Freeze | await get_tree().create_timer() |

---

## 10. Checklist Agent (Pre-Commit)

Avant de valider du code UI:

- [ ] Toutes les couleurs viennent de MerlinVisual.PALETTE ou MerlinVisual.GBC
- [ ] Toutes les polices viennent de MerlinVisual.get_font()
- [ ] Tailles de police = constantes MerlinVisual (TITLE_SIZE, BODY_SIZE, etc.)
- [ ] Panneaux utilisent make_parchment_style() ou make_grotte_style()
- [ ] Boutons styles via apply_button_theme()
- [ ] Cibles tactiles >= 48px
- [ ] Animations utilisent ANIM_FAST/NORMAL/SLOW
- [ ] Easing = EASING_UI + TRANS_UI
- [ ] Ornements via celtic_ornament()
- [ ] Type annotations sur tous les acces Dictionary (var x: Color = ...)
- [ ] Aucune animation bloquante
- [ ] Layout responsive (anchors + size_flags)
- [ ] validate.bat passe (Step 0 minimum)

---

## Annexe A: Fichiers de reference

| Fichier | Description |
|---------|-------------|
| scripts/autoload/merlin_visual.gd | Source de verite visuelle |
| shaders/merlin_paper.gdshader | Shader parchemin |
| resources/fonts/morris/ | Polices Morris Roman |
| resources/fonts/celtic_bit/ | Police celtic-bit |
| .claude/agents/ui_consistency_rules.md | Regles agents |
| docs/70_graphic/ART_DIRECTION_AUDIT.md | Audit artistique |

## Annexe B: Inspiration

- **Kingdom Two Crowns** — Pixel-art minimaliste, animations douces, palette restreinte
- **Reigns** — Swipe mechanique, cartes narratives, UI epuree
- **Slay the Spire** — Jauges claires, feedback visuel des effets
- **Inscryption** — Atmosphere mystique, table de jeu, eclairages dramatiques
