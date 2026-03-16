## ═══════════════════════════════════════════════════════════════════════════════
## Store Factions — Faction alignment, trust, periods, biome affinity
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_store.gd — pure delegation, no behavior changes.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name StoreFactions


## Snapshot faction_rep (meta) -> run["faction_context"].
static func build_and_store_faction_context(state: Dictionary) -> void:
	var meta: Dictionary = state.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var run: Dictionary = state.get("run", {})
	var context: Dictionary = {"dominant": "", "tiers": {}, "active_effects": []}
	var dominant_score: int = 0
	for faction in MerlinConstants.FACTIONS:
		var score: int = int(faction_rep.get(faction, 0))
		var tier: String = faction_score_to_tier(score)
		context["tiers"][faction] = tier
		if tier != "neutre":
			context["active_effects"].append({"faction": faction, "tier": tier, "score": score})
		if score > dominant_score:
			context["dominant"] = faction
			dominant_score = score
	run["faction_context"] = context
	state["run"] = run


## Convertit un score faction en tier string.
static func faction_score_to_tier(score: int) -> String:
	if score >= 80:    return "honore"
	elif score >= 50:  return "sympathisant"
	elif score >= 20:  return "neutre"
	elif score >= 5:   return "mefiant"
	else:              return "hostile"


## Applique les bonus/malus de debut de run selon les tiers actuels.
static func apply_faction_run_bonuses(state: Dictionary) -> void:
	var run: Dictionary = state.get("run", {})
	var faction_context: Dictionary = run.get("faction_context", {})
	var tiers: Dictionary = faction_context.get("tiers", {})
	for faction in MerlinConstants.FACTIONS:
		var tier: String = str(tiers.get(faction, "neutre"))
		var bonuses: Dictionary = MerlinConstants.FACTION_RUN_BONUSES.get(faction, {})
		var bonus: Dictionary = bonuses.get(tier, {})
		if bonus.is_empty():
			continue
		var bonus_type: String = str(bonus.get("type", ""))
		var amount: int = int(bonus.get("amount", 0))
		match bonus_type:
			"ADD_KARMA":
				var hidden: Dictionary = run.get("hidden", {})
				hidden["karma"] = clampi(int(hidden.get("karma", 0)) + amount, -20, 20)
				run["hidden"] = hidden
			"ADD_TENSION":
				var hidden: Dictionary = run.get("hidden", {})
				hidden["tension"] = clampi(int(hidden.get("tension", 0)) + amount, 0, 100)
				run["hidden"] = hidden
			"HEAL_LIFE":
				run["life_essence"] = mini(int(run.get("life_essence", 0)) + amount, MerlinConstants.LIFE_ESSENCE_MAX)
			"DAMAGE_LIFE":
				run["life_essence"] = maxi(int(run.get("life_essence", 0)) - abs(amount), 0)
	state["run"] = run


## Update trust (confiance Merlin). Returns {"old": int, "new": int, "tier": String}.
static func update_trust(state: Dictionary, delta: int) -> Dictionary:
	if delta == 0:
		return {}
	var meta: Dictionary = state.get("meta", {})
	var old_value: int = int(meta.get("trust_merlin", 0))
	var new_value: int = clampi(old_value + delta, 0, 100)
	meta["trust_merlin"] = new_value
	state["meta"] = meta
	var tier: String = get_trust_tier(state)
	return {"old": old_value, "new": new_value, "tier": tier}


static func get_trust_tier(state: Dictionary) -> String:
	var trust: int = int(state.get("meta", {}).get("trust_merlin", 0))
	for tier_key in MerlinConstants.TRUST_TIERS:
		var tier: Dictionary = MerlinConstants.TRUST_TIERS[tier_key]
		if trust >= int(tier.get("range_min", 0)) and trust <= int(tier.get("range_max", 100)):
			return tier_key
	return "T0"


## In-game period from card index (bible v2.4 s.6.4).
static func get_period(card_index: int) -> String:
	for period_key in MerlinConstants.IN_GAME_PERIODS:
		var period: Dictionary = MerlinConstants.IN_GAME_PERIODS[period_key]
		if card_index >= int(period.get("cards_min", 0)) and card_index <= int(period.get("cards_max", 0)):
			return period_key
	return "nuit"


static func get_period_bonus(card_index: int, faction: String) -> float:
	var period_key: String = get_period(card_index)
	var period: Dictionary = MerlinConstants.IN_GAME_PERIODS.get(period_key, {})
	var factions: Array = period.get("factions", [])
	if factions.has(faction):
		return float(period.get("bonus", 0.0))
	return 0.0


## Biome affinity bonus for ogham in matching biome (bible v2.4 s.2.2).
static func get_biome_affinity_bonus(biome_id: String, ogham_id: String) -> Dictionary:
	var biome: Dictionary = MerlinConstants.BIOMES.get(biome_id, {})
	var affinity_list: Array = biome.get("oghams_affinity", [])
	if affinity_list.has(ogham_id):
		return {"score_bonus": 0.10, "cooldown_reduction": 1}
	return {"score_bonus": 0.0, "cooldown_reduction": 0}
