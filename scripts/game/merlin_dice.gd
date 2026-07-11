class_name MerlinDice
extends Control
## v2-W4 (user 2026-07-05) — DÉ d20 : culbute (nombres 1-20 qui défilent + squash/rotation fausse-3D)
## → ralenti → pose sur la face PRÉ-TIRÉE, avec HALO à la pose : VERT sourd si le jet réussit
## (success), ROUGE sourd sinon. La face porte un GROS chiffre 1-20 centré (charte gravure). Le liseré
## de rareté / le flash d'or (die_mod) sont SUPPRIMÉS du rendu de jet : le halo binaire success/échec
## remplace « le sort a souri » (die_mod devenu inerte, §K). Le silhouette icosaédrique (hexagone
## fausse-3D + arêtes) donne le « feel » d20 sans coût de vraie 3D.
## Tout procédural (_draw), palette canon, durées ×motion(), reduced_motion = face finale directe.
##
## Le mode INDICE statique (hint()/set_hint_rarity()) et rim_for_rarity() restent INCHANGÉS :
## MerlinActionView s'en sert pour le liseré de tuile (langage R133) — indépendant du jet.

signal done

const SIZE_PX: float = 96.0
# v11-W1 (spec panel) : dé COMPRESSÉ ~1,15 s total (vs 2,10 s) — il se lance en chevauchement sur la
# décrue de fusion (MerlinFx.run Phase 3), la séquence complète reste lisible sans traîner.
const TUMBLE_S: float = 0.35     # phase 1 : culbute rapide
const SLOW_S: float = 0.40       # phase 2 : le défilement ralentit
const SETTLE_S: float = 0.25     # phase 3 : pose + rebond
# N4-P1 (chantier 2b) : micro-pause de LECTURE entre la pose (face visible) et le verdict
# (halo + stinger). Ordre dramatique : geste, puis de, puis pause, puis verdict. En x motion().
const PAUSE_READ_S: float = 0.35
# N4-P1 (chantier 7) : a l'eclatante uniquement, halo GOLD PROLONGE (celebration rare) : tenue
# supplementaire avant le fondu, APRES l'emission de done (jamais bloquant pour le flux).
const BRILLIANT_HOLD_S: float = 0.90

var _face: int = 1               # face AFFICHÉE (défile pendant la culbute, 1-20)
var _final_face: int = 1
var _success: bool = false       # issue du jet → couleur du halo à la pose
var _brilliant: bool = false     # N4-P1 (chantier 7) : éclatante → halo GOLD prolongé
var _on_verdict: Callable = Callable()  # N4-P1 (chantier 2b) : appelé À l'instant du halo (stinger)
var _rim: Color = MerlinVisual.BORDER_BRUN  # (mode INDICE uniquement — liseré de rareté)
var _squash: Vector2 = Vector2.ONE
var _settled: bool = false
var _halo: float = 0.0           # 0-1 : intensité du halo à la pose (pulse)
var _static_mode: bool = false   # mode INDICE (près du bouton Résoudre) : face « ? », aucun roll


static func rim_for_rarity(rarity: String) -> Color:
	match rarity:
		"Rare": return MerlinVisual.RARE_BLUE
		"Épique": return MerlinVisual.RARITY_EPIC
		"Mythique": return MerlinVisual.GOLD
	return MerlinVisual.BORDER_BRUN


