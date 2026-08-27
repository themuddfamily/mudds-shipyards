extends SceneTree

## Four real Forward+ cabin frames of the retained Halyard status panel.  The
## capture drives only its presentation input so it cannot alter crew, command,
## repair, or network authority while showing the full text-token vocabulary.

const OUTPUT_DIRECTORY := "res://artifacts/halyard_crew_status_display"
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
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
	var states := [
		{"name": "detached", "snapshot": _snapshot(false, false, false, false, false, {})},
		{"name": "open", "snapshot": _snapshot(true, false, false, false, false, {})},
		{
			"name": "active_ack",
			"snapshot": _snapshot(true, true, false, true, false, {
				"previous_role": &"passenger",
				"new_role": &"pilot",
				"ready": true,
				"neutral_command_confirmed": true,
			}),
		},
		{"name": "fault", "snapshot": _snapshot(true, true, false, true, false, {})},
	]
	for state_variant in states:
		var state := state_variant as Dictionary
		if state.get("name", "") == "fault":
			display.present_engineer_repair_snapshot(_repair_fault_envelope(
				int(display.get_repair_presentation_snapshot().get("generation", 0))
			))
		else:
			display.begin_repair_generation(int(display.get_repair_presentation_snapshot().get("generation", 0)) + 1)
		display.present_crew_snapshot(state.get("snapshot", {}) as Dictionary)
		for _frame in 8:
			await process_frame
			await physics_frame
		var image := viewport.get_texture().get_image()
		var output_path := "%s/%s.png" % [OUTPUT_DIRECTORY, state.get("name", "unknown")]
		if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
			push_error("failed to save Halyard status capture: %s" % output_path)
			quit(1)
			return
	print("HALYARD_CREW_STATUS_DISPLAY_CAPTURE_OK: %s" % OUTPUT_DIRECTORY)
	quit(0)


func _snapshot(
		linked: bool, pilot: bool, gunner: bool, engineer: bool, passenger: bool, handoff: Dictionary
) -> Dictionary:
	return {
		"authority_attached": linked,
		"role_occupancy": {
			&"pilot": [{}] if pilot else [],
			&"gunner": [{}] if gunner else [],
			&"engineer": [{}] if engineer else [],
			&"passenger": [{}] if passenger else [],
		},
		"departure_readiness": {
			"pilot_present": pilot,
			"ready": pilot,
			"optional_crew_count": int(gunner) + int(engineer) + int(passenger),
		},
		"power_routing": {"engineer": {"channel": &"mobility_multiplier" if engineer else &"none"}},
		"emergency_pilot_handoff": handoff.duplicate(true),
	}.duplicate(true)


func _repair_fault_envelope(generation: int) -> Dictionary:
	var repair := {
		"status": &"interrupted",
		"reason": &"role_released",
		"component_id": &"engine_bay",
		"component_generation": 1,
		"progress": 0.58,
		"cooldown_remaining": 0.0,
	}
	return {
		"generation": generation,
		"sequence": 1,
		"repair_snapshot": {
			"repair": repair,
			"owner": {"seat_id": &"crew_port_01", "occupant_peer_id": 77},
			"presentation_only": true,
		},
	}.duplicate(true)
