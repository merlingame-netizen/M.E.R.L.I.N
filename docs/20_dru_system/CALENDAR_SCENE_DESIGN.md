# Calendar Scene Design Specification

**Document version**: 1.0
**Author**: Systems Game Designer
**Date**: 2026-02-06

---

## Game Design Report

### Topic: Calendar.tscn - Meta-Progression Information Screen

---

## Design Intent

The Calendar is a **meta-progression information screen** accessible from the main menu (bottom-left corner button). It provides players with:

1. **Temporal awareness** - Understanding where they are in the Celtic year
2. **Event preview** - Upcoming festivals and their gameplay implications
3. **Run retrospective** - Historical data from past runs
4. **Soft guidance** - Hints about optimal play times without hard-gating

The Calendar reinforces the game's themes:
- Brittany mystique and Celtic lore
- Time as a living system (not just decoration)
- Long-term engagement (Animal Crossing pacing)
- Merlin as overseer (his calendar, his world)

---

## Information Architecture

### Primary Display: Celtic Wheel of the Year

```
            SAMHAIN (Oct 31)
               /    \
    LUGHNASADH        IMBOLC (Feb 1)
    (Aug 1)    \    /
           [CURRENT DAY]
              /    \
    BELTANE           OSTARA
    (May 1)    \    /  (Mar 21)
             LITHA
            (Jun 21)
```

The wheel shows:
- Current position in the Celtic year
- Next approaching festival (highlighted)
- Season indicator (arc coloring)

### Secondary Display: Monthly Event List

Scrollable list showing events for current month:

```
+----------------------------------+
|  FEVRIER 2026                    |
|----------------------------------|
|  02  Serment des Sources    [*]  |
|  14  Lueur du Gui           [ ]  |
|  26  Veillee des Saules     [ ]  |
+----------------------------------+
[*] = Attended/Triggered
[ ] = Upcoming
```

### Tertiary Display: Run Statistics (Optional Tab)

```
+----------------------------------+
|  STATISTIQUES                    |
|----------------------------------|
|  Runs totaux:           12       |
|  Cartes jouees:         847      |
|  Jours survecus:        156      |
|  Fins vues:             5/8      |
|  Points de Gloire:      1280     |
+----------------------------------+
```

---

## Visual Design (Reigns Aesthetic)

### Color Palette (Matches existing themes)

```gdscript
const CALENDAR_COLORS := {
    # Base (paper/ink from Reigns theme)
    "paper": Color(0.96, 0.92, 0.84),
    "paper_dark": Color(0.93, 0.88, 0.80),
    "ink": Color(0.12, 0.10, 0.08),
    "ink_soft": Color(0.18, 0.16, 0.13),

    # Accent
    "accent": Color(0.46, 0.18, 0.16),  # Celtic red
    "accent_soft": Color(0.62, 0.28, 0.20),

    # Seasonal colors
    "spring": Color(0.45, 0.65, 0.35),   # Green growth
    "summer": Color(0.85, 0.70, 0.25),   # Golden warmth
    "autumn": Color(0.70, 0.40, 0.20),   # Bronze/rust
    "winter": Color(0.35, 0.45, 0.55),   # Cool blue-grey

    # Event states
    "event_past": Color(0.50, 0.48, 0.45),    # Muted
    "event_today": Color(0.84, 0.70, 0.38),   # Gold highlight
    "event_future": Color(0.12, 0.10, 0.08),  # Standard ink
}
```

### Typography

- **Title font**: MorrisRomanBlack (matches main menu)
- **Body font**: MorrisRomanBlackAlt
- **Size hierarchy**:
  - Screen title: 28-32px
  - Section headers: 20-24px
  - Event names: 16-18px
  - Dates/details: 12-14px

### Card-Based Layout

The calendar uses a **single central card** similar to the main menu, containing:

```
+----------------------------------------+
|            CALENDRIER CELTIQUE          |
|----------------------------------------|
|                                         |
|              [WHEEL OF YEAR]            |
|           (circular SVG/drawn)          |
|                                         |
|----------------------------------------|
|  Prochain evenement:                    |
|  14 Fevrier - Lueur du Gui              |
|  "Les branches de gui brillent..."      |
|----------------------------------------|
|  [EVENEMENTS]  [STATISTIQUES]           |
+----------------------------------------+
```

---

## Scene Structure (Calendar.tscn)

