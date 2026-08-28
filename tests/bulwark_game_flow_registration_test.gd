extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")


class IsolatedFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes,
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path) or files.has(to_path):
			return ERR_FILE_NOT_FOUND if not files.has(from_path) else ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var capture_path := OS.get_environment("MUDDS_BULWARK_MAIN_CAPTURE")
	if not capture_path.is_empty():
		root.size = Vector2i(1600, 900)
		root.content_scale_size = Vector2i.ZERO
		root.msaa_3d = Viewport.MSAA_2X
		root.use_taa = true
	var flow := MAIN_SCENE.instantiate() as GameFlow
	var bulwark := flow.get_node("BulwarkHeavyGunship") as HeroShip
	var filesystem := IsolatedFilesystem.new()
	var store := Store.new("memory://bulwark-game-flow-registration.json", filesystem)
	var settings := Settings.new("memory://bulwark-game-flow-registration.cfg")
	_check(bool(store.load().get("accepted", false)), "isolated settings store opens empty")
	_check(
		bool(store.commit({Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "fixture").get("accepted", false)),
		"isolated settings fixture publishes a validated payload"
	)
	_check(
		flow.configure_runtime_settings_persistence(
			store, "memory://bulwark-game-flow-registration.cfg"
		),
		"GameFlow accepts isolated settings before startup"
	)
	root.add_child(flow)
	await process_frame
	await process_frame
	await process_frame
	var roster_audit := await _await_settled_roster(flow)

	var definition := bulwark.get_ship_definition()
	var clearance: Dictionary = bulwark.get_berth_clearance_report()
	var rig := bulwark.get_ship_audio_rig()
	var registered := flow.get_flyable_ships()
	var authority := flow.get_combat_authority() as LiveCombatAuthority
	var world := flow.get_node("ShipyardWorld")
	var berth := world.get_berth_node(&"bulwark_fleet_dock_berth") as ShipBerth
	_check(definition != null and definition.is_definition_valid(), "exact Bulwark production scene exposes a valid ShipDefinition")
	_check(definition != null and definition.audio_profile_id == &"bulwark_heavy_gunship", "Bulwark definition retains its exact audio profile identity")
	_check(rig != null and rig.get_profile_id() == &"bulwark_heavy_gunship", "Bulwark rig builds the definition's exact audio profile")
	_check(rig != null and bool(rig.get_audit_report().get("valid", false)), "Bulwark ship-local audio rig passes its public audit")
	_check(registered.has(bulwark), "public GameFlow flyable roster accepts the exact Bulwark production scene")
	_check(registered.count(bulwark) == 1, "public GameFlow flyable roster registers Bulwark exactly once")
	_check(
		flow.find_children("BulwarkHeavyGunship", "", false, false).size() == 1,
		"Main retains exactly one direct Bulwark production scene child"
	)
	_check(
		berth != null and berth.get_occupant() == bulwark,
		"public GameFlow registration occupies Bulwark at Dock03"
	)
	_check(
		berth != null and bulwark.global_transform.is_equal_approx(berth.get_dock_transform()),
		"Bulwark uses the authoritative Dock03 transform without a duplicate scene transform"
	)
	_check(
		clearance.get("home_berth_id", &"") == &"bulwark_fleet_dock_berth"
		and clearance.get("dock_role", &"") == &"fleet_dock_03"
		and clearance.get("flight_collision_bounds", AABB())
			== AABB(Vector3(-5.8, -0.2, -5.3), Vector3(11.6, 3.1, 10.8))
		and bool(clearance.get("physical_boarding_contract", false)),
		"retention preserves Bulwark's exact flight collision and physical boarding envelope"
	)
	_check(authority.get_source_id(bulwark) == 1107, "Bulwark owns stable combat source 1107")
	var cinder: HeroShip
	for craft in registered:
		if craft.get_ship_id() == &"cinder-long-range-bomber":
			cinder = craft
			break
	_check(cinder != null and authority.get_source_id(cinder) == 1106, "Cinder bomber retains stable combat source 1106")
	var pilot_profile := authority.get_weapon_profile(
		bulwark, GameFlow.BULWARK_COMBAT_WEAPON_ID
	)
	var gunner_profile := authority.get_weapon_profile(
		bulwark, GameFlow.BULWARK_CREW_WEAPON_ID
	)
	_check(
		pilot_profile == {"range": 360.0, "damage": 50.0, "origin_tolerance": 24.0},
		"Bulwark pilot owns the authored 360m/50/24m sustained-pulse envelope"
	)
	_check(not gunner_profile.is_empty(), "Bulwark keeps the siege-lance gunner profile on source 1107")
	var attach := bulwark.call("attach_gunner_combat_authority", authority) as Dictionary
	_check(bool(attach.get("accepted", false)), "gunner attaches to the already-complete shared source")
	_check(
		authority.get_weapon_profile(bulwark, GameFlow.BULWARK_COMBAT_WEAPON_ID) == pilot_profile,
		"gunner attach never replaces the pilot weapon dictionary"
	)
	_check(
		bool(roster_audit.get("valid", false))
		and int(roster_audit.get("expected_player_source_count", 0)) == 7
		and int(roster_audit.get("expected_source_count", 0)) == 11
		and int(roster_audit.get("actual_source_count", 0)) == 11,
		"settled public roster contains seven player sources and eleven exact total sources"
	)
	if not capture_path.is_empty():
		await _capture_main_dock03_boarding_hud(flow, bulwark, capture_path)

	flow.queue_free()
	for _cleanup_frame in 10:
		await process_frame
	if _failures.is_empty():
		print("BULWARK_GAME_FLOW_REGISTRATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _await_settled_roster(flow: GameFlow) -> Dictionary:
	var audit: Dictionary = {}
	for _attempt in 120:
		audit = flow.get_live_combat_source_roster_audit()
		if bool(audit.get("valid", false)) \
				and int(audit.get("expected_player_source_count", 0)) == 7 \
				and int(audit.get("expected_source_count", 0)) == 11 \
				and int(audit.get("actual_source_count", 0)) == 11:
			return audit
		await process_frame
	return audit


func _capture_main_dock03_boarding_hud(
	flow: GameFlow, bulwark: HeroShip, output_path: String
) -> void:
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
		and DisplayServer.get_name() == "X11"
		and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a display-backed X11 Forward+ rendering device"
	)
	var begin_event := InputEventAction.new()
	begin_event.action = &"interact"
	begin_event.pressed = true
	Input.parse_input_event(begin_event)
	await process_frame
	begin_event.pressed = false
	Input.parse_input_event(begin_event)
	for _frame in 180:
		if flow.phase == GameFlow.Phase.APPROACH_SHIP:
			break
		await process_frame
	var player := flow.get_node("Player") as PlayerController
	var boarding_position := bulwark.get_boarding_position()
	var player_position := boarding_position + bulwark.global_basis * Vector3(2.0, 0.0, 0.0)
	player_position.y = 7.0
	var facing := (boarding_position - player_position).slide(Vector3.UP).normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(facing, Vector3.UP).orthonormalized(), player_position
	))
	for _frame in 12:
		await physics_frame
		await process_frame
	var interaction_panel := flow.hud.find_child("InteractionPanel", true, false) as Control
	var interaction_labels := (
		interaction_panel.find_children("*", "Label", true, false)
		if interaction_panel != null else []
	)
	var interaction_label := (
		interaction_labels[0] as Label if not interaction_labels.is_empty() else null
	)
	_check(
		flow.boarding_candidate == bulwark
		and interaction_panel != null and interaction_panel.visible
		and interaction_label != null and interaction_label.text.contains("BULWARK"),
		"public on-foot discovery presents the Bulwark boarding HUD at Dock03 (candidate=%s panel=%s text=%s player=%s boarding=%s)"
			% [
				flow.boarding_candidate.get_ship_id() if flow.boarding_candidate != null else &"none",
				interaction_panel.visible if interaction_panel != null else false,
				interaction_label.text if interaction_label != null else "missing",
				player.global_position,
				boarding_position,
			]
	)
	var camera := Camera3D.new()
	camera.name = "Dock03BoardingReviewCamera"
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 180.0
	flow.add_child(camera)
	var camera_position := boarding_position + bulwark.global_basis * Vector3(-24.0, 12.0, 28.0)
	camera.look_at_from_position(
		camera_position,
		bulwark.global_position + bulwark.global_basis * Vector3(0.0, 1.0, 0.0),
		Vector3.UP
	)
	camera.current = true
	for _frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_path) if image != null and not image.is_empty() else ERR_CANT_CREATE
	_check(
		image != null and not image.is_empty()
		and image.get_size() == Vector2i(1600, 900)
		and save_error == OK,
		"Main Dock03 boarding/HUD Forward+ frame saves (size=%s error=%s)"
			% [image.get_size() if image != null else Vector2i.ZERO, save_error]
	)
	print(
		"BULWARK_MAIN_DOCK03_CAPTURE: renderer=%s adapter=%s berth=%s source=%d output=%s"
		% [
			RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name(),
			bulwark.get_home_berth_id(),
			flow.get_combat_authority().get_source_id(bulwark),
			output_path,
		]
	)
	camera.queue_free()
