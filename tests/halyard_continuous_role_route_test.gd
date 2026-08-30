extends SceneTree

## Focused embodied regression for Halyard's production route. One staging
## placement starts at the exterior boarding marker; every subsequent position
## is reached with the real PlayerController's ordinary locomotion.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node_or_null(^"Player") as PlayerController
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var craft := game.get_node_or_null(^"HalyardCrewTransport") as HalyardCrewTransport
	_check(player != null and world != null and craft != null,
		"production player, world and Halyard are live")
	if player == null or world == null or craft == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var berth := world.get_berth_node(craft.get_home_berth_id())
	_check(
		berth != null
		and berth.get_occupant() == craft
		and craft.global_transform.is_equal_approx(
			world.get_berth_transform(craft.get_home_berth_id())
		),
		"the walk uses Halyard at its occupied production berth"
	)
	var boarding_area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	var pilot_anchor := craft.get_pilot_seat_anchor()
	var gunner_anchor := craft.get_co_pilot_station_anchor()
	var crew_anchors := craft.get_crew_seat_anchors()
	var crew_by_id: Dictionary = {}
	for anchor in crew_anchors:
		crew_by_id[StringName(anchor.get_meta("seat_id", &""))] = anchor
	_check(
		boarding_area != null
		and boarding_area.get_ship() == craft
		and boarding_area.is_available()
		and pilot_anchor != null
		and gunner_anchor != null
		and crew_anchors.size() == 6
		and crew_by_id.size() == 6,
		"one pilot, one gunner and all six crew-seat anchors retain their authority"
	)
	_check(
		crew_by_id.has(&"crew_port_01")
		and crew_by_id.has(&"crew_starboard_00"),
		"the engineer and representative passenger route anchors resolve"
	)

	game.start_shift()
	await process_frame
	player.teleport_to(Transform3D(
		craft.global_basis.orthonormalized(),
		craft.get_boarding_position() + craft.global_basis.y.normalized() * 0.01
	))
	for _index in 12:
		await physics_frame
	_check(
		player.is_on_floor()
		and craft.to_local(player.global_position).distance_to(
			craft.to_local(craft.get_boarding_position())
		) < 0.03
		and game.boarding_candidate == craft,
		"the real player begins grounded with Halyard available at its exterior boarding point"
	)

	var engineer_anchor := crew_by_id[&"crew_port_01"] as Marker3D
	var passenger_anchor := crew_by_id[&"crew_starboard_00"] as Marker3D
	var anchor_locals := {
		&"engineer": craft.to_local(engineer_anchor.global_position),
		&"passenger": craft.to_local(passenger_anchor.global_position),
		&"gunner": craft.to_local(gunner_anchor.global_position),
		&"pilot": craft.to_local(pilot_anchor.global_position),
	}
	# Crew-seat approaches stay on the central aisle beside each chair. Flight-
	# deck approaches stand aft of each forward-facing seat on the same deck.
	var targets := [
		[&"cabin_deck", craft.get_interior_deck_marker().position],
		[&"engineer", Vector3(-0.45, 0.5, (anchor_locals[&"engineer"] as Vector3).z)],
		[&"passenger", Vector3(0.45, 0.5, (anchor_locals[&"passenger"] as Vector3).z)],
		[&"gunner", (anchor_locals[&"gunner"] as Vector3) + Vector3(0.0, 0.3, 0.9)],
		[&"pilot", (anchor_locals[&"pilot"] as Vector3) + Vector3(0.0, 0.3, 0.9)],
	]
	var reports: Array[Dictionary] = []
	for target_spec in targets:
		var report := await _walk_to(player, craft, target_spec[1], 360)
		report["id"] = target_spec[0]
		reports.append(report)
		_check(
			bool(report.get("reached", false)) and bool(report.get("grounded", false)),
			"normal locomotion reaches the grounded %s approach" % str(target_spec[0])
		)

	for report in reports:
		var role_id := StringName(report.get("id", &""))
		if not anchor_locals.has(role_id):
			continue
		var final := report.get("final", Vector3.ZERO) as Vector3
		var anchor_local := anchor_locals[role_id] as Vector3
		_check(
			Vector2(final.x, final.z).distance_to(
				Vector2(anchor_local.x, anchor_local.z)
			) < 1.15,
			"%s approach finishes within normal reading/interaction distance of its live seat anchor"
				% str(role_id)
		)

	var moving_frame := craft.get_moving_interior_component()
	_check(
		moving_frame != null
		and moving_frame.is_occupant_registered(player)
		and player.is_on_floor(),
		"the complete branched walk remains supported and registered to Halyard's moving interior"
	)
	_check(
		not player.is_seated()
		and not craft.is_piloted()
		and boarding_area.get_ship() == craft
		and craft.get_crew_seat_anchors().size() == 6,
		"route traversal does not claim, remove or replace any boarding or seat authority"
	)

	print("HALYARD_CONTINUOUS_ROLE_ROUTE: anchors=", anchor_locals, " reports=", reports)
	game.queue_free()
	await process_frame
	_finish()


func _walk_to(
		player: PlayerController,
		craft: HalyardCrewTransport,
		target_local: Vector3,
		frame_budget: int
	) -> Dictionary:
	var camera_yaw := player.get_node(^"CameraRig/CameraYaw") as Node3D
	var closest := INF
	var grounded := true
	var walked := 0
	for _index in frame_budget:
		var local := craft.to_local(player.global_position)
		var delta := Vector2(target_local.x - local.x, target_local.z - local.z)
		closest = minf(closest, delta.length())
		if delta.length() < 0.22:
			break
		# Turning the existing camera yaw and pressing the production forward
		# action is equivalent to ordinary mouse-look locomotion; no body transform
		# is written anywhere after the exterior staging placement.
		camera_yaw.rotation.y = atan2(-delta.x, -delta.y)
		Input.action_press(&"move_forward")
		await physics_frame
		walked += 1
		grounded = grounded and player.is_on_floor()
	Input.action_release(&"move_forward")
	for _index in 5:
		await physics_frame
		grounded = grounded and player.is_on_floor()
	var final := craft.to_local(player.global_position)
	return {
		"reached": Vector2(final.x - target_local.x, final.z - target_local.z).length() < 1.0,
		"grounded": grounded,
		"frames": walked,
		"closest": closest,
		"target": target_local,
		"final": final,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	Input.action_release(&"move_forward")
	if _failures.is_empty():
		print("halyard_continuous_role_route_test: %d assertions" % _assertions)
		quit(0)
	else:
		print("HALYARD_CONTINUOUS_ROLE_ROUTE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
