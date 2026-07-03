class_name MerlinSceneArt
extends Control
## v10.16 — Décor vivant : silhouettes plates + lune réactive + god rays + 18 motes 3 catégories
## + brume parallaxe réactive + arbres réactifs. DA flat rétro-minimaliste (2026-05-26).

const COL_SCENE_BG: Color = MerlinVisual.SCENE_BG
const COL_SIL: Color = MerlinVisual.SILHOUETTE
const COL_MOON: Color = MerlinVisual.CREAM
const COL_STONE: Color = MerlinVisual.INK
const COL_INK: Color = MerlinVisual.SILHOUETTE
const COL_MIST: Color = MerlinVisual.MIST

var _beat: String = "Exploration"
var _menu_decor: bool = false
var _animated: bool = false
var _t: float = 0.0

const HALO_SPEED_IDLE: float = 0.45
const HALO_SPEED_THINK: float = 1.6
var _thinking: bool = false
var _halo_phase: float = 0.0

var _moon_flash: float = 0.0
var _moon_dim: float = 0.0
var _mist_factor: float = 1.0
var _tree_sway: float = 0.0
var _react_tw: Tween = null

# v10.18 (menu Phase 2) — densité de motes + parallaxe + aura de curseur, pilotés par merlin_menu.gd.
var _mote_density: float = 1.0
var _parallax: Vector2 = Vector2.ZERO
var _cursor_pos: Vector2 = Vector2.ZERO
var _cursor_inside: bool = false

# v10.18 — Variation selon l'heure RÉELLE (aube/jour/crépuscule/nuit) : teinte du ciel + chaleur de
# la lune. Dérivé des couleurs canon (zéro hex). Défaut = nuit canon → in-game inchangé.
var _tod_sky: Color = MerlinVisual.SCENE_BG
var _tod_moon_warm: float = 0.0
var _fireflies: bool = false  # v10.18 — lucioles (nuit/crépuscule, menu)

# v10.18 — Étoiles filantes occasionnelles (MENU uniquement) : traînée crème le long d'un court arc.
var _shoot_t: float = -1.0            # <0 = inactive ; sinon progression 0→1
var _shoot_next: float = 4.0          # compte à rebours avant la prochaine
var _shoot_a: Vector2 = Vector2.ZERO  # départ (normalisé 0-1)
var _shoot_b: Vector2 = Vector2.ZERO  # arrivée (normalisé 0-1)

# v10.18 — Regard de MERLIN (menu) : suit la souris, cligne des yeux, regarde ailleurs par moments.
var _fig_head: Vector2 = Vector2.ZERO  # centre de la tête (calculé en _draw, lu en _process : 1 frame de retard ok)
var _fig_hr: float = 1.0               # rayon de la tête
var _gaze: Vector2 = Vector2.ZERO      # décalage de regard LISSÉ (-1..1 par axe)
var _blink: float = 0.0                # 0 = ouvert, 1 = fermé (pic du clignement)
var _blink_t: float = -1.0             # <0 = pas en clignement ; sinon progression
var _blink_next: float = 3.0           # compte à rebours avant le prochain clignement
var _lookaway_t: float = -1.0          # <0 = suit la souris ; sinon regarde ailleurs (épisode)
var _lookaway_next: float = 5.0
var _lookaway_dir: Vector2 = Vector2.ZERO

# v10.18 — Matérialisation de Merlin COUCHE PAR COUCHE (boot) : 0 = invisible, 1 = pleinement matérialisé.
# Défaut 1.0 → menu/in-game inchangés. cape [0-0.45] → tête [0.40-0.70] → yeux [0.65-1.0].
var _fig_reveal: float = 1.0

# v10.18 — Révélation du DÉCOR (boot cinématique) : 0 = décor caché (gros plan yeux sur fond ciel),
# 1 = décor complet. Multiplie l'alpha de TOUS les éléments décor (PAS la figure). Défaut 1.0 → menu/in-game inchangés.
var _decor_reveal: float = 1.0

# v10.18 — Hooks YEUX cinématiques (boot) : surcouches neutres par défaut → menu/in-game inchangés.
var _eye_open_force: float = -1.0   # <0 = clignement auto ; sinon 0..1 ouverture FORCÉE (réveil)
var _eye_glow: float = 1.0          # multiplicateur de luminosité des yeux (réveil + flash ébahi)
var _eye_widen: float = 1.0         # écartement + allongement des barres (ébahi)
# v10.20 — HUMEUR des yeux (R124, user 2026-06-29) : neutral=bleu brillant, surprise=jaune+glow,
# angry=rouge+sourcils froncés. Décroît vers neutral après quelques secondes.
var _eye_mood: String = "neutral"
var _eye_mood_t: float = 0.0
# v10.20 — Mode ŒIL-LUNE (in-game, user 2026-06-29) : les yeux de Merlin vivent DANS la lune (cercle
# central) et suivent le curseur. La lune est agrandie ; les yeux du figure sont alors supprimés (doublon).
var _watch_eyes: bool = false
var _gaze_scripted: bool = false    # true = regard piloté par merlin_boot (pas la souris)
var _gaze_forced: Vector2 = Vector2.ZERO

# v10.18 — SAISON : feuillage saisonnier dérivé palette canon (zéro hex). Défaut neutre (alpha 0) → arbres nus inchangés.
var _season_key: String = ""
var _season_leaf: Color = MerlinVisual.GREEN
var _season_leaf_a: float = 0.0
var _season_blobs: int = 0
var _season_blob_r: float = 0.012
var _season_fly_mult: float = 1.0
var _season_fly_col: Color = MerlinVisual.GREEN.lerp(MerlinVisual.GOLD, 0.45)
var _season_sol: Color = MerlinVisual.SILHOUETTE
var _season_sol_f: float = 0.0
var _season_sky: Color = MerlinVisual.SCENE_BG
var _season_sky_f: float = 0.0

# v10.20.3 (Wave C) — FACTION de la run : teinte LÉGÈRE du décor (lune + ciel + motes) dérivée UNIQUEMENT
# de la palette canon (zéro hex). Modulation subtile (DA cohérente) ; Corrompus = le shift le plus froid/marqué.
# Défaut "" → forces à 0 → menu/in-game inchangés tant qu'aucune faction n'est posée.
var _faction_key: String = ""
var _faction_accent: Color = MerlinVisual.GOLD
var _faction_moon_f: float = 0.0
var _faction_sky_f: float = 0.0
var _faction_mote_f: float = 0.0

# v10.21 — SILHOUETTE DU PILIER PNJ (spec panel) : présence SEULEMENT aux beats du PNJ (Rencontre,
# interventions). Bande GAUCHE (x=0.22w — la beat map vit à droite), pieds sur la crête du sol,
# couleur SILHOUETTE.lerp(accent, 0.25) (§20 zéro hex), matérialisation 1.0s / disparition 0.6s ×motion().
const PILIER_ACCENT: Dictionary = {
	"choeur": "GREEN", "etre": "RARE_BLUE", "chevalier": "GOLD", "compagnon": "VIOLET", "enfant": "CREAM"}
var _pilier_key: String = ""
var _pilier_reveal: float = 0.0  # 0 = absent → 1 = matérialisé (rampe corps puis détails)
var _pilier_tw: Tween = null

# v10.21 (user 2026-06-30 : « décor bien plus animé, moins design HTML ») — REFONTE ORGANIQUE.
# Feuilles qui tombent (couleur saisonnière ; hiver = flocons crème). 6 particules recyclées.
const LEAF_COUNT: int = 6
var _leaves: Array = []  # [{p:Vector2 (normalisé 0-1), phase:float, speed:float, size:float}]
# Oiseau furtif : silhouette « accent circonflexe » qui traverse le ciel (rare, comme l'étoile filante).
var _bird_t: float = -1.0
var _bird_next: float = 9.0
var _bird_y: float = 0.18
var _bird_dir: float = 1.0
var _bird_flock: int = 3


func set_beat(beat_type: String) -> void:
	_beat = beat_type
	queue_redraw()


func set_menu_decor(on: bool) -> void:
	_menu_decor = on
	queue_redraw()


func set_animated(on: bool) -> void:
	_animated = on
	set_process(on)
	queue_redraw()


func set_thinking(on: bool) -> void:
	if on == _thinking:
		return
	_thinking = on
	queue_redraw()


