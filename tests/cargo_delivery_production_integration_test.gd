extends SceneTree

## Production proof for the modern Jovian fabrication-kit delivery. Activity
## selection is driven through the same pause-menu buttons a player uses; cargo
## time, landing, inventory, and lifecycle all stay in their existing owners.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const STORE_PATH := "user://cargo-delivery-production-settings.json"

var _assertions := 0
var _failures: Array[String] = []
var _filesystem: MemoryFilesystem


class MemoryFilesystem extends UserDataFilesystem:
	var reject_writes := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		return ERR_CANT_CREATE if reject_writes else super.write_bytes_and_flush(path, bytes)


class InterruptedRewardFilesystem extends UserDataFilesystem:
	var stopped := false
	var interrupt_rewards := true
	var reward_rejected := false
	var reject_writes := false

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		if stopped or reject_writes:
			return ERR_UNAVAILABLE
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if interrupt_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			reward_rejected = true
			stopped = true
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)

	func remove_path(path: String) -> Error:
		return ERR_UNAVAILABLE if stopped or reject_writes else super.remove_path(path)

	func rename_path(from_path: String, to_path: String) -> Error:
		return ERR_UNAVAILABLE if stopped or reject_writes else super.rename_path(from_path, to_path)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--ordinary-jovian-kit-reload" in OS.get_cmdline_user_args():
		await _run_ordinary_jovian_kit_reload()
		return
	if "--ordinary-jovian-kit-deliver" in OS.get_cmdline_user_args():
		await _run_ordinary_jovian_kit_board(true, true)
		return
	if "--ordinary-jovian-kit-depart" in OS.get_cmdline_user_args():
		await _run_ordinary_jovian_kit_board(true)
		return
	if "--ordinary-jovian-kit-board" in OS.get_cmdline_user_args():
		await _run_ordinary_jovian_kit_board()
		return
	var game := MAIN_SCENE.instantiate() as GameFlow
	_filesystem = MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, _filesystem) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(
			store, "memory://cargo-delivery-production-legacy.cfg"
		),
		"the production fixture injects isolated settings before Main startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var hud := game.get_node_or_null(^"HUD") as GameHUD
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var jovian := _find_ship(game, &"jovian_provisional")
	var torrent := _find_ship(game, &"torrent_provisional")
	var freight_berth := (
		world.get_jovian_freight_berth()
		if world != null
		else null
	)
	_check(
		hud != null and world != null and jovian != null and torrent != null
		and freight_berth != null,
		"production Main exposes the HUD, both real craft, and the real Jovian freight berth"
	)
	if (
		hud == null or world == null or jovian == null or torrent == null
		or freight_berth == null
	):
		await _clean_up(game)
		_finish()
		return

	await _test_player_selection_and_atomic_failure(
		game, hud, jovian, freight_berth
	)
	_test_contract_and_start_gates(game, hud, jovian, torrent, freight_berth)
	await _test_physics_reentry_and_physical_delivery(
		game, hud, world, jovian, freight_berth
	)
	_test_failure_expiry_reset_and_authority(game, hud)

	var saved_generation := game.cargo_delivery_activity.get_generation()
	await _clean_up(game)
	await _test_saved_cargo_reentry(saved_generation)
	await _test_interrupted_cargo_recovery()
	await _test_unsaved_cargo_reset_recovery()
	_finish()


# Restore only: the coordinator starts this selector in a distinct OS process,
# with the accepted delivery's original XDG_DATA_HOME and absolute store path.
const RELOAD_STORE_ARGUMENT := "--ordinary-jovian-kit-reload-store="
const RELOAD_SHA256_ARGUMENT := "--ordinary-jovian-kit-reload-sha256="
const RELOAD_TRACE_ARGUMENT := "--ordinary-jovian-kit-reload-trace"
var _reload_baseline: Dictionary = {}
var _reload_store: UserDataStore
var _reload_completed := false
var _reload_trace_selected := false
var _reload_trace_started_msec := 0


func _run_ordinary_jovian_kit_reload() -> void:
	_ordinary_deadline = Time.get_ticks_msec() + 30000
	_reload_trace_started_msec = _ordinary_deadline - 30000
	_reload_trace_selected = RELOAD_TRACE_ARGUMENT in OS.get_cmdline_user_args()
	await _ordinary_reload_scenario()
	_reload_require(_reload_completed, "restore scenario reached terminal acceptance")
	_ordinary_reload_trace("cleanup_begin", {"completed": _reload_completed})
	# Do not remove or rewrite the accepted store during harness cleanup.
	for action in InputMap.get_actions():
		Input.action_release(action)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	paused = false
	if is_instance_valid(_ordinary_game):
		_ordinary_game.release_mouse_capture()
		if _ordinary_game.is_inside_tree():
			_ordinary_game.queue_free()
		else:
			_ordinary_game.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	await process_frame
	_reload_require(not is_instance_valid(_ordinary_game), "restored Main freed before success")
	if _reload_store != null and not _reload_baseline.is_empty():
		_reload_require(_ordinary_reload_store_unchanged(), "cleanup preserves substantive saved cargo and paid reward")
	_ordinary_reload_trace("cleanup_end", {"main_valid": is_instance_valid(_ordinary_game)})
	print("JOVIAN_KIT_ORDINARY_RELOAD_ASSERTIONS: ", _assertions)
	if _reload_completed and _failures.is_empty():
		print("JOVIAN_KIT_ORDINARY_RELOAD_OK")
	_ordinary_reload_trace("terminal_exit", {"completed": _reload_completed, "failures": _failures.size()})
	quit(0 if _reload_completed and _failures.is_empty() else 1)


func _ordinary_reload_scenario() -> void:
	_ordinary_reload_trace("scenario_entry")
	var path := ""
	var path_arguments := 0
	var expected_sha256 := ""
	var sha256_arguments := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(RELOAD_STORE_ARGUMENT):
			path = argument.trim_prefix(RELOAD_STORE_ARGUMENT)
			path_arguments += 1
		elif argument.begins_with(RELOAD_SHA256_ARGUMENT):
			expected_sha256 = argument.trim_prefix(RELOAD_SHA256_ARGUMENT)
			sha256_arguments += 1
	if not _reload_require(path_arguments == 1 and path.is_absolute_path()
		and FileAccess.file_exists(path), "one explicit absolute accepted store path exists"):
		return
	if not _reload_require(sha256_arguments == 1 and expected_sha256.length() == 64
		and FileAccess.get_sha256(path) == expected_sha256,
		"actual primary matches the accepted KIT-DELIVER artifact before Main"):
		return
	_reload_store = Store.new(path, UserDataFilesystem.new()) as UserDataStore
	var loaded := _reload_store.load_read_only()
	if not _reload_require(bool(loaded.get("accepted", false)) and _reload_store.get_loaded_source() == &"primary",
		"production store accepts actual primary without backup recovery"):
		return
	_reload_baseline = _reload_store.get_snapshot()
	var session := _reload_baseline.get("jovian_cargo_session", {}) as Dictionary
	var rows := session.get("activities", []) as Array
	if not _reload_require(rows.size() == 1, "accepted baseline has one saved Jovian activity"):
		return
	var row := rows[0] as Dictionary
	var saved := (row.get("progress", {}) as Dictionary).get("cargo_session_state", {}) as Dictionary
	var activity := saved.get("activity_state", {}) as Dictionary
	var receipt := activity.get("accepted_receipt", {}) as Dictionary
	var reward := _reload_baseline.get("game_flow_reward_store", {}) as Dictionary
	var paid := reward.get("last_receipt", {}) as Dictionary
	if not _reload_require(int(activity.get("generation", 0)) == 1
		and int(activity.get("state", -1)) == CargoDeliveryActivity.State.COMPLETED
		and bool(row.get("reward_requested", false)) and bool(row.get("reward_granted", false))
		and str(receipt.get("transfer_id", "")) == "jovian_fabrication_kit_delivery_g1"
		and bool(receipt.get("accepted", false)) and int(receipt.get("quantity", 0)) == 2
		and int(receipt.get("source_quantity_after", -1)) == 4
		and int(receipt.get("destination_quantity_after", -1)) == 2
		and int(reward.get("total_receipts", 0)) == 1
		and str(paid.get("activity_id", "")) == "jovian_fabrication_kit_delivery"
		and int(paid.get("activity_generation", 0)) == 1
		and str(paid.get("reward_id", "")) == "return_fabrication_kits_to_shipyard"
		and bool(paid.get("granted", false)) and not bool(paid.get("replay_allowed", true)),
		"saved baseline is completed generation one with its exact paid delivery"):
		return
	# Both the actual store and its substantive baseline exist before Main.
	_ordinary_reload_trace("before_instantiate")
	_ordinary_game = MAIN_SCENE.instantiate() as GameFlow
	_ordinary_reload_trace("after_instantiate")
	if not _reload_require(_ordinary_game.configure_runtime_settings_persistence(
		_reload_store, path.get_base_dir().path_join("legacy.cfg")),
		"real production filesystem configured before Main enters tree"):
		return
	if _reload_trace_selected:
		for child in _ordinary_game.get_children():
			child.ready.connect(_ordinary_reload_child_ready.bind(str(child.name)), CONNECT_ONE_SHOT)
		_ordinary_game.ready.connect(_ordinary_reload_main_ready, CONNECT_ONE_SHOT)
	_ordinary_reload_trace("before_tree_entry")
	root.add_child(_ordinary_game)
	_ordinary_reload_trace("after_add_child")
	if _reload_trace_selected:
		for index in 4:
			_ordinary_reload_trace("before_tickwait", {"tick": index + 1})
			await _ordinary_ticks(1)
			_ordinary_reload_trace("after_tickwait", {"tick": index + 1})
	else:
		await _ordinary_ticks(4)
	if not _reload_require(_ordinary_game.hud is GameHUD and _ordinary_game.world is ShipyardWorld
		and _ordinary_game.world.get_jovian_freight_berth() != null
		and _find_ship(_ordinary_game, &"jovian_provisional") != null
		and bool((_ordinary_game.get("_jovian_cargo_session_restore_status") as Dictionary).get("accepted", false)),
		"normal production startup accepts Jovian restore with real craft and freight service"):
		return
	if not _reload_require(_ordinary_reload_matches_baseline(),
		"startup restores same lifecycle clock, generations, kits, transfer receipt and single paid reward"):
		return
	var physics_start := Engine.get_physics_frames()
	var process_start := Engine.get_process_frames()
	for _index in 60:
		await _ordinary_ticks(1)
		if not _reload_require(Time.get_ticks_msec() < _ordinary_deadline and not paused
			and _ordinary_game.is_physics_processing() and _ordinary_game.is_processing()
			and _ordinary_reload_matches_baseline(),
			"ordinary startup/retry ticks preserve completed cargo and reward without replay"):
			return
	_reload_completed = _reload_require(Engine.get_physics_frames() - physics_start >= 60
		and Engine.get_process_frames() - process_start >= 60 and _ordinary_reload_store_unchanged(),
		"at least sixty normal physics/process ticks retain saved completion and no duplicate reward")


func _ordinary_reload_trace(boundary: String, details: Dictionary = {}) -> void:
	if not _reload_trace_selected:
		return
	var receipt := {"boundary": boundary, "elapsed_msec": Time.get_ticks_msec() - _reload_trace_started_msec,
		"engine_ticks_msec": Time.get_ticks_msec(), "pid": OS.get_process_id(), "process_frames": Engine.get_process_frames(),
		"physics_frames": Engine.get_physics_frames(), "details": details}
	# application/run/flush_stdout_on_print is already enabled in project.godot.
	print("JOVIAN_KIT_ORDINARY_RELOAD_TRACE: ", JSON.stringify(receipt))


func _ordinary_reload_child_ready(child_name: String) -> void:
	_ordinary_reload_trace("child_ready", {"child": child_name})


func _ordinary_reload_main_ready() -> void:
	var diagnostic := {"initialized": _ordinary_game.get("_initialized"),
		"phase": _ordinary_game.phase, "paused": paused,
		"restore": _ordinary_game.get("_jovian_cargo_session_restore_status")}
	var cargo := _ordinary_game.cargo_delivery_activity
	if is_instance_valid(cargo):
		diagnostic["cargo_generation"] = cargo.get_generation()
		diagnostic["cargo_state"] = cargo.get_state()
	_ordinary_reload_trace("main_ready", diagnostic)


func _ordinary_reload_matches_baseline() -> bool:
	var owner := _ordinary_game.cargo_delivery_activity
	var authority := _ordinary_game.cargo_transfer_authority
	if owner == null or authority == null:
		return false
	var row := (_reload_baseline.jovian_cargo_session.activities as Array)[0] as Dictionary
	var saved := row.progress.cargo_session_state as Dictionary
	var report := _ordinary_game.get_activity_integration_report()
	var reward := (_ordinary_game.get_activity_reward_report().get("authority", {}) as Dictionary).get("record", {}) as Dictionary
	return owner.get_state() == CargoDeliveryActivity.State.COMPLETED and owner.get_generation() == 1 \
		and _manifest_quantity(report.get("cargo_source_manifest", {}) as Dictionary) == 4 \
		and _manifest_quantity(report.get("cargo_destination_manifest", {}) as Dictionary) == 2 \
		and JSON.parse_string(JSON.stringify(owner.capture_persistence_state())) == saved.activity_state \
		and JSON.parse_string(JSON.stringify(authority.to_dictionary())) == saved.authority_state \
		and JSON.parse_string(JSON.stringify(reward)) == _reload_baseline.game_flow_reward_store \
		and int(authority.audit().get("committed_transfer_count", -1)) == 1 \
		and _cargo_receipts(_ordinary_game) == 1 \
		and (_ordinary_game.get("_owed_game_flow_activity_rewards") as Array).is_empty() \
		and not bool(_ordinary_game.call(&"_has_pending_jovian_cargo_reward"))


