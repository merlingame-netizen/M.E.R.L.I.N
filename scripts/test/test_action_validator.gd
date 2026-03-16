## =============================================================================
## Unit Tests — ActionValidator
## =============================================================================
## Tests: validate(), schema validation, action type checking, parameter
## validation, condition checking, _load_actions_schema, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


## Helper: create an ActionValidator with a manually injected schema (no file I/O).
func _make_validator(schema: Dictionary = {}, state: Dictionary = {}) -> ActionValidator:
	var v: ActionValidator = ActionValidator.new()
	v.actions_schema = schema
	v.game_state_ref = state
	return v


func _default_schema() -> Dictionary:
	return {
		"attack": {
			"params": ["target_id", "weapon_id"],
			"conditions": ["target_in_range"],
		},
		"cast_spell": {
			"params": ["spell_id"],
			"conditions": ["has_mana", "spell_known"],
		},
		"move": {
			"params": ["direction"],
		},
		"idle": {},
	}


# =============================================================================
# VALIDATE — missing action type
# =============================================================================

func test_validate_missing_type_returns_invalid() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var result: Dictionary = v.validate({})
	if result.valid != false:
		push_error("validate({}): expected valid=false, got true")
		return false
	var errors: Array = result.errors
	if errors.size() != 1:
		push_error("validate({}): expected 1 error, got %d" % errors.size())
		return false
	if str(errors[0]).find("Missing action type") == -1:
		push_error("validate({}): expected 'Missing action type' error, got '%s'" % errors[0])
		return false
	return true


func test_validate_empty_dict_has_errors_array() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var result: Dictionary = v.validate({})
	if not result.has("valid"):
		push_error("validate: result missing 'valid' key")
		return false
	if not result.has("errors"):
		push_error("validate: result missing 'errors' key")
		return false
	if typeof(result.errors) != TYPE_ARRAY:
		push_error("validate: errors should be Array, got %d" % typeof(result.errors))
		return false
	return true


# =============================================================================
# VALIDATE — unknown action type
# =============================================================================

func test_validate_unknown_type_returns_invalid() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "teleport"}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(teleport): expected valid=false")
		return false
	var found_unknown: bool = false
	for err in result.errors:
		if str(err).find("Unknown action type") != -1:
			found_unknown = true
	if not found_unknown:
		push_error("validate(teleport): expected 'Unknown action type' error")
		return false
	return true


# =============================================================================
# VALIDATE — valid actions (no missing params, no failing conditions)
# =============================================================================

func test_validate_idle_no_params_no_conditions() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "idle"}
	var result: Dictionary = v.validate(action)
	if result.valid != true:
		push_error("validate(idle): expected valid=true, errors=%s" % str(result.errors))
		return false
	if result.errors.size() != 0:
		push_error("validate(idle): expected 0 errors, got %d" % result.errors.size())
		return false
	return true


func test_validate_move_with_required_param() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "move", "params": {"direction": "north"}}
	var result: Dictionary = v.validate(action)
	if result.valid != true:
		push_error("validate(move): expected valid=true, errors=%s" % str(result.errors))
		return false
	return true


func test_validate_attack_with_all_params_and_conditions() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {
		"type": "attack",
		"params": {"target_id": "enemy_1", "weapon_id": "sword"},
	}
	var result: Dictionary = v.validate(action)
	# target_in_range always returns true in default implementation
	if result.valid != true:
		push_error("validate(attack): expected valid=true, errors=%s" % str(result.errors))
		return false
	return true


# =============================================================================
# VALIDATE — missing params
# =============================================================================

func test_validate_missing_single_param() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "move"}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(move no params): expected valid=false")
		return false
	var found_direction: bool = false
	for err in result.errors:
		if str(err).find("direction") != -1:
			found_direction = true
	if not found_direction:
		push_error("validate(move no params): expected error mentioning 'direction'")
		return false
	return true


func test_validate_missing_multiple_params() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "attack", "params": {}}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(attack empty params): expected valid=false")
		return false
	if result.errors.size() < 2:
		push_error("validate(attack empty params): expected >=2 errors for target_id + weapon_id, got %d" % result.errors.size())
		return false
	return true