func flash_moon() -> void:
	if _react_tw != null and _react_tw.is_valid():
		_react_tw.kill()
	_moon_dim = 0.0
	_moon_flash = 1.0
	_react_tw = create_tween()
	_react_tw.tween_property(self, "_moon_flash", 0.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func dim_moon() -> void:
	if _react_tw != null and _react_tw.is_valid():
		_react_tw.kill()
	_moon_flash = 0.0
	_moon_dim = 0.6
	_react_tw = create_tween()
	_react_tw.tween_property(self, "_moon_dim", 0.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func thicken_mist() -> void:
	_mist_factor = 2.2
	var tw: Tween = create_tween()
	tw.tween_property(self, "_mist_factor", 1.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func sway_trees() -> void:
	_tree_sway = 4.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "_tree_sway", 0.0, MerlinVisual.DUR_WORLD_REACT * MerlinVisual.motion() * 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# v10.18 (menu Phase 2) — réactions composées + contrôles continus pilotés par merlin_menu.gd.

# Souffle de forêt : les arbres oscillent ET la brume s'épaissit brièvement (réutilise l'existant).
func trigger_gust() -> void:
	sway_trees()
	thicken_mist()


# Pulse rare de l'orbe lunaire (réutilise le flash réactif).
func moon_pulse() -> void:
	flash_moon()


# Densité de motes (1.0 = canon) — le menu monte à ~1.35 pour un fond plus vivant. Borné.
func set_mote_density(factor: float) -> void:
	_mote_density = clampf(factor, 0.0, 3.0)
	queue_redraw()


# Décalage de parallaxe (px) suivant le curseur : lune/motes = couche lointaine (facteur < 1) dans _draw.
func set_parallax(offset: Vector2) -> void:
	_parallax = offset
	queue_redraw()


# Curseur (coordonnées locales au node) + dedans/dehors → aura GOLD douce près du curseur dans _draw.
func set_cursor(pos: Vector2, inside: bool) -> void:
	_cursor_pos = pos
	_cursor_inside = inside
	queue_redraw()


# Matérialisation progressive de Merlin (boot) : 0 = invisible → 1 = pleinement matérialisé.
func set_figure_reveal(p: float) -> void:
	_fig_reveal = clampf(p, 0.0, 1.0)
	queue_redraw()


# v10.18 — Boot cinématique : révélation du décor (0 = caché → 1 = complet). Les yeux/tête (figure) ne
# sont PAS affectés → ils restent visibles sur fond ciel pendant le gros plan (decor_reveal=0).
func set_decor_reveal(p: float) -> void:
	_decor_reveal = clampf(p, 0.0, 1.0)
	queue_redraw()


# v10.18 — Boot cinématique (yeux). set_eye_open(v<0) = clignement auto ; v∈[0..1] = ouverture forcée.
func set_eye_open(v: float) -> void:
	_eye_open_force = v
	queue_redraw()


func set_eye_glow(v: float) -> void:
	_eye_glow = maxf(v, 0.0)
	queue_redraw()


func set_eye_widen(v: float) -> void:
	_eye_widen = maxf(v, 0.1)
	queue_redraw()


# Humeur des yeux : "neutral" (bleu), "surprise" (jaune+glow), "angry" (rouge+sourcils). Décroît seule.
func set_eye_mood(mood: String) -> void:
	_eye_mood = mood
	_eye_mood_t = 0.0 if mood == "neutral" else 4.5  # tenue ~4.5s puis retour au bleu
	queue_redraw()


# v10.20 — Mode œil-lune (in-game) : yeux dans la lune qui suivent le curseur (set_cursor) + humeur.
func set_watch_eyes(on: bool) -> void:
	_watch_eyes = on
	queue_redraw()


# Heuristique d'humeur depuis une réplique (zéro LLM) : "?"/interjections → surprise ; ton dur/colère/
# corruption → angry ; sinon neutral. Statique → utilisable par tout appelant qui fait parler Merlin.
static func mood_for_text(t: String) -> String:
	var s: String = t.to_lower()
	var angry: PackedStringArray = ["jamais", "insolent", "gare", "malheur", "fureur", "colère", "colere",
		"insensé", "insense", "imprudent", "tais-toi", "n'ose", "trahi", "maudit", "ténèbres", "tenebres",
		"corruption", "ombre te"]
	for w in angry:
		if s.find(w) != -1:
			return "angry"
	if s.find("?") != -1 or s.find("…") != -1 or s.find("oh") != -1 or s.find("ah ") != -1 \
			or s.find("tiens") != -1 or s.find("vraiment") != -1 or s.find("étrange") != -1 \
			or s.find("etrange") != -1 or s.find("korrigan") != -1 or s.find("eh bien") != -1:
		return "surprise"
	return "neutral"


# Regard piloté par le boot (séquence scriptée gauche/droite/centre) au lieu de suivre la souris.
func set_scripted_gaze(on: bool, dir: Vector2 = Vector2.ZERO) -> void:
	_gaze_scripted = on
	_gaze_forced = dir
	queue_redraw()


# v10.18 — SAISON : feuillage + accents dérivés UNIQUEMENT de la palette canon (zéro hex). Clé inconnue
# / "" → neutre (arbres nus, menu/in-game inchangés). L'heure du jour garde l'autorité sur ciel/lune ;
# la saison ne fait que MODULER (lerp léger) pour éviter les conflits de teinte.
func set_season(season: String) -> void:
	_season_key = season
	match season:
		"printemps":
			_season_leaf = MerlinVisual.GREEN.lerp(MerlinVisual.CREAM, 0.30)
			_season_leaf_a = 0.55
			_season_blobs = 2
			_season_blob_r = 0.012
			_season_fly_mult = 1.0
			_season_fly_col = MerlinVisual.GREEN.lerp(MerlinVisual.GOLD, 0.45)
			_season_sol = MerlinVisual.GREEN
			_season_sol_f = 0.10
			_season_sky = MerlinVisual.GREEN
			_season_sky_f = 0.05
		"ete":
			_season_leaf = MerlinVisual.GREEN.lerp(MerlinVisual.GOLD, 0.18)
			_season_leaf_a = 0.78
			_season_blobs = 3
			_season_blob_r = 0.016
			_season_fly_mult = 1.0
			_season_fly_col = MerlinVisual.GOLD.lerp(MerlinVisual.GREEN, 0.30)
			_season_sol = MerlinVisual.GOLD
			_season_sol_f = 0.08
			_season_sky = MerlinVisual.GOLD
			_season_sky_f = 0.06
		"automne":
			_season_leaf = MerlinVisual.GOLD.lerp(MerlinVisual.VIOLET, 0.22)
			_season_leaf_a = 0.62
			_season_blobs = 2
			_season_blob_r = 0.013
			_season_fly_mult = 0.8
			_season_fly_col = MerlinVisual.GOLD.lerp(MerlinVisual.GREEN, 0.45)
			_season_sol = MerlinVisual.VIOLET
			_season_sol_f = 0.10
			_season_sky = MerlinVisual.VIOLET
			_season_sky_f = 0.07
		"hiver":
			_season_leaf = MerlinVisual.CREAM.lerp(MerlinVisual.RARE_BLUE, 0.20)
			_season_leaf_a = 0.28
			_season_blobs = 1
			_season_blob_r = 0.009
			_season_fly_mult = 0.4
			_season_fly_col = MerlinVisual.RARE_BLUE.lerp(MerlinVisual.CREAM, 0.30)
			_season_sol = MerlinVisual.RARE_BLUE
			_season_sol_f = 0.12
			_season_sky = MerlinVisual.RARE_BLUE
			_season_sky_f = 0.08
		_:
			_season_leaf_a = 0.0
			_season_blobs = 0
			_season_sol_f = 0.0
			_season_sky_f = 0.0
			_season_fly_mult = 1.0
			_season_fly_col = MerlinVisual.GREEN.lerp(MerlinVisual.GOLD, 0.45)
	queue_redraw()


# v10.20.3 (Wave C) — FACTION de la run : pose l'accent + les forces de teinte (lune/ciel/motes). Idempotent
# (re-appel même clé = no-op) → appelable à chaque beat sans coût. Clé inconnue / "" → neutre (forces 0).
func set_faction(faction: String) -> void:
	if faction == _faction_key:
		return
	_faction_key = faction
	match faction:
		"druides":      # sage de la nature — vert vivant
			_faction_accent = MerlinVisual.GREEN
			_faction_moon_f = 0.14; _faction_sky_f = 0.05; _faction_mote_f = 0.30
		"creatures":    # féerique étrange — bleu-acier d'outre-monde
			_faction_accent = MerlinVisual.RARE_BLUE
			_faction_moon_f = 0.18; _faction_sky_f = 0.06; _faction_mote_f = 0.40
		"chevalerie":   # honneur terni — or patiné (gris-or)
			_faction_accent = MerlinVisual.GOLD.lerp(MerlinVisual.DIM_WARM, 0.45)
			_faction_moon_f = 0.16; _faction_sky_f = 0.04; _faction_mote_f = 0.30
		"corrompus":    # froid malsain — violet de Corruption, le shift le plus marqué
			_faction_accent = MerlinVisual.VIOLET
			_faction_moon_f = 0.26; _faction_sky_f = 0.10; _faction_mote_f = 0.55
		_:
			_faction_accent = MerlinVisual.GOLD
			_faction_moon_f = 0.0; _faction_sky_f = 0.0; _faction_mote_f = 0.0
	queue_redraw()


# v10.21 — Présence du PNJ pilier : matérialisation 1.0s (rampe corps→détails) / disparition 0.6s,
# ×motion(). Reduce-motion (R74) : alpha instantané. key="" ou on=false → départ fondu.
func set_pilier(key: String, on: bool) -> void:
	if on and key != "":
		_pilier_key = key
	var target: float = 1.0 if (on and key != "") else 0.0
	if _pilier_tw != null and _pilier_tw.is_valid():
		_pilier_tw.kill()
	if MerlinVisual.reduced_motion:
		_pilier_reveal = target
		queue_redraw()
		return
	_pilier_tw = create_tween()
	_pilier_tw.tween_property(self, "_pilier_reveal", target,
		(1.0 if target > 0.5 else 0.6) * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Saison courante dérivée de la date système (override possible via MERLIN_SEASON pour les tests).
static func season_for_now() -> String:
	if OS.has_environment("MERLIN_SEASON"):
		return OS.get_environment("MERLIN_SEASON")
	var mo: int = int(Time.get_datetime_dict_from_system().get("month", 6))
	if mo == 12 or mo <= 2:
		return "hiver"
	if mo <= 5:
		return "printemps"
	if mo <= 8:
		return "ete"
	return "automne"


# v10.18 — Le décor change selon l'heure réelle (passer Time...["hour"]). 4 périodes : la teinte du
# ciel et la chaleur de la lune varient ; le menu reste nocturne-merveilleux (variations subtiles).
# Teintes DÉRIVÉES des couleurs canon (zéro hex hors merlin_visual.gd).
func set_time_of_day(hour: int) -> void:
	var h: int = clampi(hour, 0, 23)
	_fireflies = false
	if h >= 5 and h < 9:        # aube — or chaud rosé
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.GOLD, 0.22).lerp(MerlinVisual.VIOLET, 0.06)
		_tod_moon_warm = 0.75
	elif h >= 9 and h < 17:     # jour — nettement plus CLAIR et froid
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.RARE_BLUE, 0.30).lerp(MerlinVisual.CREAM, 0.10)
		_tod_moon_warm = 0.15
	elif h >= 17 and h < 21:    # crépuscule — violet franc + lucioles
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.VIOLET, 0.30)
		_tod_moon_warm = 0.80
		_fireflies = true
	else:                        # nuit — bleu profond, lune froide + lucioles
		_tod_sky = MerlinVisual.SCENE_BG.lerp(MerlinVisual.RARE_BLUE, 0.16)
		_tod_moon_warm = 0.0
		_fireflies = true
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_halo_phase += delta * (HALO_SPEED_THINK if _thinking else HALO_SPEED_IDLE)
	if _eye_mood_t > 0.0:
		_eye_mood_t -= delta
		if _eye_mood_t <= 0.0:
			_eye_mood = "neutral"  # retour au bleu brillant après la tenue d'humeur
	if (_menu_decor or _watch_eyes) and not MerlinVisual.reduced_motion:
		if _menu_decor:
			_update_shooting_star(delta)
		_update_merlin_gaze(delta)  # menu = suit la souris ; œil-lune in-game = suit le curseur (set_cursor)
	elif _menu_decor and _gaze_scripted:
		_update_merlin_gaze(delta)  # reduced_motion : seul le gaze scripté (boot) tourne (early-return interne)
	if _animated and not MerlinVisual.reduced_motion:
		_update_leaves(delta)  # v10.21 : feuilles/flocons qui tombent (menu ET in-game)
		_update_bird(delta)    # v10.21 : oiseau furtif occasionnel
	queue_redraw()


# v10.21 — Feuilles qui tombent (couleur saisonnière ; hiver = flocons lents). Particules recyclées,
# positions NORMALISÉES (0-1) → indépendant du resize. Vent léger + spin par feuille.
func _update_leaves(delta: float) -> void:
	if _leaves.is_empty():
		for i in LEAF_COUNT:
			_leaves.append({"p": Vector2(randf(), randf() * 0.8), "phase": randf() * TAU,
				"speed": 0.028 + randf() * 0.022, "size": 0.8 + randf() * 0.7})
	var winter: bool = _season_key == "hiver"
	for lf in _leaves:
		var spd: float = float(lf["speed"]) * (0.55 if winter else 1.0)
		var pos: Vector2 = lf["p"]
		pos.y += spd * delta
		pos.x += (sin(_t * 1.6 + float(lf["phase"])) * 0.010 + 0.006) * delta
		if pos.y > 0.92:
			pos = Vector2(randf(), -0.04)
			lf["phase"] = randf() * TAU
		lf["p"] = pos


# v10.21 — Oiseau furtif : petit vol en « accents » qui traverse le haut du ciel (rare, 9-16 s).
func _update_bird(delta: float) -> void:
	if _bird_t < 0.0:
		_bird_next -= delta
		if _bird_next <= 0.0:
			_bird_next = randf_range(9.0, 16.0)
			_bird_t = 0.0
			_bird_y = randf_range(0.08, 0.26)
			_bird_dir = 1.0 if randf() < 0.5 else -1.0
			_bird_flock = 2 + (1 if randf() < 0.5 else 0)
	else:
		_bird_t += delta / 8.0  # traversée lente ~8 s
		if _bird_t > 1.0:
			_bird_t = -1.0


# Regard de Merlin (menu) : clignements ponctuels + suivi de la souris, interrompu par de courts
# épisodes où il « regarde ailleurs ». _gaze (offset -1..1) est lissé puis appliqué aux barres en _draw.
func _update_merlin_gaze(delta: float) -> void:
	# Boot cinématique : le regard est piloté (séquence scriptée) → on applique directement, pas de souris.
	if _gaze_scripted:
		_gaze = _gaze.lerp(_gaze_forced, clampf(delta * 9.0, 0.0, 1.0))
		return
	# Clignement : minuterie → pinch rapide (~0.16s) fermeture/ouverture (courbe sin 0→1→0).
	if _blink_t < 0.0:
		_blink_next -= delta
		if _blink_next <= 0.0:
			_blink_next = randf_range(2.4, 5.5)
			_blink_t = 0.0
	else:
		_blink_t += delta / 0.16
		_blink = sin(clampf(_blink_t, 0.0, 1.0) * PI)
		if _blink_t >= 1.0:
			_blink_t = -1.0
			_blink = 0.0
	# « Regarder ailleurs » : épisodes courts (0.8-1.6s) dans une direction aléatoire, surtout horizontale.
	if _lookaway_t < 0.0:
		_lookaway_next -= delta
		if _lookaway_next <= 0.0:
			_lookaway_next = randf_range(4.5, 9.0)
			_lookaway_t = randf_range(0.8, 1.6)
			var ang: float = randf_range(0.0, TAU)
			_lookaway_dir = Vector2(cos(ang), sin(ang) * 0.55)
	else:
		_lookaway_t -= delta
	# Cible de regard : ailleurs (pendant l'épisode) sinon vers la souris (dir tête→curseur, clampée).
	var target: Vector2 = Vector2.ZERO
	if _lookaway_t >= 0.0:
		target = _lookaway_dir
	elif _fig_hr > 1.0:
		var to_cur: Vector2 = (_cursor_pos - _fig_head) / (_fig_hr * 6.0)
		target = Vector2(clampf(to_cur.x, -1.0, 1.0), clampf(to_cur.y, -1.0, 1.0))
	_gaze = _gaze.lerp(target, clampf(delta * 6.0, 0.0, 1.0))  # suivi smooth


# Étoile filante (menu) : minuterie aléatoire (6-13s) puis traversée ~0.85s d'un court arc.
func _update_shooting_star(delta: float) -> void:
	if _shoot_t < 0.0:
		_shoot_next -= delta
		if _shoot_next <= 0.0:
			_shoot_next = randf_range(6.0, 13.0)
			_shoot_t = 0.0
			_shoot_a = Vector2(randf_range(0.10, 0.62), randf_range(0.05, 0.26))
			_shoot_b = _shoot_a + Vector2(randf_range(0.18, 0.32), randf_range(0.09, 0.17))
	else:
		_shoot_t += delta / 0.85
		if _shoot_t > 1.0:
			_shoot_t = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 4.0 or s.y <= 4.0:
		return
	var w: float = s.x
	var h: float = s.y
	var rm: bool = MerlinVisual.reduced_motion
	var dr: float = _decor_reveal  # v10.18 — révélation décor (boot) : multiplie l'alpha des éléments décor

	# Ciel : teinte de l'heure, MODULÉE par la saison puis (subtilement) par la faction de la run (Wave C).
	var sky_col: Color = _tod_sky.lerp(_season_sky, _season_sky_f).lerp(_faction_accent, _faction_sky_f)
	draw_rect(Rect2(Vector2.ZERO, s), sky_col, true)
	# v10.21 — PROFONDEUR du ciel : 2 bandes d'horizon légèrement éclaircies (banding flat, zéro dégradé).
	var horizon_l: Color = sky_col.lerp(MerlinVisual.CREAM, 0.045)
	draw_rect(Rect2(Vector2(0.0, h * 0.52), Vector2(w, h * 0.20)), Color(horizon_l.r, horizon_l.g, horizon_l.b, 0.5 * dr), true)
	var horizon_l2: Color = sky_col.lerp(MerlinVisual.CREAM, 0.08)
	draw_rect(Rect2(Vector2(0.0, h * 0.62), Vector2(w, h * 0.10)), Color(horizon_l2.r, horizon_l2.g, horizon_l2.b, 0.5 * dr), true)
	# v10.21 — ÉTOILES scintillantes (positions déterministes, twinkle par phase) — la nuit vit aussi in-game.
	if _animated:
		for sti in 14:
			var stf: float = float(sti)
			var sp2: Vector2 = Vector2(w * fmod(stf * 0.618 + 0.05, 1.0), h * (0.04 + 0.30 * fmod(stf * 0.382, 1.0)))
			var tw_a: float = (0.10 + 0.16 * maxf(sin(_t * (0.7 + fmod(stf, 0.6)) + stf * 2.3), 0.0)) * dr
			if rm:
				tw_a *= 0.5
			draw_circle(sp2 + _parallax * 0.3, 1.4 + fmod(stf * 0.7, 1.2), Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, tw_a))
	# v10.21 — COLLINES LOINTAINES : bande silhouette douce derrière les arbres (couche de profondeur).
	var hills: PackedVector2Array = PackedVector2Array()
	var h_steps: int = 16
	for hi2 in h_steps + 1:
		var hx: float = float(hi2) / float(h_steps) * w
		var hy: float = h * 0.74 + sin(hx * 0.006 + 1.3) * h * 0.030 + sin(hx * 0.017 + 4.0) * h * 0.012
		hills.append(Vector2(hx, hy) + _parallax * 0.25)
	hills.append(Vector2(w, h))
	hills.append(Vector2(0.0, h))
	draw_colored_polygon(hills, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, 0.30 * dr))

	var moon_c: Vector2 = Vector2(w * 0.5, h * 0.40) + _parallax * 0.5  # parallaxe : la lune = couche lointaine
	var moon_r: float = minf(w, h) * (0.17 if _watch_eyes else 0.13)  # lune agrandie en mode œil-lune (lisibilité)

	# God rays (behind everything except background)
	if _animated and not rm:
		for ri in 3:
			var angle: float = -0.35 + float(ri) * 0.35 + sin(_t * 0.03 + float(ri) * 1.7) * 0.08
			var top_half: float = w * 0.018
			var bot_half: float = w * 0.06
			var ray_len: float = h * 0.50
			var ca: float = cos(angle)
			var sa: float = sin(angle)
			var tip: Vector2 = moon_c + Vector2(sa, ca) * ray_len
			var pts: PackedVector2Array = PackedVector2Array([
				moon_c + Vector2(-ca * top_half, sa * top_half),
				moon_c + Vector2(ca * top_half, -sa * top_half),
				tip + Vector2(ca * bot_half, -sa * bot_half),
				tip + Vector2(-ca * bot_half, sa * bot_half),
			])
			var ra: float = (0.025 + 0.010 * sin(_t * 0.12 + float(ri) * 2.1)) * dr
			draw_colored_polygon(pts, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, ra))

	# Moon halos + disk
	if _animated:
		var halo_outer_r: float = moon_r * (1.45 + 0.08 * sin(_halo_phase * 0.6))
		var halo_outer_a: float = (0.025 + 0.012 * (0.5 + 0.5 * sin(_halo_phase * 0.6))) * dr
		if rm:
			halo_outer_a *= 0.5
		draw_circle(moon_c, halo_outer_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_outer_a))
		var halo_r: float = moon_r * (1.22 + 0.06 * sin(_halo_phase))
		var halo_a: float = (0.05 + 0.025 * (0.5 + 0.5 * sin(_halo_phase))) * dr
		draw_circle(moon_c, halo_r, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, halo_a))

	# Moon flash/dim reactive (+ chaleur selon l'heure, v10.18 ; + teinte de faction, Wave C)
	var moon_col: Color = COL_MOON.lerp(MerlinVisual.GOLD, _tod_moon_warm * 0.35).lerp(_faction_accent, _faction_moon_f)
	if _moon_flash > 0.01:
		moon_col = moon_col.lerp(Color.WHITE, _moon_flash * 0.6)
	if _moon_dim > 0.01:
		moon_col = moon_col.lerp(COL_SCENE_BG, _moon_dim)
	draw_circle(moon_c, moon_r, Color(moon_col.r, moon_col.g, moon_col.b, moon_col.a * dr))
	# v10.21 — ANNEAU RUNIQUE : 6 segments d'arc en rotation TRÈS lente autour de la lune (mystique discret).
	if _animated:
		var ring_r: float = moon_r * 1.55
		var ring_a: float = (0.07 + 0.02 * sin(_halo_phase * 0.5)) * dr * (0.5 if rm else 1.0)
		var ring_col: Color = Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, ring_a)
		var spin_r: float = _t * 0.04
		for ai in 6:
			var a0: float = spin_r + float(ai) * (TAU / 6.0)
			draw_arc(moon_c, ring_r, a0, a0 + 0.62, 7, ring_col, 2.0, true)

	# v10.20 — ŒIL-LUNE : les yeux de Merlin vivent DANS la lune et suivent le curseur (suivi gameplay,
	# user 2026-06-29). _fig_head/_fig_hr = lune → le gaze (_update_merlin_gaze) vise le curseur depuis ici.
	if _watch_eyes:
		_fig_head = moon_c
		_fig_hr = moon_r
		_draw_eyes(moon_c, moon_r * 0.80, 1.0)

	# v10.18 — étoile filante (menu) : traînée crème qui apparaît/disparaît le long de l'arc.
	if _menu_decor and _shoot_t >= 0.0 and _shoot_t <= 1.0 and not rm:
		var sh_head: Vector2 = Vector2(lerpf(_shoot_a.x, _shoot_b.x, _shoot_t) * w, lerpf(_shoot_a.y, _shoot_b.y, _shoot_t) * h)
		var sh_tt: float = maxf(_shoot_t - 0.14, 0.0)
		var sh_tail: Vector2 = Vector2(lerpf(_shoot_a.x, _shoot_b.x, sh_tt) * w, lerpf(_shoot_a.y, _shoot_b.y, sh_tt) * h)
		var sh_a: float = sin(_shoot_t * PI) * 0.7 * dr
		draw_line(sh_tail, sh_head, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, sh_a), 2.0, true)
		draw_circle(sh_head, 2.6, Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, sh_a))

	# Background trees (with reactive sway) — alpha = decor_reveal (boot : décor caché en gros plan yeux)
	_tree(Vector2(w * 0.12 + _tree_sway * 0.8, h), h * 0.74, w, dr)
	_tree(Vector2(w * 0.27 + _tree_sway * 0.5, h), h * 0.60, w, dr)
	_tree(Vector2(w * 0.80 - _tree_sway * 0.5, h), h * 0.66, w, dr)
	_tree(Vector2(w * 0.91 - _tree_sway * 0.8, h), h * 0.78, w, dr)

	# Menhir
	_menhir(Vector2(w * 0.66, h * 0.46), Vector2(w * 0.052, h * 0.40), dr)

	# Thinking mote
	if _thinking and _animated:
		var menhir_c: Vector2 = Vector2(w * 0.686, h * 0.66)
		var mote: Vector2 = menhir_c + Vector2(cos(_t * 2.2) * w * 0.045, sin(_t * 2.2) * h * 0.10)
		draw_circle(mote, maxf(minf(w, h) * 0.008, 2.5), Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, dr))

	# Figure — supprimée en mode œil-lune (in-game) : la présence de Merlin EST l'œil dans la lune ;
	# la silhouette encapuchonnée occulterait les yeux (v10.20, capture QA).
	if not _watch_eyes and (_beat == "Rencontre" or _beat == "Climax" or _beat == "Dilemme"):
		_figure(Vector2(w * 0.5, h * 0.84), h * 0.50, w * 0.075)

	# (v10.21 — la silhouette du pilier est dessinée APRÈS la brume : présence au premier plan, jamais délavée.)

	# 18 ambient motes (3 categories: firefly/dust/ember)
	if _animated:
		var mcount: int = int(MerlinVisual.MOTE_COUNT_AMBIENT * _mote_density)  # v10.18 : densité pilotée
		var mote_col: Color = MerlinVisual.GOLD.lerp(_faction_accent, _faction_mote_f)  # Wave C : motes teintées faction
		for mi in mcount:
			var mf: float = float(mi)
			var cat: int = mi % 3
			var base_x: float = w * fmod(mf * 0.618 + 0.1, 1.0)
			var base_y: float
			var mr: float
			var speed: float
			var ma: float
			match cat:
				0:
					base_y = h * (0.15 + 0.25 * fmod(mf * 0.382, 1.0))
					mr = maxf(minf(w, h) * 0.003, 1.5)
					speed = 0.12 + mf * 0.03
					var flicker: float = sin(_t * (2.5 + mf * 0.7) + mf * 3.1)
					ma = 0.08 + 0.14 * maxf(flicker, 0.0)
				1:
					base_y = h * (0.40 + 0.25 * fmod(mf * 0.271, 1.0))
					mr = maxf(minf(w, h) * 0.005, 2.0)
					speed = 0.20 + mf * 0.02
					ma = lerpf(0.10, 0.18, fmod(mf * 0.5, 1.0)) * (0.6 + 0.4 * sin(_t * 0.45 + mf))
				_:
					base_y = h * (0.70 + 0.20 * fmod(mf * 0.437, 1.0))
					mr = maxf(minf(w, h) * 0.007, 2.5)
					speed = 0.08 + mf * 0.015
					ma = lerpf(0.14, 0.26, fmod(mf * 0.3, 1.0)) * (0.5 + 0.5 * sin(_t * 0.3 + mf * 1.9))
			var mx: float = base_x + sin(_t * speed + mf * 1.7) * w * 0.030
			var my: float = base_y + cos(_t * (speed * 0.7) + mf * 2.3) * h * 0.020
			if cat == 1:
				mx += _t * 0.8
				mx = fmod(mx, w)
			if rm:
				ma *= 0.5
			# v10.21 — RE-SKIN de ≤8 motes pendant la présence du pilier (spec panel : zéro nouvel émetteur) :
			# Chœur = vertes ASCENDANTES · Être = bleues d'outre-monde · Chevalier = braises · Compagnon =
			# violettes basses · Enfant = crème. Les 10 autres motes gardent l'ambre ambiant.
			var mc2: Color = mote_col
			if _pilier_reveal > 0.5 and mi < 8:
				match _pilier_key:
					"choeur":
						mc2 = MerlinVisual.GREEN
						my -= fmod(_t * 9.0 + mf * 37.0, h * 0.22)
					"etre":
						mc2 = MerlinVisual.RARE_BLUE
					"chevalier":
						mc2 = MerlinVisual.GOLD.lerp(MerlinVisual.INK, 0.25)
					"compagnon":
						mc2 = MerlinVisual.VIOLET
						my = minf(my + h * 0.10, h * 0.86)
					"enfant":
						mc2 = MerlinVisual.CREAM
			draw_circle(Vector2(mx, my) + _parallax, mr, Color(mc2.r, mc2.g, mc2.b, ma * dr))

	# v10.18 — Lucioles (nuit / crépuscule, menu) : 12 points vert-or qui dérivent et clignotent
	# (blink piqué via pow). Distinctes des motes ambrées : plus vertes, halo, parmi les arbres.
	if _menu_decor and _fireflies and _animated:
		var fcol: Color = _season_fly_col  # v10.18 : teinte des lucioles selon la saison
		var fcount: int = int(round(12.0 * _season_fly_mult))  # densité saisonnière (hiver ~5, été 12)
		for fi in fcount:
			var ff: float = float(fi)
			var fpx: float = w * (0.42 + 0.55 * fmod(ff * 0.618 + 0.2, 1.0)) + sin(_t * (0.28 + ff * 0.04) + ff) * w * 0.018
			var fpy: float = h * (0.42 + 0.46 * fmod(ff * 0.382 + 0.1, 1.0)) + cos(_t * (0.22 + ff * 0.03) + ff * 1.3) * h * 0.028
			var blink: float = 0.5 + 0.5 * sin(_t * (1.6 + ff * 0.27) + ff * 2.1)
			var fa: float = (0.08 + 0.55 * pow(blink, 3.0)) * dr
			if rm:
				fa *= 0.5
			var fr: float = maxf(minf(w, h) * 0.0045, 2.0)
			draw_circle(Vector2(fpx, fpy), fr * 2.2, Color(fcol.r, fcol.g, fcol.b, fa * 0.22))
			draw_circle(Vector2(fpx, fpy), fr, Color(fcol.r, fcol.g, fcol.b, fa))

	# v10.21 — SOL en 2 ondulations SUPERPOSÉES (profondeur) + touffes d'herbe animées sur la crête.
	if _animated:
		var gnd_col: Color = COL_SIL.lerp(_season_sol, _season_sol_f)  # accent sol saisonnier (subtil)
		var band_specs: Array = [
			{"y": 0.855, "amp": 0.016, "ph": 0.0, "a": 0.20, "spd": 0.07},
			{"y": 0.885, "amp": 0.022, "ph": 2.1, "a": 0.38, "spd": 0.11},
		]
		var front_crest: PackedVector2Array = PackedVector2Array()
		for bspec in band_specs:
			var gnd_pts: PackedVector2Array = PackedVector2Array()
			var gnd_steps: int = 20
			for gi in gnd_steps + 1:
				var gx: float = float(gi) / float(gnd_steps) * w
				var gy: float = h * float(bspec["y"]) \
					+ sin(gx * 0.010 + _t * float(bspec["spd"]) + float(bspec["ph"])) * h * float(bspec["amp"]) \
					+ sin(gx * 0.031 + float(bspec["ph"]) * 2.0) * h * float(bspec["amp"]) * 0.4
				gnd_pts.append(Vector2(gx, gy))
			if bspec == band_specs[1]:
				front_crest = gnd_pts.duplicate()
			gnd_pts.append(Vector2(w, h))
			gnd_pts.append(Vector2(0.0, h))
			var gnd_a: float = float(bspec["a"]) * dr * (0.5 if rm else 1.0)
			draw_colored_polygon(gnd_pts, Color(gnd_col.r, gnd_col.g, gnd_col.b, gnd_a))
		# Touffes d'herbe : éventails de 3 brins sur la crête avant, sway par touffe (déterministe).
		if not front_crest.is_empty():
			var g_a: float = 0.55 * dr * (0.5 if rm else 1.0)
			var g_col: Color = Color(gnd_col.r, gnd_col.g, gnd_col.b, g_a)
			for ti in 9:
				var tf: float = float(ti)
				var ci: int = clampi(int(fmod(tf * 0.618 + 0.07, 1.0) * 20.0), 0, front_crest.size() - 1)
				var root: Vector2 = front_crest[ci]
				var g_h: float = h * (0.020 + fmod(tf * 0.37, 0.014))
				var lean: float = 0.0 if rm else sin(_t * (0.8 + fmod(tf, 0.5)) + tf * 2.2) * g_h * 0.35
				for bl2 in 3:
					var spread: float = (float(bl2) - 1.0) * g_h * 0.45
					draw_line(root, root + Vector2(spread + lean, -g_h * (0.75 + 0.25 * float(bl2 == 1))), g_col, 1.5, true)

	# v10.21 — BRUME en RUBANS ondulants (bords sinueux, dérive continue) — fini les rects plats.
	var mist_layers: Array = [
		{"y": 0.55, "speed": 0.12, "alpha": 0.10, "width": 0.58, "th": 0.030},
		{"y": 0.66, "speed": 0.18, "alpha": 0.14, "width": 0.64, "th": 0.038},
		{"y": 0.78, "speed": 0.25, "alpha": 0.18, "width": 0.70, "th": 0.046},
	]
	for li in mist_layers.size():
		var ml: Dictionary = mist_layers[li]
		var alpha: float = float(ml["alpha"]) * _mist_factor * dr * (0.5 if rm else 1.0)
		if alpha <= 0.004:
			continue
		var m_w: float = w * float(ml["width"])
		var m_x: float = w * 0.5 - m_w * 0.5
		var m_y: float = h * float(ml["y"])
		var m_th: float = h * float(ml["th"])
		var drift: float = (_t * float(ml["speed"])) if _animated else 0.0
		var seg: int = 14
		var ribbon: PackedVector2Array = PackedVector2Array()
		for si2 in seg + 1:  # bord SUPÉRIEUR sinueux (2 ondes superposées, dérive lente)
			var fx: float = float(si2) / float(seg)
			var px: float = m_x + fx * m_w
			var wob: float = sin(fx * 6.0 + drift + float(li) * 2.1) * m_th * 0.45 \
				+ sin(fx * 13.0 - drift * 1.7) * m_th * 0.20
			ribbon.append(Vector2(px, m_y + wob))
		for si3 in seg + 1:  # bord INFÉRIEUR sinueux (retour, phase décalée)
			var fx2: float = 1.0 - float(si3) / float(seg)
			var px2: float = m_x + fx2 * m_w
			var wob2: float = sin(fx2 * 5.0 - drift * 0.8 + float(li)) * m_th * 0.35
			ribbon.append(Vector2(px2, m_y + m_th + wob2))
		draw_colored_polygon(ribbon, Color(COL_MIST.r, COL_MIST.g, COL_MIST.b, alpha))
		# (QA v10.21 : le « cœur » rectangulaire créait des coutures droites — retiré, le ruban seul suffit.)

	# v10.21 — SILHOUETTE DU PNJ PILIER : dessinée APRÈS la brume (premier plan, jamais délavée — QA probe).
	if _pilier_reveal > 0.01:
		_draw_pilier(w, h, dr)

	# v10.21 — FEUILLES qui tombent (quads tournoyants, couleur saison ; hiver = flocons crème ronds).
	if _animated and not _leaves.is_empty():
		var winter: bool = _season_key == "hiver"
		var leaf_col: Color = (MerlinVisual.CREAM if winter else _season_leaf.lerp(MerlinVisual.GOLD, 0.25))
		for lf2 in _leaves:
			var lp2: Vector2 = Vector2(float((lf2["p"] as Vector2).x) * w, float((lf2["p"] as Vector2).y) * h) + _parallax * 0.8
			var l_a: float = 0.42 * dr * (0.5 if rm else 1.0)
			var lsz: float = maxf(minf(w, h) * 0.006, 2.4) * float(lf2["size"])
			if winter:
				draw_circle(lp2, lsz * 0.6, Color(leaf_col.r, leaf_col.g, leaf_col.b, l_a))
			else:
				var spin: float = _t * (1.2 + float(lf2["phase"]) * 0.15) + float(lf2["phase"])
				var ca2: float = cos(spin)
				var sa2: float = sin(spin)
				draw_colored_polygon(PackedVector2Array([
					lp2 + Vector2(ca2, sa2) * lsz, lp2 + Vector2(-sa2, ca2) * lsz * 0.5,
					lp2 + Vector2(-ca2, -sa2) * lsz, lp2 + Vector2(sa2, -ca2) * lsz * 0.5,
				]), Color(leaf_col.r, leaf_col.g, leaf_col.b, l_a))

	# v10.21 — OISEAU furtif : petit vol de chevrons qui bat des ailes en traversant le ciel.
	if _animated and _bird_t >= 0.0 and _bird_t <= 1.0 and not rm:
		var bx2: float = lerpf(-0.06, 1.06, _bird_t if _bird_dir > 0.0 else 1.0 - _bird_t) * w
		var by2: float = _bird_y * h + sin(_bird_t * 9.0) * h * 0.012
		var b_a: float = sin(_bird_t * PI) * 0.5 * dr
		var b_col: Color = Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, b_a)
		for bi2 in _bird_flock:
			var bo: Vector2 = Vector2(bx2 - float(bi2) * 14.0 * _bird_dir, by2 + float(bi2) * 6.0)
			var flap: float = sin(_t * 7.0 + float(bi2) * 1.7) * 3.0
			var wing: float = 5.0
			draw_line(bo, bo + Vector2(-wing * _bird_dir, -2.5 - flap), b_col, 1.6, true)
			draw_line(bo, bo + Vector2(wing * _bird_dir, -2.5 + flap), b_col, 1.6, true)

	# Foreground silhouettes (2 edge trees, slow drift)
	if _animated:
		var fg_a: float = 0.12
		if rm:
			fg_a = 0.08
		var fg_drift: float = 0.0
		if not rm:
			fg_drift = sin(_t * 0.06) * w * 0.008
		_tree(Vector2(w * 0.02 - fg_drift, h), h * 0.90, w, fg_a * dr)
		_tree(Vector2(w * 0.97 + fg_drift, h), h * 0.85, w, fg_a * dr)

	# v10.18 (menu) — aura douce qui suit le curseur : 3 cercles GOLD très discrets (off en reduced_motion).
	if _animated and _cursor_inside and not rm:
		for ck in 3:
			var aura_r: float = minf(w, h) * 0.045 * (1.0 + float(ck) * 0.9)
			var aura_a: float = (0.05 / (float(ck) + 1.0)) * dr
			draw_circle(_cursor_pos, aura_r, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, aura_a))

	# Menu decor — v10.21 : TERTRES organiques (fini les rects plats à couleurs en dur, violation DA §20).
	if _menu_decor:
		var drift: float = sin(_t * 0.16) * w * 0.012 if _animated else 0.0
		var mounds: Array = [
			{"x0": -0.02, "x1": 0.46, "y": 0.815, "amp": 0.020, "col": MerlinVisual.GREEN, "off": drift},
			{"x0": 0.56, "x1": 1.02, "y": 0.855, "amp": 0.024, "col": MerlinVisual.VIOLET, "off": -drift},
		]
		for mo in mounds:
			var m_pts: PackedVector2Array = PackedVector2Array()
			var m_seg: int = 12
			var crest_y: float = h * float(mo["y"]) - h * float(mo["amp"]) * 3.0
			for msi in m_seg + 1:
				var mf: float = float(msi) / float(m_seg)
				var mx2: float = lerpf(float(mo["x0"]), float(mo["x1"]), mf) * w + float(mo["off"])
				var dome: float = sin(mf * PI)  # 0 aux bords → 1 au centre
				# QA v10.21 : le profil DESCEND SOUS l'écran aux extrémités (h*1.02) → vraie colline,
				# plus de murs verticaux aux bords du polygone.
				var my2: float = lerpf(h * 1.02, crest_y, dome) - sin(mf * 9.0 + _t * 0.2) * h * 0.004
				m_pts.append(Vector2(mx2, my2))
			m_pts.append(Vector2(lerpf(float(mo["x0"]), float(mo["x1"]), 1.0) * w + float(mo["off"]), h * 1.04))
			m_pts.append(Vector2(float(mo["x0"]) * w + float(mo["off"]), h * 1.04))
			var m_col: Color = mo["col"]
			draw_colored_polygon(m_pts, Color(m_col.r, m_col.g, m_col.b, 0.16 * dr))
		var star_i: int = 0
		for sp in [Vector2(0.40, 0.18), Vector2(0.62, 0.28), Vector2(0.72, 0.50), Vector2(0.30, 0.40)]:
			var a: float = 1.0
			if _animated:
				a = 0.40 + 0.60 * (0.5 + 0.5 * sin(_t * 1.1 + float(star_i) * 1.9))
			_star(Vector2(w * sp.x, h * sp.y), maxf(minf(w, h) * 0.010, 2.5), a * dr)
			star_i += 1


