extends SceneTree

## Four real Forward+ cabin frames of the retained Halyard status panel. The
## capture uses the production crew-role APIs so the released frame cannot
## retain an engineer selection, route, repair lifecycle, or owner.

const OUTPUT_DIRECTORY := "res://artifacts/halyard_crew_status_display"
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var retired_fault_path := ProjectSettings.globalize_path("%s/fault.png" % OUTPUT_DIRECTORY)
	if FileAccess.file_exists(retired_fault_path):
		DirAccess.remove_absolute(retired_fault_path)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("07111d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8c8c3")
	settings.ambient_light_energy = 0.32
	environment.environment = settings
	world.add_child(environment)
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	world.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame
	var display := craft.get_crew_status_display()
	var readout := display.get_node_or_null(^"CrewStatusReadout") as Label3D
	if readout == null:
		push_error("Halyard crew status readout unavailable")
		quit(1)
		return
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.fov = 52.0
	camera.current = true
	world.add_child(camera)
	camera.global_position = readout.global_position + Vector3(0.0, 0.05, 2.20)
	camera.look_at(readout.global_position + Vector3(0.0, 0.05, 0.0), Vector3.UP)
	if not await _capture_frame(viewport, "detached"):
		return

	var authority := Authority.new(1)
	if not _accepted(authority.register_halyard_roster()) \
			or not _accepted(craft.attach_crew_role_authority(authority)):
		_capture_failed("failed to attach the production Halyard crew authority")
		return
	if not await _capture_frame(viewport, "open"):
		return

	if not _accepted(authority.claim(
		1, 77, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1
	)) or not _accepted(authority.claim(
		1, 73, &"passenger_avatar", &"crew_port_00", Authority.ROLE_PASSENGER, 1
	)):
		_capture_failed("failed to admit the active capture crew")
		return
	var passenger := CharacterBody3D.new()
	passenger.name = "capture_passenger_avatar"
	world.add_child(passenger)
	passenger.global_position = craft.global_position + Vector3(0.0, 1.0, -1.0)
	await process_frame
	if not _accepted(craft.attach_crew_role_occupant(
		73, &"passenger_avatar", &"crew_port_00", passenger
	)):
		_capture_failed("failed to attach the active capture passenger")
		return
	var model = craft.get_component_damage()
	model.record_damage(70.0, Vector3(0.0, 2.88, 0.325))
	var system_id := ShipComponentDamageType.COMPONENT_ENGINE_BAY
	if model.get_component_integrity(system_id) >= 1.0:
		_capture_failed("failed to damage the Halyard engine bay for the active repair frame")
		return
	craft.set("_landed", true)
	var repair := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.5, "system_generation": 1},
		2
	)
	if not bool(repair.get("consumed", false)):
		_capture_failed("failed to begin the production engineer repair")
		return
	var handoff := craft.request_emergency_pilot_handoff(
		1, 73, &"passenger_avatar", &"crew_port_00", 2, 3, passenger, 1
	)
	if not _accepted(handoff):
		_capture_failed("failed to complete the production emergency pilot handoff")
		return
	if not await _capture_frame(viewport, "active_ack"):
		return

	var release := craft.release_crew_role(
		1, 77, &"engineer_avatar", &"crew_port_01", 3, 1
	)
	var released_gameplay := craft.get_crew_role_gameplay_snapshot()
	var released_network := craft.get_engineer_repair_network_snapshot()
	if not _accepted(release) \
			or not ((released_gameplay.get("selected_targets", {}) as Dictionary).get("engineer", {}) as Dictionary).is_empty() \
			or not ((released_network.get("owner", {}) as Dictionary).is_empty()) \
			or not display.get_readout_text().contains("E [OPEN]") \
			or not display.get_readout_text().contains("ENG ROUTE [NONE]") \
			or not display.get_readout_text().contains("REPAIR [READY // IDLE // REPAIR READY]"):
		_capture_failed("production engineer release retained selection, route, owner, or display lifecycle")
		return
	if not await _capture_frame(viewport, "released"):
		return
	print("HALYARD_CREW_STATUS_DISPLAY_CAPTURE_OK: %s" % OUTPUT_DIRECTORY)
	quit(0)


func _capture_frame(viewport: SubViewport, state_name: String) -> bool:
	for _frame in 8:
		await process_frame
		await physics_frame
	var output_path := "%s/%s.png" % [OUTPUT_DIRECTORY, state_name]
	if viewport.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(output_path)
	) != OK:
		_capture_failed("failed to save Halyard status capture: %s" % output_path)
		return false
	return true


func _accepted(result: Dictionary) -> bool:
	return bool(result.get("accepted", false))


func _capture_failed(message: String) -> void:
	push_error(message)
	quit(1)
