extends SceneTree
## v2-W3 (2026-07-05) — GREFFES « roll » : graft_bonus = somme des greffes kind=="roll" posées sur
## l'action jouée (run.graft_roll_bonus), passé à resolve() aux DEUX call-sites (résolution + preview
## du bot, R120). talent (W2) et greffes-jet (W3) STACKENT sur le total → §K re-dérivé (leviers infra).
## v2-W1 (2026-07-05) — MOTEUR d20-vs-DC : le dé du beat est un d20 (randi_range 1-20) ; resolve()
## calcule total = die + skill_mod + graft_bonus + COVER_PER_TAG×couverts + synergy_bonus,
## comparé à DC_BY_DIFF. §K RE-DÉRIVÉ par leviers (DC_BY_DIFF {11,15,18}, PARTIEL_LOW 13,
## ECLAT_MARGIN 8) — 4 bandes de degrés IN à 300 (échec ~6 · partiel ~32 · réussite ~50 · éclatante
## ~11). HARD_DEGREE_BANDS reste false : échec IN mais marge modeste, on ne DURCIT pas encore (une
## variance de seed pourrait tiper échec à 8,x). Restes logués : pushes ~1,6 / corr ~7,2 (marginaux,
## couplés au volume de partiel via le push R130). Le visuel du dé reste d6 (projeté clampi 1-6) → W4.
##
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
## 0 beat à requis hors-pool (whitelist spec §F, CHEMIN RÉEL du jeu vérifié par self-test) +
## émission des tags ×1 bornée à 1 beat/quête + GATES DE MORTS PAR ARCHÉTYPE (BAL-04-B, v1.0-V4a).
## Les 4 bandes de degrés §K deviennent dures à l'atteinte (BAL-20-B, HARD_DEGREE_BANDS) ; les
## métriques de flux (pushes, drafts, deadhand, fins corrompues) restent LOGUÉES IN/OUT.

const RunScript := preload("res://scripts/game/merlin_run.gd")
const Scenario := preload("res://scripts/llm/merlin_scenario.gd")
const ResolutionScript := preload("res://scripts/game/merlin_resolution.gd")
const TagsScript := preload("res://scripts/game/merlin_tags.gd")
const CardScript := preload("res://scripts/game/merlin_card.gd")

const ARCHETYPES: Array = ["optimal", "greedy", "chaotic", "corrompu", "tag_ignorant"]
const GUARD_BEATS: int = 90  # filet anti-boucle (chaîne de quêtes : jusqu'à 15 beats)

# v1.0-V4a (BAL-20-B) — les 4 bandes de degrés deviennent DURES uniquement une fois ATTEINTES
# (mesure IN sur les 4). Tant que false : OUT logué avec le delta restant explicite, non-bloquant.
const HARD_DEGREE_BANDS: bool = false

