extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame
	await physics_frame

	var player := game.player as PlayerController
	var hud := game.hud as GameHUD
	var console := game.world.call(
		&"get_planetary_destination_console"
	) as Area3D
	_check(
		is_instance_valid(console)
		and console.get_parent().name == &"ConsoleBay01",
		"Aft Operations Console Bay 01 contains the physical Destination Board terminal",
	)
	if not is_instance_valid(console) or not is_instance_valid(player) or hud == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var header := console.find_child(
		"PlanetaryDestinationHeader", true, false
	) as MeshInstance3D
	var collision := console.find_child(
		"InteractionCollision", true, false
	) as CollisionShape3D
	_check(
		is_instance_valid(header)
		and header.mesh is TextMesh
		and (header.mesh as TextMesh).text == "DESTINATION BOARD"
		and is_instance_valid(collision)
		and collision.shape is BoxShape3D,
		"the physical screen is labelled at a glance and has one ordinary interaction volume",
	)

	var report := console.call(&"get_presentation_snapshot") as Dictionary
	var authority := report.get("authority", {}) as Dictionary
	_check(
		int(report.get("destination_count", 0)) == 3
		and int(report.get("routed_destination_count", 0)) == 3
		and str(report.get("status_text", "")) == "3 WORLDS // 3 ROUTES"
		and str(report.get("route_text", "")).begins_with("EMBER // ")
		and authority.values().all(
			func(value: Variant) -> bool: return value == false
		),
		"GameFlow mirrors the retained three-world catalog without giving the console gameplay authority",
	)
	var retained_report := report.duplicate(true)
	_check(
		not bool(console.call(
			&"present_catalog_status", 2, 3, &"ready"
		))
		and console.call(&"get_presentation_snapshot") == retained_report,
		"invalid route counts fail closed without repainting the retained display",
	)

	# These are real cruise states, not arrival/holding: overspeed reduction
	# retains cruise participation, while ordinary braking can still be moving.
	var route_label := console.find_child(
		"PlanetaryDestinationEmberStatus", true, false
	) as MeshInstance3D
	for braking: Array in [
		[&"braking_to_speed", "EMBER // BRAKING TO SPEED"],
		[&"braking", "EMBER // BRAKING"],
	]:
		var accepted := bool(console.call(&"present_catalog_status",
			int(retained_report.destination_count),
			int(retained_report.routed_destination_count), braking[0]))
		var braking_report := console.call(&"get_presentation_snapshot") as Dictionary
		_check(
			accepted and is_instance_valid(route_label) and route_label.mesh is TextMesh
			and (route_label.mesh as TextMesh).text == braking[1]
			and braking_report.get("route_text") == braking[1]
			and braking_report.get("ember_status_id") == braking[0]
			and braking_report.get("status_text") == retained_report.status_text
			and braking_report.get("authority") == authority,
			"the physical terminal reports %s without claiming arrival or holding, changing the catalog, or acquiring authority" % braking[0],
		)
	_check(bool(console.call(&"present_catalog_status",
		int(retained_report.destination_count), int(retained_report.routed_destination_count),
		retained_report.ember_status_id))
		and console.call(&"get_presentation_snapshot") == retained_report,
		"the next live catalog status replaces braking feedback on the same terminal")

	var approach := console.global_position + Vector3(0.0, 0.0, -1.05)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), approach))
	await physics_frame
	await physics_frame
	await process_frame
	# The production interact handler deliberately recomputes this physics-owned
	# candidate synchronously before deciding, so exercise that exact decision
	# boundary instead of relying on the preceding idle cache.
	game.call(&"_refresh_interaction_targets")
	var interaction_candidate := game.station_interaction_candidate as Node3D
	_check(
		interaction_candidate == console
		and "DESTINATION BOARD" in str(console.call(&"get_interaction_prompt")),
		"facing Console Bay 01 selects its Destination Board prompt (candidate: %s)"
			% (
				str(interaction_candidate.get_path())
				if is_instance_valid(interaction_candidate)
				else "none"
			),
	)

	var catalog_before := game.get_planetary_destination_catalog_snapshot()
	var cruise_before := game.planetary_cruise_binding.get_snapshot().duplicate(true)
	var connection_count := console.get_signal_connection_list(&"open_requested").size()
	game.call(&"_on_interact_requested")
	await process_frame
	var pause_overlay := hud.get("_pause") as Control
	var destination_page := hud.get("_planetary_destination_page") as Control
	var focus_owner := root.gui_get_focus_owner()
	_check(
		is_instance_valid(pause_overlay)
		and pause_overlay.visible
		and is_instance_valid(destination_page)
		and destination_page.visible,
		"one embodied interaction pauses and opens the existing Destination Board page",
	)
	_check(
		is_instance_valid(focus_owner)
		and focus_owner.name == &"PlanetaryDestinationBackButton",
		"the physical route skips the correctly disabled on-foot Ember action and focuses Back",
	)
	var cruise_after := game.planetary_cruise_binding.get_snapshot()
	_check(
		game.get_planetary_destination_catalog_snapshot() == catalog_before
		and cruise_after.get("generation") == cruise_before.get("generation")
		and cruise_after.get("engagement_requested")
			== cruise_before.get("engagement_requested"),
		"opening the terminal selects no world and starts no planetary journey",
	)

	# The sector's own enterable places are listed beside the worlds. The pilot
	# is on foot in the yard with Cinder streamed out, so both are shown and
	# both are honestly refused.
	var board := hud.get_planetary_destination_report()
	var board_snapshot := board.get("snapshot", {}) as Dictionary
	var site_rows := board_snapshot.get("sector_sites", []) as Array
	var site_ids := PackedStringArray()
	for row_variant: Variant in site_rows:
		site_ids.append(str((row_variant as Dictionary).get("destination_id", &"")))
	_check(
		int(board_snapshot.get("destination_count", -1)) == 3
		and int(board_snapshot.get("sector_site_count", -1)) == 2
		and site_ids == PackedStringArray([
			"cinder_hulk_dock_site", "cinder_belt_bore_site",
		]),
		"the Destination Board lists the hulk dock and the belt bore beside the worlds",
	)
	var site_cards_present := true
	var site_actions_refused := true
	for row_variant: Variant in board.get("sector_site_actions", []) as Array:
		var action_row := row_variant as Dictionary
		if not bool(action_row.get("button_disabled", false)):
			site_actions_refused = false
		if str(action_row.get("button_text", "")) != "OUT OF SENSOR RANGE":
			site_actions_refused = false
	for site_id in site_ids:
		if not is_instance_valid(
			hud.get("_planetary_destination_rows").find_child(
				"PlanetaryDestination_%s" % site_id, true, false
			)
		):
			site_cards_present = false
	_check(
		site_cards_present and site_actions_refused,
		"each place has a board card that refuses while the pilot is in the yard",
	)
	_check(
		not bool(game.call(
			&"_on_hud_sector_site_briefing_requested", &"cinder_hulk_dock_site"
		))
		and not bool(game.call(
			&"_on_hud_sector_site_briefing_requested", &"cinder_nowhere_site"
		)),
		"the site action refuses an absent place and an unlisted one alike",
	)
	var catalog_after_site := game.get_planetary_destination_catalog_snapshot()
	_check(
		catalog_after_site.get("destination_count") == 3
		and catalog_after_site.get("sector_site_count") == 2
		and (catalog_after_site.get("available_sector_site_ids", PackedStringArray())
			as PackedStringArray).is_empty(),
		"asking about a place never streams a sector in or makes it reachable",
	)
	await _test_destination_board_small_viewport(game, hud)

	hud.set_paused(false)
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var rebound := game.world.call(
		&"get_planetary_destination_console"
	) as Area3D
	_check(
		rebound == console
		and rebound.get_signal_connection_list(&"open_requested").size()
			== connection_count
		and rebound.call(&"get_presentation_snapshot") == retained_report,
		"Main detach and re-entry retain one terminal, one binding, and the same catalog display",
	)

	game.queue_free()
	await process_frame
	await process_frame
	_finish()


