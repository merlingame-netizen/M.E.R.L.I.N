extends SceneTree
## Soak Monte Carlo (v10.13 Phase P) — N runs logiques COMPLETS, sans LLM ni UI. C'est la PREUVE
## mesurable du « 100% fiable » : chaque run atteint un état de fin, zéro erreur script, invariants
## tenus à chaque beat. Archétypes de joueur paramétrables (prêt pour l'équilibrage v10.14) +
## cas dégénérés forcés (deck vide, corruption proche du cap, intégrité minimale) + cas S5
## save/resume (reprise = début de beat, jamais de double-application des coûts).
##   Godot --headless --path . --script res://tools/probe_soak.gd -- --runs=200 --archetype=mixed
## Sortie : [SOAK] ... + ligne finale « [SOAK] DONE — N/N PASS » ; exit 1 si le moindre échec.

const RunScript := preload("res://scripts/game/merlin_run.gd")
const Scenario := preload("res://scripts/llm/merlin_scenario.gd")

const ARCHETYPES: Array = ["optimal", "greedy", "chaotic", "corrompu", "tag_ignorant"]
const GUARD_BEATS: int = 60  # filet anti-boucle (un run normal = 5-7 beats)

var _fail: int = 0
var _ends: Dictionary = {}
var _degrees: Dictionary = {}
var _drafts_offered: int = 0
var _drafts_taken: int = 0
var _secours_injected: int = 0


func _init() -> void:
	var runs: int = 200
	var archetype: String = "mixed"
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--runs="):
			runs = maxi(1, int(s.trim_prefix("--runs=")))
		elif s.begins_with("--archetype="):
			archetype = s.trim_prefix("--archetype=")
	print("[SOAK] start — runs=%d archetype=%s" % [runs, archetype])
	# Préserve la sauvegarde RÉELLE du joueur (review HIGH) : le cas S5 écrit/efface
	# user://merlin_run.json — snapshot avant la campagne, restauration après.
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""
	var t0: int = Time.get_ticks_msec()
	for i in runs:
		var arch: String = archetype
		if archetype == "mixed":
			arch = str(ARCHETYPES[i % ARCHETYPES.size()])
		_soak_one(i, arch)
	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
			print("[SOAK] sauvegarde joueur restaurée")
	var dt: float = float(Time.get_ticks_msec() - t0) / 1000.0
	print("[SOAK] ends=%s" % str(_ends))
	print("[SOAK] degrees=%s" % str(_degrees))
	print("[SOAK] drafts %d/%d pris · secours injectées=%d" % [_drafts_taken, _drafts_offered, _secours_injected])
	print("[SOAK] DONE — %d/%d PASS (%.1fs)" % [runs - _fail, runs, dt])
	quit(1 if _fail > 0 else 0)