func _star(p: Vector2, rr: float, alpha: float = 1.0) -> void:
	var col: Color = Color(COL_MOON.r, COL_MOON.g, COL_MOON.b, alpha)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0.0, -rr), p + Vector2(rr * 0.5, 0.0), p + Vector2(0.0, rr), p + Vector2(-rr * 0.5, 0.0)]), col)


# v10.21 — Arbre ORGANIQUE (user : « moins design HTML ») : tronc GALBÉ en polygone effilé avec courbe
# en S, 2 branches maîtresses effilées, CANOPÉE en masses sombres qui respirent + sway idle propre à
# chaque arbre (déterministe : seedé par base.x — zéro randf en _draw). Signature INCHANGÉE (6 appelants).
func _tree(base: Vector2, height: float, w_ref: float, alpha: float = 1.0) -> void:
	var col: Color = COL_SIL if alpha >= 1.0 else Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, alpha)
	var tseed: float = fmod(absf(base.x) * 0.137, TAU)  # variation par arbre, stable d'une frame à l'autre
	var rm2: bool = MerlinVisual.reduced_motion
	var idle: float = 0.0 if rm2 else sin(_t * (0.22 + fmod(tseed, 0.13)) + tseed) * height * 0.012
	var swy: float = idle + _tree_sway * 0.35
	var top: Vector2 = base + Vector2(swy * 2.2, -height)
	var t_w: float = maxf(w_ref * 0.010, 3.0)
	var mid: Vector2 = base.lerp(top, 0.5) + Vector2(sin(tseed * 3.7) * height * 0.04 + swy, 0.0)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-t_w * 2.4, 0.0), base + Vector2(t_w * 2.4, 0.0),
		mid + Vector2(t_w * 1.2, 0.0), top + Vector2(t_w * 0.55, 0.0),
		top + Vector2(-t_w * 0.55, 0.0), mid + Vector2(-t_w * 1.2, 0.0),
	]), col)
	for bi in 2:
		var b_side: float = 1.0 if bi == 0 else -1.0
		var bp: Vector2 = base.lerp(top, 0.58 + 0.16 * float(bi)) + Vector2(swy, 0.0)
		var tip: Vector2 = bp + Vector2(b_side * height * (0.20 - 0.05 * float(bi)), -height * 0.16)
		draw_colored_polygon(PackedVector2Array([
			bp + Vector2(0.0, -t_w * 0.9), tip, bp + Vector2(0.0, t_w * 0.9)]), col)
	# Canopée : 5 masses sombres agglomérées, respiration douce (phase par blob).
	var crown: Vector2 = top + Vector2(swy * 1.5, height * 0.06)
	var cr: float = height * 0.16
	for k in 5:
		var kf: float = float(k)
		var ang: float = tseed + kf * 1.256
		var breathe: float = 0.0 if rm2 else sin(_t * 0.5 + tseed + kf) * cr * 0.06
		var bc: Vector2 = crown + Vector2(cos(ang) * cr * (0.9 + fmod(kf * 0.31, 0.5)), sin(ang) * cr * 0.55 - cr * 0.25 + breathe)
		draw_circle(bc, cr * (0.55 + fmod(kf * 0.27, 0.35)), col)
	# Feuillage saisonnier : petits accents colorés DANS les masses de la canopée (QA v10.21 : les gros
	# pois flottaient hors couronne → rayon réduit, nombre doublé, positions calées sur les blobs sombres).
	if _season_leaf_a > 0.001 and alpha > 0.01:
		var leaf_a: float = _season_leaf_a * alpha * 0.85 * (0.7 if rm2 else 1.0)
		var lc: Color = Color(_season_leaf.r, _season_leaf.g, _season_leaf.b, leaf_a)
		var br: float = _season_blob_r * w_ref * 0.75
		for k2 in _season_blobs * 6:
			var kf2: float = float(k2)
			var ang2: float = tseed * 1.3 + kf2 * 0.897
			var rad2: float = cr * (0.35 + fmod(kf2 * 0.43, 0.55))  # DANS la couronne (0.35-0.90 × cr)
			var lp: Vector2 = crown + Vector2(cos(ang2) * rad2, sin(ang2) * rad2 * 0.55 - cr * 0.25)
			draw_circle(lp, br * (0.7 + fmod(kf2 * 0.29, 0.5)), lc)


