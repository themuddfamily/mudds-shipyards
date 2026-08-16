extends SceneTree

## Rendered flight review of the nearby sector cluster.
##
## This is evidence, not a matrix suite: it boots the production `Main`, boards
## and launches the real Torrent, then flies it from the central berth out to
## Cinder Reach and back on real command-source input at production flight
## tuning, capturing named frames from the pilot's own chase camera along the
## way. It also prints the measured simulated travel time, which is the number
## the cluster's placement was designed around.
##
## Staged, and enumerated so nobody mistakes it for a playthrough: the on-foot
## walk to the craft is replaced by one teleport beside the boarding point, the
## range opponent is frozen so a fifteen-second transit is not a dogfight, and an
## evidence camera is added for the three wide compositions. Boarding, engine
## start, launch, every metre of flight and the return are the production path.
##
## Run: xvfb-run -a -s "-screen 0 2560x1440x24" godot --path <worktree> \
##   --display-driver x11 --rendering-driver vulkan \
##   --script tests/nearby_sector_flight_review.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/nearby-sector"
## Review resolution. Deliberately not the 2560x1440 the frozen gameplay capture
## uses: this script renders every frame of a twenty-five second round trip, and
## the transit frames are what dominate the cost, not the fourteen saved ones.
const CAPTURE_RESOLUTION := Vector2i(1600, 900)

const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const AXIS_RIGHT_X := 2
const AXIS_RIGHT_Y := 3
const AXIS_LEFT_TRIGGER := 4
const AXIS_RIGHT_TRIGGER := 5

var _failures: Array[String] = []
var _frames_written: Array[String] = []
var _flight_frames := 0
var _game: GameFlow
## Headless runs skip the PNG writes and exercise the flight only, which is how
## the route is debugged without paying for a software-rendered round trip.
var _headless := false
var _last_hull := 100.0