```
Calendar (Control)
+-- Background (ColorRect)
+-- CalendarCard (PanelContainer)
|   +-- CardContents (VBoxContainer)
|       +-- TitleLabel (Label) "CALENDRIER CELTIQUE"
|       +-- WheelContainer (Control)
|       |   +-- WheelSprite (Sprite2D or custom draw)
|       |   +-- CurrentDayMarker (Control)
|       |   +-- SeasonArc (custom draw)
|       +-- Separator (ColorRect)
|       +-- NextEventPanel (PanelContainer)
|       |   +-- EventVBox (VBoxContainer)
|       |       +-- NextLabel (Label) "Prochain evenement:"
|       |       +-- EventDateLabel (Label)
|       |       +-- EventNameLabel (Label)
|       |       +-- EventDescLabel (Label)
|       +-- TabsContainer (HBoxContainer)
|           +-- EventsTabBtn (Button)
|           +-- StatsTabBtn (Button)
+-- ContentPanel (PanelContainer)
|   +-- ContentScroll (ScrollContainer)
|       +-- EventsSection (VBoxContainer)
|       |   +-- MonthHeader (Label)
|       |   +-- EventList (VBoxContainer)
|       +-- StatsSection (VBoxContainer)
|           +-- StatRows (VBoxContainer)
+-- BackButton (Button)
+-- CornerHints (Control)
    +-- SeasonIndicator (Label)
    +-- DayCounter (Label)
```

---

## Data Sources

### Calendar Events (from CALENDAR_2026_PRINT.md)

The scene loads events from `res://data/calendar_2026.json`:

```json
{
  "events": [
    {
      "id": "serment_sources",
      "date": "2026-02-02",
      "name_fr": "Serment des Sources",
      "description_fr": "Les sources sacrees murmurent des promesses anciennes.",
      "tags": ["ritual", "source", "aube"],
      "season": "winter",
      "effects": {
        "spawn_mods": {"ritual": 1.2, "mystery": 1.15},
        "hour_bonus": {"05": 1.3, "06": 1.4}
      }
    }
  ]
}
```

### Run Statistics (from DruStore meta)

```gdscript
# Pulled from state.meta
var stats := {
    "total_runs": state.meta.total_runs,
    "total_cards_played": state.meta.total_cards_played,
    "endings_seen": state.meta.endings_seen,
    "gloire_points": state.meta.gloire_points,
}
```

### Current Date

```gdscript
# Real-world date (game uses 1:1 day mapping)
var today := Time.get_date_dict_from_system()
var current_day := today.day
var current_month := today.month
var current_year := today.year
```

---

## Interactions

### Navigation Flow

```
[Main Menu] --[CAL button]--> [Calendar]
                                  |
                         [Back button or ESC]
                                  |
                              [Main Menu]
```

### Tab Switching

| Tab | Content | Default |
|-----|---------|---------|
| Evenements | Scrollable event list for current month | Yes |
| Statistiques | Run history and meta-progression | No |

### Event Row Interaction

- **Tap/Click**: Expand event description
- **No deep navigation**: Calendar is read-only
- **Visual feedback**: Hover highlights row, shows tooltip with effects

### Wheel Interaction (Optional Enhancement)

- **Tap section**: Scroll event list to that season
- **Long press**: Show season description tooltip

---

## Controller Script (Calendar.gd)

### Responsibilities

1. Load calendar data from JSON
2. Determine current date and season
3. Populate event list
4. Draw wheel with current position
5. Load meta stats from DruStore
6. Handle tab switching
7. Handle back navigation

### Key Methods

```gdscript
extends Control

const CALENDAR_DATA_PATH := "res://data/calendar_2026.json"
const SEASONS := ["winter", "spring", "summer", "autumn"]
const CELTIC_FESTIVALS := {
    "samhain": {"month": 10, "day": 31},
    "yule": {"month": 12, "day": 21},
    "imbolc": {"month": 2, "day": 1},
    "ostara": {"month": 3, "day": 21},
    "beltane": {"month": 5, "day": 1},
    "litha": {"month": 6, "day": 21},
    "lughnasadh": {"month": 8, "day": 1},
    "mabon": {"month": 9, "day": 21},
}

var calendar_data: Dictionary = {}
var current_events: Array = []
var meta_stats: Dictionary = {}

func _ready() -> void:
    _load_calendar_data()
    _determine_current_context()
    _populate_wheel()
    _populate_events()
    _populate_stats()
    _setup_tabs()
    _setup_navigation()

func _load_calendar_data() -> void:
    # Load from JSON, validate structure

func _determine_current_context() -> Dictionary:
    # Return {date, season, next_event, days_until_next}

func _get_season_for_date(month: int, day: int) -> String:
    # Map date to Celtic season

func _populate_wheel() -> void:
    # Draw wheel, position current day marker

func _populate_events() -> void:
    # Filter events for current month, sort by date

func _populate_stats() -> void:
    # Load from DruStore or saved meta

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
```

