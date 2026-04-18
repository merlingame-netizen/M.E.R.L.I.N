extends RefCounted
class_name MerlinTrustSystem

## Confiance Merlin — 0-100 clamped, T0-T3 tiers, mid-run changes.
## Determines how much information Merlin reveals during a run.
## Bible v2.4 s.6.3: immediate tier change mid-run, no delay.

const TRUST_MIN: int = 0
const TRUST_MAX: int = 100

var _trust: int = 0


func _init(initial_value: int = 0) -> void:
	_trust = clampi(initial_value, TRUST_MIN, TRUST_MAX)


func get_trust() -> int:
	return _trust


func set_trust(value: int) -> void:
	_trust = clampi(value, TRUST_MIN, TRUST_MAX)


func get_tier() -> String:
	return resolve_tier(_trust)


func get_tier_label() -> String:
	return resolve_tier_label(_trust)


func apply_delta(delta_type: String) -> Dictionary:
	var deltas: Dictionary = MerlinConstants.TRUST_DELTAS
	var delta: int = 0
	match delta_type:
		"promise_kept":
			delta = int(deltas.get("promise_kept", 10))
		"promise_broken":
			delta = int(deltas.get("promise_broken", -15))
		"courageous_choice":
			var d_min: int = int(deltas.get("courageous_choice_min", 3))
			var d_max: int = int(deltas.get("courageous_choice_max", 5))
			delta = randi_range(d_min, d_max)
		"selfish_choice":
			var d_min: int = int(deltas.get("selfish_choice_min", -5))
			var d_max: int = int(deltas.get("selfish_choice_max", -3))
			delta = randi_range(d_min, d_max)
		_:
			return {"ok": false, "reason": "unknown_delta_type: %s" % delta_type}

	var old_trust: int = _trust
	var old_tier: String = resolve_tier(old_trust)
	_trust = clampi(_trust + delta, TRUST_MIN, TRUST_MAX)
	var new_tier: String = resolve_tier(_trust)

	return {
		"ok": true,
		"old_trust": old_trust,
		"new_trust": _trust,
		"delta": delta,
		"delta_type": delta_type,
		"tier_changed": old_tier != new_tier,
		"old_tier": old_tier,
		"new_tier": new_tier,
	}


func apply_raw_delta(amount: int) -> void:
	_trust = clampi(_trust + amount, TRUST_MIN, TRUST_MAX)


func get_hint_level() -> int:
	var tier: String = resolve_tier(_trust)
	match tier:
		"T0":
			return 0
		"T1":
			return 1
		"T2":
			return 2
		"T3":
			return 3
	return 0


func build_llm_context() -> Dictionary:
	var tier: String = resolve_tier(_trust)
	var label: String = resolve_tier_label(_trust)
	return {
		"trust_value": _trust,
		"trust_tier": tier,
		"trust_label": label,
		"hint_level": get_hint_level(),
		"instruction": _get_tier_instruction(tier),
	}


static func resolve_tier(value: int) -> String:
	var tiers: Dictionary = MerlinConstants.TRUST_TIERS
	for tier_key in tiers:
		var tier: Dictionary = tiers[tier_key]
		if value >= int(tier.get("range_min", 0)) and value <= int(tier.get("range_max", 100)):
			return str(tier_key)
	return "T0"


static func resolve_tier_label(value: int) -> String:
	var tiers: Dictionary = MerlinConstants.TRUST_TIERS
	for tier_key in tiers:
		var tier: Dictionary = tiers[tier_key]
		if value >= int(tier.get("range_min", 0)) and value <= int(tier.get("range_max", 100)):
			return str(tier.get("label", "cryptique"))
	return "cryptique"


static func _get_tier_instruction(tier: String) -> String:
	match tier:
		"T0":
			return "Merlin parle en enigmes. Indices tres vagues. Jamais de reponse directe."
		"T1":
			return "Merlin donne des indices subtils. Metaphores celtiques. Laisse le joueur deduire."
		"T2":
			return "Merlin avertit clairement des dangers. Conseils directs mais poetiques."
		"T3":
			return "Merlin revele ses secrets. Parle ouvertement des consequences et des chemins caches."
	return "Merlin parle en enigmes."