# v10.21 — Les 5 silhouettes de PILIERS (spec panel) : formes DISTINCTES par nature, deux rampes d'alpha
# (corps 0→0.70 de reveal, détails accent 0.40→1.0), bob idle léger, tailles hiérarchisées (Être le seul
# plus grand que les arbres proches, désaxé — inquiétant ; Enfant demi-taille).
func _draw_pilier(w: float, h: float, dr: float) -> void:
	var accent: Color = MerlinVisual.GOLD
	match _pilier_key:
		"choeur": accent = MerlinVisual.GREEN
		"etre": accent = MerlinVisual.RARE_BLUE
		"chevalier": accent = MerlinVisual.GOLD.lerp(MerlinVisual.DIM_WARM, 0.45)
		"compagnon": accent = MerlinVisual.VIOLET
		"enfant": accent = MerlinVisual.CREAM
	var col_base: Color = COL_SIL.lerp(accent, 0.35)  # QA probe : accent renforcé (identité lisible)
	var a_body: float = clampf(_pilier_reveal / 0.70, 0.0, 1.0) * dr
	var a_det: float = clampf((_pilier_reveal - 0.40) / 0.60, 0.0, 1.0) * dr
	if a_body <= 0.01:
		return
	var rm3: bool = MerlinVisual.reduced_motion
	var bob: float = 0.0 if rm3 else sin(_t * 0.9) * h * 0.004
	# QA probe : x=0.345 — la clairière entre l'arbre de gauche (0.27) et le sentier de la lune (0.5) ;
	# à 0.22 la silhouette était coincée entre deux troncs.
	var feet: Vector2 = Vector2(w * 0.345, h * 0.868 + bob)
	var body: Color = Color(col_base.r, col_base.g, col_base.b, a_body)
	var det: Color = Color(accent.r, accent.g, accent.b, a_det * 0.85)
	match _pilier_key:
		"choeur":  # druide : robe droite + bâton surmonté d'une lueur
			var eh: float = h * 0.22
			var hw2: float = eh * 0.16
			draw_colored_polygon(PackedVector2Array([
				feet + Vector2(-hw2, 0.0), feet + Vector2(hw2, 0.0),
				feet + Vector2(hw2 * 0.55, -eh * 0.78), feet + Vector2(-hw2 * 0.55, -eh * 0.78)]), body)
			draw_circle(feet + Vector2(0.0, -eh * 0.88), hw2 * 0.62, body)  # capuche
			var staff_x: float = feet.x + hw2 * 1.7
			draw_line(Vector2(staff_x, feet.y), Vector2(staff_x, feet.y - eh * 1.05), body, 3.0, true)
			draw_circle(Vector2(staff_x, feet.y - eh * 1.10), hw2 * 0.34, det)  # lueur du bâton
		"etre":  # trop grand, trop fin, désaxé — la forêt qui marche
			var eh2: float = h * 0.30
			var lean2: float = eh2 * 0.105  # ~6°
			var hw3: float = eh2 * 0.055
			draw_colored_polygon(PackedVector2Array([
				feet + Vector2(-hw3 * 1.6, 0.0), feet + Vector2(hw3 * 1.6, 0.0),
				feet + Vector2(hw3 + lean2, -eh2 * 0.86), feet + Vector2(-hw3 + lean2, -eh2 * 0.86)]), body)
			draw_circle(feet + Vector2(lean2 * 1.15, -eh2 * 0.93), hw3 * 2.1, body)  # tête trop petite, décalée
			for e_i in 2:  # deux lueurs d'yeux (froides)
				draw_circle(feet + Vector2(lean2 * 1.15 + (float(e_i) - 0.5) * hw3 * 1.6, -eh2 * 0.94), 1.8, det)
		"chevalier":  # large, tête baissée, épée pointe au sol
			var eh3: float = h * 0.20
			var hw4: float = eh3 * 0.26
			draw_colored_polygon(PackedVector2Array([
				feet + Vector2(-hw4, 0.0), feet + Vector2(hw4, 0.0),
				feet + Vector2(hw4 * 0.72, -eh3 * 0.72), feet + Vector2(-hw4 * 0.72, -eh3 * 0.72)]), body)
			draw_circle(feet + Vector2(hw4 * 0.18, -eh3 * 0.76), hw4 * 0.42, body)  # tête INCLINÉE vers l'avant
			var sw_x: float = feet.x - hw4 * 1.45
			draw_line(Vector2(sw_x, feet.y - eh3 * 0.52), Vector2(sw_x, feet.y), det, 2.5, true)  # lame plantée
			draw_line(Vector2(sw_x - hw4 * 0.34, feet.y - eh3 * 0.52), Vector2(sw_x + hw4 * 0.34, feet.y - eh3 * 0.52), body, 3.0, true)  # garde
		"compagnon":  # humain, main tendue vers le centre
			var eh4: float = h * 0.19
			var hw5: float = eh4 * 0.14
			draw_colored_polygon(PackedVector2Array([
				feet + Vector2(-hw5, 0.0), feet + Vector2(hw5, 0.0),
				feet + Vector2(hw5 * 0.6, -eh4 * 0.74), feet + Vector2(-hw5 * 0.6, -eh4 * 0.74)]), body)
			draw_circle(feet + Vector2(0.0, -eh4 * 0.84), hw5 * 0.72, body)
			var sh: Vector2 = feet + Vector2(hw5 * 0.5, -eh4 * 0.62)
			var hand: Vector2 = sh + Vector2(eh4 * 0.34, eh4 * 0.06)  # bras tendu vers la lune
			draw_line(sh, hand, body, 3.5, true)
			draw_circle(hand, 2.6, det)  # la main qui offre
		"enfant":  # demi-taille, grosse tête, petite étoile près de la main
			var eh5: float = h * 0.11
			var hw6: float = eh5 * 0.20
			draw_colored_polygon(PackedVector2Array([
				feet + Vector2(-hw6, 0.0), feet + Vector2(hw6, 0.0),
				feet + Vector2(hw6 * 0.62, -eh5 * 0.62), feet + Vector2(-hw6 * 0.62, -eh5 * 0.62)]), body)
			draw_circle(feet + Vector2(0.0, -eh5 * 0.80), hw6 * 1.05, body)  # tête proportionnellement grande
			var star_p: Vector2 = feet + Vector2(hw6 * 2.0, -eh5 * 0.42 + (0.0 if rm3 else sin(_t * 1.4) * 2.0))
			draw_colored_polygon(PackedVector2Array([
				star_p + Vector2(0.0, -4.0), star_p + Vector2(2.0, 0.0),
				star_p + Vector2(0.0, 4.0), star_p + Vector2(-2.0, 0.0)]), det)  # l'étoile qu'il « a trouvée »


