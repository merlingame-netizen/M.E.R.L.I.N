extends SceneTree
## OÙ PASSENT LES SECONDES — décomposition du coût d'une sélection.
##
## POURQUOI. Une sélection prend 112 s dans le jeu contre 31 s sans rien dessiner, et le seul
## chiffre dont on disposait était un total. Une mesure du 2026-08-15 avait montré que couper la
## sortie de 28 % ne gagnait que 2 % du temps : le coût n'est donc PAS dans ce que le modèle
## écrit. Restaient deux suspects jamais séparés — l'évaluation du prompt, et le coût fixe.
##
## MÉTHODE : la même génération à deux plafonds de sortie.
##   · max_tokens = 1   → coût fixe + évaluation du prompt (le modèle n'écrit qu'un token)
##   · max_tokens = 160 → le tout
##   · la différence    → le temps d'écriture
## Puis le même couple sur un prompt COURT (sans bloc de biome, sans titres mémorisés) : la
## différence entre les deux prompts donne la pente, en millisecondes par token de prompt.
##
## Le binaire recompilé le 2026-08-18 joint en plus les compteurs EXACTS de llama.cpp
## (prompt_eval_ms / eval_ms). Quand ils sont là, la sonde les rend ET garde la mesure par
## différence : deux méthodes indépendantes qui doivent concorder — si elles divergent, c'est
## qu'une des deux ment, et mieux vaut le savoir.
##
##   MERLIN_ALLOW_HEADLESS_LLM=1 godot --headless --path . --script res://tools/probe_llm_decompose.gd
##
## Réglages : MERLIN_DECOMP_BIOME (défaut foret) · MERLIN_DECOMP_OUT (dossier où déposer le
## prompt exact, pour le rejouer sous Ollama et comparer sur pièce).

const NODE_TIMEOUT_MS: int = 15000
const LOAD_TIMEOUT_MS: int = 300000
const PASSE_TIMEOUT_MS: int = 300000


func _init() -> void:
	_run()


