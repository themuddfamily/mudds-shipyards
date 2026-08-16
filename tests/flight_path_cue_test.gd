extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_hud_contract()
	await _test_game_flow_projection()
	_finish()


func _test_hud_contract() -> void:
	var hud := GameHUD.new()
	hud.name = "FlightPathCueHUDTest"
	root.add_child(hud)
	await process_frame
	var gameplay_hud := hud.get("_hud") as Control
	var cue := hud.get("_flight_cue_layer") as Control
	var reticle := hud.get("_reticle") as Control
	gameplay_hud.visible = true
	hud.set_mode("piloting")
	await process_frame

	_check(hud.has_method("get_flight_cue_report"), "HUD exposes the stable flight-cue audit contract")
	_check(cue != null and cue.name == "FlightPathCue", "HUD builds one dedicated flight-path cue layer")
	_check(cue != null and cue.mouse_filter == Control.MOUSE_FILTER_IGNORE, "flight-path cue cannot consume pointer input")
	_check(reticle != null and reticle.visible, "piloting retains the fixed nose and weapon reticle")
	_check(cue != null and reticle != null and cue.get_index() < reticle.get_index(), "fixed weapon reticle renders above the velocity cue")
	var reticle_position := reticle.position
	var hidden_report: Dictionary = hud.get_flight_cue_report()
	_check(not bool(hidden_report.get("marker_visible", true)), "cue starts hidden until projected telemetry is available")
	var center := hidden_report.get("safe_center", Vector2.ZERO) as Vector2
	var radii := hidden_report.get("safe_radii", Vector2.ZERO) as Vector2
	_check(center.x > 0.0 and center.y > 0.0 and radii.x > 0.0 and radii.y > 0.0, "cue reports a finite viewport-relative safe ellipse")

	var telemetry := _hud_telemetry(center)
	hud.update_ship_telemetry(telemetry)
	await process_frame
	var centered_report: Dictionary = hud.get_flight_cue_report()
	_check(bool(centered_report.get("marker_visible", false)), "valid piloting telemetry shows the flight-path marker")
	_check((centered_report.get("marker_position") as Vector2).is_equal_approx(center), "nose-aligned travel shares the screen centre without moving the reticle")
	_check(not bool(centered_report.get("connector_visible", true)), "aligned travel does not add connector clutter")
	_check(reticle.position == reticle_position and reticle.visible, "flight telemetry never repositions or hides the weapon reticle")

	telemetry["flight_path_screen_position"] = center + Vector2(96.0, -18.0)
	telemetry["flight_path_alignment"] = 0.72
	hud.update_ship_telemetry(telemetry)
	await process_frame
	var displaced_report: Dictionary = hud.get_flight_cue_report()
	_check(bool(displaced_report.get("connector_visible", false)), "meaningful nose-to-path separation gains a thin connector")
	_check(is_equal_approx(float(displaced_report.get("alignment", 0.0)), 0.72), "HUD preserves the physical path-alignment telemetry")

	telemetry["flight_path_clamped"] = true
	hud.update_ship_telemetry(telemetry)
	var clamped_report: Dictionary = hud.get_flight_cue_report()
	_check(bool(clamped_report.get("clamped", false)), "HUD exposes the off-screen forward marker state")

	telemetry["flight_path_screen_position"] = center + Vector2(30.0, radii.y)
	telemetry["flight_path_rearward"] = true
	telemetry["flight_path_alignment"] = -0.95
	telemetry["camera_view"] = &"cockpit"
	hud.update_ship_telemetry(telemetry)
	await process_frame
	var reverse_report: Dictionary = hud.get_flight_cue_report()
	_check(bool(reverse_report.get("rearward", false)), "HUD exposes the shape-distinct rearward cue state")
	_check(not bool(reverse_report.get("connector_visible", true)), "rearward cue never draws a misleading centre connector")
	_check(reverse_report.get("camera_view") == &"cockpit", "HUD audit identifies the camera used for the latest projection")

	telemetry["flight_path_screen_position"] = Vector2(NAN, 0.0)
	hud.update_ship_telemetry(telemetry)
	_check(not bool(hud.get_flight_cue_report().get("marker_visible", true)), "non-finite screen data safely hides the cue")

	hud.set_mode("on-foot")
	_check(not bool(hud.get_flight_cue_report().get("marker_visible", true)), "leaving the pilot seat immediately clears the flight cue")
	_check(not reticle.visible, "on-foot mode hides the weapon reticle as before")
	_check(_has_label_text(hud, "INTERACT / BOARD"), "E remains the on-foot interaction and boarding control")
	hud.set_mode("piloting")
	await process_frame
	var keyboard_rows := hud._help_rows_for_mode(GameHUD.MODE_PILOTING) as Array
	_check(
		_prompt_for_detail(keyboard_rows, "PITCH") == "Up / Down",
		"ship help names the current Up and Down keyboard pitch bindings"
	)
	_check(
		_prompt_for_detail(keyboard_rows, "ROLL") == "Q / R",
		"ship help names Q and R roll without taking E from interaction"
	)
	_check(
		_prompt_for_detail(keyboard_rows, "FORWARD / REVERSE  //  AUTO POWER") == "W / S"
		and _prompt_for_detail(keyboard_rows, "LEAVE SEAT: AUTO-OFFLINE") == "E"
		and not InputMap.has_action(&"engine_start")
		and not InputMap.has_action(&"engine_stop"),
		"ship help describes automatic engine power without reviving retired manual actions"
	)

	var gamepad_pitch := InputEventJoypadMotion.new()
	gamepad_pitch.axis = JOY_AXIS_RIGHT_Y
	gamepad_pitch.axis_value = -1.0
	root.push_input(gamepad_pitch)
	await process_frame
	var gamepad_rows := hud._help_rows_for_mode(GameHUD.MODE_PILOTING) as Array
	_check(
		_prompt_for_detail(gamepad_rows, "FORWARD / REVERSE  //  AUTO POWER") == "Left Stick"
		and _prompt_for_detail(gamepad_rows, "PITCH") == "Right Stick"
		and _prompt_for_detail(gamepad_rows, "ROLL") == "Right Stick"
		and _prompt_for_detail(gamepad_rows, "LEAVE SEAT: AUTO-OFFLINE") == "Left Face Button",
		"ship help resolves the current gamepad bindings instead of a stale static summary"
	)
	_check(_all_controls_passthrough(gameplay_hud), "the complete gameplay HUD remains transparent to look and fire input")

	hud.queue_free()
	await process_frame
	await process_frame


