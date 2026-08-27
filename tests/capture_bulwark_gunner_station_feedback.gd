extends SceneTree

## Native Forward+ witness for the production Bulwark gunner console. Each
## frame advances the existing public crew roster or gunner receipt lifecycle;
## this harness adds no substitute station or authority.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const LiveCombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const RESOLUTION := Vector2i(1280, 720)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus" \
			and DisplayServer.get_name() == "X11" \
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device"
	)
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	var craft := BULWARK_SCENE.instantiate() as HeroShip
	stage.add_child(craft)
	var camera := Camera3D.new()
	camera.position = Vector3(2.35, 2.6, -1.7)
	camera.fov = 38.0
	camera.near = 0.05
	camera.far = 80.0
	stage.add_child(camera)
	camera.look_at(Vector3(2.35, 2.3, -0.45), Vector3.UP)
	camera.current = true
	await process_frame
	craft.set_canopy_open(true, 0.0)
	_isolate_cockpit(craft)
	await _capture("detached")

	var authority := _build_authority()
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "public role roster attaches")
	var combat := LiveCombatAuthority.new()
	stage.add_child(combat)
	_check(bool(craft.attach_gunner_combat_authority(combat).get("accepted", false)), "shared combat authority attaches")
	await _capture("available")
	_check(bool(authority.claim(1, 88, &"capture_gunner", &"gunner_station", Authority.ROLE_GUNNER, 1).get("accepted", false)), "gunner is claimed")
	await _capture("claimed")
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	craft.call("submit_crew_intent", 1, 88, &"capture_gunner", Authority.ACTION_GUNNER_FIRE, {
		"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID, "target_id": &"capture_target", "trigger": false, "target_generation": 1,
	}, 2)
	await _capture("armed")
	craft.call("submit_crew_intent", 1, 88, &"capture_gunner", Authority.ACTION_GUNNER_FIRE, {
		"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID, "target_id": &"capture_target", "trigger": true, "target_generation": 1,
	}, 3)
	await _capture("active")
	_check(bool(craft.release_crew_role(1, 88, &"capture_gunner", &"gunner_station", 4).get("accepted", false)), "gunner releases")
	await _capture("released")

	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BULWARK_GUNNER_STATION_CAPTURE_OK: 6 Forward+ roster-state frames")
		quit(0)
	for failure in _failures:
		push_error(failure)
	quit(1)


func _build_authority() -> CrewSeatRoleAuthority:
	var authority := Authority.new(1)
	for seat in [[&"pilot_station", Authority.ROLE_PILOT], [&"gunner_station", Authority.ROLE_GUNNER], [&"passenger_slot", Authority.ROLE_PASSENGER], [&"engineer_slot", Authority.ROLE_ENGINEER]]:
		authority.register_seat(seat[0], &"bulwark_heavy_gunship", seat[1], &"bulwark_flight_deck", 1, &"gunner_station_anchor" if seat[0] == &"gunner_station" else &"")
	authority.seal_roster()
	return authority


func _add_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05090e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ea0b2")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("fff3df")
	key_light.light_energy = 1.7
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-52.0, 22.0, 0.0)
	stage.add_child(key_light)


func _isolate_cockpit(craft: HeroShip) -> void:
	var visual := craft.get_node_or_null(^"BulwarkHeavyGunshipVisual") as Node3D
	var cockpit := visual.get_node_or_null(^"CockpitInterior") as Node3D if visual != null else null
	var gunner_station := visual.get_node_or_null(^"GunnerStation") as Node3D if visual != null else null
	if visual == null or cockpit == null:
		return
	for child in visual.get_children():
		if child is Node3D and child != cockpit and child != gunner_station:
			(child as Node3D).visible = false


func _capture(state: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s frame renders" % state)
	if image == null or image.is_empty():
		return
	var directory := OS.get_environment("BULWARK_GUNNER_CAPTURE_DIR")
	if directory.is_empty():
		directory = "/tmp/bulwark_gunner_station_feedback"
	DirAccess.make_dir_recursive_absolute(directory)
	_check(image.save_png(directory.path_join("%s.png" % state)) == OK, "%s frame saves" % state)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append("FAIL: " + message)
