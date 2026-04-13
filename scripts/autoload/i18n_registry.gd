## I18nRegistry — Central Text Registry (Autoload Singleton)
## Loads text_registry.json and provides t() for all user-facing strings.
## Works alongside LocaleManager for language switching.
extends Node

const REGISTRY_PATH := "res://data/i18n/text_registry.json"

var _registry: Dictionary = {}
var _flat_cache: Dictionary = {}  # "ui.hub.anam_label" -> { "fr": "Anam: %d", ... }
var _current_lang: String = "fr"


func _ready() -> void:
	_load_registry()
	# Sync with LocaleManager if available
	if Engine.has_singleton("LocaleManager"):
		_current_lang = LocaleManager.get_language()
		LocaleManager.language_changed.connect(_on_language_changed)
	elif has_node("/root/LocaleManager"):
		var lm: Node = get_node("/root/LocaleManager")
		_current_lang = lm.call("get_language")
		if lm.has_signal("language_changed"):
			lm.language_changed.connect(_on_language_changed)


## Get translated text by dotted key. Returns French fallback if translation missing.
## Usage: I18nRegistry.t("ui.hub.anam_label") -> "Anam: %d"
## With format: I18nRegistry.t("ui.hub.anam_label") % [42] -> "Anam: 42"
func t(key: String) -> String:
	if _flat_cache.has(key):
		var entry: Dictionary = _flat_cache[key]
		var text: String = entry.get(_current_lang, "")
		if text.is_empty():
			# Fallback to French
			text = entry.get("fr", "")
		if text.is_empty():
			push_warning("[I18nRegistry] Missing translation: %s" % key)
			return "[%s]" % key
		return text
	push_warning("[I18nRegistry] Unknown key: %s" % key)
	return "[%s]" % key


## Get translated text with format arguments.
## Usage: I18nRegistry.tf("ui.hub.anam_label", [42]) -> "Anam: 42"
func tf(key: String, args: Array = []) -> String:
	var text: String = t(key)
	if args.is_empty():
		return text
	return text % args


## Check if a key exists in the registry.
func has_key(key: String) -> bool:
	return _flat_cache.has(key)


## Get all keys matching a prefix.
## Usage: I18nRegistry.keys_with_prefix("ui.hub.") -> ["ui.hub.anam_label", ...]
func keys_with_prefix(prefix: String) -> Array:
	var result: Array = []
	for key in _flat_cache:
		if key.begins_with(prefix):
			result.append(key)
	return result


## Get the raw entry dict for a key (all languages).
func get_entry(key: String) -> Dictionary:
	return _flat_cache.get(key, {})


## Reload registry from disk (for hot-reload during development).
func reload() -> void:
	_flat_cache.clear()
	_load_registry()


func _on_language_changed(lang_code: String) -> void:
	_current_lang = lang_code


func _load_registry() -> void:
	if not FileAccess.file_exists(REGISTRY_PATH):
		push_error("[I18nRegistry] Registry file not found: %s" % REGISTRY_PATH)
		return
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("[I18nRegistry] Cannot open: %s" % REGISTRY_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[I18nRegistry] JSON parse error: %s" % json.get_error_message())
		return
	if not json.data is Dictionary:
		push_error("[I18nRegistry] Registry root must be a Dictionary")
		return
	_registry = json.data
	_flatten(_registry, "")


## Recursively flatten nested dict into dotted keys.
## { "ui": { "hub": { "anam_label": { "fr": "..." } } } }
## -> _flat_cache["ui.hub.anam_label"] = { "fr": "..." }
func _flatten(node: Dictionary, prefix: String) -> void:
	for key in node:
		if key.begins_with("_"):
			continue  # Skip _meta
		var value = node[key]
		var full_key: String = prefix + key if prefix.is_empty() else prefix + "." + key
		if value is Dictionary:
			# Check if this is a leaf (has language codes) or a branch
			if value.has("fr") or value.has("en"):
				_flat_cache[full_key] = value
			else:
				_flatten(value, full_key)