func _ordinary_reload_store_unchanged() -> bool:
	var loaded := _reload_store.load_read_only()
	var current := _reload_store.get_snapshot()
	return bool(loaded.get("accepted", false)) and _reload_store.get_loaded_source() == &"primary" \
		and current.get("jovian_cargo_session") == _reload_baseline.get("jovian_cargo_session") \
		and current.get("game_flow_reward_store") == _reload_baseline.get("game_flow_reward_store")


func _reload_require(condition: bool, description: String) -> bool:
	if not condition and _failures.is_empty():
		var diagnostic := {"description": description, "pid": OS.get_process_id(),
			"remaining_msec": _ordinary_deadline - Time.get_ticks_msec()}
		if is_instance_valid(_ordinary_game) and _ordinary_game.is_inside_tree():
			diagnostic["restore"] = _ordinary_game.get("_jovian_cargo_session_restore_status")
			diagnostic["cargo"] = _ordinary_game.cargo_delivery_activity.get_snapshot() if _ordinary_game.cargo_delivery_activity != null else {}
			diagnostic["rewards"] = (_ordinary_game.get_activity_reward_report().get("authority", {}) as Dictionary).get("record", {})
		print("JOVIAN_KIT_ORDINARY_RELOAD_FIRST_FAILURE: ", JSON.stringify(diagnostic))
	return _check(condition, description)


# Selected ordinary routes share the accepted KIT-BOARD approach. The default
# staged integration/recovery fixture below retains its original contract.
# KIT-DEPART continues from the accepted seat using only ordinary flight input.
const ORDINARY_WALK_ACTIONS := [&"move_forward", &"move_back", &"move_left", &"move_right"]
const ORDINARY_STATION_APPROACH := [
	Vector3(0.0, 0.0, 13.5), Vector3(-35.0, 0.0, 13.5),
	Vector3(-35.0, 0.0, 22.0), Vector3(-48.0, 0.0, 22.0),
	Vector3(-48.0, 0.38, 24.0), Vector3(-49.0, 0.38, 26.0),
	Vector3(-51.5, 0.38, 26.0), Vector3(-53.0, 0.38, 27.5),
	Vector3(-53.0, 0.38, 33.5), Vector3(-53.0, 0.38, 40.0),
	Vector3(-42.0, 0.38, 40.0),
]
var _ordinary_game: GameFlow
var _ordinary_player: PlayerController
var _ordinary_ship: HeroShip
var _ordinary_player_id := 0
var _ordinary_deadline := 0
var _ordinary_directory := ""
var _ordinary_board_completed := false
var _ordinary_depart_selected := false
var _ordinary_depart_completed := false
var _ordinary_deliver_selected := false
var _ordinary_deliver_completed := false
var _ordinary_transfer_receipts: Array[Dictionary] = []
var _ordinary_source: LocalShipInputSource
var _ordinary_home_berth: ShipBerth
var _ordinary_home_lease: StringName
var _ordinary_home_id: StringName
var _ordinary_hull := 0.0
var _ordinary_initial_position := Vector3.ZERO
var _ordinary_initial_nose := Vector3.ZERO
var _ordinary_start_snapshots: Array[Dictionary] = []
var _ordinary_start_step := -1
var _ordinary_previous_elapsed := 0.0


