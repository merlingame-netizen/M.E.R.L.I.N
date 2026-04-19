extends CanvasLayer
class_name MerlinWhisper

signal whisper_shown(text: String)

const INTERVAL_MIN: float = 18.0
const INTERVAL_MAX: float = 30.0
const FADE_IN: float = 1.2
const HOLD: float = 4.5
const FADE_OUT: float = 1.8

const WHISPERS_GENERIC: Array[String] = [
	"Les racines murmurent ton nom...",
	"Le vent porte des mots anciens.",
	"Quelque chose t'observe entre les branches.",
	"Les pierres se souviennent de toi.",
	"Le temps hesite ici.",
	"Un echo de tes vies passees...",
	"La brume a des yeux.",
	"Chaque pas reveille un souvenir enfoui.",
	"Les etoiles bougent quand tu ne regardes pas.",
	"Le sentier n'etait pas la hier.",
	"Ecoute... le silence a une voix.",
	"Tu marches sur les reves des anciens.",
	"La foret respire avec toi.",
	"Un korrigan ricane dans l'ombre. Ou pas.",
	"Le chene murmure : 'encore un...'",
]

const WHISPERS_LOW_HEALTH: Array[String] = [
	"Ton souffle faiblit... prudence.",
	"Les ombres se rapprochent de toi.",
	"La foret sent ta faiblesse.",
	"Chaque pas coute plus cher maintenant.",
	"Les corbeaux tournent au-dessus de toi.",
]

const WHISPERS_HIGH_HEALTH: Array[String] = [
	"Ta vitalite irradie. La foret le sent.",
	"Les esprits s'ecartent sur ton passage.",
	"Tu brilles comme un feu dans la nuit.",
]

const WHISPERS_NIGHT: Array[String] = [
	"La nuit celtique n'est jamais vraiment noire.",
	"Les feux follets dansent a la lisiere.",
	"Sous la lune, les regles changent.",
	"Les morts marchent aussi, la nuit.",
	"Un hibou te surveille depuis trois chenes.",
]

const WHISPERS_DAWN: Array[String] = [
	"L'aube lave les peches de la nuit.",
	"Le premier rayon touche les menhirs en premier.",
	"Un nouveau jour, une nouvelle chance de comprendre.",
]

const WHISPERS_DUSK: Array[String] = [
	"Le crepuscule brouille les frontieres.",
	"Entre chien et loup... litteralement.",
	"Les ombres s'etirent comme des doigts.",
]

const WHISPERS_BROCELIANDE: Array[String] = [
	"Broceliande cache plus qu'elle ne montre.",
	"Viviane dort quelque part sous ces eaux.",
	"L'arbre de Merlin pulse encore, parfois.",
	"Chaque clairiere est un piege ou un cadeau.",
	"Les druides ont plante ces chenes il y a mille ans.",
]

const WHISPERS_VETERAN: Array[String] = [
	"Tu commences a comprendre les regles. Attention.",
	"La foret change pour ceux qui reviennent trop souvent.",
	"Tu as deja vu cette clairiere... non ?",
	"Les esprits te reconnaissent maintenant.",
]

var _label: Label
var _timer: float = 0.0
var _next_interval: float = 12.0
var _active: bool = false
var _paused: bool = false
var _tween: Tween

var _context_biome: String = "broceliande"
var _context_health_pct: float = 1.0
var _context_time: String = "morning"
var _context_total_runs: int = 0


func _ready() -> void:
	layer = 4
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -80
	_label.offset_bottom = -24
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(14))
	_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])
	_label.modulate.a = 0.0
	_label.text = ""
	add_child(_label)
	_next_interval = randf_range(8.0, 15.0)
	_active = true


func _process(delta: float) -> void:
	if not _active or _paused:
		return
	_timer += delta
	if _timer >= _next_interval:
		_timer = 0.0
		_next_interval = randf_range(INTERVAL_MIN, INTERVAL_MAX)
		_show_whisper(_pick_whisper())


func set_context(biome: String, health_pct: float, time_of_day: String, total_runs: int = 0) -> void:
	_context_biome = biome
	_context_health_pct = health_pct
	_context_time = time_of_day
	_context_total_runs = total_runs


func pause_whispers() -> void:
	_paused = true


func resume_whispers() -> void:
	_paused = false
	_timer = 0.0
	_next_interval = randf_range(8.0, 15.0)


func force_whisper(text: String) -> void:
	_show_whisper(text)


func _pick_whisper() -> String:
	var pool: Array[String] = []
	pool.append_array(WHISPERS_GENERIC)

	if _context_health_pct <= 0.25:
		pool.append_array(WHISPERS_LOW_HEALTH)
		pool.append_array(WHISPERS_LOW_HEALTH)
	elif _context_health_pct >= 0.9:
		pool.append_array(WHISPERS_HIGH_HEALTH)

	match _context_time:
		"night", "evening":
			pool.append_array(WHISPERS_NIGHT)
		"dawn":
			pool.append_array(WHISPERS_DAWN)
		"dusk":
			pool.append_array(WHISPERS_DUSK)

	if _context_biome.find("broceliande") >= 0:
		pool.append_array(WHISPERS_BROCELIANDE)

	if _context_total_runs >= 5:
		pool.append_array(WHISPERS_VETERAN)

	return pool[randi() % pool.size()]


func _show_whisper(text: String) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_label.text = text
	_label.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_label, "modulate:a", 0.7, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_OUT)

	whisper_shown.emit(text)

	if is_instance_valid(SFXManager):
		SFXManager.play_varied("mist_breath", 0.15)