# v10.21 — Menhir ORGANIQUE : pierre effilée légèrement penchée (polygone irrégulier) + mousse au pied.
# Les entailles ogham (trait vertical + 4 barres) demeurent — c'est sa signature.
func _menhir(pos: Vector2, dim: Vector2, alpha: float = 1.0) -> void:
	var stone: Color = COL_STONE if alpha >= 1.0 else Color(COL_STONE.r, COL_STONE.g, COL_STONE.b, COL_STONE.a * alpha)
	var ink: Color = COL_INK if alpha >= 1.0 else Color(COL_INK.r, COL_INK.g, COL_INK.b, COL_INK.a * alpha)
	var lean: float = dim.x * 0.16  # penché vers la lune (ancienneté)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(dim.x * 0.08, dim.y),                       # pied gauche
		pos + Vector2(-dim.x * 0.06 + lean, dim.y * 0.42),        # flanc gauche renflé
		pos + Vector2(dim.x * 0.16 + lean, dim.y * 0.06),         # épaule gauche
		pos + Vector2(dim.x * 0.62 + lean, 0.0),                  # sommet arrondi (facette)
		pos + Vector2(dim.x * 0.98 + lean, dim.y * 0.14),         # épaule droite
		pos + Vector2(dim.x * 1.04, dim.y * 0.55),                # flanc droit
		pos + Vector2(dim.x * 0.92, dim.y),                       # pied droit
	]), stone)
	var cx: float = pos.x + dim.x * 0.5 + lean * 0.5
	var y0: float = pos.y + dim.y * 0.20
	var y1: float = pos.y + dim.y * 0.82
	draw_line(Vector2(cx, y0), Vector2(cx, y1), ink, 2.0, true)
	var tick: float = dim.x * 0.38
	for i in 4:
		var ty: float = lerpf(y0, y1, float(i + 1) / 5.0)
		draw_line(Vector2(cx - tick, ty), Vector2(cx + tick, ty), ink, 2.0, true)
	# Mousse au pied (accent GREEN canon, discret — la forêt reprend la pierre).
	var moss: Color = MerlinVisual.GREEN
	draw_circle(pos + Vector2(dim.x * 0.22, dim.y * 0.97), dim.x * 0.20, Color(moss.r, moss.g, moss.b, 0.22 * alpha))
	draw_circle(pos + Vector2(dim.x * 0.70, dim.y * 1.00), dim.x * 0.26, Color(moss.r, moss.g, moss.b, 0.16 * alpha))


