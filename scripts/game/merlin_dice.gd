class_name MerlinDice
extends Control
## R158 (2026-07-14) : DES 2d6 : DEUX des a points (pips 1-6) qui culbutent (faces qui defilent +
## squash/rotation fausse-3D), ralentissent, puis se posent sur la somme PRE-TIREE (2-12), avec HALO
## a la pose : VERT sourd si le jet reussit (success), ROUGE sourd sinon. La dramaturgie P1 est
## CONSERVEE : pose, micro-pause de lecture, puis verdict (halo + stinger). Le d20 mono-face (culbute
## d'un GROS chiffre 1-20) est remplace par la paire de des : les stats pesent, la chance suit la cloche.
## Tout procedural (_draw), palette canon, durees x motion(), reduced_motion = faces finales directes.
##
## Le mode INDICE statique (hint()/set_hint_rarity()) et rim_for_rarity() restent INCHANGES :
## MerlinActionView s'en sert pour le lisere de tuile (langage R133), independant du jet.

signal done

const SIZE_PX: float = 120.0     # emprise des DEUX des cote a cote
const DIE_HALF: float = 26.0     # demi-cote d'un de carre
const DIE_GAP: float = 14.0      # ecart entre les deux des
# R158 : la culbute reste compressee ~1,15 s (elle chevauche la decrue de fusion, MerlinFx Phase 3).
const TUMBLE_S: float = 0.35     # phase 1 : culbute rapide
const SLOW_S: float = 0.40       # phase 2 : le defilement ralentit
const SETTLE_S: float = 0.25     # phase 3 : pose + rebond
# N4-P1 (chantier 2b) : micro-pause de LECTURE entre la pose (faces visibles) et le verdict
# (halo + stinger). Ordre dramatique : geste, puis des, puis pause, puis verdict. En x motion().
const PAUSE_READ_S: float = 0.35
# N4-P1 (chantier 7) : a l'eclatante uniquement, halo GOLD PROLONGE (celebration rare) : tenue
# supplementaire avant le fondu, APRES l'emission de done (jamais bloquant pour le flux).
const BRILLIANT_HOLD_S: float = 0.90

var _f1: int = 1                 # face AFFICHEE du de gauche (defile pendant la culbute, 1-6)
var _f2: int = 1                 # face AFFICHEE du de droit
var _final1: int = 1
var _final2: int = 1
var _success: bool = false       # issue du jet, couleur du halo a la pose
var _brilliant: bool = false     # N4-P1 (chantier 7) : eclatante, halo GOLD prolonge
var _on_verdict: Callable = Callable()  # N4-P1 (chantier 2b) : appele A l'instant du halo (stinger)
var _rim: Color = MerlinVisual.BORDER_BRUN  # (mode INDICE uniquement, lisere de rarete)
var _squash: Vector2 = Vector2.ONE
var _settled: bool = false
var _halo: float = 0.0           # 0-1 : intensite du halo a la pose (pulse)
var _static_mode: bool = false   # mode INDICE (pres du bouton Resoudre) : face « ? », aucun roll


static func rim_for_rarity(rarity: String) -> Color:
	match rarity:
		"Rare": return MerlinVisual.RARE_BLUE
		"Épique": return MerlinVisual.RARITY_EPIC
		"Mythique": return MerlinVisual.GOLD
	return MerlinVisual.BORDER_BRUN


# R158 : decompose une somme 2d6 (2-12) en un couple de des valides (1-6, 1-6). Cosmetique : la
# somme est la verite mecanique (resolve lit `die` = somme) ; les deux pips ne font que l'illustrer.
static func split_2d6(total: int) -> Array:
	var t: int = clampi(total, 2, 12)
	var lo: int = maxi(1, t - 6)
	var hi: int = mini(6, t - 1)
	var d1: int = clampi(int(round(float(t) / 2.0)), lo, hi)
	return [d1, t - d1]


