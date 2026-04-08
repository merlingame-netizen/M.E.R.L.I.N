## Headless parchment screenshot test.
## Generates a parchment, sets final state directly, captures viewport to PNG.
## Run: godot --path . -s scripts/test/headless_parchment_test.gd --position -3000,-3000

extends SceneTree


func _init() -> void:
	root.ready.connect(_run_test)


func _run_test() -> void:
	print("[HEADLESS-TEST] Starting parchment screenshot test...")

	var ctx: Dictionary = {
		"biome_id": "broceliande",
		"ogham_id": "beith",
		"faction_rep": 35,
		"previous_runs": 2,
		"explored_detours": [],
		"weather": "pluie",
		"festival": "",
		"trust_tier": "T1",
		"trust_value": 50,
	}

	var graph: MerlinRunGraph = MerlinSkeletonGenerator._generate_procedural(ctx)
	if graph == null:
		print("[HEADLESS-TEST] ERROR: graph is null")
		quit(1)
		return

	var validation: Dictionary = graph.validate()
	if not validation["valid"]:
		print("[HEADLESS-TEST] ERROR: graph invalid")
		for err in validation["errors"]:
			print("  - %s" % err)
		quit(1)
		return

	print("[HEADLESS-TEST] Graph OK — %d main nodes, title: %s" % [graph.main_path.size(), graph.scenario_title])
	print("[HEADLESS-TEST] Synopsis (%d chars): %s..." % [graph.scenario_synopsis.length(), graph.scenario_synopsis.substr(0, 120)])

	# Create SubViewport for offscreen rendering.
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)

	# Create the parchment inside the viewport with explicit size.
	var parchment: ParchmentDisplay = ParchmentDisplay.new()
	parchment.position = Vector2.ZERO
	parchment.size = Vector2(1280, 720)
	vp.add_child(parchment)

	# Wait for layout to propagate through anchors.
	for _i in range(8):
		await process_frame

	# Force sizes on all children (anchors don't auto-resolve in SubViewport).
	parchment.size = Vector2(1280, 720)
	for child in parchment.get_children():
		if child is Control:
			child.size = Vector2(
				(child.anchor_right - child.anchor_left) * 1280.0,
				(child.anchor_bottom - child.anchor_top) * 720.0
			)
			child.position = Vector2(child.anchor_left * 1280.0, child.anchor_top * 720.0)
	# Force map canvas size explicitly.
	if parchment._map_canvas:
		var map_parent: Control = parchment._map_canvas.get_parent() as Control
		if map_parent:
			map_parent.size = Vector2(1250, 470)
			map_parent.position = Vector2(15, 220)
		parchment._map_canvas.size = Vector2(1250, 470)

	for _i in range(4):
		await process_frame

	print("[HEADLESS-TEST] Parchment size: %s" % str(parchment.size))
	print("[HEADLESS-TEST] Map canvas: %s" % str(parchment._map_canvas.size if parchment._map_canvas else "null"))

	# Set final state directly (no animation).
	parchment._graph = graph
	parchment.visible = true
	parchment.modulate = Color(1, 1, 1, 1)

	# Set title and text — force width for proper wrapping in SubViewport.
	if parchment._title_label:
		parchment._title_label.text = graph.scenario_title
		parchment._title_label.size.x = 1200.0
	if parchment._text_label:
		parchment._text_label.text = graph.scenario_synopsis
		parchment._text_label.size.x = 1200.0
		parchment._text_label.size.y = 140.0

	# Compute trail with actual canvas size.
	parchment._compute_winding_trail()

	print("[HEADLESS-TEST] Trail points: %d" % parchment._trail_points.size())
	print("[HEADLESS-TEST] Node positions: %d" % parchment._node_positions.size())

	# Reveal all trail and nodes (simulate quill having completed).
	parchment._revealed_trail_count = parchment._trail_points.size()
	parchment._quill_index = parchment._trail_points.size()
	parchment._quill_visible = false
	parchment._time_elapsed = 2.0
	parchment._revealed_node_ids.clear()
	for nid in graph.main_path:
		parchment._revealed_node_ids.append(nid)
		parchment._node_reveal_times[nid] = 1.0
	for nid in graph.nodes:
		if graph.nodes[nid].get("is_detour", false):
			parchment._revealed_node_ids.append(nid)
			parchment._node_reveal_times[nid] = 1.0

	# Spawn decorations along the trail (simulate quill pass).
	for i in range(0, parchment._trail_points.size(), 5):
		parchment._spawn_decoration(parchment._trail_points[i])

	# Force redraw.
	if parchment._map_canvas:
		parchment._map_canvas.queue_redraw()

	# Wait for rendering.
	for _i in range(6):
		await process_frame

	# Capture screenshot.
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("[HEADLESS-TEST] ERROR: could not get viewport image")
		quit(1)
		return

	var run_id: String = str(randi() % 9999)
	var out_path: String = "C:/Users/PGNK2128/Downloads/parchment_bk_%s.png" % run_id
	var err: int = img.save_png(out_path)
	if err != OK:
		print("[HEADLESS-TEST] ERROR saving PNG: %d" % err)
		quit(1)
		return

	print("[HEADLESS-TEST] Screenshot saved to: %s" % out_path)
	print("[HEADLESS-TEST] Image size: %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
