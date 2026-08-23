extends SceneTree

## Focused embodied navigator contract: a physical Cinder station delegates
## occupancy and one bounded passenger ping to CrewSeatRoleAuthority without
## granting movement, cargo, combat, or world-marker authority.

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

	var interaction := craft.get_navigator_interaction()
	var anchor := craft.get_navigator_station_anchor()
	_check(interaction != null, "Cinder exposes a ship-owned navigator Area3D interaction")
	_check(anchor != null, "the navigator station exposes a physical anchor")
	_check(interaction != null and interaction.get_seat_id() == Hauler.NAVIGATOR_STATION_SEAT_ID, "the interaction names the stable navigator seat")
	_check(interaction != null and interaction.get_seat_generation() == 1, "the navigator interaction publishes generation one")
	_check(interaction != null and interaction.get_node_or_null(^"InteractionShape") is CollisionShape3D, "the navigator interaction has a physical range shape")
	_check(anchor != null and StringName(anchor.get_meta(&"route_id", &"")) == Hauler.NAVIGATOR_ROUTE_ID, "the station publishes its authored cabin route")

	var authority := Authority.new(1)
	for seat_record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
		[Hauler.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
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
	_check(bool(authority.seal_roster().get("accepted", false)), "the navigator roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the navigator station binds to the injected authority")
	_check(interaction.is_available(), "the navigator interaction opens only with its authority seat registered")

	var actor := CharacterBody3D.new()
	actor.name = "CinderNavigatorActor"
	root.add_child(actor)
	actor.global_position = interaction.global_position + Vector3(0.0, 0.0, 2.0)
	var out_of_range := interaction.try_claim(actor, 1, 88, &"navigator_avatar", 1)
	_check(not bool(out_of_range.get("accepted", true)) and out_of_range.get("status", &"") == &"interaction_out_of_range", "the navigator rejects an out-of-range actor")
	actor.global_position = interaction.global_position
	anchor.set_meta(&"seat_generation", 2)
	var stale_generation := interaction.try_claim(actor, 1, 88, &"navigator_avatar", 1)
	_check(not bool(stale_generation.get("accepted", true)) and stale_generation.get("status", &"") == &"stale_seat_generation", "a generation-one navigator interaction rejects a generation-two seat")
	anchor.set_meta(&"seat_generation", 1)

	var claimed := interaction.try_claim(actor, 1, 88, &"navigator_avatar", 1)
	_check(bool(claimed.get("accepted", false)), "the in-range navigator delegates an atomic authority claim")
	_check(StringName((authority.get_assignment(88, &"navigator_avatar")).get("seat_id", &"")) == Hauler.NAVIGATOR_STATION_SEAT_ID, "the claim records the exact navigator seat")
	var second_actor := CharacterBody3D.new()
	root.add_child(second_actor)
	second_actor.global_position = interaction.global_position
	var occupied := interaction.try_claim(second_actor, 1, 89, &"navigator_second", 1)
	_check(not bool(occupied.get("accepted", true)) and occupied.get("status", &"") == &"interaction_unavailable", "the physical navigator station is mutually exclusive")

	var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, -4.0)))
	_check(bool(reset.get("accepted", false)), "Cinder reset completes through the existing lifecycle")
	_check(authority.get_assignment(88, &"navigator_avatar").is_empty(), "reset releases the navigator authority assignment without caller release")
	_check(interaction.is_available(), "reset leaves a clean navigator re-entry interaction")
	var fresh_actor := CharacterBody3D.new()
	root.add_child(fresh_actor)
	fresh_actor.global_position = interaction.global_position
	var fresh_claim := interaction.try_claim(fresh_actor, 1, 89, &"navigator_fresh", 1)
	_check(bool(fresh_claim.get("accepted", false)), "a fresh occupant can claim after reset cleanup")
	var ping := craft.submit_crew_intent(
		1,
		89,
		&"navigator_fresh",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"sensor", "marker_id": &"route_beacon"},
		2
	)
	_check(bool(ping.get("accepted", false)) and bool(ping.get("consumed", false)), "the navigator consumes one authority-fenced passenger ping")
	var ping_snapshot := craft.get_navigator_ping_snapshot()
	_check(StringName((ping_snapshot.get("receipt", {}) as Dictionary).get("marker_id", &"")) == &"route_beacon", "the navigator exposes a detached ping receipt")
	_check(not bool(ping_snapshot.get("movement_authority", true)) and not bool(ping_snapshot.get("cargo_authority", true)), "the ping receipt grants no movement or cargo authority")
	interaction.clear_for_detach()
	_check(authority.get_assignment(89, &"navigator_fresh").is_empty(), "detach releases the navigator assignment without caller release")
	_check((craft.get_navigator_ping_snapshot().get("receipt", {}) as Dictionary).is_empty(), "detach clears the navigator ping receipt")
	interaction.refresh_availability()
	_check(interaction.is_available(), "detach cleanup permits navigator re-entry")

	actor.queue_free()
	second_actor.queue_free()
	fresh_actor.queue_free()
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_INTERACTION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
