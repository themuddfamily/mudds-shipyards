extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const BUTTON_X := 2
const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const WALK_FRAME_BUDGET := 240


class IsolatedFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool: return files.has(path)
	func directory_exists(_path: String) -> bool: return false
	func ensure_parent_directory(_path: String) -> Error: return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path): return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path): return ERR_FILE_NOT_FOUND
		if files.has(to_path): return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var filesystem := IsolatedFilesystem.new()
	var store := Store.new("memory://physical-fleet-switching.json", filesystem)
	var settings := Settings.new("memory://physical-fleet-switching.cfg")
	store.load()
	store.commit({Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "fixture")
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(store, "memory://physical-fleet-switching.cfg")
	root.add_child(game)
	for _settle in 8:
		await physics_frame
		await process_frame
	game.start_shift()
	game.boarding_motion_time = 0.08
	game.canopy_motion_time = 0.08
	game.disembarking_motion_time = 0.08
	await physics_frame
	await process_frame
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(player != null and game.get_flyable_ships().size() == 8, "GameFlow exposes baseline and all three nested craft")
	if player == null:
		_finish(game)
		return
	var expansion_ids := [&"cinder-cargo-hauler", &"cinder-long-range-bomber", &"cinder-light-interceptor"]
	for craft_id: StringName in expansion_ids:
		var craft := _find_craft(game.get_flyable_ships(), craft_id)
		_check(craft != null, "%s is registered for physical switching" % craft_id)
		if craft == null:
			continue
		var boarded := await _approach_and_board(game, player, craft)
		_check(boarded, "%s boards through the real walked-up GameFlow path" % craft_id)
		_check(game.get_active_ship() == craft and craft.is_piloted(), "%s becomes the active piloted craft" % craft_id)
		var disembarked := await _disembark(game, player)
		_check(disembarked, "%s disembarks through the real GameFlow path" % craft_id)
	_finish(game)


func _find_craft(fleet: Array[HeroShip], craft_id: StringName) -> HeroShip:
	for craft in fleet:
		if craft.get_ship_id() == craft_id:
			return craft
	return null


func _approach_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var start := craft.get_boarding_position() + craft.global_basis * Vector3(0.0, 0.0, 5.0)
	var direction := (craft.get_boarding_position() - start).slide(Vector3.UP).normalized()
	player.teleport_to(Transform3D(Basis.looking_at(direction, Vector3.UP).orthonormalized(), start))
	for _settle in 8:
		await physics_frame
		await process_frame
	if game.boarding_candidate == craft:
		return await _tap_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 4)
	_set_button(7, true)
	var walked := 0
	while walked < WALK_FRAME_BUDGET and game.boarding_candidate != craft:
		var offset := craft.get_boarding_position() - player.get_interaction_origin()
		var desired := offset.slide(Vector3.UP).normalized()
		var yaw := player.get_node_or_null(^"CameraYaw") as Node3D
		var reference := yaw.global_basis if yaw != null else player.global_basis
		var forward := (-reference.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		_set_axis(AXIS_LEFT_X, clampf(desired.dot(right), -1.0, 1.0))
		_set_axis(AXIS_LEFT_Y, clampf(-desired.dot(forward), -1.0, 1.0))
		await physics_frame
		await process_frame
		walked += 1
	_release_input()
	if game.boarding_candidate != craft:
		return false
	return await _tap_until(func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 4)


func _disembark(game: GameFlow, player: PlayerController) -> bool:
	var accepted := await _tap_until(
		func() -> bool: return game.phase == GameFlow.Phase.DISEMBARKING or not player.is_seated(),
		8
	)
	if not accepted:
		return false
	for _frame in 240:
		if not player.is_seated() and player.is_control_enabled():
			return true
		await physics_frame
		await process_frame
	return not player.is_seated()


func _tap_until(predicate: Callable, attempts: int) -> bool:
	for _attempt in attempts:
		if predicate.call(): return true
		_set_button(BUTTON_X, true)
		await physics_frame
		_set_button(BUTTON_X, false)
		for _frame in 30:
			if predicate.call(): return true
			await physics_frame
			await process_frame
	return predicate.call()


func _set_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _set_button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_input() -> void:
	_set_axis(AXIS_LEFT_X, 0.0)
	_set_axis(AXIS_LEFT_Y, 0.0)
	_set_button(7, false)


func _finish(game: GameFlow) -> void:
	_release_input()
	if is_instance_valid(game):
		var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
		var production := world.get_fleet_expansion_production_binding() if world != null else null
		if production != null:
			for craft_id: StringName in [
				&"cinder_cargo_hauler",
				&"cinder_long_range_bomber",
				&"cinder_light_interceptor",
			]:
				production.detach_craft(craft_id)
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("PASS game_flow_fleet_expansion_physical_switching_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures: push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