# Lance les 2d6 au-dessus du parent : culbute, ralenti, pose. `await dice.done` puis auto-fondu.
# `success` (issue FINALE du jet, K) donne le halo VERT si reussi, ROUGE sinon. `final_face` = somme 2-12.
# N4-P1 : `brilliant` (chantier 7) = halo GOLD prolonge a l'eclatante ; `on_verdict` (chantier 2b)
# = Callable appelee A l'instant du halo (le stinger de degre joue LA, jamais avant la pause).
static func roll(parent: Control, final_face: int, success: bool,
		brilliant: bool = false, on_verdict: Callable = Callable()) -> MerlinDice:
	var d: MerlinDice = MerlinDice.new()
	var pair: Array = split_2d6(final_face)
	d._final1 = int(pair[0])
	d._final2 = int(pair[1])
	d._success = success
	d._brilliant = brilliant
	d._on_verdict = on_verdict
	d.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	d.size = Vector2(SIZE_PX, SIZE_PX)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.z_index = 30
	parent.add_child(d)
	var vp: Vector2 = parent.get_viewport_rect().size
	# Positionnement (zone DECOR, au-dessus de l'encart de situation) : centre ~y 205 a 1080p.
	d.position = Vector2(vp.x * 0.5 - SIZE_PX * 0.5, vp.y * 0.19 - SIZE_PX * 0.5)
	d.pivot_offset = Vector2(SIZE_PX, SIZE_PX) * 0.5
	d._run()
	return d


# Mode INDICE statique (feedforward « ce choix jettera un de ») : petite face « ? » au lisere de rarete.
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
		# N4-P1 (chantier 2b, R148) : meme ORDRE degrade proprement : faces posees NEUTRES, micro-pause
		# de lecture (x motion), PUIS verdict (halo statique + stinger via callback). Jamais de softlock.
		_f1 = _final1
		_f2 = _final2
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
	# Phase 1+2 : culbute : les faces 1-6 defilent (vite puis lentement), squash/rotation fausse-3D.
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
			flip_gap = lerpf(60.0, 240.0, prog * prog)  # le defilement RALENTIT (fausse inertie)
			next_flip_ms = now + int(flip_gap)
			_f1 = _roll_face(_f1)
			_f2 = _roll_face(_f2)
			MerlinAudio.play_sfx("slider_tick", 1.2 - prog * 0.4)
		rotation = sin(float(now) * 0.011) * (0.5 - prog * 0.42)          # bascule qui s'amortit
		_squash = Vector2(1.0 + sin(float(now) * 0.02) * (0.16 - prog * 0.13),
			1.0 - sin(float(now) * 0.02) * (0.16 - prog * 0.13))          # respiration fausse-3D
		queue_redraw()
		await get_tree().process_frame
	# Phase 3 : pose : faces finales, rebond squash, halo success/echec.
	_f1 = _final1
	_f2 = _final2
	_settled = true
	rotation = 0.0
	MerlinAudio.play_sfx("card_pick", 1.0)
	var settle: Tween = create_tween()
	settle.tween_method(func(v: float) -> void:
		_squash = Vector2(1.0 + 0.22 * (1.0 - v), 1.0 - 0.22 * (1.0 - v))
		queue_redraw(), 0.0, 1.0, SETTLE_S * m).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if settle.is_running():  # R148 : jamais d'await sur un tween deja fini
		await settle.finished
	# N4-P1 (chantier 2b) : micro-pause de LECTURE : les faces posees se lisent AVANT le verdict.
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
	await get_tree().create_timer(0.15 * m).timeout  # le flux repart des le verdict pose
	done.emit()
	# Queue de vie APRES done (fire-and-forget pour le flux) : les 2 pulses s'achevent, l'eclatante
	# tient BRILLIANT_HOLD_S de plus (chantier 7, celebration rare), puis fondu. Gardes R148.
	if halo_tw.is_running():
		await halo_tw.finished
	if _brilliant and is_inside_tree():
		await get_tree().create_timer(BRILLIANT_HOLD_S * m).timeout
	_fade_out()


# Face suivante pendant la culbute : jamais identique a la precedente (defilement lisible).
func _roll_face(prev: int) -> int:
	var nf: int = randi_range(1, 6)
	return nf if nf != prev else (nf % 6) + 1


# N4-P1 : setter du halo (tween_method) : une seule ecriture + redraw, reutilise par les pulses.
func _set_halo(v: float) -> void:
	_halo = v
	queue_redraw()


