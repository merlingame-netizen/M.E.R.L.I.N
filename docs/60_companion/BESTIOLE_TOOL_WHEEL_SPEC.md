# Bestiole Tool Wheel — UI Architecture & Implementation Spec

> **Agent**: UI Implementation Specialist
> **Date**: 2026-02-08
> **Version**: 1.0
> **Depends on**: DOC_12_Triade_Gameplay_System, BESTIOLE_SYSTEM, merlin_constants.gd

---

## 1. ANALYSE DE L'UI EXISTANTE

### 1.1 Systeme Triade (actif) — `triade_game_ui.gd`

Le layout actuel du gameplay Triade est construit entierement en code (pas de scene `.tscn` pour l'UI Triade):

```
VBoxContainer (PRESET_FULL_RECT)
  +-- HBoxContainer (top_bar)
  |     +-- HBoxContainer (aspect_panel) : 3x [VBox: icon + name + state_circles + state_name]
  |     +-- VBoxContainer (souffle_panel) : title + 7x circles
  +-- Control (spacer)
  +-- CenterContainer (card_container) : Panel + RichTextLabel
  +-- Control (spacer)
  +-- HBoxContainer (options_container) : 3x [VBox: label + button + cost]
  +-- HBoxContainer (info_panel) : mission_label + cards_label
```

**Observations cles:**
- Le signal `skill_activated(skill_id: String)` existe deja dans `TriadeGameUI` mais rien ne l'emet actuellement
- Le controller `TriadeGameController` a deja `_use_skill(skill_id)` qui dispatche `TRIADE_USE_SKILL`
- Il n'y a AUCUN element Bestiole dans l'UI Triade (contrairement a l'UI Reigns)
- Tout est cree dynamiquement en `_ready()`, pas de noeuds scene

### 1.2 Systeme Reigns (legacy) — `reigns_game_ui.gd` + `ReignsGame.tscn`

L'ancien layout contenait un BestiolePanel en bas d'ecran:

```
BestiolePanel (anchors: bottom, full width, 100px height)
  +-- BondLabel ("Lien: 50%")
  +-- MoodLabel (":|")
  +-- SkillContainer (HBoxContainer) : skill buttons in a row
```

**Problemes de l'ancienne approche:**
- Skills affiches en liste horizontale plate (pas intuitif pour 18 Oghams)
- Pas de categorisation visuelle
- Pas de feedback verrouille/deverrouille
- Pas adapte au tactile (boutons trop petits)
- Occupe de l'espace ecran permanent

### 1.3 Theme visuel — `merlin_theme.tres`

**Palette parchemin coherente:**
- Paper: `Color(0.96, 0.92, 0.84)` (fond principal)
- Ink: `Color(0.12, 0.10, 0.08)` (texte)
- Accent: `Color(0.46, 0.18, 0.16)` (highlight, progress bar fill)
- Hover: `Color(0.93, 0.88, 0.80)` avec border accent
- Font: MorrisRomanBlackAlt (police medievale)
- Corners: 6px radius, border 2px, shadow 8px

### 1.4 Integration existante avec le Store

Le `MerlinStore` gere deja:
- `state.bestiole.bond` (0-100) avec tiers: distant/friendly/close/bonded/soulmate
- `state.bestiole.skills_equipped` (Array de skill_id)
- `state.bestiole.skill_cooldowns` (Dictionary {skill_id: tours_restants})
- Action `TRIADE_USE_SKILL` avec `skill_id` + `card` context
- 18 Oghams definis dans `MerlinConstants.OGHAM_SKILLS` avec 6 categories

---

## 2. RECHERCHE DE PATTERNS — RADIAL MENU

### 2.1 Pourquoi un radial menu (et pas une liste)

| Critere | Liste lineaire | Radial menu |
|---------|---------------|-------------|
| Loi de Fitts | Distance variable | Distance egale a chaque item |
| Memoire musculaire | Faible | Forte (direction = skill) |
| Touch mobile | Moyen | Excellent (geste naturel) |
| Categorisation | Sections + scroll | Arcs colores = categories |
| Espace ecran | Permanent | Overlay temporaire |
| 18 items | Scroll obligatoire | 2 anneaux concentriques |
| Apprentissage | Rapide | Moyen (plus intuitif ensuite) |

**Decision**: 18 Oghams = trop pour un seul anneau (max recommande: 12). Solution: **double anneau concentrique** ou **anneau a 6 sections avec 3 items par section**.

### 2.2 Patterns Godot 4 disponibles

1. **RadialMenu Control Node** (asset library #3469) — Plugin avec sous-menus, gamepad, themes
2. **kidscancode recipe** — Implementation simple: TextureButton + Buttons container + Tween
3. **Custom draw** — `_draw()` avec arcs, selection par angle `atan2()`

**Recommandation**: Implementation custom (option 3) car:
- Meilleur controle du style celtique/parchemin
- Pas de dependance externe
- Integration native avec le signal `skill_activated`
- Gestion fine du verrouillage/cooldown

### 2.3 Recherche UX tactile

Bonnes pratiques pour les roues tactiles:
- Le menu apparait SOUS le doigt qui a touche (context-aware origin)
- Chaque secteur doit faire au moins 48x48px de zone de touche
- La selection se fait par DIRECTION + relachement (drag-and-release)
- Un delai de 200ms avant apparition previent les activations accidentelles
- Le retour haptique confirme la selection
- Un texte/tooltip s'affiche PENDANT le drag pour confirmer le choix

---

## 3. ARCHITECTURE UI PROPOSEE

### 3.1 Positionnement de l'icone Bestiole

```
+--------------------------------------------------+
| [Aspects]    [Souffle]                            |
|  Sanglier     Corbeau     Cerf                    |
|                                                   |
|                                                   |
|               +----------+                        |
|               |          |                        |
|               |  CARTE   |                        |
|               |          |                        |
|               +----------+                        |
|                                                   |
|   [A]         [B]         [C]                     |
|                                                   |
| [Mission]  [Cartes]          [BESTIOLE ICON]  <<< |
+--------------------------------------------------+
```

**Position**: Coin inferieur droit, au-dessus de la barre d'info.
- Raison: non-intrusif, accessible pouce droit (mobile portrait), ne chevauche pas les options A/B/C.
- Taille: 56x56px minimum (touch target >= 48px).
- Visible en permanence mais discret.
- Inclut un indicateur d'humeur (couleur du contour).

### 3.2 Layout de la roue (18 slots, 6 categories)

Architecture: **6 secteurs de 60 degres chacun, 3 items par secteur**

```
            REVEAL (3)
         ___/    \___
        /              \
   SPECIAL (3)      PROTECTION (3)
       |                |
       |   [BESTIOLE]   |
       |    (centre)    |
   RECOVERY (3)     BOOST (3)
        \              /
         \___    ___/
           NARRATIVE (3)
```

Chaque secteur = 60 degres. Chaque item dans un secteur = 20 degres.
Les 3 items sont disposes sur un arc a l'interieur du secteur.

**Disposition detaillee (sens horaire, 0 = haut):**

| Secteur | Angle | Couleur | Items |
|---------|-------|---------|-------|
| REVEAL | 330-30 | Bleu ciel `#4BB4E6` | beith, coll, ailm |
| PROTECTION | 30-90 | Vert `#50BE87` | luis, gort, eadhadh |
| BOOST | 90-150 | Or `#FFD200` | duir, tinne, onn |
| NARRATIVE | 150-210 | Violet `#A885D8` | nuin, huath, straif |
| RECOVERY | 210-270 | Rose `#FFB4E6` | quert, ruis, saille |
| SPECIAL | 270-330 | Rouge accent `#BB4A40` | muin, ioho, ur |

### 3.3 Etats visuels des Oghams

| Etat | Apparence | Interaction |
|------|-----------|-------------|
| **Verrouille** | Icone grisee + cadenas, opacity 0.3 | Tooltip "Lien insuffisant" |
| **Disponible** | Icone pleine, couleur categorie | Tap/click = activer |
| **En cooldown** | Icone assombrie + compteur tours | Tooltip "Disponible dans X tours" |
| **Starter** (beith, luis, quert) | Contour dore | Toujours disponible si bond > 0 |
| **Actif** (vient d'etre utilise) | Flash lumineux + particules | Feedback visuel 0.5s |

### 3.4 Animations

**Ouverture de la roue:**
1. Long-press (250ms) ou tap sur l'icone Bestiole
2. Le jeu se met en **pause visuelle** (fond assombri, carte figee, alpha 0.5)
3. La roue s'expande depuis l'icone Bestiole avec `TRANS_BACK, EASE_OUT` en 0.3s
4. Les items apparaissent en cascade (decalage 20ms par item) depuis le centre
5. Le texte Bestiole + humeur apparait au centre de la roue

**Pendant la selection:**
- Hover/drag sur un secteur = le secteur s'illumine + tooltip apparait
- Le tooltip montre: nom Ogham + nom arbre + effet + cooldown restant
- SFX subtil de hover ("tick" leger)

**Fermeture:**
- Tap sur un Ogham disponible = activation + fermeture automatique
- Tap a l'exterieur = fermeture sans action
- Touche Escape = fermeture
- Animation inverse (retraction vers icone, 0.2s)

**Feedback d'activation:**
- Flash blanc 0.1s sur l'icone activee
- Particules celtiques (spirales) qui se diffusent
- Texte "+[NomOgham]!" flottant brievement
- SFX magique court
- Le jeu reprend immediatement

---

## 4. PLAN D'IMPLEMENTATION TECHNIQUE

### 4.1 Node Tree recommande

```
BestioleWheelSystem (Control) .............. bestiole_wheel_system.gd
  +-- BestioleButton (TextureButton) ....... Icone cliquable en permanence
  |     +-- MoodIndicator (ColorRect) ...... Contour colore selon humeur
  |     +-- CooldownOverlay (Label) ........ "2" si skills en cooldown
  +-- WheelOverlay (CanvasLayer) ........... Couche au-dessus du jeu
       +-- DimBackground (ColorRect) ....... Fond semi-transparent noir
       +-- WheelContainer (Control) ........ Container centre sur Bestiole
            +-- CenterCircle (Panel) ....... Cercle central (portrait Bestiole)
            |     +-- BestiolePortrait (TextureRect)
            |     +-- BondLabel (Label) .... "Lien: 72%"
            |     +-- MoodLabel (Label) .... Humeur textuelle
            +-- SectorContainer (Control) .. Container des 6 secteurs
            |     +-- Sector_Reveal (Control)
            |     |     +-- OghamSlot_beith (Control)
            |     |     +-- OghamSlot_coll (Control)
            |     |     +-- OghamSlot_ailm (Control)
            |     +-- Sector_Protection (Control)
            |     |     +-- OghamSlot_luis (Control)
            |     |     +-- OghamSlot_gort (Control)
            |     |     +-- OghamSlot_eadhadh (Control)
            |     +-- ... (4 autres secteurs)
            +-- TooltipPanel (PanelContainer)
                  +-- TooltipName (Label)
                  +-- TooltipTree (Label)
                  +-- TooltipEffect (RichTextLabel)
                  +-- TooltipCooldown (Label)
```

### 4.2 Code indicatif — `bestiole_wheel_system.gd`

```gdscript
## =============================================================================
## Bestiole Wheel System — Radial Ogham Selector
## =============================================================================
## A radial menu for selecting Bestiole skills (Oghams).
## 18 skills organized in 6 categories, displayed as pie sectors.
## =============================================================================

extends Control
class_name BestioleWheelSystem

signal ogham_selected(skill_id: String)
signal wheel_opened
signal wheel_closed

# =============================================================================
# CONFIGURATION
# =============================================================================

const WHEEL_RADIUS := 160.0
const INNER_RADIUS := 60.0
const CENTER_RADIUS := 50.0
const SECTOR_COUNT := 6
const ITEMS_PER_SECTOR := 3
const OPEN_DURATION := 0.3
const CLOSE_DURATION := 0.2
const LONG_PRESS_DELAY := 0.25  # seconds before wheel opens
const MIN_TOUCH_TARGET := 48.0  # px, accessibility minimum

const CATEGORY_ORDER := ["reveal", "protection", "boost", "narrative", "recovery", "special"]
const CATEGORY_COLORS := {
	"reveal": Color(0.294, 0.706, 0.902),      # Bleu ciel
	"protection": Color(0.314, 0.745, 0.529),   # Vert
	"boost": Color(1.0, 0.824, 0.0),            # Or
	"narrative": Color(0.659, 0.529, 0.847),     # Violet
	"recovery": Color(1.0, 0.706, 0.902),        # Rose
	"special": Color(0.733, 0.290, 0.251),       # Rouge accent
}

const CATEGORY_LABELS := {
	"reveal": "Revelation",
	"protection": "Protection",
	"boost": "Force",
	"narrative": "Recit",
	"recovery": "Guerison",
	"special": "Secret",
}

# =============================================================================
# STATE
# =============================================================================

var is_open := false
var is_opening := false
var selected_sector := -1
var selected_item := -1
var hovered_skill_id := ""

# Data from store
var unlocked_skills: Array = []
var cooldowns: Dictionary = {}
var bond_level: int = 50
var bestiole_mood: String = "neutral"

# Press detection
var _press_timer := 0.0
var _is_pressing := false

# =============================================================================
# REFERENCES (set in _ready)
# =============================================================================

var wheel_overlay: CanvasLayer
var dim_background: ColorRect
var wheel_container: Control
var tooltip_panel: PanelContainer
var bestiole_button: TextureButton

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_setup_bestiole_button()
	_setup_wheel_overlay()
	set_process(false)  # Only process when pressing


func _setup_bestiole_button() -> void:
	"""Create the always-visible Bestiole icon button."""
	bestiole_button = TextureButton.new()
	bestiole_button.name = "BestioleButton"
	bestiole_button.custom_minimum_size = Vector2(56, 56)

	# Position: bottom-right corner with margin
	bestiole_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bestiole_button.offset_left = -72
	bestiole_button.offset_top = -72
	bestiole_button.offset_right = -16
	bestiole_button.offset_bottom = -16

	# Fallback: draw a circle if no texture
	var placeholder := _create_bestiole_placeholder()
	bestiole_button.add_child(placeholder)

	bestiole_button.button_down.connect(_on_bestiole_press_start)
	bestiole_button.button_up.connect(_on_bestiole_press_end)
	add_child(bestiole_button)


func _setup_wheel_overlay() -> void:
	"""Create the wheel overlay (hidden by default)."""
	wheel_overlay = CanvasLayer.new()
	wheel_overlay.name = "WheelOverlay"
	wheel_overlay.layer = 10  # Above game UI
	wheel_overlay.visible = false
	add_child(wheel_overlay)

	# Dim background
	dim_background = ColorRect.new()
	dim_background.name = "DimBackground"
	dim_background.color = Color(0.0, 0.0, 0.0, 0.6)
	dim_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_background.gui_input.connect(_on_background_input)
	wheel_overlay.add_child(dim_background)

	# Wheel container (will be positioned at Bestiole icon)
	wheel_container = Control.new()
	wheel_container.name = "WheelContainer"
	wheel_overlay.add_child(wheel_container)

	# Tooltip
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "TooltipPanel"
	tooltip_panel.visible = false
	tooltip_panel.custom_minimum_size = Vector2(200, 80)
	wheel_overlay.add_child(tooltip_panel)


func _create_bestiole_placeholder() -> Control:
	"""Fallback visual for Bestiole button."""
	var circle := ColorRect.new()
	circle.color = Color(0.3, 0.6, 0.4, 0.8)
	circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ideally a TextureRect with Bestiole sprite
	var label := Label.new()
	label.text = "B"
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	circle.add_child(label)
	return circle


# =============================================================================
# INPUT — PRESS DETECTION
# =============================================================================

func _process(delta: float) -> void:
	if _is_pressing:
		_press_timer += delta
		if _press_timer >= LONG_PRESS_DELAY and not is_open:
			_open_wheel()
			_is_pressing = false


func _on_bestiole_press_start() -> void:
	_is_pressing = true
	_press_timer = 0.0
	set_process(true)


func _on_bestiole_press_end() -> void:
	if _is_pressing and _press_timer < LONG_PRESS_DELAY:
		# Short tap: toggle wheel
		if is_open:
			_close_wheel()
		else:
			_open_wheel()
	_is_pressing = false
	set_process(false)


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_wheel()
	elif event is InputEventScreenTouch and event.pressed:
		_close_wheel()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		_close_wheel()
		get_viewport().set_input_as_handled()


# =============================================================================
# WHEEL OPEN / CLOSE
# =============================================================================

func _open_wheel() -> void:
	if is_open or is_opening:
		return

	is_opening = true
	is_open = true

	# Position wheel at Bestiole button center
	var btn_center := bestiole_button.global_position + bestiole_button.size / 2.0
	wheel_container.global_position = btn_center

	# Build/refresh wheel items
	_build_wheel_items()

	# Show overlay
	wheel_overlay.visible = true
	dim_background.modulate.a = 0.0

	# Animate open
	var tween := create_tween().set_parallel()
	tween.tween_property(dim_background, "modulate:a", 1.0, OPEN_DURATION)

	# Animate each slot from center
	var slot_index := 0
	for child in wheel_container.get_children():
		if child is Control:
			var target_pos: Vector2 = child.get_meta("target_pos", Vector2.ZERO)
			child.position = Vector2.ZERO
			child.scale = Vector2(0.3, 0.3)
			child.modulate.a = 0.0
			tween.tween_property(child, "position", target_pos, OPEN_DURATION) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.set_delay(slot_index * 0.02)
			tween.tween_property(child, "scale", Vector2.ONE, OPEN_DURATION) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
				.set_delay(slot_index * 0.02)
			tween.tween_property(child, "modulate:a", 1.0, OPEN_DURATION * 0.5) \
				.set_delay(slot_index * 0.02)
			slot_index += 1

	tween.finished.connect(func(): is_opening = false)
	wheel_opened.emit()


func _close_wheel() -> void:
	if not is_open:
		return

	is_open = false
	tooltip_panel.visible = false

	var tween := create_tween().set_parallel()
	tween.tween_property(dim_background, "modulate:a", 0.0, CLOSE_DURATION)

	for child in wheel_container.get_children():
		if child is Control:
			tween.tween_property(child, "position", Vector2.ZERO, CLOSE_DURATION) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(child, "scale", Vector2(0.3, 0.3), CLOSE_DURATION)
			tween.tween_property(child, "modulate:a", 0.0, CLOSE_DURATION * 0.5)

	tween.finished.connect(func():
		wheel_overlay.visible = false
		_clear_wheel_items()
	)
	wheel_closed.emit()


# =============================================================================
# WHEEL CONSTRUCTION
# =============================================================================

func _build_wheel_items() -> void:
	"""Build wheel slots based on current skill data."""
	_clear_wheel_items()

	var angle_per_sector := TAU / float(SECTOR_COUNT)
	var angle_per_item := angle_per_sector / float(ITEMS_PER_SECTOR)
	var start_angle := -PI / 2.0  # Start from top (12 o'clock)

	for sector_idx in range(SECTOR_COUNT):
		var category: String = CATEGORY_ORDER[sector_idx]
		var category_color: Color = CATEGORY_COLORS.get(category, Color.WHITE)
		var sector_angle_start := start_angle + sector_idx * angle_per_sector

		# Get skills in this category
		var category_skills: Array = _get_skills_for_category(category)

		for item_idx in range(mini(category_skills.size(), ITEMS_PER_SECTOR)):
			var skill_id: String = category_skills[item_idx]
			var skill_data: Dictionary = MerlinConstants.OGHAM_SKILLS.get(skill_id, {})
			var item_angle := sector_angle_start + (item_idx + 0.5) * angle_per_item

			# Calculate position on the ring
			var pos := Vector2(WHEEL_RADIUS, 0).rotated(item_angle)

			# Create slot
			var slot := _create_ogham_slot(skill_id, skill_data, category_color)
			slot.set_meta("target_pos", pos)
			slot.set_meta("skill_id", skill_id)
			slot.position = pos  # Will be overridden by animation
			wheel_container.add_child(slot)


func _create_ogham_slot(skill_id: String, skill_data: Dictionary, cat_color: Color) -> Control:
	"""Create a single Ogham slot in the wheel."""
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(50, 50)
	slot.pivot_offset = Vector2(25, 25)

	# Determine state
	var is_locked := not unlocked_skills.has(skill_id)
	var cooldown_remaining: int = int(cooldowns.get(skill_id, 0))
	var is_on_cooldown := cooldown_remaining > 0
	var is_starter := MerlinConstants.OGHAM_STARTER_SKILLS.has(skill_id)

	# Visual styling
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 25
	style.corner_radius_top_right = 25
	style.corner_radius_bottom_left = 25
	style.corner_radius_bottom_right = 25
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	if is_locked:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		slot.text = "?"
		slot.disabled = true
		slot.modulate.a = 0.3
	elif is_on_cooldown:
		style.bg_color = cat_color.darkened(0.5)
		style.border_color = cat_color.darkened(0.3)
		slot.text = str(cooldown_remaining)
		slot.disabled = true
		slot.modulate.a = 0.5
	else:
		style.bg_color = cat_color.darkened(0.2)
		style.border_color = cat_color
		# First letter of tree name as icon
		var tree_name: String = skill_data.get("name", skill_id)
		slot.text = tree_name.substr(0, 2)
		slot.disabled = false

		if is_starter:
			style.border_color = Color(0.9, 0.8, 0.3)  # Gold border for starters
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3

	slot.add_theme_stylebox_override("normal", style)
	slot.add_theme_stylebox_override("hover", style.duplicate())
	slot.add_theme_stylebox_override("pressed", style.duplicate())
	slot.add_theme_stylebox_override("disabled", style.duplicate())
	slot.add_theme_font_size_override("font_size", 14)

	# Signals
	if not is_locked and not is_on_cooldown:
		slot.pressed.connect(_on_ogham_pressed.bind(skill_id))
	slot.mouse_entered.connect(_on_ogham_hover.bind(skill_id, skill_data))
	slot.mouse_exited.connect(_on_ogham_hover_exit)

	return slot


func _clear_wheel_items() -> void:
	for child in wheel_container.get_children():
		child.queue_free()


func _get_skills_for_category(category: String) -> Array:
	"""Return skill IDs for a given category, in order."""
	var result: Array = []
	for skill_id in MerlinConstants.OGHAM_SKILLS:
		var data: Dictionary = MerlinConstants.OGHAM_SKILLS[skill_id]
		if data.get("category", "") == category:
			result.append(skill_id)
	return result


# =============================================================================
# INTERACTION
# =============================================================================

func _on_ogham_pressed(skill_id: String) -> void:
	"""Ogham selected — emit signal and close wheel."""
	ogham_selected.emit(skill_id)
	_play_activation_feedback(skill_id)
	_close_wheel()


func _on_ogham_hover(skill_id: String, skill_data: Dictionary) -> void:
	"""Show tooltip for hovered Ogham."""
	hovered_skill_id = skill_id

	if not tooltip_panel:
		return

	# Clear and rebuild tooltip content
	for child in tooltip_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Name + tree
	var name_label := Label.new()
	name_label.text = "%s (%s)" % [skill_data.get("name", "?"), skill_id]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	vbox.add_child(name_label)

	# Category
	var cat_label := Label.new()
	var category: String = skill_data.get("category", "?")
	cat_label.text = CATEGORY_LABELS.get(category, category)
	cat_label.add_theme_font_size_override("font_size", 12)
	cat_label.add_theme_color_override("font_color", CATEGORY_COLORS.get(category, Color.GRAY))
	vbox.add_child(cat_label)

	# Effect
	var effect_label := Label.new()
	effect_label.text = _get_effect_description(skill_data.get("effect", ""))
	effect_label.add_theme_font_size_override("font_size", 13)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(effect_label)

	# Cooldown
	var cd_remaining: int = int(cooldowns.get(skill_id, 0))
	var cd_max: int = int(skill_data.get("cooldown", 0))
	var cd_label := Label.new()
	if cd_remaining > 0:
		cd_label.text = "Recharge: %d/%d tours" % [cd_remaining, cd_max]
		cd_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.2))
	else:
		cd_label.text = "Pret! (Recharge: %d tours)" % cd_max
		cd_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	cd_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(cd_label)

	tooltip_panel.add_child(vbox)
	tooltip_panel.visible = true

	# Position tooltip near center of screen (avoid edges)
	var viewport_size := get_viewport_rect().size
	tooltip_panel.position = Vector2(
		viewport_size.x / 2.0 - 100,
		viewport_size.y / 2.0 - 120
	)


func _on_ogham_hover_exit() -> void:
	hovered_skill_id = ""
	if tooltip_panel:
		tooltip_panel.visible = false


func _get_effect_description(effect: String) -> String:
	"""Human-readable effect descriptions."""
	match effect:
		"reveal_one": return "Revele l'effet d'une option"
		"reveal_all": return "Revele tous les effets"
		"predict_next": return "Predit la prochaine carte"
		"reduce_30": return "Reduit un effet negatif de 30%"
		"absorb_one": return "Absorbe un effet negatif"
		"skip_negative": return "Ignore tous les effets negatifs ce tour"
		"boost_50": return "Amplifie un effet positif de 50%"
		"double_gain": return "Double les gains ce tour"
		"boost_20_3turns": return "+20% gains pendant 3 tours"
		"add_option": return "Ajoute une 4eme option a la carte"
		"change_card": return "Change la carte actuelle"
		"force_rare": return "Force l'apparition d'un evenement rare"
		"heal_lowest_15": return "Reequilibre l'aspect le plus faible"
		"balance_gauges": return "Equilibre tous les aspects"
		"regen_5_3turns": return "Regeneration douce pendant 3 tours"
		"invert_effects": return "Inverse les effets de la carte"
		"full_reroll": return "Relance completement la carte"
		"sacrifice_trade": return "Sacrifie un aspect pour en renforcer un autre"
		_: return effect


func _play_activation_feedback(_skill_id: String) -> void:
	"""Visual + audio feedback when an Ogham is activated."""
	# Flash on Bestiole button
	if bestiole_button:
		var tween := create_tween()
		tween.tween_property(bestiole_button, "modulate", Color(2.0, 2.0, 2.0), 0.1)
		tween.tween_property(bestiole_button, "modulate", Color.WHITE, 0.3)

	# Floating text could be added here
	# SFX could be played here


# =============================================================================
# PUBLIC API — Called by Controller
# =============================================================================

func update_skills(equipped: Array, skill_cooldowns: Dictionary) -> void:
	"""Update available skills and cooldowns from the store."""
	unlocked_skills = equipped.duplicate()
	cooldowns = skill_cooldowns.duplicate()

	# If wheel is open, rebuild
	if is_open:
		_build_wheel_items()


func update_bestiole_status(bond: int, mood: String) -> void:
	"""Update Bestiole info displayed in the wheel center."""
	bond_level = bond
	bestiole_mood = mood

	# Update button mood indicator
	_update_mood_indicator()


func _update_mood_indicator() -> void:
	"""Update the color indicator on the Bestiole button."""
	if not bestiole_button:
		return

	var mood_color: Color
	match bestiole_mood:
		"happy": mood_color = Color(0.3, 0.9, 0.4)
		"content": mood_color = Color(0.7, 0.7, 0.7)
		"tired": mood_color = Color(0.9, 0.7, 0.2)
		"distressed": mood_color = Color(0.9, 0.3, 0.3)
		_: mood_color = Color(0.7, 0.7, 0.7)

	# Apply tint to button border/modulate
	bestiole_button.self_modulate = mood_color.lightened(0.3)
```

### 4.3 Integration avec le Controller

Modification requise dans `triade_game_controller.gd`:

```gdscript
# In _ready():
var bestiole_wheel := BestioleWheelSystem.new()
bestiole_wheel.name = "BestioleWheel"
ui.add_child(bestiole_wheel)  # Add as child of the game UI

# Connect wheel signal to skill handler
bestiole_wheel.ogham_selected.connect(_on_skill_activated)

# Connect wheel state management
bestiole_wheel.wheel_opened.connect(func(): get_tree().paused = true)
bestiole_wheel.wheel_closed.connect(func(): get_tree().paused = false)

# In _sync_bestiole_ui():
var equipped: Array = bestiole.get("skills_equipped", [])
var skill_cooldowns: Dictionary = bestiole.get("skill_cooldowns", {})
bestiole_wheel.update_skills(equipped, skill_cooldowns)

var bond: int = int(bestiole.get("bond", 50))
var mood: String = _compute_mood(bestiole)
bestiole_wheel.update_bestiole_status(bond, mood)
```

### 4.4 Responsive — Mobile vs Desktop

| Aspect | Mobile (portrait) | Desktop (landscape) |
|--------|-------------------|---------------------|
| Bestiole icon position | Bottom-right, 56x56px | Bottom-right, 48x48px |
| Wheel radius | 140px (smaller screen) | 180px (more space) |
| Slot size | 54x54px (touch-friendly) | 44x44px |
| Tooltip | Above wheel, centered | Near hovered item |
| Selection | Drag-and-release | Click |
| Opening | Long-press 250ms OR tap | Click |
| Closing | Tap outside | Click outside / Escape |
| Pause mode | Process mode ALWAYS | Process mode ALWAYS |

Implementation du responsive:

```gdscript
func _get_responsive_config() -> Dictionary:
    var viewport_size := get_viewport_rect().size
    var is_mobile := viewport_size.x < 800 or viewport_size.y > viewport_size.x

    if is_mobile:
        return {
            "radius": 140.0,
            "slot_size": Vector2(54, 54),
            "font_size": 12,
            "button_size": Vector2(56, 56),
        }
    else:
        return {
            "radius": 180.0,
            "slot_size": Vector2(44, 44),
            "font_size": 14,
            "button_size": Vector2(48, 48),
        }
```

### 4.5 Gestion du pause pendant la roue

**Recommandation: Pause VISUELLE uniquement, pas `get_tree().paused`.**

Raison: `get_tree().paused = true` bloque aussi les tweens et l'input sur le CanvasLayer. Mieux vaut:

1. Mettre la roue sur un `CanvasLayer` avec `layer = 10`
2. Assombrir le fond (ColorRect alpha 0.6)
3. Desactiver les boutons d'option A/B/C pendant que la roue est ouverte
4. Le controller ignore les inputs de carte tant que `is_wheel_open` est vrai

```gdscript
# In controller:
var _is_wheel_open := false

func _on_option_chosen(option: int) -> void:
    if _is_wheel_open:
        return  # Ignore card inputs while wheel is open
    _resolve_choice(option)
```

---

## 5. PLAN D'IMPLEMENTATION EN PHASES

### Phase 1: Infrastructure (1 jour)
- [ ] Creer `scripts/ui/bestiole_wheel_system.gd`
- [ ] Creer l'icone Bestiole visible en permanence
- [ ] Integrer dans `triade_game_controller.gd`
- [ ] Tester: icone visible, tap detecte

### Phase 2: Roue basique (2 jours)
- [ ] Implementer l'overlay + dim background
- [ ] Creer les 18 slots positionnes en cercle
- [ ] Animation ouverture/fermeture
- [ ] Selection par tap
- [ ] Signal `ogham_selected` fonctionnel

### Phase 3: Etats et categories (1 jour)
- [ ] Couleurs par categorie
- [ ] Etat verrouille (grise, opacity 0.3)
- [ ] Etat cooldown (compteur affiche)
- [ ] Starters avec bordure doree
- [ ] Connexion aux donnees du store

### Phase 4: Tooltips et feedback (1 jour)
- [ ] Tooltip au hover/long-press
- [ ] Description d'effet en francais
- [ ] Flash d'activation
- [ ] SFX integration
- [ ] Texte flottant "+[Ogham]!"

### Phase 5: Polish et responsive (1 jour)
- [ ] Adaptation taille selon viewport
- [ ] Test tactile (touch events)
- [ ] Test clavier (navigation par fleches?)
- [ ] Ornements celtiques (optionnel)
- [ ] Integration theme parchemin

**Effort total estime: 6 jours de developpement**

---

## 6. ALTERNATIVES CONSIDEREES ET REJETEES

### 6.1 Liste horizontale scrollable (style Reigns actuel)
- Rejete car: 18 items = trop de scroll, pas de categorisation visuelle, prend de l'espace permanent

### 6.2 Grille 6x3
- Rejete car: pas de lien spatial intuitif entre categories, moins engageant visuellement, occupe beaucoup d'espace

### 6.3 Sous-menus par categorie (tap categorie -> liste)
- Rejete car: 2 niveaux de navigation = trop lent pendant le gameplay, friction

### 6.4 Anneau unique de 18 items
- Rejete car: 18 items dans un anneau = secteurs trop petits (20 degres chacun, ~18px d'arc a 160px de rayon), en dessous du minimum tactile

### 6.5 Plugin RadialMenu (asset library)
- Rejete car: dependance externe, style graphique non-celtique, moins de controle sur l'integration

---

## 7. QUESTIONS OUVERTES

1. **Faut-il un drag-and-release ou un tap?** Le tap est plus simple a implementer, le drag plus rapide pour les experts. Recommandation: supporter les deux.

2. **Navigation clavier/gamepad?** Le design actuel est optimise touch/souris. Pour gamepad, ajouter une navigation circulaire avec les sticks pourrait etre un phase 2.

3. **Bestiole portrait au centre?** Si on a un sprite Bestiole, l'afficher au centre de la roue serait tres immersif. Sinon, utiliser une icone stylisee celtique.

4. **Animation de repos de Bestiole?** L'icone pourrait avoir une animation idle subtile (respiration, yeux qui clignent) pour donner vie au compagnon.

5. **Notification de skill disponible?** Un petit badge/point sur l'icone Bestiole quand un Ogham sort de cooldown attirerait l'attention sans etre intrusif.

---

## SOURCES

- [Radial Menu Control Node for Godot 4](https://github.com/jesuisse/godot-radial-menu-control)
- [Radial Popup Menu - Godot 4 Recipes (kidscancode)](https://kidscancode.org/godot_recipes/4.x/ui/radial_menu/index.html)
- [Touch Means a New Chance for Radial Menus (Big Medium)](https://bigmedium.com/ideas/radial-menus-for-touch-ui.html)
- [The Usability of Radial Menus (Pushing Pixels)](https://www.pushing-pixels.org/2012/07/25/the-usability-of-radial-menus.html)
- [Gesture-based Radial Menus (Luis Abreu)](https://lmjabreu.com/post/gesture-based-radial-menus/)
- [Pie Menu - Wikipedia](https://en.wikipedia.org/wiki/Pie_menu)