var _fail: int = 0
var _gate_fail: int = 0           # v1.0-V4a : échecs de GATES §K (distincts des échecs de runs)
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
var _grafts_total: int = 0          # v11-W3 : greffes posées (toutes runs)
var _grafts_clean: int = 0          # ... runs saines (rapport §K : E[acquisitions] cible 5-6)
var _talent_nodes_taken: int = 0    # v2-W2 : nœuds de talent pris au draft (toutes runs, info §K)
var _talent_levels_sum: int = 0     # v2-W2 : somme des niveaux de talent en fin de run saine (moy. §K)
var _talent_runs: int = 0           # ... nb de runs saines sommées (dénominateur)


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
	_selftest_grafts()     # v11-W3 : banques, cap 3, dérivations, table de dé, prix one-shot
	_selftest_talent()     # v2-W2 : gain au degré, ciblage du nœud, cap/coût, skill_mod, save round-trip
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
	# v1.0-V4a — runs (fiabilité R109) et gates §K (équilibrage) comptés SÉPARÉMENT : un gate rouge
	# ne maquille pas le compte de runs, mais bloque quand même la sortie (exit 1).
	print("[SOAK] DONE — %d/%d PASS · gates §K durs : %d FAIL (%.1fs)" % [total_runs - _fail, total_runs, _gate_fail, dt])
	quit(1 if (_fail > 0 or _gate_fail > 0) else 0)


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
	# v1.0-V4a LEVIER 7b — un tag GREFFÉ passe en tête des candidats gap : requis dès diff 2.
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = 4242
	var req_g: Array = Scenario.pick_required_tags("Epreuve", 2, pool2, rng_g, [])
	var has_graft_req: bool = false
	for tg in req_g:
		if TagsScript.to_canon(str(tg)) == "sacrifice":
			has_graft_req = true
	_st(has_graft_req, "tag greffé prioritaire dans les requis (%s)" % str(req_g))
	# v1.0-V4a LEVIER 7a — retag du deck : les ×1 restent exactement {franchise, mystere, rituel}
	# et tous les autres tags gap restent ×2 (aucun tag ne devient orphelin ni ×1 par accident).
	var counts_st: Dictionary = pool.get("counts", {})
	for gtag in ["vigilance", "memoire", "endurance", "finesse", "ruse", "autorite", "vision"]:
		_st(int(counts_st.get(str(gtag), 0)) >= 2,
			"gap '%s' reste ×2 après retag (%d)" % [str(gtag), int(counts_st.get(str(gtag), 0))])
	_st((pool.get("x1", []) as Array).size() == 3, "exactement 3 tags ×1 après retag")
	# v1.0-V4a (BAL-14-A) — composition §F : un tirage pick_required_tags passe composition_ok, et
	# une paire base-only (ex-FALLBACK_ARC_TAGS) la VIOLE à diff 2 (elle serait re-tirée au présent).
	var rng_st := RandomNumberGenerator.new()
	rng_st.seed = 12345
	for d_st in [1, 2, 3]:
		var req_st: Array = Scenario.pick_required_tags("Epreuve", d_st, pool, rng_st, [])
		_st(Scenario.composition_ok(req_st, d_st, pool, []),
			"pick_required_tags diff %d respecte composition_ok (%s)" % [d_st, str(req_st)])
	_st(not Scenario.composition_ok(["Sens", "Instinct"], 2, pool, []),
		"paire base-only rejetée par composition_ok (diff 2)")
	# v2-W1 — barème d'échec PAR DIFFICULTÉ : −2 en diff 1-2, −3 en diff 3 (partiel/réussite/
	# éclatante inchangés, le push R130 garde sa valeur). Sous le moteur d20 on FORCE l'échec par
	# le plancher nat 1 (die=1 → ECHEC quels que soient couverture/mods) : test déterministe du barème.
	var cards_l8: Array = [CardScript.make_actions()[0]]
	_st(int(ResolutionScript.resolve(["Ruse", "Vision"], cards_l8, [], 1, [], 2).get("integrite_delta", 0)) == -2 \
		and int(ResolutionScript.resolve(["Ruse", "Vision"], cards_l8, [], 1, [], 3).get("integrite_delta", 0)) == -3 \
		and int(ResolutionScript.resolve(["Ruse", "Vision"], cards_l8, [], 1, [], 1).get("integrite_delta", 0)) == -2,
		"barème échec par difficulté (−2/−2/−3, nat 1 forcé)")
	# v2-W1 — planchers d20 : nat 1 → échec, nat 20 → éclatante (quels que soient les modificateurs).
	var act_l8: Variant = CardScript.make_actions()[0]
	_st(str(ResolutionScript.resolve(["Sens", "Savoir"], [act_l8], [], 1, [], 1).get("degree", "")) == ResolutionScript.ECHEC,
		"plancher nat 1 → échec")
	_st(str(ResolutionScript.resolve(["Ruse", "Vision"], [act_l8], [], 20, [], 3).get("degree", "")) == ResolutionScript.ECLATANTE,
		"plancher nat 20 → éclatante (même à diff 3, 0 couvert)")
	# v2-W1 — la MARGE décide entre les planchers : couverture pleine (2×COVER_PER_TAG) + jet médian
	# passe le DC de diff 2 ; jet faible sur 0 couverture échoue. Vérifie les clés total/dc/margin/success.
	var r_full: Dictionary = ResolutionScript.resolve(["Sens", "Savoir"], [act_l8], [], 10, [], 2)
	_st(bool(r_full.get("success", false)) and r_full.has("total") and r_full.has("dc") and r_full.has("margin"),
		"couverture pleine + d10 → succès (total=%d dc=%d)" % [int(r_full.get("total", 0)), int(r_full.get("dc", 0))])
	# v1.0-V4a (GD-32-B) — contre-pression §E : quête 3 (index 2) + ≥3 greffes → diff 3 ; sinon inchangé.
	_st(Scenario.effective_difficulty({"difficulte": 2, "quest": 2}, 3) == 3 \
		and Scenario.effective_difficulty({"difficulte": 2, "quest": 2}, 2) == 2 \
		and Scenario.effective_difficulty({"difficulte": 2, "quest": 1}, 5) == 2 \
		and Scenario.effective_difficulty({"difficulte": 3, "quest": 2}, 0) == 3,
		"effective_difficulty (contre-pression quête 3, seuil 3 greffes)")
	# v1.0-V4a (TEC-17-A) — le JEU passe par le MÊME chemin que le harnais (assertion anti-drift,
	# grep source) : build_situation appelle validate_required_tags + pick_required_tags +
	# composition_ok ; prepare_arc tire ses tags d'arc via pick_required_tags.
	var src: String = FileAccess.get_file_as_string("res://scripts/llm/merlin_scenario.gd")
	var bs0: int = src.find("func build_situation(")
	var bs1: int = src.find("\nfunc ", bs0 + 1)
	var bs_body: String = src.substr(bs0, bs1 - bs0) if (bs0 >= 0 and bs1 > bs0) else ""
	_st(bs_body.find("pick_required_tags(") >= 0 and bs_body.find("validate_required_tags(") >= 0 \
		and bs_body.find("composition_ok(") >= 0 and bs_body.find("effective_difficulty(") >= 0,
		"build_situation branché whitelist (pick + validate + composition + contre-pression)")
	var pa0: int = src.find("func prepare_arc(")
	var pa1: int = src.find("\nfunc ", pa0 + 1)
	var pa_body: String = src.substr(pa0, pa1 - pa0) if (pa0 >= 0 and pa1 > pa0) else ""
	_st(pa_body.find("pick_required_tags(") >= 0, "prepare_arc branché pool générable")
	print("[SOAK] self-test §F : pool base=%s gap=%s x1=%s" % [str(base), str(pool.get("gap", [])), str(x1)])


func _st(cond: bool, label: String) -> void:
	if not cond:
		_fail += 1
		print("[SOAK]   FAIL self-test — %s" % label)


