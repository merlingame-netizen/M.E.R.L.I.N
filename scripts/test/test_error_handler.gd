## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — ErrorHandler & HealthMonitor
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: report, severity filtering, recovery strategies, signal emission,
## log persistence, health monitor checks.
## ═══════════════════════════════════════════════════════════════════════════════

extends GutTest

var handler: ErrorHandler
var monitor: HealthMonitor


func before_each() -> void:
	handler = ErrorHandler.new()
	handler._ready()
	monitor = HealthMonitor.new()


func after_each() -> void:
	if handler:
		handler.clear()
		handler.clear_persisted_log()
		handler.queue_free()
		handler = null
	if monitor:
		monitor.queue_free()
		monitor = null


# ═══════════════════════════════════════════════════════════════════════════════
# ERROR REPORTING
# ═══════════════════════════════════════════════════════════════════════════════

func test_report_adds_error() -> void:
	handler.report("card_system", ErrorHandler.Severity.WARNING, "Card pool empty")
	assert_eq(handler.get_error_count(), 1, "Should have 1 error after report")


func test_report_multiple_errors() -> void:
	handler.report("card_system", ErrorHandler.Severity.INFO, "Loading cards")
	handler.report("llm_adapter", ErrorHandler.Severity.WARNING, "LLM slow")
	handler.report("save_system", ErrorHandler.Severity.ERROR, "Save failed")
	assert_eq(handler.get_error_count(), 3, "Should have 3 errors")


func test_report_stores_correct_data() -> void:
	var ctx: Dictionary = {"biome": "foret_broceliande", "card_index": 5}
	handler.report("effect_engine", ErrorHandler.Severity.ERROR, "Effect overflow", ctx)
	var last: Dictionary = handler.get_last_error()
	assert_eq(str(last.get("system", "")), "effect_engine", "System should match")
	assert_eq(int(last.get("severity", -1)), ErrorHandler.Severity.ERROR, "Severity should match")
	assert_eq(str(last.get("message", "")), "Effect overflow", "Message should match")
	assert_eq(str(last.get("severity_name", "")), "ERROR", "Severity name should be ERROR")
	var stored_ctx: Dictionary = last.get("context", {})
	assert_eq(str(stored_ctx.get("biome", "")), "foret_broceliande", "Context biome should match")


func test_report_clamps_severity() -> void:
	handler.report("test", -5, "Below minimum")
	var last: Dictionary = handler.get_last_error()
	assert_eq(int(last.get("severity", -1)), ErrorHandler.Severity.INFO, "Should clamp to INFO")

	handler.report("test", 99, "Above maximum")
	last = handler.get_last_error()
	assert_eq(int(last.get("severity", -1)), ErrorHandler.Severity.CRITICAL, "Should clamp to CRITICAL")


# ═══════════════════════════════════════════════════════════════════════════════
# SEVERITY FILTERING
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_errors_filters_by_severity() -> void:
	handler.report("a", ErrorHandler.Severity.INFO, "Info msg")
	handler.report("b", ErrorHandler.Severity.WARNING, "Warning msg")
	handler.report("c", ErrorHandler.Severity.ERROR, "Error msg")
	handler.report("d", ErrorHandler.Severity.CRITICAL, "Critical msg")

	var warnings_up: Array = handler.get_errors(ErrorHandler.Severity.WARNING)
	assert_eq(warnings_up.size(), 3, "WARNING+ should return 3 entries")

	var errors_up: Array = handler.get_errors(ErrorHandler.Severity.ERROR)
	assert_eq(errors_up.size(), 2, "ERROR+ should return 2 entries")

	var criticals: Array = handler.get_errors(ErrorHandler.Severity.CRITICAL)
	assert_eq(criticals.size(), 1, "CRITICAL should return 1 entry")

	var all: Array = handler.get_errors(ErrorHandler.Severity.INFO)
	assert_eq(all.size(), 4, "INFO+ should return all 4 entries")


func test_get_errors_empty_when_no_match() -> void:
	handler.report("a", ErrorHandler.Severity.INFO, "Just info")
	var errors: Array = handler.get_errors(ErrorHandler.Severity.ERROR)
	assert_eq(errors.size(), 0, "Should return 0 when no errors at that severity")


# ═══════════════════════════════════════════════════════════════════════════════
# HAS_CRITICAL
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_critical_false_when_empty() -> void:
	assert_false(handler.has_critical(), "Should be false with no errors")


func test_has_critical_false_with_only_warnings() -> void:
	handler.report("a", ErrorHandler.Severity.WARNING, "Just a warning")
	handler.report("b", ErrorHandler.Severity.ERROR, "An error")
	assert_false(handler.has_critical(), "Should be false without CRITICAL")


func test_has_critical_true_when_critical_exists() -> void:
	handler.report("a", ErrorHandler.Severity.CRITICAL, "System crash")
	assert_true(handler.has_critical(), "Should be true with CRITICAL error")


# ═══════════════════════════════════════════════════════════════════════════════
# CLEAR
# ═══════════════════════════════════════════════════════════════════════════════

func test_clear_removes_all_errors() -> void:
	handler.report("a", ErrorHandler.Severity.ERROR, "err1")
	handler.report("b", ErrorHandler.Severity.CRITICAL, "err2")
	assert_eq(handler.get_error_count(), 2)
	handler.clear()
	assert_eq(handler.get_error_count(), 0, "Should be empty after clear")
	assert_false(handler.has_critical(), "No criticals after clear")


# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM ERROR COUNT
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_system_error_count() -> void:
	handler.report("card_system", ErrorHandler.Severity.WARNING, "w1")
	handler.report("llm_adapter", ErrorHandler.Severity.ERROR, "e1")
	handler.report("card_system", ErrorHandler.Severity.ERROR, "e2")
	assert_eq(handler.get_system_error_count("card_system"), 2, "card_system should have 2 errors")
	assert_eq(handler.get_system_error_count("llm_adapter"), 1, "llm_adapter should have 1 error")
	assert_eq(handler.get_system_error_count("unknown_sys"), 0, "unknown system should have 0")


# ═══════════════════════════════════════════════════════════════════════════════
# GET LAST ERROR
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_last_error_empty_when_none() -> void:
	var last: Dictionary = handler.get_last_error()
	assert_true(last.is_empty(), "Should return empty dict when no errors")


func test_get_last_error_returns_most_recent() -> void:
	handler.report("a", ErrorHandler.Severity.INFO, "first")
	handler.report("b", ErrorHandler.Severity.WARNING, "second")
	var last: Dictionary = handler.get_last_error()
	assert_eq(str(last.get("message", "")), "second", "Should return most recent error")


# ═══════════════════════════════════════════════════════════════════════════════
# RECOVERY STRATEGIES
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_strategies_registered() -> void:
	var keys: Array = handler.get_strategy_keys()
	assert_true(keys.has("card_loading_failure"), "Should have card_loading_failure strategy")
	assert_true(keys.has("llm_timeout"), "Should have llm_timeout strategy")
	assert_true(keys.has("save_corruption"), "Should have save_corruption strategy")
	assert_true(keys.has("effect_overflow"), "Should have effect_overflow strategy")
	assert_true(keys.has("scene_transition_failure"), "Should have scene_transition_failure strategy")
	assert_true(keys.has("audio_failure"), "Should have audio_failure strategy")


func test_get_strategy_returns_correct_data() -> void:
	var strategy: Dictionary = handler.get_strategy("llm_timeout")
	assert_eq(str(strategy.get("action", "")), "use_fastroute", "LLM timeout action should be use_fastroute")
	assert_false(str(strategy.get("description", "")).is_empty(), "Should have a description")


func test_get_strategy_returns_empty_for_unknown() -> void:
	var strategy: Dictionary = handler.get_strategy("nonexistent_failure")
	assert_true(strategy.is_empty(), "Should return empty for unknown failure type")


func test_attempt_recovery_known_failure() -> void:
	var result: Dictionary = handler.attempt_recovery("card_loading_failure")
	assert_true(result.get("recovered", false), "Should recover from known failure")
	assert_eq(str(result.get("action", "")), "use_fallback_pool", "Action should be use_fallback_pool")


func test_attempt_recovery_unknown_failure() -> void:
	var result: Dictionary = handler.attempt_recovery("totally_unknown_failure")
	assert_false(result.get("recovered", true), "Should not recover from unknown failure")
	assert_eq(str(result.get("action", "")), "none", "Action should be none")


func test_register_custom_strategy() -> void:
	handler.register_strategy("custom_failure", {
		"description": "Custom recovery",
		"action": "do_custom_thing",
	})
	var strategy: Dictionary = handler.get_strategy("custom_failure")
	assert_eq(str(strategy.get("action", "")), "do_custom_thing", "Custom strategy should be retrievable")


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL EMISSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_error_reported_signal_emitted() -> void:
	var received: Array = []
	handler.error_reported.connect(func(sys: String, sev: int, msg: String) -> void:
		received.append({"system": sys, "severity": sev, "message": msg})
	)
	handler.report("audio", ErrorHandler.Severity.WARNING, "Speaker not found")
	assert_eq(received.size(), 1, "Signal should be emitted once")
	assert_eq(str(received[0].get("system", "")), "audio", "Signal system should match")
	assert_eq(int(received[0].get("severity", -1)), ErrorHandler.Severity.WARNING, "Signal severity should match")


# ═══════════════════════════════════════════════════════════════════════════════
# MAX ERRORS TRIMMING
# ═══════════════════════════════════════════════════════════════════════════════

func test_errors_trimmed_at_max_capacity() -> void:
	for i in range(ErrorHandler.MAX_ERRORS + 50):
		handler.report("stress", ErrorHandler.Severity.INFO, "msg_%d" % i)
	assert_true(handler.get_error_count() <= ErrorHandler.MAX_ERRORS,
		"Error count should not exceed MAX_ERRORS (%d)" % ErrorHandler.MAX_ERRORS)
	# Verify the oldest were trimmed (last entry should be the most recent)
	var last: Dictionary = handler.get_last_error()
	var expected_msg: String = "msg_%d" % (ErrorHandler.MAX_ERRORS + 49)
	assert_eq(str(last.get("message", "")), expected_msg, "Most recent error should be preserved")


# ═══════════════════════════════════════════════════════════════════════════════
# HEALTH MONITOR — Basic tests (no scene tree needed)
# ═══════════════════════════════════════════════════════════════════════════════

func test_health_monitor_initial_state() -> void:
	var status: Dictionary = monitor.get_health_status()
	assert_eq(int(status.get("check_count", -1)), 0, "Check count should start at 0")
	assert_eq(int(status.get("warnings_emitted", -1)), 0, "Warnings should start at 0")
	assert_true(status.get("enabled", false), "Should be enabled by default")


func test_health_monitor_get_memory() -> void:
	var status: Dictionary = monitor.get_health_status()
	var mem: float = float(status.get("memory_current_mb", 0.0))
	assert_true(mem > 0.0, "Memory usage should be positive (got %.1f MB)" % mem)
