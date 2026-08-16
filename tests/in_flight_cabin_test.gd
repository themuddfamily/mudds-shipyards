extends SceneTree

## Focused regression for leaving the pilot seat away from a berth and walking a
## craft's cabin under way.
##
## `modern_interpretation`. Nothing here asserts, implies, or depends on any
## historical craft behaviour; it is a modern design decision about this fleet.
##
## Behaviour groups, each with at least one structured-red mutation the suite
## proves turns the production behaviour red:
##
##   A. craft contract — which craft may offer the cabin at all, and on what
##      geometry. Red: withdraw the interior and the offer must withdraw with it.
##   B. cabin containment — the anti-stranding envelope. Red: clear containment
##      and the identical displacement is *not* recovered.
##   C. frame-relative seat transitions — the exit pose belongs to the craft.
##      Red: the same exit against a world-space pose strands the body where the
##      craft used to be.
##
## Every wait is a bounded frame count on the fixed physics step. Nothing here
## reads a wall clock.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Deck plates the confinement envelope has to enclose, in ship-local space.
## Sampled from the craft's own colliders rather than restated as numbers, so a
## deck that moves cannot silently escape the envelope that protects it.
const WALKABLE_DECK_COLLIDERS := [
	"CargoDeckCollision",
	"PassengerDeckCollision",
	"CockpitDeckCollision",
]

var _failures: Array[String] = []
var _assertion_count := 0
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	_test_root = Node3D.new()
	_test_root.name = "InFlightCabinTestRoot"
	root.add_child(_test_root)

	await _test_craft_contract()
	await _test_cabin_containment()
	await _test_frame_relative_seat_transitions()

	_test_root.queue_free()
	_test_root = null
	await process_frame
	await physics_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"every cabin fixture cleans up without leaving scene nodes behind"
	)
	_finish()


# ---------------------------------------------------------------- group A ----


func _test_craft_contract() -> void:
	var fighters := {
		"Torrent": TORRENT_SCENE,
		"Arrow": ARROW_SCENE,
		"Zenith": ZENITH_SCENE,
	}
	for craft_name: String in fighters:
		var fighter := (fighters[craft_name] as PackedScene).instantiate() as HeroShip
		_test_root.add_child(fighter)
		await process_frame
		await physics_frame
		var report := fighter.get_in_flight_cabin_report()
		_check(
			not bool(report.get("supported", false))
			and not fighter.supports_in_flight_cabin_access(),
			"%s has no walkable cabin and refuses to release its pilot in space" % craft_name
		)
		_check(
			(report.get("local_bounds", AABB()) as AABB).size.is_zero_approx(),
			"%s publishes no confinement envelope, so nothing can confine a pilot to open space" % craft_name
		)
		fighter.queue_free()
		await process_frame

	var jovian := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	_test_root.add_child(jovian)
	await process_frame
	await physics_frame
	await physics_frame

	var cabin := jovian.get_in_flight_cabin_report()
	_check(
		bool(cabin.get("supported", false)) and jovian.supports_in_flight_cabin_access(),
		"the freighter's connected walkable interior does offer in-flight cabin access"
	)
	_check(
		cabin.get("frame") == jovian.get_moving_interior_component(),
		"the cabin contract hands back the craft's own occupancy coordinator, not a second one"
	)

	var bounds := cabin.get("local_bounds", AABB()) as AABB
	var stand := cabin.get("stand_transform", Transform3D.IDENTITY) as Transform3D
	var stand_local := jovian.global_transform.affine_inverse() * stand.origin
	_check(
		bounds.has_point(stand_local),
		"the standing pose the pilot arrives at is inside the confinement envelope"
	)
	# The envelope has to cover every deck plate a crew member can stand on, or
	# containment would fight the floor instead of the hull opening.
	for collider_name: String in WALKABLE_DECK_COLLIDERS:
		var collider := jovian.get_node_or_null(collider_name) as CollisionShape3D
		_check(collider != null, "%s exists as a physical deck plate" % collider_name)
		if collider == null:
			continue
		var box := collider.shape as BoxShape3D
		_check(box != null, "%s is a box deck plate" % collider_name)
		if box == null:
			continue
		var half := box.size * 0.5
		var top := collider.position + Vector3(0.0, half.y, 0.0)
		var footprint := AABB(
			Vector3(top.x - half.x, top.y, top.z - half.z),
			Vector3(half.x * 2.0, 0.01, half.z * 2.0)
		)
		_check(
			bounds.encloses(AABB(footprint.position, Vector3(footprint.size.x, 0.0, footprint.size.z))),
			"the confinement envelope encloses the whole %s walking surface" % collider_name
		)

	# The flight deck is walkable now, so it must be enclosed by real geometry
	# rather than by the containment guard alone.
	_check(
		jovian.get_node_or_null("CockpitForwardWallCollision") is CollisionShape3D,
		"the flight deck has a physical forward wall a crew member cannot walk off"
	)
	var cockpit_sidewalls := 0
	for child in jovian.get_children():
		if child is CollisionShape3D and str(child.name).ends_with("CockpitSidewallCollision"):
			cockpit_sidewalls += 1
	_check(cockpit_sidewalls == 2, "the flight deck has physical port and starboard walls")

	# Structured red: the offer is derived from the live occupancy coordinator,
	# not asserted. Unbinding the coordinator must withdraw it.
	var coordinator := jovian.get_moving_interior_component()
	var occupant_volume := coordinator.get_occupant_volume()
	coordinator.set_moving_frame(null)
	await process_frame
	_check(
		not jovian.supports_in_flight_cabin_access(),
		"RED: a freighter whose occupancy coordinator is unbound withdraws the cabin offer"
	)
	coordinator.configure(jovian, JovianLightFreighter.INTERIOR_BOUNDS, occupant_volume)
	await process_frame
	await physics_frame
	_check(
		jovian.supports_in_flight_cabin_access(),
		"restoring the coordinator restores the cabin offer"
	)

	# Structured red: a destroyed cabin is not a cabin.
	jovian.apply_damage(jovian.maximum_hull + 1.0, jovian.global_position, Vector3.UP)
	await process_frame
	await physics_frame
	_check(
		jovian.is_destroyed() and not jovian.supports_in_flight_cabin_access(),
		"RED: a destroyed freighter refuses to release a pilot into its wreck"
	)

	jovian.queue_free()
	await process_frame