# (Jamais appele en mode indice : l'indice vit avec le bouton Resolution, pas de cycle de vie propre.)
func _fade_out() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var out: Tween = create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.30 * MerlinVisual.motion())
	out.tween_callback(queue_free)


func _draw() -> void:
	var s: Vector2 = size
	var half: Vector2 = s * 0.5
	var face_col: Color = MerlinVisual.CREAM
	# N4-P1 (chantier 7) : eclatante = halo GOLD (celebration rare), sinon vert/rouge sourd.
	var halo_col: Color = MerlinVisual.HALO_SUCCESS if _success else MerlinVisual.HALO_FAIL
	if _brilliant:
		halo_col = MerlinVisual.GOLD

	# Mode INDICE : petite pastille « ? » au lisere de rarete (langage R133, inchange).
	if _static_mode:
		var r0: float = s.x * 0.46
		var isb: StyleBoxFlat = StyleBoxFlat.new()
		isb.bg_color = face_col
		isb.set_corner_radius_all(int(r0 * 0.22))
		isb.set_border_width_all(2)
		isb.border_color = _rim
		draw_style_box(isb, Rect2(half - Vector2(r0, r0) * 0.72, Vector2(r0, r0) * 1.44))
		draw_circle(half, r0 * 0.14, Color(MerlinVisual.INK.r, MerlinVisual.INK.g, MerlinVisual.INK.b, 0.8))
		return

	# Halo a la pose : glow diffus englobant les DEUX des + lisere colore.
	var span: float = DIE_HALF + DIE_GAP * 0.5
	var rr: float = span + DIE_HALF
	if _settled and _halo > 0.0:
		draw_circle(half, rr * (1.30 + 0.28 * _halo),
			Color(halo_col.r, halo_col.g, halo_col.b, 0.16 * _halo))
		draw_circle(half, rr * (1.05 + 0.20 * _halo),
			Color(halo_col.r, halo_col.g, halo_col.b, 0.30 * _halo))

	var border_col: Color = MerlinVisual.BORDER_BRUN
	if _settled and _halo > 0.0:
		border_col = MerlinVisual.BORDER_BRUN.lerp(halo_col, 0.55 + 0.45 * _halo)

	# Deux des carres cote a cote (fausse-3D par squash commun). Gauche = _f1, droite = _f2.
	_draw_one_die(Vector2(half.x - (DIE_HALF + DIE_GAP * 0.5), half.y), _f1, face_col, border_col)
	_draw_one_die(Vector2(half.x + (DIE_HALF + DIE_GAP * 0.5), half.y), _f2, face_col, border_col)


# Un de carre creme a coins arrondis + pips 1-6 encres (charte gravure). `col` = fond, `bc` = lisere.
func _draw_one_die(center: Vector2, face: int, col: Color, bc: Color) -> void:
	var hw: float = DIE_HALF * _squash.x
	var hh: float = DIE_HALF * _squash.y
	# Ombre portee (ancre le de).
	var ssb: StyleBoxFlat = StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.30)
	ssb.set_corner_radius_all(int(DIE_HALF * 0.30))
	draw_style_box(ssb, Rect2(center - Vector2(hw, hh) + Vector2(3, 5), Vector2(hw, hh) * 2.0))
	# Corps du de.
	var dsb: StyleBoxFlat = StyleBoxFlat.new()
	dsb.bg_color = col
	dsb.set_corner_radius_all(int(DIE_HALF * 0.30))
	dsb.set_border_width_all(3)
	dsb.border_color = bc
	draw_style_box(dsb, Rect2(center - Vector2(hw, hh), Vector2(hw, hh) * 2.0))
	# Pips : positions standard d'un de (grille 3x3), rayon proportionnel au de.
	var pr: float = DIE_HALF * 0.16
	var off: float = DIE_HALF * 0.44
	var ink: Color = MerlinVisual.INK
	for p in _pips(face):
		draw_circle(center + Vector2(p.x * off, p.y * off), pr, ink)


# Offsets normalises (-1,0,1) des pips pour une face 1-6.
func _pips(face: int) -> Array:
	match clampi(face, 1, 6):
		1: return [Vector2(0, 0)]
		2: return [Vector2(-1, -1), Vector2(1, 1)]
		3: return [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)]
		4: return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
		5: return [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]
		6: return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]
	return [Vector2(0, 0)]