# --- Self-test greffes (v11-W3, spec §E) : banques, guardrail corruption, dérivations, dé. ---
func _selftest_grafts() -> void:
	var seen: Dictionary = {}
	for pk in ["", "choeur", "etre", "compagnon", "chevalier", "enfant"]:
		var bank: Array = CardScript.graft_banks(str(pk))
		var min_n: int = 3 if str(pk) == "" else 2
		_st(bank.size() >= min_n, "banque '%s' >= %d greffes (%d)" % [str(pk), min_n, bank.size()])
		for g in bank:
			var gd: Dictionary = g
			var gid: String = str(gd.get("id", ""))
			_st(gid != "" and not seen.has(gid), "id de greffe unique '%s'" % gid)
			seen[gid] = true
			# GUARDRAIL CRITICAL : prix one-shot ≤ 1 — aucune greffe ne porte de coût récurrent.
			_st(int(gd.get("corr_cost", 0)) <= 1, "corr_cost <= 1 one-shot (%s)" % gid)
			var kind: String = str(gd.get("kind", ""))
			_st(kind == "tag" or kind == "roll" or kind == "charge", "kind valide (%s=%s)" % [gid, kind])
			if kind == "roll":  # v2-W3 : greffe « +N au jet » porte un amount >= 1 (graft_bonus)
				_st(int(gd.get("amount", 0)) >= 1, "greffe roll porte amount >= 1 (%s)" % gid)
			if kind == "tag":
				_st(str(gd.get("tag", "")) != "", "greffe tag porte un tag (%s)" % gid)
			if kind == "charge":
				_st(int(gd.get("charges", 0)) >= 1 and str(gd.get("effect_type", "")) != "",
					"charges valides (%s)" % gid)
	# Dérivations UNIQUES : rarity = f(nb greffes), tags = base + greffés, corruption JAMAIS récurrente.
	var act: Variant = CardScript.make_actions()[0]
	var etre_bank: Array = CardScript.graft_banks("etre")
	var gen_bank: Array = CardScript.graft_banks("")
	act.grafts.append(etre_bank[0])
	act.refresh_from_grafts()
	_st(str(act.rarity) == "Rare", "1 greffe -> Rare (%s)" % str(act.rarity))
	_st(int(act.corruption) == 0, "action greffée reste corruption 0 (récurrent interdit)")
	var atags: Array = act.tags
	_st(atags.size() == 3 and str(atags[2]) == str((etre_bank[0] as Dictionary).get("tag", "")),
		"tags = 2 base + greffé (%s)" % str(atags))
	act.grafts.append(gen_bank[0])
	act.grafts.append(gen_bank[1])
	act.refresh_from_grafts()
	_st(str(act.rarity) == "Mythique", "3 greffes -> Mythique (%s)" % str(act.rarity))
	# Round-trip save : grafts additifs dans to_dict/from_dict, dérivations rejouées au load.
	var act2: Variant = CardScript.from_dict(act.to_dict())
	_st((act2.grafts as Array).size() == 3 and str(act2.rarity) == "Mythique",
		"round-trip to_dict/from_dict conserve les greffes")
	# v2-W1 — MODÈLE d20 : DC_BY_DIFF présent et strictement croissant ; bandes de marge cohérentes
	# (PARTIEL_LOW ≥ 1, ECLAT_MARGIN > 0) ; COVER_PER_TAG et SYN positifs. Remplace le self-test
	# des DIE_BANDS (les bandes de rareté d6 n'existent plus : le dé est un vrai d20).
	var dc_by: Dictionary = ResolutionScript.DC_BY_DIFF
	_st(dc_by.has(1) and dc_by.has(2) and dc_by.has(3) \
		and int(dc_by[1]) < int(dc_by[2]) and int(dc_by[2]) < int(dc_by[3]),
		"DC_BY_DIFF présent et croissant (%s)" % str(dc_by))
	_st(int(ResolutionScript.PARTIEL_LOW) >= 1 and int(ResolutionScript.ECLAT_MARGIN) >= 1 \
		and int(ResolutionScript.COVER_PER_TAG) >= 1 and int(ResolutionScript.SYN) >= 1,
		"bandes/leviers d20 positifs (part_low=%d eclat=%d cover=%d syn=%d)" % [
			int(ResolutionScript.PARTIEL_LOW), int(ResolutionScript.ECLAT_MARGIN),
			int(ResolutionScript.COVER_PER_TAG), int(ResolutionScript.SYN)])
	# Cap 3/action + prix one-shot via une run réelle (API merlin_run).
	var run: Node = RunScript.new()
	run._rng.seed = 99
	run.new_run({"title": "st_grafts", "beats": [{"type": "Exploration", "n": 1}], "total": 1})
	var corr0: int = run.corruption
	_st(run.apply_graft("action_percevoir", etre_bank[1]), "apply_graft OK")
	_st(run.corruption == corr0 + int((etre_bank[1] as Dictionary).get("corr_cost", 0)),
		"prix one-shot payé à la pose (%d -> %d)" % [corr0, run.corruption])
	_st(run.apply_graft("action_percevoir", gen_bank[2]), "2e greffe OK")
	_st(run.apply_graft("action_percevoir", gen_bank[3]), "3e greffe OK")
	_st(not run.apply_graft("action_percevoir", gen_bank[4]), "cap 3/action -> refus de la 4e")
	var picks: Array = run.graft_choices(3)
	var placed: Dictionary = run.placed_graft_ids()
	_st(placed.size() == 3, "placed_graft_ids = 3 (%d)" % placed.size())
	for p in picks:
		_st(not placed.has(str((p as Dictionary).get("id", ""))), "graft_choices exclut les greffes posées")
	run.free()
	# v2-W3 — graft_roll_bonus : somme des amount des greffes « roll » de l'action, 0 sinon, et
	# TOLÉRANCE legacy d'une vieille greffe kind=="die" (compat save R108). Round-trip save inclus.
	var run_r: Node = RunScript.new()
	run_r._rng.seed = 77
	run_r.new_run({"title": "st_roll", "beats": [{"type": "Exploration", "n": 1}], "total": 1})
	var roll_default: int = int(CardScript.ROLL_BONUS_DEFAULT)
	_st(int(run_r.graft_roll_bonus(run_r.actions[0])) == 0, "graft_roll_bonus neuf = 0")
	var roll_g: Dictionary = {}
	for g in gen_bank:
		if str((g as Dictionary).get("kind", "")) == "roll":
			roll_g = g
			break
	_st(not roll_g.is_empty(), "banque générique porte >=1 greffe roll")
	_st(run_r.apply_graft("action_agir", roll_g), "pose greffe roll OK")
	_st(int(run_r.graft_roll_bonus(run_r._action_by_id("action_agir"))) == int(roll_g.get("amount", roll_default)),
		"graft_roll_bonus = amount de la greffe posée (%d)" % int(run_r.graft_roll_bonus(run_r._action_by_id("action_agir"))))
	_st(int(run_r.graft_roll_bonus(run_r._action_by_id("action_percevoir"))) == 0, "graft_roll_bonus d'une autre action = 0")
	# Legacy : greffe kind=="die" posée (save pré-pivot) → comptée comme roll d'amount ROLL_BONUS_DEFAULT.
	var legacy_die: Dictionary = {"id": "g_legacy_die", "name": "Legacy", "evocation": "", "kind": "die",
		"tag": "", "effect_type": "", "effect_value": 0, "charges": 0, "corr_cost": 0, "pilier": ""}
	_st(run_r.apply_graft("action_parler", legacy_die), "pose greffe legacy die OK (tolérée)")
	_st(int(run_r.graft_roll_bonus(run_r._action_by_id("action_parler"))) == roll_default,
		"greffe legacy die comptée comme roll (+%d)" % roll_default)
	# Save round-trip : la greffe roll ET la legacy die survivent, bonus identique au resume.
	run_r.save()
	var run_r2: Node = RunScript.new()
	_st(run_r2.load_run(), "load_run() roll OK")
	_st(int(run_r2.graft_roll_bonus(run_r2._action_by_id("action_agir"))) == int(run_r.graft_roll_bonus(run_r._action_by_id("action_agir"))) \
		and int(run_r2.graft_roll_bonus(run_r2._action_by_id("action_parler"))) == roll_default,
		"resume graft_roll_bonus identique (roll + legacy die)")
	run_r.clear_save()
	run_r.free()
	run_r2.free()
	print("[SOAK] self-test §E greffes : %d greffes en banques, cap/dérivations/roll/legacy-die OK" % seen.size())