func _test_game_flow_projection() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "production scene loads for active-camera projection coverage")
	if packed == null:
		return
	var game := packed.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_physics_process(false)
	var ship := game.get_node("TorrentInterceptor") as HeroShip
	var hud := game.get_node("HUD") as GameHUD
	var camera := ship.get_camera()
	var viewport_rect := camera.get_viewport().get_visible_rect()
	var center := viewport_rect.position + viewport_rect.size * 0.5
	var camera_basis := camera.global_basis.orthonormalized()
	var camera_forward := -camera_basis.z.normalized()
	var camera_right := camera_basis.x.normalized()
	var camera_up := camera_basis.y.normalized()
	var physical_forward := -ship.global_basis.z.normalized()

	var forward := _projection_telemetry(camera_forward * 30.0, physical_forward)
	game.call("_decorate_flight_path_telemetry", forward)
	_check(bool(forward.get("flight_path_visible", false)), "forward velocity produces a visible projected cue")
	_check((forward.get("flight_path_screen_position") as Vector2).distance_to(center) < 0.5, "camera-forward velocity projects to the fixed reticle centre")
	_check(not bool(forward.get("flight_path_clamped", true)) and not bool(forward.get("flight_path_rearward", true)), "centred forward travel is neither clamped nor rearward")
	_check(float(forward.get("flight_path_alignment", 0.0)) > 0.999, "projection retains travel-to-physical-nose alignment")

	var right := _projection_telemetry((camera_forward * 0.8 + camera_right * 0.6).normalized() * 30.0, physical_forward)
	game.call("_decorate_flight_path_telemetry", right)
	_check((right.get("flight_path_screen_position") as Vector2).x > center.x, "camera-right slip moves the path marker right")
	var upward := _projection_telemetry((camera_forward * 0.8 + camera_up * 0.6).normalized() * 30.0, physical_forward)
	game.call("_decorate_flight_path_telemetry", upward)
	_check((upward.get("flight_path_screen_position") as Vector2).y < center.y, "camera-up slip moves the path marker upward")

	var side := _projection_telemetry(camera_right * 30.0, physical_forward)
	game.call("_decorate_flight_path_telemetry", side)
	_check(bool(side.get("flight_path_visible", false)) and bool(side.get("flight_path_clamped", false)), "sideways travel uses a stable safe-edge projection")
	_check(not bool(side.get("flight_path_rearward", true)), "exactly sideways travel is not mislabeled as reverse")

	var extreme := _projection_telemetry((camera_forward * 0.005 + camera_right).normalized() * 30.0, physical_forward)
	game.call("_decorate_flight_path_telemetry", extreme)
	var extreme_position := extreme.get("flight_path_screen_position") as Vector2
	var safe_radii := Vector2(
		minf(viewport_rect.size.x * 0.27, viewport_rect.size.y * 0.52),
		viewport_rect.size.y * 0.18
	)
	_check(bool(extreme.get("flight_path_clamped", false)), "off-screen forward travel is explicitly marked as clamped")
	_check(_ellipse_metric(extreme_position - center, safe_radii) <= 1.0001, "off-screen marker centre remains inside the documented safe ellipse")

	var reverse := _projection_telemetry((-camera_forward + camera_right * 0.3).normalized() * 30.0, physical_forward)
	game.call("_decorate_flight_path_telemetry", reverse)
	var reverse_position := reverse.get("flight_path_screen_position") as Vector2
	_check(bool(reverse.get("flight_path_rearward", false)) and bool(reverse.get("flight_path_clamped", false)), "rear-hemisphere velocity selects the dedicated reverse state")
	_check(is_equal_approx(reverse_position.y, center.y + safe_radii.y) and reverse_position.x > center.x, "reverse state uses the lower safe edge with camera-local horizontal bias")
	_check(float(reverse.get("flight_path_alignment", 0.0)) < -0.9, "reverse projection reports strong physical nose disagreement")

	for hidden_case: Dictionary in [
		_projection_telemetry(camera_forward, physical_forward),
		_projection_telemetry(camera_forward * 30.0, physical_forward, true, false),
		_projection_telemetry(camera_forward * 30.0, physical_forward, false, true),
		_projection_telemetry(Vector3(NAN, 0.0, 0.0), physical_forward),
		{"landed": false, "destroyed": false},
	]:
		game.call("_decorate_flight_path_telemetry", hidden_case)
		_check(not bool(hidden_case.get("flight_path_visible", true)), "low-speed, unavailable, or invalid flight state safely hides the marker")

	ship.set_cockpit_view(true)
	await process_frame
	var cockpit_camera := ship.get_camera()
	var cockpit_forward := -cockpit_camera.global_basis.z.normalized()
	var cockpit := _projection_telemetry(cockpit_forward * 30.0, physical_forward)
	cockpit["camera_view"] = &"cockpit"
	game.call("_decorate_flight_path_telemetry", cockpit)
	var cockpit_center := cockpit_camera.get_viewport().get_visible_rect().get_center()
	_check(cockpit_camera != camera and (cockpit.get("flight_path_screen_position") as Vector2).distance_to(cockpit_center) < 0.5, "camera-view changes recompute through the active cockpit camera")
	hud.get("_hud").visible = true
	hud.set_mode("piloting")
	hud.update_ship_telemetry(cockpit)
	var integrated_report: Dictionary = hud.get_flight_cue_report()
	_check(bool(integrated_report.get("marker_visible", false)) and integrated_report.get("camera_view") == &"cockpit", "decorated GameFlow telemetry reaches the public HUD cue report")

	game.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _projection_telemetry(
	velocity_world: Vector3,
	flight_forward_world: Vector3,
	landed: bool = false,
	destroyed: bool = false
) -> Dictionary:
	return {
		"velocity_world": velocity_world,
		"flight_forward_world": flight_forward_world,
		"camera_view": &"chase",
		"landed": landed,
		"destroyed": destroyed,
	}


