# Calendar Scene Visual Specification

## Art Direction Report

### Asset/Feature: Calendar.tscn

### Overview

The Calendar scene displays game time, seasons, and Celtic festivals. It is accessed from the main menu via the "CAL" corner button. The design must feel like a natural extension of the Reigns-style main menu - a mystical parchment scroll or ancient druidic tome revealing the flow of time.

---

## Visual Analysis

### Design Philosophy

The Calendar should evoke the feeling of consulting an ancient Breton manuscript or a druid's personal almanac. Unlike the Collection scene (which uses a dark, gold-accented palette for a "trophy room" feel), the Calendar maintains the warm paper/ink aesthetic of the main menu to feel like the same physical artifact - just a different page.

### Layout Style: Vertical Scroll

The Calendar uses a **single card/scroll layout** that echoes the main menu's central card. This creates visual continuity and reinforces the "turning pages of a mystical journal" metaphor.

```
+----------------------------------+
|         [paper background]        |
|                                   |
|   +---------------------------+   |
|   |     CALENDRIER CELTIQUE   |   |  <- Title
|   |     ~~~~~~~~~~~~~~~~~~~   |   |  <- Decorative line
|   |                           |   |
|   |   [Season Indicator]      |   |  <- Current season with icon
|   |   Hiver - Jour 42         |   |  <- Season label + day count
|   |                           |   |
|   |   ═══════════════════     |   |  <- Separator
|   |                           |   |
|   |   Aujourd'hui             |   |  <- "Today" section
|   |   6 Fevrier 2026          |   |  <- Current date
|   |   Heure: Crepuscule       |   |  <- Current hour slice
|   |                           |   |
|   |   ═══════════════════     |   |
|   |                           |   |
|   |   Evenements Actifs       |   |  <- Active events header
|   |   +-------------------+   |   |
|   |   | [Event Card]      |   |   |  <- Scrollable event list
|   |   | Serment des       |   |   |
|   |   | Sources           |   |   |
|   |   | 02/02 - ritual    |   |   |
|   |   +-------------------+   |   |
|   |                           |   |
|   |   Prochains Evenements    |   |  <- Upcoming events
|   |   +-------------------+   |   |
|   |   | [Event Row]       |   |   |
|   |   +-------------------+   |   |
|   |                           |   |
|   +---------------------------+   |
|                                   |
|   [<] Retour                      |  <- Back button (bottom-left)
+----------------------------------+
```

---

## Color Palette

### Primary Colors (from MenuPrincipalMerlin.gd)

```gdscript
const CALENDAR_PALETTE := {
    # Base colors (inherited from main menu)
    "paper": Color(0.96, 0.92, 0.84),        # #F5EBD7 - warm parchment
    "paper_dark": Color(0.93, 0.88, 0.80),   # #EDE0CC - aged parchment
    "ink": Color(0.12, 0.10, 0.08),          # #1F1A14 - deep brown-black
    "ink_soft": Color(0.18, 0.16, 0.13),     # #2E2921 - softer ink
    "accent": Color(0.46, 0.18, 0.16),       # #752D29 - dried blood/rust
    "accent_soft": Color(0.62, 0.28, 0.20),  # #9E4733 - lighter accent

    # Functional colors
    "shadow": Color(0.05, 0.05, 0.05, 0.35), # Card shadow
    "line": Color(0.12, 0.10, 0.08, 0.18),   # Separator lines

    # Season-specific accent colors
    "winter": Color(0.23, 0.36, 0.60),       # #3B5C99 - mystic blue/frost
    "spring": Color(0.29, 0.36, 0.14),       # #4A5D23 - moss green
    "summer": Color(0.79, 0.64, 0.15),       # #C9A227 - gold/sun
    "autumn": Color(0.55, 0.27, 0.07),       # #8C4512 - burnt orange/rust

    # Event state colors
    "active_event": Color(0.46, 0.18, 0.16), # accent - event happening now
    "upcoming_event": Color(0.18, 0.16, 0.13), # ink_soft - future events
    "passed_event": Color(0.30, 0.26, 0.22, 0.5), # faded ink
}
```