func _await_node(path: String, max_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	var n: Node = root.get_node_or_null(path)
	while n == null and (Time.get_ticks_msec() - t0) < max_ms:
		await create_timer(0.05).timeout
		n = root.get_node_or_null(path)
	return n


# Une passe = un appel au modèle, chronométré au mur, avec les compteurs du moteur s'il en donne.
func _passe(mn: Node, nom: String, sys: String, usr: String, max_tok: int) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var res: Dictionary = await mn.generate(sys, usr, {
		"creative": true, "max_tokens": max_tok, "plein_regime": true, "label": nom,
	})
	var mur: int = Time.get_ticks_msec() - t0
	var m: Dictionary = mn.last_metrics() if mn.has_method("last_metrics") else {}
	var d: Dictionary = {
		"nom": nom, "max_tokens": max_tok, "mur_ms": mur,
		"erreur": str(res.get("error", "")),
		"sortie_chars": str(res.get("text", "")).length(),
		"compteurs_reels": bool(m.get("compteurs_reels", false)),
		"prompt_ms": float(m.get("prompt_ms", 0.0)),
		"prompt_tokens": int(m.get("prompt_tokens", 0)),
		"ecriture_ms": float(m.get("ecriture_ms", 0.0)),
		"tokens_ecrits": int(m.get("tokens_ecrits", 0)),
	}
	var detail: String = ""
	if bool(d["compteurs_reels"]):
		detail = " · prompt %.1f s / %d tok · ecriture %.1f s / %d tok" % [
			float(d["prompt_ms"]) / 1000.0, int(d["prompt_tokens"]),
			float(d["ecriture_ms"]) / 1000.0, int(d["tokens_ecrits"])]
	print("[DECOMP] %-14s max=%-4d mur=%6.1f s%s" % [nom, max_tok, mur / 1000.0, detail])
	return d


func _run() -> void:
	var out: Dictionary = {"t": Time.get_datetime_string_from_system(true), "ok": false, "passes": []}
	var mn: Node = await _await_node("MerlinNative", NODE_TIMEOUT_MS)
	var sc: Node = await _await_node("MerlinScenario", NODE_TIMEOUT_MS)
	var run: Node = await _await_node("MerlinRun", NODE_TIMEOUT_MS)
	if mn == null or sc == null or run == null:
		out["etape"] = "autoloads absents"
		_emettre(out)
		quit(2)
		return

	var biome: String = OS.get_environment("MERLIN_DECOMP_BIOME")
	if biome == "":
		biome = "foret"
	run.biome = biome

	# Le chargement est chronométré À PART : il fait partie de ce que le joueur attend au premier
	# lancement, mais le mélanger aux générations rendrait toute comparaison fausse.
	var t0: int = Time.get_ticks_msec()
	while not mn.is_ready() and (Time.get_ticks_msec() - t0) < LOAD_TIMEOUT_MS:
		if mn.has_method("boot_error") and str(mn.boot_error()) != "":
			out["etape"] = "moteur indisponible : %s" % str(mn.boot_error())
			_emettre(out)
			quit(3)
			return
		await create_timer(0.25).timeout
	if not mn.is_ready():
		out["etape"] = "modele jamais charge"
		_emettre(out)
		quit(3)
		return
	out["charge_ms"] = Time.get_ticks_msec() - t0
	out["biome"] = biome
	out["moteur"] = mn.model_info() if mn.has_method("model_info") else {}
	print("[DECOMP] modele pret en %.1f s · biome=%s" % [float(out["charge_ms"]) / 1000.0, biome])

	# LE PROMPT DU JEU, pas un prompt de laboratoire : celui que _generate_selection_sourced
	# construit réellement (persona + matière du biome + titres déjà vus + angle imposé).
	var p_long: Dictionary = MerlinPromptBuilder.selection(
			sc._voice_prefix(), sc._run_biome(), sc.titres_deja_vus(), sc._tirer_angle())
	# Le prompt COURT retire les deux blocs qu'on soupçonne de coûter cher : la matière du biome
	# et la liste anti-répétition. Même tâche, même voix — seule la longueur change.
	var p_court: Dictionary = MerlinPromptBuilder.selection(
			MerlinPromptBuilder.MERLIN_VOICE_PREFIX, sc._run_biome(), [], "")

	out["prompt_long_chars"] = str(p_long["system"]).length() + str(p_long["user"]).length()
	out["prompt_court_chars"] = str(p_court["system"]).length() + str(p_court["user"]).length()

	# Déposer le prompt EXACT sur disque : c'est lui qu'on rejouera sous Ollama, sur les mêmes
	# poids et la même machine. Sans ça la comparaison porterait sur deux tâches différentes et
	# ne prouverait rien.
	var dossier: String = OS.get_environment("MERLIN_DECOMP_OUT")
	if dossier != "":
		_deposer(dossier + "/prompt_system.txt", str(p_long["system"]))
		_deposer(dossier + "/prompt_user.txt", str(p_long["user"]))

	# L'ORDRE COMPTE : on commence par le plafond à 1 token. Le premier appel d'une session paie
	# des frais qu'aucun autre ne paie (allocations, premières pages du modèle touchées) ; les
	# mettre sur la passe la moins chère les rend visibles au lieu de les diluer.
	for essai in [
		{"nom": "long_1tok", "p": p_long, "max": 1},
		{"nom": "long_160tok", "p": p_long, "max": 160},
		{"nom": "court_1tok", "p": p_court, "max": 1},
		{"nom": "court_160tok", "p": p_court, "max": 160},
	]:
		var pr: Dictionary = essai["p"]
		var d: Dictionary = await _passe(mn, str(essai["nom"]), str(pr["system"]),
				str(pr["user"]), int(essai["max"]))
		(out["passes"] as Array).append(d)
		# Le moteur est mono-place : lui laisser rendre la main évite de compter une collision
		# comme une lenteur.
		await create_timer(1.0).timeout

	out["ok"] = true
	out["lecture"] = _lecture(out["passes"])
	_emettre(out)
	quit(0)


# La conclusion en français, calculée ici pour qu'elle ne dépende pas de qui lit le JSON.
func _lecture(passes: Array) -> Dictionary:
	var par_nom: Dictionary = {}
	for p in passes:
		par_nom[str((p as Dictionary)["nom"])] = p
	var l: Dictionary = {}
	if par_nom.has("long_1tok") and par_nom.has("long_160tok"):
		var fixe: int = int(par_nom["long_1tok"]["mur_ms"])
		var tout: int = int(par_nom["long_160tok"]["mur_ms"])
		l["prompt_et_fixe_ms"] = fixe
		l["ecriture_ms"] = tout - fixe
		l["part_prompt_pct"] = int(round(100.0 * float(fixe) / maxf(float(tout), 1.0)))
	if par_nom.has("long_1tok") and par_nom.has("court_1tok"):
		# Deux prompts, même tâche : l'écart isole ce que coûtent les blocs retirés.
		l["surcout_blocs_ms"] = int(par_nom["long_1tok"]["mur_ms"]) - int(par_nom["court_1tok"]["mur_ms"])
	return l


func _deposer(chemin: String, contenu: String) -> void:
	var f: FileAccess = FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_string(contenu)
		f.close()
	else:
		push_warning("[DECOMP] depot impossible : %s" % chemin)


func _emettre(d: Dictionary) -> void:
	print("[DECOMP_JSON] " + JSON.stringify(d))
