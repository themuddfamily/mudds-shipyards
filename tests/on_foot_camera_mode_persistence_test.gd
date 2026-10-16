extends SceneTree

## Proves the player-owned first/third-person preference survives a completely
## fresh Main without sharing authority with the ship cockpit/chase camera.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")

const STORE_PATH := "memory://on-foot-camera-mode-persistence.json"
const LEGACY_PATH := "memory://on-foot-camera-mode-persistence-legacy.cfg"

var _assertions := 0
var _failures: PackedStringArray = []
var _player_signal_count := 0
var _begin_interact_count := 0


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		return (
			{"error": OK, "bytes": (files[path] as PackedByteArray).duplicate()}
			if files.has(path)
			else {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		)

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path):
			return ERR_FILE_NOT_FOUND if not files.has(from_path) else ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--begin-recovery-input-only" in OS.get_cmdline_user_args():
		for reduced_motion: bool in [true, false]:
			for gamepad: bool in [false, true]:
				await _test_recovered_begin_boundary(reduced_motion, gamepad)
		_finish()
		return
	var store := Store.new(STORE_PATH, FakeFilesystem.new())
	var legacy_settings := Settings.new(LEGACY_PATH)
	var schema_eight_payload := legacy_settings.to_user_data_payload()
	schema_eight_payload.schema_version = 8
	# A historical payload contains only fields introduced by that schema.
	for later_field in ["high_contrast_hud", "reticle_style", "on_foot_first_person", "limit_ultrawide_fov"]:
		(schema_eight_payload.values as Dictionary).erase(later_field)
	_check(bool(store.load().accepted), "fixture opens an empty atomic store")
	_check(
		bool(store.commit({Adapter.SETTINGS_PAYLOAD_KEY: schema_eight_payload}, 0, "schema-eight").accepted),
		"fixture writes a schema-eight settings payload without on-foot camera preference"
	)

	var first := await _instantiate_with_store(store)
	var first_player := first.get_node(^"Player") as PlayerController
	var first_ship := first.active_ship as HeroShip
	_check(
		first_player.get_camera_view_mode() == PlayerController.CameraViewMode.THIRD_PERSON
		and not first.get_runtime_settings().on_foot_first_person
		and first_ship.get_camera_view() == HeroShip.CAMERA_VIEW_CHASE,
		"schema-eight payload migrates to third-person default without changing ship camera authority"
	)

	first_player.camera_view_mode_changed.connect(_on_player_camera_view_mode_changed)
	first_player.set_camera_view_mode(PlayerController.CameraViewMode.THIRD_PERSON)
	first_player.set_camera_view_mode(PlayerController.CameraViewMode.FIRST_PERSON)
	_check(
		_player_signal_count == 1
		and first.get_runtime_settings().on_foot_first_person
		and first_ship.get_camera_view() == HeroShip.CAMERA_VIEW_CHASE,
		"one changed-only Player preference persists without synthesizing a ship camera change"
	)
	var persisted := store.get_snapshot().get(Adapter.SETTINGS_PAYLOAD_KEY, {}) as Dictionary
	_check(
		int(persisted.get("schema_version", -1)) == Settings.USER_DATA_PAYLOAD_SCHEMA_VERSION
		and bool((persisted.get("values", {}) as Dictionary).get("on_foot_first_person", false)),
		"changed on-foot preference upgrades and commits the typed atomic payload"
	)

	first.queue_free()
	await process_frame
	var restarted := await _instantiate_with_store(store)
	var restarted_player := restarted.get_node(^"Player") as PlayerController
	var restarted_ship := restarted.active_ship as HeroShip
	_check(
		restarted_player.get_camera_view_mode() == PlayerController.CameraViewMode.FIRST_PERSON
		and restarted_player.is_first_person_active()
		and restarted.get_runtime_settings().on_foot_first_person
		and restarted_ship.get_camera_view() == HeroShip.CAMERA_VIEW_CHASE,
		"fresh Main restores the selected on-foot first-person camera while ship chase remains independent"
	)

	restarted.queue_free()
	await process_frame
	await _test_recovered_begin_boundary(true, false)
	_finish()


