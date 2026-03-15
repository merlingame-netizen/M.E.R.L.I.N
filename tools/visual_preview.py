"""
visual_preview.py — Text-based visual preview prediction for M.E.R.L.I.N. game screens.

CLI tool: python tools/visual_preview.py [screen]
Screens: hub, run, end_screen, card, biome_<name>, all

Generates ASCII wireframe layouts, color maps, component inventories,
animation timelines, and sound event maps for each game screen.

Python 3.12, no external deps, Windows compatible.
"""

import sys
import textwrap
from dataclasses import dataclass, field
from typing import Optional


# ═══════════════════════════════════════════════════════════════════════════════
# COLOR DATA (extracted from MerlinVisual.CRT_PALETTE)
# ═══════════════════════════════════════════════════════════════════════════════

CRT_PALETTE = {
    "bg_deep": "Color(0.02, 0.04, 0.02) — near-black with green tinge",
    "bg_dark": "Color(0.04, 0.08, 0.04) — dark terminal background",
    "bg_panel": "Color(0.06, 0.12, 0.06) — panel fill",
    "bg_highlight": "Color(0.08, 0.16, 0.08) — hover/active panel",
    "phosphor": "Color(0.20, 1.00, 0.40) — primary green text",
    "phosphor_dim": "Color(0.12, 0.60, 0.24) — secondary/dim green",
    "phosphor_bright": "Color(0.40, 1.00, 0.60) — bright highlight",
    "amber": "Color(1.00, 0.75, 0.20) — amber accent/titles",
    "amber_dim": "Color(0.60, 0.45, 0.12) — dim amber labels",
    "amber_bright": "Color(1.00, 0.85, 0.40) — bright amber",
    "cyan": "Color(0.30, 0.85, 0.80) — mystic cyan",
    "cyan_bright": "Color(0.50, 1.00, 0.95) — bright cyan",
    "danger": "Color(1.00, 0.20, 0.15) — red danger/death",
    "warning": "Color(1.00, 0.75, 0.20) — yellow warning",
    "success": "Color(0.20, 1.00, 0.40) — green success",
    "inactive": "Color(0.20, 0.25, 0.20) — greyed out",
    "border": "Color(0.12, 0.30, 0.14) — panel borders",
    "line": "Color(0.12, 0.30, 0.14, 0.25) — connecting lines",
    "souffle": "Color(0.30, 0.85, 0.80) — souffle icons (cyan)",
    "souffle_full": "Color(1.00, 0.85, 0.40) — souffle full (amber)",
}

FACTION_COLORS = {
    "druides": "Color(0.20, 0.80, 0.30) — green",
    "anciens": "Color(0.70, 0.55, 0.30) — amber/brown",
    "korrigans": "Color(0.80, 0.40, 0.80) — purple",
    "niamh": "Color(0.30, 0.70, 0.90) — blue",
    "ankou": "Color(0.60, 0.20, 0.20) — dark red",
}

FACTION_SYMBOLS = {
    "druides": "[D]",
    "anciens": "[A]",
    "korrigans": "[K]",
    "niamh": "[N]",
    "ankou": "[X]",
}

# ═══════════════════════════════════════════════════════════════════════════════
# SFX DATA (extracted from SFXEngine enum)
# ═══════════════════════════════════════════════════════════════════════════════

SFX_CATALOG = [
    "CARD_DRAW", "CARD_FLIP", "OPTION_SELECT", "MINIGAME_START",
    "MINIGAME_END", "SCORE_REVEAL", "EFFECT_POSITIVE", "EFFECT_NEGATIVE",
    "OGHAM_ACTIVATE", "OGHAM_COOLDOWN", "LIFE_DRAIN", "LIFE_HEAL",
    "DEATH", "VICTORY", "REP_UP", "REP_DOWN", "ANAM_GAIN",
    "WALK_STEP", "BIOME_TRANSITION", "MENU_CLICK", "MENU_HOVER",
    "PROMISE_CREATE", "PROMISE_FULFILL", "PROMISE_BREAK",
    "KARMA_SHIFT", "HUB_AMBIENT", "RUN_AMBIENT",
]

# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION DATA (extracted from MerlinVisual constants)
# ═══════════════════════════════════════════════════════════════════════════════

ANIM_CONSTANTS = {
    "ANIM_FAST": "0.2s",
    "ANIM_NORMAL": "0.3s",
    "ANIM_SLOW": "0.5s",
    "ANIM_VERY_SLOW": "1.5s",
    "CARD_ENTRY_DURATION": "0.65s",
    "CARD_EXIT_DURATION": "0.55s",
    "CARD_DEAL_DURATION": "0.35s",
    "CARD_FLOAT_DURATION": "2.8s (idle float loop)",
    "CRT_PHOSPHOR_FADE": "0.4s",
    "CRT_GLITCH_DURATION": "0.08s",
    "BREATHE_DURATION": "5.0s (ambient breathe loop)",
    "OPTION_SLIDE_DURATION": "0.35s",
    "LAYER_REVEAL_STAGGER": "0.08s between layers",
    "LAYER_REVEAL_DURATION": "0.30s per layer",
    "EASING_UI": "Tween.EASE_OUT + TRANS_SINE",
    "EASING_PATH": "Tween.EASE_IN_OUT + TRANS_CUBIC",
}

# ═══════════════════════════════════════════════════════════════════════════════
# BIOME DATA (extracted from BiomeConfig presets)
# ═══════════════════════════════════════════════════════════════════════════════

