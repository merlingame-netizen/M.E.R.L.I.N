## LocaleManager — Gestionnaire de Langue (Autoload Singleton)
## Integre TranslationServer pour l'UI et fournit les directives LLM.
extends Node

signal language_changed(lang_code: String)

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "fr"
const DIRECTIVES_PATH := "res://data/ai/config/language_directives.json"

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
var _directives: Dictionary = {}


func _ready() -> void:
	_load_language()
	_load_directives()
	TranslationServer.set_locale(_current_language)


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
	TranslationServer.set_locale(code)
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


## Returns the LLM language directive for the current language.
## Injected into system prompts as {language_directive}.
func get_llm_directive() -> String:
	var lang_data: Dictionary = _directives.get(_current_language, _directives.get("_default", {}))
	var directive: String = str(lang_data.get("directive", ""))
	var gloss: String = str(lang_data.get("celtic_gloss", ""))
	if directive.is_empty() and gloss.is_empty():
		return ""
	# Replace {language_name} placeholder for _default template
	directive = directive.replace("{language_name}", get_language_name())
	var parts: Array = []
	if not directive.is_empty():
		parts.append(directive)
	if not gloss.is_empty():
		parts.append(gloss)
	return " ".join(parts)


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


func _load_directives() -> void:
	if not FileAccess.file_exists(DIRECTIVES_PATH):
		push_warning("[LocaleManager] Language directives file not found: %s" % DIRECTIVES_PATH)
		return
	var file := FileAccess.open(DIRECTIVES_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_directives = json.data
