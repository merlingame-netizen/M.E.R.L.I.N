extends SceneTree
## Soak Monte Carlo v11 (pivot ACTION+TRAIT, spec panel 2026-07-04 §K) — N runs logiques COMPLETS,
## sans LLM ni UI. Preuve mesurable R109 : chaque run atteint une fin, zéro erreur script,
## invariants tenus à chaque beat. Le geste v11 = [ACTION permanente (4 tuiles), TRAIT (main de 4)] ;
## la main de traits est REDISTRIBUÉE à chaque beat (redraw_hand, cycle vrai) ; cas dégénérés
## forcés (pool anéanti, corruption au cap, intégrité minimale) + save/resume S5 (R108).
##   Godot --headless --path . --script res://tools/probe_soak.gd -- --runs=200 --archetype=mixed
## Sortie : [SOAK] ... + ligne finale « [SOAK] DONE — N/N PASS » ; exit 1 si le moindre échec.
##
## RÈGLE tools/ : DUCK-TYPING uniquement — zéro référence class_name (compile-order : --script se
## charge AVANT les autoloads). Tout passe par les scripts préchargés ci-dessous.
##
## ASSERTIONS DURES (font échouer le soak) : invariants (jauges bornées, 4 actions permanentes,
## main ≥ 1 trait, cap 1 corrompu/main R113, ids uniques, run terminée R93, resume R108) +
## 0 beat à requis hors-pool (whitelist spec §F) + émission des tags ×1 bornée à 1 beat/quête.
## Les CIBLES de distribution §K sont LOGUÉES avec verdict IN/OUT par bande mais ne font PAS
## échouer le run (recalibrage W2/W3 assumé — guardrail « période transitoire »).

const RunScript := preload("res://scripts/game/merlin_run.gd")
const Scenario := preload("res://scripts/llm/merlin_scenario.gd")
const ResolutionScript := preload("res://scripts/game/merlin_resolution.gd")
const TagsScript := preload("res://scripts/game/merlin_tags.gd")
const CardScript := preload("res://scripts/game/merlin_card.gd")

const ARCHETYPES: Array = ["optimal", "greedy", "chaotic", "corrompu", "tag_ignorant"]
const GUARD_BEATS: int = 90  # filet anti-boucle (chaîne de quêtes : jusqu'à 15 beats)

var _fail: int = 0
var _runs_total: int = 0
var _clean_runs: int = 0          # runs SANS cas dégénéré forcé (base des cibles §K)
var _ends: Dictionary = {}
var _ends_clean: Dictionary = {}
var _degrees: Dictionary = {}
var _degrees_clean: Dictionary = {}
var _beats_total: int = 0
var _beats_clean: int = 0
var _drafts_offered: int = 0
var _drafts_taken: int = 0
var _pushes: int = 0              # v10.21 (R130) : « Pousser » simulés, toutes runs
var _pushes_clean: int = 0
var _corr_gained_clean: int = 0   # somme des Δcorruption positifs par beat (runs saines)
var _offpool_beats: int = 0       # beats à requis ENTIÈREMENT hors-pool (assertion dure : 0)
var _deadhand_beats: int = 0      # beats où AUCUN trait de la main ne couvre un requis (info §C)
var _climax_beats: int = 0        # beats difficulté 3 (3 requis)
var _climax_full: int = 0         # ... dont couverture pleine (§K : 45-55 %)
var _variant_swaps: int = 0       # ramification v1 mesurée (§K : fréquence loguée)
var _secours_injected: int = 0
var _x1_emissions: Dictionary = {}  # tag ×1 -> nb d'émissions (Franchise/Mystère/Rituel...)
var _arch_stats: Dictionary = {}    # arch -> {"degrees": {}, "ends": {}, "runs": 0}


