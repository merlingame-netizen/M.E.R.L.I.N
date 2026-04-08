## ═══════════════════════════════════════════════════════════════════════════════
## Test Scene — Skeleton Map System visual runner
## ═══════════════════════════════════════════════════════════════════════════════
## Runs all 18 unit tests + displays a procedural graph + parchment preview.
## Launch: godot --path . scenes/test_skeleton_map.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Control


var _log_label: RichTextLabel = null
var _parchment: ParchmentDisplay = null
var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	_build_ui()
	await _run_tests()
	await _show_parchment_demo()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_active = true
	_log_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log_label.add_theme_color_override("default_color", Color(0.85, 0.65, 0.13))
	_log_label.add_theme_font_size_override("normal_font_size", 18)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	margin.add_child(_log_label)


func _log(text: String) -> void:
	print(text)
	if _log_label:
		_log_label.append_text(text + "\n")


func _run_tests() -> void:
	_log("[b]═══ SKELETON MAP TESTS ═══[/b]\n")

	var runner: RefCounted = load("res://scripts/test/test_skeleton_map.gd").new()
	var methods: Array = []

	# Collect all test methods.
	for m in runner.get_method_list():
		var mname: String = str(m.get("name", ""))
		if mname.begins_with("test_"):
			methods.append(mname)

	methods.sort()
	_total = methods.size()
	_passed = 0
	_failed = 0

	for mname in methods:
		var result: bool = runner.call(mname)
		if result:
			_passed += 1
			_log("[color=green]PASS[/color]  %s" % mname)
		else:
			_failed += 1
			_log("[color=red]FAIL[/color]  %s" % mname)

	_log("")
	var color: String = "green" if _failed == 0 else "red"
	_log("[b][color=%s]Results: %d/%d passed (%d failed)[/color][/b]" % [color, _passed, _total, _failed])
	_log("")


func _show_parchment_demo() -> void:
	if _failed > 0:
		_log("[color=yellow]Skipping parchment demo due to test failures.[/color]")
		return

	_log("[b]═══ PARCHMENT DEMO ═══[/b]")
	_log("Generating procedural skeleton for foret_broceliande...")

	var ctx: Dictionary = {
		"biome_id": "foret_broceliande",
		"ogham_id": "beith",
		"faction_rep": 20,
		"previous_runs": 0,
		"explored_detours": [],
		"weather": "brume_legere",
		"festival": "",
		"trust_tier": 1,
		"trust_value": 50,
	}

	var graph: MerlinRunGraph = MerlinSkeletonGenerator._generate_procedural(ctx)
	var validation: Dictionary = graph.validate()

	_log("Graph: %d main nodes, %d detour nodes, valid=%s" % [
		graph.main_path.size(),
		graph.total_detour_nodes,
		str(validation["valid"]),
	])

	for nid in graph.main_path:
		var node: Dictionary = graph.nodes.get(nid, {})
		var det: String = " [detour: %s]" % str(node.get("detour_entry", "")) if str(node.get("detour_entry", "")) != "" and str(node.get("detour_entry", "")) != "null" else ""
		_log("  [%s] %s — %s%s" % [nid, str(node.get("type", "")), str(node.get("label", "")), det])

	_log("")
	_log("Showing parchment display in 2 seconds...")
	await get_tree().create_timer(2.0).timeout

	# Hide log, show parchment.
	_log_label.visible = false

	_parchment = ParchmentDisplay.new()
	add_child(_parchment)
	_parchment.reveal(graph)
	await _parchment.animation_finished

	_log_label.visible = true
	_log("[color=green]Parchment animation complete![/color]")

	# Keep parchment visible for inspection, dismiss after 5s.
	await get_tree().create_timer(5.0).timeout
	if _parchment:
		await _parchment.dismiss()
		_log("Demo finished. Close the window to exit.")