func _hud_telemetry(position: Vector2) -> Dictionary:
	return {
		"speed": 30.0,
		"altitude": 12.0,
		"throttle": 0.6,
		"maximum_hull": 100.0,
		"hull": 100.0,
		"damage_status": &"healthy",
		"engine_power": 1.0,
		"engine_state": &"ONLINE",
		"flight_path_screen_position": position,
		"flight_path_visible": true,
		"flight_path_clamped": false,
		"flight_path_rearward": false,
		"flight_path_alignment": 1.0,
		"camera_view": &"chase",
	}


func _ellipse_metric(offset: Vector2, radii: Vector2) -> float:
	return sqrt(pow(offset.x / radii.x, 2.0) + pow(offset.y / radii.y, 2.0))


func _has_label_text(search_root: Node, text: String) -> bool:
	for candidate in search_root.find_children("*", "Label", true, false):
		if (candidate as Label).text == text:
			return true
	return false


func _prompt_for_detail(rows: Array, detail: String) -> String:
	for row: Array in rows:
		if str(row[1]) == detail:
			return str(row[0])
	return ""


func _all_controls_passthrough(control: Control) -> bool:
	if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in control.get_children():
		if child is Control and not _all_controls_passthrough(child as Control):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLIGHT_PATH_CUE_TEST_OK")
		quit(0)
	else:
		print("FLIGHT_PATH_CUE_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