# ---------------------------------------------------------------- group B ----


func _test_cabin_containment() -> void:
	var fixture := await _make_containment_fixture()
	var frame := fixture["frame"] as Node3D
	var player := fixture["player"] as PlayerController
	var bounds := fixture["bounds"] as AABB

	_check(player.is_cabin_containment_active(), "containment binds to the supplied frame")
	_check(
		bool(player.get_cabin_containment_report().get("contained", false)),
		"a body that starts inside the envelope reports contained"
	)

	# A body driven hard at the open side is stopped at the envelope, not past it.
	for _push_tick in 90:
		player.velocity = frame.global_basis.x * -40.0
		await physics_frame
	var pushed := player.get_cabin_containment_report()
	_check(
		bool(pushed.get("contained", false)),
		"a body driven at the open side of the envelope is held inside it"
	)
	_check(
		int(pushed.get("clamp_count", 0)) > 0,
		"holding the body inside is recorded as a clamp rather than happening silently"
	)
	_check(
		(pushed.get("local_position", Vector3.INF) as Vector3).x >= bounds.position.x,
		"the clamped body never crosses the envelope's open face"
	)

	# A body displaced clean out of the craft is returned bodily.
	var recalls_before := int(player.get_cabin_containment_report().get("recall_count", 0))
	player.global_position += frame.global_basis.x * -140.0
	for _recall_tick in 4:
		await physics_frame
	var recalled := player.get_cabin_containment_report()
	_check(
		bool(recalled.get("contained", false))
		and int(recalled.get("recall_count", 0)) > recalls_before,
		"a body displaced clean outside the craft is recalled into the cabin"
	)
	_check(
		(recalled.get("local_position", Vector3.INF) as Vector3).distance_to(
			fixture["recall_local_origin"] as Vector3
		) < 0.35,
		"the recall lands the body on the published standing pose, not an arbitrary point"
	)

	# Falling out of the bottom of the craft is a floor failure, not a doorway
	# nudge: it must recall rather than clamp the capsule inside the deck.
	var below_recalls := int(player.get_cabin_containment_report().get("recall_count", 0))
	player.global_position += frame.global_basis.y * -6.0
	for _drop_tick in 4:
		await physics_frame
	_check(
		int(player.get_cabin_containment_report().get("recall_count", 0)) > below_recalls
		and bool(player.get_cabin_containment_report().get("contained", false)),
		"a body that ends up below the deck plane is recalled rather than clamped into it"
	)

	# The envelope travels with the craft, so a moving hull cannot leave it behind.
	var carried_local := (player.get_cabin_containment_report().get("local_position", Vector3.INF) as Vector3)
	for _travel_tick in 30:
		frame.global_position += frame.global_basis.z * -4.0
		player.global_position += frame.global_basis.z * -4.0
		await physics_frame
	var travelled := player.get_cabin_containment_report()
	_check(
		bool(travelled.get("contained", false))
		and (travelled.get("local_position", Vector3.INF) as Vector3).distance_to(carried_local) < 1.0,
		"containment is evaluated against the live craft, so travel alone never violates it"
	)

	# Structured red: containment is what does this. Without it the identical
	# displacement leaves the body outside the craft, permanently.
	player.clear_cabin_containment()
	_check(not player.is_cabin_containment_active(), "containment can be released")
	var escape_origin := player.global_position
	player.global_position += frame.global_basis.x * -140.0
	for _escape_tick in 8:
		await physics_frame
	var escaped_local := frame.global_transform.affine_inverse() * player.global_position
	_check(
		not bounds.has_point(escaped_local)
		and player.global_position.distance_to(escape_origin) > 100.0,
		"RED: with containment released the same displacement leaves the body outside the craft"
	)

	await _free_containment_fixture(fixture)


