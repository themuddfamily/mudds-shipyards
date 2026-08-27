extends SceneTree

## Four actual-roster Forward+ review frames. The production cabin sign and the
## retained HUD card are driven through the existing Cinder role/manifest seam;
## this harness adds only a camera and neutral review environment.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const BindingType := preload("res://scripts/ui/cinder_loadmaster_hud_binding.gd")
const OUTPUT_DIR := "res://artifacts/cinder_loadmaster_roster_states"
const RESOLUTION := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a live X11 Vulkan Forward+ renderer"
	)
	var stage := Node3D.new()
	root.add_child(stage)
	_build_environment(stage)
	var craft := Hauler.new() as CinderCargoHauler
	stage.add_child(craft)
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.call(&"_begin")
	await create_timer(0.4).timeout
	# The HUD's retained card is asserted below; the four render frames keep the
	# camera on the paired production cabin sign so its text remains reviewable.
	hud.visible = false
	await physics_frame
	var camera := Camera3D.new()
	camera.fov = 34.0
	camera.near = 0.05
	camera.far = 40.0
	camera.position = Vector3(-0.15, 0.43, -0.75)
	stage.add_child(camera)
	camera.look_at(Vector3(-0.15, 0.43, -2.28), Vector3.UP)
	camera.current = true
	var authority := Authority.new(1)
	for seat_record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		_check(bool(authority.register_seat(StringName(seat_record[0]), Hauler.COMPONENT_ID, StringName(seat_record[1]), &"cinder_cargo_walkable_interior", 1, StringName(seat_record[0])).get("accepted", false)), "actual Cinder roster registers %s" % seat_record[0])
	_check(bool(authority.seal_roster().get("accepted", false)), "actual Cinder roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "actual Cinder authority attaches")
	var binding := BindingType.new()
	_check(bool(binding.attach(craft, hud).get("accepted", false)), "production HUD binding attaches")
	_check(bool(authority.claim(1, 91, &"capture_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).get("accepted", false)), "actual loadmaster claims station")
	# A rebind is presentation-only; it publishes the real occupied roster state.
	craft.refresh_loadmaster_status_display()
	binding.detach()
	_check(bool(binding.attach(craft, hud).get("accepted", false)), "loading state republishes through binding")
	await _capture(hud, "01_loading.png", "[>] LOADING")
	var blocked := craft.submit_crew_intent(1, 91, &"capture_loadmaster", RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST, {"manifest_id": &"capture_manifest", "route_id": &"dock_04_cargo", "ready": false}, 2)
	_check(bool(blocked.get("consumed", false)), "actual blocked receipt is admitted")
	await _capture(hud, "02_blocked.png", "[!] BLOCKED")
	var secured := craft.submit_crew_intent(1, 91, &"capture_loadmaster", RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST, {"manifest_id": &"capture_manifest", "route_id": &"dock_04_cargo", "ready": true}, 3)
	_check(bool(secured.get("consumed", false)), "actual ready receipt is admitted")
	await _capture(hud, "03_secured.png", "[=] SECURED")
	_check(bool(craft.release_crew_role(1, 91, &"capture_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, 4, 1).get("accepted", false)), "actual loadmaster releases station")
	await _capture(hud, "04_detached.png", "[/] DETACHED")
	binding.detach()
	craft.queue_free()
	hud.queue_free()
	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_LOADMASTER_ROSTER_CAPTURE_OK: ", OUTPUT_DIR)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture(hud: Node, filename: String, expected_roster_text: String) -> void:
	var detail := hud.get("_runtime_status_detail") as Label
	_check(detail != null and detail.text.contains(expected_roster_text), "%s roster text is visible without colour" % filename)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty() and image.get_size() == RESOLUTION, "%s is a non-empty 1600x900 frame" % filename)
	if image != null and not image.is_empty():
		var absolute := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(filename))
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		_check(image.save_png(absolute) == OK, "%s saves" % filename)


func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061019")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7894a5")
	environment.ambient_light_energy = 0.38
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_energy = 1.2
	stage.add_child(key_light)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
