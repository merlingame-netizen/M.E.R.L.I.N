## ═══════════════════════════════════════════════════════════════════════════════
## HUD Controller — 3D walk HUD + card overlay HUD (Phase 7, DEV_PLAN_V2.5)
## ═══════════════════════════════════════════════════════════════════════════════
## Subscribes to Run3DController signals and updates UI elements.
## Two modes: 3D walk (minimal HUD) and card overlay (text + 3 options).
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name HudController

signal option_selected(option_index: int)
signal ogham_activated(ogham_id: String)

# ═══════════════════════════════════════════════════════════════════════════════
# UI STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _life: int = 100
var _life_max: int = 100
var _currency: int = 0
var _current_ogham: String = "beith"
var _ogham_cooldown: int = 0
var _promises: Array = []
var _period: String = "aube"
var _card_visible: bool = false
var _current_card: Dictionary = {}

# UI node references (set by scene setup)
var _life_bar: ProgressBar = null
var _life_label: Label = null
var _currency_label: Label = null
var _ogham_button: Button = null
var _period_label: Label = null
var _promise_container: Control = null
var _card_panel: Control = null
var _card_text_label: RichTextLabel = null
var _option_buttons: Array = []  # Array[Button]


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP — Bind to Run3DController signals
# ═══════════════════════════════════════════════════════════════════════════════

func bind_to_run_controller(controller: Run3DController) -> void:
	controller.life_changed.connect(update_life)
	controller.currency_changed.connect(update_currency)
	controller.ogham_updated.connect(update_ogham)
	controller.promises_updated.connect(update_promises)
	controller.period_changed.connect(update_period)
	controller.card_started.connect(_on_card_started)
	controller.card_ended.connect(_on_card_ended)
	controller.run_ended.connect(_on_run_ended)
	# Merchant spawner signal → HUD notification
	var spawner: NpcMerchantSpawner = controller.get_merchant_spawner()
	if spawner:
		spawner.merchant_spawned.connect(_on_merchant_spawned)


func set_ui_nodes(nodes: Dictionary) -> void:
	_life_bar = nodes.get("life_bar")
	_life_label = nodes.get("life_label")
	_currency_label = nodes.get("currency_label")
	_ogham_button = nodes.get("ogham_button")
	_period_label = nodes.get("period_label")
	_promise_container = nodes.get("promise_container")
	_card_panel = nodes.get("card_panel")
	_card_text_label = nodes.get("card_text_label")
	_option_buttons = nodes.get("option_buttons", [])

	# Connect ogham button
	if _ogham_button and not _ogham_button.pressed.is_connected(_on_ogham_pressed):
		_ogham_button.pressed.connect(_on_ogham_pressed)

	# Connect option buttons
	for i in range(_option_buttons.size()):
		var btn: Button = _option_buttons[i]
		if btn and not btn.pressed.is_connected(_on_option_pressed.bind(i)):
			btn.pressed.connect(_on_option_pressed.bind(i))


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS — From Run3DController
# ═══════════════════════════════════════════════════════════════════════════════

func update_life(current: int, maximum: int) -> void:
	_life = current
	_life_max = maximum
	if _life_bar:
		_life_bar.max_value = maximum
		_life_bar.value = current
	if _life_label:
		_life_label.text = "%d/%d" % [current, maximum]
	# Low life warning
	if current <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD and _life_bar:
		_life_bar.modulate = MerlinVisual.CRT_PALETTE["danger"]
	elif _life_bar:
		_life_bar.modulate = Color.WHITE


func update_currency(amount: int) -> void:
	_currency = amount
	if _currency_label:
		_currency_label.text = str(amount)


func update_ogham(ogham_id: String, cooldown: int) -> void:
	_current_ogham = ogham_id
	_ogham_cooldown = cooldown
	if _ogham_button:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		var name: String = str(spec.get("name", ogham_id))
		if cooldown > 0:
			_ogham_button.text = "%s (%d)" % [name, cooldown]
			_ogham_button.disabled = true
		else:
			_ogham_button.text = name
			_ogham_button.disabled = false


func update_promises(promises: Array, current_card_index: int = 0) -> void:
	_promises = promises
	if _promise_container == null:
		return
	# Clear existing
	for child in _promise_container.get_children():
		child.queue_free()
	# Add promise indicators
	for promise in promises:
		if not (promise is Dictionary):
			continue
		var label: Label = Label.new()
		var desc: String = str(promise.get("description", ""))
		var deadline: int = int(promise.get("deadline_card", 0))
		var remaining: int = maxi(deadline - current_card_index, 0)
		label.text = "%s (%d)" % [desc, remaining]
		label.add_theme_font_size_override("font_size", 12)
		_promise_container.add_child(label)


func update_period(period: String) -> void:
	_period = period
	if _period_label:
		var labels: Dictionary = {
			"aube": "Aube",
			"jour": "Jour",
			"crepuscule": "Crepuscule",
			"nuit": "Nuit",
		}
		_period_label.text = str(labels.get(period, period))


func show_ogham_switch_menu(available: Array) -> void:
	# Emit signal — actual menu creation is scene-dependent
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# CARD OVERLAY
# ═══════════════════════════════════════════════════════════════════════════════

func _on_card_started(card: Dictionary) -> void:
	_current_card = card
	_card_visible = true
	_show_card_overlay(card)


func _on_card_ended() -> void:
	_card_visible = false
	_current_card = {}
	_hide_card_overlay()


func _on_run_ended(_reason: String, _data: Dictionary) -> void:
	_hide_card_overlay()


func _on_merchant_spawned(npc_name: String) -> void:
	print("[HUD] Merchant appeared: %s" % npc_name)


func _show_card_overlay(card: Dictionary) -> void:
	if _card_panel:
		_card_panel.visible = true
	if _card_text_label:
		_card_text_label.text = str(card.get("text", ""))

	var options: Array = card.get("options", [])
	for i in range(_option_buttons.size()):
		var btn: Button = _option_buttons[i]
		if btn == null:
			continue
		if i < options.size():
			var option: Dictionary = options[i] if options[i] is Dictionary else {}
			btn.text = str(option.get("label", "..."))
			btn.visible = true
			btn.disabled = false
		else:
			btn.visible = false

	# Show ogham button during card (can activate before choosing)
	if _ogham_button:
		_ogham_button.visible = true


func _hide_card_overlay() -> void:
	if _card_panel:
		_card_panel.visible = false
	for btn in _option_buttons:
		if btn:
			btn.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# USER INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _on_option_pressed(index: int) -> void:
	if not _card_visible:
		return
	# Disable buttons to prevent double-click
	for btn in _option_buttons:
		if btn:
			btn.disabled = true
	option_selected.emit(index)


func _on_ogham_pressed() -> void:
	if _ogham_cooldown > 0:
		return
	ogham_activated.emit(_current_ogham)


# ═══════════════════════════════════════════════════════════════════════════════
# QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

func is_card_visible() -> bool:
	return _card_visible


func get_current_life() -> int:
	return _life


func get_current_period() -> String:
	return _period