func _init() -> void:
	var runs: int = 200
	var archetype: String = "mixed"
	var per_arch: bool = false  # 5 × N runs, stats par archétype
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--runs="):
			runs = maxi(1, int(s.trim_prefix("--runs=")))
		elif s.begins_with("--archetype="):
			archetype = s.trim_prefix("--archetype=")
		elif s == "--per-archetype":
			per_arch = true
	print("[SOAK] start v11 — runs=%d archetype=%s per_arch=%s" % [runs, archetype, str(per_arch)])
	_selftest_whitelist()  # plomberie spec §F éprouvée AVANT la campagne (validation LLM incluse)
	# Préserve la sauvegarde RÉELLE du joueur : le cas S5 écrit/efface user://merlin_run.json —
	# snapshot avant la campagne, restauration après.
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""
	var t0: int = Time.get_ticks_msec()
	if per_arch:
		var idx: int = 0
		for arch_name in ARCHETYPES:
			for _i in runs:
				_soak_one(idx, str(arch_name))
				idx += 1
	else:
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
	var total_runs: int = runs * (ARCHETYPES.size() if per_arch else 1)
	print("[SOAK] ends=%s (toutes runs)" % str(_ends))
	print("[SOAK] degrees=%s (toutes runs, %d beats)" % [str(_degrees), _beats_total])
	print("[SOAK] drafts %d/%d pris · secours injectées=%d · pushes R130=%d" % [_drafts_taken, _drafts_offered, _secours_injected, _pushes])
	_report_k()
	_report_arch()
	print("[SOAK] DONE — %d/%d PASS (%.1fs)" % [total_runs - _fail, total_runs, dt])
	quit(1 if _fail > 0 else 0)


# --- Self-test whitelist (spec §F) : le pool, les gardes et la validation LLM, hors campagne. ---
func _selftest_whitelist() -> void:
	var pool: Dictionary = Scenario.build_tag_pool(CardScript.make_actions(), CardScript.starter_traits())
	var allowed: Dictionary = pool.get("allowed", {})
	var base: Array = pool.get("base", [])
	var x1: Array = pool.get("x1", [])
	_st(base.size() == 8, "8 tags de base d'actions (mesuré %d)" % base.size())
	_st(not allowed.has("sacrifice") and not allowed.has("equilibre"),
		"Sacrifice/Équilibre jamais requérables sans greffe")
	_st(not allowed.has("vide") and not allowed.has("murmure") and not allowed.has("emprise"),
		"tags Corrompus jamais requérables")
	_st(x1.has("franchise") and x1.has("mystere") and x1.has("rituel"),
		"tags ×1 détectés par comptage dynamique (%s)" % str(x1))
	# Validation LLM : tag inventé → remplacé par le fallback du MÊME index, résultat in-pool.
	var fixed: Array = Scenario.validate_required_tags(["Dragon", "Sens"], 0, pool)
	var ok_fix: bool = not fixed.is_empty()
	for t in fixed:
		if not allowed.has(TagsScript.to_canon(str(t))):
			ok_fix = false
	_st(ok_fix, "arc_tags hors-pool remplacés in-pool (%s)" % str(fixed))
	# W3-proof : un tag GREFFÉ (au-delà des 2 tags de base d'une action) entre dans le pool.
	var acts: Array = CardScript.make_actions()
	acts[1].tags.append("Sacrifice")
	var pool2: Dictionary = Scenario.build_tag_pool(acts, CardScript.starter_traits())
	var allowed2: Dictionary = pool2.get("allowed", {})
	_st(allowed2.has("sacrifice"), "greffe Sacrifice → tag requérable (W3)")
	print("[SOAK] self-test §F : pool base=%s gap=%s x1=%s" % [str(base), str(pool.get("gap", [])), str(x1)])


func _st(cond: bool, label: String) -> void:
	if not cond:
		_fail += 1
		print("[SOAK]   FAIL self-test — %s" % label)


func _ensure_arch(arch: String) -> void:
	if not _arch_stats.has(arch):
		_arch_stats[arch] = {"degrees": {}, "ends": {}, "runs": 0}


func _bump_arch(arch: String, kind: String, key: String) -> void:
	_ensure_arch(arch)
	var d: Dictionary = _arch_stats[arch][kind]
	d[key] = int(d.get(key, 0)) + 1