## Save the context through a real first shift, then cold-load it. No authored
## Player/ship positions or gameplay/recovery state are injected by this test.
func _test_recovered_begin_boundary(reduced_motion: bool, gamepad: bool) -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem)
	_check(bool(store.load().accepted), "Begin recovery opens an empty store")
	var settings := Settings.new(LEGACY_PATH)
	settings.reduced_motion = reduced_motion
	_check(bool(store.commit(
		{Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "begin-recovery"
	).accepted), "Begin recovery saves the motion preference")
	var first := await _instantiate_with_store(store)
	# Jump is an ordinary title-confirm control and does not request boarding.
	var jump := InputEventKey.new()
	jump.physical_keycode = KEY_SPACE
	jump.keycode = KEY_SPACE
	jump.pressed = true
	Input.parse_input_event(jump)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame
	jump = jump.duplicate() as InputEventKey
	jump.pressed = false
	Input.parse_input_event(jump)
	Input.flush_buffered_events()
	for _tick in range(180):
		await physics_frame
		await process_frame
		var saved := store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {}) as Dictionary
		if saved.get("mode", "") == "on_foot":
			break
	var context := store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {}) as Dictionary
	_check(context.get("mode", "") == "on_foot" and not first.player.is_seated(),
		"first ordinary shift produces a real settled on-foot recovery context")
	first.queue_free()
	await process_frame
	await physics_frame
	# A separate store reloads bytes written by the previous Main.
	var cold_store := Store.new(STORE_PATH, filesystem)
	var game := await _instantiate_with_store(cold_store)
	var label := "reduced_motion=%s gamepad=%s" % [str(reduced_motion), str(gamepad)]
	_check(
		game.phase == GameFlow.Phase.INTRO and not game.player.is_control_enabled()
		and not game.player.is_seated() and not bool(game.get("_piloting"))
		and (game.get("_solo_safe_recovery_context") as Dictionary).get("mode", "") == "on_foot",
		"%s cold baseline is restored on-foot context, never a saved pilot" % label
	)
	_begin_interact_count = 0
	game.player.interact_requested.connect(_on_begin_probe_interact)
	var press := _begin_binding_event(gamepad, true)
	_check(press != null, "%s has a physical Interact binding" % label)
	if press == null:
		game.queue_free()
		await process_frame
		return
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	# Match SettingsNativeInputEvents/_settings_tap's first press/flush frame.
	await physics_frame
	await process_frame
	Input.parse_input_event(_begin_binding_event(gamepad, false))
	Input.flush_buffered_events()
	await physics_frame
	await process_frame
	for _tick in range(120):
		if game.phase != GameFlow.Phase.INTRO:
			break
		await physics_frame
		await process_frame
	await physics_frame
	await process_frame
	print("BEGIN_RECOVERY_INPUT // %s // phase=%s // controls=%s // piloting=%s // seated=%s // interactions=%d // candidate=%s" % [
		label, str(game.phase), str(game.player.is_control_enabled()),
		str(game.get("_piloting")), str(game.player.is_seated()),
		_begin_interact_count, str(game.get("boarding_candidate")),
	])
	_check(_begin_interact_count == 0,
		"%s title-confirm press emits no gameplay Interact after on-foot restore" % label)
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP and game.player.is_control_enabled()
		and not game.player.is_seated() and not bool(game.get("_piloting"))
		and not bool(game.get("_transition_busy")),
		"%s real recovery stays on foot after Begin" % label)
	if game.phase == GameFlow.Phase.APPROACH_SHIP and game.player.is_control_enabled():
		var before := _begin_interact_count
		# Exercise the production control-handoff API with E/pad Interact held.
		# No Player physics runs between enabling control, release, and repress:
		# the fence cannot expire naturally before this fresh deliberate edge.
		game.player.set_control_enabled(false)
		Input.parse_input_event(_begin_binding_event(gamepad, true))
		Input.flush_buffered_events()
		game.player.set_control_enabled(true)
		Input.parse_input_event(_begin_binding_event(gamepad, false))
		Input.flush_buffered_events()
		Input.parse_input_event(_begin_binding_event(gamepad, true))
		Input.flush_buffered_events()
		await physics_frame
		await process_frame
		_check(_begin_interact_count == before + 1,
			"%s held-Interact control handoff admits release/repress before its first physics tick" % label)
	Input.parse_input_event(_begin_binding_event(gamepad, false))
	Input.flush_buffered_events()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_free()
	await process_frame
	await physics_frame


func _begin_binding_event(gamepad: bool, pressed: bool) -> InputEvent:
	for binding: InputEvent in InputMap.action_get_events(&"interact"):
		if (gamepad and binding is InputEventJoypadButton) \
				or (not gamepad and binding is InputEventKey):
			var event := binding.duplicate() as InputEvent
			if event is InputEventKey:
				var key := event as InputEventKey
				key.pressed = pressed
				if key.keycode == 0:
					key.keycode = key.physical_keycode
			else:
				(event as InputEventJoypadButton).device = 0
				(event as InputEventJoypadButton).pressed = pressed
			return event
	return null


func _on_begin_probe_interact() -> void:
	_begin_interact_count += 1


func _instantiate_with_store(store: UserDataStore) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(store, LEGACY_PATH), "Main accepts injected store before startup")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	return game


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _on_player_camera_view_mode_changed(_mode: PlayerController.CameraViewMode) -> void:
	_player_signal_count += 1


func _finish() -> void:
	if _failures.is_empty():
		print("ON_FOOT_CAMERA_MODE_PERSISTENCE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("ON_FOOT_CAMERA_MODE_PERSISTENCE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
