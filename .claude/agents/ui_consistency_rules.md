# UI Consistency Rules — M.E.R.L.I.N. Agent Instructions

## MANDATORY: Read Before Any UI Work

This document defines the binding rules for all agents working on UI/UX in M.E.R.L.I.N.
Violation of these rules creates visual inconsistency. Full spec: docs/70_graphic/UI_UX_BIBLE.md.

## 1. Visual System: MerlinVisual Autoload

ALL visual constants are centralized in scripts/autoload/merlin_visual.gd. ONLY source of truth.

### Colors

    # Parchment palette (narrative UI)
    MerlinVisual.PALETTE["paper"]        # Background
    MerlinVisual.PALETTE["ink"]          # Text
    MerlinVisual.PALETTE["accent"]       # Bronze highlights
    MerlinVisual.PALETTE["celtic_gold"]  # Celtic metalwork
    MerlinVisual.PALETTE["danger"]       # Critical state
    MerlinVisual.PALETTE["success"]      # Positive state

    # GBC palette (biome/gameplay colors)
    MerlinVisual.GBC["grass"]           # Nature/Monde
    MerlinVisual.GBC["fire"]            # Fire/Force
    MerlinVisual.GBC["mystic"]          # Arcane/Ame
    MerlinVisual.GBC["earth"]           # Earth/Corps

    # Aspect colors (Triade system)
    MerlinVisual.ASPECT_COLORS["Corps"]  # Earthy brown
    MerlinVisual.ASPECT_COLORS["Ame"]    # Purple mystic
    MerlinVisual.ASPECT_COLORS["Monde"]  # Forest green

### Fonts

    MerlinVisual.get_font("title")   # MorrisRomanBlack
    MerlinVisual.get_font("body")    # MorrisRomanBlackAlt
    MerlinVisual.get_font("celtic")  # celtic-bit

    # Sizes
    MerlinVisual.TITLE_SIZE     # 48
    MerlinVisual.TITLE_SMALL    # 36
    MerlinVisual.BODY_SIZE      # 20
    MerlinVisual.BODY_LARGE     # 22
    MerlinVisual.CAPTION_SIZE   # 14
    MerlinVisual.BUTTON_SIZE    # 18

### Styles

    MerlinVisual.make_parchment_style()  # Parchment panel
    MerlinVisual.make_grotte_style()     # Cave/dark panel
    MerlinVisual.apply_button_theme(btn) # Full button styling
    MerlinVisual.apply_label_style(lbl, "title", MerlinVisual.TITLE_SIZE)
    MerlinVisual.celtic_ornament()       # Ornament divider string

### Animation

    MerlinVisual.ANIM_FAST       # 0.2s
    MerlinVisual.ANIM_NORMAL     # 0.3s
    MerlinVisual.ANIM_SLOW       # 0.5s
    MerlinVisual.ANIM_VERY_SLOW  # 1.5s
    MerlinVisual.TW_DELAY        # 0.025s per letter
    MerlinVisual.TW_PUNCT_DELAY  # 0.080s punctuation
    MerlinVisual.EASING_UI       # Tween.EASE_OUT
    MerlinVisual.TRANS_UI        # Tween.TRANS_SINE

## 2. Forbidden Patterns

| Pattern | Why | Correct |
|---------|-----|---------|
| Color(0.5, 0.3, 0.7) | Hardcoded | MerlinVisual.PALETTE["accent"] |
| const PALETTE := {} | Local copy | MerlinVisual.PALETTE |
| Default Godot font | Breaks unity | MerlinVisual.get_font("body") |
| var c := MerlinVisual.PALETTE["x"] | Type inference | var c: Color = MerlinVisual.PALETTE["x"] |
| yield() | Deprecated | await |
| Blocking animations | Freezes input | Non-blocking tweens |
| Bold/italic body | Typography rules | Only MorrisRomanBlack titles |
| Red/green gauges | Generic | MerlinVisual.ASPECT_COLORS |

## 3. Pre-Commit Checklist

    [ ] All colors from MerlinVisual.PALETTE or MerlinVisual.GBC
    [ ] All fonts from MerlinVisual.get_font()
    [ ] Font sizes from MerlinVisual constants
    [ ] Panels use make_parchment_style() or make_grotte_style()
    [ ] Buttons styled via apply_button_theme()
    [ ] Touch targets >= 48px (MerlinVisual.MIN_TOUCH_TARGET)
    [ ] Animations use MerlinVisual timing constants
    [ ] Easing uses EASING_UI / TRANS_UI
    [ ] Celtic ornaments via celtic_ornament()
    [ ] Type annotations on all dictionary accesses
    [ ] No blocking animations
    [ ] Responsive layout (anchors + size_flags)
    [ ] validate.bat passes (Step 0)

## 4. Scene-Specific Rules

| Scene | Background | Key Colors | Special |
|-------|-----------|-----------|---------|
| MenuPrincipal | paper shader | Full parchment | Card swipe |
| IntroCeltOS | Black | fire palette | Ember timeline |
| SceneEveil | Fire->parchment | fire + parchment | Typewriter |
| HubAntre | Grotte shader | parchment + celtic_gold | Map, Bestiole, portrait |
| TransitionBiome | Biome colors | BIOME_COLORS | 6-phase landscape |
| TriadeGameUI | Paper shader | ASPECT_COLORS | 3 cards, gauges |
| Calendar | Paper panel | SEASON_COLORS | Season wheel |
| Collection | Paper panel | celtic_gold | Achievement cards |
| BestioleWheel | Dark bg | OGHAM_CATEGORY_COLORS | Radial menu |
| ArbreDeVie | Paper panel | ASPECT_COLORS + amber | Node network |

## 5. Quick Reference

    SHADER: res://shaders/merlin_paper.gdshader
    FONTS: res://resources/fonts/morris/ + res://resources/fonts/celtic_bit/
    AUTOLOAD: MerlinVisual (scripts/autoload/merlin_visual.gd)
    BIBLE: docs/70_graphic/UI_UX_BIBLE.md
