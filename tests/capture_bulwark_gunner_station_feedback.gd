extends SceneTree

## Native Forward+ witness for the production Bulwark gunner console. Each
## frame advances the existing public crew roster or gunner receipt lifecycle;
## this harness adds no substitute station or authority.

const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Bulwark := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const LiveCombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const RESOLUTION := Vector2i(1280, 720)
const CAPTURE_STATES: Array[String] = [
	"detached", "available", "claimed", "armed", "active", "released",
]
const MINIMUM_VISIBLE_TEXT_PIXELS := 300

var _failures: Array[String] = []
var _camera: Camera3D
var _readout: Label3D
var _captured_images: Dictionary = {}
var _pixel_hashes: Dictionary = {}
var _text_hashes: Dictionary = {}


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
	var station_anchor := craft.call("get_gunner_station_anchor") as Marker3D
	_readout = craft.get_node_or_null(
		^"BulwarkHeavyGunshipVisual/GunnerStation/GunnerStatusReadout"
	) as Label3D
	_check(
		station_anchor != null
			and _readout != null
			and station_anchor.get_parent() == _readout.get_parent(),
		"production gunner station exposes one shared physical anchor/readout envelope"
	)
	_camera = Camera3D.new()
	_camera.name = "GunnerStationCaptureCamera"
	_camera.fov = 46.0
	_camera.near = 0.05
	_camera.far = 80.0
	stage.add_child(_camera)
	if station_anchor != null and _readout != null:
		# This is a seated head pose relative to the public station marker, with a
		# bounded downward look at the physical console rather than a camera staged
		# on the reverse/exterior side of its display.
		_camera.global_position = station_anchor.to_global(Vector3(0.0, 0.65, 0.18))
		_camera.look_at(_readout.global_position, craft.global_basis.y)
	_camera.current = true
	await process_frame
	craft.set_canopy_open(true, 0.0)
	_check(
		station_anchor != null
			and _camera.global_position.distance_to(station_anchor.global_position) < 0.72
			and _readout.global_basis.z.normalized().dot(
				(_camera.global_position - _readout.global_position).normalized()
			) > 0.9,
		"capture camera is a bounded reachable eye offset on the front side of the production marker"
	)
	await _capture(craft, "detached")

	var authority := _build_authority()
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "public role roster attaches")
	var combat := LiveCombatAuthority.new()
	stage.add_child(combat)
	_check(bool(craft.attach_gunner_combat_authority(combat).get("accepted", false)), "shared combat authority attaches")
	await _capture(craft, "available")
	_check(bool(authority.claim(1, 88, &"capture_gunner", &"gunner_station", Authority.ROLE_GUNNER, 1).get("accepted", false)), "gunner is claimed")
	await _capture(craft, "claimed")
	craft.set_piloted(true)
	_camera.current = true
	craft.request_engine_start()
	for _frame in 180:
		if StringName(craft.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE:
			break
		await physics_frame
	_check(
		StringName(craft.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE,
		"public engine-start lifecycle reaches ONLINE"
	)
	var armed := craft.call("submit_crew_intent", 1, 88, &"capture_gunner", Authority.ACTION_GUNNER_FIRE, {
		"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID, "target_id": &"capture_target", "trigger": false, "target_generation": 1,
	}, 2) as Dictionary
	_check(bool(armed.get("consumed", false)), "public gunner intent arms the retained station")
	await _capture(craft, "armed")
	var active := craft.call("submit_crew_intent", 1, 88, &"capture_gunner", Authority.ACTION_GUNNER_FIRE, {
		"weapon_id": Bulwark.BULWARK_CREW_WEAPON_ID, "target_id": &"capture_target", "trigger": true, "target_generation": 1,
	}, 3) as Dictionary
	_check(
		bool(active.get("consumed", false))
			and (active.get("effect", {}) as Dictionary).get("status", &"") == &"charge_started",
		"public gunner intent starts the ACTIVE charge"
	)
	await _capture(craft, "active")
	_check(bool(craft.release_crew_role(1, 88, &"capture_gunner", &"gunner_station", 4).get("accepted", false)), "gunner releases")
	await _capture(craft, "released")
	_validate_capture_set()

	stage.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("BULWARK_GUNNER_STATION_CAPTURE_OK: 6 unique visible Forward+ roster-state frames")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _build_authority() -> CrewSeatRoleAuthority:
	var authority := Authority.new(1)
	for seat in [[&"pilot_station", Authority.ROLE_PILOT], [&"gunner_station", Authority.ROLE_GUNNER], [&"passenger_slot", Authority.ROLE_PASSENGER], [&"engineer_slot", Authority.ROLE_ENGINEER]]:
		_check(
			bool(authority.register_seat(seat[0], &"bulwark_heavy_gunship", seat[1], &"bulwark_flight_deck", 1, &"gunner_station_anchor" if seat[0] == &"gunner_station" else &"").get("accepted", false)),
			"public capture seat registers: %s" % seat[0]
		)
	_check(bool(authority.seal_roster().get("accepted", false)), "public capture roster seals")
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


func _capture(craft: HeroShip, state: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var feedback := craft.call("get_gunner_station_feedback_snapshot") as Dictionary
	_check(
		feedback.get("roster_state", &"") == StringName(state)
			and _readout.text.contains("[%s]" % state.to_upper()),
		"%s frame comes from the exact public roster state" % state.to_upper()
	)
	_check(
		image != null
			and not image.is_empty()
			and image.get_size() == RESOLUTION,
		"%s frame renders a nonempty exact-size viewport" % state.to_upper()
	)
	if image == null or image.is_empty():
		return
	var region := _readout_screen_region(image)
	_check(region.size.x > 0 and region.size.y > 0, "%s readout projects fully onscreen" % state.to_upper())
	if region.size.x <= 0 or region.size.y <= 0:
		return
	var visible_crop := image.get_region(region)
	_text_hashes[state] = _readout.text.sha256_text()
	_pixel_hashes[state] = _image_hash(visible_crop)

	# A hidden-label comparison proves that the projected text really contributed
	# visible pixels; a hash or sentinel alone cannot pass this check.
	_readout.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden_image := root.get_texture().get_image()
	_readout.visible = true
	var changed_pixels := _different_pixel_count(
		visible_crop,
		hidden_image.get_region(region) if hidden_image != null and not hidden_image.is_empty() else Image.new()
	)
	_check(
		changed_pixels >= MINIMUM_VISIBLE_TEXT_PIXELS,
		"%s readout is front-facing and unoccluded (%d visible text pixels)" % [state.to_upper(), changed_pixels]
	)
	_captured_images[state] = image
	var directory := OS.get_environment("BULWARK_GUNNER_CAPTURE_DIR")
	if directory.is_empty():
		directory = "/tmp/bulwark_gunner_station_feedback"
	DirAccess.make_dir_recursive_absolute(directory)
	_check(image.save_png(directory.path_join("%s.png" % state)) == OK, "%s frame saves" % state.to_upper())


func _readout_screen_region(image: Image) -> Rect2i:
	if _camera == null or _readout == null or _camera.is_position_behind(_readout.global_position):
		return Rect2i()
	var bounds := _readout.get_aabb()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for endpoint_index in 8:
		var world_corner := _readout.global_transform * bounds.get_endpoint(endpoint_index)
		if _camera.is_position_behind(world_corner):
			return Rect2i()
		var screen_corner := _camera.unproject_position(world_corner)
		minimum = minimum.min(screen_corner)
		maximum = maximum.max(screen_corner)
	var margin := Vector2(10.0, 10.0)
	minimum = (minimum - margin).max(Vector2.ZERO)
	maximum = (maximum + margin).min(Vector2(image.get_size()))
	var origin := Vector2i(floori(minimum.x), floori(minimum.y))
	var end := Vector2i(ceili(maximum.x), ceili(maximum.y))
	return Rect2i(origin, end - origin)


func _different_pixel_count(first: Image, second: Image) -> int:
	if first == null or second == null or first.is_empty() or second.is_empty() \
			or first.get_size() != second.get_size():
		return 0
	var changed := 0
	for y in first.get_height():
		for x in first.get_width():
			var first_pixel := first.get_pixel(x, y)
			var second_pixel := second.get_pixel(x, y)
			if maxf(
				absf(first_pixel.r - second_pixel.r),
				maxf(absf(first_pixel.g - second_pixel.g), absf(first_pixel.b - second_pixel.b))
			) > 0.035:
				changed += 1
	return changed


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _validate_capture_set() -> void:
	_check(_captured_images.size() == CAPTURE_STATES.size(), "all six required nonempty frames were captured")
	_check(_text_hashes.size() == CAPTURE_STATES.size(), "all six visible text states were hashed")
	_check(_pixel_hashes.size() == CAPTURE_STATES.size(), "all six projected readout regions were hashed")
	var unique_text_hashes := {}
	var unique_pixel_hashes := {}
	for state in CAPTURE_STATES:
		unique_text_hashes[str(_text_hashes.get(state, ""))] = true
		unique_pixel_hashes[str(_pixel_hashes.get(state, ""))] = true
	_check(unique_text_hashes.size() == CAPTURE_STATES.size(), "six visible status texts have unique SHA-256 hashes")
	_check(unique_pixel_hashes.size() == CAPTURE_STATES.size(), "six visible projected pixel regions have unique SHA-256 hashes")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append("FAIL: " + message)