func _figure(base_in: Vector2, height: float, half_w: float) -> void:
	# v10.18 — Merlin FLOTTE (menu) : bob vertical + sway horizontal smooth via _t. In-game inchangé.
	# v10.21 (goal) — MERLIN plus DÉTAILLÉ et VIVANT, toujours simpliste/flat : ombre au sol, ourlet de
	# cape ONDULANT, capuche en pointe, BÂTON à orbe qui pulse avec le halo, étincelles runiques en orbite.
	var menu: bool = _menu_decor and _animated and not MerlinVisual.reduced_motion
	var fx: float = (sin(_t * 0.55) * half_w * 0.10) if menu else 0.0
	var fy: float = (sin(_t * 0.80) * height * 0.018) if menu else 0.0
	# Matérialisation : la figure monte un peu en se formant + alpha par COUCHE (cape → tête → yeux).
	var base: Vector2 = base_in + Vector2(fx, fy + (1.0 - _fig_reveal) * height * 0.10)
	var a_cloak: float = clampf(_fig_reveal / 0.45, 0.0, 1.0)
	var a_head: float = clampf((_fig_reveal - 0.40) / 0.30, 0.0, 1.0)
	var a_eyes: float = clampf((_fig_reveal - 0.65) / 0.35, 0.0, 1.0)
	var top: float = base.y - height
	var shoulder: float = base.y - height * 0.62
	# Ombre au sol : flaque elliptique douce sous la cape (l'ancre au monde — il FLOTTE au-dessus).
	var sh_c: Vector2 = Vector2(base_in.x, base_in.y + height * 0.015)
	var sh_pts: PackedVector2Array = PackedVector2Array()
	for shi in 10:
		var sha: float = float(shi) / 10.0 * TAU
		sh_pts.append(sh_c + Vector2(cos(sha) * half_w * 1.15, sin(sha) * half_w * 0.22))
	draw_colored_polygon(sh_pts, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, 0.28 * a_cloak))
	# Cape à OURLET VIVANT : le bas ondule (3 points animés entre les deux coins).
	var hem_w: float = 0.0 if not menu else 1.0
	var cloak: PackedVector2Array = PackedVector2Array([
		Vector2(base.x - half_w * 0.45, top + height * 0.10),
		Vector2(base.x - half_w, base.y),
		Vector2(base.x - half_w * 0.5, base.y + sin(_t * 1.3 + 0.5) * height * 0.014 * hem_w),
		Vector2(base.x, base.y + sin(_t * 1.1 + 2.1) * height * 0.018 * hem_w),
		Vector2(base.x + half_w * 0.5, base.y + sin(_t * 1.4 + 4.2) * height * 0.014 * hem_w),
		Vector2(base.x + half_w, base.y),
		Vector2(base.x + half_w * 0.45, top + height * 0.10),
		Vector2(base.x + half_w * 0.30, shoulder),
		Vector2(base.x - half_w * 0.30, shoulder),
	])
	draw_colored_polygon(cloak, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, a_cloak))
	var head_c: Vector2 = Vector2(base.x, top + height * 0.06)
	var hr: float = half_w * 0.42
	draw_circle(head_c, hr, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, a_head))
	# Capuche en pointe (signature d'enchanteur, 1 triangle).
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(-hr * 0.9, -hr * 0.25), head_c + Vector2(hr * 0.15, -hr * 1.55),
		head_c + Vector2(hr * 0.95, -hr * 0.10)]), Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, a_head))
	# BÂTON : hampe légèrement inclinée à sa droite + ORBE d'or qui pulse avec le halo de la lune.
	var staff_top: Vector2 = Vector2(base.x + half_w * 1.30, top - height * 0.06)
	var staff_bot: Vector2 = Vector2(base.x + half_w * 1.05, base.y)
	draw_line(staff_bot, staff_top, Color(COL_SIL.r, COL_SIL.g, COL_SIL.b, a_head), maxf(half_w * 0.07, 2.5), true)
	var orb_pulse: float = 0.5 + 0.5 * sin(_halo_phase) if _animated else 1.0
	var orb_a: float = (0.45 + 0.35 * orb_pulse) * a_eyes
	draw_circle(staff_top, half_w * 0.30, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, orb_a * 0.25))
	draw_circle(staff_top, half_w * 0.16, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, orb_a))
	# Étincelles runiques : 3 poussières d'or en orbite lente autour de lui (vivant, discret).
	if menu and a_eyes > 0.3:
		for rs in 3:
			var ra: float = _t * (0.35 + float(rs) * 0.11) + float(rs) * 2.09
			var rp: Vector2 = Vector2(base.x, shoulder) + Vector2(cos(ra) * half_w * 1.55, sin(ra) * height * 0.30)
			var rs_a: float = (0.25 + 0.30 * (0.5 + 0.5 * sin(_t * 1.8 + float(rs) * 2.0))) * a_eyes
			draw_circle(rp, 1.8, Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, rs_a))
	# v10.18 — Yeux MERLIN (menu) : 2 BARRES BLEUES VERTICALES lumineuses + lueur qui pulse (signature,
	# user 2026-06-29). S'ALLUMENT EN DERNIER dans la matérialisation (a_eyes : grandissent + s'éclairent).
	# v10.20 — en mode « œil-lune » (set_watch_eyes), les yeux vivent dans la LUNE (dessinés en _draw) :
	# on ne les dessine PAS aussi sur la tête (anti-doublon) et on NE touche PAS _fig_head (la lune l'a posé).
	if _menu_decor and not _watch_eyes:
		_fig_head = head_c  # lu par _update_merlin_gaze (frame suivante) pour viser la souris
		_fig_hr = hr
		_draw_eyes(head_c, hr, a_eyes)


