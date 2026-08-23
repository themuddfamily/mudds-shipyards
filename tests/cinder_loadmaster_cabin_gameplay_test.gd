extends SceneTree

## Focused production check for Cinder's embodied cargo cabin. The shell keeps
## the original outer bounds, while a split port collision leaves one reachable
## no-jump route to the physical loadmaster station. Role receipts remain
## caller-owned proposals and never transfer cargo, rewards or flight control.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

var _assertions := 0
var _failures: Array[String] = []
var _craft: CinderCargoHauler


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_craft = Hauler.new() as CinderCargoHauler
	root.add_child(_craft)
	var craft := _craft
	await process_frame
	await physics_frame
	await physics_frame

	var cabin := craft.get_in_flight_cabin_report()
	_check(bool(cabin.get("supported", false)), "Cinder publishes a live walkable cabin contract")
	_check(cabin.get("frame") == craft.get_moving_interior_component(), "the cabin uses one ship-owned MovingInteriorFrame")
	_check(craft.get_moving_interior_component() != null, "the moving interior coordinator is present")
	_check(craft.get_loadmaster_station_anchor() != null, "the loadmaster station is a physical anchor")
	_check(craft.get_loadmaster_station_anchor().get_meta("seat_type", &"") == &"physical", "the station is not a marker-only role")

	var shell_names := [
		"CargoHullFloor", "CargoHullRoof", "CargoHullStarboardWall",
		"CargoHullPortWallForward", "CargoHullPortWallAft",
		"CargoHullNoseWall", "CargoHullTailWall",
	]
	for shell_name: String in shell_names:
		_check(craft.get_node_or_null(shell_name) is CollisionShape3D, "%s is a physical shell collision" % shell_name)

	var access := craft.get_node(^"WalkableInterior/CargoCabinAccessMarker") as Marker3D
	var exit := craft.get_node(^"WalkableInterior/CargoCabinExitMarker") as Marker3D
	var station := craft.get_loadmaster_station_anchor()
	var route_points: Array[Vector3] = [
		craft.get_boarding_marker().global_position,
		access.global_position,
		station.global_position,
		exit.global_position,
	]
	for index in route_points.size():
		var point := route_points[index]
		var floor_hit := _ray(point + Vector3.UP * 0.9, point + Vector3.DOWN * 1.8)
		_check(not floor_hit.is_empty(), "route point %d has a physical floor below it" % index)
	_check(
		_ray(route_points[0] + Vector3.UP * 0.15, route_points[1] + Vector3.UP * 0.15).is_empty(),
		"the port aperture has no blocking shell across the boarding route"
	)
	_check(
		_ray(route_points[1] + Vector3.UP * 0.15, route_points[2] + Vector3.UP * 0.15).is_empty(),
		"the cabin aisle reaches the loadmaster station without a jump"
	)

	var occupant := CharacterBody3D.new()
	occupant.name = "CinderCabinTestOccupant"
	root.add_child(occupant)
	occupant.global_position = station.global_position
	await physics_frame
	var frame := craft.get_moving_interior_component()
	var registered := frame.register_occupant(occupant, {"require_inside_bounds": true, "rotate_basis": true})
	_check(bool(registered.get("registered", false)), "a physical occupant registers with the cabin frame")
	_check(frame.get_occupant_count() == 1, "cabin occupancy is owned by MovingInteriorFrame")
	var unregistered := frame.unregister_occupant(occupant, true, &"test_disembark")
	_check(bool(unregistered.get("released", false)), "the same occupant can disembark through the route")
	_check(frame.get_occupant_count() == 0, "disembark clears frame occupancy exactly once")

	var authority := Authority.new(1)
	for seat_record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		var seat_id := StringName(seat_record[0])
		var role := StringName(seat_record[1])
		var registered_seat := authority.register_seat(
			seat_id,
			Hauler.COMPONENT_ID,
			role,
			&"cinder_cargo_walkable_interior",
			1,
			Hauler.LOADMASTER_STATION_SEAT_ID if seat_id == Hauler.LOADMASTER_STATION_SEAT_ID else seat_id
		)
		_check(bool(registered_seat.get("accepted", false)), "the authority registers Cinder %s role" % role)
	_check(bool(authority.seal_roster().get("accepted", false)), "the one-seat Cinder roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "Cinder accepts only its physical role roster")
	_check(
		bool(authority.claim(
			1, 62, &"cinder_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the loadmaster occupant claims the physical station"
	)
	var receipt := craft.submit_crew_intent(
		1, 62, &"cinder_loadmaster", RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"cinder_manifest", "route_id": &"dock_04_cargo", "ready": true}, 2
	)
	_check(
		bool(receipt.get("consumed", false))
			and (receipt.get("effect", {}) as Dictionary).get("receipt", {}).get("manifest_id", &"") == &"cinder_manifest"
			and not craft.get_loadmaster_manifest_snapshot().get("cargo_transfer_authority", true),
		"the admitted loadmaster receipt records readiness without cargo authority"
	)
	var released := craft.release_crew_role(1, 62, &"cinder_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, 3, 1)
	_check(bool(released.get("accepted", false)), "role release clears the physical station assignment")
	_check(craft.get_loadmaster_manifest_snapshot().get("receipt", {}).is_empty(), "role release clears the old manifest receipt")
	_check(int(craft.get_loadmaster_manifest_snapshot().get("manifest_generation", 0)) == 2, "role release advances manifest generation")

	var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(12.0, 0.0, 4.0)))
	_check(bool(reset.get("accepted", false)), "Cinder reset preserves the reusable cabin lifecycle")
	_check(craft.get_moving_interior_component().get_occupant_count() == 0, "reset leaves no stale cabin occupants")
	_check(craft.get_loadmaster_manifest_snapshot().get("receipt", {}).is_empty(), "reset leaves no stale loadmaster receipt")
	_check(int(craft.get_loadmaster_manifest_snapshot().get("manifest_generation", 0)) == 1, "re-entry resets manifest generation")

	occupant.queue_free()
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_LOADMASTER_CABIN_GAMEPLAY_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	return _craft.get_world_3d().direct_space_state.intersect_ray(query)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