BIOMES = {
    "foret_broceliande": {
        "name": "Foret de Broceliande",
        "sky": "Color(0.50, 0.80, 0.40) — bright green canopy",
        "ground": "Color(0.08, 0.22, 0.10) — dark mossy",
        "fog": "Color(0.12, 0.35, 0.16) — green haze",
        "fog_density": 0.025,
        "ambient": "Color(0.30, 0.65, 0.30) — filtered green",
        "ambient_energy": 0.5,
        "tree_density": 1.0,
        "particles": "mist",
        "season": "automne",
        "crt_palette": "Deep greens: #020602 -> #70FF50",
    },
    "landes_bruyere": {
        "name": "Landes de Bruyere",
        "sky": "Color(0.80, 0.55, 0.85) — pale purple",
        "ground": "Color(0.20, 0.10, 0.24) — dark heather",
        "fog": "Color(0.35, 0.18, 0.40) — purple haze",
        "fog_density": 0.018,
        "ambient": "Color(0.65, 0.40, 0.70) — warm purple",
        "ambient_energy": 0.55,
        "tree_density": 0.3,
        "particles": "fireflies",
        "season": "hiver",
        "crt_palette": "Purples: #060206 -> #F5B3FF",
    },
    "cotes_sauvages": {
        "name": "Cotes Sauvages",
        "sky": "Color(0.55, 0.75, 0.85) — coastal blue",
        "ground": "Color(0.08, 0.16, 0.28) — wet dark sand",
        "fog": "Color(0.22, 0.42, 0.58) — sea mist",
        "fog_density": 0.030,
        "ambient": "Color(0.35, 0.58, 0.72) — ocean tint",
        "ambient_energy": 0.6,
        "tree_density": 0.2,
        "particles": "rain",
        "season": "hiver",
        "crt_palette": "Ocean blues: #020408 -> #BFE6FF",
    },
    "villages_celtes": {
        "name": "Villages Celtes",
        "sky": "Color(0.90, 0.65, 0.30) — warm golden",
        "ground": "Color(0.24, 0.14, 0.06) — packed earth",
        "fog": "Color(0.40, 0.24, 0.10) — dust haze",
        "fog_density": 0.010,
        "ambient": "Color(0.75, 0.50, 0.22) — warm firelight",
        "ambient_energy": 0.65,
        "tree_density": 0.4,
        "particles": "none",
        "season": "ete",
        "crt_palette": "Warm earth: #060402 -> #FFCC66",
    },
    "cercles_pierres": {
        "name": "Cercles de Pierres",
        "sky": "Color(0.75, 0.75, 0.85) — pale stone blue",
        "ground": "Color(0.16, 0.16, 0.20) — grey stone",
        "fog": "Color(0.28, 0.28, 0.34) — stone mist",
        "fog_density": 0.035,
        "ambient": "Color(0.58, 0.58, 0.68) — cool grey",
        "ambient_energy": 0.4,
        "tree_density": 0.15,
        "particles": "mist",
        "season": "printemps",
        "crt_palette": "Stone greys: #030304 -> #D4D4E6",
    },
    "marais_korrigans": {
        "name": "Marais des Korrigans",
        "sky": "Color(0.50, 0.72, 0.55) — sickly green",
        "ground": "Color(0.10, 0.18, 0.14) — dark bog",
        "fog": "Color(0.16, 0.28, 0.22) — swamp vapor",
        "fog_density": 0.045,
        "ambient": "Color(0.35, 0.55, 0.42) — murky green",
        "ambient_energy": 0.35,
        "tree_density": 0.5,
        "particles": "fireflies",
        "season": "printemps",
        "crt_palette": "Murky greens: #020604 -> #80E6A0",
    },
    "collines_dolmens": {
        "name": "Collines aux Dolmens",
        "sky": "Color(0.75, 0.78, 0.42) — overcast yellow-green",
        "ground": "Color(0.18, 0.20, 0.10) — dried grass",
        "fog": "Color(0.30, 0.34, 0.16) — highland haze",
        "fog_density": 0.020,
        "ambient": "Color(0.60, 0.65, 0.32) — cold hillside",
        "ambient_energy": 0.45,
        "tree_density": 0.35,
        "particles": "snow",
        "season": "automne",
        "crt_palette": "Yellow-greens: #040402 -> #D9E066",
    },
    "iles_mystiques": {
        "name": "Iles Mystiques",
        "sky": "Color(0.60, 0.78, 0.88) — ethereal blue",
        "ground": "Color(0.10, 0.18, 0.30) — dark ocean rock",
        "fog": "Color(0.18, 0.30, 0.46) — ocean mist",
        "fog_density": 0.040,
        "ambient": "Color(0.42, 0.60, 0.75) — deep blue",
        "ambient_energy": 0.4,
        "tree_density": 0.25,
        "particles": "rain",
        "season": "hiver",
        "crt_palette": "Deep blues: #020406 -> #99C7E0",
    },
}

# ═══════════════════════════════════════════════════════════════════════════════
# PARTICLE VISUAL DESCRIPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

PARTICLE_DESC = {
    "mist": "Slow-drifting translucent wisps, low opacity, horizontal motion",
    "fireflies": "Tiny glowing dots with random float paths, intermittent blink",
    "rain": "Vertical streaks, slight diagonal, splash particles on ground",
    "snow": "Gentle falling flakes, slight wind drift, accumulation on surfaces",
    "none": "No particle effects",
}


# ═══════════════════════════════════════════════════════════════════════════════
# RENDERING HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

def box(title: str, lines: list[str], width: int = 60) -> str:
    """Render a bordered box with title and content lines."""
    top = f"{'=' * width}"
    sep = f"{'-' * width}"
    result = [top, f"  {title}", sep]
    for line in lines:
        result.append(f"  {line}")
    result.append(top)
    return "\n".join(result)


def section(title: str, lines: list[str]) -> str:
    """Render a titled section."""
    header = f"\n--- {title} ---"
    return header + "\n" + "\n".join(f"  {line}" for line in lines)


