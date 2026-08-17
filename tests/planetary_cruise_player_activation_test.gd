extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "memory://planetary-cruise-player-activation-settings.json"
const EXPECTED_ASSERTIONS := 26

var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}
	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK
	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}
	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate(); return OK
	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path); return OK
	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path); return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for player cruise activation")
	if game == null:
		_finish(); return
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://planetary-cruise-player-activation-legacy.cfg"
		),
		"player activation journey isolates settings persistence",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var binding := game.get_node_or_null(
		^"PlanetaryCruiseProductionBinding"
	) as PlanetaryCruiseProductionBinding
	var ember := game.get_node_or_null(
		^"EmberMoonStreamingBootstrap"
	) as EmberMoonStreamingBootstrap
	var ship := game.get_active_ship()
	_check(
		hud != null and binding != null and ember != null and ship != null,
		"one HUD, binding, Ember frame, and active HeroShip resolve",
	)
	if hud == null or binding == null or ember == null or ship == null:
		await _cleanup(game); _finish(); return
	var controller := binding.get_controller()
	var pause_overlay := hud.get("_pause") as Control
	var cruise_button := pause_overlay.find_child(
		"PlanetaryCruiseToggleButton", true, false
	) as Button
	var cruise_status := pause_overlay.find_child(
		"PlanetaryCruiseStatus", true, false
	) as Label
	_check(
		cruise_button != null
		and cruise_status != null
		and hud.has_signal(&"planetary_cruise_toggle_requested")
		and cruise_button.focus_mode == Control.FOCUS_ALL,
		"pause Main owns one typed controller-focusable Ember cruise row",
	)

	var initial := hud.get_planetary_cruise_presentation_report()
	_check(
		initial.get("status_id") == &"unavailable"
		and initial.get("status_text") == "UNAVAILABLE — PILOT REQUIRED"
		and bool(initial.get("button_disabled", false))
		and not bool(initial.get("engagement_requested", true))
		and not bool(binding.get_snapshot().get("engagement_requested", true))
		and not bool(initial.get("actor_sampling_authority", true))
		and not bool(initial.get("policy_authority", true))
		and not bool(initial.get("movement_authority", true))
		and not bool(initial.get("origin_authority", true))
		and not bool(initial.get("destination_selection_authority", true)),
		"startup is unavailable on foot and never auto-engages",
	)

	_test_exact_presentation_vocabulary(hud)
	_test_public_gate_vocabulary(game)
	game.call("_sync_planetary_cruise_hud")

	game.set_physics_process(false)
	for fleet_ship in game.get_flyable_ships():
		fleet_ship.set_physics_process(false)
	var canonical := (
		binding.get_snapshot().get("canonical_destination_orbital", {}) as Dictionary
	)
	var frame := ember.get_coordinate_frame_for_session()
	var destination_result := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	)
	var destination := destination_result.get("position", Vector3.INF) as Vector3
	ship.global_position = Vector3(0.0, 5_000.0, 0.0)
	ship.global_basis = Basis.looking_at(
		(destination - ship.global_position).normalized(), Vector3.UP
	)
	ship.velocity = Vector3.ZERO
	ship.set_piloted(true)
	game.set("_piloting", true)
	game.set("_sortie_departed_berth", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.call("_sync_planetary_cruise_hud")
	var ready := hud.get_planetary_cruise_presentation_report()
	_check(
		ready.get("status_id") == &"ready"
		and ready.get("status_text") == "READY — EMBER MOON"
		and bool(ready.get("toggle_enabled", false))
		and not bool(ready.get("button_disabled", true)),
		"departed clear flight synchronizes the exact ready presentation",
	)
	var ready_generation := binding.get_generation()
	game._physics_process(1.0 / 60.0)
	game._physics_process(1.0 / 60.0)
	_check(
		binding.get_generation() == ready_generation
		and not bool(binding.get_snapshot().get("engagement_requested", true))
		and not bool(controller.get_snapshot().get("attached", true))
		and hud.get_planetary_cruise_presentation_report().get("status_id")
			== &"ready",
		"multiple production-ready ticks never auto-engage or attach a controller",
	)

	# Bypass only the title splash. Pause, controller focus navigation, and accept
	# below all use the real shipping HUD routes and typed request signal.
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud.call("_unhandled_input", pause_event)
	var resume := pause_overlay.find_child("ResumeButton", true, false) as Button
	_check(
		paused and pause_overlay.visible and root.gui_get_focus_owner() == resume,
		"the existing pause action opens Main and focuses Resume",
	)
	await _push_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var settings := pause_overlay.find_child(
		"SettingsOpenButton", true, false
	) as Button
	_check(
		root.gui_get_focus_owner() == settings,
		"one controller down press follows the frozen pause navigation to Settings",
	)
	await _push_joypad_button(JOY_BUTTON_DPAD_DOWN)
	_check(
		root.gui_get_focus_owner() == cruise_button,
		"a second controller down press reaches Ember cruise without pointer input",
	)

	var reads_before_request := int(
		game.get_activity_integration_report().get("actor_position_sample_count", -1)
	)
	var generation_before_request := binding.get_generation()
	var toast_before_request := int(hud.get("_toast_serial"))
	var nested_request_attempted := [false]
	binding.engagement_changed.connect(func(_snapshot: Dictionary) -> void:
		nested_request_attempted[0] = true
		hud.planetary_cruise_toggle_requested.emit(2)
	, CONNECT_ONE_SHOT)
	await _activate_focused_control()
	var queued := hud.get_planetary_cruise_presentation_report()
	_check(
		queued.get("status_id") == &"queued"
		and queued.get("status_text") == "QUEUED"
		and bool(queued.get("engagement_requested", false))
		and int(queued.get("request_serial", 0)) == 1
		and bool(binding.get_snapshot().get("engagement_requested", false)),
		"controller accept emits one typed request and commits the queued state",
	)
	_check(
		bool(nested_request_attempted[0])
		and int(game.get_planetary_cruise_report().get(
			"last_hud_toggle_serial", 0
		)) == 1
		and binding.get_generation() == generation_before_request + 1
		and int(hud.get("_toast_serial")) == toast_before_request + 1,
		"hostile binding-signal reentry consumes no nested serial and commits one transition/toast",
	)
	_check(
		int(game.get_activity_integration_report().get(
			"actor_position_sample_count", -2
		)) == reads_before_request
		and (ship.get_planetary_cruise_attachment_report().get(
			"pending_envelope", {}
		) as Dictionary).is_empty(),
		"the UI request performs no second actor sample and queues no early envelope",
	)
	var toast_serial := int(hud.get("_toast_serial"))
	var generation_after_request := binding.get_generation()
	hud.planetary_cruise_toggle_requested.emit(1)
	hud.planetary_cruise_toggle_requested.emit(3)
	_check(
		binding.get_generation() == generation_after_request
		and int(game.get_planetary_cruise_report().get(
			"last_hud_toggle_serial", 0
		)) == 1
		and int(hud.get("_toast_serial")) == toast_serial
		and generation_after_request > generation_before_request,
		"replayed and skipped request serials cannot toggle or duplicate toast",
	)

	game._physics_process(1.0 / 60.0)
	var pending := ship.get_planetary_cruise_attachment_report()
	_check(
		int(game.get_activity_integration_report().get(
			"actor_position_sample_count", -1
		)) == reads_before_request + 1
		and not (pending.get("pending_envelope", {}) as Dictionary).is_empty()
		and hud.get_planetary_cruise_presentation_report().get("status_id")
			== &"queued",
		"one adjusted production sample queues one next-Hero-tick envelope",
	)
	var before_move := ship.global_position
	ship._physics_process(1.0 / 60.0)
	game.call("_sync_planetary_cruise_hud")
	var accelerating := hud.get_planetary_cruise_presentation_report()
	_check(
		ship.global_position.distance_to(before_move) > 0.0
		and accelerating.get("status_id") == &"accelerating"
		and accelerating.get("status_text") == "ACCELERATING"
		and bool(accelerating.get("engagement_requested", false)),
		"HeroShip alone consumes the envelope and publishes accelerating",
	)

	await _activate_focused_control()
	var braking := hud.get_planetary_cruise_presentation_report()
	_check(
		braking.get("status_id") == &"braking"
		and braking.get("status_text") == "BRAKING"
		and bool(braking.get("button_disabled", false))
		and not bool(braking.get("engagement_requested", true))
		and not bool(binding.get_snapshot().get("engagement_requested", true)),
		"the same toggle requests bounded braking disengage and disables repeats",
	)
	ship._physics_process(1.0 / 60.0)
	game.call("_sync_planetary_cruise_hud")
	_check(
		hud.get_planetary_cruise_presentation_report().get("status_id") == &"ready"
		and ship.velocity.is_zero_approx(),
		"Hero-owned braking returns the row to ready only after velocity reaches zero",
	)

	# A fresh player request is intentionally live when Main leaves the tree. The
	# binding must retire it; the retained pause focus may return, but engagement
	# may not.
	cruise_button.grab_focus()
	await _activate_focused_control()
	_check(
		bool(binding.get_snapshot().get("engagement_requested", false))
		and int(hud.get_planetary_cruise_presentation_report().get(
			"request_serial", 0
		)) == 3,
		"a third explicit press starts one fresh pre-reentry request",
	)
	var identities := [
		hud.get_instance_id(),
		cruise_button.get_instance_id(),
		binding.get_instance_id(),
		controller.get_instance_id(),
	]
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	paused = false
	parent.add_child(game)
	await process_frame
	await process_frame
	paused = true
	var reentered := hud.get_planetary_cruise_presentation_report()
	_check(
		identities == [
			hud.get_instance_id(),
			cruise_button.get_instance_id(),
			binding.get_instance_id(),
			controller.get_instance_id(),
		]
		and root.gui_get_focus_owner() == cruise_button,
		"whole-Main reentry retains exact HUD/binding identities and cruise focus",
	)
	_check(
		not bool(binding.get_snapshot().get("engagement_requested", true))
		and not bool(reentered.get("engagement_requested", true))
		and reentered.get("status_id") == &"ready"
		and int(reentered.get("request_serial", 0)) == 3
		and int(game.get_planetary_cruise_report().get(
			"last_hud_toggle_serial", 0
		)) == 3,
		"reentry preserves replay fences but never ghost-engages cruise",
	)
	var reentry_generation := binding.get_generation()
	var reentry_toast_serial := int(hud.get("_toast_serial"))
	await _activate_focused_control()
	_check(
		bool(binding.get_snapshot().get("engagement_requested", false))
		and binding.get_generation() == reentry_generation + 1
		and int(hud.get_planetary_cruise_presentation_report().get(
			"request_serial", 0
		)) == 4
		and int(game.get_planetary_cruise_report().get(
			"last_hud_toggle_serial", 0
		)) == 4
		and int(hud.get("_toast_serial")) == reentry_toast_serial + 1
		and hud.get_signal_connection_list(
			&"planetary_cruise_toggle_requested"
		).size() == 1,
		"the first post-reentry click reaches one retained connection and one transition",
	)
	game.disengage_planetary_cruise(false)

	paused = false
	await _cleanup(game)
	_finish()


func _test_exact_presentation_vocabulary(hud: GameHUD) -> void:
	var states := [
		[&"ready", "READY — EMBER MOON", true, false],
		[&"queued", "QUEUED", true, true],
		[&"accelerating", "ACCELERATING", true, true],
		[&"cruising", "CRUISING", true, true],
		[&"braking_to_speed", "BRAKING TO SPEED", true, true],
		[&"braking", "BRAKING", false, false],
		[&"unavailable", "UNAVAILABLE — COMBAT ACTIVE", false, false],
	]
	var exact := true
	for state: Array in states:
		exact = exact and hud.set_planetary_cruise_state(
			state[0], state[1], state[2], state[3]
		)
		var report := hud.get_planetary_cruise_presentation_report()
		exact = exact and report.get("status_id") == state[0]
		exact = exact and report.get("status_text") == state[1]
		exact = exact and bool(report.get("toggle_enabled")) == state[2]
		exact = exact and bool(report.get("engagement_requested")) == state[3]
	_check(exact, "HUD freezes all seven exact detached cruise presentation states")
	var before := hud.get_planetary_cruise_presentation_report()
	var mismatched := hud.set_planetary_cruise_state(
		&"queued", "CRUISING", true, true
	)
	var leaked_internal := hud.set_planetary_cruise_state(
		&"unavailable",
		"UNAVAILABLE — controller_identity_drift",
		false,
		false,
	)
	var mutated := before.duplicate(true)
	mutated["status_text"] = "FORGED"
	_check(
		not mismatched
		and not leaked_internal
		and mutated.get("status_text") == "FORGED"
		and hud.get_planetary_cruise_presentation_report().get("status_text")
			== before.get("status_text"),
		"forged state/copy combinations reject and reports remain detached",
	)
	var emissions := [0]
	var observe_request := func(_request_serial: int) -> void:
		emissions[0] = int(emissions[0]) + 1
	hud.planetary_cruise_toggle_requested.connect(observe_request)
	hud.set_planetary_cruise_state(&"ready", "READY — EMBER MOON", true, false)
	hud.set(
		"_planetary_cruise_toggle_serial",
		GameHUD.MAX_PLANETARY_CRUISE_TOGGLE_SERIAL,
	)
	hud.call("_refresh_planetary_cruise_row")
	hud.call("_request_planetary_cruise_toggle")
	var exhausted := hud.get_planetary_cruise_presentation_report()
	hud.planetary_cruise_toggle_requested.disconnect(observe_request)
	_check(
		int(emissions[0]) == 0
		and not bool(exhausted.get("toggle_enabled", true))
		and bool(exhausted.get("button_disabled", false)),
		"HUD serial MAX visibly disables the toggle and emits nothing",
	)
	hud.set("_planetary_cruise_toggle_serial", 0)
	hud.call("_refresh_planetary_cruise_row")


func _test_public_gate_vocabulary(game: GameFlow) -> void:
	var gates := {
		&"main_unavailable": "SYSTEM OFFLINE",
		&"binding_unavailable": "SYSTEM OFFLINE",
		&"active_ship_unavailable": "NO ACTIVE SHIP",
		&"ship_destroyed": "SHIP DESTROYED",
		&"pilot_unseated": "PILOT REQUIRED",
		&"landing_active": "LANDING ACTIVE",
		&"combat_active": "COMBAT ACTIVE",
		&"ship_recovery": "SHIP RECOVERY",
		&"free_flight_unavailable": "DEPART SHIPYARD",
		&"activity_running": "ACTIVITY RUNNING",
		&"coordinate_frame_unavailable": "NAVIGATION OFFLINE",
		&"origin_rebase_pending": "ORIGIN SHIFT PENDING",
		&"unexpected_internal": "NOT AVAILABLE",
	}
	var exact := true
	for raw_reason: Variant in gates:
		var copy := str(game.call(
			"_planetary_cruise_public_gate_copy", StringName(raw_reason)
		))
		exact = exact and copy == gates[raw_reason]
		exact = exact and copy.length() <= 32 and not copy.contains("_")
	_check(exact, "GameFlow exposes only the bounded public cruise gate vocabulary")


func _push_joypad_button(button_index: int) -> void:
	var pressed_event := InputEventJoypadButton.new()
	pressed_event.button_index = button_index
	pressed_event.pressed = true
	root.push_input(pressed_event)
	await process_frame
	var released_event := InputEventJoypadButton.new()
	released_event.button_index = button_index
	released_event.pressed = false
	root.push_input(released_event)
	await process_frame


func _activate_focused_control() -> void:
	# The project intentionally has no cruise-specific InputMap action. Drive the
	# built-in focused UI acceptance path after real D-pad traversal instead.
	var pressed_event := InputEventAction.new()
	pressed_event.action = &"ui_accept"
	pressed_event.pressed = true
	root.push_input(pressed_event)
	await process_frame
	var released_event := InputEventAction.new()
	released_event.action = &"ui_accept"
	released_event.pressed = false
	root.push_input(released_event)
	await process_frame


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print(
			"PLANETARY_CRUISE_PLAYER_ACTIVATION_TEST_OK: %d assertions"
			% _assertions
		)
		quit(0)
		return
	for failure in _failures:
		push_error("PLANETARY_CRUISE_PLAYER_ACTIVATION_TEST: %s" % failure)
	quit(1)