### Season Color Application

Each season subtly tints certain UI elements:

| Season   | Tint Application                          | Hex     |
|----------|-------------------------------------------|---------|
| Hiver    | Season icon, active event border          | #3B5C99 |
| Printemps| Season icon, active event border          | #4A5D23 |
| Ete      | Season icon, active event border          | #C9A227 |
| Automne  | Season icon, active event border          | #8C4512 |

The tint is applied sparingly - only to the season indicator and event accent borders - to maintain the paper/ink cohesion.

---

## Typography

### Font Family
- **Display/Title**: MorrisRomanBlack (medieval feel)
- **Body**: MorrisRomanBlackAlt
- **Fallback**: System serif or Arial

### Size Hierarchy

| Element              | Size (Desktop) | Size (Mobile) | Style      |
|----------------------|----------------|---------------|------------|
| Scene Title          | 42px           | 28px          | Bold, ink  |
| Section Headers      | 24px           | 18px          | Bold, ink  |
| Season Label         | 20px           | 16px          | Bold, season color |
| Current Date         | 28px           | 20px          | Bold, accent |
| Hour Label           | 18px           | 14px          | Regular, ink_soft |
| Event Name           | 18px           | 14px          | Bold, ink  |
| Event Details        | 14px           | 12px          | Regular, ink_soft |
| Back Button          | 16px           | 14px          | Regular, ink |

---

## Season Visual Indicators

### Season Icons (32x32 or 64x64)

Simple silhouette icons in the Reigns style (flat, 2-3 colors max):

```
HIVER (Winter)
+--------+
|   /\   |  Snowflake or bare tree silhouette
|  /  \  |  Color: winter blue on paper
| /    \ |
|  \  /  |
|   \/   |
+--------+

PRINTEMPS (Spring)
+--------+
|   ()   |  Budding branch or flower
|  /||\  |  Color: moss green on paper
| / || \ |
|   ||   |
+--------+

ETE (Summer)
+--------+
|   __   |  Sun disc with rays
|  /  \  |  Color: gold on paper
| |    | |
|  \__/  |
|   ||   |
+--------+

AUTOMNE (Autumn)
+--------+
|   /\   |  Falling leaf or oak leaf
|  /  \  |  Color: burnt orange on paper
| /____\ |
|   ||   |
+--------+
```

### Season Display Component

```
+------------------------------------------+
|  [Icon]  HIVER                           |
|          Jour 42 de la saison            |
|          ~~~~~~~~~~~~~~~~~~~~~~~~        |  <- subtle underline
+------------------------------------------+
```

- Icon size: 48x48 (desktop), 32x32 (mobile)
- Season name in season color
- Day count in ink_soft

---

## Festival/Event Styling

### Event Card (Active/Today)

```
+---------------------------------------+
|  [border: 2px season_color]           |
|                                       |
|  Veillee des Menhirs                  |  <- Event name (bold, ink)
|                                       |
|  5 Janvier 2026                       |  <- Date (ink_soft)
|  ritual - menhir - spirit             |  <- Tags (small, ink_soft)
|                                       |
|  "Rituel d'ancrage, points de         |  <- Notes (italic, ink_soft)
|   menhir plus actifs."                |
|                                       |
|  [Hour bonus indicator]               |
|  20h-24h: +40%                        |  <- Hour bonus (accent)
+---------------------------------------+
```

**Active Event Card Style:**
```gdscript
var active_event_style := StyleBoxFlat.new()
active_event_style.bg_color = PALETTE.paper_dark
active_event_style.border_color = current_season_color  # Dynamic
active_event_style.border_width_left = 3
active_event_style.border_width_top = 1
active_event_style.border_width_right = 1
active_event_style.border_width_bottom = 1
active_event_style.corner_radius_top_left = 6
active_event_style.corner_radius_top_right = 6
active_event_style.corner_radius_bottom_left = 6
active_event_style.corner_radius_bottom_right = 6
active_event_style.shadow_color = PALETTE.shadow
active_event_style.shadow_size = 4
active_event_style.content_margin_left = 12
active_event_style.content_margin_top = 10
active_event_style.content_margin_right = 12
active_event_style.content_margin_bottom = 10
```