# --- Self-test talent (v2-W2) : gain au degré, ciblage du nœud, cap/coût, skill_mod, save round-trip. ---
func _selftest_talent() -> void:
	var run: Node = RunScript.new()
	run._rng.seed = 4321
	run.new_run({"title": "st_talent", "beats": [{"type": "Exploration", "n": 1}], "total": 1})
	# À neuf : 0 point, 4 verbes à 0, aucun usage, nœud non offert.
	_st(int(run.talent_points) == 0 and not run.can_offer_talent_node(), "talent neuf : 0 point, nœud non offert")
	_st(int(run.skill_mod_for(run.actions[0])) == 0, "skill_mod neuf = 0")
	# Gain au degré : réussite +1, éclatante +2, partiel/échec 0.
	run.gain_talent_points(ResolutionScript.REUSSITE)
	run.gain_talent_points(ResolutionScript.PARTIEL)
	run.gain_talent_points(ResolutionScript.ECHEC)
	run.gain_talent_points(ResolutionScript.ECLATANTE)
	_st(int(run.talent_points) == int(run.TALENT_GAIN_REUSSITE) + int(run.TALENT_GAIN_ECLATANTE),
		"gain au degré (réussite+éclatante = %d)" % int(run.talent_points))
	# Ciblage : le verbe le plus utilisé est la cible du nœud.
	run.note_verb_played(run.actions[1])  # AGIR
	run.note_verb_played(run.actions[1])  # AGIR ×2
	run.note_verb_played(run.actions[2])  # PARLER ×1
	_st(str(run.talent_node_target()) == "AGIR", "cible = verbe le plus utilisé (%s)" % str(run.talent_node_target()))
	# Offre + application : coût TALENT_COST consommé, verbe +1, skill_mod monte.
	_st(run.can_offer_talent_node(), "nœud offert quand points >= coût")
	var node: Dictionary = run.build_talent_node()
	var pts_before: int = int(run.talent_points)
	_st(run.apply_talent_node(node), "apply_talent_node OK")
	_st(int(run.talent_points) == pts_before - int(run.TALENT_COST), "coût talent consommé (%d->%d)" % [pts_before, int(run.talent_points)])
	_st(int(run.talent.get("AGIR", 0)) == 1, "verbe ciblé monté à 1")
	# skill_mod du verbe AGIR (actions[1]) = 1 maintenant.
	_st(int(run.skill_mod_for(run.actions[1])) == 1, "skill_mod du verbe amélioré = 1")
	# Cap : monter AGIR au cap puis refuser au-delà.
	run.talent["AGIR"] = int(run.TALENT_CAP)
	run.talent_points = 100
	_st(not run.apply_talent_node({"kind": "talent", "verb": "AGIR", "amount": 1}), "cap talent : refus au-delà de TALENT_CAP")
	# Un verbe au cap n'est jamais ciblé.
	run.verb_usage["AGIR"] = 999
	_st(str(run.talent_node_target()) != "AGIR", "verbe au cap jamais ciblé (%s)" % str(run.talent_node_target()))
	# Save round-trip : talent / points / usage survivent au resume (R108, champs additifs).
	run.save()
	var run2: Node = RunScript.new()
	_st(run2.load_run(), "load_run() talent OK")
	_st(int(run2.talent.get("AGIR", 0)) == int(run.talent.get("AGIR", 0)) \
		and int(run2.talent_points) == int(run.talent_points) \
		and int(run2.verb_usage.get("AGIR", 0)) == int(run.verb_usage.get("AGIR", 0)),
		"resume talent/points/usage identiques")
	# Save legacy (sans champs talent) : défauts safe (4 verbes à 0, pas de crash).
	var run3: Node = RunScript.new()
	run3.new_run({"title": "st_legacy", "beats": [{"type": "Exploration", "n": 1}], "total": 1})
	run3.talent = run3._talent_dict({})  # simulate load partiel
	_st((run3.talent as Dictionary).size() == 4 and int(run3.talent.get("PERCEVOIR", 0)) == 0,
		"défaut safe talent (4 verbes à 0)")
	var cap_v: int = int(run.TALENT_CAP)
	var cost_v: int = int(run.TALENT_COST)
	run.clear_save()
	run.free()
	run2.free()
	run3.free()
	print("[SOAK] self-test W2 talent : gain/ciblage/cap/coût/skill_mod/save OK (cap=%d coût=%d)" % [cap_v, cost_v])


