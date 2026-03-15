# UI Consistency Rules — M.E.R.L.I.N. Agent Instructions

## MANDATORY: Read Before Any UI Work

This document defines the binding rules for all agents working on UI/UX in M.E.R.L.I.N.
Violation of these rules creates visual inconsistency. Full spec: docs/70_graphic/UI_UX_BIBLE.md.

## 1. Visual System: MerlinVisual Autoload (CRT Terminal Aesthetic)

ALL visual constants are centralized in scripts/autoload/merlin_visual.gd. ONLY source of truth.

### Colors — CRT Terminal (CRT_PALETTE)

    # Backgrounds (dark with green tinge)
    MerlinVisual.CRT_PALETTE["bg_deep"]         # Deepest black
    MerlinVisual.CRT_PALETTE["bg_dark"]          # Dark panel
    MerlinVisual.CRT_PALETTE["bg_panel"]         # Standard panel bg
    MerlinVisual.CRT_PALETTE["bg_highlight"]     # Highlighted bg

    # Primary text (phosphor green)
    MerlinVisual.CRT_PALETTE["phosphor"]         # Main text
    MerlinVisual.CRT_PALETTE["phosphor_dim"]     # Secondary text
    MerlinVisual.CRT_PALETTE["phosphor_bright"]  # Bright/hover text

    # Accents (amber)
    MerlinVisual.CRT_PALETTE["amber"]            # Accent highlights
    MerlinVisual.CRT_PALETTE["amber_bright"]     # Gold/celtic accent

    # Special
    MerlinVisual.CRT_PALETTE["cyan"]             # Mystic/magic
    MerlinVisual.CRT_PALETTE["border"]           # Panel borders
    MerlinVisual.CRT_PALETTE["danger"]           # Critical state
    MerlinVisual.CRT_PALETTE["success"]          # Positive state

    # CRT Faction colors (in terminal phosphor)
    MerlinVisual.CRT_PALETTE["phosphor"]         # Default faction color
    MerlinVisual.CRT_PALETTE["danger"]           # Ankou faction
    MerlinVisual.CRT_PALETTE["success"]          # Druides faction

    # Biome CRT palettes (8 colors per biome, phosphor tint + distortion)
    MerlinVisual.apply_biome_crt("broceliande")  # Apply to CRTLayer

### Fonts — VT323 Monospace Terminal

    MerlinVisual.get_font("title")     # VT323-Regular
    MerlinVisual.get_font("body")      # VT323-Regular
    MerlinVisual.get_font("terminal")  # VT323-Regular
    MerlinVisual.get_font("celtic")    # celtic-bit (pixel accents)

    # Sizes (increased for CRT readability through scanlines)
    MerlinVisual.TITLE_SIZE     # 52
    MerlinVisual.TITLE_SMALL    # 38
    MerlinVisual.BODY_SIZE      # 22
    MerlinVisual.BODY_LARGE     # 26
    MerlinVisual.CAPTION_SIZE   # 16
    MerlinVisual.BUTTON_SIZE    # 22

### Styles — Sharp CRT Terminal Panels (corner_radius=0, shadow=0)

    MerlinVisual.make_parchment_style()  # CRT terminal panel
    MerlinVisual.make_grotte_style()     # Deep dark panel
    MerlinVisual.apply_button_theme(btn) # CRT button (phosphor text)
    MerlinVisual.apply_label_style(lbl, "title", MerlinVisual.TITLE_SIZE)
    MerlinVisual.make_celtic_option_style(color) # Left-accent terminal option
    MerlinVisual.make_modal_style()      # Deep black modal

### CRT Animations

    MerlinVisual.phosphor_reveal(label)       # Text fades dim->bright
    MerlinVisual.phosphor_fade(label)         # Text dims with afterglow
    MerlinVisual.create_cursor_blink(parent)  # Blinking _ cursor
    MerlinVisual.boot_line_type(label, text)  # Terminal boot typing
    MerlinVisual.glitch_pulse()               # Screen glitch flash
    MerlinVisual.TW_DELAY        # 0.015s per letter (fast terminal)
    MerlinVisual.EASING_UI       # Tween.EASE_OUT
    MerlinVisual.TRANS_UI        # Tween.TRANS_SINE

## 2. Forbidden Patterns

| Pattern | Why | Correct |
|---------|-----|---------|
| Color(0.5, 0.3, 0.7) | Hardcoded | MerlinVisual.CRT_PALETTE["amber"] |
| MerlinVisual.PALETTE["x"] | LEGACY deprecated | MerlinVisual.CRT_PALETTE["x"] |
| const MY_PALETTE := {} | Local copy | MerlinVisual.CRT_PALETTE |
| Default Godot font | Breaks unity | MerlinVisual.get_font("body") |
| var c := CRT_PALETTE["x"] | Type inference | var c: Color = CRT_PALETTE["x"] |
| corner_radius > 0 | CRT = sharp | set_corner_radius_all(0) |
| shadow_size > 0 | No CRT shadows | shadow_size = 0 |
| White/parchment bg | Wrong aesthetic | CRT_PALETTE bg_* dark colors |
| Morris Roman font | LEGACY deprecated | VT323 terminal font |
| yield() | Deprecated | await |

## 3. Pre-Commit Checklist

    [ ] All colors from MerlinVisual.CRT_PALETTE or MerlinVisual.GBC
    [ ] All fonts from MerlinVisual.get_font() (VT323)
    [ ] Corner radius = 0 (sharp CRT corners)
    [ ] Shadow size = 0 (no drop shadows)
    [ ] Dark backgrounds (CRT_PALETTE bg_* colors)
    [ ] Phosphor text (CRT_PALETTE phosphor* colors)
    [ ] Type annotations on all dict accesses
    [ ] Touch targets >= 48px
    [ ] validate.bat Step 0 passes

## 4. Scene CRT Rules

| Scene | Background | Key Colors | CRT Profile |
|-------|-----------|-----------|-------------|
| MenuPrincipal | bg_dark | phosphor + amber | medium |
| IntroCeltOS | bg_deep | phosphor + cyan | boot sequence |
| IntroQuiz | bg_panel | phosphor + choice_* | subtle |
| Rencontre | bg_deep | phosphor + amber | medium |
| HubAntre | bg_dark | amber + phosphor | medium |
| TransitionBiome | bg_dark | BIOME_CRT_PALETTES | per-biome |
| MerlinGame | bg_panel | CRT_ASPECT_COLORS | per-biome |
| Calendar | bg_dark | amber + event colors | subtle |
| Collection | bg_dark | amber_bright | subtle |
| ArbreDeVie | bg_panel | CRT_ASPECT_COLORS | medium |

## 5. Quick Reference

    CRT SHADER: res://shaders/crt_terminal.gdshader
    CRT LAYER: scripts/ui/screen_dither_layer.gd (CRTLayer, autoload ScreenDither)
    SCREEN FX: scripts/autoload/ScreenEffects.gd (mood system -> CRTLayer)
    VISUAL: scripts/autoload/merlin_visual.gd (CRT_PALETTE, factories, animations)
    FONTS: res://resources/fonts/terminal/VT323-Regular.ttf
    THEME: themes/merlin_theme.tres (VT323, dark bg, phosphor text)