# v10.20 — Rendu des YEUX (2 barres bleues + humeur + gaze + lueur + sourcils colère) à un CENTRE et un
# RAYON donnés. Appelé par _figure (à la tête) ET par le mode œil-lune (set_watch_eyes, centre de la lune).
func _draw_eyes(center: Vector2, hr: float, a_eyes: float) -> void:
	if a_eyes <= 0.01:
		return
	var pulse: float = (0.62 + 0.38 * (0.5 + 0.5 * sin(_t * 1.7))) if (_animated and not MerlinVisual.reduced_motion) else 1.0
	var eye_col: Color = MerlinVisual.EYE_NEUTRAL
	var mood_glow: float = 1.0
	var mood_widen: float = 1.0
	match _eye_mood:
		"surprise":
			eye_col = MerlinVisual.EYE_SURPRISE
			mood_glow = 1.5
			mood_widen = 1.12
		"angry":
			eye_col = MerlinVisual.EYE_ANGRY
			mood_glow = 1.35
			mood_widen = 0.90  # les yeux se plissent en colère
	var openf: float = _eye_open_force if _eye_open_force >= 0.0 else maxf(1.0 - 0.9 * _blink, 0.07)
	var widen: float = _eye_widen * mood_widen
	var eye_h: float = hr * 0.70 * openf * a_eyes * widen
	var eye_w: float = maxf(hr * 0.16, 2.0)
	var eye_dx: float = hr * 0.34 * widen
	var gaze_px: Vector2 = _gaze * (hr * 0.22)  # le REGARD décale les barres (suit la souris / ailleurs)
	var core_a: float = minf(0.9 * pulse * a_eyes * _eye_glow * mood_glow, 1.0)
	var halo_a: float = minf(0.16 * pulse * a_eyes * _eye_glow * mood_glow, 0.7)
	for s in [-1.0, 1.0]:
		var ec2: Vector2 = Vector2(center.x + s * eye_dx, center.y) + gaze_px
		var ey: float = ec2.y - eye_h * 0.5
		draw_circle(ec2, eye_w * 2.4, Color(eye_col.r, eye_col.g, eye_col.b, halo_a))
		draw_rect(Rect2(ec2.x - eye_w * 0.5, ey, eye_w, eye_h), Color(eye_col.r, eye_col.g, eye_col.b, core_a), true)
		draw_circle(Vector2(ec2.x, ey), eye_w * 0.5, Color(eye_col.r, eye_col.g, eye_col.b, core_a))
		draw_circle(Vector2(ec2.x, ey + eye_h), eye_w * 0.5, Color(eye_col.r, eye_col.g, eye_col.b, core_a))
	if _eye_mood == "angry":
		var brow_y: float = center.y - eye_h * 0.62
		var brow_col: Color = Color(eye_col.r, eye_col.g, eye_col.b, core_a)
		for s2 in [-1.0, 1.0]:
			var inner: Vector2 = Vector2(center.x + s2 * eye_dx * 0.50, brow_y + hr * 0.12)
			var outer: Vector2 = Vector2(center.x + s2 * eye_dx * 1.35, brow_y - hr * 0.10)
			draw_line(inner, outer, brow_col, maxf(eye_w * 0.75, 2.0), true)
