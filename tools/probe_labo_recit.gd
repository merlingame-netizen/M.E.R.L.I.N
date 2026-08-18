extends SceneTree
## LE LABORATOIRE DU RÉCIT — mini-tests organisés (/goal Maxime, nuit du 2026-08-18).
##
## Deux questions, une batterie chacune, sur le MÊME contexte figé (une scène de Rencontre avec
## des éléments nommés : les druides, le chevalier, l'enfant, l'autel) :
##
##   RICHESSE   — la même issue à trois niveaux (richesse 0/1/2 : 3-4, 5-7, 7-9 phrases).
##                « Les résolutions sont trop légères » : on mesure ce que chaque palier coûte
##                (secondes) et rend (texte), pour choisir en connaissance.
##   ENCHAÎNEMENT — la scène suivante écrite EN CONNAISSANT l'issue précédente (scene_jit,
##                lookahead de la bible) contre la même scène écrite à l'aveugle (arc_tranche,
##                l'architecture actuelle). « Les beats ne s'enchaînent pas logiquement. »
##
## Lancée deux fois — MERLIN_MODELE=e4b puis e2b — elle répond aussi à la question des cerveaux :
## le petit modèle tient-il la qualité pour un temps drastiquement meilleur ?
##
##   MERLIN_ALLOW_HEADLESS_LLM=1 MERLIN_MODELE=e4b godot --headless --path . --script res://tools/probe_labo_recit.gd
##
## Sortie : [LABO_JSON] {...} — textes COMPLETS + compteurs réels (prompt/écriture séparés).

const NODE_TIMEOUT_MS: int = 15000
const LOAD_TIMEOUT_MS: int = 300000

const SITU: Dictionary = {
	"type": "Rencontre", "die": 9, "difficulte": 2, "required_tags": [],
	"narration": "Vous gagnez le coeur du bois : deux druides en bure sombre repetent une formule monotone pres du cercle de pierres. Un chevalier aux jointures rouillees s'agenouille devant l'autel couvert de mousse rouge, et un enfant aux cheveux d'or pointe le bas de l'autel en demandant pourquoi les pierres ne parlent plus.",
}
const ISSUE_PRECEDENTE: String = "[i]Vous tendez la main vers le chevalier et lui demandez s'il a vu les traces du mot interdit.[/i] Le regard fatigue du guerrier se relache, et il hoche lentement la tete vers le sentier qui s'enfonce derriere l'autel — mais l'enfant saisit votre manche, inquiet."


func _init() -> void:
	_run()


func _await_node(path: String, max_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	var n: Node = root.get_node_or_null(path)
	while n == null and (Time.get_ticks_msec() - t0) < max_ms:
		await create_timer(0.05).timeout
		n = root.get_node_or_null(path)
	return n


func _gen(mn: Node, nom: String, p: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	var m: Dictionary = mn.last_metrics()
	var d: Dictionary = {
		"nom": nom, "mur_ms": Time.get_ticks_msec() - t0,
		"erreur": str(r.get("error", "")),
		"prompt_tokens": int(m.get("prompt_tokens", 0)), "prompt_ms": float(m.get("prompt_ms", 0.0)),
		"tokens_ecrits": int(m.get("tokens_ecrits", 0)), "ecriture_ms": float(m.get("ecriture_ms", 0.0)),
		"texte": str(r.get("text", "")),
	}
	print("[LABO] %-16s %6.1f s · prompt %d tok · écrit %d tok · %d car."
			% [nom, d["mur_ms"] / 1000.0, d["prompt_tokens"], d["tokens_ecrits"], str(d["texte"]).length()])
	# Le moteur est mono-place : une courte respiration évite qu'un poll tardif ne télescope
	# la génération suivante.
	await create_timer(1.0).timeout
	return d


func _run() -> void:
	var out: Dictionary = {"t": Time.get_datetime_string_from_system(true),
		"modele": OS.get_environment("MERLIN_MODELE"), "ok": false, "items": []}
	var mn: Node = await _await_node("MerlinNative", NODE_TIMEOUT_MS)
	var sc: Node = await _await_node("MerlinScenario", NODE_TIMEOUT_MS)
	var run: Node = await _await_node("MerlinRun", NODE_TIMEOUT_MS)
	if mn == null or sc == null or run == null:
		print("[LABO_JSON] " + JSON.stringify({"ok": false, "etape": "autoloads absents"}))
		quit(2)
		return
	run.biome = "foret"
	var t0: int = Time.get_ticks_msec()
	while not mn.is_ready() and (Time.get_ticks_msec() - t0) < LOAD_TIMEOUT_MS:
		if mn.has_method("boot_error") and str(mn.boot_error()) != "":
			print("[LABO_JSON] " + JSON.stringify({"ok": false, "etape": str(mn.boot_error())}))
			quit(3)
			return
		await create_timer(0.25).timeout
	if not mn.is_ready():
		print("[LABO_JSON] " + JSON.stringify({"ok": false, "etape": "modele jamais charge"}))
		quit(3)
		return
	out["moteur"] = mn.model_info() if mn.has_method("model_info") else {}

	# Contexte RÉEL : squelette + run neufs → vraies cartes, vrai fil (faction, pilier).
	var skel: Dictionary = sc.build_skeleton("Le Souffle du Vieux Druide",
		"Trouve le mot que les druides ont jure de ne jamais prononcer, ou tu deviendras partie du lichen.")
	run.clear_save()
	run.new_run(skel)
	var action: Variant = run.actions[0] if not (run.actions as Array).is_empty() else null
	var trait_c: Variant = run.hand[0] if not (run.hand as Array).is_empty() else null
	if action == null or trait_c == null:
		print("[LABO_JSON] " + JSON.stringify({"ok": false, "etape": "cartes absentes"}))
		quit(2)
		return
	var combo: Array = [action, trait_c]
	var res: Dictionary = {"degree": "reussite", "synergy": 1}
	var items: Array = out["items"]

	# --- Batterie RICHESSE : la même issue à trois paliers ---
	for r_niv in [0, 1, 2]:
		var p: Dictionary = MerlinPromptBuilder.resolution(SITU, combo, res, sc._run_thread, r_niv)
		items.append(await _gen(mn, "issue_r%d" % r_niv, p))

	# --- Batterie ENCHAÎNEMENT : la scène 3, avec et sans l'issue précédente ---
	var fblock: String = MerlinPromptBuilder.faction_pilier_block(
		str(sc._run_thread.get("faction", "")), str(sc._run_thread.get("pilier", "")),
		str(sc._run_thread.get("pilier2", "")), false)
	var pj: Dictionary = MerlinPromptBuilder.scene_jit(skel, "Epreuve", 2, 6, [],
			str(SITU["narration"]), ISSUE_PRECEDENTE, fblock, "Broceliande", [])
	items.append(await _gen(mn, "scene_lookahead", pj))
	var pa: Dictionary = MerlinPromptBuilder.arc_tranche(skel, [[]], ["Epreuve"], 2, 6,
			str(SITU["narration"]), fblock, "Broceliande", [])
	items.append(await _gen(mn, "scene_aveugle", pa))

	# --- Témoin de voix : l'intro (juge la tenue du français et du ton par modèle) ---
	var pi: Dictionary = MerlinPromptBuilder.intro(sc._voice_prefix(), skel, "", "Broceliande")
	items.append(await _gen(mn, "intro", pi))

	out["ok"] = true
	print("[LABO_JSON] " + JSON.stringify(out))
	quit(0)
