extends SceneTree
## LE LABO DES DEUX MAINS (v33) — mesure le partage 2+2 : une issue s'écrit sur le Vif
## PENDANT qu'une scène s'écrit sur le Conteur. Trois mesures sur le MÊME contexte figé :
## vif seul, conteur seul, puis LES DEUX ENSEMBLE — tok/s d'écriture par voie.
##
##   MERLIN_ALLOW_HEADLESS_LLM=1 godot --headless --path . --script res://tools/probe_labo_deuxmains.gd
##
## Sortie : [DEUXMAINS_JSON] {...} + lignes [2M] par mesure.

const NODE_TIMEOUT_MS: int = 15000
const LOAD_TIMEOUT_MS: int = 300000
const DUO_TIMEOUT_MS: int = 300000

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


func _libre(mn: Node) -> void:
	# Attend que TOUTES les voies soient libres (amorçages du boot compris).
	var t0: int = Time.get_ticks_msec()
	while mn.is_busy() and (Time.get_ticks_msec() - t0) < 180000:
		await create_timer(0.5).timeout


func _lancer(mn: Node, nom: String, p: Dictionary, sortie: Dictionary) -> void:
	# Sans await à l'appel : la coroutine vit seule — c'est ainsi que le duo se lance.
	var t0: int = Time.get_ticks_msec()
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	var cerveau: String = str((p["opts"] as Dictionary).get("cerveau", "conteur"))
	var m: Dictionary = {}
	if "_voies" in mn:
		m = ((mn._voies as Dictionary).get(cerveau, {}) as Dictionary).get("metrics", {})
	var mesure: Dictionary = {
		"nom": nom, "mur_ms": Time.get_ticks_msec() - t0, "erreur": str(r.get("error", "")),
		"cerveau": str(m.get("cerveau", cerveau)),
		"prompt_tokens": int(m.get("prompt_tokens", 0)), "prompt_ms": float(m.get("prompt_ms", 0.0)),
		"tokens_ecrits": int(m.get("tokens_ecrits", 0)), "ecriture_ms": float(m.get("ecriture_ms", 0.0)),
		"car": str(r.get("text", "")).length(),
	}
	sortie[nom] = mesure
	var vit: float = 0.0
	if float(mesure["ecriture_ms"]) > 0.0:
		vit = float(mesure["tokens_ecrits"]) * 1000.0 / float(mesure["ecriture_ms"])
	print("[2M] %-13s [%s] %6.1f s · écrit %d tok en %.1f s (%.2f tok/s) · %d car."
			% [nom, mesure["cerveau"], float(mesure["mur_ms"]) / 1000.0, mesure["tokens_ecrits"],
				float(mesure["ecriture_ms"]) / 1000.0, vit, mesure["car"]])


func _run() -> void:
	var out: Dictionary = {"t": Time.get_datetime_string_from_system(true), "ok": false, "mesures": {}}
	var mn: Node = await _await_node("MerlinNative", NODE_TIMEOUT_MS)
	var sc: Node = await _await_node("MerlinScenario", NODE_TIMEOUT_MS)
	var run: Node = await _await_node("MerlinRun", NODE_TIMEOUT_MS)
	if mn == null or sc == null or run == null:
		print("[DEUXMAINS_JSON] " + JSON.stringify({"ok": false, "etape": "autoloads absents"}))
		quit(2)
		return
	var t0: int = Time.get_ticks_msec()
	while not mn.is_ready() and (Time.get_ticks_msec() - t0) < LOAD_TIMEOUT_MS:
		if str(mn.boot_error()) != "":
			print("[DEUXMAINS_JSON] " + JSON.stringify({"ok": false, "etape": str(mn.boot_error())}))
			quit(3)
			return
		await create_timer(0.5).timeout
	if not mn.is_ready():
		print("[DEUXMAINS_JSON] " + JSON.stringify({"ok": false, "etape": "modele jamais charge"}))
		quit(3)
		return
	# Le Vif doit être là — sans lui, pas de duo à mesurer.
	t0 = Time.get_ticks_msec()
	while not mn.est_vif_pret() and (Time.get_ticks_msec() - t0) < LOAD_TIMEOUT_MS:
		await create_timer(0.5).timeout
	if not mn.est_vif_pret():
		print("[DEUXMAINS_JSON] " + JSON.stringify({"ok": false, "etape": "vif jamais pret"}))
		quit(4)
		return
	out["deux_voies"] = bool("_voies" in mn)
	await _libre(mn)

	var skel: Dictionary = sc.build_skeleton("Le Souffle du Vieux Druide",
		"Trouve le mot que les druides ont jure de ne jamais prononcer, ou tu deviendras partie du lichen.")
	run.clear_save()
	run.new_run(skel)
	var action: Variant = run.actions[0] if not (run.actions as Array).is_empty() else null
	var trait_c: Variant = run.hand[0] if not (run.hand as Array).is_empty() else null
	if action == null or trait_c == null:
		print("[DEUXMAINS_JSON] " + JSON.stringify({"ok": false, "etape": "cartes absentes"}))
		quit(2)
		return
	var combo: Array = [action, trait_c]
	var res: Dictionary = {"degree": "reussite", "synergy": 1}
	var p_issue: Dictionary = MerlinPromptBuilder.resolution(SITU, combo, res, sc._run_thread, 2)
	var fblock: String = MerlinPromptBuilder.faction_pilier_block(
		str(sc._run_thread.get("faction", "")), str(sc._run_thread.get("pilier", "")),
		str(sc._run_thread.get("pilier2", "")), false)
	var p_scene: Dictionary = MerlinPromptBuilder.scene_jit(skel, "Epreuve", 2, 6, [],
			str(SITU["narration"]), ISSUE_PRECEDENTE, fblock, "Broceliande", [])
	var mes: Dictionary = out["mesures"]

	# 1) chaque voie SEULE (référence)
	await _lancer(mn, "vif_seul", p_issue, mes)
	await _libre(mn)
	await _lancer(mn, "conteur_seul", p_scene, mes)
	await _libre(mn)

	# 2) LES DEUX ENSEMBLE — le cœur de la mesure
	var duo: Dictionary = {}
	_lancer(mn, "vif_duo", p_issue, duo)
	_lancer(mn, "conteur_duo", p_scene, duo)
	var dl: int = Time.get_ticks_msec() + DUO_TIMEOUT_MS
	while duo.size() < 2 and Time.get_ticks_msec() < dl:
		await create_timer(0.5).timeout
	for k in duo:
		mes[k] = duo[k]
	out["ok"] = duo.size() == 2
	print("[DEUXMAINS_JSON] " + JSON.stringify(out))
	quit(0 if bool(out["ok"]) else 5)