# Lance le d20 au-dessus du parent : culbute → ralenti → pose. `await dice.done` puis auto-fondu.
# `success` (issue FINALE du jet, §K) → halo VERT si réussi, ROUGE sinon. `final_face` clampé 1-20.
# N4-P1 : `brilliant` (chantier 7) = halo GOLD prolonge a l'eclatante ; `on_verdict` (chantier 2b)
# = Callable appelee A l'instant du halo (le stinger de degre joue LA, jamais avant la pause).
static func roll(parent: Control, final_face: int, success: bool,
		brilliant: bool = false, on_verdict: Callable = Callable()) -> MerlinDice:
	var d: MerlinDice = MerlinDice.new()
	d._final_face = clampi(final_face, 1, 20)
	d._success = success
	d._brilliant = brilliant
	d._on_verdict = on_verdict
	d.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	d.size = Vector2(SIZE_PX, SIZE_PX)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.z_index = 30
	parent.add_child(d)
	var vp: Vector2 = parent.get_viewport_rect().size
	# N4-BUG LOW : 0.34 posait le dé en plein MILIEU de l'encart de situation (il recouvrait la prose).
	# 0.19 = zone DÉCOR (grille v11-V2a @1080p : marge 16 + HUD env. 60-80 + sép 8, donc décor env.
	# y 90-290, encart dès y env. 292) : centre du dé vers 205. N4-P1 (chantier 2c, review MEDIUM-2) :
	# halo renforcé max = r x 1,75 soit env. 77 px, borné vers 282 : toujours AU-DESSUS de l'encart
	# (marge fine env. 9 px, vérifiée par capture probe_dice_capture). Ne pas re-grossir le halo
	# sans redescendre ce plafond ; le halo reste lisible sur le décor sombre.
	d.position = Vector2(vp.x * 0.5 - SIZE_PX * 0.5, vp.y * 0.19 - SIZE_PX * 0.5)
	d.pivot_offset = Vector2(SIZE_PX, SIZE_PX) * 0.5
	d._run()
	return d


# Mode INDICE statique (feedforward « ce choix jettera un dé ») : petite face « ? » au liseré de rareté.
static func hint(size_px: float = 26.0) -> MerlinDice:
	var d: MerlinDice = MerlinDice.new()
	d._static_mode = true
	d.custom_minimum_size = Vector2(size_px, size_px)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func set_hint_rarity(rarity: String) -> void:
	_rim = rim_for_rarity(rarity)
	queue_redraw()