def bar_ascii(value: int, max_val: int = 100, width: int = 10) -> str:
    """Render a progress bar as ASCII."""
    filled = round(value / max_val * width) if max_val > 0 else 0
    filled = max(0, min(width, filled))
    empty = width - filled
    return f"[{'#' * filled}{'.' * empty}]"


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN: HUB
# ═══════════════════════════════════════════════════════════════════════════════

def preview_hub() -> str:
    parts: list[str] = []

    # ASCII wireframe
    wireframe = textwrap.dedent("""\
    +============================================================+
    |  === L'ANTRE DE MERLIN ===                (amber)          |
    |  > Druide    Anam: 150    Runs: 7    Maturite: 42          |
    |  (phosphor)  (cyan)       (dim)      (dim)                 |
    +------------------------------------------------------------+
    |  [ REPUTATIONS ]                           (amber_dim)     |
    |  [D] Druides    [########..] 80  Honore       (green)      |
    |  [A] Anciens    [######....] 60  Sympathisant (amber)      |
    |  [K] Korrigans  [####......] 40  Neutre       (purple)     |
    |  [N] Niamh      [###.......] 30  Neutre       (blue)       |
    |  [X] Ankou      [##........] 20  Neutre       (red)        |
    |      |---- 50 ----|---- 80 ----|  (threshold markers)      |
    +------------------------------------------------------------+
    |  [ BIOMES ]                  (amber_dim, 4-col grid)       |
    |  [Broceliande] [Landes] [Cotes]  [Villages]  (phosphor)    |
    |  [X Cercles  ] [X Marais] [X Collines] [X Iles] (inactive) |
    +------------------------------------------------------------+
    |  [ OGHAMS ] (1/3)            (amber_dim, 6-col grid)       |
    |  (Beith) (Luis) (Fearn) (Saille) (Nion) ...  (cyan/dim)   |
    +------------------------------------------------------------+
    |  [>> PARTIR EN RUN <<]  [ARBRE DE VIE]  [SAUVER & QUITTER]|
    |     (160x40 buttons, CRT button theme)                     |
    +============================================================+""")
    parts.append(wireframe)

    # Color map
    parts.append(section("COLOR MAP", [
        "Root background:      bg_deep — " + CRT_PALETTE["bg_deep"],
        "Section panels:       bg_panel — " + CRT_PALETTE["bg_panel"],
        "Section borders:      border — " + CRT_PALETTE["border"],
        "Title '=== ANTRE':    amber — " + CRT_PALETTE["amber"],
        "Section labels:       amber_dim — " + CRT_PALETTE["amber_dim"],
        "Player name:          phosphor — " + CRT_PALETTE["phosphor"],
        "Anam value:           cyan — " + CRT_PALETTE["cyan"],
        "Runs/Maturite:        phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
        "Faction bars:         per-faction color (see FACTION_COLORS)",
        "  Druides:            " + FACTION_COLORS["druides"],
        "  Anciens:            " + FACTION_COLORS["anciens"],
        "  Korrigans:          " + FACTION_COLORS["korrigans"],
        "  Niamh:              " + FACTION_COLORS["niamh"],
        "  Ankou:              " + FACTION_COLORS["ankou"],
        "Bar thresholds:       amber (0.6 alpha) at 50% and 80%",
        "Tier 'Honore':        amber_bright — " + CRT_PALETTE["amber_bright"],
        "Tier 'Sympathisant':  phosphor — " + CRT_PALETTE["phosphor"],
        "Tier 'Neutre':        phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
        "Tier 'Mefiant':       warning — " + CRT_PALETTE["warning"],
        "Tier 'Hostile':       danger — " + CRT_PALETTE["danger"],
        "Biome selected:       amber — " + CRT_PALETTE["amber"],
        "Biome available:      phosphor — " + CRT_PALETTE["phosphor"],
        "Biome locked:         inactive — " + CRT_PALETTE["inactive"],
        "Ogham selected:       cyan_bright — " + CRT_PALETTE["cyan_bright"],
        "Ogham unselected:     phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
        "Ogham count:          phosphor — " + CRT_PALETTE["phosphor"],
    ]))

    # Component inventory
    parts.append(section("COMPONENT INVENTORY", [
        "ScrollContainer (FULL_RECT, h-scroll disabled)",
        "  VBoxContainer (_root_vbox, EXPAND_FILL, spacing=8)",
        "    PanelContainer [Header]",
        "      VBoxContainer (spacing=4)",
        "        Label: title '=== L'ANTRE DE MERLIN ===' (18pt, amber, centered)",
        "        HBoxContainer (spacing=16, centered)",
        "          Label: player_name (14pt, phosphor)",
        "          Label: anam (14pt, cyan)",
        "          Label: runs (12pt, phosphor_dim)",
        "          Label: maturity (12pt, phosphor_dim)",
        "    PanelContainer [Factions]",
        "      VBoxContainer (spacing=4)",
        "        Label: '[ REPUTATIONS ]' (14pt, amber_dim)",
        "        VBoxContainer (spacing=2)",
        "          5x FactionRepBar (min_size=280x32)",
        "            HBoxContainer (spacing=6):",
        "              Label: symbol [D/A/K/N/X] (14pt, 32w, centered)",
        "              Label: name (12pt, 90w)",
        "              Control: bar (min 120x18, custom _draw)",
        "              Label: value (12pt, 36w, right-aligned)",
        "              Label: tier (10pt, 80w)",
        "    PanelContainer [Biomes]",
        "      VBoxContainer (spacing=6)",
        "        Label: '[ BIOMES ]' (14pt, amber_dim)",
        "        GridContainer (4 columns, h_sep=6, v_sep=6)",
        "          N x Button (140x36, CRT theme)",
        "    PanelContainer [Oghams]",
        "      VBoxContainer (spacing=6)",
        "        HBoxContainer (spacing=12)",
        "          Label: '[ OGHAMS ]' (14pt, amber_dim)",
        "          Label: count '(N/3)' (12pt, phosphor)",
        "        GridContainer (6 columns, h_sep=4, v_sep=4)",
        "          N x Button (100x30, CRT theme, tooltip: desc+category+cooldown)",
        "    PanelContainer [Actions]",
        "      HBoxContainer (spacing=12, centered)",
        "        Button: '>> PARTIR EN RUN <<' (160x40, disabled if no biome+ogham)",
        "        Button: 'ARBRE DE VIE' (160x40)",
        "        Button: 'SAUVER & QUITTER' (160x40)",
    ]))

    # Animation timeline
    parts.append(section("ANIMATION TIMELINE", [
        "on _ready():  Build UI, apply root style (instant)",
        "on setup():   Refresh all sections (instant data bind)",
        "Biome hover:  Button theme hover state (CRT button theme)",
        "Ogham toggle: Immediate color swap cyan_bright <-> phosphor_dim",
        "No entry/exit tweens defined in hub_screen.gd",
        "Scrollable via ScrollContainer (vertical)",
    ]))

    # Sound event map
    parts.append(section("SOUND EVENT MAP", [
        "MENU_CLICK:   on biome button pressed (select_biome)",
        "MENU_CLICK:   on ogham button pressed (toggle_ogham)",
        "MENU_CLICK:   on '>> PARTIR EN RUN <<' pressed",
        "MENU_CLICK:   on 'ARBRE DE VIE' pressed",
        "MENU_CLICK:   on 'SAUVER & QUITTER' pressed",
        "MENU_HOVER:   on any button focus_entered (CRT button theme)",
        "HUB_AMBIENT:  continuous background loop while hub is active",
    ]))

    return f"\n{'=' * 60}\n  SCREEN PREVIEW: HUB\n{'=' * 60}\n" + "\n".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN: RUN (3D Walk + HUD overlay)
