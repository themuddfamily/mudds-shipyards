extends SceneTree

## Focused embodied interaction contract: public ShipBoardingArea discovery and
## the reachable loadmaster Area3D both delegate identity/generation/occupancy
## to CrewSeatRoleAuthority without taking input, cargo or flight authority.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame
	await physics_frame

	var boarding := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(boarding != null, "Cinder exposes the shared public ShipBoardingArea")
	_check(boarding != null and boarding.get_ship() == craft, "boarding resolves its physical Cinder owner")
	_check(boarding != null and boarding.is_available(), "the boarding aperture is available through the public flow")
	_check(boarding != null and boarding.get_prompt().contains("BOARD CINDER"), "boarding publishes the authored Cinder prompt")

	var interaction := craft.get_loadmaster_interaction()
	_check(interaction != null, "the loadmaster station exposes a ship-owned Area3D interaction")
	_check(interaction != null and interaction.get_seat_id() == Hauler.LOADMASTER_STATION_SEAT_ID, "the interaction names the exact physical seat")
	_check(interaction != null and interaction.get_seat_generation() == 1, "the interaction publishes the current seat generation")
	_check(interaction != null and interaction.get_node_or_null(^"InteractionShape") is CollisionShape3D, "the station interaction has a physical range shape")

	var authority := Authority.new(1)
	for seat_record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		var seat_id := StringName(seat_record[0])
		var role := StringName(seat_record[1])
		_check(
			bool(authority.register_seat(
				seat_id,
				Hauler.COMPONENT_ID,
				role,
				&"cinder_cargo_walkable_interior",
				1,
				seat_id
			).get("accepted", false)),
			"the authority registers Cinder %s" % role
		)
	_check(bool(authority.seal_roster().get("accepted", false)), "the authority roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the station binds to the injected authority")

	var actor := CharacterBody3D.new()
	actor.name = "CinderLoadmasterActor"
	root.add_child(actor)
	actor.global_position = interaction.global_position + Vector3(0.0, 0.0, 2.0)
	var out_of_range := interaction.try_claim(actor, 1, 73, &"interaction_loadmaster", 1)
	_check(not bool(out_of_range.get("accepted", true)) and out_of_range.get("status", &"") == &"interaction_out_of_range", "the station rejects an out-of-range actor")
	actor.global_position = interaction.global_position
	craft.get_loadmaster_station_anchor().set_meta(&"seat_generation", 2)
	var stale_generation := interaction.try_claim(actor, 1, 73, &"interaction_loadmaster", 1)
	_check(
		not bool(stale_generation.get("accepted", true))
			and stale_generation.get("status", &"") == &"stale_seat_generation",
		"a generation-one interaction cannot claim a generation-two seat"
	)
	craft.get_loadmaster_station_anchor().set_meta(&"seat_generation", 1)
	var claimed := interaction.try_claim(actor, 1, 73, &"interaction_loadmaster", 1)
	_check(bool(claimed.get("accepted", false)), "the in-range station interaction delegates an atomic authority claim")
	_check(
		StringName((authority.get_assignment(73, &"interaction_loadmaster")).get("seat_id", &"")) == Hauler.LOADMASTER_STATION_SEAT_ID,
		"the claim records the exact Cinder seat in the shared ledger"
	)
	_check(not interaction.is_available(), "the station interaction closes while its authority assignment is occupied")
	var wrong_actor := CharacterBody3D.new()
	root.add_child(wrong_actor)
	var wrong_release := interaction.release(wrong_actor, 1, 73, &"interaction_loadmaster", 2)
	_check(not bool(wrong_release.get("accepted", true)), "a different actor cannot release the station")

	var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, -4.0)))
	_check(bool(reset.get("accepted", false)), "Cinder reset completes through the existing lifecycle")
	_check(authority.get_assignment(73, &"interaction_loadmaster").is_empty(), "reset releases the physical authority assignment")
	_check(interaction.is_available(), "reset leaves a clean re-entry interaction")
	_check(boarding.is_available(), "reset leaves the public boarding area available")
	var fresh_actor := CharacterBody3D.new()
	fresh_actor.name = "CinderLoadmasterFreshActor"
	root.add_child(fresh_actor)
	fresh_actor.global_position = interaction.global_position
	var fresh_claim := interaction.try_claim(fresh_actor, 1, 74, &"interaction_loadmaster_fresh", 1)
	_check(bool(fresh_claim.get("accepted", false)), "a fresh generation can claim after reset cleanup")
	var released := interaction.release(fresh_actor, 1, 74, &"interaction_loadmaster_fresh", 2)
	_check(bool(released.get("accepted", false)), "the fresh owner releases through the interaction seam")
	_check(interaction.is_available(), "release reopens the station interaction")
	_check(authority.get_assignment(74, &"interaction_loadmaster_fresh").is_empty(), "release removes the fresh authority assignment exactly once")

	wrong_actor.queue_free()
	actor.queue_free()
	fresh_actor.queue_free()
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_LOADMASTER_INTERACTION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