## One actual production roster/cell. Keep this beside the real console route:
## the detached panel test's two-world fixture cannot protect the five-card board.
func _test_destination_board_small_viewport(game: GameFlow, hud: GameHUD) -> void:
	var previous_size := root.size
	var previous_content_size := root.content_scale_size
	var previous_aspect := root.content_scale_aspect
	var previous_scale := hud.get_ui_scale()
	var was_processing := game.is_processing()
	var was_physics_processing := game.is_physics_processing()
	game.set_process(false)
	game.set_physics_process(false)
	var original := game.get_planetary_destination_catalog_snapshot()
	var cruise_before := game.planetary_cruise_binding.get_snapshot().duplicate(true)
	var requests: Array[StringName] = []
	var on_travel := func(destination_id: StringName, _serial: int) -> void:
		requests.append(destination_id)
	var on_site := func(site_id: StringName) -> void: requests.append(site_id)
	hud.planetary_destination_requested.connect(on_travel)
	hud.sector_site_briefing_requested.connect(on_site)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1024, 768)
	root.size = Vector2i(1024, 768)
	hud.set_ui_scale(GameHUD.MAX_UI_SCALE)
	await process_frame
	await process_frame
	var page := hud.get("_planetary_destination_page") as Control
	var rows := hud.get("_planetary_destination_rows") as VBoxContainer
	var back := hud.get("_planetary_destination_back_button") as Button
	var effective := GameHUD.compute_effective_pause_ui_scale(
		GameHUD.MAX_UI_SCALE, Vector2(1024, 768))
	var safe := preload("res://scripts/ui/ultrawide_safe_area_contract.gd").safe_rect(
		Vector2(1024, 768), effective)
	print("MEASURED: actual five-card Destination Board 1024x768 request %.2f -> effective %.6f page %s"
		% [GameHUD.MAX_UI_SCALE, effective, page.get_global_rect()])
	_check(root.get_visible_rect().size == Vector2(1024, 768)
		and is_equal_approx(hud.get_ui_scale(), GameHUD.MAX_UI_SCALE),
		"Destination Board cell uses actual 1024x768 and the authored maximum request")
	_check(rows.get_child_count() == 5,
		"Destination Board cell retains all three production worlds and both sector sites")
	_check(safe.grow(0.75).encloses(page.get_global_rect()),
		"Destination Board five-card page fits the 1024x768 readable bounds")
	_check(safe.grow(0.75).encloses(back.get_global_rect()),
		"Destination Board Back remains wholly inside the readable bounds")
	# Header/subtitle belong outside the row region and must remain visible.
	for candidate: Node in page.find_children("*", "Label", true, false):
		if not rows.is_ancestor_of(candidate):
			var label := candidate as Label
			_check(safe.grow(0.75).encloses(label.get_global_rect()),
				"Destination Board header copy remains wholly visible: %s" % label.text)
			_check_destination_label_fits(label)
	for child: Node in rows.get_children():
		var card := child as Control
		var scroll: ScrollContainer
		var ancestor := card.get_parent()
		while ancestor != null and ancestor != page:
			if ancestor is ScrollContainer:
				scroll = ancestor as ScrollContainer
				break
			ancestor = ancestor.get_parent()
		if scroll != null:
			scroll.ensure_control_visible(card)
			await process_frame
			await process_frame
		var readable := page.get_global_rect() if scroll == null else scroll.get_global_rect()
		_check(safe.grow(0.75).encloses(readable)
			and readable.grow(0.75).encloses(card.get_global_rect())
			and not card.get_global_rect().intersects(back.get_global_rect()),
			"Destination Board card is completely readable through authored scrolling: %s" % card.name)
		var action := card.find_child("PlanetaryDestinationAction_*", true, false) as Button
		_check(action != null
			and card.get_global_rect().grow(0.75).encloses(action.get_global_rect())
			and readable.grow(0.75).encloses(action.get_global_rect())
			and action.size.x + 0.75 >= action.get_minimum_size().x,
			"Destination Board contains the complete action, including disabled guidance: %s" % card.name)
		for candidate: Node in card.find_children("*", "Label", true, false):
			var label := candidate as Label
			_check(card.get_global_rect().grow(0.75).encloses(label.get_global_rect()),
				"Destination Board card contains essential copy: %s/%s" % [card.name, label.name])
			_check_destination_label_fits(label)
	# Obtain a ready Ember row through the same catalog/presentation bridge used
	# by Main. Do not forge a synthetic roster or trigger the travel action.
	var ready := game.call(&"_make_planetary_destination_catalog_snapshot", {
		"status_id": &"ready", "status_text": "READY — EMBER MOON",
		"toggle_enabled": true, "engagement_requested": false,
	}) as Dictionary
	var ember := rows.find_child("PlanetaryDestinationAction_ember_moon", true, false) as Button
	var retained_card := ember.get_parent().get_parent().get_parent()
	var retained_status := retained_card.find_child("PlanetaryDestinationStatus", true, false)
	_check(hud.set_planetary_destination_snapshot(ready),
		"Destination Board accepts the real production catalog's ready presentation")
	await process_frame
	await process_frame
	var ordered: Array[Button] = []
	for child: Node in rows.get_children():
		var action := child.find_child("PlanetaryDestinationAction_*", true, false) as Button
		if action.disabled:
			_check(action.focus_mode == Control.FOCUS_NONE,
				"Destination Board skips disabled action focus: %s" % action.name)
		else:
			ordered.append(action)
			_check(action.focus_mode == Control.FOCUS_ALL,
				"Destination Board retains enabled action focus: %s" % action.name)
			# Exercise focus-follow itself, without ensure_control_visible here.
			action.grab_focus()
			await process_frame
			await process_frame
			var ancestor := action.get_parent()
			var readable := safe
			while ancestor != null and ancestor != page:
				if ancestor is ScrollContainer:
					readable = (ancestor as Control).get_global_rect()
					break
				ancestor = ancestor.get_parent()
			_check(root.gui_get_focus_owner() == action
				and readable.grow(0.75).encloses(action.get_global_rect())
				and action.size.x + 0.75 >= action.get_minimum_size().x,
				"Destination Board enabled focus reveals the complete action: %s" % action.name)
	_check(ordered.has(ember), "Destination Board ready cell exercises enabled Ember travel focus")
	ordered.append(back)
	for index in ordered.size():
		var action := ordered[index]
		_check(action.get_node_or_null(action.focus_neighbor_top) == ordered[maxi(0, index - 1)]
			and action.get_node_or_null(action.focus_neighbor_bottom) == ordered[mini(ordered.size() - 1, index + 1)],
			"Destination Board focus chain includes only enabled actions and Back: %s" % action.name)
	# Exercise the last site's ordinary briefing affordance as a presentation
	# state. The actual on-foot refusal above remains the gameplay authority.
	var world_states: Dictionary = {}
	for row: Dictionary in ready.get("destinations", []):
		world_states[row.destination_id] = {
			"status_id": row.status_id, "status_text": row.status_text,
			"action_enabled": row.action_enabled,
			"engagement_requested": row.engagement_requested,
		}
	var catalog := game.get("_planetary_destination_catalog") as RefCounted
	var nearby := catalog.call(&"get_presentation_snapshot", world_states, {
		&"cinder_belt_bore_site": {"reachable": true},
	}) as Dictionary
	var bore := rows.find_child(
		"PlanetaryDestinationAction_cinder_belt_bore_site", true, false) as Button
	_check(hud.set_planetary_destination_snapshot(nearby)
		and not bore.disabled and bore.text == "SHOW BRIEFING",
		"Destination Board accepts the retained production catalog's reachable Bore briefing state")
	var scroll := rows.get_parent() as ScrollContainer
	_check(scroll != null, "Destination Board supplies authored scrolling for enabled site focus")
	if scroll != null:
		scroll.scroll_vertical = 0
		ember.grab_focus()
		await process_frame
		await process_frame
		var next := ember.get_node_or_null(ember.focus_neighbor_bottom) as Button
		_check(next == bore and bore.get_node_or_null(bore.focus_neighbor_bottom) == back
			and back.get_node_or_null(back.focus_neighbor_top) == bore,
			"Destination Board enabled briefing joins the travel-to-Back focus chain")
		if next != null:
			next.grab_focus()
			await process_frame
			await process_frame
		_check(root.gui_get_focus_owner() == bore and scroll.scroll_vertical > 0
			and scroll.get_global_rect().grow(0.75).encloses(bore.get_global_rect())
			and bore.size.x + 0.75 >= bore.get_minimum_size().x,
			"Destination Board focus-follow reveals the complete final site briefing action from scroll top")
	back.grab_focus()
	_check(hud.set_planetary_destination_snapshot(original),
		"Destination Board restores the ordinary on-foot production presentation")
	await process_frame
	await process_frame
	_check(rows.find_child("PlanetaryDestinationAction_ember_moon", true, false) == ember
		and rows.find_child("PlanetaryDestinationAction_cinder_belt_bore_site", true, false) == bore
		and retained_card.find_child("PlanetaryDestinationStatus", true, false) == retained_status
		and root.gui_get_focus_owner() == back and ember.disabled and bore.disabled,
		"Destination Board refresh retains row/status identity and chosen Back focus")
	_check(requests.is_empty()
		and game.planetary_cruise_binding.get_snapshot() == cruise_before
		and game.get_planetary_destination_catalog_snapshot() == original,
		"Destination Board layout, scrolling and focus dispatch no travel or site request")
	hud.planetary_destination_requested.disconnect(on_travel)
	hud.sector_site_briefing_requested.disconnect(on_site)
	root.content_scale_aspect = previous_aspect
	root.content_scale_size = previous_content_size
	root.size = previous_size
	hud.set_ui_scale(previous_scale)
	game.set_process(was_processing)
	game.set_physics_process(was_physics_processing)
	await process_frame
	await process_frame


func _check_destination_label_fits(label: Label) -> void:
	var fits := label.get_visible_line_count() == label.get_line_count()
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var font := label.get_theme_font("font")
		fits = fits and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, label.get_theme_font_size("font_size")).x <= label.size.x + 0.75
	_check(fits and not label.clip_text,
		"Destination Board essential label is untruncated: %s" % label.text)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"PLANETARY_DESTINATION_CONSOLE_PRODUCTION_TEST_OK: %d assertions"
			% _assertions
		)
		quit(0)
	else:
		print(
			"PLANETARY_DESTINATION_CONSOLE_PRODUCTION_TEST_FAILED: %s"
			% ", ".join(_failures)
		)
		quit(1)
