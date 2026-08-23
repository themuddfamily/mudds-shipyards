extends SceneTree

## Focused cabin presentation contract: the retained loadmaster sign consumes
## detached role/manifest receipts, stays text-readable without colour, and has
## no gameplay collision or light ownership.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame
	await physics_frame

	var display := craft.get_node_or_null(^"WalkableInterior/LoadmasterCabin/LoadmasterStatusDisplay") as Label3D
	var panel := craft.get_node_or_null(^"WalkableInterior/LoadmasterCabin/LoadmasterStatusPanel") as MeshInstance3D
	_check(display != null and panel != null, "the reachable cabin retains one status display and panel")
	_check(
		display != null
			and display.get_meta("presentation_only", false)
			and display.get_meta("color_independent", false)
			and display.text.contains("[AVAILABLE]"),
		"the initial state is text-readable AVAILABLE without colour semantics"
	)
	_check(
		panel != null
			and panel.get_meta("presentation_only", false)
			and panel.get_meta("color_independent", false)
			and panel.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the restrained emissive panel owns no gameplay collision"
	)
	_check(craft.get_node_or_null(^"WalkableInterior/LoadmasterCabin/LoadmasterStatusDisplay") == display, "the display is retained rather than recreated")

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
			"the presentation test registers the %s role" % role
		)
	_check(bool(authority.seal_roster().get("accepted", false)), "the presentation roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the display binds to the existing role authority")
	_check(bool(authority.claim(1, 72, &"display_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).get("accepted", false)), "the display occupant claims the physical station")
	var occupied := craft.refresh_loadmaster_status_display()
	_check(
		occupied.get("state", &"") == &"occupied"
			and display.text.contains("[OCCUPIED]"),
		"an admitted occupant is shown as OCCUPIED"
	)
	var receipt := craft.submit_crew_intent(
		1,
		72,
		&"display_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"display_manifest", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	_check(bool(receipt.get("consumed", false)), "the display receives the authoritative manifest receipt")
	_check(
		display.text.contains("[MANIFEST READY]")
			and display.text.contains("ROUTE dock_04_cargo")
			and craft.get_loadmaster_status_snapshot().get("presentation_only", false),
		"manifest readiness and route are visible as detached text state"
	)
	var released := craft.release_crew_role(1, 72, &"display_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, 3, 1)
	_check(bool(released.get("accepted", false)), "release follows the existing authority lifecycle")
	_check(display.text.contains("[RELEASED]"), "release is visibly distinct from an available station")
	_check(display.get_instance_id() == (craft.get_node(^"WalkableInterior/LoadmasterCabin/LoadmasterStatusDisplay") as Label3D).get_instance_id(), "release does not recreate the display node")

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_LOADMASTER_CABIN_PRESENTATION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
