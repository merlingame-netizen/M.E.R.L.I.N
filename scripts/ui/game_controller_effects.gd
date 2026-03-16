## ═══════════════════════════════════════════════════════════════════════════════
## Game Controller — Effects & Game Mechanics Module
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_controller.gd.
## Handles choice resolution pipeline, karma/blessings, talent shields/bonuses,
## biome passives, mission progression, dynamic difficulty, run rewards,
## critical choice detection, and power milestones.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name GameControllerEffects

const KARMA_MIN := -10
const KARMA_MAX := 10
const BLESSINGS_MAX := 2
const RULE_CHECK_INTERVAL := 3


func apply_talent_shields(effects: Array, store: Node,
		shield_corps_used: bool) -> Dictionary:
	## Apply talent shields (cancel first damage, 1/run).
	## Returns {"effects": Array, "shield_corps_used": bool}.
	if not store or not store.has_method("is_talent_active"):
		return {"effects": effects, "shield_corps_used": shield_corps_used}

	var result: Array = []
	var new_shield_corps: bool = shield_corps_used
	for e in effects:
		var etype: String = str(e.get("type", ""))
		if etype == "DAMAGE_LIFE" and not new_shield_corps:
			if store.is_talent_active("racines_2"):
				new_shield_corps = true
				print("[Merlin] Talent: Endurance Naturelle absorbe les degats!")
				SFXManager.play("skill_activate")
				continue
		result.append(e)
	return {"effects": result, "shield_corps_used": new_shield_corps}


func update_karma_score(score: int, direction: String, karma: int) -> Dictionary:
	## Karma update based on raw score. Returns {"karma": int, "blessings_delta": int}.
	var new_karma: int = karma
	var blessings_delta: int = 0
	if score >= 95:
		new_karma = clampi(new_karma + 2, KARMA_MIN, KARMA_MAX)
		blessings_delta = 1
	elif score <= 20:
		new_karma = clampi(new_karma - 2, KARMA_MIN, KARMA_MAX)
	elif score >= 80:
		if direction == "right":
			new_karma = clampi(new_karma + 1, KARMA_MIN, KARMA_MAX)
		elif direction == "left":
			new_karma = clampi(new_karma - 1, KARMA_MIN, KARMA_MAX)
	return {"karma": new_karma, "blessings_delta": blessings_delta}


func apply_talent_bonuses(store: Node) -> Dictionary:
	## Apply talent effects at the start of a run. Returns initial state overrides.
	var result: Dictionary = {"free_center": 0, "blessings": 0}
	if not store or not store.has_method("is_talent_active"):
		return result
	if store.is_talent_active("feuillage_2"):
		result["free_center"] = 1
	if store.is_talent_active("racines_3"):
		result["blessings"] = 1
	return result


func detect_critical_choice(karma: int, critical_used: bool, cards_this_run: int) -> bool:
	## Returns true if this card should be a critical choice.
	if critical_used or cards_this_run < 3:
		return false
	if karma >= 6 and randf() < 0.4:
		return true
	elif karma <= -6 and randf() < 0.5:
		return true
	elif randf() < 0.15:
		return true
	return false


func show_card_modifier_indicator(current_card: Dictionary, ui: Node) -> void:
	## Show badge for card modifiers (chance, ogham, nocturne, saisonnier).
	if not ui or not is_instance_valid(ui):
		return
	var modifier_name: String = str(current_card.get("modifier", ""))
	if modifier_name.is_empty():
		return
	if ui.has_method("show_modifier_badge"):
		ui.show_modifier_badge(modifier_name)
	if modifier_name == "chance":
		SFXManager.play("dice_shake")
		print("[Merlin] Chance modifier active! Minigame: %s" % str(current_card.get("minigame", "")))
	elif modifier_name == "nocturne":
		print("[Merlin] Nocturne modifier active!")


func check_power_milestone(cards_this_run: int, store: Node, ui: Node) -> void:
	## Check power milestones — player gets stronger every 5 cards.
	if not MerlinConstants.POWER_MILESTONES.has(cards_this_run):
		return
	var ms: Dictionary = MerlinConstants.POWER_MILESTONES[cards_this_run]
	var mtype: String = str(ms.get("type", ""))
	var mval: int = int(ms.get("value", 0))
	print("[Merlin] Power milestone at card %d: %s +%d" % [cards_this_run, mtype, mval])
	match mtype:
		"HEAL":
			if store:
				store.dispatch({"type": "HEAL_LIFE", "amount": mval})
		"DC_REDUCTION":
			if store:
				var run_state: Dictionary = store.state.get("run", {})
				var bonuses: Dictionary = run_state.get("power_bonuses", {})
				bonuses["dc_reduction"] = int(bonuses.get("dc_reduction", 0)) + mval
				run_state["power_bonuses"] = bonuses
	if ui and is_instance_valid(ui) and ui.has_method("show_milestone_popup"):
		ui.show_milestone_popup(str(ms.get("label", "")), str(ms.get("desc", "")))
	SFXManager.play("ogham_chime")