# ═══════════════════════════════════════════════════════════════════════════════

def preview_run() -> str:
    parts: list[str] = []

    wireframe = textwrap.dedent("""\
    +============================================================+
    |  PV 85/100                                         ~ 12    |
    |  [########..]                                  (amber)     |
    |  (phosphor/warning/danger)      * * * o o o o              |
    |                                 (souffle, cyan)            |
    |                                                            |
    |                                                            |
    |                    3D VIEWPORT                             |
    |                                                            |
    |              (Biome environment fills screen)              |
    |                                                            |
    |                          +                                 |
    |                      (crosshair)                           |
    |                    (phosphor_dim)                           |
    |                                                            |
    |                                                            |
    |                                                            |
    |  Broceliande | automne | crepuscule       (phosphor_dim)   |
    +============================================================+
    | CanvasLayer=5  (mouse_filter=IGNORE)                       |
    +============================================================+""")
    parts.append(wireframe)

    parts.append(section("3D VIEWPORT DESCRIPTION", [
        "Full-screen 3D SubViewport with rail-based camera",
        "Player walks forward on a predefined path (rail)",
        "Environment loaded from BiomeConfig preset:",
        "  - Sky dome with biome-specific sky_color",
        "  - Ground plane with ground_color",
        "  - Fog: volumetric with biome fog_color + density",
        "  - Ambient light: biome ambient_light_color + energy",
        "  - Vegetation: tree_density controls spawned meshes",
        "  - Particles: biome particle_type (mist/fireflies/rain/snow)",
        "Collectibles spawn along the path (essences)",
        "Walk events trigger card transitions (fondu/fade)",
    ]))

    parts.append(section("HUD OVERLAY LAYOUT (WalkHUD — CanvasLayer 5)", [
        "TOP ROW (MarginContainer, h_margin=12, v_margin=8):",
        "  HBoxContainer (spacing=20):",
        "    LEFT: VBoxContainer (PV)",
        "      Label: 'PV N/N' (14pt, terminal font)",
        "        color: phosphor (>50%), warning (25-50%), danger (<25%)",
        "      ProgressBar (120x10, bg_dark fill, phosphor_dim bar)",
        "    CENTER: Label: souffle '* * * o o o o' (16pt, souffle/cyan)",
        "    RIGHT: Label: essences '~ N' (14pt, amber, right-aligned)",
        "",
        "CENTER: Label: crosshair '+' (14pt, phosphor_dim, centered)",
        "",
        "BOTTOM-LEFT: Label: zone 'Biome | Season | Time' (11pt, phosphor_dim)",
    ]))

    parts.append(section("COLOR MAP", [
        "PV label:          phosphor (>50%) / warning (25-50%) / danger (<25%)",
        "PV bar bg:         bg_dark — " + CRT_PALETTE["bg_dark"],
        "PV bar border:     border — " + CRT_PALETTE["border"],
        "PV bar fill:       phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
        "Souffle icons:     souffle — " + CRT_PALETTE["souffle"],
        "Essences:          amber — " + CRT_PALETTE["amber"],
        "Crosshair:         phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
        "Zone label:        phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
    ]))

    parts.append(section("COMPONENT INVENTORY", [
        "CanvasLayer (layer=5)",
        "  Control (_root, FULL_RECT, MOUSE_FILTER_IGNORE)",
        "    MarginContainer (TOP_WIDE, margins: h=12, v=8)",
        "      HBoxContainer (spacing=20)",
        "        VBoxContainer [PV]",
        "          Label: _pv_label (14pt, terminal font)",
        "          ProgressBar: _pv_bar (120x10, no percentage)",
        "        Control: spacer (EXPAND_FILL)",
        "        Label: _souffle_label (16pt, terminal font, centered)",
        "        Control: spacer (EXPAND_FILL)",
        "        Label: _essences_label (14pt, terminal font, right)",
        "    Label: _crosshair '+' (CENTER preset, 14pt)",
        "    MarginContainer (BOTTOM_LEFT, margins: h=12, v=8)",
        "      Label: _zone_label (11pt, terminal font)",
    ]))

    parts.append(section("ANIMATION TIMELINE", [
        "Continuous:   3D rail camera moves forward at walk speed",
        "Continuous:   Particles system active per biome config",
        "on collect:   Essence pickup flash + ANAM_GAIN sfx",
        "on card:      Fade to black -> card screen -> fade back",
        "PV update:    Immediate color shift at thresholds (25%, 50%)",
        "Zone toggle:  _zone_label visibility toggle (no tween)",
    ]))

    parts.append(section("SOUND EVENT MAP", [
        "WALK_STEP:          continuous footstep loop during movement",
        "RUN_AMBIENT:        continuous biome ambient sound loop",
        "BIOME_TRANSITION:   on entering a new biome zone",
        "LIFE_DRAIN:         on PV decrease (-1/card at DRAIN step)",
        "LIFE_HEAL:          on PV increase (heal effects)",
        "ANAM_GAIN:          on collecting essence in 3D",
        "CARD_DRAW:          on walk event triggers card transition",
    ]))

    return f"\n{'=' * 60}\n  SCREEN PREVIEW: RUN (3D Walk + HUD)\n{'=' * 60}\n" + "\n".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN: END_SCREEN (3-screen flow)