func _run() -> void:
	var m: float = MerlinVisual.motion()
	if MerlinVisual.reduced_motion:
		# N4-P1 (chantier 2b, R148) : meme ORDRE degrade proprement : face posee NEUTRE, micro-pause
		# de lecture (x motion), PUIS verdict (halo statique + stinger via callback). Jamais de softlock.
		_face = _final_face
		_settled = true
		queue_redraw()
		await get_tree().create_timer(PAUSE_READ_S * m).timeout
		if not is_inside_tree():
			done.emit()  # v11-W1 (review CRITICAL) : sans lui, `await dice.done` dans MerlinFx = softlock
			return
		if _on_verdict.is_valid():
			_on_verdict.call()
		_halo = 1.0
		queue_redraw()
		await get_tree().create_timer(0.5).timeout
		done.emit()
		_fade_out()
		return
	MerlinAudio.play_sfx("card_pick", 0.7)  # petit claquement de lancer (recette existante, grave)
	# Phase 1+2 — culbute : les nombres 1-20 défilent (vite puis lentement), squash/rotation fausse-3D.
	var t0: int = Time.get_ticks_msec()
	var total_ms: int = int((TUMBLE_S + SLOW_S) * 1000.0 * m)
	var next_flip_ms: int = 0
	var flip_gap: float = 60.0
	modulate.a = 0.0
	var ain: Tween = create_tween()
	ain.tween_property(self, "modulate:a", 1.0, 0.18 * m)
	while Time.get_ticks_msec() - t0 < total_ms and is_inside_tree():
		var now: int = Time.get_ticks_msec() - t0
		var prog: float = float(now) / float(total_ms)
		if now >= next_flip_ms:
			flip_gap = lerpf(60.0, 240.0, prog * prog)  # le défilement RALENTIT (fausse inertie)
			next_flip_ms = now + int(flip_gap)
			var nf: int = randi_range(1, 20)
			_face = nf if nf != _face else (nf % 20) + 1
			MerlinAudio.play_sfx("slider_tick", 1.2 - prog * 0.4)
		rotation = sin(float(now) * 0.011) * (0.5 - prog * 0.42)          # bascule qui s'amortit
		_squash = Vector2(1.0 + sin(float(now) * 0.02) * (0.16 - prog * 0.13),
			1.0 - sin(float(now) * 0.02) * (0.16 - prog * 0.13))          # respiration fausse-3D
		queue_redraw()
		await get_tree().process_frame
	# Phase 3 — pose : face finale, rebond squash, halo success/échec.
	_face = _final_face
	_settled = true
	rotation = 0.0
	# v11-W1 (review) : plus de seal_stamp ici — 3 stamps quasi identiques se tassaient dans ~2 s
	# (impact de fusion + pose du dé + stinger de degré). La pose claque avec le son de lancer, grave.
	MerlinAudio.play_sfx("card_pick", 1.0)
	var settle: Tween = create_tween()
	settle.tween_method(func(v: float) -> void:
		_squash = Vector2(1.0 + 0.22 * (1.0 - v), 1.0 - 0.22 * (1.0 - v))
		queue_redraw(), 0.0, 1.0, SETTLE_S * m).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if settle.is_running():  # R148 : jamais d'await sur un tween deja fini
		await settle.finished
	# N4-P1 (chantier 2b) : micro-pause de LECTURE : la face posee se lit AVANT le verdict.
	# Pendant la pause, bordure et halo restent NEUTRES (_halo = 0, voir _draw) : rien ne spoile.
	await get_tree().create_timer(PAUSE_READ_S * m).timeout
	if not is_inside_tree():
		done.emit()  # R148 : le parent a pu mourir pendant la pause : jamais de softlock amont
		return
	# VERDICT : le stinger de degre joue ICI (callback merlin_game._play_seal_audio), en meme temps
	# que le halo. N4-P1 (chantier 2c) : halo RENFORCE (rayon/alpha ~x2) + 2 pulses PERSISTANTS.
	if _on_verdict.is_valid():
		_on_verdict.call()
	var halo_tw: Tween = create_tween()
	halo_tw.tween_method(_set_halo, 0.0, 1.0, 0.18 * m)
	halo_tw.tween_method(_set_halo, 1.0, 0.62, 0.30 * m)   # pulse 1
	halo_tw.tween_method(_set_halo, 0.62, 1.0, 0.30 * m)
	halo_tw.tween_method(_set_halo, 1.0, 0.62, 0.30 * m)   # pulse 2
	halo_tw.tween_method(_set_halo, 0.62, 0.85, 0.25 * m)  # repos haut : le verdict reste lisible
	await get_tree().create_timer(0.15 * m).timeout  # le flux repart des le verdict pose (+~0,35 s vs v11-W1)
	done.emit()
	# Queue de vie APRES done (fire-and-forget pour le flux) : les 2 pulses s'achevent, l'eclatante
	# tient BRILLIANT_HOLD_S de plus (chantier 7, celebration rare), puis fondu. Gardes R148.
	if halo_tw.is_running():
		await halo_tw.finished
	if _brilliant and is_inside_tree():
		await get_tree().create_timer(BRILLIANT_HOLD_S * m).timeout
	_fade_out()


# N4-P1 : setter du halo (tween_method) : une seule ecriture + redraw, reutilise par les pulses.
func _set_halo(v: float) -> void:
	_halo = v
	queue_redraw()


# (Jamais appelé en mode indice — l'indice vit avec le bouton Résolution, pas de cycle de vie propre.)
func _fade_out() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var out: Tween = create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.30 * MerlinVisual.motion())
	out.tween_callback(queue_free)


