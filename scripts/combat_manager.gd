## ═══════════════════════════════════════════════════════════════════════════════
## DRU v7 - Combat Manager
## ═══════════════════════════════════════════════════════════════════════════════
## Handles turn-based Pokemon-style combat with Ogham power words
## ═══════════════════════════════════════════════════════════════════════════════

class_name CombatManager
extends RefCounted

signal combat_log_updated(message: String)
signal player_hp_changed(current: int, max_hp: int)
signal enemy_hp_changed(current: int, max_hp: int)
signal turn_changed(is_player_turn: bool)
signal combat_ended(victory: bool)
signal status_applied(target: String, status_name: String)

# Combat state
var enemy_data: Dictionary = {}
var enemy_current_hp: int = 0
var is_player_turn: bool = true
var turn_count: int = 0
var combat_active: bool = false

# Status effects
var player_statuses: Array = []  # [{name, turns_remaining, effect}]
var enemy_statuses: Array = []

func start_combat(enemy: Dictionary) -> void:
	enemy_data = enemy.duplicate()
	enemy_current_hp = enemy.hp
	is_player_turn = true
	turn_count = 0
	combat_active = true
	player_statuses.clear()
	enemy_statuses.clear()
	
	emit_signal("combat_log_updated", "Un %s sauvage apparaît!" % enemy.name)
	emit_signal("enemy_hp_changed", enemy_current_hp, enemy.hp)
	emit_signal("turn_changed", true)

func use_ogham(ogham_id: String) -> Dictionary:
	if not combat_active or not is_player_turn:
		return {"success": false, "message": "Ce n'est pas ton tour!"}
	
	var ogham: Dictionary = GameManager.OGHAMS.get(ogham_id, {})
	if ogham.is_empty():
		return {"success": false, "message": "Ogham inconnu!"}
	
	var result := {"success": true, "message": "", "damage": 0, "effects": []}
	
	# Check accuracy
	var accuracy: int = ogham.get("accuracy", 100)
	var accuracy_modifier: int = _get_status_modifier("accuracy", player_statuses)
	accuracy = clampi(accuracy + accuracy_modifier, 0, 100)
	
	if randf() * 100 > accuracy:
		result.message = "%s utilise %s... mais rate!" % [GameManager.bestiole.name, ogham.name]
		emit_signal("combat_log_updated", result.message)
		_end_player_turn()
		return result
	
	# Calculate damage
	var power: int = ogham.get("power", 0)
	if power > 0:
		var type_mult: float = GameManager.get_type_multiplier(ogham.type, enemy_data.type)
		var atk: int = GameManager.bestiole.atk + _get_status_modifier("attack", player_statuses)
		var def: int = enemy_data.get("def", 5) + _get_status_modifier("defense", enemy_statuses)
		
		var base_damage: int = power + atk - int(def / 2.0)
		var damage: int = max(1, int(base_damage * type_mult))
		
		# Add variance
		damage = damage + randi_range(-2, 2)
		damage = max(1, damage)
		
		result.damage = damage
		enemy_current_hp = max(0, enemy_current_hp - damage)
		
		var effectiveness: String = ""
		if type_mult > 1.5:
			effectiveness = " (Super efficace!)"
		elif type_mult < 0.75 and type_mult > 0:
			effectiveness = " (Peu efficace...)"
		elif type_mult == 0:
			effectiveness = " (Aucun effet!)"
			damage = 0
		
		result.message = "%s utilise %s! %d dégâts%s" % [
			GameManager.bestiole.name, ogham.name, damage, effectiveness
		]
		
		emit_signal("enemy_hp_changed", enemy_current_hp, enemy_data.hp)
	else:
		result.message = "%s utilise %s!" % [GameManager.bestiole.name, ogham.name]
	
	# Apply effects
	var effect: Dictionary = ogham.get("effect", {})
	if not effect.is_empty():
		var effect_result := _apply_ogham_effect(effect, "enemy")
		result.effects.append(effect_result)
		if not effect_result.message.is_empty():
			result.message += " " + effect_result.message
	
	emit_signal("combat_log_updated", result.message)
	
	# Check victory
	if enemy_current_hp <= 0:
		_end_combat(true)
		return result
	
	_end_player_turn()
	return result