class ControllerStateProvider:
	extends RefCounted

	var buttons: Dictionary = {}
	var axes: Dictionary = {}

	func set_axis(axis_index: int, value: float) -> void:
		axes[axis_index] = clampf(value, -1.0, 1.0)

	func release_all() -> void:
		buttons.clear()
		axes.clear()

	func get_action_strength(action: StringName) -> float:
		if not InputMap.has_action(action):
			return 0.0
		var strength := 0.0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				var button := event as InputEventJoypadButton
				if bool(buttons.get(button.button_index, false)):
					strength = 1.0
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				var actual := float(axes.get(motion.axis, 0.0))
				if signf(actual) == signf(motion.axis_value):
					strength = maxf(strength, absf(actual))
		return strength

	func is_action_pressed(action: StringName) -> bool:
		return (
			InputMap.has_action(action)
			and get_action_strength(action) > InputMap.action_get_deadzone(action)
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(CAPTURE_RESOLUTION)
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	print(
		"REVIEW_RENDERER: method=%s display=%s window=%dx%d"
		% [
			RenderingServer.get_current_rendering_method(),
			DisplayServer.get_name(),
			DisplayServer.window_get_size().x,
			DisplayServer.window_get_size().y,
		]
	)

	_headless = DisplayServer.get_name() == "headless"
	var game := MAIN_SCENE.instantiate() as GameFlow
	_game = game
	root.add_child(game)
	await process_frame
	await physics_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null("Player") as PlayerController
	var ship := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var opponent := game.get_node_or_null("RangeOpponent") as CharacterBody3D
	var hud := game.hud
	if world == null or player == null or ship == null or hud == null:
		_fail("production Main did not expose world, player, Torrent and HUD")
		await _dispose(game)
		_finish()
		return

	var cluster := world.get_nearby_sector_cluster()
	if cluster == null:
		_fail("the world exposes no nearby sector cluster")
		await _dispose(game)
		_finish()
		return
	var report := cluster.get_cluster_audit_report()
	print("CLUSTER_AUDIT_VALID: ", report.get("valid", false), " errors=", report.get("errors", []))
	print(
		"CLUSTER_PLATFORM: distance=%.1f m cruise=%.2f s boost=%.2f s"
		% [
			float(report.get("platform_distance", 0.0)),
			float(report.get("cruise_travel_seconds", 0.0)),
			float(report.get("boost_travel_seconds", 0.0)),
		]
	)

	var picket := game.get_node_or_null("StandoffPicket")

	# The production title control, through the HUD's own begin handler, so the
	# intro overlay actually fades and the shift camera takes over. Headless runs
	# have no renderer for the fade tween to matter to, but the wait below is what
	# makes the two cases share one path.
	hud.call("_begin")
	if not await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 4.0):
		game.start_shift()
		await process_frame
	print("PHASE_AFTER_START: ", game.phase)

	var boarding_point: Vector3 = ship.get_boarding_position()
	var deck_height := world.get_player_spawn().origin.y
	var boarding_start := Vector3(boarding_point.x - 0.65, deck_height, boarding_point.z + 0.25)
	player.teleport_to(Transform3D(Basis(Vector3.UP, -PI * 0.5), boarding_start))
	game.boarding_motion_time = 0.25
	game.canopy_motion_time = 0.2
	await _frames(4)
	await physics_frame
	# Staged: the interact *signal* is emitted rather than the key pressed, so the
	# same production `GameFlow._on_interact_requested` handler runs with or
	# without a renderer attached. Everything it does from there is the real path.
	print(
		"BOARDING_CANDIDATE: ", game.boarding_candidate,
		" control=", player.is_control_enabled(),
		" phase=", game.phase
	)
	player.interact_requested.emit()
	await physics_frame
	if not await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 8.0):
		_fail("production boarding did not reach the pilot seat")
		await _dispose(game)
		_finish()
		return

	ship.request_engine_start()
	if not await _wait_for_phase(game, GameFlow.Phase.LAUNCH, 6.0):
		_fail("engine start did not reach the launch phase")
		await _dispose(game)
		_finish()
		return

	var source := ship.get_command_source() as LocalShipInputSource
	if source == null:
		_fail("the piloted Torrent exposed no local command source")
		await _dispose(game)
		_finish()
		return
	var provider := ControllerStateProvider.new()
	source.set_input_provider(provider)

	ship.destroyed.connect(func(position: Vector3, _velocity: Vector3) -> void:
		print("SHIP_DESTROYED at ", position, " t=%.1fs" % [float(_flight_frames) / 60.0])
	)
	var berth_origin := ship.global_position
	print(
		"SHIP_TUNING: maximum_speed=%.1f boost_speed=%.1f thrust=%.1f"
		% [ship.maximum_speed, ship.boost_speed, ship.thrust_acceleration]
	)

	var lane_entry: Vector3 = cluster.get_approach_lane_point(170.0)
	var gate_center: Vector3 = cluster.get_dock_gate_center()
	var gate_exit: Vector3 = cluster.get_approach_lane_point(58.0)
	var beacons: Array[Vector3] = cluster.get_route_beacon_positions()

	# --- Outbound -------------------------------------------------------------
	var outbound_start := _flight_frames
	# The target range's own header beam spans x +/-31.5 at y = 8.5 .. 9.5,
	# z = -120, and the first version of this route flew straight into it at
	# 46 m/s. This waypoint no longer carries a hand-chosen altitude: it takes the
	# station's published outbound clearance band, which is measured from the
	# production hulls and is the same number the launch gate marker and
	# `tests/outbound_route_clearance_test.gd` use. The pilot's real line out is
	# the same one - under the range gantry, then down and starboard along the
	# beacon chain.
	var clearance: Dictionary = world.get_outbound_clearance_band()
	var outbound_y := float(clearance["aim_y"])
	print(
		"OUTBOUND_CLEARANCE_BAND: floor=%.2f ceiling=%.2f aim=%.2f  launch_gate=%s"
		% [
			float(clearance["floor"]),
			float(clearance["ceiling"]),
			outbound_y,
			str(world.get_launch_gate_transform().origin),
		]
	)
	await _fly(ship, provider, Vector3(8.0, outbound_y, -96.0), 12.0, 16.0)
	await _capture("01_departure.png")

	# Staged, and it has to happen *here*: crossing the launch threshold on the leg
	# above is what activates the production encounter, so anything suppressed
	# before launch is simply switched back on. Left running, the range defender
	# holds station inside the target range and had killed the Torrent five seconds
	# out on the first three runs of this script. The transit is meant to be a
	# flight; the combat loop has its own suites.
	_suppress_range_encounter(opponent, picket)

	await _fly(ship, provider, beacons[0] + Vector3(18.0, 4.0, -8.0), 14.0, 14.0)
	await _capture("02_beacon_alpha.png")

	await _fly(ship, provider, beacons[2] + Vector3(20.0, 6.0, -10.0), 16.0, 22.0)
	await _capture("03_beacon_chain.png")

	await _fly(ship, provider, lane_entry, 16.0, 22.0)
	await _capture("04_field_approach.png")

	await _fly(ship, provider, gate_center, 10.0, 14.0)
	await _capture("05_dock_gate.png")

	await _fly(ship, provider, gate_exit, 9.0, 12.0)
	await _brake(ship, provider, 8.0)
	await _capture("06_platform.png")
	var outbound_frames := _flight_frames - outbound_start
	var outbound_seconds := float(outbound_frames) / float(Engine.physics_ticks_per_second)
	print(
		"OUTBOUND: %.2f simulated seconds over %.1f m (berth -> platform gate exit)"
		% [outbound_seconds, berth_origin.distance_to(ship.global_position)]
	)
	if not _check(
		ship.global_position.distance_to(cluster.PLATFORM_ANCHOR) < 120.0,
		"the production Torrent physically reached the platform"
	):
		pass
	print("SHIP_HULL_AT_PLATFORM: ", ship.get_telemetry().get("hull", -1.0))

	# --- Evidence compositions -----------------------------------------------
	var evidence_camera := Camera3D.new()
	evidence_camera.name = "ClusterEvidenceCamera"
	evidence_camera.far = 4000.0
	game.add_child(evidence_camera)
	await _frame_camera(
		evidence_camera,
		cluster.PLATFORM_ANCHOR + Vector3(70.0, 130.0, 190.0),
		cluster.PLATFORM_ANCHOR + Vector3(0.0, -6.0, 10.0),
		52.0
	)
	await _capture("07_platform_wide.png")

	await _frame_camera(
		evidence_camera,
		cluster.PLATFORM_ANCHOR + Vector3(6.0, 12.0, 128.0),
		cluster.PLATFORM_ANCHOR + Vector3(0.0, 6.0, 30.0),
		58.0
	)
	await _capture("08_dock_gate_wide.png")

	await _frame_camera(
		evidence_camera,
		cluster.MOONLET_ANCHOR + Vector3(150.0, 70.0, 330.0),
		cluster.MOONLET_ANCHOR,
		50.0
	)
	await _capture("09_moonlet.png")

	await _frame_camera(
		evidence_camera,
		beacons[1] + Vector3(34.0, 12.0, 44.0),
		beacons[1] + Vector3(0.0, 6.0, 0.0),
		46.0
	)
	await _capture("10_route_beacon.png")

	await _frame_camera(
		evidence_camera,
		Vector3(0.0, 10.0, -60.0),
		beacons[0],
		48.0
	)
	await _capture("11_outbound_from_station.png")
	evidence_camera.queue_free()
	await process_frame
	ship.get_camera().current = true
	await _frames(3)

	# --- Homebound ------------------------------------------------------------
	var home_start := _flight_frames
	await _fly(ship, provider, beacons[2] + Vector3(0.0, 10.0, 30.0), 18.0, 26.0)
	await _capture("12_homebound_beacons.png")
	# Home the same way the pilot left: under the range gantry, not over it, on the
	# same published clearance band.
	await _fly(ship, provider, Vector3(14.0, outbound_y - 1.0, -150.0), 18.0, 26.0)
	await _capture("13_range_reentry.png")
	await _fly(ship, provider, Vector3(4.0, outbound_y, -84.0), 14.0, 16.0)
	await _brake(ship, provider, 8.0)
	await _capture("14_station_in_sight.png")
	var home_seconds := float(_flight_frames - home_start) / float(Engine.physics_ticks_per_second)
	print("HOMEBOUND: %.2f simulated seconds back to the launch corridor" % home_seconds)
	_check(
		ship.global_position.distance_to(berth_origin) < 140.0,
		"the same craft flew back to the station without being stranded"
	)
	print("SHIP_HULL_HOME: ", ship.get_telemetry().get("hull", -1.0))
	print(
		"ROUND_TRIP: %.2f simulated seconds"
		% [outbound_seconds + home_seconds]
	)

	provider.release_all()
	await _dispose(game)
	_finish()


