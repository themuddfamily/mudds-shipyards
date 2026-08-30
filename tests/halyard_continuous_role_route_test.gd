extends SceneTree

## Focused embodied regression for every assigned approach in
## `halyard_multi_crew_interior_v1`. One staging placement starts at the
## exterior boarding marker; every subsequent position is reached with the real
## PlayerController's ordinary locomotion.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ROLE_CONTRACT := preload("res://scripts/fleet/multi_crew_interior_role_contract.gd")
const CREW_AUTHORITY := preload("res://scripts/ships/crew_seat_role_authority.gd")
const AUTHORITY_SEAT_GENERATION := 7
const REQUIRED_ROLE_SEATS := {
	&"pilot": &"pilot_station",
	&"co_pilot": &"co_pilot_station",
	&"navigator": &"crew_port_00",
	&"sensor_operator": &"crew_starboard_00",
	&"systems_engineer": &"crew_port_01",
	&"passenger": &"crew_starboard_01",
}
# Follow the physical cabin from its middle row to its forward row and flight
# deck, avoiding teleports or test-only shortcuts between role approaches.
const WALK_ORDER := [
	&"systems_engineer", &"passenger", &"navigator", &"sensor_operator",
	&"co_pilot", &"pilot",
]

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
	var co_pilot_anchor := craft.get_co_pilot_station_anchor()
	var crew_anchors := craft.get_crew_seat_anchors()
	var physical_anchors: Dictionary = {
		&"pilot_station": pilot_anchor,
		&"co_pilot_station": co_pilot_anchor,
	}
	for anchor in crew_anchors:
		physical_anchors[StringName(anchor.get_meta("seat_id", &""))] = anchor
	_check(
		boarding_area != null
		and boarding_area.get_ship() == craft
		and boarding_area.is_available()
		and pilot_anchor != null
		and co_pilot_anchor != null
		and crew_anchors.size() == 6
		and physical_anchors.size() == 8,
		"pilot, co-pilot and all six crew-seat anchors retain their physical authority"
	)

	var contract := ROLE_CONTRACT.get_contract()
	var role_definitions: Dictionary = {}
	var contract_mapping: Dictionary = {}
	for role_variant in contract.get("roles", []) as Array:
		var role := role_variant as Dictionary
		var role_id := StringName(role.get("role_id", &""))
		role_definitions[role_id] = role
		contract_mapping[role_id] = StringName(role.get("seat_id", &""))
	_check(
		StringName(contract.get("contract_id", &"")) == &"halyard_multi_crew_interior_v1"
		and role_definitions.size() == 6
		and contract_mapping == REQUIRED_ROLE_SEATS,
		"the test walks the exact six assigned seats from halyard_multi_crew_interior_v1"
	)
	var every_assigned_anchor_resolves := true
	for seat_id in REQUIRED_ROLE_SEATS.values():
		every_assigned_anchor_resolves = every_assigned_anchor_resolves \
			and physical_anchors.get(seat_id) is Marker3D
	_check(every_assigned_anchor_resolves,
		"all six named role assignments resolve to live production anchors")

	# Give the production ship a meaningful, sealed role ledger rather than
	# comparing two vacuous empty snapshots. These six occupants are test setup;
	# the embodied walker claims none of them.
	var authority := CREW_AUTHORITY.new(1) as CrewSeatRoleAuthority
	_check(
		bool(authority.register_halyard_roster(
			&"halyard_new_design", &"halyard_walkable_interior", AUTHORITY_SEAT_GENERATION
		).get("accepted", false))
		and bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"one sealed production CrewSeatRoleAuthority attaches to Halyard"
	)
	var registered_snapshot := authority.get_snapshot()
	var authority_role_by_seat: Dictionary = {}
	for seat_variant in registered_snapshot.get("seats", []) as Array:
		var seat := seat_variant as Dictionary
		authority_role_by_seat[StringName(seat.get("seat_id", &""))] = \
			StringName(seat.get("role", &""))
	var claim_index := 0
	var all_profile_claims_accepted := true
	for role_id in REQUIRED_ROLE_SEATS:
		var seat_id := REQUIRED_ROLE_SEATS[role_id] as StringName
		var claimed := authority.claim(
			1,
			101 + claim_index,
			StringName("route_%s" % str(role_id)),
			seat_id,
			StringName(authority_role_by_seat.get(seat_id, &"")),
			1
		)
		all_profile_claims_accepted = all_profile_claims_accepted \
			and bool(claimed.get("accepted", false))
		claim_index += 1
	var authority_before := authority.get_snapshot()
	var assignments_before := (
		authority_before.get("assignments", []) as Array
	).duplicate(true)
	var generations_before := _seat_generations(authority_before)
	_check(
		all_profile_claims_accepted
		and assignments_before.size() == 6
		and _assignment_seat_ids(assignments_before) \
			== _sorted_seat_ids(REQUIRED_ROLE_SEATS.values()),
		"all six profile seats have concrete authoritative assignments before walking"
	)
	_check(
		generations_before.size() == 8
		and _all_generations_match(generations_before, AUTHORITY_SEAT_GENERATION),
		"all eight physical seats begin at the snapshotted generation 7"
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

	var deck_report := await _walk_to(
		player, craft, craft.get_interior_deck_marker().position, 360
	)
	_check(
		bool(deck_report.get("reached", false)) and bool(deck_report.get("grounded", false)),
		"normal locomotion crosses the airstair onto the grounded moving cabin deck"
	)
	var anchor_locals: Dictionary = {}
	var targets: Dictionary = {}
	for role_id in REQUIRED_ROLE_SEATS:
		var seat_id := REQUIRED_ROLE_SEATS[role_id] as StringName
		var anchor := physical_anchors[seat_id] as Marker3D
		var anchor_local := craft.to_local(anchor.global_position)
		anchor_locals[role_id] = anchor_local
		targets[role_id] = (
			anchor_local + Vector3(0.0, 0.3, 0.9)
			if role_id == &"pilot" or role_id == &"co_pilot"
			else Vector3(signf(anchor_local.x) * 0.45, 0.5, anchor_local.z)
		)

	var reports: Array[Dictionary] = []
	for role_id in WALK_ORDER:
		var role := role_definitions[role_id] as Dictionary
		var report := await _walk_to(player, craft, targets[role_id], 360)
		report["role_id"] = role_id
		report["display_name"] = String(role.get("display_name", str(role_id)))
		report["seat_id"] = REQUIRED_ROLE_SEATS[role_id]
		reports.append(report)
		_check(
			bool(report.get("reached", false)) and bool(report.get("grounded", false)),
			"normal locomotion reaches the grounded %s approach (%s)" % [
				String(report.display_name), str(report.seat_id),
			]
		)

	for report in reports:
		var role_id := StringName(report.get("role_id", &""))
		var final := report.get("final", Vector3.ZERO) as Vector3
		var anchor_local := anchor_locals[role_id] as Vector3
		_check(
			Vector2(final.x, final.z).distance_to(
				Vector2(anchor_local.x, anchor_local.z)
			) < 1.15,
			"%s finishes within normal approach distance of its assigned live seat anchor"
				% String(report.display_name)
		)

	var authority_after := authority.get_snapshot()
	_check(
		(authority_after.get("assignments", []) as Array) == assignments_before,
		"normal traversal preserves every crew-role authority assignment exactly"
	)
	_check(
		_seat_generations(authority_after) == generations_before,
		"normal traversal preserves every physical seat generation exactly"
	)
	_check(
		int(authority_after.get("event_sequence", -1))
			== int(authority_before.get("event_sequence", -2)),
		"walking emits no hidden seat claim, release, handoff or intent event"
	)
	var moving_frame := craft.get_moving_interior_component()
	_check(
		moving_frame != null
		and moving_frame.is_occupant_registered(player)
		and player.is_on_floor(),
		"the complete six-role walk remains supported and registered to Halyard's moving interior"
	)
	_check(
		not player.is_seated()
		and not craft.is_piloted()
		and boarding_area.get_ship() == craft
		and craft.get_crew_role_authority() == authority,
		"route traversal bypasses neither boarding nor the one attached seat authority"
	)

	print(
		"HALYARD_CONTINUOUS_ROLE_ROUTE: contract=", contract.contract_id,
		" anchors=", anchor_locals, " reports=", reports,
		" assignments=", assignments_before, " generations=", generations_before
	)
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


func _seat_generations(snapshot: Dictionary) -> Dictionary:
	var generations: Dictionary = {}
	for seat_variant in snapshot.get("seats", []) as Array:
		var seat := seat_variant as Dictionary
		generations[StringName(seat.get("seat_id", &""))] = \
			int(seat.get("seat_generation", 0))
	return generations


func _all_generations_match(generations: Dictionary, expected: int) -> bool:
	for value in generations.values():
		if int(value) != expected:
			return false
	return true


func _assignment_seat_ids(assignments: Array) -> Array[StringName]:
	var seat_ids: Array[StringName] = []
	for assignment_variant in assignments:
		seat_ids.append(StringName((assignment_variant as Dictionary).get("seat_id", &"")))
	seat_ids.sort()
	return seat_ids


func _sorted_seat_ids(values: Array) -> Array[StringName]:
	var seat_ids: Array[StringName] = []
	for value in values:
		seat_ids.append(StringName(value))
	seat_ids.sort()
	return seat_ids


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