func _soak_one(i: int, arch: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (i + 1)
	var run: Node = RunScript.new()
	run._rng.seed = 1000 + i  # runs variés ET reproductibles (hors arbre : pas de randomize())
	run.new_run(_skel(i))
	var resume_tested: bool = false

	# Cas dégénérés forcés (cycle) — la fiabilité doit tenir AUSSI là.
	if i % 7 == 3:
		run.corruption = 16  # proche du cap 18 → fins « corrompu » + injections de Murmures
	if i % 11 == 5:
		run.integrite = 2    # chemins de mort
	if i % 13 == 8:
		run.deck = []
		run.discard = []
		run.hand = []        # pool anéanti → ensure_playable_hand DOIT injecter des secours

	var guard: int = 0
	while not run.ended and guard < GUARD_BEATS:
		guard += 1
		run.ensure_playable_hand()  # invariant Fix 5 : main jouable à CHAQUE début de beat
		if not _check(run.hand.size() >= 2, i, "main jouable (%d)" % run.hand.size(), run):
			break
		for c in run.hand:
			if str(c.id).begins_with("secours_"):
				_secours_injected += 1
		var beat: Dictionary = run.current_beat()
		var btype: String = str(beat.get("type", "Exploration"))
		var diff: int = int(beat.get("difficulte", 1))
		var required: Array = Scenario.TYPE_TAG_BIAS.get(btype, ["Sens"]).slice(0, diff)
		var combo: Array = _pick_combo(arch, run.hand, required, rng)
		var res: Dictionary = MerlinResolution.resolve(required, combo, [])
		var deg: String = str(res.get("degree", ""))
		_degrees[deg] = int(_degrees.get(deg, 0)) + 1
		run.play_and_discard(combo)
		run.apply_card_effects(combo)
		run.apply_resolution(res)
		# Draft logique (mêmes conditions que merlin_game._on_resolve)
		if (deg == MerlinResolution.REUSSITE or deg == MerlinResolution.ECLATANTE) \
				and not run.is_climax() and not run.ended:
			var choices: Array = run.draft_choices(3)
			if not choices.is_empty():
				_drafts_offered += 1
				if rng.randf() < 0.7:
					run.add_card_to_deck(choices[rng.randi_range(0, choices.size() - 1)])
					_drafts_taken += 1
		# Invariants après CHAQUE beat.
		if not _invariants(run, i):
			break
		if not run.ended:
			run.advance_beat()
			# Cas S5 (Fix 6) : save au début de beat → reprise = MÊME état, coûts jamais rejoués.
			if not resume_tested and i % 17 == 2 and not run.ended:
				resume_tested = true
				_check_resume(run, i)
	_check(run.ended, i, "run terminée (guard=%d)" % guard, run)
	if run.ended:
		_ends[run.end_type] = int(_ends.get(run.end_type, 0)) + 1
	run.clear_save()
	run.free()


func _check(cond: bool, i: int, label: String, run: Node) -> bool:
	if not cond:
		_fail += 1
		print("[SOAK]   FAIL run#%d — %s (PV=%d Corr=%d beat=%d ended=%s)" % [
			i, label, run.integrite, run.corruption, run.beat_index, str(run.ended)])
	return cond


func _invariants(run: Node, i: int) -> bool:
	if not _check(run.integrite >= 0 and run.integrite <= run._max_integrite(), i,
			"integrite bornée (%d)" % run.integrite, run):
		return false
	if not _check(run.corruption >= 0, i, "corruption >= 0 (%d)" % run.corruption, run):
		return false
	var cap: int = run._hand_size() + run.HAND_CAP_EXTRA
	if not _check(run.hand.size() <= cap, i, "main <= %d (%d)" % [cap, run.hand.size()], run):
		return false
	# Unicité des ids sur TOUT le pool (deck + main + défausse) — drafts/injections compris.
	var seen: Dictionary = {}
	for c in run.deck + run.hand + run.discard:
		var cid: String = str(c.id)
		if seen.has(cid):
			return _check(false, i, "id dupliqué '%s'" % cid, run)
		seen[cid] = true
	return true


# Reprise S5 : save() (déjà fait par l'appelant au début de beat) → load dans une instance NEUVE →
# l'état repris est IDENTIQUE (pas de coûts rejoués, pioche/défausse conservées).
func _check_resume(run: Node, i: int) -> void:
	run.save()
	var run2: Node = RunScript.new()
	var ok: bool = run2.load_run()
	if _check(ok, i, "load_run() OK", run):
		_check(run2.integrite == run.integrite, i,
			"resume integrite %d==%d" % [run2.integrite, run.integrite], run)
		_check(run2.corruption == run.corruption, i,
			"resume corruption %d==%d" % [run2.corruption, run.corruption], run)
		_check(run2.beat_index == run.beat_index, i,
			"resume beat %d==%d" % [run2.beat_index, run.beat_index], run)
		var pool_a: int = run.deck.size() + run.hand.size() + run.discard.size()
		var pool_b: int = run2.deck.size() + run2.hand.size() + run2.discard.size()
		_check(pool_a == pool_b, i, "resume pool %d==%d" % [pool_b, pool_a], run)
	run2.free()


func _pick_combo(arch: String, hand: Array, required: Array, rng: RandomNumberGenerator) -> Array:
	var scored: Array = []
	for card in hand:
		var cov: Dictionary = MerlinTags.coverage(required, card.tags)
		scored.append({"card": card, "cov": cov["covered"].size()})
	match arch:
		"optimal":
			scored.sort_custom(func(a, b): return a["cov"] > b["cov"])
		"greedy":
			var rar_rank: Dictionary = {"Commune": 0, "Rare": 1, "Épique": 2, "Mythique": 3}
			scored.sort_custom(func(a, b):
				return int(rar_rank.get(a["card"].rarity, 0)) > int(rar_rank.get(b["card"].rarity, 0)))
		"corrompu":
			scored.sort_custom(func(a, b): return a["card"].corruption > b["card"].corruption)
		"tag_ignorant":
			scored.sort_custom(func(a, b): return a["cov"] < b["cov"])
		_:
			# chaotic : mélange Fisher-Yates seedé
			for k in range(scored.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, k)
				var tmp: Variant = scored[k]
				scored[k] = scored[j]
				scored[j] = tmp
	var combo: Array = []
	for s in scored:
		combo.append(s["card"])
		if combo.size() == 2:
			break
	return combo


func _skel(i: int) -> Dictionary:
	var beats: Array = []
	var types: Array = ["Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax"]
	var diffs: Array = [1, 2, 2, 2, 3]
	for k in types.size():
		beats.append({"n": k + 1, "type": types[k], "difficulte": diffs[k]})
	return {"title": "Soak #%d" % i, "synopsis": "Probe", "beats": beats, "total": beats.size()}