# v1.0-V4a (BAL-04-B) — gates de morts PAR ARCHÉTYPE (runs saines), ASSERTIONS DURES du soak.
# tag_ignorant = baseline non-lecteur, volontairement sans gate (mesure la sensibilité au signal).
const ARCH_MORT_GATES: Dictionary = {"optimal": 10.0, "greedy": 30.0, "chaotic": 30.0, "corrompu": 25.0}
const ARCH_GATE_MIN_RUNS: int = 20  # petit échantillon → gate non significatif (loguée seulement)


func _ensure_arch(arch: String) -> void:
	if not _arch_stats.has(arch):
		_arch_stats[arch] = {"degrees": {}, "ends": {}, "runs": 0, "ends_clean": {}, "runs_clean": 0}


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
	var action_plays: Dictionary = {}      # v11-W3 : action_id -> poses (cible « optimal » des greffes)
	var grafts_run: int = 0                # v11-W3 : greffes posées cette run (rapport §K)

	# v1.0-V4a (BAL-11-B/GD-27) — miroir du draft d'OUVERTURE (merlin_game._end_interstitial) :
	# une greffe offerte AVANT le 1er beat, prise ~70 % (même politique que les autres drafts).
	# Flag d'unicité posé comme au jeu (persisté — un « Passer » n'est jamais re-proposé, R108).
	if run.has_graftable_action() and not run.opening_draft_done:
		run.opening_draft_done = true
		var open_choices: Array = run.graft_choices(3)
		if not open_choices.is_empty():
			_drafts_offered += 1
			if rng.randf() < 0.7 and _apply_soak_graft(run, arch,
					open_choices[rng.randi_range(0, open_choices.size() - 1)], action_plays, rng, i):
				_drafts_taken += 1
				grafts_run += 1

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
		# v1.0-V4a (GD-32-B) — MIROIR de la contre-pression §E : difficulté effective (quête 3 +
		# build ≥3 greffes → 3 requis 2+1), même statique que build_situation (zéro drift).
		var diff: int = Scenario.effective_difficulty(beat, int(run.total_grafts()))
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
		if run.intervention_beats.has(run.beat_index) and int(run.pilier_interventions) < 1:  # v11-V2b : cap 1/run
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
		# v2-W1 : dé PRÉ-TIRÉ du beat AVANT le choix — d20 (miroir build_situation, R120 preview=résolution).
		var die: int = rng.randi_range(1, 20)
		var combo: Array = _pick_combo(arch, run, required, die, rng, diff)
		action_plays[str(combo[0].id)] = int(action_plays.get(str(combo[0].id), 0)) + 1
		# v1.0-V4a L8 — même diff que la preview du bot (_pick_combo) : barème d'échec par difficulté.
		# v2-W2 — skill_mod = talent du verbe joué (miroir merlin_game._on_resolve, R120 preview=résolution).
		# v2-W3 — graft_bonus = greffes « roll » posées sur l'action jouée (miroir merlin_game, R120).
		var skill_mod: int = int(run.skill_mod_for(combo[0]))
		var graft_bonus: int = int(run.graft_roll_bonus(combo[0]))
		run.note_verb_played(combo[0])  # compteur d'usage du verbe (cible du nœud de talent au draft)
		var res: Dictionary = ResolutionScript.resolve(required, combo, [], die, run.blessed_bonus(combo), diff, skill_mod, graft_bonus)
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
		# v11-W3 — miroir merlin_game._on_resolve : les charges de greffe du verbe joué (HEAL/PURGE/
		# DRAW) se consomment à la pose, AVANT apply_resolution (un HEAL peut sauver — même ordre).
		run.apply_graft_charges(combo[0])
		run.apply_resolution(res)
		run.gain_talent_points(deg)  # v2-W2 : points de talent au degré FINAL (réussite +1 / éclatante +2), après le push R130
		# v11-W3 — le draft sert des GREFFES (miroir merlin_game._advance_to_next) : offrande du
		# pilier au beat Rencontre (1×/run, banque signée) sinon draft générique aux réussites ;
		# ~70 % de prise conservé ; cible = action ÉLIGIBLE (archétype greffe-aware) ; les tags
		# greffés entrent dans la whitelist au beat suivant (Sacrifice/Équilibre débloqués §F).
		var did_offering: bool = false
		if btype == "Rencontre" and not run.pilier_offering_done and not run.ended:
			run.pilier_offering_done = true
			if run.has_graftable_action():
				var offer: Array = run.pilier_graft_offering(_soak_draw_pilier(rng), 2)
				if not offer.is_empty():
					did_offering = true
					_drafts_offered += 1
					# v2-W2 — le nœud de talent remplace un choix (miroir _inject_talent_node) : pris → draft consommé.
					if _maybe_take_talent_node(run, arch, rng):
						_drafts_taken += 1
						_talent_nodes_taken += 1
					elif rng.randf() < 0.7 and _apply_soak_graft(run, arch,
							offer[rng.randi_range(0, offer.size() - 1)], action_plays, rng, i):
						_drafts_taken += 1
						grafts_run += 1
		# Draft logique standard (mêmes conditions que merlin_game) — sauté si offrande / actions
		# pleines. v1.0-V4a (BAL-11-B/GD-27) : draft GARANTI en plus à chaque transition de quête
		# (le beat résolu referme sa quête — qn == qtotal — et la run continue), degré indifférent.
		var quest_close: bool = beat.has("qtotal") and int(beat.get("qn", 1)) >= int(beat.get("qtotal", 1))
		if not did_offering and (deg == ResolutionScript.REUSSITE or deg == ResolutionScript.ECLATANTE or quest_close) \
				and not run.is_climax() and not run.ended and run.has_graftable_action():
			var choices: Array = run.graft_choices(3)
			if not choices.is_empty():
				_drafts_offered += 1
				# v2-W2 — nœud de talent (miroir _inject_talent_node) : pris → draft consommé, sinon greffe.
				if _maybe_take_talent_node(run, arch, rng):
					_drafts_taken += 1
					_talent_nodes_taken += 1
				elif rng.randf() < 0.7 and _apply_soak_graft(run, arch,
						choices[rng.randi_range(0, choices.size() - 1)], action_plays, rng, i):
					_drafts_taken += 1
					grafts_run += 1
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
	_grafts_total += grafts_run
	if run.ended:
		_ends[run.end_type] = int(_ends.get(run.end_type, 0)) + 1
		_bump_arch(arch, "ends", run.end_type)
		if not forced:
			_clean_runs += 1
			_ends_clean[run.end_type] = int(_ends_clean.get(run.end_type, 0)) + 1
			_pushes_clean += run_pushes
			_corr_gained_clean += corr_gained_run
			_grafts_clean += grafts_run
			# v2-W2 — talent final : somme des 4 niveaux en fin de run saine (moyenne §K = poussée du build).
			var tl: int = 0
			for tv in run.TALENT_VERBS:
				tl += int((run.talent as Dictionary).get(tv, 0))
			_talent_levels_sum += tl
			_talent_runs += 1
			# v1.0-V4a (BAL-04-B) — base des gates de morts par archétype : runs SAINES uniquement
			# (les cas dégénérés forcés meurent par construction et fausseraient le gate).
			_bump_arch(arch, "ends_clean", run.end_type)
			_arch_stats[arch]["runs_clean"] = int(_arch_stats[arch]["runs_clean"]) + 1
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