### Event Row (Upcoming/List View)

```
+---------------------------------------+
| [Date]  |  [Event Name]      | [Tag]  |
| 21/01   |  Brume de l'Ankou  | brume  |
+---------------------------------------+
```

- Simple horizontal layout
- Date in fixed-width column (ink_soft)
- Event name truncated if needed (ink)
- Primary tag as subtle badge

### Event Tags as Visual Badges

Tags appear as small inline badges:

```gdscript
# Tag badge style
var tag_style := StyleBoxFlat.new()
tag_style.bg_color = Color(PALETTE.ink.r, PALETTE.ink.g, PALETTE.ink.b, 0.08)
tag_style.corner_radius_top_left = 3
tag_style.corner_radius_top_right = 3
tag_style.corner_radius_bottom_left = 3
tag_style.corner_radius_bottom_right = 3
tag_style.content_margin_left = 6
tag_style.content_margin_right = 6
tag_style.content_margin_top = 2
tag_style.content_margin_bottom = 2
```

---

## Hour/Time Display

### Current Hour Indicator

```
+---------------------------------------+
|  HEURE ACTUELLE                       |
|                                       |
|  [====|================] 17h          |
|       ^-- marker                      |
|                                       |
|  Crepuscule                           |  <- Hour label
|  "Le soir s'installe..."              |  <- Flavor text (optional)
+---------------------------------------+
```

**Hour bar style:**
- Track: paper_dark with 1px ink border
- Fill: gradient from ink (0h) to accent (12h) to ink (24h)
- Marker: 4px wide, accent color
- Height: 12px

Alternatively, a simpler text-only display:

```
+---------------------------------------+
|  17h00 - Crepuscule                   |
|  [ritual] [mystery]                   |  <- Active hour tags
+---------------------------------------+
```

---

## Navigation and Back Button

### Back Button Style

Positioned bottom-left, matching main menu corner button style:

```gdscript
# Back button - text only, no border
back_button.text = "< Retour"
back_button.flat = true
back_button.custom_minimum_size = Vector2(80, 48)
back_button.add_theme_font_override("font", body_font)
back_button.add_theme_font_size_override("font_size", 16)
back_button.add_theme_color_override("font_color", PALETTE.ink_soft)
back_button.add_theme_color_override("font_hover_color", PALETTE.accent)
```

### Swipe Transition

When navigating back, use the same swipe animation as the main menu:
- Card rotates 7 degrees
- Slides 140px in exit direction
- Fades to transparent over 0.2s

---

## Responsive Layout

### Desktop (width > 560px)

```
+------------------------------------------+
|                                          |
|      +----------------------------+      |
|      |                            |      |
|      |   [Full Calendar Card]     |      |
|      |   Max width: 600px         |      |
|      |   Centered                 |      |
|      |                            |      |
|      +----------------------------+      |
|                                          |
| [<]                                      |
+------------------------------------------+
```

### Mobile (width <= 560px)

```
+------------------------+
| [Season] HIVER         |
| Jour 42                |
+------------------------+
| Aujourd'hui            |
| 6 Fevrier - Crepuscule |
+------------------------+
| Evenements             |
| [Event cards stack]    |
|                        |
+------------------------+
| [<] Retour             |
+------------------------+
```

- Reduce margins (10px vs 20px)
- Stack elements vertically
- Smaller fonts (see typography table)
- Event cards full-width

---

## Decorative Elements

### Separator Lines

```
═══════════════════════════
```

Simple horizontal rules using the `line` color:
- Height: 1px
- Margin: 16px vertical
- Style: solid (not dashed, to match Reigns simplicity)

### Celtic Knotwork (Optional)

If decorative flourishes are desired, use simple Celtic knot corners:

```
    ╔═══╗
────╢   ╟────
    ╚═══╝
```

- Drawn in ink color at 20% opacity
- Corner decorations only, not busy patterns
- Maximum 4 small motifs per screen

### Paper Texture

