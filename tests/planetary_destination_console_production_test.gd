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
		int(report.get("destination_count", 0)) == 2
		and int(report.get("routed_destination_count", 0)) == 1
		and str(report.get("status_text", "")) == "2 WORLDS // 1 ROUTE"
		and str(report.get("route_text", "")).begins_with("EMBER // ")
		and authority.values().all(
			func(value: Variant) -> bool: return value == false
		),
		"GameFlow mirrors the retained two-world catalog without giving the console gameplay authority",
	)
	var retained_report := report.duplicate(true)
	_check(
		not bool(console.call(
			&"present_catalog_status", 2, 3, &"ready"
		))
		and console.call(&"get_presentation_snapshot") == retained_report,
		"invalid route counts fail closed without repainting the retained display",
	)

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
