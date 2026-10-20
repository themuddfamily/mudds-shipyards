extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")


class FakeFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		return {
			"error": OK,
			"bytes": (files[path] as PackedByteArray).duplicate(),
		} if files.has(path) else {
			"error": ERR_FILE_NOT_FOUND,
			"bytes": PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


class MutableInputProvider extends RefCounted:
	var strength := 0.0
	var pressed := false

	func get_action_strength(action: StringName) -> float:
		return strength if action == &"sprint_boost" else 0.0

	func is_action_pressed(action: StringName) -> bool:
		return pressed if action == &"sprint_boost" else false

	func set_boost(is_pressed: bool) -> void:
		pressed = is_pressed
		strength = 1.0 if is_pressed else 0.0


var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var filesystem := FakeFilesystem.new()
	var store := Store.new("memory://sprint-toggle-reentry.json", filesystem)
	var seeded := Settings.new("memory://sprint-toggle-reentry-legacy.cfg")
	var profile := seeded.get_input_binding_profile()
	_check(
		profile.set_action_options(&"sprint_boost", {
			"deadzone": 0.0,
			"curve": Profile.CURVE_LINEAR,
			"hold_mode": Profile.TOGGLE,
		}) and seeded.set_input_binding_profile(profile),
		"fixture authors a valid persisted sprint toggle",
	)
	_check(bool(store.load().accepted), "isolated settings store opens")
	_check(
		bool(store.commit({
			Adapter.SETTINGS_PAYLOAD_KEY: seeded.to_user_data_payload(),
		}, 0, "sprint-toggle-fixture").accepted),
		"toggle profile is persisted before production startup",
	)

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(
		game.configure_runtime_settings_persistence(
			store,
			"memory://sprint-toggle-reentry-legacy.cfg",
		),
		"production GameFlow accepts the isolated settings authority",
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var source := game.get_flyable_ships()[0].get_local_input_source()
	var source_id := source.get_instance_id()
	var player := game.get_node(^"Player") as PlayerController
	var player_id := player.get_instance_id()
	var provider := MutableInputProvider.new()
	source.set_input_provider(provider)
	source.next_command(1000)

	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	_check(
		game.get_flyable_ships()[0].get_local_input_source().get_instance_id() == source_id
		and source.get_input_binding_profile().get_action_options(&"sprint_boost").hold_mode
		== Profile.TOGGLE,
		"retained GameFlow re-entry keeps the production source and persisted toggle profile",
	)
	provider.set_boost(false)
	source.next_command(1001)
	provider.set_boost(true)
	var toggled_on := source.next_command(1002)
	provider.set_boost(false)
	var released := source.next_command(1003)
	provider.set_boost(true)
	var toggled_off := source.next_command(1004)
	_check(
		toggled_on.boost and released.boost and not toggled_off.boost,
		"after re-entry sprint boost latches across release and unlatches on the second press",
	)

	_check(
		game.get_node(^"Player").get_instance_id() == player_id,
		"retained GameFlow re-entry keeps the actual on-foot Player consumer",
	)
	# This is a synthetic Input-action consumer probe, not a physical-device
	# or ordinary station traversal claim. The saved profile above is applied
	# only through production GameFlow startup/re-entry composition.
	Input.action_release(&"sprint_boost")
	player.set_control_enabled(true)
	player._sample_sprint_held()
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "actual on-foot Player accepts the sprint press")
	Input.action_release(&"sprint_boost")
	_check(
		player._sample_sprint_held(),
		"actual retained on-foot Player keeps persisted TOGGLE sprint active after release",
	)
	player.set_control_enabled(false)
	await _test_player_sprint_contract(game, player)

	game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_SPRINT_TOGGLE_REENTRY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_player_sprint_contract(game: GameFlow, player: PlayerController) -> void:
	# Controlled source fixture: keep the actual retained Player and its normal
	# physics implementation, but stage it on an isolated flat collision slab.
	# Manual physics ticks avoid GameFlow gameplay routing; this does not prove
	# an ordinary station route, a physical input device, or native performance.
	game.set_physics_process(false)
	player.set_physics_process(false)
	player.set_camera_active(false)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = PhysicsLayers.WORLD
	floor_body.collision_mask = 0
	floor_body.position = Vector3(20000.0, 19999.5, 20000.0)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(128.0, 1.0, 128.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(20000.0, 20000.05, 20000.0)))
	player.set_control_enabled(true)
	await _step_player(player, 20)
	_check(player.is_on_floor(), "controlled actual Player physics fixture has real floor support")

	Input.action_press(&"move_forward")
	Input.action_press(&"sprint_boost")
	await _step_player(player, 20)
	_check(_at_speed(player, player.sprint_speed), "saved TOGGLE press reaches actual Player physics sprint speed")
	Input.action_release(&"sprint_boost")
	await _step_player(player, 3)
	_check(_at_speed(player, player.sprint_speed), "saved TOGGLE release retains actual Player physics sprint speed")
	Input.action_press(&"sprint_boost")
	await _step_player(player, 20)
	_check(_at_speed(player, player.walk_speed), "saved TOGGLE second press restores actual Player physics walking speed")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint_boost")
	player._sample_sprint_held()

	_set_sprint_mode(game, Profile.HOLD)
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "live HOLD profile accepts a held sprint press")
	Input.action_release(&"sprint_boost")
	_check(not player._sample_sprint_held(), "live HOLD profile stops sprint on release")
	Input.action_press(&"sprint_boost")
	player._sample_sprint_held()
	_set_sprint_mode(game, Profile.TOGGLE)
	_check(not player._sample_sprint_held(), "live TOGGLE replacement primes a held key without inventing a press")
	Input.action_release(&"sprint_boost")
	player._sample_sprint_held()
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "live TOGGLE replacement accepts the next fresh press")
	Input.action_release(&"sprint_boost")
	_check(player._sample_sprint_held(), "live TOGGLE replacement retains sprint on release")
	var reclaimed: Dictionary = game._apply_runtime_input_bindings_and_options()
	_check(
		bool(reclaimed.accepted) and int(reclaimed.source_count) == game.get_flyable_ships().size()
		and int(reclaimed.replaced_count) == 0 and player._sample_sprint_held(),
		"equal live profile reclaim preserves the local latch and existing fleet counts",
	)
	_set_sprint_mode(game, Profile.HOLD)
	_check(not player._sample_sprint_held(), "live HOLD replacement clears a released TOGGLE latch")
	_set_sprint_mode(game, Profile.TOGGLE)

	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "fresh TOGGLE press starts the control handoff fixture")
	player.set_control_enabled(false)
	_check(not player._sample_sprint_held(), "disabled local control cannot consume sprint input")
	player.set_control_enabled(true)
	_check(not player._sample_sprint_held(), "re-enabled local control clears latch and primes the still-held key")
	Input.action_release(&"sprint_boost")
	player._sample_sprint_held()
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "control handoff accepts sprint after release and a fresh press")

	# A retained actual Player exiting/re-entering its scene is a fresh intent
	# boundary even though its accepted settings and node identity survive.
	var player_parent := player.get_parent()
	var player_id := player.get_instance_id()
	player_parent.remove_child(player)
	_check(not player._sample_sprint_held(), "detached Player cannot consume local sprint input")
	player_parent.add_child(player)
	await process_frame
	_check(
		player.get_instance_id() == player_id and not player._sample_sprint_held(),
		"retained Player tree re-entry clears latch and primes the still-held key",
	)
	Input.action_release(&"sprint_boost")
	player._sample_sprint_held()
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "retained Player tree re-entry accepts a fresh sprint press")

	player.set_remote_drive_enabled(true)
	_check(not player._sample_sprint_held(), "remote takeover discards the local toggle and ignores the held local key")
	player.apply_remote_intent(Vector2.ZERO, 0.0, true, false)
	_check(player._sample_sprint_held(), "remote run intent remains authoritative under shared TOGGLE")
	player.apply_remote_intent(Vector2.ZERO, 0.0, false, false)
	_check(not player._sample_sprint_held(), "remote run false stops immediately without local toggle semantics")
	player.set_control_enabled(true)
	_check(not player.is_control_enabled(), "local enable cannot take control of a remote-driven Player")
	player.set_remote_drive_enabled(false)
	player.set_control_enabled(true)
	_check(not player._sample_sprint_held(), "remote-to-local handoff starts neutral despite a still-held sprint key")
	Input.action_release(&"sprint_boost")
	player._sample_sprint_held()
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "remote-to-local handoff accepts a fresh sprint press")
	Input.action_release(&"sprint_boost")
	_check(player._sample_sprint_held(), "local TOGGLE remains functional after remote handoff")

	game._on_settings_reset_requested()
	_check(
		game.runtime_settings.get_input_binding_profile().get_action_options(&"sprint_boost").hold_mode
		== Profile.HOLD and not player._sample_sprint_held(),
		"production settings reset restores default HOLD and clears the local latch",
	)
	Input.action_press(&"sprint_boost")
	_check(player._sample_sprint_held(), "default/reset HOLD accepts a held press")
	Input.action_release(&"sprint_boost")
	_check(not player._sample_sprint_held(), "default/reset HOLD stops sprint on release")
	player.set_control_enabled(false)
	floor_body.queue_free()
	await process_frame


func _set_sprint_mode(game: GameFlow, mode: StringName) -> void:
	var profile := game.runtime_settings.get_input_binding_profile()
	var options := profile.get_action_options(&"sprint_boost")
	options.hold_mode = mode
	_check(
		profile.set_action_options(&"sprint_boost", options)
		and game.runtime_settings.set_input_binding_profile(profile),
		"production RuntimeSettings accepts live sprint mode %s" % mode,
	)


func _step_player(player: PlayerController, frames: int) -> void:
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	for _frame in frames:
		await physics_frame
		player._physics_process(tick)


func _at_speed(player: PlayerController, expected: float) -> bool:
	return player.is_on_floor() and absf(player.velocity.slide(Vector3.UP).length() - expected) < 0.01


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