---

## Wheel of the Year Implementation

### Option A: Pre-rendered Sprite

- Create SVG/PNG wheel graphic
- Overlay dynamic elements (current position, highlights)
- Pros: Beautiful, consistent
- Cons: Less flexible

### Option B: Custom Draw (Recommended)

```gdscript
func _draw_wheel(center: Vector2, radius: float) -> void:
    # Draw base circle
    draw_arc(center, radius, 0, TAU, 64, CALENDAR_COLORS.ink_soft, 2.0)

    # Draw season arcs
    var season_angles := [
        {"start": -PI/4, "end": PI/4, "color": CALENDAR_COLORS.winter},
        {"start": PI/4, "end": 3*PI/4, "color": CALENDAR_COLORS.spring},
        {"start": 3*PI/4, "end": 5*PI/4, "color": CALENDAR_COLORS.summer},
        {"start": 5*PI/4, "end": 7*PI/4, "color": CALENDAR_COLORS.autumn},
    ]

    for arc in season_angles:
        draw_arc(center, radius - 10, arc.start, arc.end, 32, arc.color, 8.0)

    # Draw festival markers
    for festival in CELTIC_FESTIVALS:
        var angle := _date_to_angle(festival.month, festival.day)
        var marker_pos := center + Vector2.from_angle(angle) * (radius - 5)
        draw_circle(marker_pos, 4, CALENDAR_COLORS.accent)

    # Draw current day marker
    var today_angle := _date_to_angle(current_month, current_day)
    var today_pos := center + Vector2.from_angle(today_angle) * radius
    draw_circle(today_pos, 8, CALENDAR_COLORS.event_today)
    draw_circle(today_pos, 6, CALENDAR_COLORS.paper)
```

---

## Event List Implementation

### Event Row Structure

```
+------------------------------------------+
| [DATE] [NAME]                     [ICON] |
| [DESCRIPTION - collapsed by default]     |
+------------------------------------------+
```

### State Indicators

| State | Visual |
|-------|--------|
| Past event (attended) | Check mark, muted colors |
| Past event (missed) | X mark, very muted |
| Today | Gold highlight, pulsing border |
| Future (< 7 days) | Normal ink, visible |
| Future (> 7 days) | Soft ink, subtle |

### Filtering Logic

```gdscript
func _filter_events_for_display(events: Array, current_date: Dictionary) -> Array:
    var result := []
    for event in events:
        var event_date := _parse_date(event.date)
        # Show events from 7 days ago to 30 days ahead
        var days_diff := _days_between(current_date, event_date)
        if days_diff >= -7 and days_diff <= 30:
            event["state"] = _determine_event_state(days_diff)
            result.append(event)
    return result
```

---

## Statistics Display

### Available Stats (from DruStore.meta)

| Stat | Source | Display Format |
|------|--------|----------------|
| Runs totaux | meta.total_runs | Number |
| Cartes jouees | meta.total_cards_played | Number |
| Jours survecus | Calculated from runs | Number |
| Fins vues | meta.endings_seen.size() / 8 | "5/8" |
| Gloire | meta.gloire_points | Number |
| Meilleur run | Max cards in single run | Number + ending |
| Promesses tenues | meta.promises_kept | Number |

### Layout

```
+------------------------------------------+
|  STATISTIQUES DE JEU                     |
|------------------------------------------|
|  Runs totaux         |              12   |
|  Cartes jouees       |             847   |
|  Meilleur run        |    156 (Exile)    |
|------------------------------------------|
|  FINS DECOUVERTES                        |
|  [x] L'Epuisement   [x] Le Surmenage     |
|  [x] La Folie       [ ] La Possession    |
|  [x] L'Exile        [ ] La Tyrannie      |
|  [x] La Famine      [ ] Le Pillage       |
|------------------------------------------|
|  Points de Gloire:              1,280    |
+------------------------------------------+
```

---

## Responsive Design

### Desktop (> 800px width)

- Card width: 560px
- Full wheel visible
- Two-column event list
- Stats in grid

### Mobile/Compact (< 560px)

- Card width: 90% viewport
- Smaller wheel (or horizontal arc)
- Single-column event list
- Stats stacked

