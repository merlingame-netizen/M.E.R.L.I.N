## ═══════════════════════════════════════════════════════════════════════════
## conformance_pipeline.gd — Extraction de la sortie RÉELLE du pipeline
## ═══════════════════════════════════════════════════════════════════════════
## Exécute le vrai code d'équilibrage du jeu (`Planner._balance_skeleton`,
## statique donc appelable sans Ollama) sur trois familles d'entrées, et dump le
## résultat en JSON pour audit par `tools/check_pipeline_output.py`.
##
##   1. FALLBACK (cascade L3)  — les 8 squelettes livrés en dur dans le jeu :
##      ce que le joueur obtient quand le LLM est indisponible.
##   2. SYNTHETIC LLM          — squelettes bruts au format exact du GBNF
##      (`{n, summary, faction_tilt, emotion}`), tailles 5 / 7 / 10 : ce que le
##      LLM peut légalement produire.
##   3. CONTRACT SCALE         — mêmes squelettes bruts mais à 25 beats, pour
##      distinguer « le clamp bloque » de « l'équilibrage est faux ».
##
## Usage : godot --headless --path . --script res://tools/godot/conformance_pipeline.gd
## Sortie : res://.tmp_pipeline_output.json
## ═══════════════════════════════════════════════════════════════════════════
extends SceneTree

const OUT_PATH := "res://.tmp_pipeline_output.json"

## Le cache des global class_name n'est pas construit en headless :
## on charge le script directement pour appeler ses membres statiques.
const Planner = preload("res://addons/merlin_ai/scenario_planner.gd")

const EMOTIONS := ["curiosite", "tension", "peur", "espoir", "sagesse",
	"fascination", "colere", "melancolie", "emerveillement"]
const FACTIONS := ["druides", "anciens", "korrigans", "niamh", "ankou", "neutre"]


func _init() -> void:
	var payload: Dictionary = {
		"generated_by": "tools/godot/conformance_pipeline.gd",
		"godot_version": Engine.get_version_info().get("string", "?"),
		"samples": [],
	}

	# ── 1. Squelettes de secours livrés dans le jeu (cascade L3) ────────────
	for biome_id in Planner.FALLBACK_SKELETONS.keys():
		var raw: Dictionary = (Planner.FALLBACK_SKELETONS[biome_id] as Dictionary).duplicate(true)
		payload["samples"].append(_run_sample("fallback_L3", biome_id, raw))

	# ── 2. Squelettes bruts au format GBNF, tailles autorisées ─────────────
	for size in [5, 7, 10]:
		payload["samples"].append(_run_sample(
			"synthetic_llm_%d" % size, "foret_broceliande", _synthetic(size)))

	# ── 3. À l'échelle du contrat (25 beats) ───────────────────────────────
	payload["samples"].append(_run_sample(
		"contract_scale_25", "foret_broceliande", _synthetic(25)))

	# ── Métadonnées du code : ce que le pipeline s'autorise ────────────────
	payload["planner_constants"] = {
		"CARD_TYPE_CAPS": Planner.CARD_TYPE_CAPS,
		"RARITY_TARGETS": Planner.RARITY_TARGETS,
		"NO_REPEAT_CARDTYPES": Planner.NO_REPEAT_CARDTYPES,
		"LEGENDARY_START_SHARE": Planner.LEGENDARY_START_SHARE,
		"BEAT_ACT_SEQUENCE": Planner.BEAT_ACT_SEQUENCE,
		"ACT_TYPE_TO_CARDTYPE": Planner.ACT_TYPE_TO_CARDTYPE,
		"BIOME_POLE_BIAS": Planner.BIOME_POLE_BIAS,
		"MAX_TITLE_LENGTH": Planner.MAX_TITLE_LENGTH,
	}

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[conformance] impossible d'ecrire %s" % OUT_PATH)
		quit(1)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("[conformance] OK — %d echantillons ecrits dans %s" % [payload["samples"].size(), OUT_PATH])
	quit(0)


## Passe un squelette brut dans le vrai équilibrage du jeu et capture avant/après.
func _run_sample(sample_id: String, biome_id: String, raw: Dictionary) -> Dictionary:
	var before: Dictionary = raw.duplicate(true)
	var after: Dictionary = Planner._balance_skeleton(raw.duplicate(true), biome_id)
	return {
		"sample_id": sample_id,
		"biome_id": biome_id,
		"beats_in": (before.get("beats", []) as Array).size(),
		"beats_out": (after.get("beats", []) as Array).size(),
		"raw": before,
		"balanced": after,
	}


## Squelette brut conforme au GBNF : uniquement n / summary / faction_tilt / emotion.
## Aucun card_type, aucune rarete, aucun pole — c'est exactement ce que le LLM
## peut emettre sous grammaire contrainte.
##
## IMPORTANT (methode) : l'entree est volontairement CONFORME au contrat sur tout
## ce qu'elle peut porter (arc emotionnel : ouverture curiosite, aucune repetition
## consecutive, finale sagesse ; faction_tilt majoritairement aligne sur le Pole
## dominant du biome). Ainsi, toute non-conformite observee en SORTIE est
## imputable au jeu, jamais au jeu de test.
func _synthetic(size: int) -> Dictionary:
	# Palette de rotation sans repetition consecutive, encadree par curiosite/sagesse.
	var middle: Array = ["fascination", "tension", "emerveillement", "espoir", "melancolie"]
	var beats: Array = []
	for i in range(size):
		var n: int = i + 1
		var emotion: String = "curiosite"
		if n == size:
			emotion = "sagesse"
		elif n > 1:
			emotion = str(middle[(i - 1) % middle.size()])
		# faction_tilt : biais vers le Pole dominant du biome (Liminal = niamh
		# pour Broceliande) — le contrat demande un biais, pas l'uniformite.
		var tilt: String = str(FACTIONS[i % FACTIONS.size()])
		if i % 2 == 0:
			tilt = "niamh"
		beats.append({
			"n": n,
			"summary": "Station %d du rite : la mousse cede sous ton pied et la brume repond." % n,
			"faction_tilt": tilt,
			"emotion": emotion,
		})
	return {"title": "Le Rite des Neuf Souffles", "beats": beats}