func update_dynamic_difficulty(store: Node, dynamic_modifier: int) -> int:
	## Update dynamic difficulty using balance heuristic. Returns new modifier.
	if not store or not store.llm:
		return dynamic_modifier
	var ctx: Dictionary = store.state.get("run", {}).duplicate()
	var tendency: String = str(ctx.get("player_tendency", "neutre"))
	var rule_change: Dictionary = store.llm._suggest_rule_heuristic(ctx, tendency)

	var rule_type: String = str(rule_change.get("type", "none"))
	var adjustment: int = int(rule_change.get("adjustment", 0))
	var new_modifier: int = dynamic_modifier

	match rule_type:
		"difficulty":
			new_modifier = clampi(dynamic_modifier + int(adjustment / 5), -3, 3)
		"tension":
			if store:
				store.dispatch({"type": "ADD_TENSION", "amount": adjustment})
		"karma":
			if store:
				store.dispatch({"type": "ADD_KARMA", "amount": adjustment})
	print("[Merlin] Rule check: type=%s adj=%d -> dynamic_modifier=%d" % [rule_type, adjustment, new_modifier])
	return new_modifier


func auto_progress_mission(outcome: String, store: Node) -> void:
	## Auto-progress the run mission based on card outcomes (Phase 43).
	if not store:
		return
	var mission: Dictionary = store.get_mission()
	var mission_type: String = str(mission.get("type", ""))
	if mission_type.is_empty():
		return

	var step: int = 0
	match mission_type:
		"survive":
			step = 1
		"equilibre":
			step = 0
		"explore":
			if outcome == "reussite" or outcome == "reussite_critique":
				step = 1
		"artefact":
			if outcome == "reussite_critique":
				step = 1

	if step > 0:
		store.dispatch({"type": "PROGRESS_MISSION", "step": step})


func check_biome_passive(store: Node, cards_this_run: int, ui: Node) -> void:
	## Check and apply biome passive effect.
	if not store or not store.biomes:
		return
	var biome_key: String = str(store.state.get("run", {}).get("current_biome", ""))
	if biome_key.is_empty():
		return
	if store.biomes.has_method("should_trigger_passive") and store.biomes.should_trigger_passive(biome_key, cards_this_run):
		var passive: Dictionary = store.biomes.get_passive_effect(biome_key, cards_this_run) if store.biomes.has_method("get_passive_effect") else {}
		if not passive.is_empty():
			print("[Merlin] Biome passive triggered: %s" % str(passive))
			var passive_type: String = str(passive.get("type", ""))
			if passive_type.contains("HEAL"):
				store.dispatch({"type": "HEAL_LIFE", "amount": int(passive.get("amount", 5))})
			else:
				store.dispatch({"type": "DAMAGE_LIFE", "amount": int(passive.get("amount", 5))})
			if ui and is_instance_valid(ui):
				ui.show_biome_passive(passive)


func apply_run_rewards(ending: Dictionary, store: Node,
		minigames_won: int, cards_this_run: int) -> void:
	## Calculate and apply run rewards.
	if not store or not store.has_method("calculate_run_rewards"):
		return
	var run_data := {
		"victory": ending.get("victory", false),
		"minigames_won": minigames_won,
		"score": ending.get("score", 0),
		"cards_played": cards_this_run,
	}
	var rewards: Dictionary = store.calculate_run_rewards(run_data)
	store.apply_run_rewards(rewards)
	ending["rewards"] = rewards
	print("[Merlin] Rewards applied: %s" % str(rewards))


func play_outcome_sfx_score(score: int) -> void:
	## Play SFX based on raw minigame score.
	if score >= 95:
		SFXManager.play("dice_crit_success")
	elif score >= 80:
		SFXManager.play("aspect_up")
	elif score >= 51:
		SFXManager.play("aspect_up")
	elif score >= 21:
		SFXManager.play("aspect_down")
	else:
		SFXManager.play("dice_crit_fail")


func get_choice_label(option: int, current_card: Dictionary) -> String:
	## Get label for the given option index.
	var options: Array = current_card.get("options", [])
	if option < options.size():
		return str(options[option].get("label", ["Prudence", "Sagesse", "Audace"][clampi(option, 0, 2)]))
	return ["Prudence", "Sagesse", "Audace"][clampi(option, 0, 2)]