# v11-W3 — pose une greffe sur une action ÉLIGIBLE : « optimal » vise l'action la PLUS JOUÉE
# (greffe là où le dé et les tags serviront) ; les autres archétypes tirent une éligible au hasard.
# Vérifie au passage le guardrail CRITICAL : prix ONE-SHOT exactement corr_cost à la pose.
func _apply_soak_graft(run: Node, arch: String, graft: Dictionary, action_plays: Dictionary, rng: RandomNumberGenerator, i: int) -> bool:
	var eligible: Array = []
	for a in run.actions:
		if (a.get("grafts") as Array).size() < int(run.MAX_GRAFTS_PER_ACTION):
			eligible.append(a)
	if eligible.is_empty():
		return false
	var target: Variant = eligible[rng.randi_range(0, eligible.size() - 1)]
	if arch == "optimal":
		var best_n: int = -1
		for a in eligible:
			var n: int = int(action_plays.get(str(a.get("id")), 0))
			if n > best_n:
				best_n = n
				target = a
	var corr_before2: int = run.corruption
	var ok: bool = run.apply_graft(str(target.get("id")), graft)
	_check(ok, i, "apply_graft sur action éligible", run)
	if ok:
		_check(run.corruption == corr_before2 + int(graft.get("corr_cost", 0)), i,
			"prix de greffe ONE-SHOT (%d->%d, coût %d)" % [
				corr_before2, run.corruption, int(graft.get("corr_cost", 0))], run)
	return ok