```gdscript
func _update_responsive_layout() -> void:
    var viewport_width := get_viewport_rect().size.x
    compact_mode = viewport_width < 560

    if compact_mode:
        wheel_container.custom_minimum_size = Vector2(200, 200)
        event_list.columns = 1
    else:
        wheel_container.custom_minimum_size = Vector2(280, 280)
        event_list.columns = 2
```

---

## Animation Specifications

### Entry Animation

```gdscript
func _play_entry_animation() -> void:
    # Card slides up from bottom
    calendar_card.modulate.a = 0
    calendar_card.position.y += 50

    var tween := create_tween()
    tween.tween_property(calendar_card, "modulate:a", 1.0, 0.3)
    tween.parallel().tween_property(calendar_card, "position:y",
        calendar_card.position.y - 50, 0.3).set_ease(Tween.EASE_OUT)
```

### Wheel Reveal

```gdscript
func _animate_wheel() -> void:
    # Current day marker pulses gently
    var pulse := create_tween().set_loops()
    pulse.tween_property(current_day_marker, "scale",
        Vector2(1.1, 1.1), 0.8).set_ease(Tween.EASE_IN_OUT)
    pulse.tween_property(current_day_marker, "scale",
        Vector2(1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
```

### Tab Switch

```gdscript
func _switch_tab(to_tab: int) -> void:
    var old_section := _get_section(current_tab)
    var new_section := _get_section(to_tab)

    # Crossfade
    var tween := create_tween()
    tween.tween_property(old_section, "modulate:a", 0.0, 0.15)
    tween.tween_callback(func():
        old_section.visible = false
        new_section.visible = true
        new_section.modulate.a = 0
    )
    tween.tween_property(new_section, "modulate:a", 1.0, 0.15)

    current_tab = to_tab
```

---

## Audio Integration

### Ambient

- Soft ambient layer when calendar opens
- Season-appropriate (birds in spring, wind in winter)

### Feedback

- Soft "paper" sound on tab switch
- Subtle tick on wheel hover
- No voice/Merlin (this is a quiet meta screen)

---

## Balance Considerations

### Pros
- Adds depth to the calendar system
- Encourages daily engagement
- Provides clear meta-progression feedback
- Reinforces Celtic theme authentically

### Cons
- May overwhelm new players with data
- Calendar events are for bonuses only (risk of FOMO)
- Statistics could feel discouraging if runs are short

### Mitigations
1. **Progressive reveal**: Hide stats tab until first run complete
2. **Positive framing**: Focus on achievements, not failures
3. **Calendar as invitation**: "Upcoming events" not "missed events"
4. **Merlin flavor**: Brief quotes add warmth without pressure

---

## Testing Recommendations

### Functional Tests

1. Calendar loads without JSON file (graceful fallback)
2. Current date marker positions correctly year-round
3. Tab switching preserves scroll position
4. Back button returns to menu correctly
5. Stats load from empty DruStore without crash

### Visual Tests

1. Wheel renders at all screen sizes
2. Event list scrolls smoothly with 30+ items
3. Colors match Reigns theme
4. Fonts load correctly (fallback works)

### User Experience Tests

1. New player understands what calendar shows
2. Player can find "next event" within 3 seconds
3. Stats feel motivating, not discouraging
4. Screen feels cohesive with main menu aesthetic

---

## Open Questions

1. **Should the calendar show events from past months?**
   - Recommendation: No, focus on present and near future

2. **Should players be able to set reminders for events?**
   - Recommendation: Not in v1, consider for future

3. **Should Merlin speak when calendar opens?**
   - Recommendation: No, keep it as a quiet information screen

4. **Should event effects be visible or hidden?**
   - Recommendation: Show spawn bonuses, hide precise numbers

5. **Should the wheel be interactive?**
   - Recommendation: Optional enhancement, not required for v1

---

## Implementation Priority

### Phase 1 (MVP)
- Basic card layout with title
- Current date display
- Event list for current month
- Back navigation

### Phase 2 (Core)
- Wheel of the year visualization
- Season coloring
- Tab system (Events/Stats)
- Stats from DruStore

### Phase 3 (Polish)
- Animations
- Responsive layout
- Event state indicators
- Audio integration

---

## File Deliverables

| File | Purpose |
|------|---------|
| `scenes/Calendar.tscn` | Scene tree |
| `scripts/Calendar.gd` | Controller logic |
| `data/calendar_2026.json` | Event data (if not exists) |
| `resources/ui/wheel_of_year.svg` | Optional: pre-rendered wheel |

---

*Document version: 1.0*
*Last updated: 2026-02-06*
