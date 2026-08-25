#!/usr/bin/env python3
"""Patch v46.1 — la sonde du geste : verifier une animation sans la VM.

La sequence v46 (fusion -> phrase du geste -> de/sceau) a ete ecrite, poussee et livree sans
avoir jamais tourne : le parse check ne dit rien d'une animation, et la partie temoin demande le
moteur natif (absent hors ARM) plus une demi-heure de VM. Entre les deux, RIEN.

Cette sonde comble le trou : une vraie scene (donc les autoloads), zero ligne de LLM, ~10 s.
Elle joue les DEUX branches de la phase 3 — le vrai jet et le geste dispense de de — et echoue
avec une raison precise si la phrase ne s'affiche pas, ne finit pas de s'ecrire, ou si la mise
ne s'allume pas. Verifiee par contre-epreuve : frappe bridee a 30 % -> rc=1.

    godot --headless --path . res://tools/probe_fx_geste.tscn

Mesures a la livraison : phrase a t+0,77 s, pleine a t+2,37 s, sequence complete en 4,3 s
(avec de) et 3,7 s (sans jet)."""
import pathlib

GESTE_GD = r"""extends Control
## Sonde de la SEQUENCE DU GESTE (v46) — fusion -> phrase du geste -> de ou sceau.
##
## POURQUOI ELLE EXISTE. Le parse check ne dit rien d'une animation, et la partie temoin de la VM
## demande le moteur natif (absent hors ARM) plus une demi-heure. Entre les deux il n'y avait RIEN :
## la sequence v46 a ete ecrite, poussee et livree sans avoir jamais tourne. Cette sonde comble
## exactement ce trou — une VRAIE scene (donc les autoloads), sans une ligne de LLM, en ~10 s.
##
## `--script` ne suffit PAS : en mode script les autoloads ne sont pas enregistres (MerlinAudio
## vaut null), la coroutine de MerlinFx meurt en silence sur le premier appel, et l'attente ne
## rend jamais la main. Il faut une scene. C'est pour ca que ce fichier a un .tscn a cote.
##
##   godot --headless --path . res://tools/probe_fx_geste.tscn
##   rc=0 : la phrase s'affiche, se remplit entierement, la mise s'allume, la sequence se termine.

const RATIO_PLEIN: float = 0.999

var _t0: int = 0
var _fautes: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_go()


func _go() -> void:
	await get_tree().process_frame
	var par_verbe: Dictionary = {}
	for a in MerlinCard.make_actions():
		par_verbe[a.card_name] = a
	var par_id: Dictionary = {}
	for c in MerlinCard.starter_traits():
		par_id[c.id] = c

	# Les deux branches de la phase 3 : le vrai jet, et le geste dispense de de (sceau).
	for cas in [
		{"nom": "avec de", "verbe": "OBSERVER", "trait": "pressentiment", "diff": 3, "talent": 0},
		{"nom": "sans jet", "verbe": "COMBATTRE", "trait": "main_de_fer", "diff": 2, "talent": 2},
	]:
		if not par_verbe.has(cas["verbe"]) or not par_id.has(cas["trait"]):
			_fautes.append("carte de test absente : %s / %s" % [cas["verbe"], cas["trait"]])
			continue
		var combo: Array = [par_verbe[cas["verbe"]], par_id[cas["trait"]]]
		var res: Dictionary = MerlinResolution.resolve(["Force", "Instinct"], combo, [], 8,
			[], int(cas["diff"]), int(cas["talent"]), 0, "Epreuve", 0)
		var phrase: String = str(res.get("phrase_geste", ""))
		var mise: String = str(res.get("mise", ""))
		print("--- %s : %s + %s ---" % [cas["nom"], cas["verbe"], par_id[cas["trait"]].card_name])
		print("  phrase : ", phrase)
		print("  mise   : %s (geste_sur=%s, de=%d)" % [mise, str(res["geste_sur"]), int(res["die"])])
		if phrase.strip_edges().is_empty():
			_fautes.append("%s : aucune phrase composee" % cas["nom"])
			continue
		if bool(res["geste_sur"]) != (int(res["die"]) == 0):
			_fautes.append("%s : geste_sur et de se contredisent" % cas["nom"])

		_t0 = Time.get_ticks_msec()
		# `card_views` vide : la sonde ne teste QUE la sequence du geste, pas le vol des cartes.
		# (La phase 2 cree alors un tween sans tweener — bruit connu, sans effet ici.)
		var fx: MerlinFx = MerlinFx.play(self, res, combo, [], func() -> bool: return true)
		_surveiller(fx, phrase, mise, str(cas["nom"]))
		await fx.run()
		print("  sequence complete en %d ms" % (Time.get_ticks_msec() - _t0))
		await get_tree().process_frame

	if _fautes.is_empty():
		print("SONDE GESTE : OK")
		get_tree().quit(0)
	else:
		for f in _fautes:
			printerr("SONDE GESTE : ", f)
		get_tree().quit(1)


# Suit le Label de la phrase pendant toute la vie du layer : quand il apparait, jusqu'ou il se
# remplit, et si la mise s'allume. Un Label present mais jamais rempli = frappe cassee.
func _surveiller(fx: MerlinFx, phrase: String, mise: String, nom: String) -> void:
	var vu_a: int = -1
	var plein_a: int = -1
	var ratio_max: float = -1.0
	var mise_allumee: bool = false
	while is_instance_valid(fx) and fx.is_inside_tree():
		for n in fx.get_children():
			if not (n is Label):
				continue
			var l: Label = n
			if l.text == phrase:
				if vu_a < 0:
					vu_a = Time.get_ticks_msec() - _t0
				if l.visible_ratio >= RATIO_PLEIN and plein_a < 0:
					plein_a = Time.get_ticks_msec() - _t0
				ratio_max = maxf(ratio_max, l.visible_ratio)
			elif mise != "" and l.text == mise and l.modulate.a > 0.5:
				mise_allumee = true
		await get_tree().process_frame

	if vu_a < 0:
		_fautes.append("%s : la phrase n'a jamais ete affichee" % nom)
		return
	if ratio_max < RATIO_PLEIN:
		_fautes.append("%s : la phrase n'a jamais fini de s'ecrire (ratio max %.2f)" % [nom, ratio_max])
	if mise != "" and not mise_allumee:
		_fautes.append("%s : la mise ne s'est jamais allumee" % nom)
	print("  phrase a t+%d ms · pleine a t+%d ms · ratio max %.2f · mise allumee=%s"
		% [vu_a, plein_a, ratio_max, str(mise_allumee)])
"""

GESTE_TSCN = r"""[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/probe_fx_geste.gd" id="1_geste"]

[node name="SondeGeste" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_geste")
"""

pathlib.Path("tools/probe_fx_geste.gd").write_text(GESTE_GD, encoding="utf-8")
pathlib.Path("tools/probe_fx_geste.tscn").write_text(GESTE_TSCN, encoding="utf-8")
print("v46.1 applique : sonde du geste posee (tools/probe_fx_geste.gd + .tscn)")