# v2-W2 — MIROIR du nœud de talent au draft (merlin_game._inject_talent_node + _on_draft_card) :
# quand un nœud de talent PEUT s'offrir (assez de points + un verbe sous le cap), il REMPLACE l'un
# des 3 choix. Le bot le prend selon sa politique ; « optimal » le prend toujours (skill_mod permanent
# rationnel sur le verbe le plus joué) ; les autres avec P ≈ 1/3 × 0,7 (nœud = 1 choix sur 3, pris ~70 %).
# Renvoie true si le nœud a été PRIS (le draft est alors consommé — pas de greffe ce beat). save() posé
# comme au jeu (progression réelle R108) — le probe teste ensuite le resume S5.
func _maybe_take_talent_node(run: Node, arch: String, rng: RandomNumberGenerator) -> bool:
	if not run.can_offer_talent_node():
		return false
	var take: bool = (arch == "optimal") or (rng.randf() < 0.233)
	if not take:
		return false
	var node: Dictionary = run.build_talent_node()
	if not run.apply_talent_node(node):
		return false  # course improbable (verbe passé au cap entre-temps) — retombe sur la greffe
	run.save()  # même contrat que la pose d'une greffe (R108)
	return true


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
		# v11-W3 (review M2) : les greffes ET leurs compteurs de charges décrémentés survivent au
		# resume (R108) — signature (action|greffe:charges) comparée, pas un simple comptage.
		_check(_graft_sig(run2) == _graft_sig(run), i,
			"resume greffes+charges identiques (%s == %s)" % [_graft_sig(run2), _graft_sig(run)], run)
		_check(int(run2.next_draw_bonus) == int(run.next_draw_bonus), i,
			"resume next_draw_bonus %d==%d" % [int(run2.next_draw_bonus), int(run.next_draw_bonus)], run)
	run2.free()


# v11-W3 — signature des greffes posées (id:charges par action, ordre stable des actions) :
# duck-typé (règle tools/), sert l'assertion R108 charges comprises.
func _graft_sig(r: Node) -> String:
	var parts: Array = []
	for a in r.actions:
		for g in (a.get("grafts") as Array):
			parts.append("%s|%s:%d" % [str(a.get("id")), str((g as Dictionary).get("id", "")),
				int((g as Dictionary).get("charges", 0))])
	return ";".join(parts)


# --- POLITIQUES par archétype (spec v11-W2) : le geste = [ACTION permanente, TRAIT de la main]. ---
# optimal      : maximise la couverture des requis ; départage synergie, puis dé (die_mod).
# greedy       : maximise les tags totaux joués (couverts + extras) ; départage dé, puis synergie.
# corrompu     : préfère le trait corrompu/coûteux ; le verbe lui importe peu (aléatoire).
# chaotic      : uniforme aléatoire (action ET trait).
# tag_ignorant : aléatoire SANS lire les requis — baseline non-lecteur, flux RNG distinct de
#                chaotic (mesure la sensibilité du système au non-signal).
func _pick_combo(arch: String, run: Node, required: Array, die: int, rng: RandomNumberGenerator, diff: int = 2) -> Array:
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
		# v2-W2 — skill_mod = talent du verbe de l'action évaluée (le bot lit la même preview, R120).
		# v2-W3 — graft_bonus = greffes « roll » de l'action évaluée (même preview que la résolution, R120).
		var sm: int = int(run.skill_mod_for(a))
		var gb: int = int(run.graft_roll_bonus(a))
		for t in traits_h:
			var r: Dictionary = ResolutionScript.resolve(required, [a, t], [], die, run.blessed_bonus([a, t]), diff, sm, gb)
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