func _make_containment_fixture() -> Dictionary:
	# A plain kinematic-free frame with one deck plate. Deliberately not a ship:
	# containment is a controller behaviour and must not need one.
	var frame := Node3D.new()
	frame.name = "ContainmentFrame"
	_test_root.add_child(frame)
	frame.global_transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(37.0)),
		Vector3(120.0, 60.0, -240.0)
	)
	var deck := StaticBody3D.new()
	deck.name = "ContainmentDeck"
	deck.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	deck.collision_mask = PhysicsLayers.WORLD_BODY_MASK
	frame.add_child(deck)
	var deck_shape := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	# Deliberately wider than the envelope, so a body pushed at the envelope's
	# open face is stopped by containment and not by running out of floor.
	deck_box.size = Vector3(30.0, 0.4, 30.0)
	deck_shape.shape = deck_box
	deck_shape.position = Vector3(0.0, -0.2, 0.0)
	deck.add_child(deck_shape)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	await process_frame
	await physics_frame
	# Locomotion input is irrelevant to containment and would make the fixture
	# depend on whatever the host's key state happens to be.
	player.set_control_enabled(false)
	player.set_camera_active(false)
	var stand := Transform3D(frame.global_basis.orthonormalized(), frame.global_position)
	player.teleport_to(stand)
	for _settle_tick in 12:
		await physics_frame

	var bounds := AABB(Vector3(-6.0, -0.6, -6.0), Vector3(12.0, 6.0, 12.0))
	player.set_cabin_containment(frame, bounds, stand)
	await physics_frame
	return {
		"frame": frame,
		"player": player,
		"bounds": bounds,
		"recall_local_origin": frame.global_transform.affine_inverse() * stand.origin,
	}


func _free_containment_fixture(fixture: Dictionary) -> void:
	(fixture["player"] as Node).queue_free()
	(fixture["frame"] as Node).queue_free()
	await process_frame
	await physics_frame


# ---------------------------------------------------------------- group C ----


func _test_frame_relative_seat_transitions() -> void:
	var travelled := await _run_seat_transition(true)
	_check(
		float(travelled["exit_error"]) < 0.35,
		"a seat exit bound to its craft lands on the craft's own exit pose while it travels"
	)
	_check(
		float(travelled["frame_travel"]) > 20.0,
		"the craft really did travel during that exit"
	)

	# Structured red: the same exit taken as a world-space pose is left behind by
	# exactly the distance the craft covered — the soft-lock this feature avoids.
	var stranded := await _run_seat_transition(false)
	_check(
		float(stranded["exit_error"]) > 10.0,
		"RED: a world-space seat exit strands the body where the craft used to be"
	)
	_check(
		absf(float(stranded["exit_error"]) - float(stranded["frame_travel"])) < 1.0,
		"RED: the stranding distance is the distance the craft covered, to within a frame of travel"
	)


## Boards then exits a seat carried by a moving frame. Returns how far the body
## finished from the craft's live exit pose, and how far the craft travelled.
func _run_seat_transition(bind_to_frame: bool) -> Dictionary:
	var frame := Node3D.new()
	frame.name = "SeatTransitionFrame"
	_test_root.add_child(frame)
	frame.global_transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-64.0)),
		Vector3(-300.0, 90.0, 410.0)
	)
	var seat := Marker3D.new()
	seat.name = "SeatAnchor"
	seat.position = Vector3(0.0, 0.6, -1.4)
	frame.add_child(seat)
	var exit_marker := Marker3D.new()
	exit_marker.name = "ExitAnchor"
	exit_marker.position = Vector3(0.0, 0.0, 1.8)
	frame.add_child(exit_marker)

	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	await process_frame
	await physics_frame
	player.set_control_enabled(false)
	player.set_camera_active(false)
	player.teleport_to(Transform3D(frame.global_basis.orthonormalized(), frame.global_position))

	player.begin_boarding(seat.global_transform, seat, 0.0)
	await player.boarding_completed
	_check(player.is_seated(), "the fixture body reaches the seat before the exit is measured")

	var start_origin := frame.global_position
	var landed := [false]
	player.disembarking_completed.connect(
		func() -> void: landed[0] = true,
		CONNECT_ONE_SHOT
	)
	player.begin_disembark(
		exit_marker.global_transform,
		0.3,
		frame if bind_to_frame else null
	)
	var travel_step := frame.global_basis.z * -1.6
	var guard := 0
	while not bool(landed[0]) and guard < 240:
		frame.global_position += travel_step
		await physics_frame
		guard += 1
	_check(bool(landed[0]), "the fixture seat exit completes within its frame budget")

	var result := {
		"exit_error": player.global_position.distance_to(exit_marker.global_position),
		"frame_travel": frame.global_position.distance_to(start_origin),
	}
	player.queue_free()
	frame.queue_free()
	await process_frame
	await physics_frame
	return result


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("IN_FLIGHT_CABIN_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"IN_FLIGHT_CABIN_TEST_FAILED: %d/%d assertions failed: %s"
			% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