# ═══════════════════════════════════════════════════════════════════════════════

def preview_end_screen() -> str:
    parts: list[str] = []

    wireframe = textwrap.dedent("""\
    SCREEN 1/3: NARRATIVE ENDING
    +============================================================+
    |                                                            |
    |  "Les tenebres t'enveloppent. Le monde celtique            |
    |   s'estompe, mais ton ame persiste. Tu reviendras."        |
    |                                                            |
    |  Reason: death / hard_max / normal                         |
    |                                                            |
    |                    [CONTINUER >>]                           |
    +============================================================+

    SCREEN 2/3: JOURNEY MAP
    +============================================================+
    |  CARTE DU VOYAGE                                           |
    |                                                            |
    |  O---#1 La Foret Enchantee [Explorer]       (phosphor)     |
    |  |                                                         |
    |  O---#2 Le Cercle de Pierres [Invoquer]     (phosphor)     |
    |  |                                                         |
    |  O---#3 La Riviere Sacree [Traverser]       (phosphor)     |
    |  |                                                         |
    |  O---#4 Le Druide Ancien [Negocier]         (phosphor)     |
    |  |                                                         |
    |  (O)--#5 Fin du voyage                      (amber/danger) |
    |                                                            |
    |  Max 12 visible nodes, scrolls to show last entries        |
    |  Victory: final node = amber    Death: final node = danger |
    |                    [CONTINUER >>]                           |
    +============================================================+

    SCREEN 3/3: REWARDS SUMMARY
    +============================================================+
    |  RECOMPENSES                                               |
    |                                                            |
    |  Anam gagne:      +45                                     |
    |  Cartes jouees:   12                                       |
    |  Minigames gagnes: 8                                       |
    |                                                            |
    |  REPUTATION DELTA:                                         |
    |  Druides:   +15                                            |
    |  Anciens:   +5                                             |
    |  Korrigans: -3                                             |
    |                                                            |
    |  Confiance Merlin: +2                                      |
    |  Promesses tenues: 3    brisees: 1                         |
    |                                                            |
    |         [RETOUR AU HUB]  or  [CHOISIR FACTION]             |
    +============================================================+

    SCREEN 4/4 (OPTIONAL): FACTION CHOICE
    +============================================================+
    |  CHOIX DE FACTION (2+ factions >= 80)                      |
    |                                                            |
    |  [Druides]  [Anciens]                                      |
    |                                                            |
    |  Choose one faction for special ending unlock              |
    +============================================================+""")
    parts.append(wireframe)

    parts.append(section("COLOR MAP", [
        "Narrative text:     phosphor — " + CRT_PALETTE["phosphor"],
        "Journey nodes:      phosphor_dim — " + CRT_PALETTE["phosphor_dim"],
        "Journey lines:      line — " + CRT_PALETTE["line"],
        "Node with choice:   phosphor — " + CRT_PALETTE["phosphor"],
        "Victory final node: amber — " + CRT_PALETTE["amber"],
        "Death final node:   danger — " + CRT_PALETTE["danger"],
        "Empty message:      phosphor_dim ('Aucune carte jouee')",
        "Rewards labels:     phosphor — " + CRT_PALETTE["phosphor"],
        "Positive deltas:    success — " + CRT_PALETTE["success"],
        "Negative deltas:    danger — " + CRT_PALETTE["danger"],
    ]))

    parts.append(section("COMPONENT INVENTORY", [
        "EndRunScreen (Node, 4 screen states)",
        "  Screen 0 — NARRATIVE:",
        "    Text display (LLM ending or fallback by reason)",
        "    Fallback texts: death / hard_max / default",
        "  Screen 1 — JOURNEY MAP:",
        "    JourneyMapDisplay (Control, custom _draw)",
        "      NODE_RADIUS=6, LINE_WIDTH=2, NODE_SPACING=32",
        "      LEFT_MARGIN=24, TEXT_OFFSET_X=20",
        "      MAX_VISIBLE_NODES=12, LABEL_FONT_SIZE=13",
        "      Vertical path with circles + connecting lines",
        "      Entry label: '#N text [choice]' (max 40 chars, truncated)",
        "      Final node: double circle with V or X icon",
        "  Screen 2 — REWARDS:",
        "    Display dict: anam, faction_rep_delta, trust_delta,",
        "    biome_currency, cards_played, minigames_won,",
        "    promises_kept, promises_broken",
        "  Screen 3 — FACTION CHOICE (optional):",
        "    Shows if 2+ factions >= 80 rep",
        "    Buttons for each eligible faction",
    ]))

    parts.append(section("ANIMATION TIMELINE", [
        "Screen transitions: advance_screen() increments _current_screen",
        "Narrative text:     Likely phosphor_reveal tween (0.4s fade-in)",
        "Journey map:        Nodes drawn via _draw() on queue_redraw()",
        "Rewards:            Sequential reveal of reward lines",
        "Skip faction choice if < 2 factions eligible",
        "After all screens:  return_to_hub signal emitted",
    ]))

    parts.append(section("SOUND EVENT MAP", [
        "SCORE_REVEAL:      on rewards screen display",
        "ANAM_GAIN:         on anam earned reveal",
        "REP_UP:            for each positive faction delta",
        "REP_DOWN:          for each negative faction delta",
        "VICTORY:           if run ended normally (not death)",
        "DEATH:             if run ended by death (PV=0)",
        "MENU_CLICK:        on 'CONTINUER' / 'RETOUR AU HUB' press",
        "PROMISE_FULFILL:   for each promise kept",
        "PROMISE_BREAK:     for each promise broken",
    ]))

    return f"\n{'=' * 60}\n  SCREEN PREVIEW: END SCREEN (3-4 screens)\n{'=' * 60}\n" + "\n".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN: CARD (3 options layout)