func _apply_ogham_effect(effect: Dictionary, target: String) -> Dictionary:
	var result := {"success": false, "message": ""}
	var effect_type: String = effect.get("type", "")
	
	match effect_type:
		"heal":
			var value: int = effect.get("value", 0)
			GameManager.heal_bestiole(value)
			result.success = true
			result.message = "%s récupère %d PV!" % [GameManager.bestiole.name, value]
		
		"defense_up":
			var turns: int = effect.get("value", 2)
			player_statuses.append({"name": "Défense+", "turns": turns, "effect": "defense", "value": 5})
			result.success = true
			result.message = "Défense augmentée!"
			emit_signal("status_applied", "player", "Défense+")
		
		"attack_up":
			var turns: int = effect.get("value", 2)
			player_statuses.append({"name": "Attaque+", "turns": turns, "effect": "attack", "value": 5})
			result.success = true
			result.message = "Attaque augmentée!"
			emit_signal("status_applied", "player", "Attaque+")
		
		"speed_up":
			var turns: int = effect.get("value", 2)
			player_statuses.append({"name": "Vitesse+", "turns": turns, "effect": "speed", "value": 3})
			result.success = true
			result.message = "Vitesse augmentée!"
			emit_signal("status_applied", "player", "Vitesse+")
		
		"accuracy_up":
			var turns: int = effect.get("value", 2)
			player_statuses.append({"name": "Précision+", "turns": turns, "effect": "accuracy", "value": 15})
			result.success = true
			result.message = "Précision augmentée!"
		
		"burn":
			var chance: float = effect.get("chance", 0.2)
			if randf() < chance:
				enemy_statuses.append({"name": "Brûlure", "turns": 3, "effect": "dot", "value": 5})
				result.success = true
				result.message = "%s est brûlé!" % enemy_data.name
				emit_signal("status_applied", "enemy", "Brûlure")
		
		"fear":
			var chance: float = effect.get("chance", 0.3)
			if randf() < chance:
				enemy_statuses.append({"name": "Terreur", "turns": 2, "effect": "skip", "value": 0.3})
				result.success = true
				result.message = "%s est terrorisé!" % enemy_data.name
				emit_signal("status_applied", "enemy", "Terreur")
		
		"confusion":
			var chance: float = effect.get("chance", 0.25)
			if randf() < chance:
				enemy_statuses.append({"name": "Confusion", "turns": 3, "effect": "confusion", "value": 0.3})
				result.success = true
				result.message = "%s est confus!" % enemy_data.name
				emit_signal("status_applied", "enemy", "Confusion")
		
		"bind":
			var turns: int = effect.get("turns", 2)
			enemy_statuses.append({"name": "Entravé", "turns": turns, "effect": "bind", "value": 3})
			result.success = true
			result.message = "%s est entravé!" % enemy_data.name
			emit_signal("status_applied", "enemy", "Entravé")
		
		"drain", "life_steal":
			var ratio: float = effect.get("value", 0.25)
			var heal_amount: int = int(enemy_current_hp * ratio)  # Based on damage dealt previously
			GameManager.heal_bestiole(heal_amount)
			result.success = true
			result.message = "%s absorbe %d PV!" % [GameManager.bestiole.name, heal_amount]
		
		"recoil":
			var ratio: float = effect.get("value", 0.1)
			var recoil_damage: int = int(GameManager.bestiole.hp * ratio)
			GameManager.damage_bestiole(recoil_damage)
			result.success = true
			result.message = "%s subit %d dégâts de recul!" % [GameManager.bestiole.name, recoil_damage]
		
		"curse":
			var value: int = effect.get("value", 5)
			enemy_statuses.append({"name": "Malédiction", "turns": 4, "effect": "dot", "value": value})
			result.success = true
			result.message = "%s est maudit!" % enemy_data.name
			emit_signal("status_applied", "enemy", "Malédiction")
		
		"blind":
			var chance: float = effect.get("chance", 0.2)
			if randf() < chance:
				enemy_statuses.append({"name": "Aveuglement", "turns": 2, "effect": "accuracy_down", "value": -30})
				result.success = true
				result.message = "%s est aveuglé!" % enemy_data.name
				emit_signal("status_applied", "enemy", "Aveuglement")
		
		"instant_death":
			var chance: float = effect.get("chance", 0.05)
			if randf() < chance:
				enemy_current_hp = 0
				result.success = true
				result.message = "Coup fatal! %s est vaincu instantanément!" % enemy_data.name
				emit_signal("enemy_hp_changed", 0, enemy_data.hp)
	
	return result

func _get_status_modifier(stat: String, statuses: Array) -> int:
	var total: int = 0
	for status in statuses:
		if status.effect == stat:
			total += status.value
	return total

func _end_player_turn() -> void:
	is_player_turn = false
	turn_count += 1
	
	# Process player status effects
	_process_status_effects(player_statuses, "player")
	
	emit_signal("turn_changed", false)
	
	# Enemy turn after short delay
	_do_enemy_turn()

