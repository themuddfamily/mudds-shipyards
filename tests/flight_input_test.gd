extends SceneTree

const ShipCommandSourceType := preload("res://scripts/control/ship_command_source.gd")

const AXIS_LEFT_Y := 1
const AXIS_RIGHT_TRIGGER := 5
const BUTTON_X := 2
const BUTTON_LEFT_SHOULDER := 9
const BUTTON_RIGHT_SHOULDER := 10
const BUTTON_DPAD_LEFT := 13

var _failures: Array[String] = []


class ScriptedCommandSource:
	extends ShipCommandSource

	var controls: Dictionary = {}
	var sample_count := 0

	func _sample_controls() -> Dictionary:
		sample_count += 1
		return controls.duplicate(true)


class ControllerOnlyInputProvider:
	extends RefCounted

	var button_states: Dictionary = {}
	var axis_states: Dictionary = {}

	func set_button(button_index: int, pressed: bool) -> void:
		button_states[button_index] = pressed

	func set_axis(axis_index: int, value: float) -> void:
		axis_states[axis_index] = clampf(value, -1.0, 1.0)

	func get_action_strength(action: StringName) -> float:
		if not InputMap.has_action(action):
			return 0.0
		var strength := 0.0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				var button := event as InputEventJoypadButton
				if bool(button_states.get(button.button_index, false)):
					strength = maxf(strength, 1.0)
			elif event is InputEventJoypadMotion:
				var motion := event as InputEventJoypadMotion
				var actual := float(axis_states.get(motion.axis, 0.0))
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
	var ship_scene := load("res://scenes/ships/torrent_interceptor.tscn") as PackedScene
	_check(ship_scene != null, "hero ship scene loads")
	if ship_scene == null:
		_finish()
		return

	var stage := Node3D.new()
	root.add_child(stage)
	await _test_variant_launch_thresholds(stage)
	await _test_fleet_chase_camera_boundaries(stage)
	await _test_controller_only_command_path(stage, ship_scene)
	var ship := ship_scene.instantiate() as CharacterBody3D
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 20.0, 0.0)
	ship.call("set_piloted", true)
	ship.set("engine_start_time", 0.02)
	var local_source := ship.call("get_command_source") as ShipCommandSource
	_check(local_source is LocalShipInputSource, "production ship creates a local command source by default")
	_check(not (local_source as LocalShipInputSource).capture_mouse_motion, "ship is the sole mouse-event owner")

	var camera_action: StringName = ship.call("get_camera_view_action")
	_check(camera_action == &"toggle_ship_camera_view", "ship camera action has a stable integration name")
	_check(InputMap.has_action(camera_action), "ship camera action is registered at runtime when absent")
	var has_default_view_key := false
	for mapped_event in InputMap.action_get_events(camera_action):
		if mapped_event is InputEventKey and (mapped_event as InputEventKey).physical_keycode == KEY_V:
			has_default_view_key = true
	_check(has_default_view_key, "runtime camera action provides physical V as its default binding")

	var minimum_zoom := float(ship.get("minimum_chase_camera_distance"))
	var maximum_zoom := float(ship.get("maximum_chase_camera_distance"))
	ship.call("set_chase_camera_distance", -1000.0)
	_check(is_equal_approx(float(ship.call("get_chase_camera_distance")), minimum_zoom), "chase zoom clamps to its near bound")
	ship.call("set_chase_camera_distance", 1000.0)
	_check(is_equal_approx(float(ship.call("get_chase_camera_distance")), maximum_zoom), "chase zoom clamps to its far bound")
	var initial_arm_distance := float(ship.call("get_current_chase_camera_distance"))
	ship.call("set_chase_camera_distance", minimum_zoom)
	await physics_frame
	await physics_frame
	var eased_arm_distance := float(ship.call("get_current_chase_camera_distance"))
	_check(
		eased_arm_distance < initial_arm_distance and eased_arm_distance > minimum_zoom,
		"chase zoom eases toward the requested distance instead of snapping"
	)
	var middle_zoom := (minimum_zoom + maximum_zoom) * 0.5
	ship.call("set_chase_camera_distance", middle_zoom)
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	ship.call("_unhandled_input", wheel_down)
	_check(
		is_equal_approx(float(ship.call("get_chase_camera_distance")), middle_zoom),
		"mouse wheel queues camera intent without mutating the ship outside its command tick"
	)
	await physics_frame
	var wheel_command := ship.call("get_last_ship_command") as ShipCommand
	_check(
		float(ship.call("get_chase_camera_distance")) > middle_zoom
		and is_equal_approx(wheel_command.camera_distance_delta, 1.0),
		"mouse wheel adjusts chase distance through the sampled ShipCommand"
	)

	var chase_camera := ship.call("get_camera") as Camera3D
	_check(chase_camera.name == &"ShipCamera" and chase_camera.current, "piloting starts in the active chase view")
	ship.call("set_cockpit_view", true)
	var cockpit_camera := ship.call("get_camera") as Camera3D
	_check(
		ship.call("is_cockpit_view") and cockpit_camera.name == &"CockpitCamera" and cockpit_camera.current,
		"public camera method selects the physical first-person cockpit view"
	)
	_check(
		cockpit_camera.position.z <= -0.48,
		"cockpit pilot-eye camera sits forward of the visible helmet and visor"
	)
	var cockpit_wheel_distance := float(ship.call("get_chase_camera_distance"))
	ship.call("_unhandled_input", wheel_down)
	await physics_frame
	_check(
		is_equal_approx(float(ship.call("get_chase_camera_distance")), cockpit_wheel_distance)
		and is_zero_approx((ship.call("get_last_ship_command") as ShipCommand).camera_distance_delta),
		"cockpit view preserves the stored chase distance without queuing a latent edge"
	)
	Input.action_press(camera_action)
	await physics_frame
	Input.action_release(camera_action)
	await physics_frame
	_check(
		not ship.call("is_cockpit_view") and ship.call("get_camera") == chase_camera and chase_camera.current,
		"camera input action returns to the active chase view"
	)

	# SpringArm3D uses a swept sphere against level geometry. It retracts immediately
	# at an obstruction while the desired zoom remains intact, then safely restores.
	ship.call("set_chase_camera_distance", middle_zoom)
	for _step in 18:
		await physics_frame
	var camera_pivot := ship.get_node("CameraRig") as Node3D
	var collision_arm := ship.get_node("CameraRig/CameraCollisionArm") as SpringArm3D
	var self_clear_distance := chase_camera.global_position.distance_to(camera_pivot.global_position)
	_check(
		collision_arm.collision_mask == PhysicsLayers.CAMERA_OBSTRUCTION_QUERY_MASK,
		"chase camera obstruction sees world geometry and other physical ships"
	)
	_check(
		self_clear_distance > float(ship.call("get_current_chase_camera_distance")) - 0.5,
		"chase camera excludes its own ship collider"
	)

	# A separate body on the canonical Ship layer must retract the arm just like
	# station geometry; this catches a mask that only protects against World.
	var other_ship := CharacterBody3D.new()
	other_ship.name = "OtherShipCameraObstacle"
	other_ship.collision_layer = PhysicsLayers.SHIP_BODY_LAYER
	other_ship.collision_mask = PhysicsLayers.NONE
	var other_ship_shape := CollisionShape3D.new()
	var other_ship_box := BoxShape3D.new()
	other_ship_box.size = Vector3(24.0, 18.0, 0.6)
	other_ship_shape.shape = other_ship_box
	other_ship.add_child(other_ship_shape)
	stage.add_child(other_ship)
	other_ship.global_position = Vector3(0.0, 25.0, 9.0)
	for _step in 4:
		await physics_frame
	var ship_obstructed_distance := chase_camera.global_position.distance_to(camera_pivot.global_position)
	_check(
		ship_obstructed_distance < float(ship.call("get_current_chase_camera_distance")) - 2.0,
		"chase camera retracts before another physical ship"
	)
	other_ship.queue_free()
	for _step in 5:
		await physics_frame
	var ship_clear_distance := chase_camera.global_position.distance_to(camera_pivot.global_position)
	_check(ship_clear_distance > ship_obstructed_distance + 2.0, "chase camera restores after another ship clears")

	var obstacle := StaticBody3D.new()
	obstacle.name = "CameraTestWall"
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(24.0, 18.0, 0.6)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	stage.add_child(obstacle)
	obstacle.global_position = Vector3(0.0, 25.0, 9.0)
	for _step in 4:
		await physics_frame
	var obstructed_distance := chase_camera.global_position.distance_to(camera_pivot.global_position)
	_check(
		obstructed_distance < float(ship.call("get_current_chase_camera_distance")) - 2.0,
		"swept chase camera retracts before world geometry"
	)
	obstacle.queue_free()
	for _step in 5:
		await physics_frame
	var restored_distance := chase_camera.global_position.distance_to(camera_pivot.global_position)
	_check(restored_distance > obstructed_distance + 2.0, "chase camera restores after an obstruction clears")

	# Exact self-hull regression: a wall whose front face is five centimetres
	# behind Torrent's enabled aft collision is a valid non-overlapping world
	# placement. The arm must still retract, but neither its camera point nor any
	# of the four near-plane corners may enter the owning hull envelope.
	var hull_bounds := (
		ship.call("get_landing_collision_report") as Dictionary
	).get("local_bounds", AABB()) as AABB
	var near_wall_front_z := hull_bounds.end.z + 0.05
	var near_wall := _camera_test_wall(
		"NearAftCameraWall",
		ship.to_global(Vector3(0.0, hull_bounds.get_center().y, near_wall_front_z + 0.30))
	)
	stage.add_child(near_wall)
	for _step in 6:
		await physics_frame
	var boundary := ship.call("get_chase_camera_self_hull_boundary_report") as Dictionary
	var boundary_samples := boundary.get("samples_local", {}) as Dictionary
	var near_wall_clear := boundary_samples.size() == 5
	for sample_name: StringName in boundary_samples:
		near_wall_clear = near_wall_clear \
			and (boundary_samples[sample_name] as Vector3).z < near_wall_front_z
	print(
		"CHASE_CAMERA_SELF_HULL_CLEARANCE: before=%.6f after=%.6f correction=%.6f"
		% [
			float(boundary.get("base_signed_clearance_m", -INF)),
			float(boundary.get("signed_clearance_m", -INF)),
			float(boundary.get("correction_m", 0.0)),
		]
	)
	_check(
		float(boundary.get("base_signed_clearance_m", 0.0)) < 0.0,
		"near-aft wall reproduces the uncorrected chase camera inside its own hull"
	)
	_check(
		bool(boundary.get("valid", false))
		and int(boundary.get("sample_count", 0)) == 5
		and float(boundary.get("signed_clearance_m", 0.0)) >= 0.019
		and float(boundary.get("correction_m", 0.0)) > 0.0,
		"structured boundary keeps the camera point and four near-plane corners outside the owning hull"
	)
	_check(
		near_wall_clear
		and (collision_arm.get_child(0) as Node3D).global_position.distance_to(
			camera_pivot.global_position
		) < float(ship.call("get_current_chase_camera_distance")) - 2.0,
		"self-hull correction preserves SpringArm retraction before the exact external wall"
	)
	_check(
		is_equal_approx(float(ship.call("get_chase_camera_distance")), middle_zoom),
		"near-aft correction leaves caller-owned chase distance unchanged"
	)
	near_wall.queue_free()
	for _step in 6:
		await physics_frame
	var cleared_boundary := ship.call("get_chase_camera_self_hull_boundary_report") as Dictionary
	_check(
		bool(cleared_boundary.get("valid", false))
		and absf(float(cleared_boundary.get("correction_m", 1.0))) < 0.001
		and chase_camera.global_position.distance_to(camera_pivot.global_position)
			> restored_distance - 0.5,
		"unobstructed chase restores its ordinary boom position with no residual correction"
	)

	var parked_basis: Basis = ship.global_basis
	ship.call("apply_look_motion", Vector2(900.0, -900.0))
	ship.call("request_engine_start")
	for _step in 4:
		await physics_frame
	_check(ship.global_basis.is_equal_approx(parked_basis), "parked mouse motion cannot queue a launch attitude snap")

	# Switching viewpoints is another mode boundary: mouse motion received in the
	# departing view must not turn the craft on the next physics callback.
	Input.action_press("move_forward")
	var before_view_switch_basis: Basis = ship.global_basis
	ship.call("apply_look_motion", Vector2(600.0, -400.0))
	ship.call("set_cockpit_view", true)
	await physics_frame
	await physics_frame
	Input.action_release("move_forward")
	_check(ship.global_basis.is_equal_approx(before_view_switch_basis), "camera switching discards queued look motion")
	var cockpit_forward := -(ship.call("get_camera") as Camera3D).global_basis.z.normalized()
	_check(cockpit_forward.dot(-ship.global_basis.z.normalized()) > 0.999, "cockpit reticle axis matches the physical nose")
	ship.call("set_cockpit_view", false)

	ship.velocity = Vector3(0.0, 0.0, -36.0)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	for _step in 54:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("move_right")
	var forward: Vector3 = -ship.global_basis.z.normalized()
	var travel: Vector3 = ship.velocity.normalized()
	_check(ship.global_basis.y.dot(Vector3.UP) > 0.98, "keyboard steering keeps the physical craft upright")
	_check(forward.dot(travel) > 0.9, "arcade momentum follows the visible nose")
	_check(absf((ship.get_node("TorrentVisual") as Node3D).rotation.z) > 0.03, "yaw produces presentation-only visual banking")
	for _step in 12:
		await physics_frame
	var released_telemetry: Dictionary = ship.call("get_telemetry")
	_check(absf(float(released_telemetry.get("throttle", 1.0))) < 0.04, "released throttle returns promptly to neutral")

	Input.action_press("move_forward")
	for _step in 12:
		await physics_frame
	Input.action_release("move_forward")
	Input.action_press("move_back")
	for _step in 14:
		await physics_frame
	Input.action_release("move_back")
	var reversed_telemetry: Dictionary = ship.call("get_telemetry")
	_check(float(reversed_telemetry.get("throttle", 0.0)) < -0.2, "opposite thrust crosses neutral without a long input lag")

	var before_basis: Basis = ship.global_basis
	var before_forward := -before_basis.z.normalized()
	var before_right := before_basis.x.normalized()
	ship.call("apply_look_motion", Vector2(120.0, 0.0))
	await physics_frame
	await physics_frame
	var right_turn_forward := -ship.global_basis.z.normalized()
	_check(right_turn_forward.dot(before_right) > before_forward.dot(before_right) + 0.01, "mouse-right turns the craft toward screen right")
	_check(
		absf(before_forward.angle_to(right_turn_forward) - 120.0 * float(ship.get("mouse_sensitivity"))) < 0.02,
		"one mouse event applies the configured sensitivity exactly once"
	)
	ship.call("apply_look_motion", Vector2(0.0, -60.0))
	await physics_frame
	await physics_frame
	var raised_forward := -ship.global_basis.z.normalized()
	_check(raised_forward.y > right_turn_forward.y + 0.01, "mouse-up raises the craft nose")
	var ship_camera := ship.call("get_camera") as Camera3D
	var camera_forward := -ship_camera.global_basis.z.normalized()
	_check(camera_forward.dot(raised_forward) > 0.999, "chase reticle axis matches the physical travel axis")

	# A scripted producer proves AI/replay/network can drive the same live
	# simulation while the real InputMap is ignored, one snapshot per tick.
	Input.action_press("move_forward")
	var scripted := ScriptedCommandSource.new()
	stage.add_child(scripted)
	scripted.controls = {
		"throttle": -0.75,
		"yaw": 0.0,
		"pitch": 0.0,
		"roll": 0.0,
		"look_yaw_delta": 0.0,
		"look_pitch_delta": 0.0,
	}
	ship.call("set_command_source", scripted)
	await physics_frame
	var scripted_command: ShipCommand = ship.call("get_last_ship_command")
	_check(scripted.sample_count == 1, "live ship samples its injected producer exactly once per physics tick")
	_check(is_equal_approx(scripted_command.throttle, -0.75), "injected command overrides held local InputMap thrust")
	var scripted_throttle := float((ship.call("get_telemetry") as Dictionary).throttle)
	_check(scripted_throttle < 0.0, "injected command drives the production flight simulation")

	# Disabling or removing authority must neutralize immediately, without a local
	# fallback that could accidentally read the still-held W key.
	scripted.enabled = false
	await physics_frame
	var disabled_command: ShipCommand = ship.call("get_last_ship_command")
	_check(disabled_command.is_neutral(), "disabled injected source yields a neutral live command")
	var throttle_after_disabled := float((ship.call("get_telemetry") as Dictionary).throttle)
	_check(throttle_after_disabled > scripted_throttle, "neutral authority decays reverse thrust instead of consuming held local input")
	scripted.enabled = true
	scripted.set_authority_peer_id(7)
	scripted.set_local_peer_id_override(1)
	await physics_frame
	_check((ship.call("get_last_ship_command") as ShipCommand).is_neutral(), "non-owner source yields a neutral live command")
	Input.action_release("move_forward")
	ship.call("set_command_source", null)
	_check(ship.call("get_command_source") == local_source, "null injection restores the ship-owned local adapter")
	await physics_frame

	var projectile_count := [0]
	ship.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		projectile_count[0] += 1
	)
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(projectile_count[0] == 1 and (ship.call("get_last_ship_command") as ShipCommand).fire, "held fire reaches weapons through the sampled command")
	var before_roll_basis: Basis = ship.global_basis
	Input.action_press("barrel_roll")
	await physics_frame
	Input.action_release("barrel_roll")
	var roll_command: ShipCommand = ship.call("get_last_ship_command")
	_check(roll_command.barrel_roll and not ship.global_basis.is_equal_approx(before_roll_basis), "barrel-roll edge drives the live attitude path")

	ship.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_controller_only_command_path(stage: Node3D, ship_scene: PackedScene) -> void:
	var controller_ship := ship_scene.instantiate() as HeroShip
	_check(controller_ship != null, "controller-only production ship instantiates")
	if controller_ship == null:
		return
	stage.add_child(controller_ship)
	controller_ship.global_position = Vector3(220.0, 20.0, 0.0)
	controller_ship.set_piloted(true)
	var source := controller_ship.get_command_source() as LocalShipInputSource
	_check(source != null, "controller-only fixture uses the production local command adapter")
	if source == null:
		controller_ship.queue_free()
		await process_frame
		return
	var controller := ControllerOnlyInputProvider.new()
	source.set_input_provider(controller)

	var projectile_count := [0]
	controller_ship.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		projectile_count[0] += 1
	)
	var minimum_zoom := controller_ship.minimum_chase_camera_distance
	var maximum_zoom := controller_ship.maximum_chase_camera_distance
	var middle_zoom := (minimum_zoom + maximum_zoom) * 0.5
	controller_ship.set_chase_camera_distance(middle_zoom)
	controller.set_axis(AXIS_LEFT_Y, -1.0)
	controller.set_axis(AXIS_RIGHT_TRIGGER, 1.0)
	controller.set_button(BUTTON_RIGHT_SHOULDER, true)
	await physics_frame
	await process_frame
	var flight_command := controller_ship.get_last_ship_command()
	_check(
		is_equal_approx(flight_command.throttle, 1.0)
		and flight_command.fire
		and projectile_count[0] == 1,
		"controller thrust and fire drive the live command path"
	)
	_check(
		is_equal_approx(
			controller_ship.get_chase_camera_distance(),
			middle_zoom + controller_ship.chase_camera_zoom_step
		),
		"RB reaches and adjusts the physical chase camera exactly once"
	)
	_check(
		str(controller_ship.get_telemetry().get("engine_state", &"")) == "ONLINE",
		"the same controller flight demand automatically wakes propulsion"
	)
	await physics_frame
	var held_flight_command := controller_ship.get_last_ship_command()
	_check(
		is_equal_approx(held_flight_command.throttle, 1.0)
		and held_flight_command.fire
		and is_zero_approx(held_flight_command.camera_distance_delta),
		"held flight axes repeat while a held camera-distance button remains edge-triggered"
	)

	controller.set_axis(AXIS_LEFT_Y, 0.0)
	controller.set_axis(AXIS_RIGHT_TRIGGER, 0.0)
	controller.set_button(BUTTON_RIGHT_SHOULDER, false)
	await physics_frame
	var distance_before_near := controller_ship.get_chase_camera_distance()
	controller.set_button(BUTTON_LEFT_SHOULDER, true)
	controller.set_button(BUTTON_DPAD_LEFT, true)
	controller.set_button(BUTTON_X, true)
	await physics_frame
	var return_command := controller_ship.get_last_ship_command()
	_check(
		return_command.landing and return_command.interact,
		"controller-only return actions reach landing and exit command edges"
	)
	_check(
		is_equal_approx(return_command.camera_distance_delta, -1.0)
		and controller_ship.get_chase_camera_distance() < distance_before_near,
		"LB reaches and adjusts the physical chase camera in the near direction"
	)
	await physics_frame
	var held_return_command := controller_ship.get_last_ship_command()
	_check(
		not held_return_command.landing
		and not held_return_command.interact
		and is_zero_approx(held_return_command.camera_distance_delta),
		"held controller return buttons cannot replay lifecycle or camera edges"
	)

	controller_ship.queue_free()
	await process_frame
	await process_frame