func _run_ordinary_jovian_kit_board(depart: bool = false, deliver: bool = false) -> void:
	_ordinary_depart_selected = depart
	_ordinary_deliver_selected = deliver
	_ordinary_deadline = Time.get_ticks_msec() + 300000
	_ordinary_directory = "user://jovian-kit-ordinary-%s-%d-%d" % ["deliver" if deliver else ("depart" if depart else "board"), OS.get_process_id(), Time.get_ticks_usec()]
	_ordinary_game = MAIN_SCENE.instantiate() as GameFlow
	await _ordinary_board_scenario()
	_ordinary_require(_ordinary_board_completed, "ordinary boarding scenario reached its terminal acceptance")
	if depart and _ordinary_board_completed and _failures.is_empty():
		await _ordinary_depart_scenario()
	if depart:
		_ordinary_require(_ordinary_depart_completed, "ordinary departure scenario reached its terminal acceptance")
	if deliver and _ordinary_depart_completed and _failures.is_empty():
		await _ordinary_deliver_scenario()
	if deliver:
		_ordinary_require(_ordinary_deliver_completed, "ordinary delivery scenario reached its terminal acceptance")
	# Always release input/capture and destroy Main, including the first failed
	# boundary. Do not use the staged fixture's piloting-state mutation cleanup.
	for action in ORDINARY_WALK_ACTIONS + [&"interact", &"sprint_boost", &"brake", &"ui_accept", &"fire", &"pause", &"landing_assist"]:
		_ordinary_action(action, false)
		Input.action_release(action)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	paused = false
	if is_instance_valid(_ordinary_game):
		_ordinary_game.release_mouse_capture()
		if _ordinary_game.is_inside_tree():
			_ordinary_game.queue_free()
		else:
			_ordinary_game.free()
	await process_frame
	await process_frame
	_ordinary_require(not is_instance_valid(_ordinary_game), "ordinary Main has actually been freed before success")
	if deliver:
		# KIT-RELOAD must consume this actual production save in a new process.
		print("JOVIAN_KIT_ORDINARY_DELIVER_STORE: ", ProjectSettings.globalize_path(_ordinary_directory.path_join("settings.json")))
	else:
		var directory := DirAccess.open(_ordinary_directory)
		if directory != null:
			for filename in directory.get_files():
				var removal := DirAccess.remove_absolute(_ordinary_directory.path_join(filename))
				if not _ordinary_require(removal == OK, "private ordinary store artifact removed: " + filename):
					break
			var directory_removal := DirAccess.remove_absolute(_ordinary_directory)
			_ordinary_require(directory_removal == OK, "private ordinary store directory removed")
	print(_ordinary_marker_prefix() + "_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		# The external isolated coordinator additionally requires actual exit 0.
		print(_ordinary_marker_prefix() + "_OK")
	quit(0 if _failures.is_empty() else 1)


func _ordinary_board_scenario() -> void:
	# MemoryFilesystem above is a failure-injection wrapper over real FileAccess.
	# This selected route instead uses the unmodified production filesystem.
	var store := Store.new(_ordinary_directory.path_join("settings.json"), UserDataFilesystem.new()) as UserDataStore
	if not _ordinary_require(bool(store.load().get("accepted", false)), "fresh private real-file store loads"):
		return
	if not _ordinary_require(_ordinary_game.configure_runtime_settings_persistence(
		store, _ordinary_directory.path_join("legacy.cfg")), "private settings configured before Main enters tree"):
		return
	root.add_child(_ordinary_game)
	await _ordinary_ticks(4)
	_ordinary_player = _ordinary_game.get_node_or_null(^"Player") as PlayerController
	_ordinary_ship = _find_ship(_ordinary_game, &"jovian_provisional")
	if not _ordinary_require(_ordinary_game.hud is GameHUD and _ordinary_game.world is ShipyardWorld
		and _ordinary_player != null and _ordinary_ship != null and _ordinary_game.phase == GameFlow.Phase.INTRO,
		"fresh production Main exposes original Player, Jovian and ordinary intro"):
		return
	_ordinary_player_id = _ordinary_player.get_instance_id()
	if not await _ordinary_button("IntroBeginShiftButton"):
		return
	if not await _ordinary_boundary(func(): return (_ordinary_game.phase == GameFlow.Phase.APPROACH_SHIP
		and _ordinary_player.is_control_enabled() and _ordinary_player.is_on_floor()), 5.0,
		"ordinary Begin Shift starts supported authored station spawn"):
		return
	var dismiss := _ordinary_game.hud.find_child("RuntimeStatusDismissButton", true, false) as Button
	if dismiss != null and dismiss.is_visible_in_tree() and not dismiss.disabled:
		if not await _ordinary_activate(dismiss):
			return
	var spawn: Transform3D = _ordinary_game.world.get_player_spawn()
	if not _ordinary_require(_ordinary_same_player() and _ordinary_player.global_position.distance_to(spawn.origin) < 0.8,
		"same original Player begins at normal authored spawn"):
		return
	await _ordinary_press(&"pause")
	if not _ordinary_require(paused, "ordinary pause input opens the menu"):
		return
	for node_name: String in ["ActivityBoardButton", "CargoDeliveryActivityButton", "ActivitySelectionBackButton", "ResumeButton"]:
		if not await _ordinary_button(node_name):
			return
	if not _ordinary_require(not paused and _ordinary_cargo_is_initial(), "focused Activity Board selects initial idle fabrication-kit delivery and resumes"):
		return
	for target: Vector3 in ORDINARY_STATION_APPROACH:
		if not await _ordinary_walk_to(target):
			return
	var boarding := _ordinary_ship.get_boarding_position()
	for target: Vector3 in [Vector3(-42.0, 0.38, boarding.z), boarding]:
		if not await _ordinary_walk_to(target):
			return
	await _ordinary_look(_ordinary_ship.get_boarding_position() + Vector3.UP * 1.2)
	await _ordinary_press(&"interact")
	if not await _ordinary_boundary(func(): return (_ordinary_game.phase == GameFlow.Phase.START_ENGINES
		and _ordinary_player.is_seated_at(_ordinary_ship.get_pilot_seat_anchor())), 12.0,
		"ordinary hatch Interact completes production animated boarding directly into pilot seat"):
		return
	var source := _ordinary_ship.get_command_source()
	var area := _ordinary_game.get("_boarding_area") as ShipBoardingArea
	if not _ordinary_require(_ordinary_same_player() and _ordinary_game.active_ship == _ordinary_ship
		and _ordinary_ship.is_piloted() and not _ordinary_ship.is_remote_piloted()
		and area != null and area.get_ship() == _ordinary_ship and area.is_reserved()
		and area.get_reservation_token() == _ordinary_player
		and source is LocalShipInputSource and source == _ordinary_ship.get_local_input_source()
		and source.enabled and source.is_enabled_owner() and _ordinary_ship.get_camera().current,
		"original Player owns actual Jovian pilot seat, hatch claim and enabled current default local InputMap source"):
		return
	if not _ordinary_require(_ordinary_home_berth_is_current(), "Jovian remains physically parked in its valid occupied home freight berth"):
		return
	_ordinary_board_completed = _ordinary_require(_ordinary_game.phase == GameFlow.Phase.START_ENGINES and _ordinary_cargo_is_initial()
		and not bool(_ordinary_game.get("_sortie_departed_berth"))
		and str(_ordinary_ship.get_telemetry().get("engine_state", "")).to_upper() == "OFFLINE",
		"stop before thrust/departure/start: cargo IDLE generation zero, initial manifest generations one, six source kits and zero destination kits")


func _ordinary_marker_prefix() -> String:
	if _ordinary_deliver_selected:
		return "JOVIAN_KIT_ORDINARY_DELIVER"
	return "JOVIAN_KIT_ORDINARY_DEPART" if _ordinary_depart_selected else "JOVIAN_KIT_ORDINARY_BOARD"


func _ordinary_depart_scenario() -> void:
	_ordinary_source = _ordinary_ship.get_command_source() as LocalShipInputSource
	_ordinary_home_id = _ordinary_ship.get_home_berth_id()
	_ordinary_home_berth = _ordinary_game.world.get_berth_node(_ordinary_home_id) as ShipBerth
	_ordinary_home_lease = _ordinary_home_berth.get_reservation_token(_ordinary_ship)
	_ordinary_hull = float(_ordinary_ship.get_telemetry().get("hull", 0.0))
	_ordinary_initial_position = _ordinary_ship.global_position
	_ordinary_initial_nose = -_ordinary_ship.global_basis.z.normalized()
	if _ordinary_deliver_selected:
		_ordinary_game.cargo_transfer_authority.transfer_committed.connect(func(receipt: Dictionary):
			_ordinary_transfer_receipts.append(receipt.duplicate(true)))
	# Observe the production owner; never invoke start or submit a phase here.
	_ordinary_game.cargo_delivery_activity.started.connect(func(snapshot: Dictionary):
		_ordinary_start_snapshots.append(snapshot.duplicate(true))
		_ordinary_start_step = int(_ordinary_game.get_activity_integration_report().get("cargo_physics_step_count", -1)))
	if not _ordinary_depart_integrity():
		return
	_ordinary_action(&"move_forward", true)
	var departure_deadline := mini(Time.get_ticks_msec() + 10000, _ordinary_deadline)
	var departed := false
	var forward_sampled := false
	while Time.get_ticks_msec() < departure_deadline:
		await _ordinary_ticks(1)
		if not _ordinary_depart_integrity():
			return
		var command := _ordinary_ship.get_last_ship_command()
		forward_sampled = forward_sampled or (command != null and command.throttle > 0.0 and not command.brake)
		if _ordinary_berth_released() and _ordinary_departure_distance() >= 5.0 and _ordinary_cargo_is_departed():
			departed = true
			break
	_ordinary_action(&"move_forward", false)
	if not _ordinary_require(departed and forward_sampled,
		"ordinary sampled forward demand releases original berth and starts ACTIVE generation one, then travels at least five metres along initial nose within ten seconds"):
		return
	_ordinary_action(&"brake", true)
	var brake_deadline := mini(Time.get_ticks_msec() + 10000, _ordinary_deadline)
	var settled_seconds := 0.0
	var settled_since := -1
	var braked := false
	while Time.get_ticks_msec() < brake_deadline:
		# Sample every physics boundary so a render-frame gap cannot count an
		# unobserved interval as continuously settled. Read the completed tick.
		await physics_frame
		if not _ordinary_depart_integrity():
			return
		if not _ordinary_depart_check(_ordinary_berth_released() and _ordinary_cargo_is_departed(),
			"braking retains actual released berth and original active return objective"):
			return
		var command := _ordinary_ship.get_last_ship_command()
		var frame_index := Engine.get_physics_frames()
		if command != null and command.brake and is_zero_approx(command.throttle) and _ordinary_ship.velocity.length() <= 0.5:
			if settled_since < 0:
				settled_since = frame_index
			settled_seconds = float(frame_index - settled_since) * _ordinary_game.get_physics_process_delta_time()
		else:
			settled_since = -1
			settled_seconds = 0.0
		if settled_seconds >= 1.0:
			braked = true
			break
	_ordinary_action(&"brake", false)
	_ordinary_depart_completed = _ordinary_require(braked and _ordinary_departure_distance() >= 5.0
		and _ordinary_previous_elapsed > 0.0 and _ordinary_berth_released() and _ordinary_cargo_is_departed(),
		"neutral thrust with ordinary sampled brake holds at most 0.5 m/s for one physics second within ten seconds, without resetting the original 180-second cargo deadline")


func _ordinary_deliver_scenario() -> void:
	# Departure queued its brake release; let normal input sampling consume it.
	await _ordinary_ticks(2)
	var capture: Dictionary = _ordinary_game.call(&"_get_landing_assist_report_for_ship", _ordinary_ship)
	if not _ordinary_require(_ordinary_deliver_integrity() and _cargo_receipts(_ordinary_game) == 0
		and int(_ordinary_game.cargo_transfer_authority.audit().get("committed_transfer_count", -1)) == 0
		and bool(capture.get("valid", false)) and capture.get("selected_berth_id") == _ordinary_home_id
		and bool(capture.get("assist_capture_accepted", false)) and bool(capture.get("docked_hull_fits", false))
		and bool(capture.get("berth_available", false)) and bool(capture.get("compatibility_accepted", false))
		and bool(capture.get("preview_non_mutating", false)) and _ordinary_berth_released(),
		"unchanged stopped departure has accepted home capture/fit, free berth, zero transfers and zero reward receipts"):
		return
	var acceptance_deadline := mini(Time.get_ticks_msec() + 8000, _ordinary_deadline)
	await _ordinary_press(&"landing_assist")
	if not await _ordinary_deliver_wait(func():
		var contract := _ordinary_ship.get_landing_contract_report()
		return (_ordinary_ship.is_landing_active() and bool(_ordinary_game.get("_landing_request_active"))
			and _ordinary_game.get("_active_landing_berth_id") == _ordinary_home_id
			and bool(contract.get("contract_accepted", false)) and contract.get("berth_id") == _ordinary_home_id
			and bool(contract.get("reservation_token_bound", false))),
		acceptance_deadline, "one ordinary landing_assist input accepts the physical home contract within eight seconds"):
		return
	if not await _ordinary_deliver_wait(_ordinary_deliver_docked,
		mini(Time.get_ticks_msec() + 120000, _ordinary_deadline),
		"physical return reaches strict same-hull occupied home dock and SHUT_DOWN within 120 seconds"):
		return
	if not _ordinary_require(_ordinary_delivery_is_complete(),
		"offline physical landing completes generation one: source six to four, destination zero to two, one exact transfer and one paid reward with none owed"):
		return
	# This is the production automatic idle timer, not an engine-stop request.
	if not await _ordinary_deliver_wait(func(): return (_ordinary_deliver_docked()
		and _ordinary_ship.get_telemetry().get("engine_state") == HeroShip.ENGINE_OFFLINE),
		mini(Time.get_ticks_msec() + int((HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS + 1.0) * 1000.0), _ordinary_deadline),
		"neutral sampled controls retain physical home docking until actual automatic ENGINE_OFFLINE"):
		return
	var exit_seconds := 2.0 * _ordinary_game.canopy_motion_time + _ordinary_game.disembarking_motion_time + 1.0
	var exit_deadline := mini(Time.get_ticks_msec() + int(exit_seconds * 1000.0), _ordinary_deadline)
	await _ordinary_press(&"interact")
	if not await _ordinary_deliver_wait(_ordinary_exterior_is_usable, exit_deadline,
		"ordinary Interact completes authored exterior disembark within two canopy motions plus disembark motion plus one second", false):
		return
	var walk_origin := _ordinary_player.global_position
	var walk_deadline := mini(Time.get_ticks_msec() + 15000, _ordinary_deadline)
	_ordinary_action(&"move_forward", true)
	var walked := false
	while Time.get_ticks_msec() < walk_deadline:
		await _ordinary_ticks(1)
		if not _ordinary_deliver_integrity(false, false) or not _ordinary_depart_check(
			_ordinary_exterior_is_usable() and _ordinary_delivery_is_complete(),
			"same unseated controllable Player remains supported outside while walking; completed transfer/reward cannot duplicate"):
			break
		if (_ordinary_player.global_position - walk_origin).slide(Vector3.UP).length() >= 0.5:
			walked = true
			break
	_ordinary_action(&"move_forward", false)
	if not _failures.is_empty() or not _ordinary_require(walked,
		"ordinary ground movement carries the supported original controllable unseated Player at least half a metre within fifteen seconds"):
		return
	# Normal production ticks exercise retry/persistence owners without calling
	# completion, transfer, reward, or retry APIs from this route.
	for _index in 60:
		await _ordinary_ticks(1)
		if not _ordinary_deliver_integrity(false) or not _ordinary_depart_check(
			_ordinary_exterior_is_usable() and _ordinary_delivery_is_complete(),
			"normal post-delivery ticks preserve exterior control and exactly one transfer/reward"):
			return
	_ordinary_deliver_completed = _ordinary_require(Time.get_ticks_msec() < _ordinary_deadline
		and _ordinary_delivery_is_complete(), "delivery retains original 300-second route cap and unreset 180-second activity clock with no duplicate cargo or reward")


func _ordinary_deliver_wait(predicate: Callable, deadline: int, description: String, seated: bool = true) -> bool:
	while Time.get_ticks_msec() < deadline:
		if not _ordinary_deliver_integrity(seated):
			return false
		if seated and not _ordinary_depart_check(not _ordinary_ship.has_manual_flight_intent(),
			"sampled flight command remains neutral through physical landing and automatic shutdown"):
			return false
		if bool(predicate.call()):
			return _ordinary_require(true, description)
		await _ordinary_ticks(1)
	return _ordinary_require(false, description)


func _ordinary_deliver_integrity(seated: bool = true, neutral: bool = true) -> bool:
	var snapshot := _ordinary_game.cargo_delivery_activity.get_snapshot()
	var report := _ordinary_game.get_activity_integration_report()
	var elapsed := float(snapshot.get("elapsed_seconds", -1.0))
	var expected := float(int(report.get("cargo_physics_step_count", -1)) - _ordinary_start_step) * _ordinary_game.get_physics_process_delta_time()
	var complete := _ordinary_game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.COMPLETED
	if not _ordinary_depart_check(_ordinary_same_player() and _ordinary_game.active_ship == _ordinary_ship
		and _ordinary_ship.get_home_berth_id() == _ordinary_home_id
		and is_equal_approx(float(_ordinary_ship.get_telemetry().get("hull", -1.0)), _ordinary_hull)
		and _ordinary_start_snapshots.size() == 1 and _ordinary_game.cargo_delivery_activity.get_generation() == 1
		and (complete or _ordinary_game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.ACTIVE)
		and float(snapshot.get("deadline_seconds", 0.0)) == 180.0 and elapsed >= _ordinary_previous_elapsed
		and elapsed < 180.0 and absf(elapsed - expected) < 0.00001
		and absf(float(snapshot.get("deadline_remaining_seconds", -1.0)) - (180.0 - expected)) < 0.00001
		and report.get("cargo_source_entity") == _ordinary_ship
		and report.get("cargo_destination_entity") == _ordinary_game.world.get_jovian_freight_berth()
		and _manifest_quantity(report.get("cargo_source_manifest", {}) as Dictionary) == (4 if complete else 6)
		and _manifest_quantity(report.get("cargo_destination_manifest", {}) as Dictionary) == (2 if complete else 0),
		"return retains same Player, hull, home, original single generation and exact unreset physics clock with conserved kits"):
		return false
	_ordinary_previous_elapsed = elapsed
	if seated:
		var area := _ordinary_game.get("_boarding_area") as ShipBoardingArea
		if not _ordinary_depart_check(_ordinary_player.is_seated_at(_ordinary_ship.get_pilot_seat_anchor())
			and _ordinary_ship.is_piloted() and not _ordinary_ship.is_remote_piloted()
			and _ordinary_ship.get_command_source() == _ordinary_source and _ordinary_source.enabled
			and _ordinary_source == _ordinary_ship.get_local_input_source() and _ordinary_source.is_enabled_owner()
			and _ordinary_source.get_input_provider() == null and _ordinary_ship.get_camera().current
			and _ordinary_source.get_authority_peer_id() == 1 and _ordinary_source.get_local_peer_id() == 1
			and area != null and area.get_ship() == _ordinary_ship and area.is_reserved() and area.get_reservation_token() == _ordinary_player,
			"return retains original seated pilot, default local Input source, camera and hatch claim"):
			return false
	if neutral:
		for action: StringName in ORDINARY_WALK_ACTIONS + [&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
			&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll", &"landing_assist", &"interact"]:
			if not _ordinary_depart_check(not Input.is_action_pressed(action), "return controls remain neutral: " + str(action)):
				return false
	return true


func _ordinary_deliver_docked(require_shutdown: bool = true) -> bool:
	var contract := _ordinary_ship.get_landing_contract_report()
	var dock := _ordinary_home_berth.get_dock_transform()
	var token := StringName((_ordinary_game.get("_berth_tokens") as Dictionary).get(_ordinary_ship.get_instance_id(), &""))
	return (not require_shutdown or _ordinary_game.phase == GameFlow.Phase.SHUT_DOWN) and _ordinary_home_berth_is_current() \
		and not _ordinary_ship.is_landing_active() and _ordinary_ship.velocity.length() <= 0.05 \
		and _ordinary_ship.global_position.distance_to(dock.origin) <= 0.05 \
		and rad_to_deg(_ordinary_ship.global_basis.orthonormalized().get_rotation_quaternion().angle_to(
			dock.basis.orthonormalized().get_rotation_quaternion())) <= 0.5 \
		and bool(contract.get("contract_accepted", false)) and bool(contract.get("strict_dock_acceptance", false)) \
		and contract.get("phase") == HeroShip.LANDING_PHASE_DOCKED and contract.get("berth_id") == _ordinary_home_id \
		and bool(contract.get("reservation_token_bound", false)) and not token.is_empty() \
		and _ordinary_home_berth.has_valid_lease(_ordinary_ship, token, _ordinary_ship.get_ship_id()) \
		and (_ordinary_game.get("_reserved_berth_ids") as Dictionary).get(_ordinary_ship.get_instance_id()) == _ordinary_home_id


func _ordinary_delivery_is_complete() -> bool:
	var snapshot := _ordinary_game.cargo_delivery_activity.get_snapshot()
	var report := _ordinary_game.get_activity_integration_report()
	var receipt := snapshot.get("accepted_receipt", {}) as Dictionary
	var reward_record := (_ordinary_game.get_activity_reward_report().get("authority", {}) as Dictionary).get("record", {}) as Dictionary
	var reward := reward_record.get("last_receipt", {}) as Dictionary
	return _ordinary_game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.COMPLETED \
		and int(snapshot.get("generation", 0)) == 1 and bool(snapshot.get("phases_complete", false)) \
		and _manifest_quantity(report.get("cargo_source_manifest", {}) as Dictionary) == 4 \
		and _manifest_quantity(report.get("cargo_destination_manifest", {}) as Dictionary) == 2 \
		and _ordinary_transfer_receipts.size() == 1 and _ordinary_transfer_receipts[0] == receipt \
		and bool(receipt.get("accepted", false)) and receipt.get("transfer_id") == &"jovian_fabrication_kit_delivery_g1" \
		and int(receipt.get("quantity", 0)) == 2 and receipt.get("item_id") == GameFlow.CARGO_DELIVERY_ITEM_ID \
		and int(_ordinary_game.cargo_transfer_authority.audit().get("committed_transfer_count", -1)) == 1 \
		and _cargo_receipts(_ordinary_game) == 1 and int(reward_record.get("total_receipts", 0)) == 1 \
		and reward.get("activity_id") == "jovian_fabrication_kit_delivery" and int(reward.get("activity_generation", 0)) == 1 \
		and reward.get("reward_id") == "return_fabrication_kits_to_shipyard" and bool(reward.get("granted", false)) \
		and not bool(reward.get("replay_allowed", true)) \
		and (_ordinary_game.get("_owed_game_flow_activity_rewards") as Array).is_empty() \
		and not bool(_ordinary_game.call(&"_has_pending_jovian_cargo_reward"))


func _ordinary_exterior_is_usable() -> bool:
	return _ordinary_same_player() and not _ordinary_player.is_seated() and _ordinary_player.is_control_enabled() \
		and _ordinary_player.is_on_floor() and _ordinary_player.get_camera().current \
		and not _ordinary_ship.is_piloted() and not bool(_ordinary_game.get("_transition_busy")) \
		and _ordinary_game.get("_boarding_area") == null and _ordinary_deliver_docked(false) \
		and _ordinary_game.phase == GameFlow.Phase.APPROACH_SHIP


func _ordinary_departure_distance() -> float:
	return (_ordinary_ship.global_position - _ordinary_initial_position).dot(_ordinary_initial_nose)


func _ordinary_berth_released() -> bool:
	var ship_id := _ordinary_ship.get_instance_id()
	return bool(_ordinary_game.get("_sortie_departed_berth")) \
		and not bool(_ordinary_ship.get_telemetry().get("landed", true)) \
		and bool(_ordinary_home_berth.audit().get("valid", false)) \
		and _ordinary_home_berth.get_occupant() == null and _ordinary_home_berth.get_reservation_owner() == null \
		and _ordinary_home_berth.get_reservation_token(_ordinary_ship).is_empty() \
		and not _ordinary_home_berth.has_valid_lease(_ordinary_ship, _ordinary_home_lease, _ordinary_ship.get_ship_id()) \
		and not (_ordinary_game.get("_berth_tokens") as Dictionary).has(ship_id) \
		and not (_ordinary_game.get("_reserved_berth_ids") as Dictionary).has(ship_id)


func _ordinary_cargo_is_departed(include_presentation: bool = true) -> bool:
	var report := _ordinary_game.get_activity_integration_report()
	var snapshot := _ordinary_game.get_active_activity_snapshot()
	var marker := _find_minimap_marker(_ordinary_game.get_minimap_snapshot().get("objective_markers", []) as Array, &"active_jovian_delivery_return")
	return _ordinary_game.phase == GameFlow.Phase.FREE_FLIGHT \
		and report.get("selected_activity_kind") == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY \
		and bool(report.get("selection_locked", false)) and report.get("active_activity_id") == GameFlow.CARGO_DELIVERY_ACTIVITY_ID \
		and int(report.get("active_generation", 0)) == 1 \
		and _ordinary_game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.ACTIVE \
		and _ordinary_game.cargo_delivery_activity.get_generation() == 1 \
		and snapshot.get("state_id", &"") == &"active" and snapshot.get("phase_id", &"") == &"return" \
		and int(snapshot.get("completed_checkpoint_count", 0)) == 1 \
		and (not include_presentation or (int(marker.get("generation", 0)) == 1 \
			and (marker.get("position", Vector3.INF) as Vector3).is_equal_approx(_ordinary_home_berth.get_dock_transform().origin) \
			and "DELIVERY  RETURN  1/2" in str(_ordinary_game.hud.get_activity_objective_report().get("text", ""))))


func _ordinary_depart_check(condition: bool, description: String) -> bool:
	# Ongoing invariants emit evidence at the first failure; terminal assertions
	# report acceptance once rather than printing identical per-tick passes.
	return true if condition else _ordinary_require(false, description)


func _ordinary_depart_integrity() -> bool:
	var source := _ordinary_ship.get_command_source() as LocalShipInputSource
	var area := _ordinary_game.get("_boarding_area") as ShipBoardingArea
	var report := _ordinary_game.get_activity_integration_report()
	if not _ordinary_depart_check(_ordinary_same_player() and _ordinary_game.active_ship == _ordinary_ship
		and _ordinary_player.is_seated_at(_ordinary_ship.get_pilot_seat_anchor())
		and _ordinary_ship.is_piloted() and not _ordinary_ship.is_remote_piloted()
		and area != null and area.get_ship() == _ordinary_ship and area.is_reserved() and area.get_reservation_token() == _ordinary_player
		and source != null and source == _ordinary_source and source == _ordinary_ship.get_local_input_source()
		and source.enabled and source.is_enabled_owner() and source.get_authority_peer_id() == 1 and source.get_local_peer_id() == 1
		and source.get_input_provider() == null and _ordinary_ship.get_camera().current
		and _ordinary_ship.get_home_berth_id() == _ordinary_home_id
		and is_equal_approx(float(_ordinary_ship.get_telemetry().get("hull", -1.0)), _ordinary_hull),
		"departure retains same original seated Player, current default Input-backed owner, hatch claim, home and hull"):
		return false
	if not _ordinary_depart_check(report.get("cargo_source_entity") == _ordinary_ship and report.get("cargo_destination_entity") == _ordinary_game.world.get_jovian_freight_berth()
		and _manifest_quantity(report.get("cargo_source_manifest", {}) as Dictionary) == 6
		and _manifest_quantity(report.get("cargo_destination_manifest", {}) as Dictionary) == 0
		and _ordinary_start_snapshots.size() <= 1, "departure conserves six source kits, zero destination kits and one automatic start"):
		return false
	if _ordinary_start_snapshots.is_empty():
		return _ordinary_depart_check(_ordinary_cargo_is_initial(), "cargo remains initial until production automatically starts it")
	var started := _ordinary_start_snapshots[0]
	var snapshot := _ordinary_game.cargo_delivery_activity.get_snapshot()
	var elapsed := float(snapshot.get("elapsed_seconds", -1.0))
	var expected_elapsed := float(int(report.get("cargo_physics_step_count", -1)) - _ordinary_start_step) * _ordinary_game.get_physics_process_delta_time()
	var valid_clock := int(started.get("generation", 0)) == 1 and int(started.get("state", -1)) == CargoDeliveryActivity.State.ACTIVE \
		and is_zero_approx(float(started.get("elapsed_seconds", -1.0))) and float(started.get("deadline_seconds", 0.0)) == 180.0 \
		and float(snapshot.get("deadline_seconds", 0.0)) == 180.0 and elapsed >= _ordinary_previous_elapsed \
		and absf(elapsed - expected_elapsed) < 0.00001 \
		and absf(float(snapshot.get("deadline_remaining_seconds", -1.0)) - (180.0 - expected_elapsed)) < 0.00001
	_ordinary_previous_elapsed = elapsed
	# HUD/minimap publication may converge after start; the existing bounded
	# departure predicate and final acceptance still require both presentations.
	return _ordinary_depart_check(valid_clock and _ordinary_cargo_is_departed(false) and _ordinary_berth_released(),
		"first automatic ACTIVE generation one retains return checkpoint, released leases and exact unreset 180-second physics clock")


func _ordinary_same_player() -> bool:
	return is_instance_valid(_ordinary_player) and _ordinary_player.is_inside_tree() \
		and _ordinary_player.get_instance_id() == _ordinary_player_id and _ordinary_game.player == _ordinary_player


func _ordinary_cargo_is_initial() -> bool:
	var report := _ordinary_game.get_activity_integration_report()
	var activity := _ordinary_game.cargo_delivery_activity
	var source := report.get("cargo_source_handle", {}) as Dictionary
	var destination := report.get("cargo_destination_handle", {}) as Dictionary
	return report.get("selected_activity_kind") == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY \
		and activity != null and activity.get_state() == CargoDeliveryActivity.State.IDLE and activity.get_generation() == 0 \
		and not bool(report.get("selection_locked", true)) \
		and report.get("active_activity_id") == GameFlow.CARGO_DELIVERY_ACTIVITY_ID and int(report.get("active_generation", -1)) == 0 \
		and int(source.get("entity_generation", 0)) == 1 and int(source.get("manifest_generation", 0)) == 1 \
		and int(destination.get("entity_generation", 0)) == 1 and int(destination.get("manifest_generation", 0)) == 1 \
		and report.get("cargo_source_entity") == _ordinary_ship \
		and report.get("cargo_destination_entity") == _ordinary_game.world.get_jovian_freight_berth() \
		and _manifest_quantity(report.get("cargo_source_manifest", {}) as Dictionary) == 6 \
		and _manifest_quantity(report.get("cargo_destination_manifest", {}) as Dictionary) == 0


func _ordinary_home_berth_is_current() -> bool:
	var berth := _ordinary_game.world.get_berth_node(_ordinary_ship.get_home_berth_id()) as ShipBerth
	var collision := _ordinary_ship.get_landing_collision_report()
	return berth != null and berth.get_berth_id() == &"jovian_freight_berth" \
		and bool(berth.audit().get("valid", false)) and berth.get_occupant() == _ordinary_ship \
		and berth.get_reservation_owner() == _ordinary_ship \
		and berth.has_valid_lease(_ordinary_ship, berth.get_reservation_token(_ordinary_ship), _ordinary_ship.get_ship_id()) \
		and bool(collision.get("valid", false)) \
		and berth.contains_oriented_bounds(_ordinary_ship.global_transform, collision.get("local_bounds", AABB()) as AABB) \
		and bool(_ordinary_ship.get_telemetry().get("landed", false))


func _ordinary_walk_to(target: Vector3) -> bool:
	await _ordinary_look(target + Vector3.UP * 1.4)
	var deadline := Time.get_ticks_msec() + 15000
	var settled := 0
	while Time.get_ticks_msec() < deadline and Time.get_ticks_msec() < _ordinary_deadline:
		var delta := (target - _ordinary_player.global_position).slide(Vector3.UP)
		if delta.length() <= 0.30:
			_ordinary_release_walk()
			await _ordinary_ticks(1)
			settled = settled + 1 if _ordinary_player.is_on_floor() and _ordinary_player.velocity.slide(Vector3.UP).length() < 0.1 else 0
			if settled >= 15:
				return _ordinary_require(absf(target.y - _ordinary_player.global_position.y) < 0.8 and _ordinary_same_player(),
					"ordinary supported continuous walk reaches goal: " + str(target))
			continue
		settled = 0
		var forward := (-_ordinary_player.get_camera().global_basis.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var axis := Vector2(delta.normalized().dot(right), -delta.normalized().dot(forward))
		axis *= clampf(delta.length() / 1.5, 0.35, 1.0)
		_ordinary_release_walk()
		_ordinary_action(&"move_left" if axis.x < 0.0 else &"move_right", true, absf(axis.x))
		_ordinary_action(&"move_forward" if axis.y < 0.0 else &"move_back", true, absf(axis.y))
		await _ordinary_ticks(1)
	_ordinary_release_walk()
	return _ordinary_require(false, "ordinary walk reaches supported goal within 15 seconds: " + str(target))


func _ordinary_release_walk() -> void:
	for action in ORDINARY_WALK_ACTIONS:
		_ordinary_action(action, false)


func _ordinary_look(target: Vector3) -> void:
	for _index in 4:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			Input.parse_input_event(click)
			await _ordinary_ticks(1)
			click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = false
			Input.parse_input_event(click)
		var desired := _ordinary_player.global_basis.inverse() * (target - _ordinary_player.get_interaction_origin()).normalized()
		var current := _ordinary_player.global_basis.inverse() * _ordinary_player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _ordinary_player.invert_mouse_y else -1.0)) / _ordinary_player.mouse_sensitivity
		Input.parse_input_event(event)
		await _ordinary_ticks(1)


func _ordinary_action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)