# --- RAPPORT §K — noyau dur BAL-20-B : 4 bandes de degrés (dures une fois atteintes, sinon delta
# restant logué) + morts par archétype (dures, _report_arch) + 0 hors-pool (dure, _assert_required).
# Les métriques de flux (pushes, drafts, deadhand, corrompues) restent LOGUÉES (anti faux-rouges). ---
func _report_k() -> void:
	var bt: float = float(maxi(_beats_clean, 1))
	var cr: float = float(maxi(_clean_runs, 1))
	print("[SOAK] — CIBLES §K v1.0 (runs saines n=%d, beats=%d — cas dégénérés forcés exclus) —" % [_clean_runs, _beats_clean])
	_band_deg("échec", 100.0 * float(int(_degrees_clean.get("echec", 0))) / bt, 3.0, 8.0)
	_band_deg("partiel", 100.0 * float(int(_degrees_clean.get("partiel", 0))) / bt, 28.0, 38.0)
	_band_deg("réussite", 100.0 * float(int(_degrees_clean.get("reussite", 0))) / bt, 45.0, 55.0)
	_band_deg("éclatante", 100.0 * float(int(_degrees_clean.get("eclatante", 0))) / bt, 8.0, 15.0)
	_band("morts", 100.0 * float(int(_ends_clean.get("mort", 0))) / cr, 10.0, 25.0)
	_band("fins corrompues", 100.0 * float(int(_ends_clean.get("corrompu", 0))) / cr, 0.0, 18.0)
	_band("pushes/run", float(_pushes_clean) / cr, 0.5, 1.5, false)
	_band("corruption gagnée/run", float(_corr_gained_clean) / cr, 3.9, 6.9, false)
	if _climax_beats > 0:
		_band("couverture pleine climax (3 requis)", 100.0 * float(_climax_full) / float(_climax_beats), 45.0, 55.0)
	print("[SOAK]   %-36s %5.2f    (info §E : E[acquisitions] cible 5-6 · offerts/run=%.2f)" % [
		"greffes posées/run (saines)", float(_grafts_clean) / cr, float(_drafts_offered) / float(maxi(_runs_total, 1))])
	# v2-W2 — TALENT : nœuds pris + niveau moyen de talent en fin de run saine (le talent pousse §K vers
	# plus de succès → la ligne trace l'ampleur du levier ; informatif, non-bloquant).
	print("[SOAK]   %-36s %5.2f    (info W2 : nœuds pris/run · niveau talent moyen fin de run=%.2f)" % [
		"nœuds de talent pris/run (saines)", float(_talent_nodes_taken) / float(maxi(_runs_total, 1)),
		float(_talent_levels_sum) / float(maxi(_talent_runs, 1))])
	print("[SOAK]   %-36s %5d     (ASSERTION DURE == 0)" % ["beats à requis hors-pool", _offpool_beats])
	print("[SOAK]   %-36s %5.1f%%   (info §C : A/B réserve de trait si > 45)" % ["deadhand (0 trait couvrant)", 100.0 * float(_deadhand_beats) / float(maxi(_beats_total, 1))])
	print("[SOAK]   variantes basculées=%d · sabotage R66 non simulé (aucun antagoniste côté probe) · émissions ×1=%s" % [_variant_swaps, str(_x1_emissions)])


func _band(label: String, value: float, lo: float, hi: float, pct: bool = true) -> void:
	var v: String = ("%5.1f%%" % value) if pct else ("%5.2f " % value)
	var cible: String = ("%.0f-%.0f%%" % [lo, hi]) if pct else ("%.1f-%.1f" % [lo, hi])
	var verdict: String = "IN " if value >= lo and value <= hi else "OUT"
	print("[SOAK]   %-36s %s   cible %-8s [%s]" % [label, v, cible, verdict])


# v1.0-V4a (BAL-20-B) — bande de DEGRÉ : dure quand HARD_DEGREE_BANDS (les 4 atteintes), sinon
# OUT logué avec le delta restant EXPLICITE vers la borne la plus proche.
func _band_deg(label: String, value: float, lo: float, hi: float) -> void:
	var verdict: String = "IN " if value >= lo and value <= hi else "OUT"
	if verdict == "IN ":
		print("[SOAK]   %-36s %5.1f%%   cible %-8s [IN ]" % [label, value, "%.0f-%.0f%%" % [lo, hi]])
		return
	var delta: float = (lo - value) if value < lo else (value - hi)
	var note: String = "DUR" if HARD_DEGREE_BANDS else "delta restant %.1f pts — non-bloquant (BAL-20-B : durcira à l'atteinte des 4 bandes)" % delta
	print("[SOAK]   %-36s %5.1f%%   cible %-8s [OUT] %s" % [label, value, "%.0f-%.0f%%" % [lo, hi], note])
	if HARD_DEGREE_BANDS:
		_gate_fail += 1


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
	# v1.0-V4a (BAL-04-B) — GATES DE MORTS par archétype sur runs SAINES : optimal ≤10 % ·
	# greedy/chaotic ≤30 % · corrompu ≤25 %. ASSERTION DURE (échantillon ≥ ARCH_GATE_MIN_RUNS).
	print("[SOAK] — GATES MORTS PAR ARCHÉTYPE (runs saines, ASSERTION DURE) —")
	for arch in _arch_stats:
		var stc: Dictionary = _arch_stats[arch]
		var rc: int = int(stc.get("runs_clean", 0))
		var ec: Dictionary = stc.get("ends_clean", {})
		var morts_c: float = 100.0 * float(int(ec.get("mort", 0))) / float(maxi(rc, 1))
		if not ARCH_MORT_GATES.has(arch):
			print("[SOAK]   %-12s morts saines=%5.1f%% (n=%d) — sans gate (baseline)" % [str(arch), morts_c, rc])
			continue
		var gate: float = float(ARCH_MORT_GATES[arch])
		if rc < ARCH_GATE_MIN_RUNS:
			print("[SOAK]   %-12s morts saines=%5.1f%% (n=%d) — échantillon < %d, gate non significatif" % [
				str(arch), morts_c, rc, ARCH_GATE_MIN_RUNS])
			continue
		var verdict: String = "PASS" if morts_c <= gate else "FAIL"
		print("[SOAK]   %-12s morts saines=%5.1f%%  gate ≤%2.0f%% (n=%d) [%s]" % [str(arch), morts_c, gate, rc, verdict])
		if morts_c > gate:
			_gate_fail += 1  # gate §K (équilibrage) — compté à part des échecs de runs (fiabilité)


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
