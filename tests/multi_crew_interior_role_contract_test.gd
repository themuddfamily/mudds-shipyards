extends SceneTree

## Focused production-scene audit for the Halyard's bounded multi-crew role
## layout.  This does not claim that a second peer can yet occupy a seat: all
## role entries are intent-only and the server/session authorities remain the
## future multiplayer seam.  It proves that the named roles already resolve to
## real seats and real, collision-backed interior routes.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const CONTRACT := preload("res://scripts/fleet/multi_crew_interior_role_contract.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate()
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var interior: Dictionary = craft.get_walkable_interior_report()
	var anchors: Array = craft.get_crew_seat_anchors()
	var anchor_positions := {
		&"pilot_station": _local_position(craft, craft.get_pilot_seat_anchor()),
		&"co_pilot_station": _local_position(craft, craft.get_co_pilot_station_anchor()),
	}
	var anchor_sources := {
		&"pilot_station": &"pilot_seat_anchor",
		&"co_pilot_station": &"co_pilot_station_anchor",
	}
	var physical_seat_ids: Array = ["pilot_station", "co_pilot_station"]
	for anchor in anchors:
		var seat_id := StringName(str(anchor.get_meta("seat_id", "")))
		anchor_positions[seat_id] = _local_position(craft, anchor)
		anchor_sources[seat_id] = &"crew_seat_anchor"
		physical_seat_ids.append(str(seat_id))

	_check(CONTRACT.get_contract().get("contract_id", StringName()) == &"halyard_multi_crew_interior_v1", "contract has a stable versioned ID")
	_check(CONTRACT.get_roles().size() == 6, "six named multi-crew roles are published")
	_check(physical_seat_ids.size() == 8, "the production transport publishes two stations plus six cabin seats")
	_check(interior.get("physical_deck_collision", false), "the role audit consumes physical deck collision")
	_check(interior.get("moving_occupant_compensation", false), "the role audit consumes MovingInteriorFrame compensation")

	var context := {
		"ship_id": craft.get_ship_id(),
		"interior_report": interior,
		"anchor_positions": anchor_positions,
		"anchor_sources": anchor_sources,
		"physical_seat_ids": physical_seat_ids,
	}
	var audit: Dictionary = CONTRACT.audit(context)
	_check(bool(audit.get("valid", false)), "all named roles resolve to physical seats and connected interior routes")
	_check((audit.get("seat_ids", []) as Array).size() == 6, "each named role has one covered seat")
	_check((audit.get("reserved_seat_ids", []) as Array).size() == 2, "remaining cabin seats are explicitly reserved for a later increment")
	_check(StringName(str(audit.get("layout_status", ""))) == &"layout_contract_only", "the contract does not overclaim live multiplayer gameplay")

	# Structured-red authority mutation: a client cannot acquire seat or movement
	# truth merely by presenting a role packet.
	var mutated_roles := CONTRACT.get_roles()
	(mutated_roles[0] as Dictionary)["authority"]["seat_reservation_owner"] = &"peer_input"
	var authority_red: Dictionary = CONTRACT.audit(context, mutated_roles)
	_check(not bool(authority_red.get("valid", true)), "RED: peer-owned seat reservation is rejected")
	_check(_contains_error(authority_red, "seat_reservation_owner"), "RED: authority drift identifies the reserved-state owner")

	# Structured-red route mutation: a role cannot bypass the physical cabin and
	# declare a direct teleport to its seat.
	var route_roles := CONTRACT.get_roles()
	(route_roles[4] as Dictionary)["route_spaces"] = PackedStringArray(["teleport"])
	var route_red: Dictionary = CONTRACT.audit(context, route_roles)
	_check(not bool(route_red.get("valid", true)), "RED: a non-physical role route is rejected")
	_check(_contains_error(route_red, "port airstair"), "RED: route failure names the missing boarding approach")

	craft.queue_free()
	await process_frame
	print("MULTI_CREW_INTERIOR_ROLE_CONTRACT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _local_position(craft: Node3D, anchor: Node3D) -> Vector3:
	return craft.global_transform.affine_inverse() * anchor.global_position


func _contains_error(report: Dictionary, fragment: String) -> bool:
	for error: String in report.get("errors", PackedStringArray()):
		if fragment in error:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