func _ordinary_press(action: StringName) -> void:
	_ordinary_action(action, true)
	await _ordinary_ticks(2)
	_ordinary_action(action, false)
	await _ordinary_ticks(3)


func _ordinary_button(node_name: String) -> bool:
	if not await _ordinary_boundary(func():
		var button := _ordinary_game.hud.find_child(node_name, true, false) as Button
		return button != null and button.is_visible_in_tree() and not button.disabled,
		5.0, "visible enabled HUD action: " + node_name):
		return false
	return await _ordinary_activate(_ordinary_game.hud.find_child(node_name, true, false) as Button)


func _ordinary_activate(button: Button) -> bool:
	# Activating a transient notice may retire its button before the next frame.
	var button_name := str(button.name)
	root.grab_focus()
	button.grab_focus()
	await process_frame
	if not _ordinary_require(root.gui_get_focus_owner() == button, "actual HUD button receives keyboard/controller focus: " + button_name):
		return false
	var activated := [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	_ordinary_action(&"ui_accept", true)
	await process_frame
	_ordinary_action(&"ui_accept", false)
	await process_frame
	return await _ordinary_boundary(func(): return activated[0], 5.0, "focused ui_accept activates real HUD button: " + button_name)


func _ordinary_ticks(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame


func _ordinary_boundary(predicate: Callable, seconds: float, description: String) -> bool:
	var deadline := mini(Time.get_ticks_msec() + int(seconds * 1000.0), _ordinary_deadline)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return _ordinary_require(true, description)
		await _ordinary_ticks(1)
	return _ordinary_require(false, description)


func _ordinary_require(condition: bool, description: String) -> bool:
	if not condition and _failures.is_empty():
		var snapshot := {"description": description, "paused": paused, "elapsed_deadline_msec": _ordinary_deadline - Time.get_ticks_msec()}
		if is_instance_valid(_ordinary_game) and _ordinary_game.is_inside_tree():
			snapshot["phase"] = _ordinary_game.phase
			snapshot["boarding_confirmation"] = _ordinary_game.get_boarding_confirmation_presentation_report()
			snapshot["cargo"] = _ordinary_game.get_activity_integration_report()
			if _ordinary_game.cargo_delivery_activity != null:
				snapshot["cargo_activity"] = _ordinary_game.cargo_delivery_activity.get_snapshot()
			var area := _ordinary_game.get("_boarding_area") as ShipBoardingArea
			snapshot["claim"] = {"area": str(area), "reserved": area.is_reserved() if area != null else false,
				"token": str(area.get_reservation_token()) if area != null else "none"}
		if is_instance_valid(_ordinary_player):
			snapshot["player"] = {"id": _ordinary_player.get_instance_id(), "original_id": _ordinary_player_id,
				"position": _ordinary_player.global_position, "velocity": _ordinary_player.velocity,
				"floor": _ordinary_player.is_on_floor(), "seated": _ordinary_player.is_seated()}
		if is_instance_valid(_ordinary_ship) and _ordinary_ship.is_inside_tree():
			var source := _ordinary_ship.get_command_source()
			snapshot["seat"] = {"anchor": str(_ordinary_ship.get_pilot_seat_anchor()),
				"player_at_anchor": _ordinary_player.is_seated_at(_ordinary_ship.get_pilot_seat_anchor()) if is_instance_valid(_ordinary_player) else false}
			snapshot["source"] = {"node": str(source), "default_local": source == _ordinary_ship.get_local_input_source(),
				"enabled": source.enabled if source != null else false, "owner": source.is_enabled_owner() if source != null else false}
			snapshot["ship"] = _ordinary_ship.get_telemetry()
			if _ordinary_deliver_selected:
				snapshot["delivery"] = {"contract": _ordinary_ship.get_landing_contract_report(),
					"capture": _ordinary_game.call(&"_get_landing_assist_report_for_ship", _ordinary_ship),
					"transition_busy": _ordinary_game.get("_transition_busy"),
					"transfers": _ordinary_transfer_receipts, "rewards": _ordinary_game.get_activity_reward_report(),
					"landing_request": _ordinary_game.get("_landing_request_active"),
					"landing_berth": _ordinary_game.get("_active_landing_berth_id")}
			var berth := _ordinary_game.world.get_berth_node(_ordinary_ship.get_home_berth_id()) as ShipBerth
			snapshot["berth"] = berth.audit() if berth != null else {}
		snapshot["inputs"] = {"forward": Input.get_action_strength(&"move_forward"), "brake": Input.is_action_pressed(&"brake")}
		if _ordinary_depart_selected:
			snapshot["departure"] = {"initial_position": _ordinary_initial_position, "initial_nose": _ordinary_initial_nose,
				"starts": _ordinary_start_snapshots, "start_physics_step": _ordinary_start_step, "previous_elapsed": _ordinary_previous_elapsed}
			if is_instance_valid(_ordinary_ship):
				snapshot["sampled_command"] = _ordinary_ship.get_last_ship_command().to_dictionary()
		print(_ordinary_marker_prefix() + "_FIRST_FAILURE: ", JSON.stringify(snapshot))
	return _check(condition, description)


func _test_player_selection_and_atomic_failure(
	game: GameFlow,
	hud: GameHUD,
	jovian: HeroShip,
	freight_berth: JovianFreightBerth
	) -> void:
	# Bypass only the title splash; the pause event and every selection below use
	# the real shipping HUD controls and request signal.
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud.call("_unhandled_input", pause_event)
	var pause_overlay := hud.get("_pause") as Control
	var board_open := pause_overlay.find_child(
		"ActivityBoardButton", true, false
	) as Button
	_check(
		paused and pause_overlay.visible and board_open != null,
		"the existing pause input opens the reachable menu containing Activity Board"
	)
	board_open.emit_signal("pressed")
	var patrol_button := pause_overlay.find_child(
		"PatrolActivityButton", true, false
	) as Button
	var race_button := pause_overlay.find_child(
		"TimedRaceActivityButton", true, false
	) as Button
	var cargo_button := pause_overlay.find_child(
		"CargoDeliveryActivityButton", true, false
	) as Button
	var convoy_button := pause_overlay.find_child(
		"ConvoyEscortActivityButton", true, false
	) as Button
	var board := hud.get_activity_selection_report()
	_check(
		bool(board.get("page_visible", false))
		and patrol_button != null and race_button != null and cargo_button != null
		and convoy_button != null
		and cargo_button.focus_mode == Control.FOCUS_ALL
		and hud.get_viewport().gui_get_focus_owner() == race_button,
		"the activity page exposes all four controls and focuses the selected race button"
	)

	patrol_button.emit_signal("pressed")
	_check(
		game.get_activity_integration_report().get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_PATROL
		and hud.get_viewport().gui_get_focus_owner() == patrol_button,
		"the patrol button reaches GameFlow and validated selection moves focus to it"
	)
	race_button.emit_signal("pressed")
	var race_selected := game.get_activity_integration_report()
	_check(
		race_selected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(race_selected.get("attached_route_owner_count", 0)) == 1,
		"the race button restores exactly one Cinder route owner"
	)

	# Structured reentrant failure witness: both cargo owners return detached, then
	# an observer of the source's reattach removes the destination synchronously.
	# The pair transaction must roll back both manifests as well as preserve the
	# previous race owner and rejected board state.
	var ship_parent := jovian.get_parent()
	var ship_index := jovian.get_index()
	var berth_parent := freight_berth.get_parent()
	var berth_index := freight_berth.get_index()
	ship_parent.remove_child(jovian)
	berth_parent.remove_child(freight_berth)
	await process_frame
	ship_parent.add_child(jovian)
	ship_parent.move_child(jovian, mini(ship_index, ship_parent.get_child_count() - 1))
	berth_parent.add_child(freight_berth)
	berth_parent.move_child(
		freight_berth,
		mini(berth_index, berth_parent.get_child_count() - 1)
	)
	await process_frame
	var cargo_before_rejection := game.get_activity_integration_report()
	var source_before_rejection := (
		cargo_before_rejection.get("cargo_source_manifest", {}) as Dictionary
	).duplicate(true)
	var destination_before_rejection := (
		cargo_before_rejection.get("cargo_destination_manifest", {}) as Dictionary
	).duplicate(true)
	var cargo_authority := cargo_before_rejection.get(
		"cargo_transfer_authority"
	) as CargoTransferAuthority
	var observer_attack := {"triggered": false}
	var lifecycle_events: Array[StringName] = []
	cargo_authority.manifest_reattached.connect(
		func(handle: Dictionary) -> void:
			lifecycle_events.append(StringName("reattached:%s" % handle.manifest_id))
	)
	cargo_authority.manifest_detached.connect(
		func(handle: Dictionary) -> void:
			lifecycle_events.append(StringName("detached:%s" % handle.manifest_id))
	)
	cargo_authority.manifest_reattached.connect(
		func(handle: Dictionary) -> void:
			if handle.get("manifest_id", &"") != &"jovian_provisional_manifest":
				return
			observer_attack["triggered"] = true
			berth_parent.remove_child(freight_berth),
		CONNECT_ONE_SHOT
	)
	cargo_button.emit_signal("pressed")
	var rejected := game.get_activity_integration_report()
	var rejected_board := hud.get_activity_selection_report()
	_check(
		rejected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_TIMED_RACE
		and int(rejected.get("attached_route_owner_count", 0)) == 1
		and bool(observer_attack.get("triggered", false))
		and lifecycle_events == [
			&"reattached:jovian_provisional_manifest",
			&"detached:jovian_freight_berth_manifest",
			&"detached:jovian_provisional_manifest",
		]
		and rejected.get("cargo_source_manifest", {}) == source_before_rejection
		and rejected.get("cargo_destination_manifest", {}) == destination_before_rejection
		and not bool(source_before_rejection.get("attached", true))
		and not bool(destination_before_rejection.get("attached", true))
		and "ACTIVITY ATTACH FAILED" in str(rejected_board.get("status", "")),
		"reentrant cargo attach failure preserves both detached manifests, the prior selection, and its route owner"
	)
	if freight_berth.get_parent() == null:
		berth_parent.add_child(freight_berth)
		berth_parent.move_child(
			freight_berth,
			mini(berth_index, berth_parent.get_child_count() - 1)
		)
	await process_frame
	await process_frame
	cargo_button.emit_signal("pressed")
	var selected := game.get_activity_integration_report()
	board = hud.get_activity_selection_report()
	_check(
		selected.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and int(selected.get("attached_route_owner_count", -1)) == 0
		and board.get("selected_activity_kind", &"")
		== GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and hud.get_viewport().gui_get_focus_owner() == cargo_button,
		"the cargo button selects the authority-backed delivery, focuses it, and releases both Cinder adapters"
	)

	# Exit by the visible menu route, leaving the tree unpaused for activity time.
	var back := pause_overlay.find_child(
		"ActivitySelectionBackButton", true, false
	) as Button
	back.emit_signal("pressed")
	_check(
		hud.get_viewport().gui_get_focus_owner() == board_open,
		"returning from Activity Board restores focus to its pause-menu entry"
	)
	var resume := pause_overlay.find_child("ResumeButton", true, false) as Button
	resume.emit_signal("pressed")
	_check(not paused and not pause_overlay.visible, "the ordinary Back/Resume route closes the board")


func _test_contract_and_start_gates(
	game: GameFlow,
	hud: GameHUD,
	jovian: HeroShip,
	torrent: HeroShip,
	freight_berth: JovianFreightBerth
	) -> void:
	var integration := game.get_activity_integration_report()
	var contract := integration.get("cargo_contract", {}) as Dictionary
	var source_handle := integration.get("cargo_source_handle", {}) as Dictionary
	var destination_handle := integration.get("cargo_destination_handle", {}) as Dictionary
	_check(
		int(integration.get("cargo_transfer_authority_count", 0)) == 1
		and integration.get("cargo_source_entity") == jovian
		and integration.get("cargo_destination_entity") == freight_berth
		and source_handle.get("entity_id", &"") == &"jovian_provisional"
		and source_handle.get("manifest_id", &"") == &"jovian_provisional_manifest"
		and destination_handle.get("entity_id", &"") == &"jovian_freight_berth"
		and destination_handle.get("manifest_id", &"") == &"jovian_freight_berth_manifest",
		"one cargo authority binds exact generation handles to the real ship and berth nodes"
	)
	_check(
		contract.get("contract_id", &"") == GameFlow.CARGO_DELIVERY_ACTIVITY_ID
		and contract.get("item_id", &"") == &"fabrication_kits"
		and int(contract.get("quantity", 0)) == 2
		and contract.get("ordered_phases", []) == [
			&"departed_shipyard", &"returned_to_shipyard"
		]
		and is_equal_approx(float(contract.get("deadline_seconds", 0.0)), 180.0),
		"the checked-in delivery contract freezes item, quantity, phases, and physics deadline"
	)
	var on_foot := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(
		not bool(on_foot.get("accepted", true))
		and on_foot.get("reason", &"") == &"not_in_free_flight"
		and not bool(game.get_activity_integration_report().get("selection_locked", true)),
		"selecting cargo cannot start it before a physical free-flight sortie"
	)
	game.active_ship = torrent
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var wrong_craft := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(
		not bool(wrong_craft.get("accepted", true))
		and wrong_craft.get("reason", &"") == &"delivery_craft_required",
		"the selected delivery cannot bind to a non-Jovian active craft"
	)
	game.active_ship = jovian
	var started := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var generation := int(started.get("session_generation", -1))
	_check(
		bool(started.get("accepted", false))
		and generation == 1
		and started.get("state_id", &"") == &"active"
		and started.get("phase_id", &"") == &"return"
		and int(started.get("completed_checkpoint_count", 0)) == 1,
		"free flight starts generation one and records physical departure exactly once"
	)
	var return_marker := _find_minimap_marker(
		game.get_minimap_snapshot().get("objective_markers", []) as Array,
		&"active_jovian_delivery_return",
	)
	_check(
		(return_marker.get("position", Vector3.INF) as Vector3).is_equal_approx(
			game.world.get_berth_transform(&"jovian_freight_berth").origin
		)
			and int(return_marker.get("generation", 0)) == generation,
		"the active delivery publishes the exact physical return berth on the minimap"
	)
	var ui_report := hud.get_activity_selection_report()
	_check(
		bool(ui_report.get("selection_locked", false))
		and "LOCKED" in str(ui_report.get("status", "")),
		"the accepted start commits the GameFlow selection lock back into the board"
	)

	# Re-open through the real pause event and prove every alternative is disabled.
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	hud.call("_unhandled_input", pause_event)
	var pause_overlay := hud.get("_pause") as Control
	(pause_overlay.find_child("ActivityBoardButton", true, false) as Button).emit_signal("pressed")
	ui_report = hud.get_activity_selection_report()
	var buttons := ui_report.get("buttons", {}) as Dictionary
	_check(
		bool((buttons.get(&"timed_race", {}) as Dictionary).get("disabled", false))
		and bool((buttons.get(&"patrol", {}) as Dictionary).get("disabled", false))
		and not bool((buttons.get(&"cargo_delivery", {}) as Dictionary).get("disabled", true)),
		"a running cargo generation disables both alternative player selections"
	)
	(pause_overlay.find_child("ActivitySelectionBackButton", true, false) as Button).emit_signal("pressed")
	(pause_overlay.find_child("ResumeButton", true, false) as Button).emit_signal("pressed")


func _test_physics_reentry_and_physical_delivery(
	game: GameFlow,
	hud: GameHUD,
	world: ShipyardWorld,
	jovian: HeroShip,
	freight_berth: JovianFreightBerth
	) -> void:
	game.set_physics_process(false)
	var initial_report := game.get_activity_integration_report()
	var race_samples := int(initial_report.get("position_sample_count", -1))
	game.call("_physics_process", 0.0)
	game.call("_physics_process", 0.5)
	var advanced := game.get_active_activity_snapshot()
	_check(
		is_equal_approx(float(advanced.get("elapsed_seconds", -1.0)), 0.5)
		and is_equal_approx(float(advanced.get("deadline_remaining_seconds", -1.0)), 179.5)
		and int(game.get_activity_integration_report().get("cargo_physics_step_count", 0)) == 1
		and int(game.get_activity_integration_report().get("position_sample_count", -2))
		== race_samples,
		"only nonzero caller physics delta advances the cargo clock; no Cinder position sample runs"
	)
	_check(
		"DELIVERY  RETURN  1/2" in str(hud.get_activity_objective_report().get("text", ""))
		and "LEFT" in str(hud.get_activity_objective_report().get("text", "")),
		"the HUD publishes return-phase progress and remaining physics time"
	)

	var before_reentry := game.get_active_activity_snapshot()
	var integration_before := game.get_activity_integration_report()
	var authority_id := int(integration_before.get("cargo_transfer_authority_instance_id", 0))
	var activity_id := int(integration_before.get("cargo_delivery_activity_instance_id", 0))
	root.remove_child(game)
	await process_frame
	await process_frame
	var detached := game.get_activity_integration_report()
	_check(
		not bool((detached.get("cargo_source_manifest", {}) as Dictionary).get("attached", true))
		and not bool((detached.get("cargo_destination_manifest", {}) as Dictionary).get("attached", true))
		and game.get_active_activity_snapshot() == before_reentry,
		"whole-Main detach freezes the delivery and marks both real manifest owners detached"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	var reentered := game.get_activity_integration_report()
	_check(
		int(reentered.get("cargo_transfer_authority_instance_id", 0)) == authority_id
		and int(reentered.get("cargo_delivery_activity_instance_id", 0)) == activity_id
		and bool((reentered.get("cargo_source_manifest", {}) as Dictionary).get("attached", false))
		and bool((reentered.get("cargo_destination_manifest", {}) as Dictionary).get("attached", false))
		and game.get_active_activity_snapshot() == before_reentry,
		"re-entry reattaches exact nodes/handles without identity, generation, time, or quantity churn"
	)

	# Stage inside the real berth's capture volume, then let the production berth
	# reservation and HeroShip landing assist perform the physical return.
	var dock_transform := world.get_berth_transform(&"jovian_freight_berth")
	jovian.global_transform = Transform3D(
		dock_transform.basis,
		dock_transform.origin + Vector3.UP * 3.0
	)
	jovian.velocity = Vector3.ZERO
	jovian.set("_landed", false)
	game.call("_mark_sortie_departed")
	# The save store cannot write while the delivery lands, so its reward
	# receipt is rejected and must stay owed rather than being lost.
	_filesystem.reject_writes = true
	game.call("_try_request_landing")
	_check(
		bool(game.get("_landing_request_active")) and jovian.is_landing_active(),
		"the real Jovian acquires its physical freight-berth landing contract"
	)
	var landed := await _wait_until(
		func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN,
		720
	)
	_filesystem.reject_writes = false
	# The same landing call completes the delivery and then docks; the routine
	# docking toast must not erase the delivery's reward-failure toast.
	var landed_toast_title := (hud.get("_toast_title") as Label).text
	var landed_toast_detail := (hud.get("_toast_detail") as Label).text
	_check(
		landed_toast_title == "FABRICATION KITS DELIVERED"
		and "reward receipt could not be saved" in landed_toast_detail,
		"the delivery reward-failure toast survives the same-frame docking toast (got %s: %s)"
		% [landed_toast_title, landed_toast_detail]
	)
	var docking_toast_follows := false
	for _frame in 600:
		if (hud.get("_toast_title") as Label).text == "LANDING COMPLETE" \
				and (hud.get("_toast_panel") as Control).visible:
			docking_toast_follows = true
			break
		await process_frame
	_check(docking_toast_follows, "the held docking toast is shown once the reward toast finishes")
	var completed := game.get_active_activity_snapshot()
	var receipt := completed.get("accepted_receipt", {}) as Dictionary
	_check(
		landed and bool(jovian.get_telemetry().get("landed", false))
		and jovian.global_transform.is_equal_approx(dock_transform)
		and completed.get("state_id", &"") == &"completed"
		and completed.get("phase_id", &"") == &"complete",
		"physical landing submits return and completes the typed delivery at the exact berth transform"
	)
	_check(
		_find_minimap_marker(
			game.get_minimap_snapshot().get("objective_markers", []) as Array,
			&"active_jovian_delivery_return",
		).is_empty(),
		"physical completion withdraws the delivery marker without a stale berth target"
	)
	var inventory := game.get_activity_integration_report()
	_check(
		_manifest_quantity(inventory.get("cargo_source_manifest", {}) as Dictionary) == 4
		and _manifest_quantity(inventory.get("cargo_destination_manifest", {}) as Dictionary) == 2
		and receipt.get("transfer_id", &"") == &"jovian_fabrication_kit_delivery_g1"
		and int(receipt.get("quantity", 0)) == 2,
		"CargoTransferAuthority conserves quantity and returns the exact generation-one receipt"
	)
	var reward_record := (
		(game.get_activity_reward_report().get("authority", {}) as Dictionary).get(
			"record", {}
		) as Dictionary
	)
	var reward_receipt := reward_record.get("last_receipt", {}) as Dictionary
	_check(
		int(reward_record.get("total_receipts", -1)) == 0
			and reward_receipt.is_empty(),
		"a landed delivery whose receipt the store rejects records no receipt yet"
	)
	_check(
		"DELIVERY  COMPLETE  2 FABRICATION KITS"
		in str(hud.get_activity_objective_report().get("text", ""))
		and "REWARD" not in str(hud.get_activity_objective_report().get("text", "")).to_upper(),
		"completion publishes exact delivered cargo without reward language"
	)
	_check(
		freight_berth.get_berth_id() == &"jovian_freight_berth",
		"delivery destination identity remains the module's published berth ID"
	)


func _test_failure_expiry_reset_and_authority(game: GameFlow, hud: GameHUD) -> void:
	var activity := game.get_activity_integration_report().get(
		"cargo_delivery_activity"
	) as CargoDeliveryActivity
	var completed_generation := activity.get_generation()
	var reset_accepted := game.reset_active_activity()
	_check(reset_accepted, "completed delivery resets explicitly (%s)" % (game.get("_jovian_cargo_session_save_status") as Dictionary).get("reason", ""))
	var reward_record := (
		(game.get_activity_reward_report().get("authority", {}) as Dictionary).get(
			"record", {}
		) as Dictionary
	)
	var reward_receipt := reward_record.get("last_receipt", {}) as Dictionary
	_check(
		int(reward_record.get("total_receipts", 0)) == 1
			and reward_receipt.get("activity_id", "") \
				== "jovian_fabrication_kit_delivery"
			and int(reward_receipt.get("activity_generation", 0)) == completed_generation
			and reward_receipt.get("reward_id", "") \
				== "return_fabrication_kits_to_shipyard"
			and bool(reward_receipt.get("granted", false))
			and not bool(reward_receipt.get("replay_allowed", true)),
		"the next reset pays the owed delivery as one non-replayable fabrication-kit receipt"
	)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var restarted := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var failure_generation := int(restarted.get("session_generation", -1))
	var stale := activity.fail(&"stale_destruction", completed_generation)
	_check(
		not bool(stale.get("accepted", true))
		and stale.get("reason", &"") == &"stale_generation"
		and failure_generation == completed_generation + 2,
		"reset and restart advance generations so an old destruction cannot fail the replacement"
	)
	_check(
		game.call("_fail_active_activity", &"ship_destroyed")
		and game.get_active_activity_snapshot().get("failure_reason", &"") == &"ship_destroyed"
		and "DELIVERY  FAILED — SHIP DESTROYED"
		in str(hud.get_activity_objective_report().get("text", "")),
		"current-generation destruction fails cargo and publishes its typed reason"
	)
	_check(game.reset_active_activity(), "failed delivery resets for a final timeout witness")
	var timeout_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	game.call("_physics_process", 179.5)
	game.call("_physics_process", 0.5)
	var expired := game.get_active_activity_snapshot()
	var final_inventory := game.get_activity_integration_report()
	_check(
		int(timeout_start.get("session_generation", -1)) == failure_generation + 2
		and expired.get("state_id", &"") == &"expired"
		and expired.get("failure_reason", &"") == &"deadline_expired"
		and is_equal_approx(float(expired.get("elapsed_seconds", -1.0)), 180.0)
		and "DELIVERY  EXPIRED — DEADLINE EXPIRED"
		in str(hud.get_activity_objective_report().get("text", "")),
		"the exact 180-second caller-physics boundary expires once with typed HUD copy"
	)
	_check(
		_manifest_quantity(final_inventory.get("cargo_source_manifest", {}) as Dictionary) == 4
		and _manifest_quantity(final_inventory.get("cargo_destination_manifest", {}) as Dictionary) == 2,
		"reset, destruction, and expiry never refill or transfer cargo"
	)
	var audit := final_inventory.get("cargo_authority_audit", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
		and int(audit.get("committed_transfer_count", -1)) == 1
		and final_inventory.get("inventory_authority")
		== final_inventory.get("cargo_transfer_authority")
		and not bool(final_inventory.get("owns_inventory", true))
		and not bool(final_inventory.get("grants_rewards", true))
		and not bool(final_inventory.get("combat_authority", true))
		and not bool(final_inventory.get("ship_authority", true))
		and not bool(final_inventory.get("berth_authority", true))
		and final_inventory.get("cargo_evidence_status", &"") == &"modern_interpretation"
		and not bool(final_inventory.get("cargo_source_bounded", true))
		and not bool(final_inventory.get("cargo_historical_authenticity_claim", true)),
		"GameFlow/HUD retain zero adjacent authority and label the delivery as modern interpretation"
	)
	# Every run moves two of the Jovian's six kits. Drain the hold through two
	# more real deliveries; the next departure must not start a run whose
	# landing transfer can only be rejected.
	for run in 2:
		_check(game.reset_active_activity(), "terminal delivery resets for another run")
		game.phase = GameFlow.Phase.FREE_FLIGHT
		var run_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		_check(
			bool(run_start.get("accepted", false))
			and bool(game.call("_complete_cargo_delivery_on_return")),
			"a later delivery in the same session starts and delivers"
		)
	var drained := game.get_activity_integration_report()
	_check(
		_manifest_quantity(drained.get("cargo_source_manifest", {}) as Dictionary) == 0
		and _manifest_quantity(drained.get("cargo_destination_manifest", {}) as Dictionary) == 6,
		"three deliveries move all six kits to the freight berth"
	)
	var final_reset := game.reset_active_activity()
	_check(final_reset, "the drained delivery resets")
	game.phase = GameFlow.Phase.FREE_FLIGHT
	var empty_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(
		not bool(empty_start.get("accepted", true))
		and empty_start.get("reason", &"") == &"insufficient_source_quantity"
		and game.get_active_activity_snapshot().get("state_id", &"") == &"idle",
		"an empty Jovian hold refuses the run at departure instead of failing it on landing"
	)
	_check(final_reset and game.get_active_activity_snapshot().get("state_id") == &"idle",
		"the actual completed cargo run retains IDLE after its accepted ordinary reset")
	var race_button := (hud.get("_activity_selection_buttons") as Dictionary).get(GameFlow.ACTIVITY_KIND_TIMED_RACE) as Button
	_check(race_button != null and not race_button.disabled,
		"the ordinary HUD enables Race after a successful cargo reset")
	race_button.pressed.emit()
	_check(game.get_activity_integration_report().get("selected_activity_kind") == GameFlow.ACTIVITY_KIND_TIMED_RACE,
		"the actual HUD Race button selects its family after a successful cargo reset")
	var cargo_owner := game.cargo_delivery_activity
	var cargo_generation := cargo_owner.get_generation()
	for kind: StringName in [GameFlow.ACTIVITY_KIND_PATROL, GameFlow.ACTIVITY_KIND_CARGO_DELIVERY,
			GameFlow.ACTIVITY_KIND_CONVOY_ESCORT, GameFlow.ACTIVITY_KIND_TIMED_RACE]:
		var button := (hud.get("_activity_selection_buttons") as Dictionary).get(kind) as Button
		_check(button != null and not button.disabled, "safe reset exposes the ordinary %s HUD choice" % kind)
		button.pressed.emit()
		var chosen := game.get_activity_integration_report()
		_check(chosen.selected_activity_kind == kind and int(chosen.attached_route_owner_count) <= 1
			and game.cargo_delivery_activity == cargo_owner and cargo_owner.get_generation() == cargo_generation
			and _manifest_quantity(chosen.cargo_source_manifest) == 0
			and _manifest_quantity(chosen.cargo_destination_manifest) == 6,
			"ordinary %s HUD adoption preserves depleted cargo, generation and one route owner" % kind)



func _test_saved_cargo_reentry(saved_generation: int) -> void:
	var fresh := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	fresh.configure_runtime_settings_persistence(store, "user://cargo-delivery-production-legacy.cfg")
	root.add_child(fresh)
	await process_frame
	await physics_frame
	await process_frame
	fresh.set_physics_process(false)
	var report := fresh.get_activity_integration_report()
	_check(bool((fresh.get("_jovian_cargo_session_restore_status") as Dictionary).get("accepted", false))
		and fresh.cargo_delivery_activity.get_generation() == saved_generation
		and fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
		and _manifest_quantity(report.cargo_source_manifest) == 0
		and _manifest_quantity(report.cargo_destination_manifest) == 6,
		"fresh Main restores the actual reset generation and depleted conserved freight pair without refilling")
	var before := fresh.cargo_delivery_activity.capture_persistence_state()
	var malformed := {"schema_version": 1, "activities": [{"activity_id": "jovian_fabrication_kit_delivery",
		"reward_requested": false, "reward_granted": false, "progress": {}, "wrong_generation": 1, "wrong_state": 0}]}
	var rejected := (fresh.get("_jovian_cargo_session_persistence") as JovianCargoSessionPersistence).validate_record(
		malformed, fresh.cargo_delivery_activity, fresh.cargo_transfer_authority)
	_check(not bool(rejected.accepted) and fresh.cargo_delivery_activity.capture_persistence_state() == before,
		"a wrong-shape six-key saved cargo row is rejected without script errors or owner mutation")
	var hud := fresh.get_node("HUD") as GameHUD
	var cargo_button := (hud.get("_activity_selection_buttons") as Dictionary).get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button
	cargo_button.pressed.emit()
	_check(fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and fresh.cargo_delivery_activity.get_generation() == saved_generation,
		"fresh Main ordinary Cargo button adopts its exact saved IDLE owner")
	await _clean_up(fresh)


func _make_disk_game(path: String, filesystem: UserDataFilesystem) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(Store.new(path, filesystem), "user://jovian-crash-legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	return game


func _cargo_receipts(game: GameFlow) -> int:
	return int((game.get_activity_reward_report().authority.record.get("reward_counts", {}) as Dictionary).get("return_fabrication_kits_to_shipyard", 0))


func _prepare_cargo_sortie(game: GameFlow) -> void:
	game.active_ship = _find_ship(game, &"jovian_provisional")
	game.active_ship.set_piloted(true)
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT


func _commit_unrelated_transfer(game: GameFlow, suffix: String) -> bool:
	var source := Node.new()
	var destination := Node.new()
	game.add_child(source)
	game.add_child(destination)
	var authority := game.cargo_transfer_authority
	var source_record := authority.register_entity(source, StringName("aux_source_" + suffix), StringName("aux_source_manifest_" + suffix), 4,
		{GameFlow.CARGO_DELIVERY_ITEM_ID: 1})
	var destination_record := authority.register_entity(destination, StringName("aux_destination_" + suffix), StringName("aux_destination_manifest_" + suffix), 4)
	var receipt := authority.transfer(StringName("aux_transfer_" + suffix), source_record.handle, destination_record.handle, GameFlow.CARGO_DELIVERY_ITEM_ID, 1)
	return bool(receipt.accepted) and authority.get_quantity(destination_record.handle, GameFlow.CARGO_DELIVERY_ITEM_ID) == 1


func _test_interrupted_cargo_recovery() -> void:
	const path := "user://jovian-interrupted-session.json"
	var first_filesystem := InterruptedRewardFilesystem.new()
	var first := await _make_disk_game(path, first_filesystem)
	var first_hud := first.get_node("HUD") as GameHUD
	first.active_ship = first.get_flyable_ships()[1]
	first.active_ship.set_piloted(true)
	first.set("_piloting", true)
	first.phase = GameFlow.Phase.FREE_FLIGHT
	var earlier_race := first.request_activity_start(GameFlow.DEFAULT_FREE_FLIGHT_ACTIVITY_ID)
	_check(bool(earlier_race.accepted) and first.reset_active_activity()
		and first.get_cinder_race_session_persistence_report().last_save_status.accepted,
		"a genuine earlier Main race reset leaves an admissible saved IDLE route before cargo starts")
	(first_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
	_prepare_cargo_sortie(first)
	_check(_commit_unrelated_transfer(first, "prior"), "an unrelated actual cargo transfer precedes the saved Main contract")
	var started := first.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	var generation := first.cargo_delivery_activity.get_generation()
	first.cargo_delivery_activity.advance_physics(0.75, generation)
	var saved := first.save_jovian_cargo_session()
	var active_capture := first.cargo_delivery_activity.capture_persistence_state()
	var active_primary := FileAccess.get_file_as_bytes(path)
	_check(bool(started.accepted) and bool(saved.accepted) and int(active_capture.next_phase_index) == 1,
		"actual departed Jovian cargo saves its live phase, clock and generation to real disk (%s)" % saved.get("reason", ""))
	if not bool(saved.accepted):
		await _clean_up(first)
		return
	first_filesystem.stopped = true
	await _clean_up(first)

	var completion_filesystem := InterruptedRewardFilesystem.new()
	var resumed := await _make_disk_game(path, completion_filesystem)
	var resumed_report := resumed.get_activity_integration_report()
	_check(resumed.cargo_delivery_activity.capture_persistence_state() == active_capture
		and resumed_report.selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and resumed.get_cinder_race_session_persistence_report().restore_status.reason == &"jovian_cargo_session_has_priority"
		and _manifest_quantity(resumed_report.cargo_source_manifest) == 6
		and _manifest_quantity(resumed_report.cargo_destination_manifest) == 0,
		"fresh Main restores exact mid-ACTIVE cargo phase/time/identity and conserved untransferred inventory")
	_prepare_cargo_sortie(resumed)
	_check(_commit_unrelated_transfer(resumed, "current"), "current unrelated containers and receipts remain independently authority-owned after cargo startup restore")
	var completed := bool(resumed.call("_complete_cargo_delivery_on_return"))
	var resumed_store := resumed.get("_runtime_settings_user_data_store") as UserDataStore
	var terminal := resumed_store.get_snapshot().get("jovian_cargo_session", {}) as Dictionary
	_check(completed and completion_filesystem.reward_rejected and completion_filesystem.stopped
		and _cargo_receipts(resumed) == 0 and int(terminal.activities[0].state) == CargoDeliveryActivity.State.COMPLETED
		and bool(terminal.activities[0].reward_requested) and not bool(terminal.activities[0].reward_granted),
		"genuine transfer publishes durable unpaid completion before its real reward write is rejected")
	await _clean_up(resumed)

	var retry_filesystem := InterruptedRewardFilesystem.new()
	var fresh := await _make_disk_game(path, retry_filesystem)
	var pending := fresh.get_activity_integration_report()
	_check(fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.COMPLETED
		and fresh.cargo_delivery_activity.get_generation() == generation and _cargo_receipts(fresh) == 0
		and _manifest_quantity(pending.cargo_source_manifest) == 4 and _manifest_quantity(pending.cargo_destination_manifest) == 2
		and retry_filesystem.reward_rejected and not fresh.reset_active_activity(),
		"fresh Main keeps the exact owed delivery and transferred pair while failed retries block reset")
	var pending_hud := fresh.get_node("HUD") as GameHUD
	var race_button := pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_TIMED_RACE) as Button
	race_button.pressed.emit()
	_check(race_button.disabled and fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY,
		"an unpaid cargo owner cannot be replaced through the ordinary Race HUD request")
	retry_filesystem.interrupt_rewards = false
	retry_filesystem.stopped = false
	fresh.call("_retry_owed_game_flow_activity_rewards")
	var fresh_store := fresh.get("_runtime_settings_user_data_store") as UserDataStore
	_check(_cargo_receipts(fresh) == 1 and fresh_store.get_snapshot().jovian_cargo_session.activities[0].reward_granted,
		"retry atomically acknowledges the exact completed delivery with one saved reward receipt")
	var paid_primary := FileAccess.get_file_as_bytes(path)
	var unpaid_backup := FileAccess.get_file_as_bytes(path + ".bak")
	# Historical false/false flags carry no entitlement. Keep the genuine
	# completion and conserved transfer, changing only its legacy reward markers.
	var legacy_payload := fresh_store.get_snapshot()
	legacy_payload.jovian_cargo_session.activities[0].reward_requested = false
	legacy_payload.jovian_cargo_session.activities[0].reward_granted = false
	var corrupt_legacy := legacy_payload.jovian_cargo_session.duplicate(true) as Dictionary
	corrupt_legacy.activities[0].reward_granted = true
	var corrupt_validation := (fresh.get("_jovian_cargo_session_persistence") as JovianCargoSessionPersistence).validate_record(
		corrupt_legacy, fresh.cargo_delivery_activity, fresh.cargo_transfer_authority)
	_check(not bool(corrupt_validation.accepted), "a granted-without-request cargo marker remains invalid")
	var legacy_saved := fresh_store.commit(legacy_payload, fresh_store.get_generation(), "jovian-legacy-reward-markers")
	await _clean_up(fresh)
	retry_filesystem = InterruptedRewardFilesystem.new()
	retry_filesystem.interrupt_rewards = false
	fresh = await _make_disk_game(path, retry_filesystem)
	fresh_store = fresh.get("_runtime_settings_user_data_store") as UserDataStore
	pending_hud = fresh.get_node("HUD") as GameHUD
	var restored_legacy := fresh.get_activity_integration_report()
	_check(bool(legacy_saved.accepted)
		and fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.COMPLETED
		and fresh.cargo_delivery_activity.get_generation() == generation
		and _manifest_quantity(restored_legacy.cargo_source_manifest) == 4
		and _manifest_quantity(restored_legacy.cargo_destination_manifest) == 2
		and _cargo_receipts(fresh) == 1 and not fresh.call("_has_pending_jovian_cargo_reward"),
		"fresh Main restores legacy completed cargo and conserved kits without inferring reward entitlement")
	# Inert cargo carries no restore priority over the earlier saved IDLE race.
	# Adopt its retained owner through the same HUD choice before testing Reset.
	(pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
	_check(fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY,
		"ordinary Cargo HUD selection adopts the cold legacy completed owner before reset")
	_prepare_cargo_sortie(fresh)
	var legacy_resaved := fresh.save_jovian_cargo_session()
	fresh.call("_retry_owed_game_flow_activity_rewards")
	var legacy_row := fresh_store.get_snapshot().jovian_cargo_session.activities[0] as Dictionary
	_check(bool(legacy_saved.accepted) and bool(legacy_resaved.accepted)
		and not legacy_row.reward_requested and not legacy_row.reward_granted
		and not fresh.call("_has_pending_jovian_cargo_reward") and _cargo_receipts(fresh) == 1,
		"legacy false/false cargo remains ambiguous without inferred debt or additional credit")
	var owner := fresh.cargo_delivery_activity
	var before := owner.capture_persistence_state()
	var before_inventory := fresh.cargo_transfer_authority.to_dictionary()
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var reset_events := {"count": 0}
	owner.activity_reset.connect(func(_snapshot: Dictionary) -> void: reset_events.count += 1)
	retry_filesystem.reject_writes = true
	_check(not fresh.reset_active_activity() and fresh.cargo_delivery_activity == owner
		and owner.capture_persistence_state() == before and fresh.cargo_transfer_authority.to_dictionary() == before_inventory
		and FileAccess.get_file_as_bytes(path) == before_bytes and int(reset_events.count) == 0,
		"rejected legacy cargo reset retains exact owner, quantities, ledger, disk bytes and unpublished lifecycle")
	retry_filesystem.reject_writes = false
	_check(fresh.reset_active_activity() and int(reset_events.count) == 1
		and owner.get_state() == CargoDeliveryActivity.State.IDLE and owner.get_generation() == generation + 1,
		"accepted legacy cargo reset durably publishes one typed IDLE generation")
	var idle_bytes := FileAccess.get_file_as_bytes(path)
	retry_filesystem.reject_writes = true
	_prepare_cargo_sortie(fresh)
	var next_start := fresh.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(bool(next_start.accepted) and owner.get_generation() == generation + 2
		and bool(fresh.call("_complete_cargo_delivery_on_return")) and _cargo_receipts(fresh) == 1
		and FileAccess.get_file_as_bytes(path) == idle_bytes,
		"a genuine next delivery completes its transfer while every start, phase and terminal write fails after saved IDLE")
	var interrupted_inventory := fresh.get_activity_integration_report()
	_check(owner.get_state() == CargoDeliveryActivity.State.COMPLETED
		and _manifest_quantity(interrupted_inventory.cargo_source_manifest) == 2
		and _manifest_quantity(interrupted_inventory.cargo_destination_manifest) == 4
		and not fresh.reset_active_activity()
		and not bool(fresh.select_activity_kind(GameFlow.ACTIVITY_KIND_TIMED_RACE).accepted),
		"the unpaid live transfer conserves remaining kits and cannot reset or switch away during the write failure")
	retry_filesystem.reject_writes = false
	var unpaid_capture := owner.capture_persistence_state()
	var unpaid_reset := owner.reset_with_persistence(owner.get_generation(), fresh.save_jovian_cargo_session)
	_check(not bool(unpaid_reset.accepted) and owner.capture_persistence_state() == unpaid_capture
		and FileAccess.get_file_as_bytes(path) == idle_bytes and _cargo_receipts(fresh) == 1,
		"the codec refuses an unpaid completed source even inside a genuine staged reset after writes recover")
	fresh.call("_retry_owed_game_flow_activity_rewards")
	var recovered := fresh_store.get_snapshot().jovian_cargo_session.activities[0] as Dictionary
	_check(_cargo_receipts(fresh) == 2 and int(recovered.generation) == owner.get_generation()
		and int(recovered.state) == CargoDeliveryActivity.State.COMPLETED
		and bool(recovered.reward_requested) and bool(recovered.reward_granted),
		"ordinary retry recovers the actual next-generation completion and credits it once after writes recover (%s)" %
		(fresh.get("_jovian_cargo_session_save_status") as Dictionary).get("reason", ""))
	if _cargo_receipts(fresh) != 2:
		await _clean_up(fresh)
		return
	fresh.call("_retry_owed_game_flow_activity_rewards")
	_check(_cargo_receipts(fresh) == 2,
		"repeated retry does not replay the recovered transfer reward")
	var paid_snapshot := owner.get_snapshot()
	_check(fresh.reset_active_activity(), "second paid cargo resets before changing board family")
	var cargo_idle_generation := owner.get_generation()
	var patrol_button := pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_PATROL) as Button
	patrol_button.pressed.emit()
	fresh.active_ship = fresh.get_flyable_ships()[1]
	fresh.active_ship.set_piloted(true)
	fresh.phase = GameFlow.Phase.FREE_FLIGHT
	var patrol_start := fresh.request_activity_start(GameFlow.DEFAULT_FREE_FLIGHT_ACTIVITY_ID)
	var route := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
	for checkpoint in route.get_checkpoint_count():
		fresh.active_ship.global_position = route.get_checkpoint_position(checkpoint)
		fresh.call("_physics_process", 0.0)
		fresh.call("_physics_process", fresh.patrol_activity.dwell_seconds)
	_check(bool(patrol_start.accepted) and fresh.get_activity_reward_report().authority.record.last_receipt.activity_id == GameFlow.CINDER_PATROL_REWARD_ACTIVITY_ID,
		"a genuine later patrol owns the unrelated latest reward receipt")
	_check(fresh.reset_active_activity(), "the genuine patrol resets before cargo adoption")
	var cargo_button := pending_hud.get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button
	cargo_button.pressed.emit()
	fresh.call("_on_cargo_delivery_owner_completed", paid_snapshot, paid_snapshot.accepted_receipt, owner.get_instance_id())
	_check(fresh.get_activity_integration_report().selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
		and owner.get_generation() == cargo_idle_generation and _cargo_receipts(fresh) == 2,
		"ordinary cargo adoption and stale inactive completion preserve acknowledged credit after a different latest receipt")
	await _clean_up(fresh)

	var last_filesystem := InterruptedRewardFilesystem.new()
	last_filesystem.interrupt_rewards = false
	var last := await _make_disk_game(path, last_filesystem)
	var last_report := last.get_activity_integration_report()
	_check(last.cargo_delivery_activity.get_generation() == cargo_idle_generation
		and last.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
		and _manifest_quantity(last_report.cargo_source_manifest) == 2 and _manifest_quantity(last_report.cargo_destination_manifest) == 4
		and _cargo_receipts(last) == 2,
		"fresh Main retains the accepted cargo reset floor and remaining conserved kits after unrelated receipts")
	# Startup retains the validated patrol owner too; its saved IDLE may be selected.
	(last.get_node("HUD").get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
	_prepare_cargo_sortie(last)
	var last_start := last.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
	_check(bool(last_start.accepted) and last.cargo_delivery_activity.get_generation() == cargo_idle_generation + 1
		and bool(last.call("_complete_cargo_delivery_on_return")) and _cargo_receipts(last) == 3,
		"restart then ordinary next delivery transfers the final actual kits and grants its new generation once")
	await _clean_up(last)
	await _test_cargo_fallback_refusal(active_primary, unpaid_backup, paid_primary, generation)


func _test_cargo_fallback_refusal(active: PackedByteArray, unpaid: PackedByteArray,
		paid: PackedByteArray, generation: int) -> void:
	for kind: String in ["active", "unpaid"]:
		var path := "user://jovian-fallback-%s-%d.json" % [kind, Time.get_ticks_usec()]
		var fallback := active if kind == "active" else unpaid
		var older: Dictionary = JSON.parse_string(fallback.get_string_from_utf8()).payload.jovian_cargo_session.activities[0]
		var newer: Dictionary = JSON.parse_string(paid.get_string_from_utf8()).payload.jovian_cargo_session.activities[0]
		_check(int(older.state) == (CargoDeliveryActivity.State.ACTIVE if kind == "active" else CargoDeliveryActivity.State.COMPLETED)
			and not older.reward_granted and newer.reward_granted and int(newer.generation) == generation,
			"fallback fixture retains genuine older %s and newer paid cargo documents" % kind)
		var writer := FileAccess.open(path + ".paid-witness", FileAccess.WRITE)
		writer.store_buffer(paid)
		writer.close()
		writer = FileAccess.open(path, FileAccess.WRITE)
		writer.store_string("corrupt newer paid Jovian primary")
		writer.close()
		writer = FileAccess.open(path + ".bak", FileAccess.WRITE)
		writer.store_buffer(fallback)
		writer.close()
		var preflight := Store.new(path) as UserDataStore
		_check(preflight.load().accepted and preflight.get_loaded_source() == &"backup",
			"the existing store selects and quarantines the genuinely corrupt cargo primary")
		var artifacts := _cargo_recovery_artifacts(path)
		_check(artifacts.get(path + ".recovery") == "corrupt newer paid Jovian primary".to_utf8_buffer(),
			"the original corrupt primary remains an exact recovery witness")
		for attempt in 2:
			var game := await _make_disk_game(path, UserDataFilesystem.new())
			var report := game.get_activity_integration_report()
			var shared := game.get("_runtime_settings_user_data_store") as UserDataStore
			_check(game.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
				and game.cargo_delivery_activity.get_generation() == 0
				and _manifest_quantity(report.cargo_source_manifest) == 6
				and _manifest_quantity(report.cargo_destination_manifest) == 0
				and (game.get("_owed_game_flow_activity_rewards") as Array).is_empty(),
				"fresh Main refuses %s fallback lifecycle, inventory and earned-debt adoption" % kind)
			var before := game.cargo_delivery_activity.capture_persistence_state()
			var before_race := game.cinder_race_session.capture_persistence_state()
			var race_restore := game.get_cinder_race_session_persistence_report().restore_status as Dictionary
			var before_receipts := _cargo_receipts(game)
			var selected := game.select_activity_kind(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY)
			var started := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
			var reset := game.reset_active_activity()
			var after_selection := game.get_activity_integration_report()
			# Recovery refuses the outgoing race too, leaving a generation-zero
			# placeholder. Selecting cargo is safe; starting it still needs flight.
			print("JOVIAN_FALLBACK_SELECTION_CONTRACT ", {"kind": kind, "attempt": attempt,
				"before": {"selected_kind": report.selected_activity_kind,
					"active_id": report.active_activity_id, "active_generation": report.active_generation,
					"race_state": before_race, "race_restore": race_restore, "cargo_state": before,
					"source_manifest": report.cargo_source_manifest, "destination_manifest": report.cargo_destination_manifest,
					"receipts": before_receipts},
				"selection": selected, "start": started, "reset": reset,
				"after": {"selected_kind": after_selection.selected_activity_kind,
					"active_id": after_selection.active_activity_id, "active_generation": after_selection.active_generation,
					"race_state": game.cinder_race_session.capture_persistence_state(),
					"cargo_state": game.cargo_delivery_activity.capture_persistence_state(),
					"source_manifest": after_selection.cargo_source_manifest,
					"destination_manifest": after_selection.cargo_destination_manifest,
					"receipts": _cargo_receipts(game), "owed_rewards": game.get("_owed_game_flow_activity_rewards"),
					"loaded_source": shared.get_loaded_source(), "artifacts_unchanged": _cargo_recovery_artifacts(path) == artifacts}})
			_check(report.active_activity_id == &"" and report.active_generation == 0
				and report.selected_activity_kind == GameFlow.ACTIVITY_KIND_TIMED_RACE
				and not bool(race_restore.accepted) and race_restore.reason == &"race_session_store_recovery_required"
				and bool(selected.accepted) and selected.reason == &"selected"
				and after_selection.selected_activity_kind == GameFlow.ACTIVITY_KIND_CARGO_DELIVERY
				and after_selection.active_activity_id == GameFlow.CARGO_DELIVERY_ACTIVITY_ID
				and after_selection.active_generation == 0
				and not bool(started.accepted) and started.reason == &"not_in_free_flight" and not reset
				and game.cinder_race_session.capture_persistence_state() == before_race
				and game.cargo_delivery_activity.capture_persistence_state() == before
				and _cargo_receipts(game) == before_receipts and shared.get_loaded_source() == &"backup"
				and after_selection.cargo_source_manifest == report.cargo_source_manifest
				and after_selection.cargo_destination_manifest == report.cargo_destination_manifest
				and (game.get("_owed_game_flow_activity_rewards") as Array).is_empty()
				and _cargo_recovery_artifacts(path) == artifacts,
				"ordinary cargo selection, Start and Reset cannot adopt fallback progress or publish a reset")
			var authority := game.get("_game_flow_reward_authority") as GameFlowRewardAuthority
			var payment := authority.commit({"activity_id": GameFlow.CARGO_DELIVERY_ACTIVITY_ID,
				"activity_generation": generation, "reward_id": GameFlowRewardAuthority.CARGO_REWARD_ID,
				"reward_authority": false, "granted": false})
			print("JOVIAN_FALLBACK_REFUSAL ", {"kind": kind, "attempt": attempt,
				"restored_state": game.cargo_delivery_activity.get_state(),
				"restore": game.get("_jovian_cargo_session_restore_status"),
				"selection": selected, "start": started, "reset": reset, "payment": payment, "source": shared.get_loaded_source()})
			_check(not payment.accepted and payment.reason == &"reward_store_recovery_required"
				and game.cargo_delivery_activity.capture_persistence_state() == before
				and _cargo_receipts(game) == before_receipts and shared.get_loaded_source() == &"backup"
				and _cargo_recovery_artifacts(path) == artifacts,
				"direct cargo payment refuses %s fallback across fresh Main without changing artifacts" % kind)
			await _clean_up(game)
			_check(_cargo_recovery_artifacts(path) == artifacts,
				"cargo owner teardown preserves fallback and quarantine bytes for explicit recovery")


func _cargo_recovery_artifacts(path: String) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".bak.1", ".bak.2", ".bak.3", ".recovery", ".tmp", ".paid-witness"]:
		if FileAccess.file_exists(path + suffix):
			result[path + suffix] = FileAccess.get_file_as_bytes(path + suffix)
	return result


func _test_unsaved_cargo_reset_recovery() -> void:
	for terminal_kind: String in ["failed", "expired", "active_abort"]:
		var path := "user://jovian-unsaved-%s-session.json" % terminal_kind
		var filesystem := InterruptedRewardFilesystem.new()
		filesystem.interrupt_rewards = false
		var game := await _make_disk_game(path, filesystem)
		(game.get_node("HUD").get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
		_prepare_cargo_sortie(game)
		var paid_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		_check(bool(paid_start.accepted) and bool(game.call("_complete_cargo_delivery_on_return"))
			and _cargo_receipts(game) == 1 and game.reset_active_activity(),
			"a genuine paid cargo run saves reset IDLE before the unsaved %s run" % terminal_kind)
		var owner := game.cargo_delivery_activity
		var idle_generation := owner.get_generation()
		var idle_bytes := FileAccess.get_file_as_bytes(path)
		filesystem.reject_writes = true
		_prepare_cargo_sortie(game)
		var next_start := game.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		if terminal_kind == "failed":
			game.call("_fail_active_activity", &"ship_destroyed")
		elif terminal_kind == "expired":
			owner.advance_physics(180.0, owner.get_generation())
		var before := owner.capture_persistence_state()
		var before_inventory := game.cargo_transfer_authority.to_dictionary()
		var reset_events := {"count": 0}
		owner.activity_reset.connect(func(_snapshot: Dictionary) -> void: reset_events.count += 1)
		var expected_state := CargoDeliveryActivity.State.ACTIVE
		if terminal_kind == "failed":
			expected_state = CargoDeliveryActivity.State.FAILED
		elif terminal_kind == "expired":
			expected_state = CargoDeliveryActivity.State.EXPIRED
		_check(bool(next_start.accepted) and owner.get_generation() == idle_generation + 1
			and owner.get_state() == expected_state
			and not game.reset_active_activity() and game.cargo_delivery_activity == owner
			and owner.capture_persistence_state() == before and game.cargo_transfer_authority.to_dictionary() == before_inventory
			and FileAccess.get_file_as_bytes(path) == idle_bytes and int(reset_events.count) == 0 and _cargo_receipts(game) == 1,
			"rejected unsaved %s reset retains exact live owner, conserved inventory, bytes and lifecycle" % terminal_kind)
		filesystem.reject_writes = false
		if terminal_kind == "active_abort":
			var discarded := {"candidate": null}
			owner.reset_with_persistence(owner.get_generation(), func(candidate: CargoDeliveryActivity) -> Dictionary:
				discarded.candidate = candidate
				return {"accepted": false, "reason": &"reset_discarded"})
			var replay := (game.get("_jovian_cargo_session_persistence") as JovianCargoSessionPersistence).save(
				discarded.candidate, game.cargo_transfer_authority, "jovian-discarded-reset", owner)
			_check(not bool(replay.accepted) and replay.reason == &"unproven_jovian_generation"
				and owner.capture_persistence_state() == before and int(reset_events.count) == 0
				and FileAccess.get_file_as_bytes(path) == idle_bytes,
				"a genuine discarded scratch cannot replay a generation jump outside its owner handoff")
		var reset := game.reset_active_activity()
		_check(reset and owner.get_state() == CargoDeliveryActivity.State.IDLE and owner.get_generation() == idle_generation + 2
			and int(reset_events.count) == 1 and _cargo_receipts(game) == 1,
			"ordinary reset recovers the actual unsaved %s run without skipping owner generations (%s)" % [terminal_kind,
			(game.get("_jovian_cargo_session_save_status") as Dictionary).get("reason", "")])
		await _clean_up(game)
		if not reset:
			continue
		var fresh_filesystem := InterruptedRewardFilesystem.new()
		fresh_filesystem.interrupt_rewards = false
		var fresh := await _make_disk_game(path, fresh_filesystem)
		var restored := fresh.get_activity_integration_report()
		_check(fresh.cargo_delivery_activity.get_state() == CargoDeliveryActivity.State.IDLE
			and fresh.cargo_delivery_activity.get_generation() == idle_generation + 2
			and _manifest_quantity(restored.cargo_source_manifest) == 4 and _manifest_quantity(restored.cargo_destination_manifest) == 2
			and _cargo_receipts(fresh) == 1,
			"fresh Main retains the recovered %s reset generation and untransferred kits" % terminal_kind)
		(fresh.get_node("HUD").get("_activity_selection_buttons").get(GameFlow.ACTIVITY_KIND_CARGO_DELIVERY) as Button).pressed.emit()
		_prepare_cargo_sortie(fresh)
		var restarted := fresh.request_activity_start(GameFlow.CARGO_DELIVERY_ACTIVITY_ID)
		_check(bool(restarted.accepted) and fresh.cargo_delivery_activity.get_generation() == idle_generation + 3
			and bool(fresh.call("_complete_cargo_delivery_on_return")) and _cargo_receipts(fresh) == 2,
			"the next genuine delivery after recovered %s reset transfers remaining kits and pays its distinct identity once" % terminal_kind)
		await _clean_up(fresh)


func _find_ship(game: GameFlow, ship_id: StringName) -> HeroShip:
	for candidate: HeroShip in game.get_flyable_ships():
		if candidate.get_ship_id() == ship_id:
			return candidate
	return null


func _manifest_quantity(manifest: Dictionary) -> int:
	for raw_entry: Variant in manifest.get("entries", []) as Array:
		var entry := raw_entry as Dictionary
		if entry.get("item_id", &"") == &"fabrication_kits":
			return int(entry.get("quantity", 0))
	return 0


func _wait_until(predicate: Callable, maximum_physics_frames: int) -> bool:
	for _frame in maximum_physics_frames:
		if bool(predicate.call()):
			return true
		await physics_frame
	return bool(predicate.call())


func _clean_up(game: GameFlow) -> void:
	paused = false
	game.set("_piloting", false)
	game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _find_minimap_marker(markers: Array, marker_id: StringName) -> Dictionary:
	for marker_variant in markers:
		if marker_variant is Dictionary \
				and marker_variant.get("id", &"") == marker_id:
			return (marker_variant as Dictionary).duplicate(true)
	return {}


func _finish() -> void:
	print("CARGO_DELIVERY_PRODUCTION_INTEGRATION_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CARGO_DELIVERY_PRODUCTION_INTEGRATION_TEST_OK")
		quit(0)
	else:
		print(
			"CARGO_DELIVERY_PRODUCTION_INTEGRATION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