# ═══════════════════════════════════════════════════════════════════════════════

def preview_card() -> str:
    parts: list[str] = []

    wireframe = textwrap.dedent("""\
    +============================================================+
    | TOP STATUS BAR (12% height)                                |
    |  [PV 85/100 [####....]]  [* * * o o o o]  [Essences: ~12] |
    |  (LifePanel)             (SoufflePanel)   (EssencePanel)   |
    +------------------------------------------------------------+
    |                                                            |
    |  MIDDLE ZONE (70% height)                                  |
    |                                                            |
    |  [Pioche]     CARD PANEL                        [Cimetiere]|
    |  [Deck ]     +----------------------------------+  [Discard]|
    |  [ 12  ]     | ILLUSTRATION (CardIllustration)  |  [  3   ]|
    |              | Pixel scene compositor:           |          |
    |              |   SKY layer (parallax=0)          |          |
    |              |   TERRAIN layer (parallax=0.3)    |          |
    |              |   SUBJECT layer (parallax=0.6)    |          |
    |              |   ATMOSPHERE layer (parallax=0)   |          |
    |              |   + Character Portrait overlay    |          |
    |              |   + NPC Portrait overlay           |          |
    |              +----------------------------------+          |
    |              | CARD BODY                         |          |
    |              |   Speaker: "Le Druide" (amber)   |          |
    |              |   Text: "Vous arrivez..."        |          |
    |              |   (RichTextLabel, phosphor)       |          |
    |              +----------------------------------+          |
    |              [LLM Source Badge]                             |
    |                                                            |
    +------------------------------------------------------------+
    | BOTTOM ZONE (18% height)                                   |
    |                                                            |
    |  +------------+  +------------+  +------------+            |
    |  | [A]        |  | [B]        |  | [C]        |            |
    |  | Explorer   |  | Negocier   |  | Fuir       |            |
    |  | (option 0) |  | (option 1) |  | (option 2) |            |
    |  +------------+  +------------+  +------------+            |
    |                                                            |
    |  Mission: "Trouver le druide"    Cartes: 5/30              |
    |  (MissionLabel)                  (CardsLabel)              |
    +============================================================+""")
    parts.append(wireframe)

    parts.append(section("COLOR MAP", [
        "Background:         ParchmentBg (ColorRect, full screen)",
        "  Currently using:  bg_deep (CRT) or paper (legacy)",
        "Card panel:         bg_panel border with bg_dark fill",
        "Illustration bg:    IlloBg ColorRect (biome-tinted)",
        "Speaker label:      amber — " + CRT_PALETTE["amber"],
        "Card text:          phosphor — " + CRT_PALETTE["phosphor"],
        "Option buttons A/B/C: CRT button theme",
        "  Normal state:     choice_normal — " + CRT_PALETTE["phosphor_dim"],
        "  Hover state:      choice_hover — " + CRT_PALETTE["phosphor"],
        "  Selected state:   choice_selected — " + CRT_PALETTE["amber"],
        "Deck/Discard counts: phosphor_dim",
        "LLM source badge:   llm_bg + llm_text (phosphor green on dark)",
        "Mission label:      phosphor_dim",
        "Cards counter:      phosphor_dim",
        "Life bar:           same as WalkHUD (color shifts at thresholds)",
        "Souffle icons:      souffle (cyan) — " + CRT_PALETTE["souffle"],
        "Essences:           amber — " + CRT_PALETTE["amber"],
    ]))

    parts.append(section("COMPONENT INVENTORY", [
        "MerlinGameUI (Control, class_name, extends Control)",
        "  ColorRect: ParchmentBg (full screen background)",
        "  Control: BiomeArtLayer (biome-specific background art)",
        "  VBoxContainer: MainVBox",
        "    HBoxContainer: TopStatusBar (12% height)",
        "      VBoxContainer: LifePanel",
        "        ProgressBar: LifeBar + Label: LifeCounter",
        "      VBoxContainer: SoufflePanel",
        "        HBoxContainer: SouffleIcons + Label: SouffleCounter",
        "      Panel: EssencePanel + Label: EssenceCounter",
        "    HBoxContainer: MiddleZone (70% height)",
        "      VBoxContainer: PiocheColumn (draw deck)",
        "        Control: DeckRoot (stacked card backs)",
        "        Label: DeckCount",
        "      Control: CardContainer",
        "        Panel: CardPanel",
        "          VBoxContainer: CardVisualSplit",
        "            PanelContainer: CardIllustration",
        "              IlloLayer: IlloBg + TileCenter + PortraitCenter",
        "            PanelContainer: CardBodyPanel",
        "              VBoxContainer: CardBodyVBox",
        "                Label: CardSpeaker",
        "                RichTextLabel: CardText",
        "            Control: TextPixelFxLayer (scanline/glitch effects)",
        "      VBoxContainer: CimetiereColumn (discard pile)",
        "        Control: DiscardRoot (stacked discarded cards)",
        "        Label: DiscardCount",
        "    VBoxContainer: BottomZone (18% height)",
        "      HBoxContainer: OptionsBar",
        "        VBoxContainer: OptionVBoxA -> Button: BtnA",
        "        VBoxContainer: OptionVBoxB -> Button: BtnB",
        "        VBoxContainer: OptionVBoxC -> Button: BtnC",
        "      HBoxContainer: InfoPanel",
        "        Label: MissionLabel",
        "        Label: CardsLabel",
        "  Control: DeckFxLayer (card deal animation overlay)",
        "  PanelContainer: ClockPanel + Label: ClockLabel",
        "  Control: NarratorOverlay",
        "",
        "Dynamic nodes (created in code):",
        "  PanelContainer: _card_source_badge (LLM source indicator)",
        "  PixelSceneCompositor: scene compositor v1 (pixel art)",
        "  Control: scene compositor v2 (layered sprite, feature flag)",
        "  PixelCharacterPortrait: player pixel portrait",
        "  PixelNpcPortrait: NPC pixel portrait",
        "  MerlinRewardBadge: reward badge on option hover",
    ]))

    parts.append(section("CARD ILLUSTRATION LAYERS", [
        "CardLayer.Type.SKY:        Background sky (parallax=0)",
        "CardLayer.Type.TERRAIN:    Ground/landscape (parallax=0.3)",
        "CardLayer.Type.SUBJECT:    Main character/NPC (parallax=0.6)",
        "CardLayer.Type.ATMOSPHERE: Fog/wisps overlay (parallax=0)",
        "Default layer size:        440x220 pixels",
        "idle_motion types:         sway, breathe, drift",
        "particles_config types:    fog, wisp (atmosphere layers)",
        "Layers stagger reveal:     0.08s between, 0.30s each",
    ]))

    parts.append(section("ANIMATION TIMELINE", [
        f"Card entry:       CARD_ENTRY_DURATION = {ANIM_CONSTANTS['CARD_ENTRY_DURATION']}",
        f"Card exit:        CARD_EXIT_DURATION = {ANIM_CONSTANTS['CARD_EXIT_DURATION']}",
        f"Card deal:        CARD_DEAL_DURATION = {ANIM_CONSTANTS['CARD_DEAL_DURATION']}",
        f"Card idle float:  CARD_FLOAT_DURATION = {ANIM_CONSTANTS['CARD_FLOAT_DURATION']}",
        f"Layer reveal:     LAYER_REVEAL_STAGGER = {ANIM_CONSTANTS['LAYER_REVEAL_STAGGER']}",
        f"Layer fade-in:    LAYER_REVEAL_DURATION = {ANIM_CONSTANTS['LAYER_REVEAL_DURATION']}",
        f"Option slide-in:  OPTION_SLIDE_DURATION = {ANIM_CONSTANTS['OPTION_SLIDE_DURATION']}",
        f"Phosphor reveal:  CRT_PHOSPHOR_FADE = {ANIM_CONSTANTS['CRT_PHOSPHOR_FADE']}",
        f"Glitch effect:    CRT_GLITCH_DURATION = {ANIM_CONSTANTS['CRT_GLITCH_DURATION']}",
        f"Breathe loop:     BREATHE_DURATION = {ANIM_CONSTANTS['BREATHE_DURATION']}",
        f"Easing:           {ANIM_CONSTANTS['EASING_UI']}",
        "Portrait entry:   Scale from 0 -> 1 with bounce",
        "Text reveal:      Typewriter or phosphor_reveal tween",
        "Deck stack:       Cards slide from pioche -> card panel",
        "Discard:          Card slides from panel -> cimetiere",
    ]))

    parts.append(section("SOUND EVENT MAP", [
        "CARD_DRAW:       on new card presented (deck -> panel)",
        "CARD_FLIP:       on card illustration reveal",
        "OPTION_SELECT:   on player clicks option A/B/C",
        "MINIGAME_START:  on minigame overlay opens",
        "MINIGAME_END:    on minigame overlay closes",
        "SCORE_REVEAL:    on minigame score shown",
        "EFFECT_POSITIVE: on positive effect applied (heal, rep_up)",
        "EFFECT_NEGATIVE: on negative effect applied (damage, rep_down)",
        "OGHAM_ACTIVATE:  on ogham used before choice",
        "OGHAM_COOLDOWN:  when ogham enters cooldown",
        "LIFE_DRAIN:      on -1 PV drain at card start",
        "PROMISE_CREATE:  on new promise created by choice",
        "MENU_HOVER:      on option button focus",
    ]))

    return f"\n{'=' * 60}\n  SCREEN PREVIEW: CARD (3 options)\n{'=' * 60}\n" + "\n".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN: BIOME (per-biome 3D environment description)