# Sommets d'un icosaèdre stylisé (hexagone régulier = silhouette d20 classique) au rayon r, centrés.
func _hex_pts(center: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 6:
		var a: float = -PI * 0.5 + float(i) * TAU / 6.0  # sommet en haut
		pts.append(center + Vector2(cos(a), sin(a)) * r * _squash)
	return pts


func _draw() -> void:
	var s: Vector2 = size
	var half: Vector2 = s * 0.5
	var r: float = s.x * 0.46
	var face_col: Color = MerlinVisual.CREAM
	# N4-P1 (chantier 7) : eclatante = halo GOLD (celebration rare), sinon vert/rouge sourd (v2-W4).
	var halo_col: Color = MerlinVisual.HALO_SUCCESS if _success else MerlinVisual.HALO_FAIL
	if _brilliant:
		halo_col = MerlinVisual.GOLD

	# Mode INDICE : petite pastille « ? » au liseré de rareté (langage R133, inchangé).
	if _static_mode:
		var isb: StyleBoxFlat = StyleBoxFlat.new()
		isb.bg_color = face_col
		isb.set_corner_radius_all(int(r * 0.22))
		isb.set_border_width_all(2)
		isb.border_color = _rim
		draw_style_box(isb, Rect2(half - Vector2(r, r) * 0.72, Vector2(r, r) * 1.44))
		draw_circle(half, r * 0.14, Color(MerlinVisual.INK.r, MerlinVisual.INK.g, MerlinVisual.INK.b, 0.8))
		return

	# Halo à la pose : glow diffus (cercle translucide) + liseré coloré autour de la silhouette.
	# N4-P1 (chantier 2c) : halo RENFORCE (le panel le trouvait timide) : rayon et alpha ~doubles,
	# en 2 couches (coeur net + aureole large). Extension max ~1,75 r : le halo ne mord jamais
	# l'encart de situation (voir la note de positionnement 0.19 dans roll()).
	if _settled and _halo > 0.0:
		draw_circle(half, r * (1.45 + 0.30 * _halo),
			Color(halo_col.r, halo_col.g, halo_col.b, 0.16 * _halo))
		draw_circle(half, r * (1.18 + 0.22 * _halo),
			Color(halo_col.r, halo_col.g, halo_col.b, 0.30 * _halo))

	# Ombre portée (ancre le dé).
	var shadow_pts: PackedVector2Array = _hex_pts(half + Vector2(3, 5), r)
	if MerlinVisual.polygon_drawable(shadow_pts):
		draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.30))

	# Silhouette icosaédrique : hexagone crème + 3 arêtes internes (fausse-3D « facettes »).
	var pts: PackedVector2Array = _hex_pts(half, r)
	if MerlinVisual.polygon_drawable(pts):
		draw_colored_polygon(pts, face_col)
	# Bordure : liseré coloré success/échec à la pose (pulse via _halo), brun neutre pendant la culbute.
	var border_col: Color = MerlinVisual.BORDER_BRUN
	# N4-P1 (chantier 2b) : le lisere ne se teinte qu'AVEC le halo (_halo > 0). Pendant la
	# micro-pause de lecture (face posee, verdict pas encore tombe), il reste brun NEUTRE.
	if _settled and _halo > 0.0:
		border_col = MerlinVisual.BORDER_BRUN.lerp(halo_col, 0.55 + 0.45 * _halo)
	var n: int = pts.size()
	for i in n:
		draw_line(pts[i], pts[(i + 1) % n], border_col, 3.0)
	# Arêtes internes : centre → sommets pairs (triangle central = facette « frontale » de l'icosaèdre).
	var facet: Color = Color(MerlinVisual.INK.r, MerlinVisual.INK.g, MerlinVisual.INK.b, 0.18)
	for i in [0, 2, 4]:
		draw_line(half, pts[i], facet, 1.5)

	# GROS chiffre 1-20 centré (charte gravure) — police par défaut du thème, taille ∝ dé.
	var font: Font = ThemeDB.fallback_font
	var fs: int = int(r * 0.95)
	var txt: String = str(_face)
	var tw: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1.0, fs)
	var baseline: Vector2 = half + Vector2(-tw.x * 0.5, fs * 0.36)
	draw_string(font, baseline, txt, HORIZONTAL_ALIGNMENT_CENTER, -1.0, fs, MerlinVisual.INK)