func _soak_one(i: int, arch: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (i + 1)
	var run: Node = RunScript.new()
	run._rng.seed = 1000 + i  # runs variés ET reproductibles (hors arbre : pas de randomize())
	run.new_run(_skel(i))
	var resume_tested: bool = false
	_runs_total += 1
	_ensure_arch(arch)
	_arch_stats[arch]["runs"] = int(_arch_stats[arch]["runs"]) + 1

	# Cas dégénérés forcés (cycle) — la fiabilité doit tenir AUSSI là. Ces runs sont EXCLUES de la
	# base des cibles §K (elles fausseraient morts/fins corrompues par construction).
	var forced: bool = (i % 7 == 3) or (i % 11 == 5) or (i % 13 == 8)
	if i % 7 == 3:
		run.corruption = 16  # proche du cap 18 → fins « corrompu » + injections de traits corrompus
	if i % 11 == 5:
		run.integrite = 2    # chemins de mort
	if i % 13 == 8:
		run.deck = []
		run.discard = []
		run.hand = []        # pool anéanti → redraw_hand DOIT injecter une trait de secours

	var x1_used_by_quest: Dictionary = {}  # quest_idx -> Array[canon] (émission ×1 bornée/quête)
	var x1_seen: Dictionary = {}           # "quest|tag" -> occurrences (assertion dure)
	var push_flip: bool = (i % 2 == 0)     # « les autres alternent » (R130) : phase initiale variée
	var corr_gained_run: int = 0
	var run_pushes: int = 0

	var guard: int = 0
	while not run.ended and guard < GUARD_BEATS:
		guard += 1
		# v11 (spec §C) : REDRAW COMPLET de la main de traits au début de CHAQUE beat (cycle vrai).
		run.redraw_hand()
		if not _check(run.actions.size() == 4, i, "4 actions permanentes (%d)" % run.actions.size(), run):
			break
		if not _check(run.hand.size() >= 1, i, "main de traits >= 1 (%d)" % run.hand.size(), run):
			break
		# Cap R113 CONDITIONNEL : ≤1 corrompu SAUF si le cycle est SATURÉ (aucun trait sain en
		# réserve deck+défausse — cas dégénéré « pool anéanti » où l'enforce garde l'excédent,
		# comportement défini de merlin_run._enforce_hand_caps ; le jeu ne peut pas faire mieux).
		var spare_clean: bool = false
		for sc_c in run.deck + run.discard:
			if sc_c is Object and sc_c.has_method("is_corrupted_trait") and not sc_c.is_corrupted_trait():
				spare_clean = true
				break
		if not _check(run._corrupted_in_hand() <= run.MAX_CORRUPTED_IN_HAND or not spare_clean, i,
				"cap %d trait corrompu/main (%d, sain dispo=%s)" % [
					run.MAX_CORRUPTED_IN_HAND, run._corrupted_in_hand(), str(spare_clean)], run):
			break
		for c in run.hand:
			if str(c.id).begins_with("secours_"):
				_secours_injected += 1
		var corr_before: int = run.corruption
		var beat: Dictionary = run.current_beat()
		var btype: String = str(beat.get("type", "Exploration"))
		var diff: int = int(beat.get("difficulte", 2))
		var quest_idx: int = int(beat.get("quest", 0))
		if bool(beat.get("swapped", false)):
			_variant_swaps += 1  # ramification v1 : fréquence loguée (§K)
		# v11 (spec §F) — MIROIR du jeu : requis tirés du POOL GÉNÉRABLE (whitelist), composition
		# par difficulté, ×1 borné 1 beat/quête. MÊME code statique que merlin_scenario (zéro drift).
		var pool_info: Dictionary = Scenario.build_tag_pool(run.actions, run.deck + run.hand + run.discard)
		if not x1_used_by_quest.has(quest_idx):
			x1_used_by_quest[quest_idx] = []
		var required: Array = Scenario.pick_required_tags(btype, diff, pool_info, rng, x1_used_by_quest[quest_idx])
		_assert_required(required, pool_info, x1_seen, quest_idx, i, run)
		# v10.21 (Wave I, R131) — miroir des INTERVENTIONS : planifiées à la Rencontre, appliquées au
		# beat cible. v11 : la bénédiction se pose sur UNE ACTION (tuile permanente, spec §G) — le
		# canal bonus_tags de resolve est inchangé (R120/R131).
		if btype == "Rencontre" and run.intervention_beats.is_empty() and int(run.pilier_interventions) == 0:
			var t1: int = run.beat_index + 1 + rng.randi_range(0, 1)
			if t1 < int(run.scenario.get("total", 5)) - 1:
				run.intervention_beats.append(t1)
		if run.intervention_beats.has(run.beat_index) and int(run.pilier_interventions) < 2:
			run.intervention_beats.erase(run.beat_index)
			run.pilier_interventions += 1
			var ipk: String = _soak_draw_pilier(rng)
			var target: Variant = run.actions[rng.randi_range(0, run.actions.size() - 1)]
			if ipk == "choeur" or ipk == "chevalier" or ipk == "enfant":
				var btag: String = "Nature" if ipk == "choeur" else "Force"
				if ipk == "enfant" and not required.is_empty():
					btag = str(required[0])  # l'Enfant offre un tag REQUIS (R131)
				run.blessed_tags[str(target.id)] = btag
			else:  # etre / compagnon : pacte opt-in selon la politique d'archétype
				var take_pact: bool = arch == "greedy" or arch == "corrompu" \
					or (arch == "optimal" and (run.corruption % 5) <= 2) \
					or (arch == "chaotic" and rng.randf() < 0.5)
				if take_pact:
					if ipk == "compagnon":
						run.draw_extra(1)
					elif not required.is_empty():
						run.blessed_tags[str(target.id)] = str(required[0])
					run.add_corruption(1)
		# Deadhand (info spec §C) : aucun trait de la main ne couvre le moindre requis.
		var best_cov: int = 0
		for tr in run.hand:
			var cvd: Dictionary = TagsScript.coverage(required, tr.tags)
			var cvd_arr: Array = cvd["covered"]
			best_cov = maxi(best_cov, cvd_arr.size())
		if best_cov == 0:
			_deadhand_beats += 1
		# v11 : dé PRÉ-TIRÉ du beat AVANT le choix (miroir build_situation — R120 preview=résolution).
		var die: int = rng.randi_range(1, 6)
		var combo: Array = _pick_combo(arch, run, required, die, rng)
		var res: Dictionary = ResolutionScript.resolve(required, combo, [], die, run.blessed_bonus(combo))
		run.consume_blessings(combo)  # R131 : une bénédiction sert UNE fois (miroir du jeu)
		# v10.21 (Wave G, R130) — miroir « Pousser » : optimal pousse si Intégrité ≤ 4 ;
		# corrompu toujours ; greedy/chaotic/tag_ignorant ALTERNENT (spec v11-W2).
		if str(res.get("degree", "")) == ResolutionScript.PARTIEL and int(run.pushes_left_quest) > 0:
			var wants: bool = false
			match arch:
				"optimal":
					wants = run.integrite <= 4
				"corrompu":
					wants = true
				_:
					wants = push_flip
					push_flip = not push_flip
			if wants:
				res = res.duplicate(true)
				res["degree"] = ResolutionScript.REUSSITE
				res["integrite_delta"] = 0
				res["corruption_delta"] = int(res.get("corruption_delta", 0)) + ResolutionScript.PUSH_PRICE
				run.pushes_left_quest -= 1
				_pushes += 1
				run_pushes += 1
		var deg: String = str(res.get("degree", ""))
		_degrees[deg] = int(_degrees.get(deg, 0)) + 1
		_beats_total += 1
		if not forced:
			_degrees_clean[deg] = int(_degrees_clean.get(deg, 0)) + 1
			_beats_clean += 1
		_bump_arch(arch, "degrees", deg)
		if diff >= 3:
			_climax_beats += 1
			var cov_res: Dictionary = res["coverage"]
			var missing_arr: Array = cov_res["missing"]
			if missing_arr.is_empty():
				_climax_full += 1
		run.play_and_discard(combo)
		run.apply_card_effects(combo)
		run.apply_resolution(res)
		# Wave D — offrande du PILIER au beat Rencontre : 1×/run, REMPLACE le draft standard ce beat.
		# W2 transitoire : la banque offre des cartes legacy qui rejoignent le deck de TRAITS (leurs
		# tags entrent dans la whitelist ; Sacrifice/Équilibre/Corrompus restent gardés côté pool).
		var did_offering: bool = false
		if btype == "Rencontre" and not run.pilier_offering_done and not run.ended:
			run.pilier_offering_done = true
			var offer: Array = run.pilier_offering(_soak_draw_pilier(rng), 2)
			if not offer.is_empty():
				did_offering = true
				_drafts_offered += 1
				if rng.randf() < 0.7:
					run.add_card_to_deck(offer[rng.randi_range(0, offer.size() - 1)])
					_drafts_taken += 1
		# Draft logique standard (mêmes conditions que merlin_game._on_resolve) — sauté si offrande.
		if not did_offering and (deg == ResolutionScript.REUSSITE or deg == ResolutionScript.ECLATANTE) \
				and not run.is_climax() and not run.ended:
			var choices: Array = run.draft_choices(3)
			if not choices.is_empty():
				_drafts_offered += 1
				if rng.randf() < 0.7:
					run.add_card_to_deck(choices[rng.randi_range(0, choices.size() - 1)])
					_drafts_taken += 1
		# Corruption GAGNÉE sur le beat (net positif : résolution + pactes − purges du même beat).
		var dcorr: int = run.corruption - corr_before
		if dcorr > 0:
			corr_gained_run += dcorr
		# Invariants après CHAQUE beat.
		if not _invariants(run, i):
			break
		if not run.ended:
			run.advance_beat()
			# Cas S5 : save au début de beat → reprise = MÊME état, coûts jamais rejoués (R108).
			if not resume_tested and i % 17 == 2 and not run.ended:
				resume_tested = true
				_check_resume(run, i)
	_check(run.ended, i, "run terminée (guard=%d)" % guard, run)
	if run.ended:
		_ends[run.end_type] = int(_ends.get(run.end_type, 0)) + 1
		_bump_arch(arch, "ends", run.end_type)
		if not forced:
			_clean_runs += 1
			_ends_clean[run.end_type] = int(_ends_clean.get(run.end_type, 0)) + 1
			_pushes_clean += run_pushes
			_corr_gained_clean += corr_gained_run
	run.clear_save()
	run.free()


# Assertion DURE spec §F : chaque tag requis est dans le pool générable ; les tags ×1 ne sont
# émis qu'une fois par quête. Compte aussi les beats ENTIÈREMENT hors-pool (métrique officielle §K).
func _assert_required(required: Array, pool_info: Dictionary, x1_seen: Dictionary, quest_idx: int, i: int, run: Node) -> void:
	var allowed: Dictionary = pool_info.get("allowed", {})
	var x1: Array = pool_info.get("x1", [])
	var off: int = 0
	for t in required:
		var c: String = TagsScript.to_canon(str(t))
		if not allowed.has(c):
			off += 1
		if x1.has(c):
			var key: String = "%d|%s" % [quest_idx, c]
			x1_seen[key] = int(x1_seen.get(key, 0)) + 1
			_check(int(x1_seen[key]) <= 1, i,
				"tag ×1 '%s' émis %d fois dans la quête %d" % [c, int(x1_seen[key]), quest_idx], run)
			_x1_emissions[c] = int(_x1_emissions.get(c, 0)) + 1
	if off > 0 and off == required.size():
		_offpool_beats += 1
	_check(off == 0, i, "tags requis hors-pool : %s" % str(required), run)
	_check(not required.is_empty(), i, "requis non vide", run)


# Wave D — tire le pilier de l'offrande aux poids de MerlinScenario (faction 30/30/30/8 → choeur/
# etre/chevalier/compagnon) + wildcard L'Enfant ~12% (surcharge). Reproductible (rng seedé).
func _soak_draw_pilier(rng: RandomNumberGenerator) -> String:
	if rng.randf() < 0.12:
		return "enfant"
	var roll: int = rng.randi_range(1, 98)
	if roll <= 30:
		return "choeur"
	if roll <= 60:
		return "etre"
	if roll <= 90:
		return "chevalier"
	return "compagnon"


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
	# Unicité des ids sur TOUT le pool (actions + deck + main + défausse) — drafts/injections compris.
	var seen: Dictionary = {}
	for c in run.actions + run.deck + run.hand + run.discard:
		var cid: String = str(c.id)
		if seen.has(cid):
			return _check(false, i, "id dupliqué '%s'" % cid, run)
		seen[cid] = true
	return true


# Reprise S5 : save() → load dans une instance NEUVE → l'état repris est IDENTIQUE (pas de coûts
# rejoués, actions + pioche/défausse conservées). Save v2 (les v10.x sont invalidées par load_run).
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
		_check(run2.actions.size() == run.actions.size(), i,
			"resume actions %d==%d" % [run2.actions.size(), run.actions.size()], run)
		var pool_a: int = run.deck.size() + run.hand.size() + run.discard.size()
		var pool_b: int = run2.deck.size() + run2.hand.size() + run2.discard.size()
		_check(pool_a == pool_b, i, "resume pool %d==%d" % [pool_b, pool_a], run)
	run2.free()


# --- POLITIQUES par archétype (spec v11-W2) : le geste = [ACTION permanente, TRAIT de la main]. ---
# optimal      : maximise la couverture des requis ; départage synergie, puis dé (die_mod).
# greedy       : maximise les tags totaux joués (couverts + extras) ; départage dé, puis synergie.
# corrompu     : préfère le trait corrompu/coûteux ; le verbe lui importe peu (aléatoire).
# chaotic      : uniforme aléatoire (action ET trait).
# tag_ignorant : aléatoire SANS lire les requis — baseline non-lecteur, flux RNG distinct de
#                chaotic (mesure la sensibilité du système au non-signal).
func _pick_combo(arch: String, run: Node, required: Array, die: int, rng: RandomNumberGenerator) -> Array:
	var acts: Array = run.actions.duplicate()
	var traits_h: Array = run.hand.duplicate()
	_shuffle_arr(acts, rng)      # départage des ex æquo : ordre pré-mélangé, argmax strict
	_shuffle_arr(traits_h, rng)
	match arch:
		"chaotic", "tag_ignorant":
			return [acts[0], traits_h[0]]
		"corrompu":
			var best_t: Variant = traits_h[0]
			var best_s: int = _corr_score(best_t)
			for t in traits_h:
				var s: int = _corr_score(t)
				if s > best_s:
					best_s = s
					best_t = t
			return [acts[0], best_t]
	# optimal / greedy : évaluation des 16 paires par resolve à blanc — le joueur VOIT la preview
	# (couverture, synergie, dé) avant de confirmer (R120), le bot lit la même vérité.
	var best: Array = [acts[0], traits_h[0]]
	var best_key: Array = []
	for a in acts:
		for t in traits_h:
			var r: Dictionary = ResolutionScript.resolve(required, [a, t], [], die, run.blessed_bonus([a, t]))
			var cov: Dictionary = r["coverage"]
			var covered_arr: Array = cov["covered"]
			var extra_arr: Array = cov["extra"]
			var key: Array = []
			if arch == "optimal":
				key = [covered_arr.size(), int(r.get("synergy", 0)), int(r.get("die_mod", 0))]
			else:  # greedy
				key = [covered_arr.size() + extra_arr.size(), int(r.get("die_mod", 0)), int(r.get("synergy", 0))]
			if best_key.is_empty() or _key_gt(key, best_key):
				best_key = key
				best = [a, t]
	return best


# Score « corrompu/coûteux » d'un trait (duck-typé, zéro référence de classe).
func _corr_score(t: Variant) -> int:
	var s: int = 0
	if t is Object and "corruption" in t:
		s += int(t.corruption) * 2
	if t is Object and t.has_method("is_corrupted_trait") and t.is_corrupted_trait():
		s += 1
	return s


# Comparaison lexicographique stricte de clés de score (Array d'ints).
func _key_gt(a: Array, b: Array) -> bool:
	for k in a.size():
		if k >= b.size():
			return true
		var av: int = int(a[k])
		var bv: int = int(b[k])
		if av != bv:
			return av > bv
	return false


func _shuffle_arr(arr: Array, rng: RandomNumberGenerator) -> void:
	for k in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var tmp: Variant = arr[k]
		arr[k] = arr[j]
		arr[j] = tmp


# --- RAPPORT §K (cibles LOGUÉES, non bloquantes — recalibrage W2/W3 assumé) ---
func _report_k() -> void:
	var bt: float = float(maxi(_beats_clean, 1))
	var cr: float = float(maxi(_clean_runs, 1))
	print("[SOAK] — CIBLES §K v11 (runs saines n=%d, beats=%d — cas dégénérés forcés exclus ; LOGUÉ, ne bloque pas) —" % [_clean_runs, _beats_clean])
	_band("échec", 100.0 * float(int(_degrees_clean.get("echec", 0))) / bt, 3.0, 8.0)
	_band("partiel", 100.0 * float(int(_degrees_clean.get("partiel", 0))) / bt, 28.0, 38.0)
	_band("réussite", 100.0 * float(int(_degrees_clean.get("reussite", 0))) / bt, 45.0, 55.0)
	_band("éclatante", 100.0 * float(int(_degrees_clean.get("eclatante", 0))) / bt, 8.0, 15.0)
	_band("morts", 100.0 * float(int(_ends_clean.get("mort", 0))) / cr, 10.0, 25.0)
	_band("fins corrompues", 100.0 * float(int(_ends_clean.get("corrompu", 0))) / cr, 0.0, 18.0)
	_band("pushes/run", float(_pushes_clean) / cr, 0.5, 1.5, false)
	_band("corruption gagnée/run", float(_corr_gained_clean) / cr, 3.9, 6.9, false)
	if _climax_beats > 0:
		_band("couverture pleine climax (3 requis)", 100.0 * float(_climax_full) / float(_climax_beats), 45.0, 55.0)
	print("[SOAK]   %-36s %5d     (ASSERTION DURE == 0)" % ["beats à requis hors-pool", _offpool_beats])
	print("[SOAK]   %-36s %5.1f%%   (info §C : A/B réserve de trait si > 45)" % ["deadhand (0 trait couvrant)", 100.0 * float(_deadhand_beats) / float(maxi(_beats_total, 1))])
	print("[SOAK]   variantes basculées=%d · sabotage R66 non simulé (aucun antagoniste côté probe) · émissions ×1=%s" % [_variant_swaps, str(_x1_emissions)])


func _band(label: String, value: float, lo: float, hi: float, pct: bool = true) -> void:
	var v: String = ("%5.1f%%" % value) if pct else ("%5.2f " % value)
	var cible: String = ("%.0f-%.0f%%" % [lo, hi]) if pct else ("%.1f-%.1f" % [lo, hi])
	var verdict: String = "IN " if value >= lo and value <= hi else "OUT"
	print("[SOAK]   %-36s %s   cible %-8s [%s]" % [label, v, cible, verdict])


# Rapport par archétype (informatif — le signal canonique reste `optimal`, joueur qui lit les tags).
func _report_arch() -> void:
	if _arch_stats.is_empty():
		return
	print("[SOAK] — PAR ARCHÉTYPE (informatif, toutes runs — v11 action×trait) —")
	for arch in _arch_stats:
		var st: Dictionary = _arch_stats[arch]
		var degs: Dictionary = st["degrees"]
		var tot_deg: int = 0
		for k in degs:
			tot_deg += int(degs[k])
		var td: float = float(maxi(tot_deg, 1))
		var ends: Dictionary = st["ends"]
		var tot_end: int = 0
		for k in ends:
			tot_end += int(ends[k])
		var morts: float = float(int(ends.get("mort", 0))) / float(maxi(tot_end, 1))
		print("[SOAK]   %-12s runs=%-4d e=%4.1f%% p=%4.1f%% r=%4.1f%% ec=%4.1f%% · morts=%5.1f%% · ends=%s" % [
			str(arch), int(st["runs"]),
			100.0 * float(int(degs.get("echec", 0))) / td,
			100.0 * float(int(degs.get("partiel", 0))) / td,
			100.0 * float(int(degs.get("reussite", 0))) / td,
			100.0 * float(int(degs.get("eclatante", 0))) / td,
			morts * 100.0, str(ends)])


func _skel(i: int) -> Dictionary:
	# MIROIR du jeu : chaîne de 2-3 quêtes (40/60) via le constructeur statique canonique
	# (zéro drift harnais↔jeu), rng seedé local → reproductible.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4241 * (i + 1)
	var nq: int = 2 if rng.randf() < 0.4 else 3
	var quests: Array = []
	for q in nq:
		quests.append({"title": "Soak #%d Q%d" % [i, q + 1], "pitch": "Probe"})
	var beats: Array = Scenario.build_chain_beats(quests, rng)
	return {"title": "Soak #%d" % i, "synopsis": "Probe", "beats": beats,
			"total": beats.size(), "quests": nq}
