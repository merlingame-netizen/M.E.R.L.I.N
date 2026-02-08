## ═══════════════════════════════════════════════════════════════════════════════
## LocaleManager — Gestionnaire de Langue (Autoload Singleton)
## ═══════════════════════════════════════════════════════════════════════════════
## Charge/sauvegarde la langue choisie, fournit le chemin de donnees localise.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

signal language_changed(lang_code: String)

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "fr"

const SUPPORTED_LANGUAGES := {
	"fr": "Francais",
	"en": "English",
	"es": "Espanol",
	"it": "Italiano",
	"pt": "Portugues",
	"zh": "中文",
	"ja": "日本語",
}

var _current_language := DEFAULT_LANGUAGE


func _ready() -> void:
	_load_language()


func get_language() -> String:
	return _current_language


func set_language(code: String) -> void:
	if not SUPPORTED_LANGUAGES.has(code):
		push_warning("[LocaleManager] Unsupported language code: %s" % code)
		return
	if code == _current_language:
		return
	_current_language = code
	_save_language()
	language_changed.emit(code)


func get_language_name(code: String = "") -> String:
	if code.is_empty():
		code = _current_language
	return SUPPORTED_LANGUAGES.get(code, code)


func get_supported_codes() -> Array:
	return SUPPORTED_LANGUAGES.keys()


func get_data_path(base_path: String) -> String:
	## Transforms a base data path into its localized version.
	## "res://data/dialogues/scene_dialogues.json" + lang "en"
	## -> "res://data/dialogues/scene_dialogues_en.json"
	## French ("fr") uses the original file (no suffix).
	if _current_language == DEFAULT_LANGUAGE:
		return base_path

	var dot_pos: int = base_path.rfind(".")
	if dot_pos == -1:
		return base_path + "_" + _current_language

	var stem: String = base_path.substr(0, dot_pos)
	var ext: String = base_path.substr(dot_pos)
	var localized: String = stem + "_" + _current_language + ext

	if FileAccess.file_exists(localized):
		return localized

	push_warning("[LocaleManager] Localized file not found: %s — falling back to %s" % [localized, base_path])
	return base_path


func _load_language() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var code: String = config.get_value("language", "code", DEFAULT_LANGUAGE)
		if SUPPORTED_LANGUAGES.has(code):
			_current_language = code


func _save_language() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("language", "code", _current_language)
	config.save(CONFIG_PATH)