func _do_enemy_turn() -> void:
	if not combat_active:
		return
	
	# Check for status effects that skip turn
	for status in enemy_statuses:
		if status.effect == "skip" and randf() < status.value:
			emit_signal("combat_log_updated", "%s est paralysé par la terreur!" % enemy_data.name)
			_end_enemy_turn()
			return
		if status.effect == "confusion" and randf() < status.value:
			# Enemy hits itself
			var self_damage: int = randi_range(3, 8)
			enemy_current_hp = max(0, enemy_current_hp - self_damage)
			emit_signal("combat_log_updated", "%s se blesse dans sa confusion! (%d dégâts)" % [enemy_data.name, self_damage])
			emit_signal("enemy_hp_changed", enemy_current_hp, enemy_data.hp)
			
			if enemy_current_hp <= 0:
				_end_combat(true)
				return
			
			_end_enemy_turn()
			return
	
	# Check for bind damage
	for status in enemy_statuses:
		if status.effect == "bind":
			var bind_damage: int = status.value
			enemy_current_hp = max(0, enemy_current_hp - bind_damage)
			emit_signal("combat_log_updated", "%s subit %d dégâts de l'entrave!" % [enemy_data.name, bind_damage])
			emit_signal("enemy_hp_changed", enemy_current_hp, enemy_data.hp)
			
			if enemy_current_hp <= 0:
				_end_combat(true)
				return
	
	# Calculate enemy damage
	var enemy_atk: int = enemy_data.get("atk", 10)
	var player_def: int = GameManager.bestiole.def + _get_status_modifier("defense", player_statuses)
	
	var accuracy: int = 90 + _get_status_modifier("accuracy", enemy_statuses)
	if randf() * 100 > accuracy:
		emit_signal("combat_log_updated", "%s attaque... mais rate!" % enemy_data.name)
		_end_enemy_turn()
		return
	
	var type_mult: float = GameManager.get_type_multiplier(enemy_data.type, GameManager.bestiole.type)
	var base_damage: int = enemy_atk - int(player_def / 3.0)
	var damage: int = max(1, int(base_damage * type_mult))
	damage = damage + randi_range(-2, 2)
	damage = max(1, damage)
	
	GameManager.damage_bestiole(damage)
	
	var effectiveness: String = ""
	if type_mult > 1.5:
		effectiveness = " (Super efficace!)"
	elif type_mult < 0.75 and type_mult > 0:
		effectiveness = " (Peu efficace...)"
	
	emit_signal("combat_log_updated", "%s attaque! %d dégâts%s" % [enemy_data.name, damage, effectiveness])
	emit_signal("player_hp_changed", GameManager.bestiole.hp, GameManager.bestiole.max_hp)
	
	# Check defeat
	if GameManager.bestiole.hp <= 0:
		_end_combat(false)
		return
	
	_end_enemy_turn()

func _end_enemy_turn() -> void:
	# Process enemy status effects
	_process_status_effects(enemy_statuses, "enemy")
	
	# Process DoT on enemy
	var dot_damage: int = 0
	for status in enemy_statuses:
		if status.effect == "dot":
			dot_damage += status.value
	
	if dot_damage > 0:
		enemy_current_hp = max(0, enemy_current_hp - dot_damage)
		emit_signal("combat_log_updated", "%s subit %d dégâts de statut!" % [enemy_data.name, dot_damage])
		emit_signal("enemy_hp_changed", enemy_current_hp, enemy_data.hp)
		
		if enemy_current_hp <= 0:
			_end_combat(true)
			return
	
	is_player_turn = true
	emit_signal("turn_changed", true)

func _process_status_effects(statuses: Array, target: String) -> void:
	var to_remove: Array = []
	
	for i in range(statuses.size()):
		statuses[i].turns -= 1
		if statuses[i].turns <= 0:
			to_remove.append(i)
	
	# Remove expired statuses (in reverse order to maintain indices)
	for i in range(to_remove.size() - 1, -1, -1):
		var status = statuses[to_remove[i]]
		emit_signal("combat_log_updated", "%s: %s dissipé" % ["Tu" if target == "player" else enemy_data.name, status.name])
		statuses.remove_at(to_remove[i])

func try_flee() -> bool:
	if not combat_active or not is_player_turn:
		return false
	
	var flee_chance: float = 0.5
	
	# Check for statuses that prevent fleeing
	for status in player_statuses:
		if status.effect == "bind":
			emit_signal("combat_log_updated", "Impossible de fuir, tu es entravé!")
			return false
	
	if randf() < flee_chance:
		combat_active = false
		emit_signal("combat_log_updated", "Tu as réussi à fuir!")
		return true
	else:
		emit_signal("combat_log_updated", "Impossible de fuir!")
		_end_player_turn()
		return false

func _end_combat(victory: bool) -> void:
	combat_active = false
	
	if victory:
		emit_signal("combat_log_updated", "%s est vaincu!" % enemy_data.name)
		
		# Rewards
		var gold: int = enemy_data.get("gold", 10)
		var xp: int = enemy_data.get("xp", 10)
		
		GameManager.add_gold(gold)
		GameManager.add_xp(xp)
		GameManager.run.combats_won += 1
		
		# Add essence
		GameManager.meta.essence[enemy_data.type] = GameManager.meta.essence.get(enemy_data.type, 0) + 1
		
		emit_signal("combat_log_updated", "+%d or, +%d XP" % [gold, xp])
	else:
		emit_signal("combat_log_updated", "%s est KO..." % GameManager.bestiole.name)
	
	emit_signal("combat_ended", victory)