# ═══════════════════════════════════════════════════════════════════════════════

def preview_biome(biome_id: str) -> str:
    biome = BIOMES.get(biome_id)
    if biome is None:
        return f"Unknown biome: {biome_id}\nAvailable: {', '.join(BIOMES.keys())}"

    parts: list[str] = []
    name = biome["name"]

    # ASCII landscape
    particle_char = {
        "mist": "~~~",
        "fireflies": "* . *",
        "rain": "/ / /",
        "snow": "o . o",
        "none": "     ",
    }
    p = particle_char.get(biome["particles"], "     ")
    density_bar = bar_ascii(int(biome["tree_density"] * 100), 200, 10)
    fog_bar = bar_ascii(int(biome["fog_density"] * 1000), 150, 10)

    wireframe = textwrap.dedent(f"""\
    +============================================================+
    |  {name:^56}  |
    |                                                            |
    |  SKY: {biome['sky']:<50}  |
    |  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  |
    |       {p}            {p}           {p}              |
    |  {p}          {p}            {p}                    |
    |                                                            |
    |  FOG: {biome['fog']:<50}  |
    |  density: {biome['fog_density']:.3f}  {fog_bar}                      |
    |                                                            |
    |  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,  |
    |  GROUND: {biome['ground']:<47}  |
    |  trees: {density_bar}                                      |
    |                                                            |
    |  AMBIENT: {biome['ambient']:<46}  |
    |  energy: {biome['ambient_energy']:.2f}                                     |
    +============================================================+""")
    parts.append(wireframe)

    parts.append(section("ENVIRONMENT PROPERTIES", [
        f"Biome ID:         {biome_id}",
        f"Display name:     {name}",
        f"Season:           {biome['season']}",
        f"Sky color:        {biome['sky']}",
        f"Ground color:     {biome['ground']}",
        f"Fog color:        {biome['fog']}",
        f"Fog density:      {biome['fog_density']} (range 0.0 - 0.15)",
        f"Ambient light:    {biome['ambient']}",
        f"Ambient energy:   {biome['ambient_energy']} (range 0.1 - 1.5)",
        f"Tree density:     {biome['tree_density']} (range 0.0 - 2.0)",
        f"Particle type:    {biome['particles']}",
        f"Particle desc:    {PARTICLE_DESC.get(biome['particles'], 'N/A')}",
        f"CRT palette:      {biome['crt_palette']}",
    ]))

    parts.append(section("COLOR MAP", [
        f"Sky dome:          {biome['sky']}",
        f"Ground plane:      {biome['ground']}",
        f"Fog volume:        {biome['fog']}",
        f"Ambient light:     {biome['ambient']}",
        f"CRT 8-color ramp:  {biome['crt_palette']}",
        "Pixel art tiles:   Uses BIOME_CRT_PALETTES[biome_short_name]",
        "Card backgrounds:  Tinted by biome palette (index 0-1 for dark)",
    ]))

    parts.append(section("SOUND EVENT MAP", [
        "RUN_AMBIENT:         Biome-specific ambient loop (continuous)",
        "WALK_STEP:           Footsteps adapted to ground type",
        "BIOME_TRANSITION:    On entering this biome from another",
        f"Particle SFX:       {'Rain patter / Wind howl' if biome['particles'] == 'rain' else 'Subtle ambient' if biome['particles'] == 'snow' else 'Cricket chirps' if biome['particles'] == 'fireflies' else 'Soft wind' if biome['particles'] == 'mist' else 'None'}",
    ]))

    return (
        f"\n{'=' * 60}\n"
        f"  SCREEN PREVIEW: BIOME — {name}\n"
        f"{'=' * 60}\n"
        + "\n".join(parts)
    )


# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL: ANIMATION + SFX REFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

def preview_reference() -> str:
    parts: list[str] = []

    parts.append(section("ALL ANIMATION CONSTANTS", [
        f"{k:30s} {v}" for k, v in ANIM_CONSTANTS.items()
    ]))

    parts.append(section("ALL SFX CATALOG", [
        f"{i:2d}. {sfx}" for i, sfx in enumerate(SFX_CATALOG)
    ]))

    parts.append(section("ALL CRT_PALETTE COLORS", [
        f"{k:22s} {v}" for k, v in CRT_PALETTE.items()
    ]))

    parts.append(section("ALL FACTION COLORS", [
        f"{k:12s} {FACTION_SYMBOLS[k]}  {v}" for k, v in FACTION_COLORS.items()
    ]))

    return (
        f"\n{'=' * 60}\n"
        f"  REFERENCE: Animation + SFX + Colors\n"
        f"{'=' * 60}\n"
        + "\n".join(parts)
    )


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

SCREEN_REGISTRY: dict[str, object] = {
    "hub": preview_hub,
    "run": preview_run,
    "end_screen": preview_end_screen,
    "card": preview_card,
    "reference": preview_reference,
}

# Add biome screens
for _bid in BIOMES:
    SCREEN_REGISTRY[f"biome_{_bid}"] = lambda bid=_bid: preview_biome(bid)


def print_usage() -> None:
    print("Usage: python tools/visual_preview.py <screen>")
    print()
    print("Available screens:")
    print("  hub              Hub 2D (between runs)")
    print("  run              3D Walk + HUD overlay")
    print("  end_screen       End-of-run (narrative + journey + rewards)")
    print("  card             Card display (3 options)")
    print("  reference        All animations, SFX, and colors")
    for bid in BIOMES:
        bname = BIOMES[bid]["name"]
        print(f"  biome_{bid:20s} {bname}")
    print("  all              Generate all screens")
    print()
    print("Example:")
    print("  python tools/visual_preview.py hub")
    print("  python tools/visual_preview.py biome_foret_broceliande")
    print("  python tools/visual_preview.py all")


def main() -> None:
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(0)

    screen = sys.argv[1].strip().lower()

    if screen in ("help", "--help", "-h"):
        print_usage()
        sys.exit(0)

    if screen == "all":
        for name, fn in SCREEN_REGISTRY.items():
            print(fn())
            print()
        sys.exit(0)

    fn = SCREEN_REGISTRY.get(screen)
    if fn is None:
        print(f"Error: Unknown screen '{screen}'")
        print()
        print_usage()
        sys.exit(1)

    print(fn())


if __name__ == "__main__":
    main()