func test_validate_partial_params_reports_missing_only() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "attack", "params": {"target_id": "e1"}}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(attack partial): expected valid=false")
		return false
	var found_weapon: bool = false
	var found_target: bool = false
	for err in result.errors:
		if str(err).find("weapon_id") != -1:
			found_weapon = true
		if str(err).find("target_id") != -1:
			found_target = true
	if not found_weapon:
		push_error("validate(attack partial): expected error for 'weapon_id'")
		return false
	if found_target:
		push_error("validate(attack partial): should NOT error for 'target_id' (provided)")
		return false
	return true


# =============================================================================
# VALIDATE — condition checking
# =============================================================================

func test_validate_has_mana_condition_fails_when_no_mana() -> bool:
	var state: Dictionary = {"player_mana": 0}
	var v: ActionValidator = _make_validator(_default_schema(), state)
	var action: Dictionary = {
		"type": "cast_spell",
		"params": {"spell_id": "fireball"},
	}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(cast_spell no mana): expected valid=false")
		return false
	var found_mana: bool = false
	for err in result.errors:
		if str(err).find("has_mana") != -1:
			found_mana = true
	if not found_mana:
		push_error("validate(cast_spell no mana): expected 'has_mana' condition error")
		return false
	return true


func test_validate_has_mana_condition_passes_with_mana() -> bool:
	var state: Dictionary = {"player_mana": 50, "known_spells": ["fireball"]}
	var v: ActionValidator = _make_validator(_default_schema(), state)
	var action: Dictionary = {
		"type": "cast_spell",
		"params": {"spell_id": "fireball"},
	}
	var result: Dictionary = v.validate(action)
	if result.valid != true:
		push_error("validate(cast_spell with mana): expected valid=true, errors=%s" % str(result.errors))
		return false
	return true


func test_validate_spell_known_condition_fails_unknown_spell() -> bool:
	var state: Dictionary = {"player_mana": 50, "known_spells": ["heal"]}
	var v: ActionValidator = _make_validator(_default_schema(), state)
	var action: Dictionary = {
		"type": "cast_spell",
		"params": {"spell_id": "fireball"},
	}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(cast_spell unknown): expected valid=false")
		return false
	var found_spell: bool = false
	for err in result.errors:
		if str(err).find("spell_known") != -1:
			found_spell = true
	if not found_spell:
		push_error("validate(cast_spell unknown): expected 'spell_known' condition error")
		return false
	return true


func test_validate_multiple_conditions_can_fail_together() -> bool:
	var state: Dictionary = {"player_mana": 0, "known_spells": []}
	var v: ActionValidator = _make_validator(_default_schema(), state)
	var action: Dictionary = {
		"type": "cast_spell",
		"params": {"spell_id": "fireball"},
	}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(cast_spell both fail): expected valid=false")
		return false
	# Should have both has_mana and spell_known errors
	var mana_err: bool = false
	var spell_err: bool = false
	for err in result.errors:
		if str(err).find("has_mana") != -1:
			mana_err = true
		if str(err).find("spell_known") != -1:
			spell_err = true
	if not mana_err or not spell_err:
		push_error("validate(cast_spell both fail): expected both condition errors, mana=%s spell=%s" % [mana_err, spell_err])
		return false
	return true


# =============================================================================
# _check_condition — unknown condition passes by default
# =============================================================================

func test_check_unknown_condition_returns_true() -> bool:
	var schema: Dictionary = {
		"custom_action": {
			"conditions": ["never_heard_of_this"],
		},
	}
	var v: ActionValidator = _make_validator(schema)
	var action: Dictionary = {"type": "custom_action"}
	var result: Dictionary = v.validate(action)
	if result.valid != true:
		push_error("validate(unknown condition): expected valid=true (unknown conditions pass), errors=%s" % str(result.errors))
		return false
	return true


# =============================================================================
# _check_condition — target_in_range (always true in default impl)
# =============================================================================

func test_check_target_in_range_always_true() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {
		"type": "attack",
		"params": {"target_id": "any_target", "weapon_id": "w"},
	}
	var result: Dictionary = v.validate(action)
	# target_in_range is stubbed to always return true
	var found_range_err: bool = false
	for err in result.errors:
		if str(err).find("target_in_range") != -1:
			found_range_err = true
	if found_range_err:
		push_error("validate(attack): target_in_range should always pass")
		return false
	return true


