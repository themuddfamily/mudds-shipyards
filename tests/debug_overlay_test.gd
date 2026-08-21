extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_f3_and_presentation_contract()
	await _test_production_snapshot()
	_finish()


func _test_f3_and_presentation_contract() -> void:
	var hud := GameHUD.new()
	hud.name = "DebugOverlayHud"
	root.add_child(hud)
	await process_frame
	hud.set("_started", true)

	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	_check(
		bool(hud.call("_is_debug_overlay_toggle_event", event)),
		"a fresh physical F3 press is the reserved debug-overlay toggle"
	)
	hud._unhandled_input(event)
	_check(hud.is_debug_overlay_visible(), "F3 shows the diagnostic overlay")

	var sample := {
		"mode": "PILOTING",
		"phase": "FREE_FLIGHT",
		"actor_name": "TORRENT",
		"actor_path": "TorrentInterceptor",
		"actor_position": Vector3(12.3456, -7.8901, 234.5678),
		"actor_velocity": Vector3(1.2, 0.0, -3.4),
		"camera_path": "TorrentInterceptor/CameraRig/Camera3D",
		"camera_position": Vector3(11.0, -6.0, 240.0),
		"camera_forward": Vector3(0.0, 0.0, -1.0),
		"camera_fov": 72.0,
		"facing": "NORTH (-Z)",
		"yaw_degrees": 0.0,
		"pitch_degrees": 0.0,
		"aim_hit": true,
		"aim_collider": "/root/Main/ShipyardWorld/Deck",
		"aim_position": Vector3(12.5, -5.25, 180.125),
		"aim_distance": 60.25,
		"absolute_coordinate": {
			"cell_x": 42,
			"cell_y": -3,
			"cell_z": 99,
			"offset_meters": Vector3(0.125, -0.25, 0.5),
		},
		"aim_absolute_coordinate": {
			"cell_x": 42,
			"cell_y": -3,
			"cell_z": 98,
			"offset_meters": Vector3(12.5, -5.25, 180.125),
		},
		"coordinate_frame_generation": 7,
		"fps": 60,
		"frame": 1234,
		"viewport_size": Vector2i(1600, 900),
	}
	hud.update_debug_overlay(sample)
	await process_frame
	var report := hud.get_debug_overlay_report()
	var text := str(report.get("text", ""))
	var overlay := hud.get("_debug_overlay") as Control
	_check(
		bool(report.get("mouse_passthrough", false))
		and "12.346 / -7.890 / 234.568" in text
		and "12.500 / -5.250 / 180.125" in text,
		"the overlay is pointer-transparent and prints actor and aim-hit XYZ to millimetres"
	)
	_check(
		"Actor absolute cell   42 / -3 / 99  |  frame 7" in text
		and "Hit absolute cell     42 / -3 / 98" in text
		and "NORTH (-Z)" in text
		and "viewport 1600x900" in text,
		"stable absolute coordinates, facing, and capture dimensions remain visible"
	)
	_check(
		overlay != null
		and overlay.position.x >= 0.0
		and overlay.position.y >= 0.0
		and overlay.position.x + overlay.size.x <= GameHUD.MIN_LOGICAL_WIDTH
		and overlay.position.y + overlay.size.y <= GameHUD.MIN_LOGICAL_HEIGHT,
		"the complete readout fits inside the HUD's minimum supported logical viewport"
	)

	event.echo = true
	hud._unhandled_input(event)
	_check(hud.is_debug_overlay_visible(), "F3 key repeat does not flicker the overlay")

	event.echo = false
	var profile := hud.get("_input_binding_profile") as InputBindingProfile
	var bindings_before: Array[Dictionary] = profile.get_bindings(&"move_forward")
	hud.set("_binding_capture_action", &"move_forward")
	hud._unhandled_input(event)
	var binding_report := hud.get_input_binding_report()
	_check(
		hud.is_debug_overlay_visible()
		and binding_report.get("capturing_action", &"") == &"move_forward"
		and profile.get_bindings(&"move_forward") == bindings_before,
		"an active key rebind rejects reserved F3 without changing the gameplay profile"
	)

	hud.call("_cancel_input_binding_capture")
	hud._unhandled_input(event)
	_check(not hud.is_debug_overlay_visible(), "the next ordinary F3 press hides the overlay")
	hud.queue_free()
	await process_frame


func _test_production_snapshot() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "the production scene loads with debug diagnostics")
	if packed == null:
		return
	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	var snapshot := game.get_debug_overlay_snapshot()
	var actor_position := snapshot.get("actor_position", Vector3.INF) as Vector3
	var camera_position := snapshot.get("camera_position", Vector3.INF) as Vector3
	_check(
		snapshot.get("mode", "") == "ON FOOT"
		and snapshot.get("actor_name", "") == "PLAYER"
		and actor_position.is_finite()
		and camera_position.is_finite(),
		"production diagnostics select the walking player and active camera with finite coordinates"
	)
	_check(
		(snapshot.get("camera_forward", Vector3.ZERO) as Vector3).is_normalized()
		and not str(snapshot.get("actor_path", "")).is_empty()
		and not str(snapshot.get("camera_path", "")).is_empty(),
		"production diagnostics publish normalized facing and identifiable scene paths"
	)
	var absolute := snapshot.get("absolute_coordinate", {}) as Dictionary
	_check(
		int(snapshot.get("coordinate_frame_generation", 0)) >= 1
		and not absolute.is_empty()
		and absolute.get("offset_meters", Vector3.INF) is Vector3,
		"the current scene position also decodes into a generation-stamped absolute cell and offset"
	)

	var hud := game.get_node("HUD") as GameHUD
	hud.set("_started", true)
	paused = true
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	hud._unhandled_input(event)
	var report := hud.get_debug_overlay_report()
	_check(
		bool(report.get("visible", false))
		and (report.get("snapshot", {}) as Dictionary).get("actor_name", "") == "PLAYER",
		"F3 requests an immediate production snapshot, including while gameplay processing is paused"
	)
	paused = false

	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	_failures.append(description)
	push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("DEBUG_OVERLAY_TEST_OK")
		quit(0)
		return
	print("DEBUG_OVERLAY_TEST_FAILED: ", ", ".join(_failures))
	quit(1)