## Retires both live range opponents and parks them well behind the station.
## `deactivate()` is each craft's own production teardown, not a poke at its
## internals; the reposition afterwards keeps a dormant hull out of the lane.
func _suppress_range_encounter(opponent: Node, picket: Node) -> void:
	for craft in [opponent, picket]:
		if craft == null or not is_instance_valid(craft):
			continue
		if craft.has_method("deactivate"):
			craft.call("deactivate")
		craft.set_physics_process(false)
		craft.set_process(false)
		if craft is Node3D:
			(craft as Node3D).global_position = Vector3(0.0, -320.0, 260.0)


func _fly(
		ship: HeroShip,
		provider: ControllerStateProvider,
		waypoint: Vector3,
		arrival_radius: float,
		nominal_seconds: float
	) -> void:
	var budget := int(ceil(nominal_seconds * float(Engine.physics_ticks_per_second))) + 240
	var frames := 0
	while frames < budget:
		var offset := waypoint - ship.global_position
		if offset.length() <= arrival_radius:
			break
		var desired := offset.normalized()
		var local_desired := ship.global_basis.orthonormalized().inverse() * desired
		var alignment := (-ship.global_basis.z.normalized()).dot(desired)
		var stopping := ship.velocity.length_squared() / maxf(2.0 * ship.brake_acceleration, 1.0)
		var should_brake := offset.length() < stopping + arrival_radius + 1.0
		if ship.velocity.length() < 1.0:
			should_brake = false
		provider.set_axis(AXIS_LEFT_X, clampf(local_desired.x * 3.4, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_Y, -1.0 if alignment > 0.72 and not should_brake else 0.0)
		provider.set_axis(AXIS_RIGHT_X, 0.0)
		provider.set_axis(AXIS_RIGHT_Y, -clampf(local_desired.y * 3.4, -1.0, 1.0))
		provider.set_axis(AXIS_LEFT_TRIGGER, 1.0 if should_brake else 0.0)
		await physics_frame
		frames += 1
		_flight_frames += 1
		var hull_now := float(ship.get_telemetry().get("hull", -1.0))
		if hull_now < _last_hull:
			var colliders: Array[String] = []
			for index in ship.get_slide_collision_count():
				var collider := ship.get_slide_collision(index).get_collider()
				colliders.append(
					"%s@%s" % [collider, ship.get_slide_collision(index).get_position()]
				)
			print(
				"HULL_DROP %.0f -> %.0f at %s speed=%.1f colliders=%s"
				% [_last_hull, hull_now, ship.global_position, ship.velocity.length(), colliders]
			)
		_last_hull = hull_now
		if _flight_frames % 180 == 0:
			print(
				"  ... t=%.1fs pos=%s speed=%.1f to_waypoint=%.0f hull=%.0f phase=%d"
				% [
					float(_flight_frames) / float(Engine.physics_ticks_per_second),
					ship.global_position,
					ship.velocity.length(),
					offset.length(),
					float(ship.get_telemetry().get("hull", -1.0)),
					int(_game.phase) if _game != null else -1,
				]
			)
	_neutral(provider)
	_check(
		ship.global_position.distance_to(waypoint) <= arrival_radius * 1.6,
		"reached waypoint %s (%.1f m away)" % [waypoint, ship.global_position.distance_to(waypoint)]
	)


func _brake(ship: HeroShip, provider: ControllerStateProvider, nominal_seconds: float) -> void:
	_neutral(provider)
	provider.set_axis(AXIS_LEFT_TRIGGER, 1.0)
	var budget := int(ceil(nominal_seconds * float(Engine.physics_ticks_per_second)))
	for _index in budget:
		if ship.velocity.length() < 1.5:
			break
		await physics_frame
		_flight_frames += 1
	_neutral(provider)
	await physics_frame


func _neutral(provider: ControllerStateProvider) -> void:
	for axis in [
		AXIS_LEFT_X, AXIS_LEFT_Y, AXIS_RIGHT_X, AXIS_RIGHT_Y,
		AXIS_LEFT_TRIGGER, AXIS_RIGHT_TRIGGER
	]:
		provider.set_axis(axis, 0.0)


func _frame_camera(camera: Camera3D, from: Vector3, look_at: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.global_position = from
	camera.look_at(look_at, Vector3.UP)
	camera.current = true
	await _frames(4)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _wait_for_phase(game: GameFlow, phase: int, seconds: float) -> bool:
	var budget := int(ceil(seconds * float(Engine.physics_ticks_per_second)))
	for _index in budget:
		if game.phase == phase:
			return true
		await physics_frame
		await process_frame
	return game.phase == phase


func _capture(file_name: String) -> void:
	if _headless:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport image for " + file_name)
		return
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_fail("could not write %s (error %d)" % [path, error])
		return
	_frames_written.append(file_name)
	print("WROTE ", path)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("OK: ", description)
	else:
		_fail(description)
	return condition


func _fail(description: String) -> void:
	_failures.append(description)
	push_error("REVIEW FAIL: " + description)


func _dispose(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _finish() -> void:
	print("REVIEW_FRAMES: ", ", ".join(_frames_written))
	if _failures.is_empty():
		print("NEARBY_SECTOR_FLIGHT_REVIEW_OK")
		quit(0)
	else:
		print("NEARBY_SECTOR_FLIGHT_REVIEW_FAILED: ", ", ".join(_failures))
		quit(1)