# =============================================================================
# _check_condition — has_mana with missing game state key
# =============================================================================

func test_has_mana_defaults_to_zero_when_key_missing() -> bool:
	var v: ActionValidator = _make_validator(_default_schema(), {})
	var action: Dictionary = {
		"type": "cast_spell",
		"params": {"spell_id": "heal"},
	}
	var result: Dictionary = v.validate(action)
	# game_state_ref has no player_mana → defaults to 0 → condition fails
	var found_mana: bool = false
	for err in result.errors:
		if str(err).find("has_mana") != -1:
			found_mana = true
	if not found_mana:
		push_error("validate(no mana key): expected has_mana fail when key absent")
		return false
	return true


# =============================================================================
# VALIDATE — empty schema (no known actions)
# =============================================================================

func test_validate_with_empty_schema_rejects_all() -> bool:
	var v: ActionValidator = _make_validator({})
	var action: Dictionary = {"type": "attack", "params": {"target_id": "e1"}}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(empty schema): expected valid=false")
		return false
	var found_unknown: bool = false
	for err in result.errors:
		if str(err).find("Unknown action type") != -1:
			found_unknown = true
	if not found_unknown:
		push_error("validate(empty schema): expected 'Unknown action type' error")
		return false
	return true


# =============================================================================
# VALIDATE — result structure consistency
# =============================================================================

func test_validate_result_valid_true_means_no_errors() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "idle"}
	var result: Dictionary = v.validate(action)
	if result.valid == true and result.errors.size() != 0:
		push_error("validate: valid=true but errors not empty")
		return false
	return true


func test_validate_result_valid_false_means_has_errors() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "move"}
	var result: Dictionary = v.validate(action)
	if result.valid == false and result.errors.size() == 0:
		push_error("validate: valid=false but errors empty")
		return false
	return true


# =============================================================================
# VALIDATE — params key present but missing specific param
# =============================================================================

func test_validate_params_key_present_but_missing_specific() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {"type": "move", "params": {"speed": 5}}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(move wrong param): expected valid=false")
		return false
	var found_dir: bool = false
	for err in result.errors:
		if str(err).find("direction") != -1:
			found_dir = true
	if not found_dir:
		push_error("validate(move wrong param): expected missing 'direction' error")
		return false
	return true


# =============================================================================
# VALIDATE — action with extra fields (should still pass)
# =============================================================================

func test_validate_extra_fields_ignored() -> bool:
	var v: ActionValidator = _make_validator(_default_schema())
	var action: Dictionary = {
		"type": "idle",
		"metadata": {"source": "AI"},
		"timestamp": 12345,
	}
	var result: Dictionary = v.validate(action)
	if result.valid != true:
		push_error("validate(idle + extras): expected valid=true, errors=%s" % str(result.errors))
		return false
	return true


# =============================================================================
# VALIDATE — schema with no conditions key (params only)
# =============================================================================

func test_validate_schema_params_only_no_conditions() -> bool:
	var schema: Dictionary = {
		"gather": {"params": ["resource_type"]},
	}
	var v: ActionValidator = _make_validator(schema)
	var action: Dictionary = {"type": "gather", "params": {"resource_type": "wood"}}
	var result: Dictionary = v.validate(action)
	if result.valid != true:
		push_error("validate(gather): expected valid=true, errors=%s" % str(result.errors))
		return false
	return true


# =============================================================================
# VALIDATE — params and conditions combined failures
# =============================================================================

func test_validate_both_param_and_condition_errors() -> bool:
	var state: Dictionary = {"player_mana": 0, "known_spells": []}
	var v: ActionValidator = _make_validator(_default_schema(), state)
	# cast_spell requires spell_id param + has_mana + spell_known conditions
	var action: Dictionary = {"type": "cast_spell"}
	var result: Dictionary = v.validate(action)
	if result.valid != false:
		push_error("validate(cast_spell no params no mana): expected valid=false")
		return false
	# Should have param error (spell_id) + condition errors (has_mana, spell_known)
	if result.errors.size() < 3:
		push_error("validate(cast_spell no params no mana): expected >=3 errors, got %d: %s" % [result.errors.size(), str(result.errors)])
		return false
	return true