Background uses the same paper color as main menu. Optional subtle texture:
- Paper grain at 5% opacity maximum
- No heavy distressing
- Consistent with Reigns minimal aesthetic

---

## Animation Specifications

### Entry Animation

When opening the Calendar:
1. Paper background fades in (0.15s)
2. Card slides up from bottom (0.2s, ease-out)
3. Content fades in staggered (0.1s each element)

### Season Change Animation

When the season changes (rare, end of season):
1. Season icon pulses once (scale 1.0 -> 1.2 -> 1.0, 0.3s)
2. Season color transitions smoothly (0.5s)
3. Brief particle effect (optional) - falling leaves, snowflakes, etc.

### Event Highlight

Active events have a subtle glow pulse:
```gdscript
# Glow animation for active event
var tween = create_tween().set_loops()
tween.tween_property(event_card, "modulate:a", 0.9, 0.8)
tween.tween_property(event_card, "modulate:a", 1.0, 0.8)
```

---

## Style Check

- [x] Color palette compliance (paper/ink/accent from main menu)
- [x] Typography correct (MorrisRoman family)
- [x] Consistent with existing assets (matches MenuPrincipalMerlin.gd)
- [x] Merlin style guide compliance (flat, minimal, silhouette-first)
- [x] Responsive considerations for mobile

---

## Asset Needs

| Asset               | Size      | Priority | Description                           |
|---------------------|-----------|----------|---------------------------------------|
| icon_season_winter  | 64x64     | High     | Snowflake/bare tree silhouette        |
| icon_season_spring  | 64x64     | High     | Budding branch silhouette             |
| icon_season_summer  | 64x64     | High     | Sun disc silhouette                   |
| icon_season_autumn  | 64x64     | High     | Falling leaf silhouette               |
| divider_celtic      | 320x16    | Low      | Optional Celtic knot separator        |
| corner_knot         | 32x32     | Low      | Optional corner decoration            |

---

## Implementation Notes

### Scene Structure

```
Calendar (Control)
├── Background (ColorRect)
├── CalendarCard (PanelContainer)
│   └── CardContents (VBoxContainer)
│       ├── TitleSection (VBoxContainer)
│       │   ├── TitleLabel
│       │   └── Separator
│       ├── SeasonSection (HBoxContainer)
│       │   ├── SeasonIcon (TextureRect)
│       │   └── SeasonInfo (VBoxContainer)
│       ├── TodaySection (VBoxContainer)
│       │   ├── DateLabel
│       │   └── HourLabel
│       ├── EventsSection (VBoxContainer)
│       │   ├── ActiveEventsLabel
│       │   └── ActiveEventsList (ScrollContainer)
│       └── UpcomingSection (VBoxContainer)
│           ├── UpcomingLabel
│           └── UpcomingList (ScrollContainer)
└── BackButton (Button)
```

### Data Binding

The Calendar scene should read from:
- `calendar_2026.json` - Event definitions
- `hourly_facts.json` - Hour slice information
- Game state - Current date, time, season

### Related Files

- `c:/Users/PGNK2128/Godot-MCP/scripts/MenuPrincipalMerlin.gd` - Reference palette and card style
- `c:/Users/PGNK2128/Godot-MCP/themes/merlin_theme.tres` - Base theme to extend
- `c:/Users/PGNK2128/Godot-MCP/docs/40_world_rules/calendar_2026.json` - Event data
- `c:/Users/PGNK2128/Godot-MCP/docs/40_world_rules/HOURLY_SLICES_GUIDE.md` - Hour system

---

## Summary

The Calendar scene maintains visual harmony with the main menu through:

1. **Same paper/ink palette** - Feels like the same artifact
2. **Central card layout** - Consistent framing and composition
3. **Season-specific accents** - Subtle color variation for seasonal identity
4. **MorrisRoman typography** - Medieval manuscript feel
5. **Minimal decoration** - Follows Reigns flat, silhouette-first approach
6. **Smooth transitions** - Swipe and fade animations match main menu

The result should feel like turning a page in Merlin's personal almanac - mystical, timeless, and deeply rooted in Celtic tradition.