func _camera_test_wall(wall_name: String, world_position: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = PhysicsLayers.WORLD
	wall.collision_mask = PhysicsLayers.NONE
	# The fixture's parent stage is identity; local assignment avoids asking an
	# out-of-tree Node3D for a global transform before ownership is established.
	wall.position = world_position
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(24.0, 18.0, 0.6)
	shape.shape = box
	wall.add_child(shape)
	return wall


func _test_fleet_chase_camera_boundaries(stage: Node3D) -> void:
	var fleet_sources := [
		["Torrent", "res://scenes/ships/torrent_interceptor.tscn"],
		["Arrow", "res://scenes/ships/arrow_recon_ship.tscn"],
		["Jovian", "res://scenes/ships/jovian_light_freighter.tscn"],
		["Zenith", "res://scenes/ships/zenith_interceptor.tscn"],
		["Halyard", "res://scenes/ships/halyard_crew_transport.tscn"],
		["Cinder cargo", "res://scripts/ships/cinder_cargo_hauler.gd"],
		["Cinder bomber", "res://scripts/ships/cinder_long_range_bomber.gd"],
		["Cinder interceptor", "res://scripts/ships/cinder_light_interceptor.gd"],
	]
	for fleet_index in fleet_sources.size():
		var specification: Array = fleet_sources[fleet_index]
		var label := str(specification[0])
		var source := load(str(specification[1]))
		var craft: HeroShip = null
		if source is PackedScene:
			craft = (source as PackedScene).instantiate() as HeroShip
		elif source is Script:
			craft = (source as Script).new() as HeroShip
		_check(craft != null, "%s chase-boundary production craft instantiates" % label)
		if craft == null:
			continue
		stage.add_child(craft)
		craft.global_position = Vector3(400.0 + float(fleet_index) * 80.0, 20.0, 0.0)
		for _settle in 3:
			await physics_frame
		var collision_before := craft.get_landing_collision_report()
		var collision_layer_before := craft.collision_layer
		var collision_mask_before := craft.collision_mask
		var bounds := collision_before.get("local_bounds", AABB()) as AABB
		var wall_front_z := bounds.end.z + 0.05
		var wall := _camera_test_wall(
			"%sNearAftCameraWall" % label.replace(" ", ""),
			craft.to_global(Vector3(0.0, bounds.get_center().y, wall_front_z + 0.30))
		)
		stage.add_child(wall)
		for _settle in 6:
			await physics_frame
		var report := craft.get_chase_camera_self_hull_boundary_report()
		var samples := report.get("samples_local", {}) as Dictionary
		var wall_clear := samples.size() == 5
		for sample_name: StringName in samples:
			wall_clear = wall_clear and (samples[sample_name] as Vector3).z < wall_front_z
		_check(
			bool(report.get("valid", false))
			and int(report.get("sample_count", 0)) == 5
			and float(report.get("signed_clearance_m", 0.0)) >= 0.019,
			"%s near-aft retraction keeps the camera point and near plane outside its own hull"
				% label
		)
		_check(
			wall_clear,
			"%s self-hull boundary remains on the craft side of the external wall" % label
		)
		var collision_after := craft.get_landing_collision_report()
		_check(
			collision_after.get("local_bounds", AABB()) == collision_before.get("local_bounds", AABB())
			and int(collision_after.get("shape_count", -1))
				== int(collision_before.get("shape_count", -2))
			and craft.collision_layer == collision_layer_before
			and craft.collision_mask == collision_mask_before,
			"%s camera correction leaves physical hull authority unchanged" % label
		)
		craft.set_cockpit_view(true)
		_check(
			craft.is_cockpit_view() and craft.get_camera().name == &"CockpitCamera",
			"%s boundary mount leaves cockpit mode on the production pilot-eye camera" % label
		)
		craft.set_cockpit_view(false)
		wall.queue_free()
		for _settle in 6:
			await physics_frame
		var restored := craft.get_chase_camera_self_hull_boundary_report()
		_check(
			bool(restored.get("valid", false))
			and absf(float(restored.get("correction_m", 1.0))) < 0.001,
			"%s unobstructed chase restores without a residual hull correction" % label
		)
		craft.queue_free()
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLIGHT_INPUT_TEST_OK")
		quit(0)
	else:
		print("FLIGHT_INPUT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)


func _test_variant_launch_thresholds(stage: Node3D) -> void:
	var variants := [
		["Torrent", "res://scenes/ships/torrent_interceptor.tscn"],
		["Arrow", "res://scenes/ships/arrow_recon_ship.tscn"],
		["Jovian", "res://scenes/ships/jovian_light_freighter.tscn"],
	]
	Input.action_release(&"move_forward")
	for variant_data: Array in variants:
		var label := str(variant_data[0])
		var variant_scene := load(str(variant_data[1])) as PackedScene
		_check(variant_scene != null, "%s launch-threshold scene loads" % label)
		if variant_scene == null:
			continue
		var variant := variant_scene.instantiate() as HeroShip
		stage.add_child(variant)
		variant.global_position = Vector3(100.0, 20.0, 0.0)
		variant.engine_start_time = 0.01
		variant.set_piloted(true)
		variant.request_engine_start()
		for _startup_tick in 2:
			await physics_frame
		_check(
			str(variant.get_telemetry().get("engine_state", &"")) == "ONLINE",
			"%s reaches online state for launch-threshold probe" % label
		)

		var tap_origin := variant.global_position
		Input.action_press(&"move_forward")
		await physics_frame
		Input.action_release(&"move_forward")
		await physics_frame
		var tap_telemetry := variant.get_telemetry()
		_check(
			bool(tap_telemetry.get("landed", false)) and variant.velocity.is_zero_approx(),
			"%s one-tick W tap retains landed authority" % label
		)
		_check(
			variant.global_position.distance_to(tap_origin) < 0.002,
			"%s one-tick W tap produces no material departure" % label
		)

		# A collision, moving platform, scripted simulation, or network correction
		# may impart real speed while the craft still carries its parked latch. Such
		# authoritative motion must not be mistaken for sub-threshold pad drift.
		var impulse_origin := variant.global_position
		var impulse_forward := -variant.global_basis.z.normalized()
		variant.velocity = impulse_forward * 2.0
		await physics_frame
		_check(
			not bool(variant.get_telemetry().get("landed", true))
			and variant.global_position.distance_to(impulse_origin) > 0.01,
			"%s external airborne motion clears landed authority" % label
		)

		var reset_transform := Transform3D(variant.global_basis, Vector3(100.0, 20.0, 0.0))
		variant.reset_for_reuse(reset_transform)
		variant.engine_start_time = 0.01
		variant.set_piloted(true)
		variant.request_engine_start()
		for _restart_tick in 2:
			await physics_frame
		var launch_origin := variant.global_position
		var launch_forward := -variant.global_basis.z.normalized()
		Input.action_press(&"move_forward")
		for _launch_tick in 12:
			await physics_frame
		Input.action_release(&"move_forward")
		var launch_offset := variant.global_position - launch_origin
		_check(
			not bool(variant.get_telemetry().get("landed", true)),
			"%s sustained W releases landed authority" % label
		)
		_check(
			launch_offset.length() > 0.01 and launch_offset.normalized().dot(launch_forward) > 0.99,
			"%s sustained W departs along its visible nose" % label
		)
		await physics_frame
		variant.queue_free()
		await process_frame
