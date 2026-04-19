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

const WHISPERS_LANDES: Array[String] = [
	"La bruyere s'incline a ton passage. Ou est-ce le vent ?",
	"Les menhirs comptent tes pas. Ils ont l'eternite.",
	"Les landes ne pardonnent pas l'orgueil.",
	"Le vent d'ouest porte les voix des navigateurs perdus.",
	"Ici, meme les pierres ont des opinions.",
	"L'horizon tremble comme un mirage de chaleur. En Bretagne.",
]

const WHISPERS_COTES: Array[String] = [
	"L'ecume murmure des noms oublies.",
	"Les falaises reculent d'un pouce par siecle. Patience.",
	"Le sel preserve tout \u2014 meme les regrets.",
	"Un phare quelque part cligne dans la brume.",
	"La mer prend plus qu'elle ne donne. Toujours.",
	"Les goemoniers connaissaient les vagues par leur prenom.",
]

const WHISPERS_VILLAGES: Array[String] = [
	"Les murs ont des oreilles. Et parfois des bouches.",
	"Quelqu'un laisse du lait pour les korrigans. Sage.",
	"La fumee des cheminees raconte qui est chez soi.",
	"Le forgeron frappe au rythme de la terre.",
	"Un chat noir te regarde depuis le seuil. Signe ? Quel signe ?",
	"Le puits du village se souvient de chaque voeu.",
]

const WHISPERS_CERCLES: Array[String] = [
	"Le cercle n'a ni debut ni fin. Comme cette conversation.",
	"Les pierres vibrent a une frequence que tu ne peux pas entendre. Pas encore.",
	"Quelqu'un a danse ici il y a trois mille ans. Le sol s'en souvient.",
	"Les alignements ne sont pas un hasard. Rien ne l'est.",
	"Tu te tiens au centre. Ou au bord. Difficile a dire.",
]

const WHISPERS_MARAIS: Array[String] = [
	"L'eau croupie cache des tresors. Et des dents.",
	"Les feux follets mentent. Mais pas toujours.",
	"La tourbe avale les secrets sans les digerer.",
	"Un korrigan te suit depuis trois tournants.",
	"Le marais respire. Lentement. Avec patience.",
	"Sous la mousse, quelque chose attend. Depuis longtemps.",
]

const WHISPERS_COLLINES: Array[String] = [
	"Du sommet, on voit le passe. Et un peu du futur.",
	"Les dolmens sont des portes. Vers ou ? Mystere.",
	"Le vent des collines porte des chansons sans paroles.",
	"Les ancetres dorment sous l'herbe. Certains pas tres profondement.",
	"Chaque colline est un tumulus qui s'ignore.",
]

const WHISPERS_ILES: Array[String] = [
	"L'ile n'etait pas la hier. Elle le sera peut-etre demain.",
	"Entre les marees, le temps hesite.",
	"Les iles mystiques existent entre deux mondes.",
	"Le brouillard qui les entoure n'est pas naturel.",
	"Tir na nOg est plus pres qu'on ne le pense.",
	"Les vagues ici chuchotent dans une langue d'avant les langues.",
]

const WHISPERS_CRITICAL: Array[String] = [
	"Tu vacilles... Le monde aussi.",
	"L'Ankou nettoie sa faux. Non loin.",
	"Tes ancetres tendent la main. Trop tot ?",
	"La lumiere faiblit. La tienne.",
	"Un pas de plus, ou un pas de trop ?",
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

	if _context_health_pct <= 0.10:
		pool.append_array(WHISPERS_CRITICAL)
		pool.append_array(WHISPERS_CRITICAL)
	elif _context_health_pct <= 0.25:
		pool.append_array(WHISPERS_LOW_HEALTH)
		pool.append_array(WHISPERS_LOW_HEALTH)
	elif _context_health_pct >= 0.9:
		pool.append_array(WHISPERS_HIGH_HEALTH)

	match _context_time:
		"night", "evening", "Nuit":
			pool.append_array(WHISPERS_NIGHT)
		"dawn", "Aube":
			pool.append_array(WHISPERS_DAWN)
		"dusk", "Crepuscule":
			pool.append_array(WHISPERS_DUSK)

	var biome_pool: Array[String] = _get_biome_pool(_context_biome)
	if biome_pool.size() > 0:
		pool.append_array(biome_pool)

	if _context_total_runs >= 5:
		pool.append_array(WHISPERS_VETERAN)

	return pool[randi() % pool.size()]


func _get_biome_pool(biome: String) -> Array[String]:
	if biome.find("broceliande") >= 0 or biome.find("foret") >= 0:
		return WHISPERS_BROCELIANDE
	if biome.find("landes") >= 0 or biome.find("bruyere") >= 0:
		return WHISPERS_LANDES
	if biome.find("cotes") >= 0 or biome.find("sauvages") >= 0:
		return WHISPERS_COTES
	if biome.find("villages") >= 0 or biome.find("celtes") >= 0:
		return WHISPERS_VILLAGES
	if biome.find("cercles") >= 0 or biome.find("pierres") >= 0:
		return WHISPERS_CERCLES
	if biome.find("marais") >= 0 or biome.find("korrigans") >= 0:
		return WHISPERS_MARAIS
	if biome.find("collines") >= 0 or biome.find("dolmens") >= 0:
		return WHISPERS_COLLINES
	if biome.find("iles") >= 0 or biome.find("mystiques") >= 0:
		return WHISPERS_ILES
	return []


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
